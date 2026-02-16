import '../models/notice_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository for notice-related data operations
class NoticeRepository {
  final ApiService _apiService;

  NoticeRepository(this._apiService);

  /// Fetch all notices from the API
  Future<ApiResponse<List<Notice>>> getNotices() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiConstants.notices,
    );

    if (response.isSuccess && response.data != null) {
      final noticeItems = response.data!['noticeitems'] as List<dynamic>?;
      
      if (noticeItems != null) {
        final notices = noticeItems
            .map((json) => Notice.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Sort by date, newest first
        notices.sort((a, b) => b.newsDate.compareTo(a.newsDate));
        
        return ApiResponse.success(notices);
      }
      
      return ApiResponse.success([]);
    }

    return ApiResponse.error(response.error ?? 'Failed to fetch notices');
  }
}
