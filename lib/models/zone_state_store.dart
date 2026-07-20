import 'zone_state.dart';

class ZoneStateStore {
  final List<ZoneState> _zones = [];

  ZoneState _get(String symbol, double zonePrice) {
    return _zones.firstWhere(
      (z) => z.symbol == symbol && z.zonePrice == zonePrice,
      orElse: () {
        final z = ZoneState(symbol: symbol, zonePrice: zonePrice);
        _zones.add(z);
        return z;
      },
    );
  }

  bool isConsumed(String symbol, double zonePrice) {
    return _get(symbol, zonePrice).consumed;
  }

  void markConsumed(String symbol, double zonePrice) {
    _get(symbol, zonePrice).consumed = true;
  }

  void resetIfPriceExited(String symbol, double currentPrice, double zonePrice) {
    final z = _get(symbol, zonePrice);
    if (currentPrice > zonePrice) {
      z.consumed = false;
    }
  }

  void purgeSymbol(String symbol) {
    final normalized = symbol.toUpperCase();
    _zones.removeWhere((z) => z.symbol.toUpperCase() == normalized);
  }
}
