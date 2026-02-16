import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/notice_reminder.dart';
import '../data/repositories/notice_reminder_repository.dart';

final noticeReminderRepositoryProvider = Provider<NoticeReminderRepository>((
  ref,
) {
  return NoticeReminderRepository();
});

final noticeReminderProvider = FutureProvider.family<NoticeReminder?, int>((
  ref,
  newsId,
) async {
  final repo = ref.watch(noticeReminderRepositoryProvider);
  return repo.getByNewsId(newsId);
});

final noticeRemindersProvider = FutureProvider<List<NoticeReminder>>((ref) {
  final repo = ref.watch(noticeReminderRepositoryProvider);
  return repo.getAll();
});
