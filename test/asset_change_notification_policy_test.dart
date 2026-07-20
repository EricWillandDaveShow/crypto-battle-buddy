import 'package:crypto_battle_buddy/ui/asset_change_notification_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 20, 12);
  const cooldown = Duration(seconds: 10);

  test('no enabled-symbol set change returns false after normalization', () {
    expect(
      shouldNotifyAssetChange(
        beforeEnabled: {' btc ', 'ETH'},
        afterEnabled: {'BTC', ' eth '},
        now: now,
        lastNotifiedAt: now.subtract(const Duration(seconds: 2)),
        cooldown: cooldown,
      ),
      isFalse,
    );
  });

  test('addition inside cooldown returns true', () {
    expect(
      shouldNotifyAssetChange(
        beforeEnabled: {'BTC'},
        afterEnabled: {'BTC', 'DOGE'},
        now: now,
        lastNotifiedAt: now.subtract(const Duration(seconds: 2)),
        cooldown: cooldown,
      ),
      isTrue,
    );
  });

  test('removal inside cooldown returns true', () {
    expect(
      shouldNotifyAssetChange(
        beforeEnabled: {'BTC', 'DOGE'},
        afterEnabled: {'BTC'},
        now: now,
        lastNotifiedAt: now.subtract(const Duration(seconds: 2)),
        cooldown: cooldown,
      ),
      isTrue,
    );
  });

  test('replacement inside cooldown returns true', () {
    expect(
      shouldNotifyAssetChange(
        beforeEnabled: {'BTC'},
        afterEnabled: {'ETH'},
        now: now,
        lastNotifiedAt: now.subtract(const Duration(seconds: 2)),
        cooldown: cooldown,
      ),
      isTrue,
    );
  });

  test('changed set outside cooldown returns true', () {
    expect(
      shouldNotifyAssetChange(
        beforeEnabled: {'BTC'},
        afterEnabled: {'BTC', 'ETH'},
        now: now,
        lastNotifiedAt: now.subtract(const Duration(seconds: 11)),
        cooldown: cooldown,
      ),
      isTrue,
    );
  });
}
