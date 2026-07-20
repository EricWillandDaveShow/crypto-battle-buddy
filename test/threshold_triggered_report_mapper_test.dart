import 'package:crypto_battle_buddy/engine/threshold_triggered_report_mapper.dart';
import 'package:crypto_battle_buddy/models/threshold_plan.dart';
import 'package:crypto_battle_buddy/models/threshold_step_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final updatedAt = DateTime.utc(2026, 6, 16, 12);

  ThresholdStepState state({
    required String stepId,
    ThresholdStepStatus status = ThresholdStepStatus.pending,
    bool wasTriggered = true,
  }) {
    return ThresholdStepState(
      stepId: stepId,
      status: status,
      updatedAt: updatedAt,
      wasTriggered: wasTriggered,
    );
  }

  const btcPlan = ThresholdPlan(
    assetSymbol: 'BTC',
    anchorPriceUsd: 40000,
    steps: [
      ThresholdStep(
        triggerPriceUsd: 38000,
        action: 'BUY',
        percentOfPosition: 25,
      ),
      ThresholdStep(
        triggerPriceUsd: 46000,
        action: 'SELL',
        percentOfPosition: 25,
      ),
    ],
  );

  test('pending triggered step appears in report entries', () {
    final entries = buildThresholdTriggeredStepReportEntries(
      statesBySymbol: {
        'BTC': {
          'BTC:0': state(stepId: 'BTC:0'),
        },
      },
      plansBySymbol: const {'BTC': btcPlan},
    );

    expect(entries, hasLength(1));
    expect(
      entries.single,
      {
        'symbol': 'BTC',
        'stepId': 'BTC:0',
        'tier': 1,
        'action': 'BUY',
        'triggerPriceUsd': 38000.0,
        'status': 'pending',
        'wasTriggered': true,
        'updatedAt': updatedAt.toIso8601String(),
      },
    );
  });

  test('untriggered pending step is omitted', () {
    final entries = buildThresholdTriggeredStepReportEntries(
      statesBySymbol: {
        'BTC': {
          'BTC:0': state(stepId: 'BTC:0', wasTriggered: false),
        },
      },
      plansBySymbol: const {'BTC': btcPlan},
    );

    expect(entries, isEmpty);
  });

  test('executed and missed triggered steps include terminal status', () {
    final entries = buildThresholdTriggeredStepReportEntries(
      statesBySymbol: {
        'BTC': {
          'BTC:0': state(
            stepId: 'BTC:0',
            status: ThresholdStepStatus.executed,
          ),
          'BTC:1': state(
            stepId: 'BTC:1',
            status: ThresholdStepStatus.dismissed,
          ),
        },
      },
      plansBySymbol: const {'BTC': btcPlan},
    );

    expect(entries, hasLength(2));
    expect(entries[0]['status'], 'executed');
    expect(entries[0]['tier'], 1);
    expect(entries[1]['status'], 'dismissed');
    expect(entries[1]['tier'], 2);
  });

  test('missing plan skips safely', () {
    final entries = buildThresholdTriggeredStepReportEntries(
      statesBySymbol: {
        'BTC': {
          'BTC:0': state(stepId: 'BTC:0'),
        },
      },
      plansBySymbol: const <String, ThresholdPlan>{},
    );

    expect(entries, isEmpty);
  });

  test('out of range step index skips safely', () {
    final entries = buildThresholdTriggeredStepReportEntries(
      statesBySymbol: {
        'BTC': {
          'BTC:2': state(stepId: 'BTC:2'),
        },
      },
      plansBySymbol: const {'BTC': btcPlan},
    );

    expect(entries, isEmpty);
  });

  test('current price is included only when available', () {
    final entriesWithoutPrice = buildThresholdTriggeredStepReportEntries(
      statesBySymbol: {
        'BTC': {
          'BTC:0': state(stepId: 'BTC:0'),
        },
      },
      plansBySymbol: const {'BTC': btcPlan},
    );

    final entriesWithPrice = buildThresholdTriggeredStepReportEntries(
      statesBySymbol: {
        'BTC': {
          'BTC:0': state(stepId: 'BTC:0'),
        },
      },
      plansBySymbol: const {'BTC': btcPlan},
      pricesUsd: const {'BTC': 37950},
    );

    expect(entriesWithoutPrice.single.containsKey('currentPriceUsd'), isFalse);
    expect(entriesWithPrice.single['currentPriceUsd'], 37950.0);
  });
}
