import '../models/position.dart';
import '../models/allocation_target.dart';
import '../models/rebalance_report.dart';

class RebalanceEngine {
  RebalanceReport build({
    required Map<String, Position> positions,
    required Map<String, double> prices,
    required List<AllocationTarget> targets,
  }) {
    final targetMap = {for (final t in targets) t.symbol: t.weight};

    double totalMV = 0.0;
    final mvBySymbol = <String, double>{};

    for (final entry in positions.entries) {
      final price = prices[entry.key];
      if (price == null) continue;
      final mv = entry.value.units * price;
      mvBySymbol[entry.key] = mv;
      totalMV += mv;
    }

    final lines = <RebalanceLine>[];

    if (totalMV <= 0) {
      return RebalanceReport(totalMarketValueUsd: 0, lines: []);
    }

    for (final sym in targetMap.keys) {
      final targetW = targetMap[sym]!;
      final mv = mvBySymbol[sym] ?? 0.0;
      final actualW = mv / totalMV;
      final targetV = totalMV * targetW;
      final delta = targetV - mv;

      lines.add(RebalanceLine(
        symbol: sym,
        targetWeight: targetW,
        actualWeight: actualW,
        marketValueUsd: double.parse(mv.toStringAsFixed(2)),
        targetValueUsd: double.parse(targetV.toStringAsFixed(2)),
        deltaUsd: double.parse(delta.toStringAsFixed(2)),
      ));
    }

    lines.sort((a, b) => b.deltaUsd.abs().compareTo(a.deltaUsd.abs()));

    return RebalanceReport(
      totalMarketValueUsd: double.parse(totalMV.toStringAsFixed(2)),
      lines: lines,
    );
  }
}
