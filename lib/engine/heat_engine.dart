import '../models/heat_mode.dart';

class HeatEngine {
  HeatModeState evaluate({
    required Map<String, double> prices,
    required HeatModeConfig config,
  }) {
    if (!config.enabled) {
      return HeatModeState(isHot: false, message: 'Heat mode disabled.');
    }

    for (final entry in config.heatThresholdBySymbol.entries) {
      final symbol = entry.key;
      final threshold = entry.value;
      final price = prices[symbol];
      if (price == null) continue;

      if (price >= threshold) {
        return HeatModeState(
          isHot: true,
          message: '$symbol is above heat threshold. Pause buys.',
        );
      }
    }

    return HeatModeState(isHot: false, message: 'Market not hot.');
  }
}
