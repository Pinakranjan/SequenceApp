import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/home_navigation_provider.dart';
import '../about/about_screen.dart';
import '../planner/planner_screen.dart';
import '../../../providers/planner_provider.dart';
import '../contact/contact_screen.dart';

/// Main home screen with bottom navigation
/// Uses lazy loading to defer data fetching until tabs are selected
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Build the list of visible nav items based on config
  List<_TabConfig> get _visibleTabs {
    final tabs = <_TabConfig>[
      _TabConfig(
        key: _TabKey.orders,
        navItem: const BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.house, size: 20),
          activeIcon: FaIcon(FontAwesomeIcons.house, size: 22),
          label: 'Orders',
        ),
        screen: const OrdersScreen(),
        isVisible: true,
      ),
      _TabConfig(
        key: _TabKey.planner,
        navItem: const BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.calendarDays, size: 20),
          activeIcon: FaIcon(FontAwesomeIcons.calendarDays, size: 22),
          label: 'Planner',
        ),
        screen: const PlannerScreen(),
        isVisible: true,
      ),
      _TabConfig(
        key: _TabKey.contact,
        navItem: const BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.addressCard, size: 20),
          activeIcon: FaIcon(FontAwesomeIcons.addressCard, size: 22),
          label: 'Contact',
        ),
        screen: const ContactScreen(),
        isVisible: true,
      ),
    ];

    return tabs.where((tab) => tab.isVisible).toList();
  }

  Widget _buildScreen(int index, Set<int> visitedTabs) {
    final tabs = _visibleTabs;
    // Only build screens that have been visited (lazy loading)
    if (!visitedTabs.contains(index) || index >= tabs.length) {
      return const SizedBox.shrink();
    }

    return tabs[index].screen;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(homeTabIndexProvider);
    final visitedTabs = ref.watch(visitedTabsProvider);
    final tabs = _visibleTabs;

    // If only 1 tab is visible, show it directly without bottom navigation
    if (tabs.length == 1) {
      return Scaffold(body: tabs.first.screen);
    }

    // Ensure currentIndex is within valid range
    final validIndex = currentIndex.clamp(0, tabs.length - 1);
    if (validIndex != currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(homeTabIndexProvider.notifier).state = validIndex;
      });
    }

    // Mark current tab as visited (for programmatic navigation)
    if (!visitedTabs.contains(validIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(visitedTabsProvider.notifier).state = {
          ...visitedTabs,
          validIndex,
        };
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: validIndex,
        children: List.generate(
          tabs.length,
          (index) => _buildScreen(index, visitedTabs),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          currentIndex: validIndex,
          onTap: (index) {
            final isTabChange = index != validIndex;

            // Requirement: Tapping Planner tab while already selected should refresh data
            if (!isTabChange &&
                index < tabs.length &&
                tabs[index].key == _TabKey.planner) {
              ref.invalidate(plannerProvider);
            }

            // Mark tab as visited and switch to it
            ref.read(visitedTabsProvider.notifier).state = {
              ...visitedTabs,
              index,
            };
            ref.read(homeTabIndexProvider.notifier).state = index;
          },
          items: tabs.map((tab) => tab.navItem).toList(),
        ),
      ),
    );
  }
}

enum _TabKey { orders, planner, contact }

/// Configuration for a single tab
class _TabConfig {
  final _TabKey key;
  final BottomNavigationBarItem navItem;
  final Widget screen;
  final bool isVisible;

  const _TabConfig({
    required this.key,
    required this.navItem,
    required this.screen,
    required this.isVisible,
  });
}
