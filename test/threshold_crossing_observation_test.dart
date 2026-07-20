import 'dart:convert';

import 'package:crypto_battle_buddy/battle_buddy_engine.dart';
import 'package:crypto_battle_buddy/models/threshold_plan.dart';
import 'package:crypto_battle_buddy/models/threshold_step_state.dart';
import 'package:crypto_battle_buddy/storage/threshold_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'observeThresholdCrossings uses persisted plan and marks crossed pending step',
      () async {
    SharedPreferences.setMockInitialValues({});
    final engine = BattleBuddyEngine();

    const plan = ThresholdPlan(
      assetSymbol: 'BTC',
      anchorPriceUsd: 42000,
      seededFromLive: true,
      steps: [
        ThresholdStep(
          triggerPriceUsd: 38000,
          action: 'BUY',
          percentOfPosition: 25,
        ),
      ],
    );

    await saveThresholdPlan(plan, source: 'test');
    final prefs = await SharedPreferences.getInstance();
    final persistedPlanBefore = prefs.getString('threshold_plan_BTC');
    await ThresholdStateStore.saveStepStates(
      symbol: 'BTC',
      states: {
        'BTC:0': ThresholdStepState(
          stepId: 'BTC:0',
          status: ThresholdStepStatus.pending,
          updatedAt: DateTime.utc(2026),
        ),
      },
    );

    final delta = await engine.observeThresholdCrossings(
      prices: {'btc': 37900},
    );

    expect(delta.containsKey('BTC'), isTrue);
    final updated = delta['BTC']!['BTC:0']!;
    expect(updated.status, ThresholdStepStatus.pending);
    expect(updated.wasTriggered, isTrue);
    expect(updated.wasCompleted, isFalse);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored['BTC:0']!.wasTriggered, isTrue);
    expect(stored['BTC:0']!.status, ThresholdStepStatus.pending);
    expect(prefs.getString('threshold_plan_BTC'), persistedPlanBefore);
  });

  test('observeThresholdCrossings treats missing step states as pending',
      () async {
    SharedPreferences.setMockInitialValues({});
    final engine = BattleBuddyEngine();

    const plan = ThresholdPlan(
      assetSymbol: 'BTC',
      anchorPriceUsd: 42000,
      seededFromLive: true,
      steps: [
        ThresholdStep(
          triggerPriceUsd: 38000,
          action: 'BUY',
          percentOfPosition: 25,
        ),
      ],
    );

    await saveThresholdPlan(plan, source: 'test');

    final delta = await engine.observeThresholdCrossings(
      prices: {'btc': 37900},
    );

    expect(delta.containsKey('BTC'), isTrue);
    expect(delta['BTC']!.containsKey('BTC:0'), isTrue);
    final updated = delta['BTC']!['BTC:0']!;
    expect(updated.status, ThresholdStepStatus.pending);
    expect(updated.wasTriggered, isTrue);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored.containsKey('BTC:0'), isTrue);
    expect(stored['BTC:0']!.status, ThresholdStepStatus.pending);
    expect(stored['BTC:0']!.wasTriggered, isTrue);
  });

  test('first ETH price durably initializes plan without false crossings',
      () async {
    SharedPreferences.setMockInitialValues({});
    final engine = BattleBuddyEngine();

    final delta = await engine.observeThresholdCrossings(
      prices: {'ETH': 3000},
    );

    expect(delta, isEmpty);
    final strictPlan = await loadPersistedThresholdPlanStrict('ETH');
    expect(strictPlan.status, PersistedThresholdPlanLoadStatus.valid);
    expect(strictPlan.plan, isNotNull);
    expect(strictPlan.plan!.anchorPriceUsd, 3000);
    expect(strictPlan.plan!.seededFromLive, isTrue);
    final triggerPrices =
        strictPlan.plan!.steps.map((step) => step.triggerPriceUsd).toList();
    expect(triggerPrices[0], closeTo(2700, 0.000001));
    expect(triggerPrices[1], closeTo(2400, 0.000001));
    expect(triggerPrices[2], closeTo(3300, 0.000001));
    expect(triggerPrices[3], closeTo(3750, 0.000001));
    expect(
      await ThresholdStateStore.loadStepStates(symbol: 'ETH'),
      isEmpty,
    );
  });

  test('valid unseeded one-dollar user plan is never reseeded', () async {
    final raw = jsonEncode({
      'assetSymbol': 'DOGE',
      'anchorPriceUsd': 1.0,
      'seededFromLive': false,
      'steps': [
        {
          'triggerPriceUsd': 0.9,
          'action': 'BUY',
          'percentOfPosition': 25,
        },
      ],
    });
    SharedPreferences.setMockInitialValues({
      'threshold_plan_DOGE': raw,
    });
    final engine = BattleBuddyEngine();

    final delta = await engine.observeThresholdCrossings(
      prices: {'DOGE': 3000},
    );

    expect(delta, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('threshold_plan_DOGE'), raw);
    final strictPlan = await loadPersistedThresholdPlanStrict('DOGE');
    expect(strictPlan.status, PersistedThresholdPlanLoadStatus.valid);
    expect(strictPlan.plan!.anchorPriceUsd, 1.0);
    expect(strictPlan.plan!.seededFromLive, isFalse);
  });

  test('malformed ETH plan is replaced before crossing observation', () async {
    SharedPreferences.setMockInitialValues({
      'threshold_plan_ETH': 'not valid json',
    });
    final engine = BattleBuddyEngine();

    final delta = await engine.observeThresholdCrossings(
      prices: {'ETH': 3000},
    );

    expect(delta, isEmpty);
    final strictPlan = await loadPersistedThresholdPlanStrict('ETH');
    expect(strictPlan.status, PersistedThresholdPlanLoadStatus.valid);
    expect(strictPlan.plan!.anchorPriceUsd, 3000);
    expect(strictPlan.plan!.seededFromLive, isTrue);
    expect(
      await ThresholdStateStore.loadStepStates(symbol: 'ETH'),
      isEmpty,
    );
  });

  test('empty prices do not initialize until the first valid price', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = BattleBuddyEngine();

    expect(await engine.observeThresholdCrossings(prices: {}), isEmpty);
    expect(
      (await loadPersistedThresholdPlanStrict('ETH')).status,
      PersistedThresholdPlanLoadStatus.missing,
    );
    expect(
      await ThresholdStateStore.loadStepStates(symbol: 'ETH'),
      isEmpty,
    );

    final delta = await engine.observeThresholdCrossings(
      prices: {'ETH': 3000},
    );

    expect(delta, isEmpty);
    final strictPlan = await loadPersistedThresholdPlanStrict('ETH');
    expect(strictPlan.status, PersistedThresholdPlanLoadStatus.valid);
    expect(strictPlan.plan!.anchorPriceUsd, 3000);
    expect(
      await ThresholdStateStore.loadStepStates(symbol: 'ETH'),
      isEmpty,
    );
  });

  test('purged dynamic asset initializes as new without stale trigger state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final engine = BattleBuddyEngine();
    const oldPlan = ThresholdPlan(
      assetSymbol: 'DOGE',
      anchorPriceUsd: 0.2,
      seededFromLive: true,
      steps: [
        ThresholdStep(
          triggerPriceUsd: 0.15,
          action: 'BUY',
          percentOfPosition: 25,
        ),
      ],
    );
    await saveThresholdPlan(oldPlan, source: 'test');
    await ThresholdStateStore.saveStepStates(
      symbol: 'DOGE',
      states: {
        'DOGE:0': ThresholdStepState(
          stepId: 'DOGE:0',
          status: ThresholdStepStatus.pending,
          updatedAt: DateTime.utc(2026),
          wasTriggered: true,
        ),
      },
    );

    await engine.purgeAsset('DOGE');
    expect(
      (await loadPersistedThresholdPlanStrict('DOGE')).status,
      PersistedThresholdPlanLoadStatus.missing,
    );
    expect(
      await ThresholdStateStore.loadStepStates(symbol: 'DOGE'),
      isEmpty,
    );

    final delta = await engine.observeThresholdCrossings(
      prices: {'DOGE': 0.12},
    );

    expect(delta, isEmpty);
    final strictPlan = await loadPersistedThresholdPlanStrict('DOGE');
    expect(strictPlan.status, PersistedThresholdPlanLoadStatus.valid);
    expect(strictPlan.plan!.anchorPriceUsd, 0.12);
    expect(strictPlan.plan!.seededFromLive, isTrue);
    expect(
      await ThresholdStateStore.loadStepStates(symbol: 'DOGE'),
      isEmpty,
    );
  });
}
