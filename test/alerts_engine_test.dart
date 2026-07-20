import 'package:crypto_battle_buddy/alerts_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AlertRule rule(String asset,
          {double? buyBelow, double? sellAbove, bool enabled = true}) =>
      AlertRule(asset: asset, buyBelow: buyBelow, sellAbove: sellAbove, enabled: enabled);

  test('triggers buy when price below threshold', () {
    final res = evaluateAlerts(
      prices: {'BTC': 30000},
      rules: {'BTC': rule('BTC', buyBelow: 31000)},
    );

    expect(res.buyCount, 1);
    expect(res.sellCount, 0);
    expect(res.infoCount, 0);
    expect(res.events.first.kind, AlertKind.buy);
    expect(res.events.first.message, contains('watch level'));
  });

  test('triggers sell when price above threshold', () {
    final res = evaluateAlerts(
      prices: {'ETH': 4000},
      rules: {'ETH': rule('ETH', sellAbove: 3900)},
    );

    expect(res.sellCount, 1);
    expect(res.buyCount, 0);
  });

  test('deterministic ordering buy then sell then info, by asset', () {
    final res = evaluateAlerts(
      prices: {'A': 1, 'B': 2, 'C': 3},
      rules: {
        'C': rule('C', buyBelow: 4),
        'B': rule('B', sellAbove: 1),
        'A': rule('A', buyBelow: 2),
      },
    );

    expect(res.events.map((e) => '${e.kind.name}:${e.asset}').toList(),
        ['buy:A', 'buy:C', 'sell:B']);
  });
}
