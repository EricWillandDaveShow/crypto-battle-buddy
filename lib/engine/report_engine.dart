import '../models/strategy_report.dart';
import '../models/feed_health.dart';
import '../models/heat_mode.dart';
import '../models/deployment_plan.dart';
import '../models/execution_intent.dart';
import 'threshold_triggered_report_summary.dart';

class ReportEngine {
  StrategyReport build({
    required String profileName,
    required String mode,
    required String feed,
    required FeedHealth feedHealth,
    required HeatModeState heat,
    required Map<String, dynamic> snapshotJson,
    required List<Map<String, dynamic>> alertsJson,
    required DeploymentPlan deploymentPlan,
    required ExecutionIntent intent,
    required Map<String, dynamic> budgetJson,
    required Map<String, dynamic> positionsJson,
    required Map<String, dynamic> pnlJson,
    required Map<String, dynamic> rebalanceJson,
    required Map<String, dynamic>? lastLedgerRecord,
    required Map<String, dynamic> marketRegime,
    required Map<String, String> guidance,
    required Map<String, dynamic> holdings,
    required Map<String, dynamic> portfolio,
    required String alertsSummary,
    required List<Map<String, dynamic>> alertsEvents,
    required Map<String, dynamic> executionGate,
    required Map<String, String> perAssetActions,
    required double monthlyBudget,
    required double monthlySpent,
    required double monthlyRemaining,
    required int buyAlerts,
    required int sellAlerts,
    List<Map<String, dynamic>> thresholdTriggeredSteps =
        const <Map<String, dynamic>>[],
  }) {
    final ts = DateTime.now();

    final buyCount = alertsJson.where((a) => a['type'] == 'buyZone').length;
    final sellCount = alertsJson.where((a) => a['type'] == 'sellZone').length;

    final totalPnlUsd = (pnlJson['totalPnlUsd'] as num?)?.toDouble() ?? 0.0;
    final totalPnlPct = (pnlJson['totalPnlPct'] as num?)?.toDouble() ?? 0.0;
    final remaining = (budgetJson['remaining'] as num?)?.toDouble() ?? 0.0;

    final summary =
        'Profile=$profileName | Mode=$mode | Feed=${feedHealth.status.name} | '
        'Alerts(Watch=$buyCount,Profit=$sellCount) | Deploy=\$${deploymentPlan.totalToDeploy.toStringAsFixed(2)} '
        '| Gate=${executionGate['statusText']} | Next=${executionGate['nextActionText']}';
    final thresholdTriggeredSummaryLines =
        buildThresholdTriggeredSummaryLines(thresholdTriggeredSteps);

    final data = <String, dynamic>{
      'timestamp': ts.toIso8601String(),
      'feed': feed,
      'mode': mode,
      'profile': profileName,
      'feedHealth': feedHealth.toJson(),
      'heat': heat.toJson(),
      'snapshot': snapshotJson,
      'alerts_raw': alertsJson,
      'deploymentPlan': {
        'perAssetAmounts': deploymentPlan.perAssetAmounts,
        'totalToDeploy': deploymentPlan.totalToDeploy,
        'message': deploymentPlan.message,
      },
      'executionIntent': intent.toJson(),
      'positions': positionsJson,
      'pnl': pnlJson,
      'rebalance': rebalanceJson,
      'lastLedgerRecord': lastLedgerRecord,
      'marketRegime': marketRegime,
      'guidance': guidance,
      'holdings': holdings,
      'portfolio': portfolio,
      'threshold_triggered_steps': thresholdTriggeredSteps,
      'threshold_triggered_summary_lines': thresholdTriggeredSummaryLines,
      'execution_gate': executionGate,
      'per_asset_actions': perAssetActions,
      'budget': {
        ...budgetJson,
        'monthlyBudget': monthlyBudget,
        'spent': monthlySpent,
        'remaining': monthlyRemaining,
      },
      'alerts': {
        'summary': alertsSummary,
        'events': alertsEvents,
        'counts': {
          'buy': buyAlerts,
          'sell': sellAlerts,
          'info': alertsEvents.length - buyAlerts - sellAlerts,
        },
      },
    };

    return StrategyReport(timestamp: ts, data: data, summary: summary);
  }
}
