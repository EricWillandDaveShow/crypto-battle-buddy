import '../models/feed_health.dart';
import 'price_feed.dart';

class MockPriceFeed implements PriceFeed {
  @override
  String get name => 'MockPriceFeed';

  final Map<String, double> prices;
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

  MockPriceFeed(this.prices);

  @override
  Future<Map<String, double>> fetchPrices({
    required List<String> symbols,
  }) async {
    _health = FeedHealth(
      status: FeedStatus.healthy,
      timestamp: DateTime.now(),
      message: 'OK',
    );
    return {
      for (final s in symbols)
        if (prices.containsKey(s)) s: prices[s]!,
    };
  }
}
