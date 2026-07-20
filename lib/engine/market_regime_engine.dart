import 'dart:math';

class MarketRegimeResult {
  final String regime;
  final int confidence;
  final List<String> reasons;

  const MarketRegimeResult({
    required this.regime,
    required this.confidence,
    required this.reasons,
  });

  Map<String, dynamic> toJson() => {
        'regime': regime,
        'confidence': confidence,
        'reasons': reasons,
      };
}

class RegimePolicyKnobs {
  final String buyCadence;
  final String allocationBias;
  final String profitTightness;

  const RegimePolicyKnobs({
    required this.buyCadence,
    required this.allocationBias,
    required this.profitTightness,
  });

  Map<String, String> toJson() => {
        'buyCadence': buyCadence,
        'allocationBias': allocationBias,
        'profitTightness': profitTightness,
      };
}

MarketRegimeResult computeMarketRegime({
  required Map<String, num> pricesUsd,
  String? heatStatusTextOrFlag,
}) {
  double read(String key) {
    final v = pricesUsd[key] ?? pricesUsd[key.toUpperCase()] ?? pricesUsd[key.toLowerCase()];
    if (v == null) return 0.0;
    return v.toDouble();
  }

  final btc = read('BTC');
  final eth = read('ETH');
  final sol = read('SOL');

  if (btc <= 0 || eth <= 0 || sol <= 0) {
    return const MarketRegimeResult(
      regime: 'NEUTRAL',
      confidence: 40,
      reasons: ['Insufficient price data.'],
    );
  }

  final ratio = btc / max(1.0, (eth + sol));
  final ethRel = eth / max(1.0, btc);
  final solRel = sol / max(1.0, btc);

  final total = btc + eth + sol;
  final btcShare = btc / max(1.0, total);
  final altsShare = (eth + sol) / max(1.0, total);
  final spread = (ethRel - solRel).abs();

  final heatText = (heatStatusTextOrFlag ?? '').toLowerCase();
  final heatSuggestsCaution = heatText.contains('pause') ||
      heatText.contains('heat') ||
      heatText.contains('lock') ||
      heatText.contains('caution') ||
      heatText.contains('hot');
  final heatSuggestsVol =
      heatText.contains('vol') || heatText.contains('spike') || heatText.contains('swing');

  final bool btcDominant = btcShare > 0.97 || ratio > 26;
  final bool altsWeak = altsShare < 0.03 || (ethRel < 0.03 && solRel < 0.0013);
  final bool altsStrong = altsShare > 0.045 && ethRel > 0.034 && solRel > 0.0015;
  final bool bigSpread = spread > 0.06 || (ethRel / max(0.0001, solRel)) > 45;

  String regime = 'NEUTRAL';
  final reasons = <String>[
    'BTC/(ETH+SOL)=${ratio.toStringAsFixed(2)}',
    'ETH/BTC=${ethRel.toStringAsFixed(4)} SOL/BTC=${solRel.toStringAsFixed(4)}',
  ];

  if ((heatSuggestsVol && heatSuggestsCaution) || bigSpread) {
    regime = 'HIGH_VOL';
    reasons.add(bigSpread
        ? 'Dispersion elevated (${spread.toStringAsFixed(4)})'
        : 'Heat indicates volatility');
  }

  if (regime != 'HIGH_VOL') {
    if (heatSuggestsCaution || (btcDominant && altsWeak)) {
      regime = 'RISK_OFF';
      if (btcDominant) {
        reasons.add('BTC dominant (${(btcShare * 100).toStringAsFixed(1)}% share)');
      }
      if (altsWeak) {
        reasons.add('Alts weak (${(altsShare * 100).toStringAsFixed(1)}% share)');
      }
      if (heatSuggestsCaution) reasons.add('Heat flag leaning defensive');
    } else if (altsStrong) {
      regime = 'RISK_ON';
      reasons.add('Alts showing strength (${(altsShare * 100).toStringAsFixed(1)}% share)');
    } else {
      regime = 'NEUTRAL';
      reasons.add('Mixed signals; staying neutral');
    }
  }

  int confidence;
  switch (regime) {
    case 'RISK_OFF':
      confidence = 55 +
          (btcDominant ? 15 : 0) +
          (altsWeak ? 10 : 0) +
          (heatSuggestsCaution ? 10 : 0) +
          (heatSuggestsVol ? 5 : 0);
      break;
    case 'RISK_ON':
      confidence = 60 +
          (altsStrong ? 15 : 0) +
          (altsShare > 0.055 ? 5 : 0) +
          (heatSuggestsCaution ? -5 : 0);
      break;
    case 'HIGH_VOL':
      confidence = 60 +
          (bigSpread ? 15 : 0) +
          (heatSuggestsVol ? 10 : 0) +
          (heatSuggestsCaution ? 5 : 0);
      break;
    default:
      confidence = 50 +
          (heatSuggestsCaution ? 5 : 0) +
          (altsShare > 0.04 ? 5 : 0) +
          (btcDominant ? 5 : 0);
      break;
  }

  confidence = confidence.clamp(0, 100);

  return MarketRegimeResult(
    regime: regime,
    confidence: confidence,
    reasons: reasons.take(4).toList(),
  );
}

RegimePolicyKnobs mapRegimeToKnobs({
  required String modeLabel,
  required MarketRegimeResult regime,
}) {
  final lowerMode = modeLabel.toLowerCase();
  final bool isChill = lowerMode.contains('chill');
  final bool isYolo = lowerMode.contains('yolo');

  String buyCadence = 'NORMAL';
  String allocationBias = 'BALANCED';
  String profitTightness = 'NORMAL';

  switch (regime.regime) {
    case 'RISK_OFF':
      buyCadence = 'PAUSE';
      allocationBias = 'BTC_HEAVY';
      profitTightness = 'TIGHT';
      break;
    case 'RISK_ON':
      buyCadence = isChill ? 'NORMAL' : 'AGGRESSIVE';
      allocationBias = isChill ? 'BALANCED' : 'ALT_TILT';
      profitTightness = isYolo ? 'LOOSE' : 'NORMAL';
      break;
    case 'HIGH_VOL':
      buyCadence = isYolo ? 'NORMAL' : 'PAUSE';
      allocationBias = 'BTC_HEAVY';
      profitTightness = 'TIGHT';
      break;
    default:
      buyCadence = 'NORMAL';
      allocationBias = isChill ? 'BTC_HEAVY' : 'BALANCED';
      profitTightness = isYolo ? 'NORMAL' : 'TIGHT';
      break;
  }

  return RegimePolicyKnobs(
    buyCadence: buyCadence,
    allocationBias: allocationBias,
    profitTightness: profitTightness,
  );
}
