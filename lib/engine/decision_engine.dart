import '../models/decision_result.dart';
import '../core/portfolio_state.dart';
import '../models/zone_state_store.dart';

class DecisionEngine {
  final ZoneStateStore zoneStore;

  DecisionEngine({ZoneStateStore? zoneStore})
      : zoneStore = zoneStore ?? ZoneStateStore();

  DecisionResult evaluate({
    required String symbol,
    required double currentPrice,
    required List<double> buyZones,
    required List<double> sellZones,
  }) {
    for (final zone in buyZones) {
      zoneStore.resetIfPriceExited(symbol, currentPrice, zone);

      if (currentPrice <= zone && !zoneStore.isConsumed(symbol, zone)) {
        zoneStore.markConsumed(symbol, zone);
        return DecisionResult(
          state: PortfolioState.buyZone,
          message: 'Price reached a watch level.',
          metadata: {'price': currentPrice, 'zone': zone},
        );
      }
    }

    if (buyZones.isNotEmpty &&
        buyZones.every((z) => zoneStore.isConsumed(symbol, z))) {
      return DecisionResult(
        state: PortfolioState.hold,
        message: 'Watch levels exhausted.',
        metadata: {'price': currentPrice},
      );
    }

    for (final zone in sellZones) {
      if (currentPrice >= zone) {
        return DecisionResult(
          state: PortfolioState.sellZone,
          message: 'Price reached a profit level.',
          metadata: {'price': currentPrice, 'zone': zone},
        );
      }
    }

    return DecisionResult(
      state: PortfolioState.hold,
      message: 'Hold position.',
      metadata: {'price': currentPrice},
    );
  }
}
