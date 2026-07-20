import 'package:crypto_battle_buddy/engine/market_regime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies risk off with heat caution and weak alts', () {
    final result = computeMarketRegime(
      pricesUsd: const {'BTC': 85000, 'ETH': 2500, 'SOL': 90},
      heatStatusTextOrFlag: 'Heat guard forced DRY RUN.',
    );

    expect(result.regime, 'RISK_OFF');
    expect(result.confidence, inInclusiveRange(50, 100));
    expect(result.reasons.length, greaterThanOrEqualTo(2));
  });

  test('classifies risk on when alts are strong', () {
    final result = computeMarketRegime(
      pricesUsd: const {'BTC': 70000, 'ETH': 4500, 'SOL': 300},
    );

    expect(result.regime, 'RISK_ON');
    expect(result.confidence, greaterThan(60));
  });

  test('classifies high volatility when heat flags turbulence', () {
    final result = computeMarketRegime(
      pricesUsd: const {'BTC': 80000, 'ETH': 3200, 'SOL': 180},
      heatStatusTextOrFlag: 'Heat: volatility spike, caution',
    );

    expect(result.regime, 'HIGH_VOL');
    expect(result.confidence, inInclusiveRange(50, 100));
  });
}
