class RebalanceLine {
  final String symbol;
  final double targetWeight;
  final double actualWeight;
  final double marketValueUsd;
  final double targetValueUsd;
  final double deltaUsd; // + buy, - sell

  RebalanceLine({
    required this.symbol,
    required this.targetWeight,
    required this.actualWeight,
    required this.marketValueUsd,
    required this.targetValueUsd,
    required this.deltaUsd,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'targetWeight': targetWeight,
        'actualWeight': actualWeight,
        'marketValueUsd': marketValueUsd,
        'targetValueUsd': targetValueUsd,
        'deltaUsd': deltaUsd,
      };
}

class RebalanceReport {
  final double totalMarketValueUsd;
  final List<RebalanceLine> lines;

  RebalanceReport({
    required this.totalMarketValueUsd,
    required this.lines,
  });

  Map<String, dynamic> toJson() => {
        'totalMarketValueUsd': totalMarketValueUsd,
        'lines': lines.map((e) => e.toJson()).toList(),
      };
}
