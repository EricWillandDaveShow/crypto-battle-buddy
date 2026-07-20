import 'dart:convert';

import '../models/strategy_report.dart';
import 'storage_backend.dart';

class ReportPersistence {
  static const _key = 'last_report';
  final StorageBackend backend;

  ReportPersistence({required this.backend});

  Future<void> save(StrategyReport report) async {
    await backend.writeString(_key, jsonEncode(report.toJson()));
  }

  Future<Map<String, dynamic>?> loadJson() async {
    final raw = await backend.readString(_key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clear() => backend.deleteString(_key);
}
