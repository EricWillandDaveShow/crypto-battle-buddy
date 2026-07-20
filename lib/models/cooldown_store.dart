class CooldownStore {
  final Map<String, DateTime> _lastFired = {};

  DateTime? lastFired(String key) => _lastFired[key];

  void setLastFired(String key, DateTime time) {
    _lastFired[key] = time;
  }

  void clear() {
    _lastFired.clear();
  }

  Map<String, String> exportIsoMap() {
    return _lastFired.map((key, value) => MapEntry(key, value.toIso8601String()));
  }

  void importIsoMap(Map<String, dynamic> map) {
    _lastFired.clear();
    map.forEach((key, value) {
      final ts = DateTime.tryParse(value.toString());
      if (ts != null) {
        _lastFired[key] = ts;
      }
    });
  }
}
