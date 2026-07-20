import 'package:crypto_battle_buddy/engine/threshold_triggered_report_assembly.dart';
import 'package:crypto_battle_buddy/models/threshold_plan.dart';
import 'package:crypto_battle_buddy/models/threshold_step_state.dart';
import 'package:crypto_battle_buddy/storage/threshold_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const btcPlan = ThresholdPlan(
    assetSymbol: 'BTC',
    anchorPriceUsd: 40000,
    seededFromLive: true,
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

  test('persisted triggered state appears in threshold report entries',
      () async {
    SharedPreferences.setMockInitialValues({});
    await saveThresholdPlan(btcPlan, source: 'test');
    await ThresholdStateStore.saveStepStates(
      symbol: 'BTC',
      states: {
        'BTC:0': state(stepId: 'BTC:0'),
      },
    );

    final entries = await buildThresholdTriggeredStepsForReport(
      symbols: const ['BTC'],
      thresholdStateDelta: const <String, Map<String, ThresholdStepState>>{},
      pricesUsd: const {'BTC': 37950},
    );

    expect(entries, [
      {
        'symbol': 'BTC',
        'stepId': 'BTC:0',
        'tier': 1,
        'action': 'BUY',
        'triggerPriceUsd': 38000.0,
        'status': 'pending',
        'wasTriggered': true,
        'updatedAt': updatedAt.toIso8601String(),
        'currentPriceUsd': 37950.0,
      },
    ]);
  });

  test('same-tick delta appears when persisted state is empty', () async {
    SharedPreferences.setMockInitialValues({});
    await saveThresholdPlan(btcPlan, source: 'test');

    final entries = await buildThresholdTriggeredStepsForReport(
      symbols: const ['BTC'],
      thresholdStateDelta: {
        'BTC': {
          'BTC:0': state(stepId: 'BTC:0'),
        },
      },
      pricesUsd: const {'BTC': 37950},
    );

    expect(entries, hasLength(1));
    expect(entries.single['symbol'], 'BTC');
    expect(entries.single['stepId'], 'BTC:0');
    expect(entries.single['status'], 'pending');
    expect(entries.single['currentPriceUsd'], 37950.0);
  });

  test('terminal triggered statuses are preserved', () async {
    SharedPreferences.setMockInitialValues({});
    await saveThresholdPlan(btcPlan, source: 'test');
    await ThresholdStateStore.saveStepStates(
      symbol: 'BTC',
      states: {
        'BTC:0': state(
          stepId: 'BTC:0',
          status: ThresholdStepStatus.executed,
        ),
        'BTC:1': state(
          stepId: 'BTC:1',
          status: ThresholdStepStatus.dismissed,
        ),
      },
    );

    final entries = await buildThresholdTriggeredStepsForReport(
      symbols: const ['BTC'],
      thresholdStateDelta: const <String, Map<String, ThresholdStepState>>{},
      pricesUsd: const {'BTC': 46100},
    );

    expect(entries, hasLength(2));
    expect(entries[0]['status'], 'executed');
    expect(entries[1]['status'], 'dismissed');
  });
}
