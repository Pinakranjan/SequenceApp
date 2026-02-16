import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls the selected tab index in HomeScreen.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Tracks which tabs have been visited to support lazy loading.
final visitedTabsProvider = StateProvider<Set<int>>((ref) => {0});
