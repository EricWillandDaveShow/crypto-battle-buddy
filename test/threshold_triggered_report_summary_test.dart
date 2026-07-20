import 'package:crypto_battle_buddy/engine/threshold_triggered_report_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty threshold triggered steps produce empty summary lines', () {
    final lines = buildThresholdTriggeredSummaryLines(
      const <Map<String, dynamic>>[],
    );

    expect(lines, isEmpty);
  });

  test('pending triggered entry produces readable summary line', () {
    final lines = buildThresholdTriggeredSummaryLines([
      {
        'symbol': 'BTC',
        'stepId': 'BTC:0',
        'tier': 1,
        'action': 'BUY',
        'triggerPriceUsd': 38000.0,
        'status': 'pending',
        'wasTriggered': true,
        'updatedAt': '2026-06-16T12:00:00.000Z',
        'currentPriceUsd': 37950.0,
      },
    ]);

    expect(lines, hasLength(1));
    expect(lines.single, contains('BTC'));
    expect(lines.single, contains('tier 1'));
    expect(lines.single, contains('BUY'));
    expect(lines.single, contains(r'$38000.00'));
    expect(lines.single, contains('pending'));
    expect(lines.single, contains(r'$37950.00'));
  });

  test('terminal status is preserved in readable summary line', () {
    final lines = buildThresholdTriggeredSummaryLines([
      {
        'symbol': 'ETH',
        'stepId': 'ETH:1',
        'tier': 2,
        'action': 'SELL',
        'triggerPriceUsd': 4600.0,
        'status': 'executed',
        'wasTriggered': true,
        'updatedAt': '2026-06-16T12:00:00.000Z',
      },
      {
        'symbol': 'SOL',
        'stepId': 'SOL:0',
        'tier': 1,
        'action': 'BUY',
        'triggerPriceUsd': 120.0,
        'status': 'dismissed',
        'wasTriggered': true,
        'updatedAt': '2026-06-16T12:00:00.000Z',
      },
    ]);

    expect(lines[0], contains('executed'));
    expect(lines[1], contains('dismissed'));
  });
}
