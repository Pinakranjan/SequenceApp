import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
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
