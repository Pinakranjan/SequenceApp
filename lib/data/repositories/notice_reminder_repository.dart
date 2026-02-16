import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notice_reminder.dart';

class NoticeReminderRepository {
  static const String _storageKey = 'notice_reminders_v1';

  Future<List<NoticeReminder>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw);
    if (list is! List) return [];

    final reminders = <NoticeReminder>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        reminders.add(NoticeReminder.fromJson(item));
      } else if (item is Map) {
        reminders.add(NoticeReminder.fromJson(item.cast<String, dynamic>()));
      }
    }

    reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return reminders;
  }

  Future<NoticeReminder?> getByNewsId(int newsId) async {
    final all = await getAll();
    for (final r in all) {
      if (r.newsId == newsId) return r;
    }
    return null;
  }

  Future<void> upsert(NoticeReminder reminder) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();

    final index = all.indexWhere((r) => r.newsId == reminder.newsId);
    if (index >= 0) {
      all[index] = reminder;
    } else {
      all.add(reminder);
    }

    final encoded = jsonEncode(all.map((r) => r.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> deleteByNewsId(int newsId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    all.removeWhere((r) => r.newsId == newsId);
    final encoded = jsonEncode(all.map((r) => r.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
