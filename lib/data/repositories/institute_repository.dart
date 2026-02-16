import '../models/institute_model.dart';
import '../services/api_service.dart';
import '../../core/constants/api_constants.dart';

/// Repository for institute-related data operations
class InstituteRepository {
  final ApiService _apiService;

  InstituteRepository(this._apiService);

  /// Fetch all institutes grouped by course type from the API
  Future<ApiResponse<Map<CourseType, List<Institute>>>> getInstitutes() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiConstants.institutes,
    );

    if (response.isSuccess && response.data != null) {
      final institutesData = response.data!['institutes'] as Map<String, dynamic>?;
      
      if (institutesData != null) {
        final Map<CourseType, List<Institute>> groupedInstitutes = {};
        
        institutesData.forEach((key, value) {
          final courseType = CourseType.fromKey(key);
          if (courseType != null && value is List) {
            final institutes = value
                .map((json) => Institute.fromJson(json as Map<String, dynamic>, key))
                .toList();
            
            // Sort by name
            institutes.sort((a, b) => a.instName.compareTo(b.instName));
            
            groupedInstitutes[courseType] = institutes;
          }
        });
        
        return ApiResponse.success(groupedInstitutes);
      }
      
      return ApiResponse.success({});
    }

    return ApiResponse.error(response.error ?? 'Failed to fetch institutes');
  }

  /// Get list of unique districts for a specific course type
  List<String> getDistrictsForCourse(
    Map<CourseType, List<Institute>> allInstitutes,
    CourseType courseType,
  ) {
    final institutes = allInstitutes[courseType] ?? [];
    final districts = institutes.map((i) => i.district).toSet().toList();
    districts.sort();
    return districts;
  }

  /// Filter institutes by district
  List<Institute> filterByDistrict(
    List<Institute> institutes,
    String? district,
  ) {
    if (district == null || district.isEmpty) {
      return institutes;
    }
    return institutes.where((i) => i.district == district).toList();
  }

  /// Search institutes by name
  List<Institute> searchInstitutes(
    List<Institute> institutes,
    String query,
  ) {
    if (query.isEmpty) {
      return institutes;
    }
    final lowerQuery = query.toLowerCase();
    return institutes.where((i) {
      return i.instName.toLowerCase().contains(lowerQuery) ||
          i.district.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
