import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../data/models/planner_entry.dart';
import '../../../data/models/planner_enums.dart';
import '../../../data/models/notice_reminder.dart';
import '../../../providers/home_navigation_provider.dart';
import '../../../providers/notice_reminder_provider.dart';
import '../../../providers/planner_pins_provider.dart';
import '../../../providers/planner_provider.dart';
import '../../../providers/push_planner_navigation_provider.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/shimmer_loading.dart';
import '../../widgets/common/theme_toggle_action.dart';
import '../../widgets/planner/planner_card.dart';
import '../../widgets/planner/category_chip.dart';
import 'planner_edit_screen.dart';
import 'planner_report_screen.dart';
import 'planner_search_screen.dart';

enum _TimelineType { plannerEntry, noticeReminder }

class _TimelineItem {
  final _TimelineType type;
  final String id;
  final String pinKey;
  final String title;
  final String? notes;
  final DateTime when;
  final int? notificationId;
  final PlannerEntry? plannerEntry;
  final NoticeReminder? noticeReminder;

  const _TimelineItem({
    required this.type,
    required this.id,
    required this.pinKey,
    required this.title,
    required this.when,
    this.notes,
    this.notificationId,
    this.plannerEntry,
    this.noticeReminder,
  });
}

enum _SectionType {
  pinned,
  today,
  upcoming,
  past,
  pending,
  completed,
  archived,
}

enum _TaskFilter { all, today, pending, completed, upcoming, archived }

class _Section {
  final _SectionType type;
  final String title;
  final List<_TimelineItem> items;

  const _Section({
    required this.type,
    required this.title,
    required this.items,
  });
}

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen>
    with WidgetsBindingObserver {
  String? _openingPlannerId;
  final Set<String> _retriedIds = {}; // Track reloads for missing IDs
  final Set<String> _locallyDismissed = <String>{};
  final Map<String, BuildContext> _itemContexts = <String, BuildContext>{};
  final ScrollController _scrollController = ScrollController();
  List<String> _pinKeysInRenderOrder = const <String>[];

  PlannerCategory? _selectedCategory;
  _TaskFilter _selectedTaskFilter = _TaskFilter.all;
  String? _highlightedPlannerId;
  int? _highlightedNoticeId;

  bool _notificationsGranted = true;
  bool _notificationBannerDismissed = false;

  static const int _collapsedItemsLimit = 3;
  final Map<_SectionType, bool> _expandedSections = <_SectionType, bool>{};

  void _toggleTaskFilter(_TaskFilter filter) {
    setState(() {
      _selectedTaskFilter =
          _selectedTaskFilter == filter ? _TaskFilter.all : filter;
      _expandedSections.clear();
    });
  }

  /// Check if a date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Filter timeline items by selected category
  List<_TimelineItem> _filteredTimelineItems(List<_TimelineItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    PlannerCategory categoryFor(_TimelineItem item) {
      if (item.type == _TimelineType.plannerEntry &&
          item.plannerEntry != null) {
        return item.plannerEntry!.category;
      }
      return item.noticeReminder?.category ?? PlannerCategory.deadline;
    }

    bool isArchived(_TimelineItem item) {
      return item.type == _TimelineType.plannerEntry &&
          item.plannerEntry?.isArchived == true;
    }

    bool isCompleted(_TimelineItem item) {
      return item.type == _TimelineType.plannerEntry &&
          item.plannerEntry?.isFullyCompleted == true;
    }

    return items
        .where((item) {
          // Category filter applies to both tasks and notices.
          if (_selectedCategory != null &&
              categoryFor(item) != _selectedCategory) {
            return false;
          }

          // Archived filter is task-only.
          if (_selectedTaskFilter == _TaskFilter.archived) {
            return isArchived(item);
          }

          // Otherwise, hide archived tasks.
          if (isArchived(item)) return false;

          final itemDay = dateOnly(item.when);

          switch (_selectedTaskFilter) {
            case _TaskFilter.all:
              return true;
            case _TaskFilter.today:
              return itemDay == today;
            case _TaskFilter.pending:
              // Notices are always pending (no completion state).
              return !isCompleted(item);
            case _TaskFilter.completed:
              // Completed is task-only.
              return isCompleted(item);
            case _TaskFilter.upcoming:
              return itemDay.isAfter(today);
            case _TaskFilter.archived:
              return false;
          }
        })
        .toList(growable: false);
  }

  Future<void> _scrollToItem(String pinKey) async {
    // In a SliverList, off-screen children are not built, so we may not have a
    // context yet. We do a best-effort two-step:
    // 1) if built -> ensureVisible
    // 2) else -> approximate scroll based on render order, then ensureVisible.

    for (var attempt = 0; attempt < 4; attempt++) {
      // Give the slivers a chance to rebuild after filter/expand changes.
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;

      final ctx = _itemContexts[pinKey];
      final element = ctx is Element ? ctx : null;
      if (element != null && element.mounted) {
        try {
          await Scrollable.ensureVisible(
            element,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.2,
          );
        } catch (_) {
          // Best effort; avoid crashing if the element disappeared mid-scroll.
        }
        return;
      }

      if (!_scrollController.hasClients || _pinKeysInRenderOrder.isEmpty) {
        continue;
      }

      final idx = _pinKeysInRenderOrder.indexOf(pinKey);
      if (idx < 0) {
        continue;
      }

      final denom = (_pinKeysInRenderOrder.length - 1);
      final t = denom <= 0 ? 0.0 : (idx / denom).clamp(0.0, 1.0);
      final max = _scrollController.position.maxScrollExtent;
      final target = (max * t).clamp(0.0, max);

      try {
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut,
        );
      } catch (_) {
        // Ignore if scroll position is not ready.
      }
    }
  }

  _SectionType _sectionTypeForFilter() {
    return switch (_selectedTaskFilter) {
      _TaskFilter.today => _SectionType.today,
      _TaskFilter.upcoming => _SectionType.upcoming,
      _TaskFilter.pending => _SectionType.pending,
      _TaskFilter.completed => _SectionType.completed,
      _TaskFilter.archived => _SectionType.archived,
      _TaskFilter.all => _SectionType.today,
    };
  }

  String _titleForFilter() {
    return switch (_selectedTaskFilter) {
      _TaskFilter.today => 'Today',
      _TaskFilter.pending => 'Pending',
      _TaskFilter.completed => 'Completed',
      _TaskFilter.upcoming => 'Upcoming',
      _TaskFilter.archived => 'Archived',
      _TaskFilter.all => 'Planner',
    };
  }

  List<_Section> _buildSectionsForSelectedFilter(
    List<_TimelineItem> items,
    Set<String> pins,
  ) {
    if (_selectedTaskFilter == _TaskFilter.all ||
        _selectedTaskFilter == _TaskFilter.archived) {
      return _buildSections(items, pins);
    }

    final pinned = <_TimelineItem>[];
    final others = <_TimelineItem>[];

    for (final it in items) {
      if (pins.contains(it.pinKey)) {
        pinned.add(it);
      } else {
        others.add(it);
      }
    }

    pinned.sort((a, b) => a.when.compareTo(b.when));
    others.sort((a, b) => a.when.compareTo(b.when));

    final sections = <_Section>[];
    if (pinned.isNotEmpty) {
      sections.add(
        _Section(type: _SectionType.pinned, title: 'Pinned', items: pinned),
      );
    }
    if (others.isNotEmpty) {
      sections.add(
        _Section(
          type: _sectionTypeForFilter(),
          title: _titleForFilter(),
          items: others,
        ),
      );
    }
    return sections;
  }

  // Scroll to and highlight a specific item
  void _tryHighlightNotice(int noticeId) {
    // If we're already highlighting this ID, do nothing
    if (_highlightedNoticeId == noticeId) return;

    setState(() {
      _highlightedNoticeId = noticeId;
      // Clear any filters so the item is visible
      _selectedTaskFilter = _TaskFilter.all;
      _selectedCategory = null;
      // Expand all sections to ensure the notice is visible
      for (final sectionType in _SectionType.values) {
        _expandedSections[sectionType] = true;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToItem('notice:$noticeId');
    });

    // Clear the pending ID so we don't re-trigger on next build
    ref.read(pushPlannerNavigationProvider.notifier).clear();

    // Remove highlight after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _highlightedNoticeId == noticeId) {
        setState(() {
          _highlightedNoticeId = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // Register lifecycle observer to detect app resume from background
    WidgetsBinding.instance.addObserver(this);

    // Register callback for foreground notification snooze to refresh UI
    LocalNotificationsService().onForegroundSnoozeComplete =
        _onForegroundSnooze;

    // Check notification permission status
    _checkNotificationPermission();

    // Check for any pending open request on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navState = ref.read(pushPlannerNavigationProvider);
      if (navState.plannerId != null) {
        _tryOpenPendingPlanner(navState.plannerId!);
      } else if (navState.noticeId != null) {
        _tryHighlightNotice(navState.noticeId!);
      }
    });
  }

  Future<void> _checkNotificationPermission() async {
    await LocalNotificationsService().initialize();
    final plugin = LocalNotificationsService().plugin;

    bool granted = true;
    if (Platform.isIOS) {
      final ios =
          plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      if (ios != null) {
        final perms = await ios.checkPermissions();
        granted = perms?.isEnabled ?? false;
      }
    } else if (Platform.isAndroid) {
      final android =
          plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android != null) {
        final ok = await android.areNotificationsEnabled();
        granted = ok ?? true;
      }
    }

    if (mounted && granted != _notificationsGranted) {
      setState(() => _notificationsGranted = granted);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check notification permission (user may have changed it in Settings)
      _checkNotificationPermission();

      // App came back to foreground - refresh data to catch any background snoozes
      // Add delay to ensure background notification handlers have completed
      // (iOS background handlers run async and may not finish before resume triggers)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        ref.read(plannerProvider.notifier).load();
        ref.invalidate(noticeRemindersProvider);
      });
    }
  }

  void _onForegroundSnooze(String type) {
    if (!mounted) return;
    // debugPrint('[PlannerScreen] Foreground snooze callback: $type');
    if (type == 'planner') {
      // Force reload from repository
      ref.read(plannerProvider.notifier).load();
    } else if (type == 'notice') {
      // noticeRemindersProvider is a FutureProvider, use invalidate+refresh
      ref.invalidate(noticeRemindersProvider);
      // Trigger a refresh to reload immediately (ignore return value)
      // ignore: unused_result
      ref.refresh(noticeRemindersProvider);
    }
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Clean up callback
    LocalNotificationsService().onForegroundSnoozeComplete = null;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for pending open requests (e.g. from notifications)
    // Listen for pending open requests (e.g. from notifications)
    ref.listen<PushPlannerNavState>(pushPlannerNavigationProvider, (_, next) {
      if (next.plannerId != null) {
        _tryOpenPendingPlanner(next.plannerId!);
      } else if (next.noticeId != null) {
        _tryHighlightNotice(next.noticeId!);
      }
    });

    // Listen for planner state changes (e.g. data loaded)
    // Listen for planner state changes (e.g. data loaded)
    ref.listen(plannerProvider, (_, __) {
      final navState = ref.read(pushPlannerNavigationProvider);
      if (navState.plannerId != null) {
        _tryOpenPendingPlanner(navState.plannerId!);
      }
    });

    final state = ref.watch(plannerProvider);
    final theme = Theme.of(context);
    final noticeRemindersAsync = ref.watch(noticeRemindersProvider);
    final noticeReminders = noticeRemindersAsync.valueOrNull ?? const [];
    final pins = ref.watch(plannerPinsProvider);

    final archivedCount = state.entries.where((e) => e.isArchived).length;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    final timelineItems = <_TimelineItem>[
      ...state.entries.map(
        (e) => _TimelineItem(
          type: _TimelineType.plannerEntry,
          id: e.id,
          pinKey: 'planner:${e.id}',
          title: e.title,
          notes: e.notes.trim().isEmpty ? null : e.notes.trim(),
          when: e.dateTime,
          notificationId: e.notificationId,
          plannerEntry: e,
        ),
      ),
      ...noticeReminders.map(
        (r) => _TimelineItem(
          type: _TimelineType.noticeReminder,
          id: r.newsId.toString(),
          pinKey: 'notice:${r.newsId}',
          title: r.noticeTitle,
          when:
              r.effectiveReminderTime, // Fix: Use effectiveReminderTime so indicator shows up
          notificationId: r.notificationId,
          noticeReminder: r,
        ),
      ),
    ];

    if (_locallyDismissed.isNotEmpty) {
      final existingKeys = timelineItems.map((e) => e.pinKey).toSet();
      _locallyDismissed.removeWhere((k) => !existingKeys.contains(k));
    }

    final visibleTimelineItems = timelineItems
        .where((it) => !_locallyDismissed.contains(it.pinKey))
        .toList(growable: false);

    // Prune cached contexts for items that are no longer visible.
    final visibleKeys = visibleTimelineItems.map((e) => e.pinKey).toSet();
    _itemContexts.removeWhere((k, _) => !visibleKeys.contains(k));

    // Keep a best-effort stable ordering so notification scroll can approximate
    // where an off-screen item likely is.
    final filteredForRender = _filteredTimelineItems(visibleTimelineItems);
    final sectionsForRender = _buildSectionsForSelectedFilter(
      filteredForRender,
      pins,
    );
    _pinKeysInRenderOrder = sectionsForRender
        .expand((s) => s.items.map((it) => it.pinKey))
        .toList(growable: false);

    // Calculate stats for header (tasks + notices; archived is task-only)
    final visibleActiveTasks = visibleTimelineItems
        .where(
          (it) =>
              it.type == _TimelineType.plannerEntry &&
              it.plannerEntry != null &&
              it.plannerEntry!.isArchived == false,
        )
        .map((it) => it.plannerEntry!)
        .toList(growable: false);

    final visibleNotices = visibleTimelineItems
        .where(
          (it) =>
              it.type == _TimelineType.noticeReminder &&
              it.noticeReminder != null,
        )
        .map((it) => it.noticeReminder!)
        .toList(growable: false);

    final completedEntries =
        visibleActiveTasks.where((e) => e.isFullyCompleted).length;
    final todayCount =
        visibleActiveTasks.where((e) => _isToday(e.dateTime)).length +
        visibleNotices.where((r) => _isToday(r.scheduledAt)).length;
    final pendingCount =
        visibleActiveTasks.where((e) => !e.isFullyCompleted).length +
        visibleNotices.length;
    final upcomingCount =
        visibleActiveTasks
            .where((e) => dateOnly(e.dateTime).isAfter(todayDate))
            .length +
        visibleNotices
            .where((r) => dateOnly(r.scheduledAt).isAfter(todayDate))
            .length;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PlannerEditScreen()));
          ref.read(plannerProvider.notifier).load();
          ref.invalidate(noticeRemindersProvider);
        },
        backgroundColor: theme.colorScheme.primary,
        elevation: 6,
        hoverElevation: 8,
        focusElevation: 8,
        highlightElevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate to force a fresh load from repository
          ref.invalidate(plannerProvider);
          // Wait for the new state to be loaded (PlannerNotifier loads in constructor)
          // We can also await the load implicitly if we read the future, but invalidation is cleaner.
          // To keep the spinner showing, we can await a manual load or just wait a bit.
          // Using manual load ensures we wait for completion.
          await ref.read(plannerProvider.notifier).load();
          ref.invalidate(noticeRemindersProvider);
        },
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              titleSpacing: 16,
              title: Row(
                children: [
                  SvgPicture.asset(
                    'assets/images/icons/logo.svg',
                    height: 22,
                    width: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Planner',
                      style: AppConfig.headerTitleTextStyle(theme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.bar_chart_rounded),
                  color: Colors.white,
                  tooltip: 'Report & Analysis',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlannerReportScreen(),
                      ),
                    );
                  },
                ),
                const IconTheme(
                  data: IconThemeData(color: Colors.white),
                  child: ThemeToggleAction(),
                ),
              ],
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),

            // Enhanced Task Summary Dashboard
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 112,
                        child: _DashboardCard(
                          icon: Icons.today_rounded,
                          label: 'Today',
                          value: '$todayCount',
                          color: const Color(0xFF3B82F6),
                          isSelected: _selectedTaskFilter == _TaskFilter.today,
                          onTap: () => _toggleTaskFilter(_TaskFilter.today),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 112,
                        child: _DashboardCard(
                          icon: Icons.pending_actions_rounded,
                          label: 'Pending',
                          value: '$pendingCount',
                          color: const Color(0xFFF59E0B),
                          isSelected:
                              _selectedTaskFilter == _TaskFilter.pending,
                          onTap: () => _toggleTaskFilter(_TaskFilter.pending),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 112,
                        child: _DashboardCard(
                          icon: Icons.task_alt,
                          label: 'Completed',
                          value: '$completedEntries',
                          color: const Color(0xFF22C55E),
                          isSelected:
                              _selectedTaskFilter == _TaskFilter.completed,
                          onTap: () => _toggleTaskFilter(_TaskFilter.completed),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 112,
                        child: _DashboardCard(
                          icon: Icons.upcoming_rounded,
                          label: 'Upcoming',
                          value: '$upcomingCount',
                          color: const Color(0xFF8B5CF6),
                          isSelected:
                              _selectedTaskFilter == _TaskFilter.upcoming,
                          onTap: () => _toggleTaskFilter(_TaskFilter.upcoming),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 90,
                        child: _DashboardCard(
                          icon: Icons.archive_outlined,
                          label: 'Archived',
                          value: '$archivedCount',
                          color: const Color(0xFF6366F1),
                          isSelected:
                              _selectedTaskFilter == _TaskFilter.archived,
                          onTap: () => _toggleTaskFilter(_TaskFilter.archived),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Category Filter Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _AllCategoryChip(
                        isSelected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: 8),
                      for (final cat in PlannerCategory.values) ...[
                        CategoryChip(
                          category: cat,
                          isSelected: _selectedCategory == cat,
                          onTap: () => setState(() => _selectedCategory = cat),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlannerSearchScreen(),
                      ),
                    );
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(
                            alpha:
                                theme.brightness == Brightness.dark
                                    ? 0.35
                                    : 1.0,
                          ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Search entries...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Notification permission banner
            if (!_notificationsGranted && !_notificationBannerDismissed)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Material(
                    color: Colors.orange.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.orange.shade300, width: 1),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        // Open app settings so user can enable notifications
                        await openAppSettings();
                        // State update will happen in didChangeAppLifecycleState when user returns
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_off_rounded,
                              color: Colors.deepOrange,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Notifications are disabled. Tap to open Settings and enable them.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.brown.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(
                                  () => _notificationBannerDismissed = true,
                                );
                              },
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.brown.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ShimmerLoading(),
              )
            else if (state.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppErrorWidget(
                  message: state.error!,
                  onRetry: () => ref.read(plannerProvider.notifier).load(),
                ),
              )
            else if (_filteredTimelineItems(visibleTimelineItems).isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_note,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedTaskFilter == _TaskFilter.archived
                              ? 'No archived entries'
                              : _selectedTaskFilter != _TaskFilter.all
                              ? 'No ${_titleForFilter().toLowerCase()} entries'
                              : _selectedCategory != null
                              ? 'No ${_selectedCategory!.label} entries'
                              : 'No planner entries yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first task.\nTrack exams, deadlines, and important dates.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              for (final section in _buildSectionsForSelectedFilter(
                _filteredTimelineItems(visibleTimelineItems),
                pins,
              ))
                ..._buildSectionSlivers(section, theme, pins),
            ],

            // Ensure there is enough scroll extent to collapse the SliverAppBar
            // even when the content is short (or in loading/empty/error states).
            const SliverToBoxAdapter(child: SizedBox(height: 300)),
          ],
        ),
      ),
    );
  }

  List<_Section> _buildSections(List<_TimelineItem> items, Set<String> pins) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    int typeOrder(_TimelineType t) => t == _TimelineType.plannerEntry ? 0 : 1;

    final pinned = <_TimelineItem>[];
    final todayItems = <_TimelineItem>[];
    final upcoming = <_TimelineItem>[];
    final past = <_TimelineItem>[];
    final archived = <_TimelineItem>[];

    for (final it in items) {
      // Check if this is an archived planner entry
      if (it.type == _TimelineType.plannerEntry &&
          it.plannerEntry?.isArchived == true) {
        archived.add(it);
        continue;
      }

      if (pins.contains(it.pinKey)) {
        pinned.add(it);
        continue;
      }

      final day = dateOnly(it.when);
      if (day == today) {
        todayItems.add(it);
      } else if (day.isAfter(today)) {
        upcoming.add(it);
      } else {
        past.add(it);
      }
    }

    int cmp(_TimelineItem a, _TimelineItem b) {
      final c = a.when.compareTo(b.when);
      if (c != 0) return c;
      return typeOrder(a.type).compareTo(typeOrder(b.type));
    }

    pinned.sort(cmp);
    todayItems.sort(cmp);
    upcoming.sort(cmp);
    past.sort((a, b) {
      final c = b.when.compareTo(a.when);
      if (c != 0) return c;
      return typeOrder(a.type).compareTo(typeOrder(b.type));
    });
    archived.sort((a, b) {
      final c = b.when.compareTo(a.when);
      if (c != 0) return c;
      return typeOrder(a.type).compareTo(typeOrder(b.type));
    });

    final sections = <_Section>[];
    if (pinned.isNotEmpty) {
      sections.add(
        _Section(type: _SectionType.pinned, title: 'Pinned', items: pinned),
      );
    }
    if (todayItems.isNotEmpty) {
      sections.add(
        _Section(type: _SectionType.today, title: 'Today', items: todayItems),
      );
    }
    if (upcoming.isNotEmpty) {
      sections.add(
        _Section(
          type: _SectionType.upcoming,
          title: 'Upcoming',
          items: upcoming,
        ),
      );
    }
    if (past.isNotEmpty) {
      sections.add(
        _Section(type: _SectionType.past, title: 'Earlier', items: past),
      );
    }
    if (archived.isNotEmpty) {
      sections.add(
        _Section(
          type: _SectionType.archived,
          title: 'Archived',
          items: archived,
        ),
      );
    }
    return sections;
  }

  List<Widget> _buildSectionSlivers(
    _Section section,
    ThemeData theme,
    Set<String> pins,
  ) {
    final isExpanded = _expandedSections[section.type] ?? false;
    final canExpand = section.items.length > _collapsedItemsLimit;
    final visibleCount =
        isExpanded
            ? section.items.length
            : math.min(section.items.length, _collapsedItemsLimit);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${section.items.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (canExpand)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _expandedSections[section.type] = !isExpanded;
                    });
                  },
                  child: Text(isExpanded ? 'View less' : 'View all'),
                ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = section.items[index];

          // Use enhanced card for planner entries
          if (item.type == _TimelineType.plannerEntry &&
              item.plannerEntry != null) {
            return Builder(
              builder: (ctx) {
                _itemContexts[item.pinKey] = ctx;
                return PlannerCard(
                  key: ValueKey(
                    '${item.plannerEntry!.id}_${item.plannerEntry!.reminderAt?.millisecondsSinceEpoch ?? 0}',
                  ),
                  entry: item.plannerEntry!,
                  isPinned: pins.contains(item.pinKey),
                  isHighlighted: _highlightedPlannerId == item.plannerEntry!.id,
                  onTap: () => _openItem(item),
                  onTogglePin: () => _togglePin(item.pinKey),
                  onToggleComplete: () => _toggleComplete(item.plannerEntry!),
                  onToggleArchive: () => _toggleArchive(item.plannerEntry!),
                  onDelete: () => _dismissAndDeleteItem(item),
                  onSnooze:
                      (minutes) => _snoozeEntry(item.plannerEntry!, minutes),
                );
              },
            );
          }

          // Fallback to simpler tile for notice reminders
          return Builder(
            builder: (ctx) {
              _itemContexts[item.pinKey] = ctx;
              return _NoticeReminderTile(
                key: ValueKey(
                  'notice_reminder_${item.id}_${item.when.millisecondsSinceEpoch}',
                ),
                item: item,
                isPinned: pins.contains(item.pinKey),
                isHighlighted:
                    _highlightedNoticeId == item.noticeReminder?.newsId,
                onTogglePin: () => _togglePin(item.pinKey),
                onDelete: () => _dismissAndDeleteItem(item),
                onOpen: () => _openItem(item),
                onSnooze:
                    item.noticeReminder != null
                        ? (minutes) =>
                            _snoozeNoticeReminder(item.noticeReminder!, minutes)
                        : null,
              );
            },
          );
        }, childCount: visibleCount),
      ),
    ];
  }

  Future<void> _togglePin(String pinKey) async {
    final nowPinned = await ref
        .read(plannerPinsProvider.notifier)
        .toggle(pinKey);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(nowPinned ? 'Pinned' : 'Unpinned')));
  }

  Future<void> _toggleComplete(PlannerEntry entry) async {
    await ref.read(plannerProvider.notifier).toggleCompletion(entry.id);
  }

  Future<void> _toggleArchive(PlannerEntry entry) async {
    await ref.read(plannerProvider.notifier).toggleArchive(entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(entry.isArchived ? 'Unarchived' : 'Archived')),
    );
  }

  Future<void> _snoozeEntry(PlannerEntry entry, int minutes) async {
    // Use the unified snooze method to ensure consistent behavior
    // with notification-based snooze
    final success = await LocalNotificationsService().snoozePlannerEntry(
      plannerId: entry.id,
      minutes: minutes,
      existingNotificationId: entry.notificationId,
    );

    // Force provider reload to update UI
    ref.invalidate(plannerProvider);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Snoozed for $minutes minutes')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to snooze')));
    }
  }

  Future<void> _deleteItem(_TimelineItem item) async {
    if (item.notificationId != null) {
      await LocalNotificationsService().cancel(item.notificationId!);
    }

    if (item.type == _TimelineType.plannerEntry) {
      await ref.read(plannerProvider.notifier).delete(item.id);
      return;
    }

    final newsId = int.tryParse(item.id);
    if (newsId != null) {
      await _removeNoticeReminder(newsId);
    }
  }

  Future<void> _dismissAndDeleteItem(_TimelineItem item) async {
    if (_locallyDismissed.contains(item.pinKey)) return;

    setState(() {
      _locallyDismissed.add(item.pinKey);
    });

    try {
      await _deleteItem(item);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locallyDismissed.remove(item.pinKey);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _openItem(_TimelineItem item) async {
    if (item.type == _TimelineType.plannerEntry) {
      final match = ref
          .read(plannerProvider)
          .entries
          .where((e) => e.id == item.id);
      final entry = match.isEmpty ? null : match.first;
      if (entry == null) return;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlannerEditScreen(existing: entry)),
      );
      ref.read(plannerProvider.notifier).load();
      ref.invalidate(noticeRemindersProvider);
      return;
    }

    final newsId = int.tryParse(item.id);
    if (newsId == null) return;

    const ordersTabIndex = 0;
    final visited = ref.read(visitedTabsProvider);
    ref.read(visitedTabsProvider.notifier).state = {...visited, ordersTabIndex};
    ref.read(homeTabIndexProvider.notifier).state = ordersTabIndex;
  }

  Future<void> _removeNoticeReminder(int newsId) async {
    final repo = ref.read(noticeReminderRepositoryProvider);
    final existing = await repo.getByNewsId(newsId);
    if (existing != null) {
      await LocalNotificationsService().cancel(existing.notificationId);
      await repo.deleteByNewsId(newsId);
      ref.invalidate(noticeRemindersProvider);
    }
  }

  Future<void> _snoozeNoticeReminder(
    NoticeReminder reminder,
    int minutes,
  ) async {
    final now = DateTime.now();
    final snoozeTime = now.add(Duration(minutes: minutes));
    final cleanSnoozeTime = DateTime(
      snoozeTime.year,
      snoozeTime.month,
      snoozeTime.day,
      snoozeTime.hour,
      snoozeTime.minute,
    );

    // Cancel old notification
    await LocalNotificationsService().cancel(reminder.notificationId);

    // Generate new notification ID
    final newNotificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      1 << 31,
    );

    // Schedule new notification
    try {
      final ok = await LocalNotificationsService().requestPermissions();
      if (ok) {
        await LocalNotificationsService().scheduleReminder(
          notificationId: newNotificationId,
          title: 'Notice reminder',
          body: reminder.noticeTitle,
          scheduledAt: cleanSnoozeTime,
          payload: 'type=notice&news_id=${reminder.newsId}',
        );
      }
    } catch (e) {
      debugPrint('Error scheduling notice snooze notification: $e');
    }

    // Update the reminder - only change reminderAt, keep original scheduledAt
    final updated = reminder.copyWith(
      reminderAt: cleanSnoozeTime,
      notificationId: newNotificationId,
    );

    // Save updated reminder
    final repo = ref.read(noticeReminderRepositoryProvider);
    await repo.upsert(updated);
    ref.invalidate(noticeRemindersProvider);

    if (!mounted) return;

    // Clear any stale highlight state to prevent spurious highlighting
    if (_highlightedNoticeId != null) {
      setState(() {
        _highlightedNoticeId = null;
      });
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Snoozed for $minutes minutes')));
  }

  Future<void> _tryOpenPendingPlanner(String id) async {
    if (!mounted) return;

    if (_openingPlannerId == id) return;
    _openingPlannerId = id;

    final state = ref.read(plannerProvider);

    if (state.isLoading) {
      _openingPlannerId = null;
      return;
    }

    if (state.error != null) {
      ref.read(plannerProvider.notifier).load();
      _openingPlannerId = null;
      return;
    }

    final match = state.entries.where((e) => e.id == id).toList();
    if (match.isEmpty) {
      // If not found, and not loading, and haven't retried yet, force reload.
      // This handles the case where the notification arrives, background updated DB,
      // but UI provider still has stale data.
      if (!state.isLoading && !_retriedIds.contains(id)) {
        _retriedIds.add(id);
        ref.read(plannerProvider.notifier).load();
        _openingPlannerId = null;
        return; // Keep pending ID for next load
      }

      // If we reach here, retries failed or item truly gone
      ref.read(pushPlannerNavigationProvider.notifier).clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Planner entry not found.')),
        );
      }
      _openingPlannerId = null;
      return;
    }

    ref.read(pendingPlannerOpenIdProvider.notifier).state = null;
    ref
        .read(pushPlannerNavigationProvider.notifier)
        .clear(); // Fix: Clear the request so it doesn't re-trigger

    // Add a small delay to allow tab switching animation / list rendering to complete
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // Highlight the card instead of opening edit screen
    setState(() {
      _highlightedPlannerId = id;
      // Clear any filters so the item is visible
      _selectedTaskFilter = _TaskFilter.all;
      _selectedCategory = null;
      // Expand all sections to avoid the item being hidden behind "View less"
      for (final sectionType in _SectionType.values) {
        _expandedSections[sectionType] = true;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToItem('planner:$id');
    });

    // Auto-clear highlight after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _highlightedPlannerId == id) {
        setState(() {
          _highlightedPlannerId = null;
        });
      }
    });

    _openingPlannerId = null;
  }

  // Helper to find key in the tree - simplistic approach,
  // relying on the fact that keys are used in the ListView.
  // In a real large list, we might need an ItemScrollController.
  // For now, let's assume standard scrolling works if item is rendered.
}

/// Simpler tile for notice reminders (keeps original style)
class _NoticeReminderTile extends StatefulWidget {
  final _TimelineItem item;
  final bool isPinned;
  final bool isHighlighted;
  final VoidCallback onTogglePin;
  final Future<void> Function() onDelete;
  final Future<void> Function() onOpen;
  final Future<void> Function(int minutes)? onSnooze;

  const _NoticeReminderTile({
    super.key,
    required this.item,
    required this.isPinned,
    this.isHighlighted = false,
    required this.onTogglePin,
    required this.onDelete,
    required this.onOpen,
    this.onSnooze,
  });

  @override
  State<_NoticeReminderTile> createState() => _NoticeReminderTileState();
}

class _NoticeReminderTileState extends State<_NoticeReminderTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.isHighlighted) {
      _glowController.repeat();
    }

    // Periodic timer to refresh snooze countdown every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant _NoticeReminderTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isHighlighted) {
      if (!_glowController.isAnimating) {
        _glowController.repeat();
      }
    } else {
      if (_glowController.isAnimating) {
        _glowController.stop();
      }
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  String? _getReminderText(DateTime scheduledAt) {
    final now = DateTime.now();
    if (scheduledAt.isBefore(now)) return null;

    final diff = scheduledAt.difference(now);
    if (diff.inMinutes < 1) return '(in <1m)';
    if (diff.inMinutes < 60) return '(in ${diff.inMinutes}m)';
    if (diff.inHours < 24) {
      final m = diff.inMinutes % 60;
      if (m == 0) return '(in ${diff.inHours}h)';
      return '(in ${diff.inHours}h ${m}m)';
    }
    return '(in ${diff.inDays}d)';
  }

  Future<void> _showSnoozeDialog(BuildContext context) async {
    final snoozeMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Snooze for',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('1 minute'),
                  onTap: () => Navigator.of(context).pop(1),
                ),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('2 minutes'),
                  onTap: () => Navigator.of(context).pop(2),
                ),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('5 minutes'),
                  onTap: () => Navigator.of(context).pop(5),
                ),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('15 minutes'),
                  onTap: () => Navigator.of(context).pop(15),
                ),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('30 minutes'),
                  onTap: () => Navigator.of(context).pop(30),
                ),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('1 hour'),
                  onTap: () => Navigator.of(context).pop(60),
                ),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('2 hours'),
                  onTap: () => Navigator.of(context).pop(120),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (snoozeMinutes != null && widget.onSnooze != null) {
      await widget.onSnooze!(snoozeMinutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final notice = widget.item.noticeReminder;
    final priority = notice?.priority ?? PlannerPriority.medium;
    final category = notice?.category ?? PlannerCategory.deadline;

    final priorityColor = Color(priority.colorValue);
    final categoryColor = Color(category.colorValue);

    final isSnoozedActive =
        widget.item.noticeReminder?.reminderAt != null &&
        widget.item.when.isAfter(now);
    final snoozeColor =
        isSnoozedActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.5);

    final isDark = theme.brightness == Brightness.dark;
    final baseBg =
        isDark
            ? categoryColor.withValues(alpha: 0.15)
            : categoryColor.withValues(alpha: 0.08);
    final cardBgColor = Color.alphaBlend(baseBg, theme.colorScheme.surface);

    final isOverdue = widget.item.when.isBefore(now);
    final isToday =
        widget.item.when.year == now.year &&
        widget.item.when.month == now.month &&
        widget.item.when.day == now.day;

    final timeText = DateFormat('h:mm a').format(widget.item.when);
    final dateText = _formatTimelineDate(widget.item.when, isToday);

    final leftBorderColor = categoryColor;

    return Dismissible(
      key: ValueKey(
        '${widget.item.pinKey}_${widget.item.when.millisecondsSinceEpoch}',
      ),
      direction: DismissDirection.horizontal,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Delete?'),
                    content: const Text(
                      'This will cancel the scheduled notification for this notice.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        await widget.onDelete();
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: GestureDetector(
          onTap: widget.onOpen,
          onLongPress: widget.onTogglePin,
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return CustomPaint(
                foregroundPainter:
                    widget.isHighlighted
                        ? _GradientBorderPainter(
                          animationValue: _glowController.value,
                          strokeWidth: 3.5,
                          radius: 16,
                        )
                        : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        widget.isHighlighted
                            ? null
                            : Border.all(
                              color: categoryColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                  ),
                  child: child,
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 8,
                      decoration: BoxDecoration(
                        color: leftBorderColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(right: 10, top: 1),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: categoryColor.withValues(alpha: 0.35),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.notifications_active_rounded,
                                size: 13,
                                color: categoryColor,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.item.title.trim().isEmpty
                                    ? '(Untitled)'
                                    : widget.item.title.trim(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.onSnooze != null)
                                  InkWell(
                                    onTap: () => _showSnoozeDialog(context),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Tooltip(
                                      message:
                                          isSnoozedActive
                                              ? 'Reschedule'
                                              : 'Snooze',
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          6,
                                          0,
                                          6,
                                          6,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.snooze_rounded,
                                              size: 18,
                                              color: snoozeColor,
                                            ),
                                            if (_getReminderText(
                                                  widget.item.when,
                                                ) !=
                                                null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                child: Text(
                                                  _getReminderText(
                                                    widget.item.when,
                                                  )!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: snoozeColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                InkWell(
                                  onTap: widget.onTogglePin,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Tooltip(
                                    message: widget.isPinned ? 'Unpin' : 'Pin',
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        6,
                                        0,
                                        6,
                                        6,
                                      ),
                                      child: Icon(
                                        widget.isPinned
                                            ? Icons.push_pin_rounded
                                            : Icons.push_pin_outlined,
                                        size: 18,
                                        color:
                                            widget.isPinned
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    6,
                                    0,
                                    0,
                                    6,
                                  ),
                                  child: Icon(
                                    FontAwesomeIcons.bullhorn,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                priority.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _timelineCategoryIcon(category),
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    category.label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.notifications_active_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            if (notice?.recurrence != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.repeat_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOverdue
                                      ? Icons.warning_amber_rounded
                                      : Icons.schedule_rounded,
                                  size: 13,
                                  color:
                                      isOverdue
                                          ? const Color(0xFFEF4444)
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isToday ? timeText : dateText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isOverdue
                                            ? const Color(0xFFEF4444)
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _timelineCategoryIcon(PlannerCategory category) {
  switch (category) {
    case PlannerCategory.exam:
      return Icons.edit_document;
    case PlannerCategory.deadline:
      return Icons.schedule;
    case PlannerCategory.reminder:
      return Icons.notifications;
    case PlannerCategory.document:
      return Icons.description;
    case PlannerCategory.other:
      return Icons.star;
  }
}

String _formatTimelineDate(DateTime date, bool isToday) {
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final dateOnly = DateTime(date.year, date.month, date.day);

  if (isToday) return 'Today';
  if (dateOnly == yesterday) return 'Yesterday';
  if (dateOnly == tomorrow) return 'Tomorrow';

  final diff = dateOnly.difference(DateTime(now.year, now.month, now.day));
  if (diff.inDays > 0 && diff.inDays <= 6) {
    return DateFormat('EEEE').format(date);
  }

  return DateFormat('MMM d').format(date);
}

class _GradientBorderPainter extends CustomPainter {
  final double animationValue;
  final double strokeWidth;
  final double radius;

  _GradientBorderPainter({
    required this.animationValue,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    const colors = [
      Color(0xFFA855F7),
      Color(0xFF3B82F6),
      Color(0xFF22C55E),
      Color(0xFFEAB308),
      Color(0xFFF97316),
      Color(0xFFEF4444),
      Color(0xFFA855F7),
    ];

    final gradient = SweepGradient(
      colors: colors,
      stops: const [0.0, 0.17, 0.34, 0.51, 0.68, 0.85, 1.0],
      transform: GradientRotation(animationValue * 2 * 3.14159),
    );

    final paint =
        Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    final deflatedParams = strokeWidth / 2;
    final path = Path()..addRRect(rrect.deflate(deflatedParams));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Dashboard card for task summary stats
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor =
        isSelected
            ? (isDark
                ? color.withValues(alpha: 0.25)
                : color.withValues(alpha: 0.15))
            : (isDark
                ? color.withValues(alpha: 0.10)
                : color.withValues(alpha: 0.06));

    final borderColor =
        isSelected
            ? color.withValues(alpha: 0.9)
            : color.withValues(alpha: 0.25);

    // Deep green for the selection tick
    const deepGreen = Color(0xFF16A34A);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                      : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 1.0),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Deep green circular tick in top-right corner when selected
          if (isSelected)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: deepGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllCategoryChip extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _AllCategoryChip({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apps_rounded,
              color: isSelected ? Colors.white : color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'All',
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
