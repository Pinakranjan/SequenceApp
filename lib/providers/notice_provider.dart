import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../data/models/notice_model.dart';
import '../data/repositories/notice_repository.dart';
import '../data/services/api_service.dart';

/// API Service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Notice repository provider
final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  return NoticeRepository(ref.watch(apiServiceProvider));
});

/// Notices state
class NoticesState {
  final List<Notice> notices;
  final bool isLoading;
  final String? error;

  NoticesState({this.notices = const [], this.isLoading = false, this.error});

  NoticesState copyWith({
    List<Notice>? notices,
    bool? isLoading,
    String? error,
  }) {
    return NoticesState(
      notices: notices ?? this.notices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notices state notifier
class NoticesNotifier extends StateNotifier<NoticesState> {
  final NoticeRepository _repository;

  NoticesNotifier(this._repository) : super(NoticesState()) {
    fetchNotices();
  }

  /// Fetch notices from API
  Future<void> fetchNotices() async {
    const minShimmerMs = 300;
    final totalStopwatch = Stopwatch()..start();

    state = state.copyWith(isLoading: true, error: null);

    try {
      final fetchStopwatch = Stopwatch()..start();
      final response = await _repository.getNotices();
      fetchStopwatch.stop();

      final remainingMs = minShimmerMs - totalStopwatch.elapsedMilliseconds;
      if (remainingMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: remainingMs));
      }

      if (response.isSuccess) {
        state = state.copyWith(notices: response.data ?? [], isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }

      totalStopwatch.stop();
      assert(() {
        debugPrint(
          '[Notices] fetch=${fetchStopwatch.elapsedMilliseconds}ms, shimmer=${totalStopwatch.elapsedMilliseconds}ms',
        );
        return true;
      }());
    } catch (e) {
      final remainingMs = minShimmerMs - totalStopwatch.elapsedMilliseconds;
      if (remainingMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: remainingMs));
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notices: $e',
      );

      totalStopwatch.stop();
      assert(() {
        debugPrint(
          '[Notices] error after shimmer=${totalStopwatch.elapsedMilliseconds}ms: $e',
        );
        return true;
      }());
    }
  }

  /// Refresh notices
  Future<void> refresh() async {
    await fetchNotices();
  }
}

/// Notices provider
final noticesProvider = StateNotifierProvider<NoticesNotifier, NoticesState>(
  (ref) => NoticesNotifier(ref.watch(noticeRepositoryProvider)),
);
