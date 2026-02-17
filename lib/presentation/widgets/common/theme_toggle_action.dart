import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/theme_provider.dart';

class ThemeToggleAction extends ConsumerWidget {
  const ThemeToggleAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isOffline) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: isDark ? 'Switch to light' : 'Switch to dark',
      iconSize: 20,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      onPressed: () {
        ref
            .read(themeModeProvider.notifier)
            .toggleTheme(currentBrightness: Theme.of(context).brightness);
      },
    );
  }
}
