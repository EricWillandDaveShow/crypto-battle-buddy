class PortfolioAssetRow {
  final String symbol;
  final double units;
  final double priceUsd;
  final double valueUsd;
  final double allocPct;
  final double targetPct;
  final double deltaPct;
  final String label;

  const PortfolioAssetRow({
    required this.symbol,
    required this.units,
    required this.priceUsd,
    required this.valueUsd,
    required this.allocPct,
    required this.targetPct,
    required this.deltaPct,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'units': units,
        'price_usd': priceUsd,
        'value_usd': valueUsd,
        'alloc_pct': allocPct,
        'target_pct': targetPct,
        'delta_pct': deltaPct,
        'label': label,
      };
}

class PortfolioSummary {
  final double totalValueUsd;
  final List<PortfolioAssetRow> rows;

  const PortfolioSummary({
    required this.totalValueUsd,
    required this.rows,
  });

  Map<String, dynamic> toJson() => {
        'total_value_usd': totalValueUsd,
        'rows': rows.map((r) => r.toJson()).toList(),
      };
}

Map<String, double> _normalizeWeights(Map<String, double> weights, Iterable<String> include) {
  final filtered = <String, double>{};
  for (final sym in include) {
    if (weights.containsKey(sym)) filtered[sym] = weights[sym] ?? 0.0;
    if (weights.containsKey(sym.toUpperCase())) filtered[sym.toUpperCase()] = weights[sym.toUpperCase()] ?? 0.0;
    if (weights.containsKey(sym.toLowerCase())) filtered[sym.toUpperCase()] = weights[sym.toLowerCase()] ?? 0.0;
  }
  final sum = filtered.values.fold<double>(0.0, (a, b) => a + b);
  if (sum <= 0) return {for (final sym in include) sym.toUpperCase(): 0.0};
  return {for (final e in filtered.entries) e.key.toUpperCase(): (e.value / sum) * 100.0};
}

String _deltaLabel(double deltaPct) {
  if (deltaPct <= -2.0) return 'Under';
  if (deltaPct >= 2.0) return 'Over';
  return 'On target';
}

PortfolioSummary computePortfolioSummary({
  required List<String> includedSymbols,
  required Map<String, double> holdingsBySymbol,
  required Map<String, num> pricesUsd,
  required Map<String, double> targetWeights,
}) {
  final upperSyms = includedSymbols.map((s) => s.toUpperCase()).toList()..sort();
  final List<PortfolioAssetRow> rows = [];
  final Map<String, double> mv = {};
  final Map<String, double> priceCache = {};

  for (final sym in upperSyms) {
    final units = holdingsBySymbol[sym] ??
        holdingsBySymbol[sym.toUpperCase()] ??
        holdingsBySymbol[sym.toLowerCase()] ??
        0.0;
    final priceNum = pricesUsd[sym] ??
        pricesUsd[sym.toUpperCase()] ??
        pricesUsd[sym.toLowerCase()] ??
        0.0;
    final price = priceNum.toDouble();
    final value = units * price;
    mv[sym] = value > 0 ? value : 0.0;
    priceCache[sym] = price;
  }

  final total = mv.values.fold<double>(0.0, (a, b) => a + b);
  final allocPct = {
    for (final e in mv.entries)
      e.key: total <= 0 ? 0.0 : (e.value / total) * 100.0,
  };
  final targetPct = _normalizeWeights(targetWeights, upperSyms);

  for (final sym in upperSyms) {
    final value = mv[sym] ?? 0.0;
    final delta = (allocPct[sym] ?? 0.0) - (targetPct[sym] ?? 0.0);
    rows.add(
      PortfolioAssetRow(
        symbol: sym,
        units: holdingsBySymbol[sym] ??
            holdingsBySymbol[sym.toUpperCase()] ??
            holdingsBySymbol[sym.toLowerCase()] ??
            0.0,
        priceUsd: priceCache[sym] ?? 0.0,
        valueUsd: value,
        allocPct: allocPct[sym] ?? 0.0,
        targetPct: targetPct[sym] ?? 0.0,
        deltaPct: delta,
        label: _deltaLabel(delta),
      ),
    );
  }

  rows.sort((a, b) {
    final cmp = b.valueUsd.compareTo(a.valueUsd);
    if (cmp != 0) return cmp;
    return a.symbol.compareTo(b.symbol);
  });

  return PortfolioSummary(totalValueUsd: total, rows: rows);
}

// Legacy helpers still used in UI helpers
Map<String, double> computeMarketValues({
  required Map<String, double> holdings,
  required Map<String, double> prices,
}) {
  final Map<String, double> mv = {};
  holdings.forEach((sym, units) {
    final price = prices[sym] ??
        prices[sym.toUpperCase()] ??
        prices[sym.toLowerCase()] ??
        0.0;
    if (units > 0 && price > 0) {
      mv[sym.toUpperCase()] = units * price;
    } else {
      mv[sym.toUpperCase()] = 0.0;
    }
  });
  return mv;
}

double totalValue(Map<String, double> mv) {
  return mv.values.fold(0.0, (a, b) => a + b);
}

Map<String, double> allocationPercents(Map<String, double> mv) {
  final total = totalValue(mv);
  if (total <= 0) {
    return {for (final k in mv.keys) k: 0.0};
  }
  return {
    for (final entry in mv.entries) entry.key: (entry.value / total) * 100.0,
  };
}

Map<String, double> normalizeWeights(Map<String, double> weights) {
  final sum = weights.values.fold<double>(0.0, (a, b) => a + b);
  if (sum <= 0) return {for (final k in weights.keys) k: 0.0};
  return {for (final e in weights.entries) e.key: (e.value / sum) * 100.0};
}

String deltaLabel(double deltaPct) {
  if (deltaPct <= -2.0) return 'Under';
  if (deltaPct >= 2.0) return 'Over';
  return 'On target';
}
