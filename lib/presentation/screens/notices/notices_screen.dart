import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../providers/notice_provider.dart';
import '../../../providers/notice_reminder_provider.dart';
import '../../../providers/push_notice_navigation_provider.dart';
import '../../../data/models/notice_model.dart';
import '../../widgets/common/shimmer_loading.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/theme_toggle_action.dart';
import '../../widgets/notices/notice_tile.dart';
import 'notice_detail_screen.dart';

/// Notices screen with list of announcements
class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  int? _openingNoticeId;
  int? _pendingNoticeIdLastRefreshed;
  int _pendingNoticeRefreshAttempts = 0;

  @override
  Widget build(BuildContext context) {
    // When a push notification requests opening a specific notice, attempt to
    // open it once notices are available.
    ref.listen<int?>(pendingNoticeOpenIdProvider, (_, next) {
      if (next == null) return;
      _tryOpenPendingNotice(next);
    });

    // Retry opening after notices data changes (e.g., after refresh completes).
    ref.listen(noticesProvider, (_, __) {
      final pendingId = ref.read(pendingNoticeOpenIdProvider);
      if (pendingId != null) {
        _tryOpenPendingNotice(pendingId);
      }
    });

    final noticesState = ref.watch(noticesProvider);
    final theme = Theme.of(context);
    final remindersAsync = ref.watch(noticeRemindersProvider);
    final reminderIds = remindersAsync.maybeWhen(
      data: (list) => list.map((r) => r.newsId).toSet(),
      orElse: () => const <int>{},
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(noticesProvider.notifier).refresh(),
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          primary: true,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: AppConfig.sliverAppBarExpandedHeight,
              pinned: true,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final settings =
                      context
                          .dependOnInheritedWidgetOfExactType<
                            FlexibleSpaceBarSettings
                          >();

                  double t = 1.0;
                  if (settings != null) {
                    final delta = (settings.maxExtent - settings.minExtent);
                    if (delta <= 0) {
                      t = 0.0;
                    } else {
                      t = ((settings.currentExtent - settings.minExtent) /
                              delta)
                          .clamp(0.0, 1.0);
                    }
                  }

                  return FlexibleSpaceBar(
                    expandedTitleScale: 1.0,
                    titlePadding: const EdgeInsets.only(
                      left: 16,
                      right: 0,
                      bottom: 8,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'News & Notices',
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
                          // Top logo (fade out completely when collapsed)
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
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 120),
                                  opacity: t <= 0.01 ? 0.0 : t,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 70,
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/images/icons/logo.svg',
                                      fit: BoxFit.contain,
                                      alignment: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Content
            if (noticesState.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ShimmerLoading(),
              )
            else if (noticesState.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppErrorWidget(
                  message: noticesState.error!,
                  onRetry: () {
                    ref.read(noticesProvider.notifier).refresh();
                  },
                ),
              )
            else if (noticesState.notices.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  title: 'No Notices',
                  subtitle: 'Check back later for updates',
                  icon: Icons.notifications_off_outlined,
                  action: ElevatedButton(
                    onPressed: () {
                      ref.read(noticesProvider.notifier).refresh();
                    },
                    child: const Text('Refresh'),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == noticesState.notices.length) {
                    return const SizedBox(height: 100);
                  }
                  final notice = noticesState.notices[index];
                  return NoticeTile(
                    notice: notice,
                    index: index,
                    hasReminder: reminderIds.contains(notice.newsId),
                    onTap: () => _handleNoticeTap(context, notice),
                  );
                }, childCount: noticesState.notices.length + 1),
              ),

            // Ensure there is enough scroll extent to collapse the SliverAppBar
            // even when there are only a few notices.
            const SliverToBoxAdapter(child: SizedBox(height: 400)),
          ],
        ),
      ),
    );
  }

  Future<void> _tryOpenPendingNotice(int newsId) async {
    if (!mounted) return;

    // Guard against repeated opens while state updates.
    if (_openingNoticeId == newsId) return;
    _openingNoticeId = newsId;

    final state = ref.read(noticesProvider);

    if (state.isLoading) {
      _openingNoticeId = null;
      return;
    }

    if (state.error != null) {
      ref.read(noticesProvider.notifier).refresh();
      _openingNoticeId = null;
      return;
    }

    Notice? target;
    for (final n in state.notices) {
      if (n.newsId == newsId) {
        target = n;
        break;
      }
    }

    if (target == null) {
      // Fetch latest and try again when provider updates.
      // IMPORTANT: avoid infinite refresh loops if the incoming `newsId`
      // doesn't exist anymore (or API is stale).
      if (_pendingNoticeIdLastRefreshed != newsId) {
        _pendingNoticeIdLastRefreshed = newsId;
        _pendingNoticeRefreshAttempts = 0;
      }

      if (_pendingNoticeRefreshAttempts >= 1) {
        // Give up and stop retrying; still keep user on Notices tab.
        ref.read(pendingNoticeOpenIdProvider.notifier).state = null;
        _openingNoticeId = null;
        return;
      }

      _pendingNoticeRefreshAttempts++;
      ref.read(noticesProvider.notifier).refresh();
      _openingNoticeId = null;
      return;
    }

    // Clear pending BEFORE opening to avoid duplicate opens from provider
    // updates while navigation happens.
    ref.read(pendingNoticeOpenIdProvider.notifier).state = null;

    await _handleNoticeTap(context, target);
    _openingNoticeId = null;
  }

  Future<void> _handleNoticeTap(BuildContext context, Notice notice) async {
    switch (notice.type) {
      case NoticeType.text:
        // Show text in bottom sheet
        _showTextNotice(context, notice);
        break;
      case NoticeType.link:
        // Open external link
        if (notice.newsUrl != null) {
          final uri = Uri.parse(notice.newsUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;
      case NoticeType.pdf:
        // Navigate to PDF viewer
        if (notice.newsDoc != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(notice: notice),
            ),
          );

          // The user may have downloaded the PDF in the detail screen.
          // Trigger a rebuild so the offline badge updates immediately.
          if (!mounted) return;
          setState(() {});
        }
        break;
    }
  }

  void _showTextNotice(BuildContext context, Notice notice) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    notice.newsTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      notice.newsText ?? '',
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
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
