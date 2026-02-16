import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/institute_model.dart';
import '../data/repositories/institute_repository.dart';
import 'notice_provider.dart'; // For apiServiceProvider

/// Institute repository provider
final instituteRepositoryProvider = Provider<InstituteRepository>((ref) {
  return InstituteRepository(ref.watch(apiServiceProvider));
});

/// Institutes state
class InstitutesState {
  final Map<CourseType, List<Institute>> institutes;
  final bool isLoading;
  final bool isCourseTransitionLoading;
  final bool isDistrictTransitionLoading;
  final String? error;
  final CourseType? selectedCourse;
  final String? selectedDistrict;
  final String searchQuery;

  InstitutesState({
    this.institutes = const {},
    this.isLoading = false,
    this.isCourseTransitionLoading = false,
    this.isDistrictTransitionLoading = false,
    this.error,
    this.selectedCourse,
    this.selectedDistrict,
    this.searchQuery = '',
  });

  InstitutesState copyWith({
    Map<CourseType, List<Institute>>? institutes,
    bool? isLoading,
    bool? isCourseTransitionLoading,
    bool? isDistrictTransitionLoading,
    String? error,
    CourseType? selectedCourse,
    Object? selectedDistrict = _sentinel,
    String? searchQuery,
    bool clearSelectedCourse = false,
    bool clearSelectedDistrict = false,
  }) {
    return InstitutesState(
      institutes: institutes ?? this.institutes,
      isLoading: isLoading ?? this.isLoading,
      isCourseTransitionLoading:
          isCourseTransitionLoading ?? this.isCourseTransitionLoading,
      isDistrictTransitionLoading:
          isDistrictTransitionLoading ?? this.isDistrictTransitionLoading,
      error: error,
      selectedCourse:
          clearSelectedCourse ? null : (selectedCourse ?? this.selectedCourse),
      selectedDistrict:
          clearSelectedDistrict
              ? null
              : (selectedDistrict == _sentinel
                  ? this.selectedDistrict
                  : selectedDistrict as String?),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Get institutes for selected course
  List<Institute> get institutesForSelectedCourse {
    if (selectedCourse == null) return [];
    return institutes[selectedCourse] ?? [];
  }

  /// Get filtered institutes based on district and search
  List<Institute> get filteredInstitutes {
    var result = institutesForSelectedCourse;

    // Filter by district
    if (selectedDistrict != null && selectedDistrict!.isNotEmpty) {
      result = result.where((i) => i.district == selectedDistrict).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result =
          result.where((i) {
            return i.instName.toLowerCase().contains(query) ||
                i.district.toLowerCase().contains(query);
          }).toList();
    }

    return result;
  }

  /// Get unique districts for selected course
  List<String> get districtsForSelectedCourse {
    final institutes = institutesForSelectedCourse;
    final districts = institutes.map((i) => i.district).toSet().toList();
    districts.sort();
    return districts;
  }
}

const Object _sentinel = Object();

/// Institutes state notifier
class InstitutesNotifier extends StateNotifier<InstitutesState> {
  final InstituteRepository _repository;
  int _courseTransitionToken = 0;
  int _districtTransitionToken = 0;

  InstitutesNotifier(this._repository) : super(InstitutesState()) {
    fetchInstitutes();
  }

  /// Fetch institutes from API
  Future<void> fetchInstitutes() async {
    _districtTransitionToken++;
    state = state.copyWith(
      isLoading: true,
      error: null,
      isDistrictTransitionLoading: false,
    );

    try {
      final response = await _repository.getInstitutes();

      if (response.isSuccess) {
        state = state.copyWith(
          institutes: response.data ?? {},
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.error);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load institutes: $e',
      );
    }
  }

  /// Select a course
  Future<void> selectCourse(CourseType course) async {
    final token = ++_courseTransitionToken;
    _districtTransitionToken++;
    state = state.copyWith(
      selectedCourse: course,
      clearSelectedDistrict: true,
      searchQuery: '',
      isCourseTransitionLoading: true,
      isDistrictTransitionLoading: false,
    );

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (token != _courseTransitionToken) return;
    if (state.selectedCourse != course) return;

    state = state.copyWith(isCourseTransitionLoading: false);
  }

  /// Clear selected course
  void clearCourse() {
    _courseTransitionToken++;
    _districtTransitionToken++;
    state = state.copyWith(
      clearSelectedCourse: true,
      clearSelectedDistrict: true,
      searchQuery: '',
      isCourseTransitionLoading: false,
      isDistrictTransitionLoading: false,
    );
  }

  /// Select a district
  Future<void> selectDistrict(String? district) async {
    if (district == state.selectedDistrict) return;

    final token = ++_districtTransitionToken;
    state = state.copyWith(
      selectedDistrict: district,
      isDistrictTransitionLoading: true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (token != _districtTransitionToken) return;

    state = state.copyWith(isDistrictTransitionLoading: false);
  }

  /// Update search query
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Refresh institutes
  Future<void> refresh() async {
    await fetchInstitutes();
  }
}

/// Institutes provider
final institutesProvider =
    StateNotifierProvider<InstitutesNotifier, InstitutesState>(
      (ref) => InstitutesNotifier(ref.watch(instituteRepositoryProvider)),
    );
