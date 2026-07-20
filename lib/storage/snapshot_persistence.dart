import 'dart:convert';

import '../models/status_snapshot.dart';
import 'storage_backend.dart';

class SnapshotPersistence {
  static const _key = 'last_snapshot';
  final StorageBackend backend;

  SnapshotPersistence({required this.backend});

  Future<void> save(StatusSnapshot snapshot) async {
    await backend.writeString(_key, jsonEncode(snapshot.toJson()));
  }

  Future<Map<String, dynamic>?> loadJson() async {
    final raw = await backend.readString(_key);
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  Future<void> clear() => backend.deleteString(_key);
}
