import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/feed_health.dart';
import 'price_feed.dart';
import 'symbol_maps.dart';

class KrakenPriceFeed implements PriceFeed {
  @override
  String get name => 'Kraken';

  static const _baseUrl = 'https://api.kraken.com/0/public/Ticker';

  FeedHealth _health = FeedHealth(
    status: FeedStatus.healthy,
    timestamp: DateTime.now(),
    message: 'OK',
  );

  @override
  FeedHealth get health => _health;

  @override
  void updateHealth(FeedHealth health) {
    _health = health;
  }

  @override
  Future<Map<String, double>> fetchPrices({
    required List<String> symbols,
  }) async {
    final Map<String, double> prices = {};
    try {
      for (final sym in symbols.where((s) => krakenPairBySymbol.containsKey(s))) {
        final pair = krakenPairBySymbol[sym]!;
        if (pair.isEmpty) {
          continue;
        }
        final uri = Uri.parse('$_baseUrl?pair=$pair');
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) {
          throw Exception('Kraken error ${response.statusCode}');
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['error'] is List && (body['error'] as List).isNotEmpty) {
          continue;
        }
        final result = body['result'] as Map<String, dynamic>? ?? {};
        if (result.isEmpty) continue;
        final ticker = result.values.first as Map<String, dynamic>;
        final lastList = ticker['c'] as List<dynamic>?;
        final last = lastList != null && lastList.isNotEmpty ? lastList.first as String? : null;
        final parsed = last == null ? null : double.tryParse(last);
        if (parsed != null) {
          prices[sym] = parsed;
        }
      }
      _health = FeedHealth(
        status: FeedStatus.healthy,
        timestamp: DateTime.now(),
        message: 'OK',
      );
      return prices;
    } catch (e) {
      _health = FeedHealth(
        status: FeedStatus.degraded,
        timestamp: DateTime.now(),
        message: e.toString(),
      );
      rethrow;
    }
  }
}
