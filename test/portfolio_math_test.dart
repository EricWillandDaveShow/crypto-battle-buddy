import 'package:crypto_battle_buddy/portfolio_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('total and allocation for two assets', () {
    final summary = computePortfolioSummary(
      includedSymbols: ['BTC', 'ETH'],
      holdingsBySymbol: {'BTC': 1.0, 'ETH': 10.0},
      pricesUsd: {'BTC': 50000.0, 'ETH': 3000.0},
      targetWeights: {'BTC': 70, 'ETH': 30},
    );

    expect(summary.totalValueUsd, 80000.0);
    final btc = summary.rows.firstWhere((r) => r.symbol == 'BTC');
    final eth = summary.rows.firstWhere((r) => r.symbol == 'ETH');
    expect(btc.allocPct.toStringAsFixed(1), '62.5');
    expect(eth.allocPct.toStringAsFixed(1), '37.5');
  });

  test('target normalization handles arbitrary scales', () {
    final summary = computePortfolioSummary(
      includedSymbols: ['BTC', 'ETH'],
      holdingsBySymbol: {'BTC': 1.0, 'ETH': 0.0},
      pricesUsd: {'BTC': 10000.0, 'ETH': 1000.0},
      targetWeights: {'BTC': 2, 'ETH': 1},
    );
    final btc = summary.rows.firstWhere((r) => r.symbol == 'BTC');
    final eth = summary.rows.firstWhere((r) => r.symbol == 'ETH');
    expect(btc.targetPct.toStringAsFixed(1), '66.7');
    expect(eth.targetPct.toStringAsFixed(1), '33.3');
  });

  test('delta labels classify around thresholds', () {
    expect(deltaLabel(-2.1), 'Under');
    expect(deltaLabel(-1.9), 'On target');
    expect(deltaLabel(2.0), 'Over');
    expect(deltaLabel(1.9), 'On target');
  });
}
