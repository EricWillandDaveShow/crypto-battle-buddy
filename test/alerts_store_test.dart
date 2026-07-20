import 'package:crypto_battle_buddy/alerts_engine.dart';
import 'package:crypto_battle_buddy/alerts_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('alert rules persist round trip', () async {
    SharedPreferences.setMockInitialValues({});

    final rule = AlertRule(asset: 'BTC', buyBelow: 30000, sellAbove: 60000, enabled: true);
    await saveAlertRules({'BTC': rule});

    final loaded = await loadAlertRules();
    expect(loaded.containsKey('BTC'), isTrue);
    final r = loaded['BTC']!;
    expect(r.asset, 'BTC');
    expect(r.buyBelow, 30000);
    expect(r.sellAbove, 60000);
    expect(r.enabled, isTrue);
  });
}
