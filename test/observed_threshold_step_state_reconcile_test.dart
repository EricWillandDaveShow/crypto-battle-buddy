import 'package:crypto_battle_buddy/engine/observed_threshold_step_state_reconcile.dart';
import 'package:crypto_battle_buddy/models/threshold_step_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ThresholdStepState state(
    String stepId,
    ThresholdStepStatus status,
    DateTime updatedAt, {
    bool wasTriggered = false,
  }) {
    return ThresholdStepState(
      stepId: stepId,
      status: status,
      updatedAt: updatedAt,
      wasTriggered: wasTriggered,
    );
  }

  test('reconcile observed crossing preserves newer terminal persisted state',
      () {
    final originallyLoaded = <String, ThresholdStepState>{
      'BTC:0': state(
        'BTC:0',
        ThresholdStepStatus.pending,
        DateTime.utc(2026, 1, 1),
      ),
    };
    final observed = <String, ThresholdStepState>{
      'BTC:0': state(
        'BTC:0',
        ThresholdStepStatus.pending,
        DateTime.utc(2026, 1, 2),
        wasTriggered: true,
      ),
    };
    final latestPersisted = <String, ThresholdStepState>{
      'BTC:0': state(
        'BTC:0',
        ThresholdStepStatus.executed,
        DateTime.utc(2026, 1, 3),
      ),
    };

    final reconciled = reconcileObservedThresholdStepStates(
      originallyLoaded: originallyLoaded,
      observed: observed,
      latestPersisted: latestPersisted,
    );

    expect(reconciled['BTC:0']!.status, ThresholdStepStatus.executed);
    expect(reconciled['BTC:0']!.updatedAt, DateTime.utc(2026, 1, 3));
  });

  test('reconcile observed crossing preserves newer reset pending state', () {
    final originallyLoaded = <String, ThresholdStepState>{
      'BTC:0': state(
        'BTC:0',
        ThresholdStepStatus.pending,
        DateTime.utc(2026, 1, 1),
      ),
    };
    final observed = <String, ThresholdStepState>{
      'BTC:0': state(
        'BTC:0',
        ThresholdStepStatus.pending,
        DateTime.utc(2026, 1, 2),
        wasTriggered: true,
      ),
    };
    final latestPersisted = <String, ThresholdStepState>{
      'BTC:0': state(
        'BTC:0',
        ThresholdStepStatus.pending,
        DateTime.utc(2026, 1, 3),
      ),
    };

    final reconciled = reconcileObservedThresholdStepStates(
      originallyLoaded: originallyLoaded,
      observed: observed,
      latestPersisted: latestPersisted,
    );

    expect(reconciled['BTC:0']!.status, ThresholdStepStatus.pending);
    expect(reconciled['BTC:0']!.wasTriggered, isFalse);
    expect(reconciled['BTC:0']!.updatedAt, DateTime.utc(2026, 1, 3));
  });

  test('reconcile observed crossing does not resurrect removed state', () {
    final originallyLoaded = <String, ThresholdStepState>{
      'BTC:0': state(
        'BTC:0',
        ThresholdStepStatus.pending,
        DateTime.utc(2026, 1, 1),
      ),
    };
    final observed = <String, ThresholdStepState>{
      'BTC:0': state(
        'BTC:0',
        ThresholdStepStatus.pending,
        DateTime.utc(2026, 1, 2),
        wasTriggered: true,
      ),
    };

    final reconciled = reconcileObservedThresholdStepStates(
      originallyLoaded: originallyLoaded,
      observed: observed,
      latestPersisted: const <String, ThresholdStepState>{},
    );

    expect(reconciled.containsKey('BTC:0'), isFalse);
  });

  test(
      'reconcile observed crossing allows new observed step when not previously loaded',
      () {
    final observed = <String, ThresholdStepState>{
      'BTC:0': state(
        'BTC:0',
        ThresholdStepStatus.pending,
        DateTime.utc(2026, 1, 2),
        wasTriggered: true,
      ),
    };

    final reconciled = reconcileObservedThresholdStepStates(
      originallyLoaded: const <String, ThresholdStepState>{},
      observed: observed,
      latestPersisted: const <String, ThresholdStepState>{},
    );

    expect(reconciled.containsKey('BTC:0'), isTrue);
    expect(reconciled['BTC:0']!.status, ThresholdStepStatus.pending);
    expect(reconciled['BTC:0']!.wasTriggered, isTrue);
  });
}
