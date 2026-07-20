import '../models/feed_health.dart';

abstract class PriceFeed {
  String get name;

  Future<Map<String, double>> fetchPrices({
    required List<String> symbols,
  });

  FeedHealth get health;

  /// Explicitly update feed health (immutable replacement).
  void updateHealth(FeedHealth health);
}
