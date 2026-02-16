import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/local_notifications_service.dart';
import '../data/models/planner_entry.dart';
import '../data/models/planner_enums.dart';
import '../data/repositories/planner_repository.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository();
});

class PlannerState {
  final List<PlannerEntry> entries;
  final bool isLoading;
  final String? error;
  final PlannerAnalytics? analytics;

  const PlannerState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
    this.analytics,
  });

  PlannerState copyWith({
    List<PlannerEntry>? entries,
    bool? isLoading,
    String? error,
    PlannerAnalytics? analytics,
  }) {
    return PlannerState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      analytics: analytics ?? this.analytics,
    );
  }

  /// Get entries filtered by category.
  List<PlannerEntry> byCategory(PlannerCategory category) {
    return entries.where((e) => e.category == category).toList();
  }

  /// Get entries filtered by priority.
  List<PlannerEntry> byPriority(PlannerPriority priority) {
    return entries.where((e) => e.priority == priority).toList();
  }

  /// Get completed entries.
  List<PlannerEntry> get completed {
    return entries.where((e) => e.isFullyCompleted && !e.isArchived).toList();
  }

  /// Get incomplete entries.
  List<PlannerEntry> get incomplete {
    return entries.where((e) => !e.isFullyCompleted && !e.isArchived).toList();
  }

  /// Get high priority entries that are incomplete.
  List<PlannerEntry> get highPriorityPending {
    return entries
        .where((e) => e.priority == PlannerPriority.high && !e.isFullyCompleted)
        .where((e) => !e.isArchived)
        .toList();
  }
}

class PlannerNotifier extends StateNotifier<PlannerState> {
  final PlannerRepository _repo;

  PlannerNotifier(this._repo) : super(const PlannerState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final entries = await _repo.getAll();
      final analytics = await _repo.getAnalytics();
      state = state.copyWith(
        entries: entries,
        isLoading: false,
        analytics: analytics,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> upsert(PlannerEntry entry) async {
    await _repo.upsert(entry);
    await load();
  }

  Future<void> _cancelReminderIfAny(PlannerEntry entry) async {
    final id = entry.notificationId;
    if (id == null) return;
    await LocalNotificationsService().cancel(id);
  }

  Future<void> delete(String id) async {
    await _repo.deleteById(id);
    await load();
  }

  /// Toggle the completion status of an entry.
  Future<void> toggleCompletion(String id) async {
    final entry = state.entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Entry not found'),
    );

    final now = DateTime.now();
    final newIsCompleted = !entry.isCompleted;

    // Notifications only for active tasks.
    if (newIsCompleted) {
      await _cancelReminderIfAny(entry);
    }

    await _repo.upsert(
      entry.copyWith(
        isCompleted: newIsCompleted,
        updatedAt: now,
        clearReminder: newIsCompleted,
        notificationId: newIsCompleted ? null : entry.notificationId,
      ),
    );
    await load();
  }

  /// Toggle the completion status of a subtask.
  Future<void> toggleSubtaskCompletion(String entryId, String subtaskId) async {
    final entry = state.entries.firstWhere(
      (e) => e.id == entryId,
      orElse: () => throw Exception('Entry not found'),
    );

    final updatedSubtasks =
        entry.subtasks.map((s) {
          if (s.id == subtaskId) {
            return s.copyWith(isCompleted: !s.isCompleted);
          }
          return s;
        }).toList();

    final updatedEntry = entry.copyWith(
      subtasks: updatedSubtasks,
      updatedAt: DateTime.now(),
    );

    if (updatedEntry.isFullyCompleted) {
      await _cancelReminderIfAny(entry);
    }

    await _repo.upsert(
      updatedEntry.copyWith(
        clearReminder: updatedEntry.isFullyCompleted,
        notificationId:
            updatedEntry.isFullyCompleted ? null : entry.notificationId,
      ),
    );
    await load();
  }

  /// Update just the priority of an entry.
  Future<void> updatePriority(String id, PlannerPriority priority) async {
    final entry = state.entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Entry not found'),
    );
    await _repo.upsert(
      entry.copyWith(priority: priority, updatedAt: DateTime.now()),
    );
    await load();
  }

  /// Update just the category of an entry.
  Future<void> updateCategory(String id, PlannerCategory category) async {
    final entry = state.entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Entry not found'),
    );
    await _repo.upsert(
      entry.copyWith(category: category, updatedAt: DateTime.now()),
    );
    await load();
  }

  /// Toggle the archive status of an entry (only for completed tasks).
  Future<void> toggleArchive(String id) async {
    final entry = state.entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Entry not found'),
    );
    // Only allow archiving completed tasks
    if (!entry.isFullyCompleted && !entry.isArchived) return;

    final nowArchived = !entry.isArchived;
    if (nowArchived) {
      await _cancelReminderIfAny(entry);
    }
    await _repo.upsert(
      entry.copyWith(
        isArchived: nowArchived,
        updatedAt: DateTime.now(),
        clearReminder: nowArchived,
        notificationId: nowArchived ? null : entry.notificationId,
      ),
    );
    await load();
  }
}

final plannerProvider = StateNotifierProvider<PlannerNotifier, PlannerState>((
  ref,
) {
  return PlannerNotifier(ref.watch(plannerRepositoryProvider));
});

/// Provider for analytics data.
final plannerAnalyticsProvider = Provider<PlannerAnalytics?>((ref) {
  return ref.watch(plannerProvider).analytics;
});

/// Provider for high priority pending tasks count.
final highPriorityPendingCountProvider = Provider<int>((ref) {
  return ref.watch(plannerProvider).highPriorityPending.length;
});

/// Provider for completion rate.
final completionRateProvider = Provider<double>((ref) {
  final analytics = ref.watch(plannerAnalyticsProvider);
  return analytics?.completionRate ?? 0.0;
});
