import 'dart:convert';

import 'package:crypto_battle_buddy/models/threshold_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadThresholdPlan returns persisted per-symbol plan when present',
      () async {
    SharedPreferences.setMockInitialValues({
      'threshold_plan_BTC': jsonEncode({
        'assetSymbol': 'BTC',
        'anchorPriceUsd': 42000,
        'seededFromLive': true,
        'steps': [
          {
            'triggerPriceUsd': 38000,
            'action': 'BUY',
            'percentOfPosition': 25,
          },
        ],
      }),
    });

    final plan = await loadThresholdPlan('btc');

    expect(plan.assetSymbol, 'BTC');
    expect(plan.anchorPriceUsd, 42000);
    expect(plan.seededFromLive, isTrue);
    expect(plan.steps.first.triggerPriceUsd, 38000);
    expect(plan.steps.first.action, 'BUY');
    expect(plan.steps.first.percentOfPosition, 25);
  });

  test('loadThresholdPlan returns default plan when no persisted key exists',
      () async {
    SharedPreferences.setMockInitialValues({});

    final plan = await loadThresholdPlan('btc');

    expect(plan.assetSymbol, 'BTC');
    expect(plan.anchorPriceUsd, 1.0);
    expect(plan.seededFromLive, isFalse);
    expect(plan.steps.length, 4);
    expect(plan.steps[0].triggerPriceUsd, 0.90);
    expect(plan.steps[0].action, 'BUY');
    expect(plan.steps[0].percentOfPosition, 25);
    expect(plan.steps[1].triggerPriceUsd, 0.80);
    expect(plan.steps[1].action, 'BUY');
    expect(plan.steps[1].percentOfPosition, 25);
    expect(plan.steps[2].triggerPriceUsd, 1.10);
    expect(plan.steps[2].action, 'SELL');
    expect(plan.steps[2].percentOfPosition, 25);
    expect(plan.steps[3].triggerPriceUsd, 1.25);
    expect(plan.steps[3].action, 'SELL');
    expect(plan.steps[3].percentOfPosition, 25);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('threshold_plan_BTC'), isNull);
  });

  test('strict load reports missing without substituting a default plan',
      () async {
    SharedPreferences.setMockInitialValues({});

    final result = await loadPersistedThresholdPlanStrict('btc');

    expect(result.status, PersistedThresholdPlanLoadStatus.missing);
    expect(result.plan, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('threshold_plan_BTC'), isNull);
  });

  test('strict load reports malformed persisted data as invalid', () async {
    SharedPreferences.setMockInitialValues({
      'threshold_plan_ETH': 'not valid json',
    });

    final result = await loadPersistedThresholdPlanStrict('eth');

    expect(result.status, PersistedThresholdPlanLoadStatus.invalid);
    expect(result.plan, isNull);
  });

  test('strict load preserves a valid unseeded one-dollar plan', () async {
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

    final result = await loadPersistedThresholdPlanStrict('doge');

    expect(result.status, PersistedThresholdPlanLoadStatus.valid);
    expect(result.plan, isNotNull);
    expect(result.plan!.anchorPriceUsd, 1.0);
    expect(result.plan!.seededFromLive, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('threshold_plan_DOGE'), raw);
  });

  test('saveThresholdPlan persists plan loadThresholdPlan can read back',
      () async {
    SharedPreferences.setMockInitialValues({});

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
        ThresholdStep(
          triggerPriceUsd: 46000,
          action: 'SELL',
          percentOfPosition: 25,
        ),
      ],
    );

    await saveThresholdPlan(plan, source: 'test');
    final loaded = await loadThresholdPlan('btc');

    expect(loaded.assetSymbol, 'BTC');
    expect(loaded.anchorPriceUsd, 42000);
    expect(loaded.seededFromLive, isTrue);
    expect(loaded.steps.length, 2);
    expect(loaded.steps[0].triggerPriceUsd, 38000);
    expect(loaded.steps[0].action, 'BUY');
    expect(loaded.steps[0].percentOfPosition, 25);
    expect(loaded.steps[1].triggerPriceUsd, 46000);
    expect(loaded.steps[1].action, 'SELL');
    expect(loaded.steps[1].percentOfPosition, 25);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('threshold_plan_BTC'), isNotNull);
  });

  test('saveThresholdPlan keeps BTC and ETH plans under separate keys',
      () async {
    SharedPreferences.setMockInitialValues({});

    const btcPlan = ThresholdPlan(
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
    const ethPlan = ThresholdPlan(
      assetSymbol: 'ETH',
      anchorPriceUsd: 3000,
      seededFromLive: true,
      steps: [
        ThresholdStep(
          triggerPriceUsd: 3600,
          action: 'SELL',
          percentOfPosition: 25,
        ),
      ],
    );

    await saveThresholdPlan(btcPlan, source: 'test');
    await saveThresholdPlan(ethPlan, source: 'test');
    final loadedBtc = await loadThresholdPlan('btc');
    final loadedEth = await loadThresholdPlan('eth');

    expect(loadedBtc.assetSymbol, 'BTC');
    expect(loadedBtc.anchorPriceUsd, 42000);
    expect(loadedBtc.steps.length, 1);
    expect(loadedBtc.steps[0].triggerPriceUsd, 38000);
    expect(loadedBtc.steps[0].action, 'BUY');
    expect(loadedBtc.steps[0].percentOfPosition, 25);

    expect(loadedEth.assetSymbol, 'ETH');
    expect(loadedEth.anchorPriceUsd, 3000);
    expect(loadedEth.steps.length, 1);
    expect(loadedEth.steps[0].triggerPriceUsd, 3600);
    expect(loadedEth.steps[0].action, 'SELL');
    expect(loadedEth.steps[0].percentOfPosition, 25);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('threshold_plan_BTC'), isNotNull);
    expect(prefs.getString('threshold_plan_ETH'), isNotNull);
  });

  test('loadThresholdPlan returns default plan when persisted JSON is invalid',
      () async {
    SharedPreferences.setMockInitialValues({
      'threshold_plan_BTC': 'not valid json',
    });

    final plan = await loadThresholdPlan('btc');

    expect(plan.assetSymbol, 'BTC');
    expect(plan.anchorPriceUsd, 1.0);
    expect(plan.seededFromLive, isFalse);
    expect(plan.steps.length, 4);
    expect(plan.steps[0].triggerPriceUsd, 0.90);
    expect(plan.steps[0].action, 'BUY');
    expect(plan.steps[0].percentOfPosition, 25);
    expect(plan.steps[1].triggerPriceUsd, 0.80);
    expect(plan.steps[1].action, 'BUY');
    expect(plan.steps[1].percentOfPosition, 25);
    expect(plan.steps[2].triggerPriceUsd, 1.10);
    expect(plan.steps[2].action, 'SELL');
    expect(plan.steps[2].percentOfPosition, 25);
    expect(plan.steps[3].triggerPriceUsd, 1.25);
    expect(plan.steps[3].action, 'SELL');
    expect(plan.steps[3].percentOfPosition, 25);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('threshold_plan_BTC'), 'not valid json');
  });

  test(
      'loadThresholdPlan returns default plan when persisted plan object is malformed',
      () async {
    final raw = jsonEncode({
      'assetSymbol': 'BTC',
      'steps': [],
    });
    SharedPreferences.setMockInitialValues({
      'threshold_plan_BTC': raw,
    });

    final plan = await loadThresholdPlan('btc');

    expect(plan.assetSymbol, 'BTC');
    expect(plan.anchorPriceUsd, 1.0);
    expect(plan.seededFromLive, isFalse);
    expect(plan.steps.length, 4);
    expect(plan.steps[0].triggerPriceUsd, 0.90);
    expect(plan.steps[0].action, 'BUY');
    expect(plan.steps[0].percentOfPosition, 25);
    expect(plan.steps[1].triggerPriceUsd, 0.80);
    expect(plan.steps[1].action, 'BUY');
    expect(plan.steps[1].percentOfPosition, 25);
    expect(plan.steps[2].triggerPriceUsd, 1.10);
    expect(plan.steps[2].action, 'SELL');
    expect(plan.steps[2].percentOfPosition, 25);
    expect(plan.steps[3].triggerPriceUsd, 1.25);
    expect(plan.steps[3].action, 'SELL');
    expect(plan.steps[3].percentOfPosition, 25);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('threshold_plan_BTC'), raw);
  });

  test('saveThresholdPlan persists non-core symbol plans', () async {
    SharedPreferences.setMockInitialValues({});

    const dogePlan = ThresholdPlan(
      assetSymbol: 'DOGE',
      anchorPriceUsd: 0.12,
      seededFromLive: true,
      steps: [
        ThresholdStep(
          triggerPriceUsd: 0.10,
          action: 'BUY',
          percentOfPosition: 25,
        ),
        ThresholdStep(
          triggerPriceUsd: 0.16,
          action: 'SELL',
          percentOfPosition: 25,
        ),
      ],
    );

    await saveThresholdPlan(dogePlan, source: 'test');
    final loaded = await loadThresholdPlan('doge');

    expect(loaded.assetSymbol, 'DOGE');
    expect(loaded.anchorPriceUsd, 0.12);
    expect(loaded.seededFromLive, isTrue);
    expect(loaded.steps.length, 2);
    expect(loaded.steps[0].triggerPriceUsd, 0.10);
    expect(loaded.steps[0].action, 'BUY');
    expect(loaded.steps[0].percentOfPosition, 25);
    expect(loaded.steps[1].triggerPriceUsd, 0.16);
    expect(loaded.steps[1].action, 'SELL');
    expect(loaded.steps[1].percentOfPosition, 25);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('threshold_plan_DOGE'), isNotNull);
  });
}
