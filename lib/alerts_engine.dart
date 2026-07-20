enum AlertKind { buy, sell, info }

class AlertRule {
  final String asset;
  final double? buyBelow;
  final double? sellAbove;
  final bool enabled;

  const AlertRule({
    required this.asset,
    this.buyBelow,
    this.sellAbove,
    this.enabled = true,
  });

  AlertRule copyWith({
    String? asset,
    double? buyBelow,
    double? sellAbove,
    bool? enabled,
  }) {
    return AlertRule(
      asset: asset ?? this.asset,
      buyBelow: buyBelow ?? this.buyBelow,
      sellAbove: sellAbove ?? this.sellAbove,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'asset': asset,
        'buyBelow': buyBelow,
        'sellAbove': sellAbove,
        'enabled': enabled,
      };

  static AlertRule fromJson(Map<String, dynamic> json) {
    return AlertRule(
      asset: (json['asset'] as String?) ?? '',
      buyBelow: (json['buyBelow'] as num?)?.toDouble(),
      sellAbove: (json['sellAbove'] as num?)?.toDouble(),
      enabled: json['enabled'] is bool ? (json['enabled'] as bool) : true,
    );
  }
}

class AlertEvent {
  final String asset;
  final AlertKind kind;
  final String message;
  final double price;

  const AlertEvent({
    required this.asset,
    required this.kind,
    required this.message,
    required this.price,
  });
}

class AlertsResult {
  final List<AlertEvent> events;
  final int buyCount;
  final int sellCount;
  final int infoCount;

  const AlertsResult({
    required this.events,
    required this.buyCount,
    required this.sellCount,
    required this.infoCount,
  });

  String get summaryLine => 'Watch $buyCount / Profit $sellCount';
}

AlertsResult evaluateAlerts({
  required Map<String, double> prices,
  required Map<String, AlertRule> rules,
}) {
  final List<AlertEvent> events = [];

  for (final rule in rules.values) {
    if (!rule.enabled) continue;
    final asset = rule.asset.toUpperCase();
    final price = prices[asset] ??
        prices[asset.toUpperCase()] ??
        prices[asset.toLowerCase()];
    if (price == null) continue;

    AlertKind? baseKind;
    if (rule.buyBelow != null && price <= (rule.buyBelow ?? 0)) {
      baseKind = AlertKind.buy;
    } else if (rule.sellAbove != null && price >= (rule.sellAbove ?? double.infinity)) {
      baseKind = AlertKind.sell;
    } else {
      continue;
    }

    AlertKind finalKind = baseKind;
    String message;

    message = baseKind == AlertKind.buy
        ? '$asset reached a watch level at ${_fmt(price)}'
        : '$asset reached a profit level at ${_fmt(price)}';

    events.add(AlertEvent(
      asset: asset,
      kind: finalKind,
      message: message,
      price: price,
    ));
  }

  events.sort((a, b) {
    int rank(AlertKind k) {
      switch (k) {
        case AlertKind.buy:
          return 0;
        case AlertKind.sell:
          return 1;
        case AlertKind.info:
          return 2;
      }
    }

    final r = rank(a.kind).compareTo(rank(b.kind));
    if (r != 0) return r;
    return a.asset.compareTo(b.asset);
  });

  final buyCount = events.where((e) => e.kind == AlertKind.buy).length;
  final sellCount = events.where((e) => e.kind == AlertKind.sell).length;
  final infoCount = events.where((e) => e.kind == AlertKind.info).length;

  return AlertsResult(
    events: events,
    buyCount: buyCount,
    sellCount: sellCount,
    infoCount: infoCount,
  );
}

String _fmt(double v) {
  // keep deterministic formatting
  return v.toStringAsFixed(2);
}
