import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'alerts_engine.dart';

const _kAlertRulesKey = 'alert_rules_v1';

Future<Map<String, AlertRule>> loadAlertRules() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kAlertRulesKey);
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, AlertRule> out = {};
    decoded.forEach((asset, ruleJson) {
      if (ruleJson is Map<String, dynamic>) {
        out[asset.toUpperCase()] = AlertRule.fromJson(ruleJson);
      }
    });
    return out;
  } catch (_) {
    return {};
  }
}

Future<void> saveAlertRules(Map<String, AlertRule> rules) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonMap = {
    for (final entry in rules.entries) entry.key.toUpperCase(): entry.value.toJson(),
  };
  await prefs.setString(_kAlertRulesKey, jsonEncode(jsonMap));
}
