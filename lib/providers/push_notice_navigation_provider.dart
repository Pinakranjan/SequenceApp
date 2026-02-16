import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When set, the Notices tab should open the relevant notice (by `newsId`).
final pendingNoticeOpenIdProvider = StateProvider<int?>((ref) => null);
