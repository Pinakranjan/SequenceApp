import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/common/theme_toggle_action.dart';

/// Orders screen (renamed from About)
///
/// Requirement: remove the previous About details content.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  static const String _headerLogoAsset = 'assets/images/icons/logo.svg';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
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
                  _headerLogoAsset,
                  height: 22,
                  width: 22,
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(
                    AppColors.logoTint,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Orders',
                    style: AppConfig.headerTitleTextStyle(theme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Replay Walkthrough',
                onPressed: () {
                  Navigator.of(context).pushNamed('/onboarding');
                },
                icon: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                ),
              ),
              const IconTheme(
                data: IconThemeData(color: Colors.white),
                child: ThemeToggleAction(),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  if (value == 'lock') {
                    Navigator.of(context).pushNamed('/lock');
                  } else if (value == 'signout') {
                    final authService = ref.read(authServiceProvider);
                    await authService.logout();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/landing', (_) => false);
                    }
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'lock',
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 20),
                            SizedBox(width: 10),
                            Text('Lock Screen'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'signout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 20, color: Colors.red),
                            SizedBox(width: 10),
                            Text(
                              'Sign Out',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
