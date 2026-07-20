import '../models/position.dart';
import '../models/pnl_report.dart';

class PnlEngine {
  PnlReport build({
    required Map<String, Position> positions,
    required Map<String, double> prices,
  }) {
    final lines = <PnlLine>[];

    double totalMV = 0.0;
    double totalCost = 0.0;

    positions.forEach((symbol, pos) {
      final price = prices[symbol];
      if (price == null) return;

      final mv = pos.units * price;
      final cost = pos.costBasisUsd;
      final pnl = mv - cost;
      final double pct = cost > 0 ? (pnl / cost) : 0.0;

      totalMV += mv;
      totalCost += cost;

      lines.add(PnlLine(
        symbol: symbol,
        units: pos.units,
        avgCostUsd: pos.avgCostUsd,
        priceUsd: price,
        marketValueUsd: mv,
        costBasisUsd: cost,
        pnlUsd: pnl,
        pnlPct: pct,
      ));
    });

    final totalPnl = totalMV - totalCost;
    final double totalPct = totalCost > 0 ? (totalPnl / totalCost) : 0.0;

    lines.sort((a, b) => b.pnlUsd.abs().compareTo(a.pnlUsd.abs()));

    return PnlReport(
      lines: lines,
      totalMarketValueUsd: totalMV,
      totalCostBasisUsd: totalCost,
      totalPnlUsd: totalPnl,
      totalPnlPct: totalPct,
    );
  }
}
