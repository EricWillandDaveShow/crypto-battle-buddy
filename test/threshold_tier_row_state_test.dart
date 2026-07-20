import 'package:crypto_battle_buddy/engine/threshold_tier_row_state.dart';
import 'package:crypto_battle_buddy/models/threshold_step_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ThresholdStepState state({
    ThresholdStepStatus status = ThresholdStepStatus.pending,
    bool wasTriggered = false,
  }) {
    return ThresholdStepState(
      stepId: 'BTC:0',
      status: status,
      updatedAt: DateTime.utc(2026),
      wasTriggered: wasTriggered,
    );
  }

  ThresholdTierRowState evaluate({
    ThresholdStepState? stepState,
    bool isArmed = true,
    bool isActiveStep = true,
    bool isActionState = true,
    bool hasPlan = true,
    bool hasPrice = true,
    bool hasRequiredPosition = true,
  }) {
    return evaluateThresholdTierRowState(
      state: stepState,
      isArmed: isArmed,
      isActiveStep: isActiveStep,
      isActionState: isActionState,
      hasPlan: hasPlan,
      hasPrice: hasPrice,
      hasRequiredPosition: hasRequiredPosition,
    );
  }

  test('pending triggered row shows TRIGGERED', () {
    final result = evaluate(stepState: state(wasTriggered: true));

    expect(result.displayState, ThresholdTierRowDisplayState.triggered);
    expect(result.labelText, 'TRIGGERED');
    expect(result.helperText, 'TRIGGERED — review execution');
  });

  test('executed overrides triggered', () {
    final result = evaluate(
      stepState: state(
        status: ThresholdStepStatus.executed,
        wasTriggered: true,
      ),
    );

    expect(result.displayState, ThresholdTierRowDisplayState.executed);
    expect(result.labelText, 'EXECUTED');
  });

  test('dismissed overrides triggered', () {
    final result = evaluate(
      stepState: state(
        status: ThresholdStepStatus.dismissed,
        wasTriggered: true,
      ),
    );

    expect(result.displayState, ThresholdTierRowDisplayState.missed);
    expect(result.labelText, 'MISSED');
  });

  test('pending untriggered row is not triggered', () {
    final result = evaluate(stepState: state());

    expect(result.displayState, ThresholdTierRowDisplayState.pending);
    expect(result.labelText, isNull);
    expect(result.helperText, 'Adjust for plan');
  });

  test('armed triggered pending row can mark missed when inactive', () {
    final result = evaluate(
      stepState: state(wasTriggered: true),
      isArmed: true,
      isActiveStep: false,
    );

    expect(result.canMarkMissed, isTrue);
  });

  test('not armed triggered pending row cannot mark missed', () {
    final result = evaluate(
      stepState: state(wasTriggered: true),
      isArmed: false,
      isActiveStep: false,
    );

    expect(result.canMarkMissed, isFalse);
  });

  test('untriggered pending inactive row cannot mark missed', () {
    final result = evaluate(
      stepState: state(),
      isArmed: true,
      isActiveStep: false,
    );

    expect(result.canMarkMissed, isFalse);
  });

  test('execute eligibility remains strict', () {
    expect(evaluate(stepState: state()).canExecute, isTrue);
    expect(evaluate(stepState: state(), isArmed: false).canExecute, isFalse);
    expect(
      evaluate(stepState: state(), isActiveStep: false).canExecute,
      isFalse,
    );
    expect(
      evaluate(stepState: state(), isActionState: false).canExecute,
      isFalse,
    );
    expect(evaluate(stepState: state(), hasPlan: false).canExecute, isFalse);
    expect(evaluate(stepState: state(), hasPrice: false).canExecute, isFalse);
    expect(
      evaluate(stepState: state(), hasRequiredPosition: false).canExecute,
      isFalse,
    );
    expect(
      evaluate(
        stepState: state(
          status: ThresholdStepStatus.executed,
          wasTriggered: true,
        ),
      ).canExecute,
      isFalse,
    );
  });
}
