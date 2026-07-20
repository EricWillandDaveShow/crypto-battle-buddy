import 'package:crypto_battle_buddy/battle_buddy_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = BattleBuddyEngine();

  ExecutionGateResult gate({
    double budget = 500,
    int buys = 1,
    int sells = 0,
    String mode = 'Balanced',
  }) =>
      engine.evaluateExecutionGate(
        budgetRemainingUsd: budget,
        buyAlertsCount: buys,
        sellAlertsCount: sells,
        modeLabel: mode,
      );

  test('no budget blocks execution', () {
    final res = gate(budget: 0);
    expect(res.canExecute, isFalse);
    expect(res.blockers, contains('NO_BUDGET'));
  });

  test('no alerts blocks execution', () {
    final res = gate(buys: 0, sells: 0);
    expect(res.canExecute, isFalse);
    expect(res.blockers, contains('NO_ALERTS'));
  });

  test('allowed path clamps chunk per mode', () {
    final resChill = gate(mode: 'Chill', budget: 1000, buys: 2);
    expect(resChill.canExecute, isTrue);
    expect(resChill.maxSpendUsd, inInclusiveRange(25, 150));

    final resBalanced = gate(mode: 'Balanced', budget: 500, buys: 1);
    expect(resBalanced.maxSpendUsd, inInclusiveRange(50, 300));

    final resYolo = gate(mode: 'YOLO', budget: 2000, buys: 1);
    expect(resYolo.maxSpendUsd, inInclusiveRange(100, 500));
  });
}
