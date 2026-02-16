import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:introduction_screen/introduction_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';

/// Full-screen onboarding walkthrough shown once per app version.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _onDone(BuildContext context) async {
    await completeOnboarding();
    if (context.mounted) {
      // If opened from About header (pushNamed), just pop back.
      // If opened from splash (pushReplacementNamed), go to /home.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleStyle = GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : AppColors.textPrimaryLight,
    );
    final bodyStyle = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color:
          isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      height: 1.5,
    );

    final pageDecoration = PageDecoration(
      titleTextStyle: titleStyle,
      bodyTextStyle: bodyStyle,
      imagePadding: const EdgeInsets.fromLTRB(68, 40, 68, 0),
      contentMargin: const EdgeInsets.symmetric(horizontal: 16),
      bodyPadding: const EdgeInsets.only(top: 8),
      titlePadding: const EdgeInsets.only(top: 16, bottom: 8),
      pageColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      imageFlex: 4, // 80% of screen for image
      bodyFlex: 1, // 20% for text
      bodyAlignment: Alignment.topCenter,
    );

    return IntroductionScreen(
      globalBackgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      safeAreaList: const [true, false, false, false],
      pages: [
        // ── Slide 1: Planner & Reminders ──
        PageViewModel(
          title: 'Planner & Reminders',
          body:
              'Plan your study schedule and get timely reminders so you never miss a deadline.',
          image: const _CrossfadingImage(
            assetPaths: [
              'assets/images/onboarding/onboarding_planner.png',
              'assets/images/onboarding/onboarding_planner2.png',
              'assets/images/onboarding/onboarding_planner3.png',
            ],
            interval: Duration(seconds: 4),
          ),
          decoration: pageDecoration,
        ),
        // ── Slide 2: Offline Notices ──
        PageViewModel(
          title: 'Offline Notices',
          body:
              'Access important notices even without internet.\nAll notices are saved for offline reading.',
          image: _buildImage('assets/images/onboarding/onboarding_offline.png'),
          decoration: pageDecoration,
        ),
        // ── Slide 3: Notice-based Reminders ──
        PageViewModel(
          title: 'Notice-based Reminders',
          body:
              'Set reminders on any notice to stay updated on critical announcements and deadlines.',
          image: const _CrossfadingImage(
            assetPaths: [
              'assets/images/onboarding/onboarding_reminders.png',
              'assets/images/onboarding/onboarding_reminders2.png',
            ],
            interval: Duration(seconds: 4),
          ),
          decoration: pageDecoration,
        ),
        // ── Slide 4: Native iOS Experience ──
        PageViewModel(
          title: 'Native iOS Experience',
          body:
              'Enjoy a smooth, native experience designed specifically for your device.',
          image: const _CrossfadingImage(
            assetPaths: [
              'assets/images/onboarding/onboarding_native.png',
              'assets/images/onboarding/onboarding_native2.png',
              'assets/images/onboarding/onboarding_native3.png',
            ],
            interval: Duration(seconds: 4),
          ),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onDone(context),
      onSkip: () => _onDone(context),
      showSkipButton: true,
      skip: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.headerGradientStart, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Skip',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.headerGradientStart,
          ),
        ),
      ),
      next: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.headerGradientStart, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Next',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.headerGradientStart,
          ),
        ),
      ),
      done: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.headerGradientStart, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Got it',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.headerGradientStart,
          ),
        ),
      ),
      dotsDecorator: DotsDecorator(
        size: const Size(8, 8),
        activeSize: const Size(22, 8),
        activeColor: AppColors.headerGradientStart,
        color: isDark ? Colors.white24 : Colors.grey.shade300,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      curve: Curves.easeInOut,
      animationDuration: 350,
    );
  }

  /// Builds the image widget for each onboarding slide.
  /// Falls back to an icon placeholder if the image asset is missing.
  Widget _buildImage(String assetPath) {
    return SizedBox.expand(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          assetPath,
          fit: BoxFit.fill,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) {
            // Placeholder shown until the user adds the real images
            return Center(
              child: Container(
                height: double.infinity,
                width: double.infinity,
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.headerGradientStart.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  size: 80,
                  color: AppColors.headerGradientStart,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A widget that smoothly crossfades between a list of images on a timer.
class _CrossfadingImage extends StatefulWidget {
  final List<String> assetPaths;
  final Duration interval;

  const _CrossfadingImage({
    required this.assetPaths,
    this.interval = const Duration(seconds: 4),
  });

  @override
  State<_CrossfadingImage> createState() => _CrossfadingImageState();
}

class _CrossfadingImageState extends State<_CrossfadingImage> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    if (widget.assetPaths.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.assetPaths.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _image(String path, double width, double height) {
    return SizedBox(
      key: ValueKey(path),
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          path,
          fit: BoxFit.fill,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.headerGradientStart.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 80,
                  color: AppColors.headerGradientStart,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _image(widget.assetPaths[_currentIndex], w, h),
          );
        },
      ),
    );
  }
}
