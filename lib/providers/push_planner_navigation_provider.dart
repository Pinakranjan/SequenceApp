import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for pending planner navigation (either planner entry or notice)
class PushPlannerNavState {
  final String? plannerId;
  final int? noticeId;

  const PushPlannerNavState({this.plannerId, this.noticeId});
}

class PushPlannerNavigation extends StateNotifier<PushPlannerNavState> {
  PushPlannerNavigation() : super(const PushPlannerNavState());

  void requestOpen(String plannerId) {
    state = PushPlannerNavState(plannerId: plannerId);
  }

  void requestOpenNotice(int noticeId) {
    state = PushPlannerNavState(noticeId: noticeId);
  }

  void clear() {
    state = const PushPlannerNavState();
  }
}

final pushPlannerNavigationProvider =
    StateNotifierProvider<PushPlannerNavigation, PushPlannerNavState>((ref) {
      return PushPlannerNavigation();
    });

/// Deprecated: use pushPlannerNavigationProvider instead
final pendingPlannerOpenIdProvider = StateProvider<String?>((ref) => null);
