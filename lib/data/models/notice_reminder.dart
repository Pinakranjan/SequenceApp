import 'package:html_unescape/html_unescape.dart';
import 'planner_enums.dart';

class NoticeReminder {
  final int newsId;
  final String noticeTitle;

  /// The original scheduled time (should not change during snooze)
  final DateTime scheduledAt;

  /// The next reminder time (updated during snooze)
  final DateTime? reminderAt;
  final int notificationId;
  final DateTime createdAt;

  final PlannerPriority priority;
  final PlannerCategory category;
  final RecurrenceRule? recurrence;
  final Duration reminderOffset;

  const NoticeReminder({
    required this.newsId,
    required this.noticeTitle,
    required this.scheduledAt,
    this.reminderAt,
    required this.notificationId,
    required this.createdAt,
    this.priority = PlannerPriority.medium,
    this.category = PlannerCategory.deadline,
    this.recurrence,
    this.reminderOffset = Duration.zero,
  });

  /// Returns the effective reminder time (reminderAt if set, otherwise scheduledAt)
  DateTime get effectiveReminderTime => reminderAt ?? scheduledAt;

  Map<String, dynamic> toJson() {
    return {
      'newsId': newsId,
      'noticeTitle': noticeTitle,
      'scheduledAt': scheduledAt.toIso8601String(),
      'reminderAt': reminderAt?.toIso8601String(),
      'notificationId': notificationId,
      'createdAt': createdAt.toIso8601String(),
      'priority': priority.name,
      'category': category.name,
      'recurrence': recurrence?.toJson(),
      'reminderOffset': reminderOffset.inMinutes,
    };
  }

  factory NoticeReminder.fromJson(Map<String, dynamic> json) {
    return NoticeReminder(
      newsId: int.parse(json['newsId'].toString()),
      noticeTitle: HtmlUnescape().convert(
        (json['noticeTitle'] ?? '').toString(),
      ),
      scheduledAt: DateTime.parse(json['scheduledAt'].toString()),
      reminderAt:
          json['reminderAt'] != null
              ? DateTime.parse(json['reminderAt'].toString())
              : null,
      notificationId: int.parse(json['notificationId'].toString()),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      priority: PlannerPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => PlannerPriority.medium,
      ),
      category: PlannerCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => PlannerCategory.deadline,
      ),
      recurrence:
          json['recurrence'] != null
              ? RecurrenceRule.fromJson(
                json['recurrence'] as Map<String, dynamic>,
              )
              : null,
      reminderOffset: Duration(
        minutes: int.tryParse(json['reminderOffset'].toString()) ?? 0,
      ),
    );
  }

  NoticeReminder copyWith({
    int? newsId,
    String? noticeTitle,
    DateTime? scheduledAt,
    DateTime? reminderAt,
    int? notificationId,
    DateTime? createdAt,
    PlannerPriority? priority,
    PlannerCategory? category,
    RecurrenceRule? recurrence,
    Duration? reminderOffset,
  }) {
    return NoticeReminder(
      newsId: newsId ?? this.newsId,
      noticeTitle: noticeTitle ?? this.noticeTitle,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      reminderAt: reminderAt ?? this.reminderAt,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      recurrence: recurrence ?? this.recurrence,
      reminderOffset: reminderOffset ?? this.reminderOffset,
    );
  }
}
