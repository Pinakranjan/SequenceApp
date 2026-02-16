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
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/auth/landing_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
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
  @override
  void initState() {
    super.initState();

    // Process any notification that launched the app, once the navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseNotificationService().processPendingInitialMessage();
      LocalNotificationsService().processPendingInitialPayload();
    });
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
        '/landing': (context) => const LandingScreen(),
        '/login': (context) => const LoginScreen(),
        '/login-credentials': (context) => const LoginCredentialsScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
      },
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
