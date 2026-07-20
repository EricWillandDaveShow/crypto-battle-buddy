import 'dart:convert';

import '../models/lockdown.dart';
import 'storage_backend.dart';

class LockdownPersistence {
  static const _key = 'lockdown_state';
  final StorageBackend backend;

  LockdownPersistence({required this.backend});

  Future<void> save(LockdownState state) async {
    await backend.writeString(_key, jsonEncode(state.toJson()));
  }

  Future<LockdownState> load() async {
    final raw = await backend.readString(_key);
    if (raw == null) {
      return LockdownState(
        enabled: false,
        checklist: ReleaseChecklist(
          reviewedZones: false,
          reviewedBudget: false,
          reviewedHeat: false,
          reviewedExecutionMode: false,
        ),
      );
    }
    return LockdownState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
