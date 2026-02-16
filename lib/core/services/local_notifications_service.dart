import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../providers/home_navigation_provider.dart';
import '../../providers/push_planner_navigation_provider.dart';
import '../constants/app_config.dart';
import 'app_navigation.dart';

import '../../data/repositories/notice_reminder_repository.dart';
import '../../data/repositories/planner_repository.dart';

/// App-wide local notifications service.
///
/// Design goals:
/// - Initialization must not request permissions (App Review: user-initiated).
/// - Scheduling must only happen after a user action.
/// - Payload taps must deep-link into native Flutter screens.

// Action IDs
const String actionSnooze1m = 'snooze_1m';
const String actionSnooze2m = 'snooze_2m';
const String actionSnooze5m = 'snooze_5m';
const String actionSnooze10m = 'snooze_10m';
const String actionSnooze15m = 'snooze_15m';
const String actionSnooze30m = 'snooze_30m';
const String actionSnooze1h = 'snooze_1h';

// iOS Category ID
const String categorySnooze = 'snooze_category';

/// Background notification action handler
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  try {
    // Ensure we can access platform channels (SharedPreferences, Timezone, etc.)
    WidgetsFlutterBinding.ensureInitialized();

    // Handle action buttons in the background
    if (response.actionId != null && response.actionId!.isNotEmpty) {
      final service = LocalNotificationsService();
      // Must initialize timezones for zonedSchedule to work in background isolate
      await service.initForBackground();

      await service._processAction(
        response.actionId!,
        response.payload,
        response.id,
      );
    } else {
      // debugPrint('[Background] Notification tapped: ${response.payload}');
    }
  } catch (e) {
    // debugPrint('[Background] Error handling notification tap: $e\n$stack');
  }
}

class LocalNotificationsService {
  static final LocalNotificationsService _instance =
      LocalNotificationsService._internal();
  factory LocalNotificationsService() => _instance;
  LocalNotificationsService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  String? _initialPayload;
  bool _initialPayloadProcessed = false;

  /// Callback invoked when a snooze action completes in foreground.
  /// UI code can set this to invalidate providers.
  void Function(String type)? onForegroundSnoozeComplete;

  static const String remindersAndroidChannelId = 'ojee_reminders';
  static const String remindersAndroidChannelName = 'Reminders';
  static const String remindersAndroidChannelDescription =
      'Planner and notice reminders';

  static const String pushAndroidChannelId = 'ojee_notices';
  static const String pushAndroidChannelName = 'Notices';
  static const String pushAndroidChannelDescription =
      'OJEE notices and announcements';

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  Future<void> initialize() async {
    if (_initialized) return;

    await _initializeTimezone();

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS: Define snooze actions and category
    // Note: iOS limits actions to 4 per category.
    final snoozeActions = [
      DarwinNotificationAction.plain(actionSnooze1m, 'Snooze 1m'),
      DarwinNotificationAction.plain(actionSnooze5m, 'Snooze 5m'),
      DarwinNotificationAction.plain(actionSnooze15m, 'Snooze 15m'),
      DarwinNotificationAction.plain(actionSnooze1h, 'Snooze 1h'),
    ];

    final initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false, // We request permission on user action
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          categorySnooze,
          actions: snoozeActions,
          options: {DarwinNotificationCategoryOption.hiddenPreviewShowTitle},
        ),
      ],
    );

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: (response) async {
        try {
          // Handle foreground actions
          if (response.actionId != null && response.actionId!.isNotEmpty) {
            final type = await _processAction(
              response.actionId!,
              response.payload,
              response.id,
            );
            // Trigger UI refresh callback for foreground snoozes
            if (type != null && onForegroundSnoozeComplete != null) {
              onForegroundSnoozeComplete!(type);
            }
            return;
          }

          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          _handlePayloadTap(payload);
        } catch (e) {
          // debugPrint(
          //   '[Foreground] Error processing notification tap: $e\n$stack',
          // );
        }
      },
    );

    // Handle cold-start launches from a local notification.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _initialPayload = launchDetails?.notificationResponse?.payload;
    }

    // Android channels (safe no-op on iOS).
    final androidImplementation =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        pushAndroidChannelId,
        pushAndroidChannelName,
        description: pushAndroidChannelDescription,
        importance: Importance.max,
      ),
    );

    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        remindersAndroidChannelId,
        remindersAndroidChannelName,
        description: remindersAndroidChannelDescription,
        importance: Importance.max,
      ),
    );

    _initialized = true;
  }

  /// Call this once after the first frame (when the navigator/context exist)
  /// to process a local-notification launch payload.
  void processPendingInitialPayload() {
    if (_initialPayloadProcessed) return;

    final payload = _initialPayload;
    if (payload == null || payload.isEmpty) {
      _initialPayloadProcessed = true;
      return;
    }

    // If the navigator context isn't ready yet, try again later.
    if (rootNavigatorKey.currentContext == null) {
      return;
    }

    _initialPayloadProcessed = true;
    _handlePayloadTap(payload);
  }

  /// Initialize only what's needed for the background isolate
  Future<void> initForBackground() async {
    // In background isolate (especially iOS Simulator), platform channels
    // might fail. UTC is robust for relative snooze times.
    await _initializeTimezone(forceUtc: true);
  }

  Future<void> _initializeTimezone({bool forceUtc = false}) async {
    try {
      tz_data.initializeTimeZones();

      if (forceUtc) {
        tz.setLocalLocation(tz.UTC);
        return;
      }

      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // debugPrint('Error initializing timezone: $e. Falling back to UTC.');
      try {
        tz.setLocalLocation(tz.UTC);
      } catch (_) {
        // Should not happen
      }
    }
  }

  Future<bool> requestPermissions() async {
    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    final macos =
        _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    bool granted = true;

    if (android != null) {
      final ok = await android.requestNotificationsPermission();
      granted = granted && (ok ?? false);

      // Request exact alarm permission for Android 12+
      final exactAlarmOk = await android.requestExactAlarmsPermission();
      if (exactAlarmOk != null && !exactAlarmOk) {
        // debugPrint('[Notifications] Exact alarm permission denied');
      }
    }

    if (ios != null) {
      final ok = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = granted && (ok ?? false);
    }

    if (macos != null) {
      final ok = await macos.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = granted && (ok ?? false);
    }

    // Android 13+ runtime permission is handled by the plugin internally.
    return granted;
  }

  Future<void> cancel(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  Future<void> cancelMany(Iterable<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  /// Unified snooze logic for planner entries.
  /// This is the single source of truth for snoozing.
  /// Called by both in-app snooze and notification action snooze.
  ///
  /// Returns true if snooze was successful, false otherwise.
  Future<bool> snoozePlannerEntry({
    required String plannerId,
    required int minutes,
    int? existingNotificationId,
  }) async {
    // debugPrint(
    //   '[Snooze] snoozePlannerEntry called for $plannerId, minutes=$minutes',
    // );

    final now = DateTime.now();
    final snoozeTime = now.add(Duration(minutes: minutes));
    // Truncate to minute precision
    final cleanSnoozeTime = DateTime(
      snoozeTime.year,
      snoozeTime.month,
      snoozeTime.day,
      snoozeTime.hour,
      snoozeTime.minute,
    );

    // Cancel existing notification if any
    if (existingNotificationId != null) {
      await cancel(existingNotificationId);
    }

    // Generate new notification ID
    final newNotificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      1 << 31,
    );

    // Fetch fresh entry from database to avoid stale data
    final repo = PlannerRepository();
    final entry = await repo.getById(plannerId);
    if (entry == null) {
      // debugPrint('[Snooze] Entry not found: $plannerId');
      return false;
    }

    // debugPrint(
    //   '[Snooze] Original dateTime: ${entry.dateTime}, Old reminderAt: ${entry.reminderAt}, New reminderAt: $cleanSnoozeTime',
    // );

    // Update entry: ONLY change reminderAt and notificationId, NEVER touch dateTime
    final updated = entry.copyWith(
      reminderAt: cleanSnoozeTime,
      notificationId: newNotificationId,
      updatedAt: DateTime.now(),
    );

    await repo.upsert(updated);

    // Schedule new notification
    try {
      await scheduleReminder(
        notificationId: newNotificationId,
        title: 'Planner reminder',
        body: entry.title.trim(),
        scheduledAt: cleanSnoozeTime,
        payload: 'type=planner&planner_id=$plannerId',
      );
      // debugPrint(
      //   '[Snooze] Notification scheduled: id=$newNotificationId at $cleanSnoozeTime',
      // );
      return true;
    } catch (e) {
      // debugPrint('[Snooze] Error scheduling notification: $e');
      return false;
    }
  }

  Future<void> scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  }) async {
    tz.TZDateTime schedule;
    try {
      // If we are in UTC fallback mode (or actually in UTC), use UTC time explicitly
      // to avoid Face Value mismatch (e.g. 5pm Local != 5pm UTC).
      if (tz.local.name == 'UTC') {
        schedule = tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC);
      } else {
        schedule = tz.TZDateTime.from(scheduledAt, tz.local);
      }
    } catch (_) {
      // Last resort fallback
      schedule = tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC);
    }

    // Android actions
    // Prioritizing most useful durations. Android typically shows 3 max.
    final List<AndroidNotificationAction> androidActions =
        AppConfig.enableNotificationSnoozeActions
            ? const [
              AndroidNotificationAction(
                actionSnooze1m,
                'Snooze 1m',
                showsUserInterface: false,
              ),
              AndroidNotificationAction(
                actionSnooze5m,
                'Snooze 5m',
                showsUserInterface: false,
              ),
              AndroidNotificationAction(
                actionSnooze15m,
                'Snooze 15m',
                showsUserInterface: false,
              ),
              // Adding 1h as 4th action, visible if expanded/supported
              AndroidNotificationAction(
                actionSnooze1h,
                'Snooze 1h',
                showsUserInterface: false,
              ),
            ]
            : [];

    final androidDetails = AndroidNotificationDetails(
      remindersAndroidChannelId,
      remindersAndroidChannelName,
      channelDescription: remindersAndroidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      actions: androidActions,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: categorySnooze,
    );

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      schedule,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    assert(() {
      // debugPrint('[Reminders] scheduled id=$notificationId at=$scheduledAt');
      return true;
    }());
  }

  /// Process action (Snooze) logic
  /// Returns the type of notification that was snoozed ('planner' or 'notice'), or null if failed.
  Future<String?> _processAction(
    String actionId,
    String? payload,
    int? notificationId,
  ) async {
    if (payload == null) return null;

    // debugPrint('[Notifications] Processing action: $actionId');

    int snoozeMinutes = 0;
    switch (actionId) {
      case actionSnooze1m:
        snoozeMinutes = 1;
        break;
      case actionSnooze2m:
        snoozeMinutes = 2;
        break;
      case actionSnooze5m:
        snoozeMinutes = 5;
        break;
      case actionSnooze10m:
        snoozeMinutes = 10;
        break;
      case actionSnooze15m:
        snoozeMinutes = 15;
        break;
      case actionSnooze30m:
        snoozeMinutes = 30;
        break;
      case actionSnooze1h:
        snoozeMinutes = 60;
        break;
      default:
        return null;
    }

    if (snoozeMinutes == 0) return null;

    // Helper to parse payload
    final params = <String, String>{};
    for (final part in payload.split('&')) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      params[kv[0].trim()] = kv[1].trim();
    }

    final type = params['type'];

    if (type == 'planner') {
      final plannerId = params['planner_id'];
      if (plannerId == null) return null;

      // Use the unified snooze method
      await snoozePlannerEntry(
        plannerId: plannerId,
        minutes: snoozeMinutes,
        existingNotificationId: notificationId,
      );
      return 'planner';
    } else if (type == 'notice') {
      final newsId = int.tryParse(params['news_id'] ?? '');
      if (newsId == null) return null;

      // Cancel existing notification
      if (notificationId != null) {
        await cancel(notificationId);
      }

      // Calculate snooze time
      final now = DateTime.now();
      final snoozeTime = now.add(Duration(minutes: snoozeMinutes));
      final cleanSnoozeTime = DateTime(
        snoozeTime.year,
        snoozeTime.month,
        snoozeTime.day,
        snoozeTime.hour,
        snoozeTime.minute,
      );

      // Generate new notification ID
      final newNotificationId = DateTime.now().millisecondsSinceEpoch.remainder(
        1 << 31,
      );

      final repo = NoticeReminderRepository();
      final reminder = await repo.getByNewsId(newsId);
      if (reminder == null) return null;

      final updated = reminder.copyWith(
        reminderAt: cleanSnoozeTime,
        notificationId: newNotificationId,
      );

      await repo.upsert(updated);

      await scheduleReminder(
        notificationId: newNotificationId,
        title: 'Notice reminder',
        body: reminder.noticeTitle,
        scheduledAt: cleanSnoozeTime,
        payload: payload,
      );
      return 'notice';
    } else {
      // Re-schedule generic reminder? Just logging for now
      // debugPrint('[Notifications] Unknown type for snooze: $type');
      return null;
    }
  }

  /// Payload format: simple key-value pairs separated by '&'.
  /// Examples:
  /// - type=notice&news_id=123
  /// - type=planner&planner_id=uuid
  void _handlePayloadTap(String payload) {
    final params = <String, String>{};
    for (final part in payload.split('&')) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      params[kv[0].trim()] = kv[1].trim();
    }

    final type = params['type'];
    if (type == 'notice') {
      final newsId = int.tryParse(params['news_id'] ?? '');
      if (newsId != null) {
        _openNoticesAndNotice(newsId);
      } else {
        _openNoticesTabOnly();
      }
      return;
    }

    if (type == 'planner') {
      final plannerId = params['planner_id'];
      final noticeIdStr = params['notice_id'];
      final noticeId = int.tryParse(noticeIdStr ?? '');
      _openPlanner(plannerId: plannerId, noticeId: noticeId);
      return;
    }

    // debugPrint('[Notifications] Unknown payload type: $payload');
  }

  void _openNoticesTabOnly() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    // Notices tab has been removed; keep behavior safe by opening Orders.
    const ordersTabIndex = 0;
    final visited = container.read(visitedTabsProvider);
    container.read(visitedTabsProvider.notifier).state = {
      ...visited,
      ordersTabIndex,
    };
    container.read(homeTabIndexProvider.notifier).state = ordersTabIndex;
  }

  void _openNoticesAndNotice(int newsId) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    // Notices tab has been removed; keep behavior safe by opening Orders.
    const ordersTabIndex = 0;
    final visited = container.read(visitedTabsProvider);
    container.read(visitedTabsProvider.notifier).state = {
      ...visited,
      ordersTabIndex,
    };
    container.read(homeTabIndexProvider.notifier).state = ordersTabIndex;
  }

  void _openPlanner({String? plannerId, int? noticeId}) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    const plannerTabIndex = 1; // Orders=0, Planner=1
    final visited = container.read(visitedTabsProvider);
    container.read(visitedTabsProvider.notifier).state = {
      ...visited,
      plannerTabIndex,
    };
    container.read(homeTabIndexProvider.notifier).state = plannerTabIndex;

    if (plannerId != null) {
      container
          .read(pushPlannerNavigationProvider.notifier)
          .requestOpen(plannerId);
      // debugPrint('[Notifications] Requested planner detail for id=$plannerId');
    }

    if (noticeId != null) {
      container
          .read(pushPlannerNavigationProvider.notifier)
          .requestOpenNotice(noticeId);
      // debugPrint(
      //   '[Notifications] Requested planner highlight for noticeId=$noticeId',
      // );
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  Push-style (FCM-style) immediate display helper
  // ─────────────────────────────────────────────────────────────────────

  Future<void> showPushNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      pushAndroidChannelId,
      pushAndroidChannelName,
      channelDescription: pushAndroidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );

    assert(() {
      // debugPrint('[Push] shown id=$id');
      return true;
    }());
  }
}
