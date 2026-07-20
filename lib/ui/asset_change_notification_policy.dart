Set<String> _normalizeEnabledSymbols(Set<String> symbols) {
  final normalized = <String>{};
  for (final raw in symbols) {
    final symbol = raw.trim().toUpperCase();
    if (symbol.isNotEmpty) {
      normalized.add(symbol);
    }
  }
  return normalized;
}

bool shouldNotifyAssetChange({
  required Set<String> beforeEnabled,
  required Set<String> afterEnabled,
  required DateTime now,
  required DateTime? lastNotifiedAt,
  required Duration cooldown,
}) {
  final before = _normalizeEnabledSymbols(beforeEnabled);
  final after = _normalizeEnabledSymbols(afterEnabled);
  final changed = before.length != after.length || !before.containsAll(after);
  if (!changed) return false;

  // Polling membership changes are material even inside the cooldown window.
  return true;
}
