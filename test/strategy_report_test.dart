import 'package:crypto_battle_buddy/report/strategy_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strategy report builds and contains expected keys', () {
    final ts = DateTime.utc(2025, 1, 1);
    final report = buildStrategyReport(
      ts: ts,
      mode: 'Balanced',
      heatMode: false,
      safetyLock: false,
      goLive: true,
      pricesUsd: const {'BTC': 50000, 'ETH': 3000},
      holdingsBySymbol: const {'BTC': 1.0, 'ETH': 2.0},
      targetWeights: const {'BTC': 70, 'ETH': 30},
      marketRegime: const {'regime': 'NEUTRAL', 'confidence': 60},
      guidance: const {'statusText': 'OK', 'nextActionText': 'Monitor'},
      statusText: 'Regime: NEUTRAL',
      nextActionText: 'Monitor — no action.',
      alertsSummary: 'Watch 1 / Profit 0',
      alertLines: const ['BTC reached a watch level'],
      monthlyBudget: 500,
      monthlySpent: 100,
      monthlyRemaining: 400,
      portfolioSummaryJson: const {'total_value_usd': 110000},
    );

    final json = report.data;
    expect(json['meta'], isNotNull);
    expect(json['prices_usd'], isNotNull);
    expect(json['holdings_units'], isNotNull);
    expect(json['texts'], isNotNull);
    expect(json['budget'], isNotNull);
    expect(report.summary, contains('Mode: Balanced'));
    expect(report.summary, contains('Next: Monitor'));

    final pretty = report.toPrettyJson();
    expect(pretty, contains('"prices_usd"'));
    expect(pretty, contains('"holdings_units"'));
  });
}
