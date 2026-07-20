import 'package:crypto_battle_buddy/assets/asset_catalog_store.dart';
import 'package:crypto_battle_buddy/assets/dynamic_asset.dart';
import 'package:crypto_battle_buddy/assets/dynamic_asset_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('upsert then loadAll returns dynamic asset metadata', () async {
    SharedPreferences.setMockInitialValues({});

    final store = DynamicAssetStore();
    await store.upsert(
      const DynamicAsset(
        symbol: 'doge',
        name: 'Dogecoin',
        coingeckoId: 'dogecoin',
      ),
    );

    final loaded = await store.loadAll();

    expect(loaded.length, 1);
    expect(loaded.first.symbol, 'DOGE');
    expect(loaded.first.name, 'Dogecoin');
    expect(loaded.first.coingeckoId, 'dogecoin');
  });

  test('upsert replaces the same symbol case-insensitively', () async {
    SharedPreferences.setMockInitialValues({});

    final store = DynamicAssetStore();
    await store.upsert(
      const DynamicAsset(
        symbol: 'doge',
        name: 'Dogecoin',
        coingeckoId: 'dogecoin',
      ),
    );
    await store.upsert(
      const DynamicAsset(
        symbol: 'DOGE',
        name: 'Dogecoin Updated',
        coingeckoId: 'dogecoin-updated',
      ),
    );

    final loaded = await store.loadAll();

    expect(loaded.length, 1);
    expect(loaded.first.symbol, 'DOGE');
    expect(loaded.first.name, 'Dogecoin Updated');
    expect(loaded.first.coingeckoId, 'dogecoin-updated');
  });

  test('remove removes by symbol case-insensitively', () async {
    SharedPreferences.setMockInitialValues({});

    final store = DynamicAssetStore();
    await store.upsert(
      const DynamicAsset(
        symbol: 'DOGE',
        name: 'Dogecoin',
        coingeckoId: 'dogecoin',
      ),
    );
    await store.upsert(
      const DynamicAsset(
        symbol: 'PEPE',
        name: 'Pepe',
        coingeckoId: 'pepe',
      ),
    );

    await store.remove('doge');

    final loaded = await store.loadAll();

    expect(loaded.map((asset) => asset.symbol), ['PEPE']);
  });

  test('dynamic asset removal does not mutate enabled symbols', () async {
    SharedPreferences.setMockInitialValues({});

    final dynamicStore = DynamicAssetStore();
    final catalogStore = AssetCatalogStore();
    await dynamicStore.upsert(
      const DynamicAsset(
        symbol: 'DOGE',
        name: 'Dogecoin',
        coingeckoId: 'dogecoin',
      ),
    );
    await catalogStore.saveEnabledSymbols({'DOGE'});

    await dynamicStore.remove('doge');

    expect(await dynamicStore.loadAll(), isEmpty);
    expect(await catalogStore.loadEnabledSymbols(), {'DOGE'});
  });
}
