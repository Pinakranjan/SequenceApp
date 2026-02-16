import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/planner_entry.dart';
import '../models/planner_enums.dart';

/// Analytics data for the planner.
class PlannerAnalytics {
  final int totalTasks;
  final int completedTasks;
  final int highPriorityPending;
  final Map<PlannerCategory, int> categoryDistribution;
  final List<int> weeklyTaskCounts;

  const PlannerAnalytics({
    required this.totalTasks,
    required this.completedTasks,
    required this.highPriorityPending,
    required this.categoryDistribution,
    required this.weeklyTaskCounts,
  });

  double get completionRate {
    if (totalTasks == 0) return 0.0;
    return completedTasks / totalTasks;
  }

  int get pendingTasks => totalTasks - completedTasks;
}

class PlannerRepository {
  static const String _storageKeyV1 = 'planner_entries_v1';
  static const String _storageKeyV2 = 'planner_entries_v2';
  static const String _migrationDoneKey = 'planner_v2_migrated';

  /// Gets all planner entries, automatically migrating from v1 if needed.
  Future<List<PlannerEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    // Force reload from disk to get latest data (crucial for background updates on iOS)
    await prefs.reload();

    // Check if migration is needed
    final hasMigrated = prefs.getBool(_migrationDoneKey) ?? false;
    if (!hasMigrated) {
      await _migrateFromV1(prefs);
    }

    final raw = prefs.getString(_storageKeyV2);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw);
    if (list is! List) return [];

    final entries = <PlannerEntry>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        entries.add(PlannerEntry.fromJson(item));
      } else if (item is Map) {
        entries.add(PlannerEntry.fromJson(item.cast<String, dynamic>()));
      }
    }

    entries.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return entries;
  }

  /// Migrates data from v1 storage key to v2.
  Future<void> _migrateFromV1(SharedPreferences prefs) async {
    final rawV1 = prefs.getString(_storageKeyV1);

    if (rawV1 != null && rawV1.isNotEmpty) {
      try {
        final listV1 = jsonDecode(rawV1);
        if (listV1 is List) {
          final entries = <PlannerEntry>[];
          for (final item in listV1) {
            Map<String, dynamic>? json;
            if (item is Map<String, dynamic>) {
              json = item;
            } else if (item is Map) {
              json = item.cast<String, dynamic>();
            }

            if (json != null) {
              // v1 entries will get default values for new fields via fromJson
              entries.add(PlannerEntry.fromJson(json));
            }
          }

          // Save to v2 format
          entries.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
          await prefs.setString(_storageKeyV2, encoded);
        }
      } catch (e) {
        // If migration fails, start fresh with v2
        // ignore: avoid_print
        print('Migration from v1 failed: $e');
      }
    }

    // Mark migration as done
    await prefs.setBool(_migrationDoneKey, true);
  }

  Future<void> upsert(PlannerEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getAll();

    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }

    entries.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKeyV2, encoded);
  }

  Future<void> deleteById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getAll();
    entries.removeWhere((e) => e.id == id);
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKeyV2, encoded);
  }

  Future<PlannerEntry?> getById(String id) async {
    final entries = await getAll();
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Updates just the completion status of an entry.
  Future<void> toggleCompletion(String id) async {
    final entry = await getById(id);
    if (entry == null) return;

    await upsert(
      entry.copyWith(
        isCompleted: !entry.isCompleted,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Updates a subtask's completion status.
  Future<void> toggleSubtaskCompletion(String entryId, String subtaskId) async {
    final entry = await getById(entryId);
    if (entry == null) return;

    final updatedSubtasks =
        entry.subtasks.map((s) {
          if (s.id == subtaskId) {
            return s.copyWith(isCompleted: !s.isCompleted);
          }
          return s;
        }).toList();

    await upsert(
      entry.copyWith(subtasks: updatedSubtasks, updatedAt: DateTime.now()),
    );
  }

  /// Gets entries filtered by category.
  Future<List<PlannerEntry>> getByCategory(PlannerCategory category) async {
    final entries = await getAll();
    return entries.where((e) => e.category == category).toList();
  }

  /// Gets entries filtered by priority.
  Future<List<PlannerEntry>> getByPriority(PlannerPriority priority) async {
    final entries = await getAll();
    return entries.where((e) => e.priority == priority).toList();
  }

  /// Gets completed entries.
  Future<List<PlannerEntry>> getCompleted() async {
    final entries = await getAll();
    return entries.where((e) => e.isFullyCompleted).toList();
  }

  /// Gets incomplete entries.
  Future<List<PlannerEntry>> getIncomplete() async {
    final entries = await getAll();
    return entries.where((e) => !e.isFullyCompleted).toList();
  }

  /// Gets analytics data for the planner.
  Future<PlannerAnalytics> getAnalytics() async {
    final entries = await getAll();
    final activeEntries = entries.where((e) => !e.isArchived).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    int totalTasks = activeEntries.length;
    int completedTasks = activeEntries.where((e) => e.isFullyCompleted).length;
    int highPriorityPending =
        activeEntries
            .where(
              (e) => e.priority == PlannerPriority.high && !e.isFullyCompleted,
            )
            .length;

    // Category distribution
    final categoryCount = <PlannerCategory, int>{};
    for (final cat in PlannerCategory.values) {
      categoryCount[cat] = activeEntries.where((e) => e.category == cat).length;
    }

    // Weekly task counts
    final weeklyTasks = <int>[0, 0, 0, 0, 0, 0, 0]; // Mon-Sun
    for (final entry in activeEntries) {
      final entryDate = DateTime(
        entry.dateTime.year,
        entry.dateTime.month,
        entry.dateTime.day,
      );
      if (!entryDate.isBefore(weekStart) &&
          entryDate.isBefore(weekStart.add(const Duration(days: 7)))) {
        weeklyTasks[entry.dateTime.weekday - 1]++;
      }
    }

    return PlannerAnalytics(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      highPriorityPending: highPriorityPending,
      categoryDistribution: categoryCount,
      weeklyTaskCounts: weeklyTasks,
    );
  }
}
