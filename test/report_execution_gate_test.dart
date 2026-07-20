import 'package:crypto_battle_buddy/battle_buddy_engine.dart';
import 'package:crypto_battle_buddy/engine/report_engine.dart';
import 'package:crypto_battle_buddy/models/deployment_plan.dart';
import 'package:crypto_battle_buddy/models/execution_intent.dart';
import 'package:crypto_battle_buddy/models/execution_mode.dart';
import 'package:crypto_battle_buddy/models/feed_health.dart';
import 'package:crypto_battle_buddy/models/heat_mode.dart';
import 'package:crypto_battle_buddy/models/strategy_report.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _gateMap(
  ExecutionGateResult gate, {
  required double budgetRemaining,
  required String modeLabel,
  required int buyAlerts,
  required int sellAlerts,
}) {
  return {
    'canExecute': gate.canExecute,
    'blockers': gate.blockers,
    'maxSpendUsd': gate.maxSpendUsd,
    'statusText': gate.statusText,
    'nextActionText': gate.nextActionText,
    'allowed': gate.canExecute,
    'blocked_by': gate.blockers.isEmpty ? 'none' : gate.blockers.first.toLowerCase(),
    'reason': gate.statusText,
    'max_spend_now': gate.maxSpendUsd,
    'budget_left': budgetRemaining,
    'mode': modeLabel,
    'alerts_buy': buyAlerts,
    'alerts_sell': sellAlerts,
  };
}

void main() {
  final ts = DateTime.utc(2025, 1, 1, 12);
  final reportEngine = ReportEngine();

  StrategyReport _buildReport({
    required ExecutionGateResult gate,
    required Map<String, String> perAssetActions,
    required double budgetRemaining,
    required int buyAlerts,
    required int sellAlerts,
    List<Map<String, dynamic>> thresholdTriggeredSteps =
        const <Map<String, dynamic>>[],
  }) {
    const modeLabel = 'Balanced';
    final gateMap = _gateMap(
      gate,
      budgetRemaining: budgetRemaining,
      modeLabel: modeLabel,
      buyAlerts: buyAlerts,
      sellAlerts: sellAlerts,
    );
    return reportEngine.build(
      profileName: 'Test',
      mode: modeLabel,
      feed: 'paper',
      feedHealth: FeedHealth(status: FeedStatus.healthy, timestamp: ts, message: 'ok'),
      heat: HeatModeState(isHot: false, message: ''),
      snapshotJson: const {},
      alertsJson: const [],
      deploymentPlan: const DeploymentPlan(perAssetAmounts: {}, totalToDeploy: 0, message: 'none'),
      intent: ExecutionIntent(
        mode: ExecutionMode.dryRun,
        perAssetAmounts: const {},
        timestamp: ts,
        message: 'none',
      ),
      budgetJson: {
        'month': DateTime(ts.year, ts.month, 1).toIso8601String(),
        'monthlyLimit': 200.0,
        'spentThisMonth': 0.0,
        'remaining': budgetRemaining,
      },
      positionsJson: const {},
      pnlJson: const {'totalPnlUsd': 0.0, 'totalPnlPct': 0.0},
      rebalanceJson: const {},
      lastLedgerRecord: null,
      marketRegime: const {'regime': 'NEUTRAL'},
      guidance: {
        'statusText': gate.statusText,
        'nextActionText': gate.nextActionText,
      },
      holdings: const {},
      portfolio: const {},
      alertsSummary: 'Watch $buyAlerts / Profit $sellAlerts',
      alertsEvents: const [],
      executionGate: gateMap,
      perAssetActions: perAssetActions,
      monthlyBudget: 200.0,
      monthlySpent: 0.0,
      monthlyRemaining: budgetRemaining,
      buyAlerts: buyAlerts,
      sellAlerts: sellAlerts,
      thresholdTriggeredSteps: thresholdTriggeredSteps,
    );
  }

  test('report reflects blocked gate and forces HOLD actions', () {
    final engine = BattleBuddyEngine();
    const budgetRemaining = 0.0;
    final gate = engine.evaluateExecutionGate(
      budgetRemainingUsd: budgetRemaining,
      buyAlertsCount: 0,
      sellAlertsCount: 0,
      modeLabel: 'Balanced',
    );
    final actions = engine.perAssetActions(gate: gate);

    final report = _buildReport(
      gate: gate,
      perAssetActions: actions,
      budgetRemaining: budgetRemaining,
      buyAlerts: 0,
      sellAlerts: 0,
    );

    final gateJson = report.data['execution_gate'] as Map<String, dynamic>;
    expect(gateJson['allowed'], isFalse);
    expect(gateJson['max_spend_now'], 0);
    expect((report.data['per_asset_actions'] as Map<String, String>).values.every((v) => v == 'HOLD'), isTrue);
    expect(report.summary.toLowerCase(), contains('budget used'));
  });

  test('report reflects allowed gate and keeps per-asset actions', () {
    final engine = BattleBuddyEngine();
    const budgetRemaining = 150.0;
    final gate = engine.evaluateExecutionGate(
      budgetRemainingUsd: budgetRemaining,
      buyAlertsCount: 1,
      sellAlertsCount: 0,
      modeLabel: 'Balanced',
    );
    final customActions = {'BTC': 'BUY', 'ETH': 'SELL', 'SOL': 'HOLD'};

    final report = _buildReport(
      gate: gate,
      perAssetActions: customActions,
      budgetRemaining: budgetRemaining,
      buyAlerts: 1,
      sellAlerts: 0,
    );

    final gateJson = report.data['execution_gate'] as Map<String, dynamic>;
    expect(gateJson['allowed'], isTrue);
    expect((gateJson['max_spend_now'] as num) > 0, isTrue);
    final perAsset = report.data['per_asset_actions'] as Map<String, String>;
    expect(perAsset['BTC'], 'BUY');
    expect(perAsset['ETH'], 'SELL');
    expect(report.summary.toLowerCase(), contains('execution allowed'));
  });

  test('report includes threshold triggered steps as distinct data field', () {
    final engine = BattleBuddyEngine();
    const budgetRemaining = 150.0;
    final gate = engine.evaluateExecutionGate(
      budgetRemainingUsd: budgetRemaining,
      buyAlertsCount: 0,
      sellAlertsCount: 0,
      modeLabel: 'Balanced',
    );
    final thresholdTriggeredSteps = [
      {
        'symbol': 'BTC',
        'stepId': 'BTC:0',
        'tier': 1,
        'action': 'BUY',
        'triggerPriceUsd': 38000.0,
        'status': 'pending',
        'wasTriggered': true,
        'updatedAt': '2026-06-16T12:00:00.000Z',
        'currentPriceUsd': 37950.0,
      },
    ];

    final report = _buildReport(
      gate: gate,
      perAssetActions: const {'BTC': 'HOLD'},
      budgetRemaining: budgetRemaining,
      buyAlerts: 0,
      sellAlerts: 0,
      thresholdTriggeredSteps: thresholdTriggeredSteps,
    );

    expect(
      report.data['threshold_triggered_steps'],
      thresholdTriggeredSteps,
    );
    final summaryLines =
        report.data['threshold_triggered_summary_lines'] as List<String>;
    expect(summaryLines, hasLength(1));
    expect(summaryLines.single, contains('BTC'));
    expect(summaryLines.single, contains('tier 1'));
    expect(summaryLines.single, contains('BUY'));
    expect(summaryLines.single, contains(r'$38000.00'));
    expect(summaryLines.single, contains('pending'));
    expect(report.data['alerts_raw'], isEmpty);
    expect((report.data['alerts'] as Map<String, dynamic>)['events'], isEmpty);
  });
}
