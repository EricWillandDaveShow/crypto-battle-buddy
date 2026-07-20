import 'dart:convert';

import '../models/cooldown_store.dart';
import 'storage_backend.dart';

class CooldownPersistence {
  static const _key = 'cooldowns';
  final StorageBackend backend;

  CooldownPersistence({required this.backend});

  Future<void> save(CooldownStore store) async {
    final data = store.exportIsoMap();
    await backend.writeString(_key, jsonEncode(data));
  }

  Future<void> loadInto(CooldownStore store) async {
    final raw = await backend.readString(_key);
    if (raw == null) return;

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      store.importIsoMap(decoded);
    }
  }

  Future<void> clear() => backend.deleteString(_key);
}
