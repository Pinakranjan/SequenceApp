import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlannerPinsRepository {
  static const String _storageKey = 'planner_pins_v1';

  Future<Set<String>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <String>{};

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};

    return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> setAll(Set<String> pins) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(pins.toList()..sort());
    await prefs.setString(_storageKey, encoded);
  }

  Future<bool> toggle(String key) async {
    final pins = await getAll();
    final next = {...pins};
    final nowPinned = !next.contains(key);
    if (nowPinned) {
      next.add(key);
    } else {
      next.remove(key);
    }
    await setAll(next);
    return nowPinned;
  }
}
