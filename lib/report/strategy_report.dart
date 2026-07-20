import 'dart:convert';

class StrategyReport {
  final DateTime ts;
  final Map<String, dynamic> data;
  final String summary;

  const StrategyReport({
    required this.ts,
    required this.data,
    required this.summary,
  });

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}

StrategyReport buildStrategyReport({
  required DateTime ts,
  required String mode,
  required bool heatMode,
  required bool safetyLock,
  required bool goLive,
  required Map<String, num> pricesUsd,
  required Map<String, double> holdingsBySymbol,
  required Map<String, double> targetWeights,
  required Map<String, dynamic>? marketRegime,
  required Map<String, dynamic>? guidance,
  required String statusText,
  required String nextActionText,
  required String? alertsSummary,
  required List<String>? alertLines,
  required double monthlyBudget,
  required double monthlySpent,
  required double monthlyRemaining,
  required Map<String, dynamic>? portfolioSummaryJson,
}) {
  final meta = {
    'ts_iso': ts.toIso8601String(),
    'mode': mode,
    'heatMode': heatMode,
    'safetyLock': safetyLock,
    'goLive': goLive,
  };

  final data = <String, dynamic>{
    'meta': meta,
    'prices_usd': pricesUsd,
    'holdings_units': holdingsBySymbol,
    'targets': targetWeights,
    'alerts': {
      'summary': alertsSummary,
      'top': alertLines ?? const [],
    },
    'texts': {
      'statusText': statusText,
      'nextActionText': nextActionText,
    },
    'budget': {
      'monthlyBudget': monthlyBudget,
      'spent': monthlySpent,
      'remaining': monthlyRemaining,
    },
  };

  if (marketRegime != null) data['market_regime'] = marketRegime;
  if (guidance != null) data['guidance'] = guidance;
  if (portfolioSummaryJson != null) data['portfolio'] = portfolioSummaryJson;

  final summaryLines = <String>[];
  final regimeLabel = marketRegime != null ? ' • Regime: ${marketRegime['regime']}' : '';
  summaryLines.add('Mode: $mode$regimeLabel');
  final portfolioLine = portfolioSummaryJson != null && portfolioSummaryJson['total_value_usd'] is num
      ? 'Portfolio: \$${(portfolioSummaryJson['total_value_usd'] as num).toStringAsFixed(0)}'
      : 'Portfolio: n/a';
  final alertsLine = alertsSummary != null && alertsSummary.isNotEmpty ? 'Alerts: $alertsSummary' : 'Alerts: n/a';
  summaryLines.add('$portfolioLine • $alertsLine');
  summaryLines.add('Next: $nextActionText');

  return StrategyReport(
    ts: ts,
    data: data,
    summary: summaryLines.join('\n'),
  );
}
