import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/feed_health.dart';
import 'price_feed.dart';
import 'symbol_maps.dart';

class CoinbasePriceFeed implements PriceFeed {
  @override
  String get name => 'Coinbase';

  static const _baseUrl = 'https://api.coinbase.com/v2/prices';

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
      for (final sym in symbols.where((s) => supportedSymbols.contains(s))) {
        final uri = Uri.parse('$_baseUrl/$sym-USD/spot');
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) {
          throw Exception('Coinbase error ${response.statusCode}');
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final amount = (data['data']?['amount'] as String?) ?? '';
        final parsed = double.tryParse(amount);
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
