class AssetDef {
  final String symbol; // e.g. "STX"
  final String name; // e.g. "Stacks"
  final bool supportsTiers; // gate advanced UI like TIERS

  const AssetDef({
    required this.symbol,
    required this.name,
    this.supportsTiers = false,
  });
}

