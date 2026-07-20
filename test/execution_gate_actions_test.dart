import 'package:crypto_battle_buddy/battle_buddy_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('perAssetActions returns HOLD when gate blocks execution', () {
    final engine = BattleBuddyEngine();
    final gate = engine.evaluateExecutionGate(
      budgetRemainingUsd: 0,
      buyAlertsCount: 0,
      sellAlertsCount: 0,
      modeLabel: 'Balanced',
    );

    final actions = engine.perAssetActions(gate: gate);
    expect(actions.values.toSet(), {'HOLD'});
  });
}
