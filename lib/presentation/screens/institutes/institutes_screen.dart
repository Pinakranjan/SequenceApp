import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../providers/institute_provider.dart';
import '../../../data/models/institute_model.dart';
import '../../widgets/common/shimmer_loading.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/theme_toggle_action.dart';
import '../../widgets/institutes/course_card.dart';
import '../../widgets/institutes/institute_tile.dart';

/// Institutes screen with course selection and institute list
class InstitutesScreen extends ConsumerWidget {
  const InstitutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutesState = ref.watch(institutesProvider);
    final isCourseBusy =
        institutesState.isLoading || institutesState.isCourseTransitionLoading;
    final isListBusy =
        isCourseBusy || institutesState.isDistrictTransitionLoading;

    return Scaffold(
      body:
          institutesState.selectedCourse == null
              ? _buildCourseSelection(
                context,
                ref,
                institutesState,
                isCourseBusy,
              )
              : _buildInstituteList(
                context,
                ref,
                institutesState,
                isCourseBusy,
                isListBusy,
              ),
    );
  }

  Widget _buildCourseSelection(
    BuildContext context,
    WidgetRef ref,
    InstitutesState state,
    bool isBusy,
  ) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: AppConfig.sliverAppBarExpandedHeight,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            titlePadding: const EdgeInsets.only(left: 16, right: 0, bottom: 8),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Institutes',
                    style: AppConfig.headerTitleTextStyle(theme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: const ThemeToggleAction(),
                ),
              ],
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Stack(
                children: [
                  // Top logo
                  Align(
                    alignment: Alignment.topCenter,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 8,
                          left: 16,
                          right: 16,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 70),
                          child: SvgPicture.asset(
                            'assets/images/icons/logo.svg',
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                            colorFilter: const ColorFilter.mode(
                              AppColors.logoTint,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Content
        if (isBusy)
          const SliverFillRemaining(child: ShimmerGridLoading())
        else if (state.error != null)
          SliverFillRemaining(
            child: AppErrorWidget(
              message: state.error!,
              onRetry: () {
                ref.read(institutesProvider.notifier).refresh();
              },
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= CourseType.values.length) {
                  return const SizedBox.shrink();
                }
                final courseType = CourseType.values[index];

                return CourseCard(
                  courseType: courseType,
                  index: index,
                  onTap: () {
                    ref
                        .read(institutesProvider.notifier)
                        .selectCourse(courseType);
                  },
                );
              }, childCount: CourseType.values.length),
            ),
          ),
        // Add bottom padding to ensure the list is long enough to scroll
        // and collapse the SliverAppBar even on large screens.
        const SliverToBoxAdapter(child: SizedBox(height: 300)),
      ],
    );
  }

  Widget _buildInstituteList(
    BuildContext context,
    WidgetRef ref,
    InstitutesState state,
    bool isCourseBusy,
    bool isListBusy,
  ) {
    final theme = Theme.of(context);
    final filteredInstitutes = state.filteredInstitutes;
    final districts = state.districtsForSelectedCourse;

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: AppConfig.sliverAppBarExpandedHeight,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            titlePadding: const EdgeInsets.only(left: 16, right: 0, bottom: 8),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.selectedCourse!.title} Institutes',
                    style: AppConfig.headerTitleTextStyle(theme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: const ThemeToggleAction(),
                ),
              ],
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Stack(
                children: [
                  // Top logo
                  Align(
                    alignment: Alignment.topCenter,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 8,
                          left: 16,
                          right: 16,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 70),
                          child: SvgPicture.asset(
                            'assets/images/icons/logo.svg',
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                            colorFilter: const ColorFilter.mode(
                              AppColors.logoTint,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Filter section (shimmers while busy)
        SliverToBoxAdapter(
          child:
              isCourseBusy
                  ? const ShimmerFilterBarLoading()
                  : Card(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    elevation: 0,
                    color:
                        theme.brightness == Brightness.light
                            ? Colors.grey.shade50
                            : theme.colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Filters',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  ref
                                      .read(institutesProvider.notifier)
                                      .clearCourse();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                  textStyle: theme.textTheme.labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.grid_view, size: 18),
                                label: const Text('Change course'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // District filter dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: state.selectedDistrict,
                                hint: const Text('All Districts'),
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down),
                                style: theme.textTheme.bodyMedium,
                                dropdownColor: theme.colorScheme.surface,
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All Districts'),
                                  ),
                                  ...districts.map(
                                    (district) => DropdownMenuItem(
                                      value: district,
                                      child: Text(district),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  ref
                                      .read(institutesProvider.notifier)
                                      .selectDistrict(value);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Search field
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search institutes...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              ref
                                  .read(institutesProvider.notifier)
                                  .updateSearchQuery(value);
                            },
                          ),
                          const SizedBox(height: 12),
                          // Results count
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${filteredInstitutes.length} institutes found',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
        ),

        if (isListBusy)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ShimmerLoading(),
          )
        else ...[
          // Institute list
          if (filteredInstitutes.isEmpty)
            SliverFillRemaining(
              child: EmptyStateWidget(
                title: 'No Institutes Found',
                subtitle: 'Try adjusting your filters',
                icon: Icons.school_outlined,
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final institute = filteredInstitutes[index];
                return InstituteTile(
                  institute: institute,
                  index: index,
                  onTap: () {
                    _showInstituteDetail(context, institute);
                  },
                );
              }, childCount: filteredInstitutes.length),
            ),
          // Bottom padding for scroll
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ],
    );
  }

  void _showInstituteDetail(BuildContext context, Institute institute) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          institute.instName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // District chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            institute.district,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Address
                        if (institute.address.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  institute.address,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Close button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
