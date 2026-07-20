import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto_battle_buddy/battle_buddy_engine.dart';
import 'package:crypto_battle_buddy/core/portfolio_state.dart';
import 'package:crypto_battle_buddy/main.dart';
import 'package:crypto_battle_buddy/models/decision_result.dart';
import 'package:crypto_battle_buddy/models/feed_health.dart';
import 'package:crypto_battle_buddy/models/status_snapshot.dart';
import 'package:crypto_battle_buddy/models/threshold_execution_event.dart';
import 'package:crypto_battle_buddy/storage/storage_backend.dart';
import 'package:crypto_battle_buddy/storage/storage_backend_selector_io.dart';
import 'package:crypto_battle_buddy/storage/threshold_state_store.dart';
import 'package:crypto_battle_buddy/price/price_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingStorageBackend implements StorageBackend {
  final Map<String, String> values = <String, String>{};
  final List<String> deletedKeys = <String>[];

  @override
  Future<void> deleteString(String key) async {
    deletedKeys.add(key);
    values.remove(key);
  }

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}

class _NeverCompletingPriceFeed implements PriceFeed {
  final Completer<Map<String, double>> _prices =
      Completer<Map<String, double>>();
  FeedHealth _health = FeedHealth(
    status: FeedStatus.healthy,
    timestamp: DateTime.now(),
    message: 'test',
  );

  @override
  Future<Map<String, double>> fetchPrices({required List<String> symbols}) {
    return _prices.future;
  }

  @override
  FeedHealth get health => _health;

  @override
  String get name => 'CoinGecko';

  @override
  void updateHealth(FeedHealth health) {
    _health = health;
  }
}

class _CompletingPriceFeed implements PriceFeed {
  final Map<String, double> prices;
  final Object? error;
  final String successMessage;
  int fetchCount = 0;
  List<String> lastRequestedSymbols = const <String>[];
  FeedHealth _health = FeedHealth(
    status: FeedStatus.healthy,
    timestamp: DateTime.now(),
    message: 'test',
  );

  _CompletingPriceFeed({
    required this.prices,
    this.error,
    this.successMessage = 'fresh-success',
  });

  @override
  Future<Map<String, double>> fetchPrices({
    required List<String> symbols,
  }) async {
    fetchCount++;
    lastRequestedSymbols = List<String>.from(symbols);
    final failure = error;
    if (failure != null) throw failure;
    _health = FeedHealth(
      status: FeedStatus.healthy,
      timestamp: DateTime.now(),
      message: successMessage,
    );
    return Map<String, double>.from(prices);
  }

  @override
  FeedHealth get health => _health;

  @override
  String get name => 'CoinGecko';

  @override
  void updateHealth(FeedHealth health) {
    _health = health;
  }
}

class _SequencedPriceFeed implements PriceFeed {
  final List<Map<String, double>> responses;
  int fetchCount = 0;
  List<String> lastRequestedSymbols = const <String>[];
  FeedHealth _health = FeedHealth(
    status: FeedStatus.healthy,
    timestamp: DateTime.now(),
    message: 'test',
  );

  _SequencedPriceFeed(this.responses);

  @override
  Future<Map<String, double>> fetchPrices({
    required List<String> symbols,
  }) async {
    lastRequestedSymbols = List<String>.from(symbols);
    final responseIndex =
        fetchCount < responses.length ? fetchCount : responses.length - 1;
    fetchCount++;
    _health = FeedHealth(
      status: FeedStatus.healthy,
      timestamp: DateTime.now(),
      message: 'sequence-$fetchCount',
    );
    return Map<String, double>.from(responses[responseIndex]);
  }

  @override
  FeedHealth get health => _health;

  @override
  String get name => 'CoinGecko';

  @override
  void updateHealth(FeedHealth health) {
    _health = health;
  }
}

Map<String, Object> _enabledBtcPreferences() => <String, Object>{
      'asset_catalog_v1': jsonEncode(<String, String>{'BTC': 'bitcoin'}),
      'asset_enabled_v1': <String>['BTC'],
    };

Future<dynamic> _pumpUntilAppState(
  WidgetTester tester,
  bool Function(dynamic state) condition,
) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 5));
    final dynamic state = tester.state(find.byType(AppShell));
    if (condition(state)) return state;
  }
  fail('AppShell did not reach the expected state.');
}

void _expectDebugReportActions({required bool enabled}) {
  final copyButton = testerWidget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Copy Report JSON'),
  );
  final exportButton = testerWidget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Export Report'),
  );
  expect(copyButton.onPressed, enabled ? isNotNull : isNull);
  expect(exportButton.onPressed, enabled ? isNotNull : isNull);
}

T testerWidget<T extends Widget>(Finder finder) {
  final widgets = finder.evaluate();
  expect(widgets, hasLength(1));
  return widgets.single.widget as T;
}

void _expectNoCurrentMarketPublication(dynamic state) {
  expect(state.snapshot, isNull);
  expect(state.livePricesUsd, isEmpty);
  expect(state.snapshotPretty, isEmpty);
  expect(state.reportPretty, isEmpty);
  expect(state.lastReportJson, isNull);
  expect(state.currentReport, isNull);
  expect(state.statusText, isEmpty);
  expect(state.nextActionText, isEmpty);
  expect(state.alerts, isEmpty);
  _expectDebugReportActions(enabled: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryStorageBackend backend;
  late BattleBuddyEngine engine;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    backend = MemoryStorageBackend();
    engine = BattleBuddyEngine(storageBackend: backend);
  });

  test('legacy last_report is deleted and ignored at startup', () async {
    await backend.writeString(
      'last_report',
      jsonEncode(<String, dynamic>{
        'recommendation': 'BUY',
        'deployment_amount': 250,
      }),
    );

    await engine.clearTransientMarketCaches();

    expect(await backend.readString('last_report'), isNull);
    expect(await engine.loadLastReportJson(), isNull);
  });

  test('factual-version last_report is also deleted and ignored', () async {
    await backend.writeString(
      'last_report',
      jsonEncode(<String, dynamic>{
        'schemaVersion': 'factual-v1',
        'observedPrice': 42000,
      }),
    );

    await engine.clearTransientMarketCaches();

    expect(await backend.readString('last_report'), isNull);
    expect(await engine.loadLastReportJson(), isNull);
  });

  test('snapshot and cooldown caches are deleted by exact key', () async {
    await backend.writeString('last_snapshot', '{"price":42000}');
    await backend.writeString(
      'cooldowns',
      '{"BTC:buy":"2026-07-17T12:00:00.000Z"}',
    );
    await backend.writeString('selected_profile', 'Balanced');
    await backend.writeString('lockdown_state', '{"enabled":false}');

    await engine.clearTransientMarketCaches();

    expect(await backend.readString('last_snapshot'), isNull);
    expect(await backend.readString('cooldowns'), isNull);
    expect(await backend.readString('selected_profile'), 'Balanced');
    expect(
      await backend.readString('lockdown_state'),
      '{"enabled":false}',
    );
  });

  test('purge requests exactly the three transient cache keys', () async {
    final recordingBackend = _RecordingStorageBackend();
    final recordingEngine = BattleBuddyEngine(storageBackend: recordingBackend);

    await recordingEngine.clearTransientMarketCaches();

    expect(recordingBackend.deletedKeys, hasLength(3));
    expect(
      recordingBackend.deletedKeys,
      unorderedEquals(<String>['last_report', 'last_snapshot', 'cooldowns']),
    );
  });

  group('IO storage key confinement', () {
    late Directory root;
    late Directory storageDirectory;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('cbb_storage_test_');
      storageDirectory = Directory(
        '${root.path}${Platform.pathSeparator}cbb_storage',
      );
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    for (final invalidKey in <String>[
      '',
      '../outside',
      r'..\outside',
      '/absolute/path',
      'C:drive-relative-path',
      r'C:\absolute\path',
      'folder/key',
      r'folder\key',
    ]) {
      test('rejects deletion key "$invalidKey" without filesystem access',
          () async {
        final backend = IoFileStorageBackend(
          storageDirectory: storageDirectory,
        );
        final outsideFile = File(
          '${root.path}${Platform.pathSeparator}outside.json',
        );
        await outsideFile.writeAsString('preserve me');

        await expectLater(
          backend.deleteString(invalidKey),
          throwsArgumentError,
        );

        expect(await outsideFile.readAsString(), 'preserve me');
        expect(await storageDirectory.exists(), isFalse);
      });
    }

    test('invalid read and write keys perform no filesystem access', () async {
      final backend = IoFileStorageBackend(
        storageDirectory: storageDirectory,
      );

      await expectLater(backend.readString('../outside'), throwsArgumentError);
      await expectLater(
        backend.writeString('../outside', 'value'),
        throwsArgumentError,
      );

      expect(await storageDirectory.exists(), isFalse);
    });

    test('physical deletion failure leaves the exact key unreadable', () async {
      final backend = IoFileStorageBackend(
        storageDirectory: storageDirectory,
        deleteFileOverride: (_) async {
          throw const FileSystemException('simulated deletion failure');
        },
      );
      await backend.writeString('last_report', 'legacy');
      final physicalFile = File(
        '${storageDirectory.path}${Platform.pathSeparator}last_report.json',
      );

      await backend.deleteString('last_report');

      expect(await physicalFile.readAsString(), 'legacy');
      expect(await backend.readString('last_report'), isNull);

      await backend.writeString('last_report', 'fresh');
      expect(await backend.readString('last_report'), 'fresh');
    });
  });

  testWidgets('application startup contains all transient cache restoration',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final startupBackend = MemoryStorageBackend();
    final startupEngine = BattleBuddyEngine(storageBackend: startupBackend);
    final timestamp = DateTime.utc(2026, 7, 17, 12);
    await startupBackend.writeString(
      'last_report',
      jsonEncode(<String, dynamic>{'marker': 'legacy-report-marker'}),
    );
    await startupBackend.writeString(
      'last_snapshot',
      jsonEncode(<String, dynamic>{'marker': 'legacy-snapshot-marker'}),
    );
    await startupBackend.writeString(
      'cooldowns',
      jsonEncode(<String, dynamic>{
        'BTC:buyZone': timestamp.toIso8601String(),
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell.forTesting(
          showDebug: true,
          engine: startupEngine,
          feed: _NeverCompletingPriceFeed(),
        ),
      ),
    );
    for (var i = 0;
        i < 20 && find.text('No saved report found').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    expect(find.text('No saved report found'), findsOneWidget);
    expect(find.textContaining('legacy-report-marker'), findsNothing);
    expect(find.textContaining('legacy-snapshot-marker'), findsNothing);
    expect(await startupBackend.readString('last_report'), isNull);
    expect(await startupBackend.readString('last_snapshot'), isNull);
    expect(await startupBackend.readString('cooldowns'), isNull);

    final alerts = startupEngine.generateAlertsFromSnapshot(
      snapshot: StatusSnapshot(
        timestamp: timestamp,
        prices: const <String, double>{'BTC': 42000},
        decisions: const <String, DecisionResult>{
          'BTC': DecisionResult(
            state: PortfolioState.buyZone,
            message: 'threshold crossed',
          ),
        },
      ),
    );
    expect(alerts, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed first poll purges caches without publishing a report',
      (tester) async {
    SharedPreferences.setMockInitialValues(_enabledBtcPreferences());
    final startupBackend = MemoryStorageBackend();
    final startupEngine = BattleBuddyEngine(storageBackend: startupBackend);
    final feed = _CompletingPriceFeed(
      prices: const <String, double>{},
      error: Exception('offline'),
    );
    await startupBackend.writeString(
      'last_report',
      jsonEncode(<String, dynamic>{'marker': 'legacy-report-marker'}),
    );
    await startupBackend.writeString(
      'last_snapshot',
      jsonEncode(<String, dynamic>{'marker': 'legacy-snapshot-marker'}),
    );
    await startupBackend.writeString(
      'cooldowns',
      jsonEncode(<String, dynamic>{
        'BTC:buyZone': DateTime.utc(2026, 7, 17, 12).toIso8601String(),
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell.forTesting(
          showDebug: true,
          engine: startupEngine,
          feed: feed,
        ),
      ),
    );
    final dynamic state = await _pumpUntilAppState(
      tester,
      (dynamic value) =>
          feed.fetchCount > 0 && value.health.status == FeedStatus.degraded,
    );

    expect(await startupBackend.readString('last_report'), isNull);
    expect(await startupBackend.readString('last_snapshot'), isNull);
    expect(await startupBackend.readString('cooldowns'), isNull);
    expect(state.snapshot, isNull);
    expect(state.livePricesUsd, isEmpty);
    expect(state.snapshotPretty, isEmpty);
    expect(state.reportPretty, isEmpty);
    expect(state.lastReportJson, isNull);
    expect(state.currentReport, isNull);
    expect(state.statusText, isEmpty);
    expect(state.nextActionText, isEmpty);
    expect(find.text('No saved report found'), findsOneWidget);
    expect(find.textContaining('legacy-report-marker'), findsNothing);
    expect(find.textContaining('legacy-snapshot-marker'), findsNothing);
    _expectDebugReportActions(enabled: false);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no enabled assets do not publish or persist a current report',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final startupBackend = MemoryStorageBackend();
    final startupEngine = BattleBuddyEngine(storageBackend: startupBackend);
    final feed = _CompletingPriceFeed(
      prices: const <String, double>{},
      successMessage: 'empty-no-assets',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell.forTesting(
          showDebug: true,
          engine: startupEngine,
          feed: feed,
        ),
      ),
    );
    final dynamic state = await _pumpUntilAppState(
      tester,
      (dynamic value) => value.health.message == 'empty-no-assets',
    );

    expect(feed.lastRequestedSymbols, isEmpty);
    expect(state.snapshot, isNull);
    expect(state.livePricesUsd, isEmpty);
    expect(state.reportPretty, isEmpty);
    expect(state.lastReportJson, isNull);
    expect(state.currentReport, isNull);
    expect(await startupBackend.readString('last_report'), isNull);
    _expectDebugReportActions(enabled: false);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty returned price map does not publish a current report',
      (tester) async {
    SharedPreferences.setMockInitialValues(_enabledBtcPreferences());
    final startupBackend = MemoryStorageBackend();
    final startupEngine = BattleBuddyEngine(storageBackend: startupBackend);
    final feed = _CompletingPriceFeed(
      prices: const <String, double>{},
      successMessage: 'empty-prices',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell.forTesting(
          showDebug: true,
          engine: startupEngine,
          feed: feed,
        ),
      ),
    );
    final dynamic state = await _pumpUntilAppState(
      tester,
      (dynamic value) => value.health.message == 'empty-prices',
    );

    expect(feed.lastRequestedSymbols, <String>['BTC']);
    expect(state.snapshot, isNull);
    expect(state.livePricesUsd, isEmpty);
    expect(state.reportPretty, isEmpty);
    expect(state.lastReportJson, isNull);
    expect(state.currentReport, isNull);
    expect(await startupBackend.readString('last_report'), isNull);
    _expectDebugReportActions(enabled: false);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fresh successful poll publishes and persists current report',
      (tester) async {
    SharedPreferences.setMockInitialValues(_enabledBtcPreferences());
    final startupBackend = MemoryStorageBackend();
    final startupEngine = BattleBuddyEngine(storageBackend: startupBackend);
    final feed = _CompletingPriceFeed(
      prices: const <String, double>{'BTC': 42000},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell.forTesting(
          showDebug: true,
          engine: startupEngine,
          feed: feed,
        ),
      ),
    );
    final dynamic state = await _pumpUntilAppState(
      tester,
      (dynamic value) => value.currentReport != null,
    );
    await tester.pump();

    expect(feed.lastRequestedSymbols, <String>['BTC']);
    expect(state.snapshot, isNotNull);
    expect(state.snapshot.prices, <String, double>{'BTC': 42000});
    expect(state.livePricesUsd, <String, double>{'BTC': 42000});
    expect(state.reportPretty, isNotEmpty);
    expect(state.lastReportJson, isNotNull);
    expect(state.currentReport, isNotNull);
    expect(state.statusText, isNotEmpty);
    expect(state.nextActionText, isNotEmpty);
    final persistedReport = await startupBackend.readString('last_report');
    expect(persistedReport, isNotNull);
    expect(persistedReport, contains('42000'));
    expect(find.text('Last Saved Report loaded'), findsOneWidget);
    _expectDebugReportActions(enabled: true);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unrequested-only prices cannot create market state',
      (tester) async {
    SharedPreferences.setMockInitialValues(_enabledBtcPreferences());
    final startupBackend = MemoryStorageBackend();
    final startupEngine = BattleBuddyEngine(storageBackend: startupBackend);
    final feed = _CompletingPriceFeed(
      prices: const <String, double>{'UNREQUESTED': 0.5},
      successMessage: 'unrequested-only',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell.forTesting(
          showDebug: true,
          engine: startupEngine,
          feed: feed,
        ),
      ),
    );
    final dynamic state = await _pumpUntilAppState(
      tester,
      (dynamic value) => value.health.message == 'unrequested-only',
    );

    expect(feed.lastRequestedSymbols, <String>['BTC']);
    _expectNoCurrentMarketPublication(state);
    expect(await startupBackend.readString('last_report'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('threshold_plan_UNREQUESTED'), isFalse);
    expect(prefs.containsKey('threshold_state_UNREQUESTED'), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final unusableCase in <String, Map<String, double>>{
    'zero': const <String, double>{'BTC': 0},
    'negative': const <String, double>{'BTC': -1},
    'NaN': const <String, double>{'BTC': double.nan},
    'positive infinity': const <String, double>{
      'BTC': double.infinity,
    },
    'negative infinity': const <String, double>{
      'BTC': double.negativeInfinity,
    },
  }.entries) {
    testWidgets('${unusableCase.key} price cannot publish or persist',
        (tester) async {
      SharedPreferences.setMockInitialValues(_enabledBtcPreferences());
      final startupBackend = MemoryStorageBackend();
      final startupEngine = BattleBuddyEngine(storageBackend: startupBackend);
      final message = 'rejected-${unusableCase.key}';
      final feed = _CompletingPriceFeed(
        prices: unusableCase.value,
        successMessage: message,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell.forTesting(
            showDebug: true,
            engine: startupEngine,
            feed: feed,
          ),
        ),
      );
      final dynamic state = await _pumpUntilAppState(
        tester,
        (dynamic value) => value.health.message == message,
      );

      _expectNoCurrentMarketPublication(state);
      expect(await startupBackend.readString('last_report'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('threshold_state_BTC'), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('mixed result publishes only requested finite positive prices',
      (tester) async {
    SharedPreferences.setMockInitialValues(_enabledBtcPreferences());
    final startupBackend = MemoryStorageBackend();
    final startupEngine = BattleBuddyEngine(storageBackend: startupBackend);
    final feed = _CompletingPriceFeed(
      prices: const <String, double>{
        'btc': 42000,
        'UNREQUESTED': 0.5,
        'ZERO': 0,
        'NEGATIVE': -1,
        'NAN': double.nan,
        'POS_INF': double.infinity,
        'NEG_INF': double.negativeInfinity,
      },
      successMessage: 'mixed-result',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell.forTesting(
          showDebug: true,
          engine: startupEngine,
          feed: feed,
        ),
      ),
    );
    final dynamic state = await _pumpUntilAppState(
      tester,
      (dynamic value) => value.currentReport != null,
    );
    await tester.pump();

    expect(state.snapshot.prices, <String, double>{'BTC': 42000});
    expect(state.livePricesUsd, <String, double>{'BTC': 42000});
    expect(state.alerts, isEmpty);
    for (final rejectedSymbol in <String>[
      'UNREQUESTED',
      'ZERO',
      'NEGATIVE',
      'NAN',
      'POS_INF',
      'NEG_INF',
    ]) {
      expect(state.reportPretty, isNot(contains(rejectedSymbol)));
    }
    final persistedReport = await startupBackend.readString('last_report');
    expect(persistedReport, isNotNull);
    expect(persistedReport, contains('BTC'));
    expect(persistedReport, contains('42000'));
    final prefs = await SharedPreferences.getInstance();
    for (final rejectedSymbol in <String>[
      'UNREQUESTED',
      'ZERO',
      'NEGATIVE',
      'NAN',
      'POS_INF',
      'NEG_INF',
    ]) {
      expect(prefs.containsKey('threshold_state_$rejectedSymbol'), isFalse);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('later invalid poll preserves prior runtime and persisted report',
      (tester) async {
    SharedPreferences.setMockInitialValues(_enabledBtcPreferences());
    final startupBackend = MemoryStorageBackend();
    final startupEngine = BattleBuddyEngine(storageBackend: startupBackend);
    final feed = _SequencedPriceFeed(<Map<String, double>>[
      const <String, double>{'BTC': 42000},
      const <String, double>{
        'BTC': 0,
        'UNREQUESTED': 0.5,
      },
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell.forTesting(
          showDebug: true,
          engine: startupEngine,
          feed: feed,
        ),
      ),
    );
    final dynamic state = await _pumpUntilAppState(
      tester,
      (dynamic value) => value.currentReport != null,
    );
    await tester.pump();
    final priorSnapshot = state.snapshot;
    final priorReport = state.currentReport;
    final priorReportPretty = state.reportPretty;
    final priorReportJson = state.lastReportJson;
    final priorStatusText = state.statusText;
    final priorNextActionText = state.nextActionText;
    final persistedBeforeInvalid =
        await startupBackend.readString('last_report');

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(seconds: 30));
    await _pumpUntilAppState(
      tester,
      (dynamic value) =>
          feed.fetchCount >= 2 && value.health.message == 'sequence-2',
    );

    expect(state.snapshot, same(priorSnapshot));
    expect(state.currentReport, same(priorReport));
    expect(state.reportPretty, priorReportPretty);
    expect(state.lastReportJson, same(priorReportJson));
    expect(state.statusText, priorStatusText);
    expect(state.nextActionText, priorNextActionText);
    expect(state.livePricesUsd, <String, double>{'BTC': 42000});
    expect(
      await startupBackend.readString('last_report'),
      persistedBeforeInvalid,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('threshold_state_UNREQUESTED'), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('historical execution and missed records remain intact', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'threshold_plan_BTC': '{"assetSymbol":"BTC"}',
      'threshold_state_BTC': '{"BTC:0":{"status":"executed"}}',
      'engine_holdings_v1': '{"BTC":0.5}',
      'operator_armed_symbols_v1': <String>['BTC'],
      'user_setting': 'preserved',
    });
    final executedAt = DateTime.utc(2026, 7, 16, 12);
    await ThresholdStateStore.appendExecutionEvent(
      symbol: 'BTC',
      event: ThresholdExecutionEvent(
        symbolUpper: 'BTC',
        stepId: 'BTC:0',
        tierIndex: 0,
        action: 'SELL',
        triggerPriceUsd: 42000,
        observedPriceUsd: 42100,
        percentOfPositionSnapshot: 25,
        positionUnitsSnapshot: 0.1,
        notionalUsdSnapshot: 4210,
        sizingSource: 'position_percent',
        reason: 'manual_execute',
        createdAt: executedAt,
      ),
    );
    await ThresholdStateStore.appendExecutionEvent(
      symbol: 'BTC',
      event: ThresholdExecutionEvent(
        symbolUpper: 'BTC',
        stepId: 'BTC:1',
        tierIndex: 1,
        action: 'SELL',
        triggerPriceUsd: 43000,
        observedPriceUsd: 42900,
        percentOfPositionSnapshot: 25,
        positionUnitsSnapshot: 0.1,
        notionalUsdSnapshot: 4290,
        sizingSource: 'position_percent',
        reason: 'missed',
        createdAt: executedAt.add(const Duration(hours: 1)),
      ),
    );

    await engine.clearTransientMarketCaches();
    await engine.loadState();
    await engine.loadHoldings();

    final prefs = await SharedPreferences.getInstance();
    final records =
        await ThresholdStateStore.loadExecutionEvents(symbol: 'BTC');
    expect(records, hasLength(2));
    expect(records.map((event) => event.reason), [
      'manual_execute',
      'missed',
    ]);
    expect(prefs.getString('threshold_plan_BTC'), isNotNull);
    expect(prefs.getString('threshold_state_BTC'), isNotNull);
    expect(prefs.getStringList('operator_armed_symbols_v1'), ['BTC']);
    expect(prefs.getString('user_setting'), 'preserved');
    expect(prefs.getString('engine_holdings_v1'), '{"BTC":0.5}');
    expect(engine.holdingOf('BTC'), 0.5);
    expect(engine.discipline.currentCycle, 0.5);
    expect(engine.discipline.lifetime, 0.5);
  });
}
