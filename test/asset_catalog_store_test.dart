import 'package:crypto_battle_buddy/assets/asset_catalog_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing enabled symbols load as empty and seed the enabled key',
      () async {
    SharedPreferences.setMockInitialValues({});

    final store = AssetCatalogStore();
    final enabled = await store.loadEnabledSymbols();

    expect(enabled, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('asset_enabled_v1'), isEmpty);
  });

  test('saved enabled symbols reload normalized uppercase', () async {
    SharedPreferences.setMockInitialValues({});

    final store = AssetCatalogStore();
    await store.saveEnabledSymbols({'btc', ' ETH ', 'doge', ''});

    final enabled = await store.loadEnabledSymbols();

    expect(enabled, {'BTC', 'ETH', 'DOGE'});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('asset_enabled_v1'), ['BTC', 'DOGE', 'ETH']);
  });

  test('saving an empty enabled symbol set reloads as empty', () async {
    SharedPreferences.setMockInitialValues({});

    final store = AssetCatalogStore();
    await store.saveEnabledSymbols({});

    final enabled = await store.loadEnabledSymbols();

    expect(enabled, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('asset_enabled_v1'), isEmpty);
  });

  test('invalid persisted enabled symbols reset enabled symbols to empty',
      () async {
    SharedPreferences.setMockInitialValues({
      'asset_enabled_v1': ['BTC', 'bad symbol'],
    });

    final store = AssetCatalogStore();
    final enabled = await store.loadEnabledSymbols();

    expect(enabled, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('asset_enabled_v1'), isEmpty);
  });

  test('syntactically valid uncataloged symbols remain enabled', () async {
    SharedPreferences.setMockInitialValues({
      'asset_enabled_v1': ['doge'],
    });

    final store = AssetCatalogStore();
    final enabled = await store.loadEnabledSymbols();

    expect(enabled, {'DOGE'});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('asset_enabled_v1'), ['doge']);
  });

  test('catalog upsert and remove do not implicitly enable symbols', () async {
    SharedPreferences.setMockInitialValues({});

    final store = AssetCatalogStore();
    await store.upsert('doge', 'dogecoin');

    expect(await store.loadCatalog(), {'DOGE': 'dogecoin'});
    expect(await store.loadEnabledSymbols(), isEmpty);

    await store.remove('doge');

    expect(await store.loadCatalog(), isEmpty);
    expect(await store.loadEnabledSymbols(), isEmpty);
  });
}
