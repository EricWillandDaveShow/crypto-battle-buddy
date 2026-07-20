import 'package:crypto_battle_buddy/assets/asset_catalog_store.dart';
import 'package:crypto_battle_buddy/assets/dynamic_asset.dart';
import 'package:crypto_battle_buddy/assets/dynamic_asset_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('enabled dynamic asset delete transaction removes durable state',
      () async {
    SharedPreferences.setMockInitialValues({});

    final catalogStore = AssetCatalogStore();
    final dynamicStore = DynamicAssetStore();

    await dynamicStore.upsert(
      const DynamicAsset(
        symbol: 'DOGE',
        name: 'Dogecoin',
        coingeckoId: 'dogecoin',
      ),
    );
    await catalogStore.upsert('DOGE', 'dogecoin');
    await catalogStore.saveEnabledSymbols({'DOGE'});

    await catalogStore.saveEnabledSymbols({});
    await catalogStore.remove('doge');
    await dynamicStore.remove('doge');

    expect(await catalogStore.loadEnabledSymbols(), isNot(contains('DOGE')));
    expect((await catalogStore.loadCatalog()).containsKey('DOGE'), isFalse);
    expect(
      (await dynamicStore.loadAll())
          .any((asset) => asset.symbol.toUpperCase() == 'DOGE'),
      isFalse,
    );
  });

  test('disabled dynamic asset delete transaction preserves enabled symbols',
      () async {
    SharedPreferences.setMockInitialValues({});

    final catalogStore = AssetCatalogStore();
    final dynamicStore = DynamicAssetStore();

    await dynamicStore.upsert(
      const DynamicAsset(
        symbol: 'DOGE',
        name: 'Dogecoin',
        coingeckoId: 'dogecoin',
      ),
    );
    await catalogStore.upsert('DOGE', 'dogecoin');
    await catalogStore.saveEnabledSymbols({'BTC'});

    await catalogStore.remove('doge');
    await dynamicStore.remove('doge');

    expect(await catalogStore.loadEnabledSymbols(), {'BTC'});
    expect((await catalogStore.loadCatalog()).containsKey('DOGE'), isFalse);
    expect(
      (await dynamicStore.loadAll())
          .any((asset) => asset.symbol.toUpperCase() == 'DOGE'),
      isFalse,
    );
  });
}
