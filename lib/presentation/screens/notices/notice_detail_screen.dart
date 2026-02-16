import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../core/services/pdf_cache_service.dart';
import '../../../data/models/notice_model.dart';
import '../../../data/models/notice_reminder.dart';
import '../../../data/repositories/notice_reminder_repository.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/notice_reminder_provider.dart';
import '../../widgets/common/theme_toggle_action.dart';
import '../../widgets/notices/notice_reminder_sheet.dart';
import '../../../data/models/planner_enums.dart';

/// Notice detail screen for viewing PDF documents
class NoticeDetailScreen extends ConsumerStatefulWidget {
  final Notice notice;

  const NoticeDetailScreen({super.key, required this.notice});

  @override
  ConsumerState<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends ConsumerState<NoticeDetailScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;

  final PdfCacheService _pdfCache = PdfCacheService();
  late final NoticeReminderRepository _reminderRepo;
  NoticeReminder? _reminder;

  @override
  void initState() {
    super.initState();
    _reminderRepo = ref.read(noticeReminderRepositoryProvider);
    _loadReminder();
    _loadPdf();
  }

  Future<void> _loadReminder() async {
    final r = await _reminderRepo.getByNewsId(widget.notice.newsId);
    if (!mounted) return;
    setState(() {
      _reminder = r;
    });
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final existingLocal = await _pdfCache.getLocalPathIfExists(widget.notice);
      if (existingLocal != null) {
        setState(() {
          _localPath = existingLocal;
          _isLoading = false;
        });
        return;
      }

      final isOffline = ref.read(isOfflineProvider);
      if (isOffline) {
        setState(() {
          _error =
              "You're offline and this PDF hasn't been downloaded yet.\nConnect to the internet and try again.";
          _isLoading = false;
        });
        return;
      }

      final filePath = await _pdfCache.download(widget.notice);

      setState(() {
        _localPath = filePath;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.notice.newsTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppConfig.headerTitleTextStyle(theme),
        ),
        foregroundColor: AppConfig.getHeaderLabelColor(theme.brightness),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        actions: [
          const ThemeToggleAction(),
          IconButton(
            tooltip: 'Reminder',
            icon: Icon(
              _reminder != null
                  ? Icons.notifications_active
                  : Icons.notifications_none,
            ),
            onPressed: _showReminderActions,
          ),
          if (_localPath != null)
            IconButton(icon: const Icon(Icons.share), onPressed: _sharePdf),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar:
          _localPath != null && _totalPages > 0
              ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: theme.colorScheme.surface,
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Page ${_currentPage + 1} of $_totalPages',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading PDF...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_localPath == null) {
      return const Center(child: Text('PDF not available'));
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      fitPolicy: FitPolicy.BOTH,
      onRender: (pages) {
        setState(() {
          _totalPages = pages ?? 0;
        });
      },
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? 0;
        });
      },
      onError: (error) {
        setState(() {
          _error = error.toString();
        });
      },
    );
  }

  Future<void> _sharePdf() async {
    if (_localPath != null) {
      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

      final params = ShareParams(
        text: widget.notice.newsTitle,
        files: [XFile(_localPath!)],
        sharePositionOrigin: origin,
      );

      await SharePlus.instance.share(params);
    }
  }

  Future<void> _showReminderActions() async {
    final isOffline = ref.read(isOfflineProvider);

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(
                  _reminder == null ? 'Set reminder' : 'Change reminder',
                ),
                subtitle:
                    isOffline
                        ? const Text('Works offline (local notification).')
                        : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  await _setReminder(existing: _reminder);
                },
              ),
              if (_reminder != null)
                ListTile(
                  leading: const Icon(Icons.notifications_off),
                  title: const Text('Remove reminder'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _removeReminder();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setReminder({NoticeReminder? existing}) async {
    final settings = await showModalBottomSheet<NoticeReminderSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => NoticeReminderSheet(
            initialDateTime: existing?.scheduledAt,
            initialPriority: existing?.priority ?? PlannerPriority.medium,
            initialCategory: existing?.category ?? PlannerCategory.deadline,
            initialRecurrence: existing?.recurrence,
            initialReminderOffset: existing?.reminderOffset ?? Duration.zero,
          ),
    );

    if (settings == null) return;

    if (settings.scheduledAt.isBefore(DateTime.now()) &&
        settings.recurrence == null) {
      // Allow past dates if recurring? Or just warn.
      // Planner allows past dates. But for a one-time reminder, it shouldn't be in past.
      // Let's keep specific check but maybe loose for just one minute.
    }

    // Ensure notification permission is granted (user initiated).
    // The sheet usually requests it when enabling reminders, but this makes
    // scheduling robust even if permission changes in Settings.
    await LocalNotificationsService().initialize();
    final ok = await LocalNotificationsService().requestPermissions();
    if (!ok) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Notifications are disabled. Enable them in Settings to use reminders.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () async {
              final uri = Uri.parse('app-settings:');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ),
      );
      return;
    }

    // Cancel old reminder if present.
    final old = _reminder;
    if (old != null) {
      await LocalNotificationsService().cancel(old.notificationId);
    }

    final notificationId =
        old?.notificationId ??
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

    // Schedule notification (must be in the future).
    final reminderTime = settings.scheduledAt.subtract(settings.reminderOffset);
    if (!reminderTime.isAfter(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder time must be in the future.')),
      );
      return;
    }

    await LocalNotificationsService().scheduleReminder(
      notificationId: notificationId,
      title: 'Notice reminder',
      body: widget.notice.newsTitle,
      scheduledAt: reminderTime,
      payload: 'type=notice&news_id=${widget.notice.newsId}',
    );

    final reminder = NoticeReminder(
      newsId: widget.notice.newsId,
      noticeTitle: widget.notice.newsTitle,
      scheduledAt: settings.scheduledAt,
      notificationId: notificationId,
      createdAt: old?.createdAt ?? DateTime.now(),
      priority: settings.priority,
      category: settings.category,
      recurrence: settings.recurrence,
      reminderOffset: settings.reminderOffset,
    );

    await _reminderRepo.upsert(reminder);

    // Ensure Notices + Planner update immediately.
    ref.invalidate(noticeRemindersProvider);
    ref.invalidate(noticeReminderProvider(widget.notice.newsId));

    if (!mounted) return;
    setState(() {
      _reminder = reminder;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder set for ${DateFormat('MMM d, h:mm a').format(settings.scheduledAt)}',
        ),
      ),
    );
  }

  Future<void> _removeReminder() async {
    final existing = _reminder;
    if (existing == null) return;

    await LocalNotificationsService().cancel(existing.notificationId);
    await _reminderRepo.deleteByNewsId(existing.newsId);

    // Ensure Notices + Planner update immediately.
    ref.invalidate(noticeRemindersProvider);
    ref.invalidate(noticeReminderProvider(widget.notice.newsId));

    if (!mounted) return;
    setState(() {
      _reminder = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reminder removed.')));
  }
}
