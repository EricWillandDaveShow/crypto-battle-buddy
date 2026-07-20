import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'asset_registry.dart';

const bool kAssetCatalogDebugLogs = false;

/// Persistent catalog for "any asset" support.
///
/// Stores:
/// - symbolUpper -> CoinGecko id (e.g. "BTC" -> "bitcoin")
/// - enabled symbols set (toggle on/off UI can build off this later)
///
/// This makes CoinGecko the source-of-truth for coverage and prevents
/// symbol-map dead ends caused by missing exchange symbol maps.
class AssetCatalogStore {
  static const String _kCatalogKey = 'asset_catalog_v1'; // Map<String,String>
  static const String _kEnabledKey = 'asset_enabled_v1'; // List<String>

  // Catalog starts empty; assets are added by user/search.
  static const Map<String, String> _kSeedCatalog = <String, String>{};

  AssetCatalogStore();

  Future<Map<String, String>> loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCatalogKey);
    if (raw == null || raw.trim().isEmpty) {
      // Initialize an empty catalog when missing.
      final seeded = <String, String>{
        for (final e in _kSeedCatalog.entries) e.key.toUpperCase(): e.value,
      };
      await prefs.setString(_kCatalogKey, jsonEncode(seeded));
      // ignore: avoid_print
      print('CATALOG_SEEDED(asset_catalog_v1): ${seeded.keys.toList()..sort()}');
      return seeded;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      final out = <String, String>{};
      decoded.forEach((k, v) {
        if (k is String && v is String) {
          out[k.toUpperCase()] = v;
        }
      });
      return out;
    } catch (_) {
      // If corrupted, reset to an empty catalog.
      final seeded = <String, String>{
        for (final e in _kSeedCatalog.entries) e.key.toUpperCase(): e.value,
      };
      await prefs.setString(_kCatalogKey, jsonEncode(seeded));
      // ignore: avoid_print
      print('CATALOG_RESEEDED(asset_catalog_v1): ${seeded.keys.toList()..sort()}');
      return seeded;
    }
  }

  Future<void> saveCatalog(Map<String, String> catalog) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = <String, String>{
      for (final e in catalog.entries) e.key.toUpperCase(): e.value,
    };
    await prefs.setString(_kCatalogKey, jsonEncode(normalized));
  }

  Future<void> upsert(String symbol, String coingeckoId) async {
    final s = symbol.toUpperCase();
    final catalog = await loadCatalog();
    catalog[s] = coingeckoId;
    await saveCatalog(catalog);
  }

  Future<void> remove(String symbol) async {
    final catalog = await loadCatalog();
    final s = symbol.toUpperCase();
    if (catalog.containsKey(s)) {
      catalog.remove(s);
      await saveCatalog(catalog);
    }
  }

  Future<Set<String>> _seedEnabledAnchorsOnly(
    SharedPreferences prefs, {
    required String reason,
  }) async {
    await prefs.setStringList(_kEnabledKey, <String>[]);
    return <String>{};
  }

  Future<Set<String>> loadEnabledSymbols() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? list;
    try {
      list = prefs.getStringList(_kEnabledKey);
    } catch (_) {
      return _seedEnabledAnchorsOnly(prefs, reason: 'invalid');
    }
    if (list == null) {
      return _seedEnabledAnchorsOnly(prefs, reason: 'missing');
    }

    final symbolPattern = RegExp(r'^[A-Z0-9]{1,20}$');
    var sawInvalid = false;
    final enabled = <String>{};
    for (final raw in list) {
      final s = raw.trim().toUpperCase();
      if (s.isEmpty) continue;
      if (!symbolPattern.hasMatch(s)) {
        sawInvalid = true;
        continue;
      }
      enabled.add(s);
    }

    if (enabled.isEmpty) {
      return _seedEnabledAnchorsOnly(prefs, reason: 'empty');
    }
    if (sawInvalid) {
      return _seedEnabledAnchorsOnly(prefs, reason: 'invalid');
    }

    final normalized = enabled.toList()..sort();
    final rawNormalized = list.map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toList()
      ..sort();
    if (normalized.join('|') != rawNormalized.join('|')) {
      await prefs.setStringList(_kEnabledKey, normalized);
    }

    if (kDebugMode && kAssetCatalogDebugLogs) {
      // ignore: avoid_print
      print('CATALOG_ENABLED_SYMBOLS: $normalized');
      // ignore: avoid_print
      print('CATALOG_ENABLED_HAS_STX: ${enabled.contains('STX')}');
    }
    return enabled;
  }

  Future<void> saveEnabledSymbols(Set<String> symbols) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = symbols.map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toSet();
    final list = normalized.toList()..sort();
    await prefs.setStringList(_kEnabledKey, list);
    if (kDebugMode && kAssetCatalogDebugLogs) {
      // ignore: avoid_print
      print('CATALOG_SAVED_ENABLED_SYMBOLS: $list');
    }
  }
}
