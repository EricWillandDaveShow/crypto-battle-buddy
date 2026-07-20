import '../models/status_snapshot.dart';
import '../models/decision_result.dart';
import '../models/deployment_plan.dart';
import 'decision_engine.dart';

class StatusEngine {
  final DecisionEngine _decisionEngine;

  StatusEngine({DecisionEngine? decisionEngine})
      : _decisionEngine = decisionEngine ?? DecisionEngine();

  StatusSnapshot buildSnapshot({
    required DateTime timestamp,
    required Map<String, double> prices,
    required Map<String, List<double>> buyZonesBySymbol,
    required Map<String, List<double>> sellZonesBySymbol,
    DeploymentPlan? deploymentPlan,
  }) {
    final Map<String, DecisionResult> decisions = {};

    for (final symbol in prices.keys) {
      final price = prices[symbol]!;

      final buyZones = buyZonesBySymbol[symbol] ?? [];
      final sellZones = sellZonesBySymbol[symbol] ?? [];

      decisions[symbol] = _decisionEngine.evaluate(
        symbol: symbol,
        currentPrice: price,
        buyZones: buyZones,
        sellZones: sellZones,
      );
    }

    return StatusSnapshot(
      timestamp: timestamp,
      prices: prices,
      decisions: decisions,
      deploymentPlan: deploymentPlan,
    );
  }
}
