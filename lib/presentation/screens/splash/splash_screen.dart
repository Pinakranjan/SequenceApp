import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../data/services/auth_service.dart';

/// Splash screen with branding and Lottie animation
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  static const String _logoAsset = 'assets/images/icons/logo.svg';

  @override
  void initState() {
    super.initState();
    // Navigate after delay — check onboarding + auth status
    _navigationTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'onboarding_completed_${AppConfig.appVersion}';
      final onboardingDone = prefs.getBool(key) ?? false;
      if (!mounted) return;

      if (!onboardingDone) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
        return;
      }

      // Check if user is authenticated
      final authService = AuthService();
      final isLoggedIn = await authService.isAuthenticated();
      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacementNamed(isLoggedIn ? '/home' : '/landing');
    });

    // Remove native splash screen after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Small delay to ensure the Lottie animation or image is loaded/rendered
      // before removing the native splash to avoid white flash
      debugPrint('Removing native splash screen');
      FlutterNativeSplash.remove();
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient + centered logo
          Container(
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    _logoAsset,
                    width: 180,
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      AppColors.logoTint,
                      BlendMode.srcIn,
                    ),
                    placeholderBuilder:
                        (_) => const Icon(
                          Icons.school,
                          size: 80,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sequence',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Lottie loading animation at bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: Lottie.asset(
                'assets/lottie/lottie_loading2.json',
                width: 60,
                height: 60,
                repeat: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
