import 'asset_def.dart';

/// Single source of truth for what assets exist in the app.
/// Adding a new asset should be a 1-line add here (plus provider mapping in symbol_maps.dart if needed).
class AssetRegistry {
  static const List<AssetDef> all = <AssetDef>[
    AssetDef(symbol: 'BTC', name: 'Bitcoin', supportsTiers: true),
    AssetDef(symbol: 'ETH', name: 'Ethereum', supportsTiers: true),
    AssetDef(symbol: 'SOL', name: 'Solana', supportsTiers: true),
    AssetDef(symbol: 'STX', name: 'Stacks', supportsTiers: false),
    // Add more here:
    // AssetDef(symbol: 'NEAR', name: 'NEAR Protocol', supportsTiers: false),
  ];

  static const Set<String> defaultEnabled = <String>{};

  static AssetDef? bySymbol(String symbol) {
    final s = symbol.toUpperCase();
    for (final a in all) {
      if (a.symbol == s) return a;
    }
    return null;
  }

  static List<AssetDef> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((a) {
      return a.symbol.toLowerCase().contains(q) ||
          a.name.toLowerCase().contains(q);
    }).toList();
  }
}
