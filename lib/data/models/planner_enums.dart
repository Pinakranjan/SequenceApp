// Enums and helper classes for enhanced planner functionality.

/// Priority levels for planner entries.
enum PlannerPriority {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case PlannerPriority.low:
        return 'Low';
      case PlannerPriority.medium:
        return 'Medium';
      case PlannerPriority.high:
        return 'High';
    }
  }

  /// Returns ARGB color value for the priority.
  int get colorValue {
    switch (this) {
      case PlannerPriority.low:
        return 0xFF22C55E; // Green
      case PlannerPriority.medium:
        return 0xFFF59E0B; // Amber
      case PlannerPriority.high:
        return 0xFFEF4444; // Red
    }
  }
}

/// Categories for organizing planner entries.
enum PlannerCategory {
  exam,
  deadline,
  reminder,
  document,
  other;

  String get label {
    switch (this) {
      case PlannerCategory.exam:
        return 'Exam';
      case PlannerCategory.deadline:
        return 'Deadline';
      case PlannerCategory.reminder:
        return 'Reminder';
      case PlannerCategory.document:
        return 'Document';
      case PlannerCategory.other:
        return 'Other';
    }
  }

  /// Returns icon name for the category.
  String get iconName {
    switch (this) {
      case PlannerCategory.exam:
        return 'edit_document';
      case PlannerCategory.deadline:
        return 'schedule';
      case PlannerCategory.reminder:
        return 'notifications';
      case PlannerCategory.document:
        return 'description';
      case PlannerCategory.other:
        return 'star';
    }
  }

  /// Returns ARGB color value for the category.
  int get colorValue {
    switch (this) {
      case PlannerCategory.exam:
        return 0xFF8B5CF6; // Purple
      case PlannerCategory.deadline:
        return 0xFFEF4444; // Red
      case PlannerCategory.reminder:
        return 0xFF3B82F6; // Blue
      case PlannerCategory.document:
        return 0xFFF97316; // Orange
      case PlannerCategory.other:
        return 0xFF6B7280; // Gray
    }
  }
}

/// Recurrence types for recurring planner entries.
enum RecurrenceType {
  daily,
  weekly,
  monthly,
  yearly;

  String get label {
    switch (this) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.yearly:
        return 'Yearly';
    }
  }
}

/// A subtask within a planner entry.
class SubTask {
  final String id;
  final String title;
  final bool isCompleted;

  const SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  SubTask copyWith({String? id, String? title, bool? isCompleted}) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'isCompleted': isCompleted};
  }

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      isCompleted: json['isCompleted'] == true,
    );
  }
}

/// Defines a recurrence pattern for recurring planner entries.
class RecurrenceRule {
  final RecurrenceType type;
  final int interval;
  final DateTime? endDate;
  final List<DateTime> specificDates;

  const RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.endDate,
    this.specificDates = const [],
  });

  RecurrenceRule copyWith({
    RecurrenceType? type,
    int? interval,
    DateTime? endDate,
    bool clearEndDate = false,
    List<DateTime>? specificDates,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      specificDates: specificDates ?? this.specificDates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'interval': interval,
      'endDate': endDate?.toIso8601String(),
      'specificDates': specificDates.map((d) => d.toIso8601String()).toList(),
    };
  }

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    List<DateTime> dates = [];
    if (json['specificDates'] is List) {
      for (final d in json['specificDates']) {
        final parsed = DateTime.tryParse(d.toString());
        if (parsed != null) dates.add(parsed);
      }
    }

    return RecurrenceRule(
      type: RecurrenceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RecurrenceType.daily,
      ),
      interval: json['interval'] is int ? json['interval'] : 1,
      endDate:
          json['endDate'] == null
              ? null
              : DateTime.tryParse(json['endDate'].toString()),
      specificDates: dates,
    );
  }

  String get displayText {
    if (specificDates.isNotEmpty) {
      return '${specificDates.length} specific date${specificDates.length > 1 ? 's' : ''}';
    }
    if (interval == 1) {
      return type.label;
    }
    switch (type) {
      case RecurrenceType.daily:
        return 'Every $interval days';
      case RecurrenceType.weekly:
        return 'Every $interval weeks';
      case RecurrenceType.monthly:
        return 'Every $interval months';
      case RecurrenceType.yearly:
        return 'Every $interval years';
    }
  }
}
