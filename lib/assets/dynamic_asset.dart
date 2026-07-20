class DynamicAsset {
  final String symbol; // e.g. "STX"
  final String name; // e.g. "Stacks"
  final String coingeckoId; // e.g. "stacks"

  const DynamicAsset({
    required this.symbol,
    required this.name,
    required this.coingeckoId,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'symbol': symbol.toUpperCase(),
        'name': name,
        'coingeckoId': coingeckoId,
      };

  static DynamicAsset fromJson(Map<String, dynamic> json) => DynamicAsset(
        symbol: (json['symbol'] as String).toUpperCase(),
        name: (json['name'] as String?) ?? (json['symbol'] as String),
        coingeckoId: (json['coingeckoId'] as String),
      );
}

