import '../models/deployment_plan.dart';
import '../models/execution_intent.dart';
import '../models/execution_mode.dart';

class ExecutionEngine {
  ExecutionIntent buildIntent({
    required DeploymentPlan plan,
    required ExecutionMode mode,
  }) {
    if (plan.totalToDeploy == 0) {
      return ExecutionIntent(
        mode: mode,
        perAssetAmounts: const {},
        timestamp: DateTime.now(),
        message: 'No plan actions pending.',
      );
    }

    final message = mode == ExecutionMode.dryRun
        ? 'DRY RUN — No trades executed.'
        : 'ARMED — Trades authorized for execution.';

    return ExecutionIntent(
      mode: mode,
      perAssetAmounts: plan.perAssetAmounts,
      timestamp: DateTime.now(),
      message: message,
    );
  }
}
