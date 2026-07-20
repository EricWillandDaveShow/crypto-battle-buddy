class Position {
  final String symbol;
  final double units;
  final double costBasisUsd;
  final double avgCostUsd;

  Position({
    required this.symbol,
    required this.units,
    required this.costBasisUsd,
    required this.avgCostUsd,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'units': units,
        'costBasisUsd': costBasisUsd,
        'avgCostUsd': avgCostUsd,
      };

  static Position fromJson(Map<String, dynamic> map) {
    return Position(
      symbol: map['symbol'],
      units: (map['units'] as num).toDouble(),
      costBasisUsd: (map['costBasisUsd'] as num).toDouble(),
      avgCostUsd: (map['avgCostUsd'] as num).toDouble(),
    );
  }
}
