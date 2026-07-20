class PnlLine {
  final String symbol;
  final double units;
  final double avgCostUsd;
  final double priceUsd;
  final double marketValueUsd;
  final double costBasisUsd;
  final double pnlUsd;
  final double pnlPct;

  PnlLine({
    required this.symbol,
    required this.units,
    required this.avgCostUsd,
    required this.priceUsd,
    required this.marketValueUsd,
    required this.costBasisUsd,
    required this.pnlUsd,
    required this.pnlPct,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'units': units,
        'avgCostUsd': avgCostUsd,
        'priceUsd': priceUsd,
        'marketValueUsd': marketValueUsd,
        'costBasisUsd': costBasisUsd,
        'pnlUsd': pnlUsd,
        'pnlPct': pnlPct,
      };
}

class PnlReport {
  final List<PnlLine> lines;
  final double totalMarketValueUsd;
  final double totalCostBasisUsd;
  final double totalPnlUsd;
  final double totalPnlPct;

  PnlReport({
    required this.lines,
    required this.totalMarketValueUsd,
    required this.totalCostBasisUsd,
    required this.totalPnlUsd,
    required this.totalPnlPct,
  });

  Map<String, dynamic> toJson() => {
        'totalMarketValueUsd': totalMarketValueUsd,
        'totalCostBasisUsd': totalCostBasisUsd,
        'totalPnlUsd': totalPnlUsd,
        'totalPnlPct': totalPnlPct,
        'lines': lines.map((e) => e.toJson()).toList(),
      };
}
