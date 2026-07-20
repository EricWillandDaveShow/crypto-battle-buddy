Set<String> computeRemovedAssetSymbols({
  required Iterable<String> previousSymbols,
  required Iterable<String> nextSymbols,
}) {
  Set<String> normalize(Iterable<String> symbols) {
    return symbols
        .map((symbol) => symbol.trim().toUpperCase())
        .where((symbol) => symbol.isNotEmpty)
        .toSet();
  }

  final previous = normalize(previousSymbols);
  final next = normalize(nextSymbols);
  return previous.difference(next);
}
