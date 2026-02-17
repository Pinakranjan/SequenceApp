import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/app_navigation.dart';
import 'core/services/firebase_notification_service.dart';
import 'core/services/local_notifications_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/auth_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/auth/landing_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/lock_screen.dart';
import 'presentation/screens/auth/login_credentials_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';

Future<void> main() async {
  // Preserve native splash screen until we're ready
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize Firebase (with error handling for misconfigured projects)
  try {
    await Firebase.initializeApp();
    // Initialize Firebase Notifications after successful Firebase init
    await FirebaseNotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint(
      'Push notifications will not be available. '
      'If on Android, ensure android/app/google-services.json exists. '
      'If on iOS, ensure ios/Runner/GoogleService-Info.plist exists.',
    );
  }

  // Initialize local notifications (no permission prompts here).
  await LocalNotificationsService().initialize();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Remove native splash now that Flutter is ready
  // Remove native splash now that Flutter is ready
  // FlutterNativeSplash.remove(); // Moved to splash_screen.dart

  runApp(const ProviderScope(child: SequenceApp()));
}

/// Main application widget
class SequenceApp extends ConsumerStatefulWidget {
  const SequenceApp({super.key});

  @override
  ConsumerState<SequenceApp> createState() => _SequenceAppState();
}

class _SequenceAppState extends ConsumerState<SequenceApp> {
  Timer? _sessionTimer;
  bool _checkingSession = false;
  late final _AppLifecycleBridge _lifecycleBridge;

  @override
  void initState() {
    super.initState();
    _lifecycleBridge = _AppLifecycleBridge(_onLifecycleChange);
    WidgetsBinding.instance.addObserver(_lifecycleBridge);
    _startSessionWatcher();

    // Process any notification that launched the app, once the navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseNotificationService().processPendingInitialMessage();
      LocalNotificationsService().processPendingInitialPayload();
      _checkSessionAndHandleExpiry();
    });
  }

  void _onLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSessionWatcher();
      _checkSessionAndHandleExpiry();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _sessionTimer?.cancel();
    }
  }

  void _startSessionWatcher() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkSessionAndHandleExpiry();
    });
  }

  Future<void> _checkSessionAndHandleExpiry() async {
    if (_checkingSession) return;

    final authService = ref.read(authServiceProvider);
    if (!authService.isAuthenticated()) return;

    _checkingSession = true;
    try {
      final result = await authService.getUser();
      if (result['success'] == true) {
        return;
      }

      final reason = authService.consumeSessionEndReason();
      final logoutMessage = _messageForSessionEndReason(reason);

      authService.clearSession();

      final navigator = rootNavigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil('/landing', (_) => false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = rootNavigatorKey.currentContext;
          if (context == null) return;
          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.clearSnackBars();
          messenger?.showSnackBar(
            SnackBar(
              content: Text(logoutMessage),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        });
      }
    } catch (_) {
      // Ignore transient connectivity issues.
    } finally {
      _checkingSession = false;
    }
  }

  String _messageForSessionEndReason(String? reason) {
    switch (reason) {
      case 'SESSION_REVOKED':
        return 'You have been logged out because your account was used on another device.';
      case 'REFRESH_TOKEN_EXPIRED':
        return 'Your session expired. Please log in again.';
      case 'DEVICE_MISMATCH':
        return 'This session is not valid for this device. Please log in again.';
      case 'NO_REFRESH_TOKEN':
      case 'SESSION_INVALIDATED':
      default:
        return 'Your session ended. Please log in again.';
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_lifecycleBridge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Sequence',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const _OfflineAwareHomeScreen(),
        '/landing':
            (context) => const _OfflineAwareAuthScreen(child: LandingScreen()),
        '/login':
            (context) => const _OfflineAwareAuthScreen(child: LoginScreen()),
        '/login-credentials':
            (context) =>
                const _OfflineAwareAuthScreen(child: LoginCredentialsScreen()),
        '/register':
            (context) => const _OfflineAwareAuthScreen(child: RegisterScreen()),
        '/forgot-password':
            (context) =>
                const _OfflineAwareAuthScreen(child: ForgotPasswordScreen()),
        '/lock':
            (context) => const _OfflineAwareAuthScreen(child: LockScreen()),
      },
    );
  }
}

class _AppLifecycleBridge extends WidgetsBindingObserver {
  _AppLifecycleBridge(this.onChange);

  final void Function(AppLifecycleState state) onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onChange(state);
  }
}

class _OfflineAwareAuthScreen extends ConsumerWidget {
  const _OfflineAwareAuthScreen({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    const grayscaleMatrix = ColorFilter.matrix(<double>[
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);

    const transparentFilter = ColorFilter.mode(
      Colors.transparent,
      BlendMode.dst,
    );

    return ColorFiltered(
      colorFilter: isOffline ? grayscaleMatrix : transparentFilter,
      child: child,
    );
  }
}

/// Wrapper widget that adds offline indicator to home screen
class _OfflineAwareHomeScreen extends ConsumerWidget {
  const _OfflineAwareHomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    // Grayscale color filter for offline mode
    const grayscaleMatrix = ColorFilter.matrix(<double>[
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);

    const transparentFilter = ColorFilter.mode(
      Colors.transparent,
      BlendMode.dst,
    );

    // Apply grayscale filter when offline, keep HomeScreen as single child
    return ColorFiltered(
      colorFilter: isOffline ? grayscaleMatrix : transparentFilter,
      child: const HomeScreen(),
    );
  }
}
