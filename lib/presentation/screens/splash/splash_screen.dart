import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';

/// Splash screen with OJEE 2026 branding and Lottie animation
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
    // Navigate after delay — check onboarding status first
    _navigationTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'onboarding_completed_${AppConfig.appVersion}';
      final completed = prefs.getBool(key) ?? false;
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(completed ? '/home' : '/onboarding');
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
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient + centered logo
          Container(
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            child: Center(
              child: SvgPicture.asset(
                _logoAsset,
                width: 180,
                fit: BoxFit.contain,
                placeholderBuilder:
                    (_) =>
                        const Icon(Icons.school, size: 80, color: Colors.white),
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
          // Copyright text
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                '© OJEE-2026',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
