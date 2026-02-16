import 'package:html_unescape/html_unescape.dart';
import 'planner_enums.dart';

class PlannerEntry {
  final String id;
  final String title;
  final String notes;
  final DateTime dateTime;

  /// If set, a local notification is scheduled at [reminderAt].
  final DateTime? reminderAt;

  /// Local notification id to cancel/update.
  final int? notificationId;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Enhanced fields
  final PlannerPriority priority;
  final PlannerCategory category;
  final bool isCompleted;
  final List<SubTask> subtasks;
  final Duration? estimatedDuration;
  final bool isRecurring;
  final RecurrenceRule? recurrence;
  final bool isArchived;

  const PlannerEntry({
    required this.id,
    required this.title,
    required this.notes,
    required this.dateTime,
    required this.createdAt,
    required this.updatedAt,
    this.reminderAt,
    this.notificationId,
    this.priority = PlannerPriority.medium,
    this.category = PlannerCategory.other,
    this.isCompleted = false,
    this.subtasks = const [],
    this.estimatedDuration,
    this.isRecurring = false,
    this.recurrence,
    this.isArchived = false,
  });

  /// Calculates completion percentage based on subtasks.
  /// Returns 1.0 if no subtasks and isCompleted is true.
  /// Returns 0.0 if no subtasks and isCompleted is false.
  double get completionPercentage {
    if (subtasks.isEmpty) {
      return isCompleted ? 1.0 : 0.0;
    }
    final completed = subtasks.where((s) => s.isCompleted).length;
    return completed / subtasks.length;
  }

  /// Returns true if all subtasks are completed (or no subtasks and isCompleted).
  bool get isFullyCompleted {
    if (subtasks.isEmpty) return isCompleted;
    return subtasks.every((s) => s.isCompleted);
  }

  PlannerEntry copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? dateTime,
    DateTime? reminderAt,
    int? notificationId,
    DateTime? createdAt,
    DateTime? updatedAt,
    PlannerPriority? priority,
    PlannerCategory? category,
    bool? isCompleted,
    List<SubTask>? subtasks,
    Duration? estimatedDuration,
    bool? isRecurring,
    RecurrenceRule? recurrence,
    bool clearReminder = false,
    bool clearDuration = false,
    bool clearRecurrence = false,
    bool? isArchived,
  }) {
    return PlannerEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dateTime: dateTime ?? this.dateTime,
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      notificationId:
          clearReminder ? null : (notificationId ?? this.notificationId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      subtasks: subtasks ?? this.subtasks,
      estimatedDuration:
          clearDuration ? null : (estimatedDuration ?? this.estimatedDuration),
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'dateTime': dateTime.toIso8601String(),
      'reminderAt': reminderAt?.toIso8601String(),
      'notificationId': notificationId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'priority': priority.name,
      'category': category.name,
      'isCompleted': isCompleted,
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
      'estimatedDurationMinutes': estimatedDuration?.inMinutes,
      'isRecurring': isRecurring,
      'recurrence': recurrence?.toJson(),
      'isArchived': isArchived,
    };
  }

  factory PlannerEntry.fromJson(Map<String, dynamic> json) {
    // Parse subtasks
    final subtasksJson = json['subtasks'];
    final subtasks = <SubTask>[];
    if (subtasksJson is List) {
      for (final item in subtasksJson) {
        if (item is Map<String, dynamic>) {
          subtasks.add(SubTask.fromJson(item));
        } else if (item is Map) {
          subtasks.add(SubTask.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    // Parse estimated duration
    final durationMinutes = json['estimatedDurationMinutes'];
    Duration? estimatedDuration;
    if (durationMinutes is int && durationMinutes > 0) {
      estimatedDuration = Duration(minutes: durationMinutes);
    }

    // Parse recurrence
    final recurrenceJson = json['recurrence'];
    RecurrenceRule? recurrence;
    if (recurrenceJson is Map<String, dynamic>) {
      recurrence = RecurrenceRule.fromJson(recurrenceJson);
    } else if (recurrenceJson is Map) {
      recurrence = RecurrenceRule.fromJson(
        recurrenceJson.cast<String, dynamic>(),
      );
    }

    return PlannerEntry(
      id: (json['id'] ?? '').toString(),
      title: HtmlUnescape().convert((json['title'] ?? '').toString()),
      notes: (json['notes'] ?? '').toString(),
      dateTime: DateTime.parse((json['dateTime'] ?? '').toString()),
      reminderAt:
          json['reminderAt'] == null
              ? null
              : DateTime.parse(json['reminderAt'].toString()),
      notificationId:
          json['notificationId'] == null
              ? null
              : int.tryParse(json['notificationId'].toString()),
      createdAt: DateTime.parse((json['createdAt'] ?? '').toString()),
      updatedAt: DateTime.parse((json['updatedAt'] ?? '').toString()),
      priority: PlannerPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => PlannerPriority.medium,
      ),
      category: PlannerCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => PlannerCategory.other,
      ),
      isCompleted: json['isCompleted'] == true,
      subtasks: subtasks,
      estimatedDuration: estimatedDuration,
      isRecurring: json['isRecurring'] == true,
      recurrence: recurrence,
      isArchived: json['isArchived'] == true,
    );
  }
}
