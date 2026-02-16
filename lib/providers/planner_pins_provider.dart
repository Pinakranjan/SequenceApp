import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/planner_pins_repository.dart';

final plannerPinsRepositoryProvider = Provider<PlannerPinsRepository>((ref) {
  return PlannerPinsRepository();
});

class PlannerPinsNotifier extends StateNotifier<Set<String>> {
  final PlannerPinsRepository _repo;

  PlannerPinsNotifier(this._repo) : super(<String>{}) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.getAll();
  }

  Future<bool> toggle(String key) async {
    final nowPinned = await _repo.toggle(key);
    state = await _repo.getAll();
    return nowPinned;
  }
}

final plannerPinsProvider =
    StateNotifierProvider<PlannerPinsNotifier, Set<String>>((ref) {
      return PlannerPinsNotifier(ref.watch(plannerPinsRepositoryProvider));
    });
