import 'package:crypto_battle_buddy/assets/removed_asset_purge_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no removal returns empty', () {
    expect(
      computeRemovedAssetSymbols(
        previousSymbols: const ['BTC', 'ETH'],
        nextSymbols: const ['BTC', 'ETH'],
      ),
      isEmpty,
    );
  });

  test('simple removal returns removed symbol', () {
    expect(
      computeRemovedAssetSymbols(
        previousSymbols: const ['BTC', 'ETH'],
        nextSymbols: const ['BTC'],
      ),
      {'ETH'},
    );
  });

  test('multiple removals return all removed symbols', () {
    expect(
      computeRemovedAssetSymbols(
        previousSymbols: const ['BTC', 'ETH', 'SOL', 'DOGE'],
        nextSymbols: const ['BTC'],
      ),
      {'ETH', 'SOL', 'DOGE'},
    );
  });

  test('addition only returns empty', () {
    expect(
      computeRemovedAssetSymbols(
        previousSymbols: const ['BTC'],
        nextSymbols: const ['BTC', 'ETH'],
      ),
      isEmpty,
    );
  });

  test('replacement returns only symbol that disappeared', () {
    expect(
      computeRemovedAssetSymbols(
        previousSymbols: const ['BTC', 'DOGE'],
        nextSymbols: const ['BTC', 'PEPE'],
      ),
      {'DOGE'},
    );
  });

  test('case and whitespace normalization avoids false removals', () {
    expect(
      computeRemovedAssetSymbols(
        previousSymbols: const [' btc ', 'Eth', '', '   '],
        nextSymbols: const ['BTC', ' eth '],
      ),
      isEmpty,
    );
  });
}
