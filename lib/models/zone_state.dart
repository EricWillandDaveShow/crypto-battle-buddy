class ZoneState {
  final String symbol;
  final double zonePrice;
  bool consumed;

  ZoneState({
    required this.symbol,
    required this.zonePrice,
    this.consumed = false,
  });
}
