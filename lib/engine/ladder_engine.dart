import '../models/alert_event.dart';
import '../models/allocation_target.dart';
import '../models/monthly_budget.dart';
import '../models/deployment_plan.dart';
import '../models/ladder_policy.dart';
import 'allocation_engine.dart';

class LadderEngine {
  final AllocationEngine _allocationEngine = AllocationEngine();

  DeploymentPlan buildPlanFromAlerts({
    required List<AlertEvent> alerts,
    required List<AllocationTarget> targets,
    required MonthlyBudget budget,
    required LadderPolicy policy,
  }) {
    if (alerts.isEmpty) {
      return const DeploymentPlan(
        perAssetAmounts: {},
        totalToDeploy: 0,
        message: 'No watch alerts. No plan actions.',
      );
    }

    final buyAlerts = alerts.where((a) => a.type == AlertType.buyZone).toList();
    if (buyAlerts.isEmpty) {
      return const DeploymentPlan(
        perAssetAmounts: {},
        totalToDeploy: 0,
        message: 'No watch alerts. No plan actions.',
      );
    }

    final eligibleSymbols = buyAlerts.map((a) => a.symbol).toSet().toList();
    final amountToDeploy =
        policy.deployNowAmount <= budget.remaining ? policy.deployNowAmount : budget.remaining;

    if (amountToDeploy == 0) {
      return const DeploymentPlan(
        perAssetAmounts: {},
        totalToDeploy: 0,
        message: 'No funds available to deploy this month.',
      );
    }

    Map<String, double> perAsset = {};

    if (policy.mode == LadderMode.equalSplit) {
      final split = (amountToDeploy / eligibleSymbols.length);
      for (final s in eligibleSymbols) {
        perAsset[s] = double.parse(split.toStringAsFixed(2));
      }
    } else {
      final eligibleTargets =
          targets.where((t) => eligibleSymbols.contains(t.symbol)).toList();

      final weightSum =
          eligibleTargets.fold<double>(0.0, (sum, t) => sum + t.weight);
      if (eligibleTargets.isEmpty || weightSum <= 0) {
        final split = (amountToDeploy / eligibleSymbols.length);
        for (final s in eligibleSymbols) {
          perAsset[s] = double.parse(split.toStringAsFixed(2));
        }
      } else {
        final normalizedTargets = eligibleTargets
            .map((t) => AllocationTarget(
                  symbol: t.symbol,
                  weight: t.weight / weightSum,
                ))
            .toList();

        final plan = _allocationEngine.buildDeploymentPlan(
          targets: normalizedTargets,
          budget: budget,
          deployNowAmount: amountToDeploy,
        );
        perAsset = Map<String, double>.from(plan.perAssetAmounts);
      }
    }

    for (final t in targets) {
      perAsset.putIfAbsent(t.symbol, () => 0.0);
    }

    double total = 0.0;
    perAsset.updateAll((key, value) {
      final rounded = double.parse(value.toStringAsFixed(2));
      total += rounded;
      return rounded;
    });

    return DeploymentPlan(
      perAssetAmounts: perAsset,
      totalToDeploy: double.parse(total.toStringAsFixed(2)),
      message: 'Plan created from watch alerts.',
    );
  }

  MonthlyBudget applySpend({
    required MonthlyBudget budget,
    required DeploymentPlan plan,
  }) {
    final double raw =
        budget.spentThisMonth + plan.totalToDeploy;

    final double newSpent =
        raw > budget.monthlyLimit ? budget.monthlyLimit : raw;

    return MonthlyBudget(
      monthlyLimit: budget.monthlyLimit,
      spentThisMonth: newSpent,
      month: budget.month,
    );
  }
}
