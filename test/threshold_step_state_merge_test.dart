import 'package:crypto_battle_buddy/engine/threshold_step_state_merge.dart';
import 'package:crypto_battle_buddy/models/threshold_step_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'mergeExternalStepStates preserves newer terminal local state over stale external state',
      () {
    final local = <String, Map<String, ThresholdStepState>>{
      'BTC': {
        'BTC:0': ThresholdStepState(
          stepId: 'BTC:0',
          status: ThresholdStepStatus.executed,
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      },
      'SOL': {
        'SOL:0': ThresholdStepState(
          stepId: 'SOL:0',
          status: ThresholdStepStatus.pending,
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      },
    };

    final incoming = <String, Map<String, ThresholdStepState>>{
      'BTC': {
        'BTC:0': ThresholdStepState(
          stepId: 'BTC:0',
          status: ThresholdStepStatus.pending,
          updatedAt: DateTime.utc(2026, 1),
          wasTriggered: true,
        ),
      },
      'ETH': {
        'ETH:0': ThresholdStepState(
          stepId: 'ETH:0',
          status: ThresholdStepStatus.pending,
          updatedAt: DateTime.utc(2026, 1),
          wasTriggered: true,
        ),
      },
    };

    final merged = mergeExternalStepStates(
      current: local,
      incoming: incoming,
    );

    expect(merged['BTC']!['BTC:0']!.status, ThresholdStepStatus.executed);
    expect(merged['ETH']!['ETH:0']!.status, ThresholdStepStatus.pending);
    expect(merged['ETH']!['ETH:0']!.wasTriggered, isTrue);
    expect(merged['SOL']!['SOL:0']!.status, ThresholdStepStatus.pending);
  });
}
