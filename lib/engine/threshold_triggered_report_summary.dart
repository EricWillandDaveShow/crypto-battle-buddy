List<String> buildThresholdTriggeredSummaryLines(
  List<Map<String, dynamic>> thresholdTriggeredSteps,
) {
  return thresholdTriggeredSteps
      .map(_thresholdTriggeredSummaryLine)
      .toList(growable: false);
}

String _thresholdTriggeredSummaryLine(Map<String, dynamic> entry) {
  final symbol = _cleanString(entry['symbol'], fallback: 'UNKNOWN');
  final tier = _cleanString(entry['tier'], fallback: '?');
  final action = _cleanString(entry['action'], fallback: 'ACTION');
  final trigger = _formatUsd(entry['triggerPriceUsd']);
  final status = _cleanString(entry['status'], fallback: 'unknown');
  final current = _formatOptionalUsd(entry['currentPriceUsd']);

  final base = '$symbol tier $tier $action @ $trigger ($status)';
  return current == null ? base : '$base current $current';
}

String _cleanString(Object? value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _formatUsd(Object? value) {
  final amount = _asDouble(value);
  if (amount == null) return r'$?';
  return '\$${amount.toStringAsFixed(2)}';
}

String? _formatOptionalUsd(Object? value) {
  final amount = _asDouble(value);
  if (amount == null) return null;
  return '\$${amount.toStringAsFixed(2)}';
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}
