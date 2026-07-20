import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../assets/asset_catalog_store.dart';
import '../assets/dynamic_asset_store.dart';
import '../models/feed_health.dart';
import 'price_feed.dart';
import 'symbol_maps.dart';

const bool kCgFeedVerboseLogs = false;

class CoinGeckoPriceFeed implements PriceFeed {
  @override
  String get name => 'CoinGecko';

  final AssetCatalogStore _catalogStore = AssetCatalogStore();
  final DynamicAssetStore _dynamicStore = DynamicAssetStore();
  Map<String, String> _catalogCache = const <String, String>{};
  DateTime? _catalogCacheTs;

  FeedHealth _health = FeedHealth(
    status: FeedStatus.healthy,
    timestamp: DateTime.now(),
    message: 'OK',
  );

  @override
  FeedHealth get health => _health;

  void _recordFailure(String msg) {
    _health = _health.copyWith(
      status: _health.status == FeedStatus.healthy
          ? FeedStatus.degraded
          : FeedStatus.down,
      timestamp: DateTime.now(),
      message: msg,
    );
  }

  void _recordSuccess() {
    _health = _health.copyWith(
      status: FeedStatus.healthy,
      timestamp: DateTime.now(),
      message: 'OK',
    );
  }

  @override
  void updateHealth(FeedHealth newHealth) {
    _health = newHealth.copyWith(timestamp: DateTime.now());
  }

  bool _isCatalogCacheFresh(DateTime now) {
    return _catalogCacheTs != null &&
        now.difference(_catalogCacheTs!).inSeconds <= 20;
  }

  void _invalidateCatalogCache() {
    _catalogCacheTs = null;
  }

  Future<Map<String, String>> _loadCatalogMergedIdMap() async {
    // Cheap cache to avoid hitting SharedPreferences every tick.
    final now = DateTime.now();
    final fresh = _catalogCacheTs != null &&
        now.difference(_catalogCacheTs!).inSeconds <= 20;
    if (!fresh) {
      try {
        final raw = await _catalogStore.loadCatalog();
        final dynamicAssets = await _dynamicStore.loadAll();
        final merged = <String, String>{
          for (final e in raw.entries) e.key.toUpperCase(): e.value,
        };
        for (final d in dynamicAssets) {
          merged[d.symbol.toUpperCase()] = d.coingeckoId;
        }
        _catalogCache = merged;
        _catalogCacheTs = now;
      } catch (_) {
        // ignore; fall back to static map only
      }
    }
    // Catalog overrides static map when present.
    return <String, String>{
      ...coingeckoIdBySymbol,
      ..._catalogCache,
    };
  }

  @override
  Future<Map<String, double>> fetchPrices({
    required List<String> symbols,
    int delaySeconds = 0,
  }) async {
    try {
      if (delaySeconds > 0) {
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      var idMap = await _loadCatalogMergedIdMap();
      final now = DateTime.now();

      // DEBUG (R3): confirm catalog/idMap coverage for requested symbols.
      final reqUpper = symbols.map((s) => s.toUpperCase()).toList()..sort();
      List<String> computeMissing(Map<String, String> map) {
        final miss = <String>[];
        for (final s in reqUpper) {
          if (!map.containsKey(s)) miss.add(s);
        }
        miss.sort();
        return miss;
      }

      var missing = computeMissing(idMap);

// R8: force one refresh if cache is fresh but symbols missing
      if (missing.isNotEmpty && _isCatalogCacheFresh(now)) {
        _invalidateCatalogCache();
        idMap = await _loadCatalogMergedIdMap();
        missing = computeMissing(idMap);
      }

      final matched = <String>[];
      for (final s in reqUpper) {
        if (idMap.containsKey(s)) matched.add(s);
      }
      // ignore: avoid_print
      print('CG_FEED_REQ_SYMBOLS: ${reqUpper.join(", ")}');
      if (kDebugMode && kCgFeedVerboseLogs) {
        // ignore: avoid_print
        print('CG_FEED_IDMAP_SIZE: ${idMap.length}');
        // ignore: avoid_print
        print('CG_FEED_MATCHED_SYMBOLS: ${matched.join(", ")}');
      }
      if (missing.isNotEmpty) {
        // Avoid insanely long logs, but still show what is missing.
        final shown = missing.take(30).toList();
        final more = missing.length > shown.length
            ? ' (+${missing.length - shown.length} more)'
            : '';
        // ignore: avoid_print
        print('CG_FEED_MISSING_SYMBOLS: ${shown.join(", ")}$more');
      }

      final ids = symbols
          .where((s) => idMap.containsKey(s.toUpperCase()))
          .map((s) => idMap[s.toUpperCase()]!)
          .toSet()
          .toList();

      if (ids.isEmpty) {
        // ignore: avoid_print
        print('CG_FEED_IDS: (empty) — no ids matched in idMap');
        return {};
      }

      // ignore: avoid_print
      print('CG_FEED_IDS: ${ids.join(",")}');
      final uri = Uri.https(
        'api.coingecko.com',
        '/api/v3/simple/price',
        {
          'ids': ids.join(','),
          'vs_currencies': 'usd',
        },
      );
      final response = await http.get(uri);
      debugPrint('CG_FEED_STATUS: ${response.statusCode}');
      debugPrint('CG_FEED_BODY: ${response.body}');
      if (response.statusCode != 200) {
        _recordFailure('CoinGecko error ${response.statusCode}');
        throw Exception('CoinGecko error ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final prices = <String, double>{};
      for (final entry in json.entries) {
        final id = entry.key;
        final data = entry.value as Map<String, dynamic>;
        final usd = (data['usd'] as num?)?.toDouble();
        if (usd == null) continue;

        // Reverse-lookup symbol from merged id map (static + catalog).
        // NOTE: O(n) in map size, but map is small and cached.
        String? sym;
        for (final e in idMap.entries) {
          if (e.value == id) {
            sym = e.key;
            break;
          }
        }
        if (sym != null) prices[sym] = usd;
      }

      _recordSuccess();
      return prices;
    } catch (e) {
      // Leave health status; PollingEngine handles 429 specially.
      if (_health.status != FeedStatus.rateLimited) {
        _recordFailure('CoinGecko exception $e');
      }
      rethrow;
    }
  }
}

