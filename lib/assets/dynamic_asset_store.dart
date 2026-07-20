import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dynamic_asset.dart';

/// Persistent store for user-added assets discovered via CoinGecko search.
/// Minimal v1: list of {symbol,name,coingeckoId}.
class DynamicAssetStore {
  static const String _kKey = 'dynamicAssets_v1';

  Future<List<DynamicAsset>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return const <DynamicAsset>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <DynamicAsset>[];
      return decoded
          .whereType<Map>()
          .map((m) => DynamicAsset.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (_) {
      return const <DynamicAsset>[];
    }
  }

  Future<void> upsert(DynamicAsset asset) async {
    final existing = await loadAll();
    final next = <DynamicAsset>[
      ...existing.where((a) => a.symbol.toUpperCase() != asset.symbol.toUpperCase()),
      asset,
    ]..sort((a, b) => a.symbol.compareTo(b.symbol));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(next.map((a) => a.toJson()).toList(growable: false)),
    );
  }

  Future<void> remove(String symbol) async {
    final all = await loadAll();
    final s = symbol.toUpperCase();
    final next = <DynamicAsset>[
      for (final a in all)
        if (a.symbol.toUpperCase() != s) a,
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(next.map((a) => a.toJson()).toList(growable: false)),
    );
  }

}
