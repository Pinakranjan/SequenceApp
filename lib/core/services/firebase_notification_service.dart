import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/home_navigation_provider.dart';
import 'local_notifications_service.dart';
import 'app_navigation.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    if (kDebugMode) {
      print('Handling a background message: ${message.messageId}');
    }
  } catch (e) {
    // If Firebase isn't configured for this build (missing/incorrect
    // GoogleService-Info.plist or google-services.json), don't crash.
    if (kDebugMode) {
      print('Background FCM handler skipped (Firebase not initialized): $e');
    }
  }
}

/// Firebase Notification Service
class FirebaseNotificationService {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin get _localNotifications =>
      LocalNotificationsService().plugin;

  RemoteMessage? _initialMessage;
  bool _initialMessageProcessed = false;

  int _tokenRetryCount = 0;
  static const int _maxTokenRetries = 5;

  static const String _androidChannelId = 'ojee_notices';
  static const String _androidChannelName = 'Notices';
  static const String _androidChannelDescription =
      'OJEE notices and announcements';

  /// Initialize Firebase and request permissions
  Future<void> initialize() async {
    // In widget tests or misconfigured builds, Firebase may not be initialized.
    // Don't crash the app; just skip push setup.
    if (Firebase.apps.isEmpty) {
      if (kDebugMode) {
        print('Firebase not initialized; skipping notifications setup.');
      }
      return;
    }

    _messaging ??= FirebaseMessaging.instance;

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // IMPORTANT (App Review): do not prompt for notification permission on
    // startup. Permission should be requested only after a user action.
    // We still query current status for debug visibility.
    try {
      final settings = await _messaging!.getNotificationSettings();
      if (kDebugMode) {
        debugPrint(
          'Notification settings (no prompt): ${settings.authorizationStatus}',
        );
      }
    } catch (_) {}

    // iOS: allow notifications to be shown while app is in foreground.
    await _messaging!.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Local notifications infra is initialized app-wide without prompting.
    await LocalNotificationsService().initialize();

    // Get FCM token
    await _getToken();

    // iOS: APNs token may not be ready immediately. Retry a few times.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _scheduleTokenRetryIfNeeded();
    }

    // Log refreshed tokens as well (e.g., reinstall, APNs changes, etc.)
    _messaging!.onTokenRefresh.listen((token) {
      if (kDebugMode) {
        debugPrint('FCM registration token (refresh): $token');
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Cache initial message (app launched from a notification). This can be
    // processed once the widget tree + navigator are ready.
    _initialMessage = await _messaging!.getInitialMessage();
  }

  /// Call this after the app navigator is ready (post-first-frame) to handle
  /// the notification that may have launched the app.
  void processPendingInitialMessage() {
    if (_initialMessageProcessed) return;
    _initialMessageProcessed = true;

    final message = _initialMessage;
    if (message != null) {
      _handleNotificationTap(message);
    }
  }

  // Permission prompts are user-initiated elsewhere (Planner/Notice reminders).

  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      final messaging = _messaging;
      if (messaging == null) return null;

      // On iOS, FCM token generation depends on APNs registration.
      // If APNs token isn't ready yet, avoid calling getToken() (it can throw
      // firebase_messaging/apns-token-not-set, and debuggers often break on it).
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              'APNs token not set yet; skipping FCM token for now. '
              'Note: FCM on iOS requires a real device + Push Notifications capability.',
            );
          }
          return null;
        }
      }

      final token = await messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM registration token: $token');
      }
      return token;
    } on FirebaseException catch (e) {
      // Defensive: in case we still hit this on some timing edge.
      if (e.code == 'apns-token-not-set') {
        if (kDebugMode) {
          debugPrint('APNs token not set yet; will retry FCM token shortly.');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('Error getting FCM token: $e');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting FCM token: $e');
      }
      return null;
    }
  }

  void _scheduleTokenRetryIfNeeded() {
    if (_tokenRetryCount >= _maxTokenRetries) return;

    _tokenRetryCount++;
    Future<void>.delayed(const Duration(seconds: 2), () async {
      final token = await _getToken();
      if (token == null) {
        _scheduleTokenRetryIfNeeded();
      }
    });
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Received foreground message: ${message.notification?.title}');
    }

    // Show a local notification so users can tap to open Notices.
    _showForegroundLocalNotification(message);
  }

  /// Handle notification taps
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification tapped: ${message.notification?.title}');
    }

    final newsId = _extractNewsId(message);
    if (newsId == null) {
      // Notices tab has been removed; fall back to Home.
      _openNoticesTabOnly();
      return;
    }

    _openNoticesAndNotice(newsId);
  }

  Future<void> _showForegroundLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'OJEE Notice';
    final body = message.notification?.body ?? '';

    final payload = _buildPayload(message);

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  String _buildPayload(RemoteMessage message) {
    final newsId = _extractNewsId(message);
    // Keep payload format simple (no JSON dependency): key=value pairs.
    // Example: "type=notice&news_id=123".
    if (newsId == null) return '';
    return 'type=notice&news_id=$newsId';
  }

  int? _extractNewsId(RemoteMessage message) {
    final data = message.data;

    dynamic raw =
        data['news_id'] ??
        data['newsId'] ??
        data['notice_id'] ??
        data['noticeId'] ??
        data['id'];

    // Some sends may include the id in notification body/title only.
    if (raw == null) return null;

    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  void _openNoticesTabOnly() {
    final navigator = rootNavigatorKey.currentState;
    navigator?.pushNamedAndRemoveUntil('/home', (route) => false);

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final container = ProviderScope.containerOf(context, listen: false);

    const ordersTabIndex = 0;
    final visited = container.read(visitedTabsProvider);
    container.read(visitedTabsProvider.notifier).state = {
      ...visited,
      ordersTabIndex,
    };
    container.read(homeTabIndexProvider.notifier).state = ordersTabIndex;
  }

  void _openNoticesAndNotice(int newsId) {
    final navigator = rootNavigatorKey.currentState;
    navigator?.pushNamedAndRemoveUntil('/home', (route) => false);

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final container = ProviderScope.containerOf(context, listen: false);

    // Notices tab has been removed; open Home on Orders tab.
    const ordersTabIndex = 0;
    final visited = container.read(visitedTabsProvider);
    container.read(visitedTabsProvider.notifier).state = {
      ...visited,
      ordersTabIndex,
    };
    container.read(homeTabIndexProvider.notifier).state = ordersTabIndex;
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    final messaging = _messaging;
    if (messaging == null) return;

    await messaging.subscribeToTopic(topic);
    if (kDebugMode) {
      print('Subscribed to topic: $topic');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    final messaging = _messaging;
    if (messaging == null) return;

    await messaging.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      print('Unsubscribed from topic: $topic');
    }
  }
}
