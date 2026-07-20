import '../models/allocation_target.dart';
import '../models/monthly_budget.dart';
import '../models/deployment_plan.dart';

class AllocationEngine {
  DeploymentPlan buildDeploymentPlan({
    required List<AllocationTarget> targets,
    required MonthlyBudget budget,
    required double deployNowAmount,
  }) {
    final weightSum = targets.fold<double>(0.0, (sum, t) => sum + t.weight);
    if (weightSum < 0.999 || weightSum > 1.001) {
      throw ArgumentError('Allocation weights must sum to 1.0');
    }

    final cappedDeploy = deployNowAmount <= budget.remaining ? deployNowAmount : budget.remaining;

    final perAsset = <String, double>{};
    for (final t in targets) {
      final amt = (cappedDeploy * t.weight);
      perAsset[t.symbol] = double.parse(amt.toStringAsFixed(2));
    }

    final total = perAsset.values.fold<double>(0.0, (sum, v) => sum + v);

    final message = cappedDeploy == 0
        ? 'No funds available to deploy this month.'
        : 'Deployment plan created.';

    return DeploymentPlan(
      perAssetAmounts: perAsset,
      totalToDeploy: double.parse(total.toStringAsFixed(2)),
      message: message,
    );
  }
}
