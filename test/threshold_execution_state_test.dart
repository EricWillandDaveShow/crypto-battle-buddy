import 'package:crypto_battle_buddy/battle_buddy_engine.dart';
import 'package:crypto_battle_buddy/models/threshold_plan.dart';
import 'package:crypto_battle_buddy/models/threshold_step_state.dart';
import 'package:crypto_battle_buddy/storage/threshold_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('confirmExecution creates executed state when step state is missing',
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

    final result = await engine.confirmExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 0,
      activeStepId: 'BTC:0',
    );

    expect(result, isTrue);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored.containsKey('BTC:0'), isTrue);
    expect(stored['BTC:0']!.status, ThresholdStepStatus.executed);
    expect(stored['BTC:0']!.wasTriggered, isFalse);
  });

  test('confirmExecution rejects already executed state', () async {
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

    await ThresholdStateStore.setStepState(
      symbol: 'BTC',
      stepId: 'BTC:0',
      status: ThresholdStepStatus.executed,
      wasTriggered: true,
      wasCompleted: false,
    );

    final result = await engine.confirmExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 0,
      activeStepId: 'BTC:0',
    );

    expect(result, isFalse);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored.containsKey('BTC:0'), isTrue);
    expect(stored['BTC:0']!.status, ThresholdStepStatus.executed);
  });

  test('confirmExecution rejects already dismissed state', () async {
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

    await ThresholdStateStore.setStepState(
      symbol: 'BTC',
      stepId: 'BTC:0',
      status: ThresholdStepStatus.dismissed,
      wasTriggered: true,
      wasCompleted: false,
    );

    final result = await engine.confirmExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 0,
      activeStepId: 'BTC:0',
    );

    expect(result, isFalse);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored.containsKey('BTC:0'), isTrue);
    expect(stored['BTC:0']!.status, ThresholdStepStatus.dismissed);
  });

  test('confirmExecution rejects wrong activeStepId', () async {
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

    final result = await engine.confirmExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 0,
      activeStepId: 'BTC:1',
    );

    expect(result, isFalse);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored, isEmpty);
  });

  test('confirmExecution rejects invalid tier index', () async {
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

    final result = await engine.confirmExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 1,
      activeStepId: 'BTC:1',
    );

    expect(result, isFalse);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored, isEmpty);
  });

  test('recordMissedExecution creates dismissed state when step state is missing',
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

    final result = await engine.recordMissedExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 0,
      activeStepId: 'BTC:0',
    );

    expect(result, isTrue);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored.containsKey('BTC:0'), isTrue);
    expect(stored['BTC:0']!.status, ThresholdStepStatus.dismissed);
    expect(stored['BTC:0']!.wasTriggered, isFalse);
  });

  test('recordMissedExecution rejects wrong activeStepId', () async {
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

    final result = await engine.recordMissedExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 0,
      activeStepId: 'BTC:1',
    );

    expect(result, isFalse);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored, isEmpty);
  });

  test('recordMissedExecution rejects invalid tier index', () async {
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

    final result = await engine.recordMissedExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 1,
      activeStepId: 'BTC:1',
    );

    expect(result, isFalse);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored, isEmpty);
  });

  test('recordMissedExecution rejects already executed state', () async {
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

    await ThresholdStateStore.setStepState(
      symbol: 'BTC',
      stepId: 'BTC:0',
      status: ThresholdStepStatus.executed,
      wasTriggered: true,
      wasCompleted: false,
    );

    final result = await engine.recordMissedExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 0,
      activeStepId: 'BTC:0',
    );

    expect(result, isFalse);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored.containsKey('BTC:0'), isTrue);
    expect(stored['BTC:0']!.status, ThresholdStepStatus.executed);
  });

  test('recordMissedExecution rejects already dismissed state', () async {
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

    await ThresholdStateStore.setStepState(
      symbol: 'BTC',
      stepId: 'BTC:0',
      status: ThresholdStepStatus.dismissed,
      wasTriggered: true,
      wasCompleted: false,
    );

    final result = await engine.recordMissedExecution(
      symbolUpper: 'BTC',
      plan: plan,
      tierIndex: 0,
      activeStepId: 'BTC:0',
    );

    expect(result, isFalse);

    final stored = await ThresholdStateStore.loadStepStates(symbol: 'BTC');
    expect(stored.containsKey('BTC:0'), isTrue);
    expect(stored['BTC:0']!.status, ThresholdStepStatus.dismissed);
  });
}
