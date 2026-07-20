import 'decision_result.dart';
import 'deployment_plan.dart';

class StatusSnapshot {
  final DateTime timestamp;
  final Map<String, double> prices;
  final Map<String, DecisionResult> decisions;
  final DeploymentPlan? deploymentPlan;

  const StatusSnapshot({
    required this.timestamp,
    required this.prices,
    required this.decisions,
    this.deploymentPlan,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'prices': prices,
      'decisions': decisions.map((symbol, decision) {
        return MapEntry(symbol, {
          'state': decision.state.name,
          'message': decision.message,
          'metadata': decision.metadata,
        });
      }),
      'deploymentPlan': deploymentPlan == null
          ? null
          : {
              'perAssetAmounts': deploymentPlan!.perAssetAmounts,
              'totalToDeploy': deploymentPlan!.totalToDeploy,
              'message': deploymentPlan!.message,
            },
    };
  }
}
