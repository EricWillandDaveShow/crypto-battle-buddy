import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../assets/asset_catalog_store.dart';
import '../assets/dynamic_asset.dart';
import '../assets/dynamic_asset_store.dart';
import '../assets/asset_registry.dart';

/// Universal Manage Assets:
/// - Search + toggle on/off in ONE place
/// - CoinGecko search is inline (no separate "Add" screen)
/// - Remove deletes a dynamic asset from local stores + disables it.
///
/// NOTE: Enabling a new symbol here may exceed current UI support (pill rendering) until
/// OperatorScreen is made symbol-driven. That's expected; this is the coverage-first path.
class ManageAssetsUniversalScreen extends StatefulWidget {
  final Set<String> enabledSymbols;
  final Future<void> Function(String symbolUpper, bool enabled) onToggle;

  const ManageAssetsUniversalScreen({
    super.key,
    required this.enabledSymbols,
    required this.onToggle,
  });

  @override
  State<ManageAssetsUniversalScreen> createState() => _ManageAssetsUniversalScreenState();
}

class _ManageAssetsUniversalScreenState extends State<ManageAssetsUniversalScreen> {
  final AssetCatalogStore _store = AssetCatalogStore();
  final DynamicAssetStore _dynamicStore = DynamicAssetStore();

  final TextEditingController _search = TextEditingController();

  Map<String, String> _catalog = const <String, String>{};
  List<DynamicAsset> _dynamicAssets = const <DynamicAsset>[];
  bool _loading = true;
  late Set<String> _enabled = Set<String>.from(widget.enabledSymbols.map((e) => e.toUpperCase()));

  bool _cgLoading = false;
  String _cgStatus = '';
  List<_CgHit> _cgHits = const <_CgHit>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cat = await _store.loadCatalog();
    final dyn = await _dynamicStore.loadAll();
    final merged = <String, String>{...cat};
    for (final a in dyn) {
      merged[a.symbol.toUpperCase()] = a.coingeckoId;
    }
    if (!mounted) return;
    setState(() {
      _catalog = merged;
      _dynamicAssets = dyn;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggle(String sym, bool enabled) async {
    final s = sym.toUpperCase();
    setState(() {
      if (enabled) {
        _enabled.add(s);
      } else {
        _enabled.remove(s);
      }
    });
    // Persist universal enabled set.
    await _store.saveEnabledSymbols(_enabled);
    // Also inform caller (so existing UI can update for known assets).
    await widget.onToggle(s, enabled);
  }

  Future<void> _searchCoinGecko(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _cgHits = const <_CgHit>[];
        _cgStatus = '';
      });
      return;
    }
    setState(() {
      _cgLoading = true;
      _cgStatus = '';
    });
    try {
      final uri = Uri.https('api.coingecko.com', '/api/v3/search', <String, String>{
        'query': query,
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        throw Exception('CoinGecko search error ${resp.statusCode}');
      }
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final coins = (decoded['coins'] as List<dynamic>? ?? const <dynamic>[]);
      final next = coins
          .whereType<Map>()
          .map((m) => _CgHit.fromJson(Map<String, dynamic>.from(m)))
          .take(40)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _cgHits = next;
        _cgStatus = next.isEmpty ? 'No results.' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cgStatus = 'Search failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cgLoading = false;
        });
      }
    }
  }

  Future<void> _addHit(_CgHit hit) async {
    final sym = hit.symbol.toUpperCase();
    // Persist dynamic asset
    await _dynamicStore.upsert(
      DynamicAsset(
        symbol: sym,
        name: hit.name,
        coingeckoId: hit.id,
      ),
    );
    // Persist symbol -> coingecko id mapping for feed resolution
    await _store.upsert(sym, hit.id);

    // Refresh local view + enable immediately
    await _load();
    await _toggle(sym, true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $sym')),
    );
  }

  Future<void> _removeAsset(String sym) async {
    final s = sym.toUpperCase();
    final existedInCatalog = _catalog.containsKey(s);
    final existedInDynamic = _dynamicAssets.any((a) => a.symbol.toUpperCase() == s);
    // Disable first
    if (_enabled.contains(s)) {
      await _toggle(s, false);
    }

    // Remove from both stores (dynamic asset + catalog id map)
    await _store.remove(s);
    await _dynamicStore.remove(s);
    // ignore: avoid_print
    print(
      'MANAGE_ASSETS_PURGE: symbol=$s existedInCatalog=$existedInCatalog existedInDynamic=$existedInDynamic',
    );

    await _load();
    if (!mounted) return;
    final removedFromLocalCatalog = existedInCatalog || existedInDynamic;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removedFromLocalCatalog
              ? 'Purged $s from local catalog'
              : 'Removed $s from local catalog',
        ),
      ),
    );
  }

  Future<void> _resetToAnchors() async {
    final anchors = <String>{};
    final removed = _enabled.difference(anchors).toList()..sort();
    final added = anchors.difference(_enabled).toList()..sort();

    setState(() {
      _enabled = Set<String>.from(anchors);
    });
    await _store.saveEnabledSymbols(_enabled);

    for (final sym in removed) {
      await widget.onToggle(sym, false);
    }
    for (final sym in added) {
      await widget.onToggle(sym, true);
    }

    // ignore: avoid_print
    print('MANAGE_ASSETS_RESET_TO_ANCHORS: ${(_enabled.toList()..sort())}');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleared enabled assets')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Assets')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final q = _search.text.trim().toLowerCase();
    final anchors = <String>{};
    final dynSyms = _catalog.keys.map((k) => k.toUpperCase()).toSet();
    final enabledSyms = _enabled.map((e) => e.toUpperCase()).toSet();
    final showSyms = <String>{...anchors, ...enabledSyms, ...dynSyms}.toList()..sort();

    final filtered = q.isEmpty
        ? showSyms
        : showSyms.where((sym) {
            final reg = AssetRegistry.bySymbol(sym);
            final name = (reg?.name ?? '').toLowerCase();
            return sym.toLowerCase().contains(q) || name.contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Assets'),
        actions: [
          TextButton(
            onPressed: _resetToAnchors,
            child: const Text('Clear Enabled'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Search & manage assets',
                hintText: 'Type to filter. Press search to query CoinGecko.',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _cgLoading ? null : () => _searchCoinGecko(_search.text),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchCoinGecko(_search.text),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            if (_cgLoading) const LinearProgressIndicator(),
            if (_cgStatus.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _cgStatus,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.75),
                ),
              ),
            ],
            if (_cgHits.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('CoinGecko results', style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  children: [
                    for (final h in _cgHits)
                      ListTile(
                        title: Text('${h.symbol.toUpperCase()} — ${h.name}'),
                        subtitle: Text('id: ${h.id}'),
                        trailing: const Icon(Icons.add),
                        onTap: () => _addHit(h),
                      ),
                    const Divider(height: 18),
                    for (final sym in filtered) _assetRow(sym, enabled: _enabled.contains(sym)),
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: ListView(
                  children: [
                    for (final sym in filtered) _assetRow(sym, enabled: _enabled.contains(sym)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assetRow(String sym, {required bool enabled}) {
    final isAnchor = false;
    final reg = AssetRegistry.bySymbol(sym);
    final name = reg?.name ??
        _dynamicAssets
            .firstWhere(
              (a) => a.symbol.toUpperCase() == sym,
              orElse: () => DynamicAsset(
                symbol: sym,
                name: sym,
                coingeckoId: _catalog[sym] ?? '',
              ),
            )
            .name;
    final id = _catalog[sym];

    return ListTile(
      title: Text('$sym — $name'),
      subtitle: (id == null || id.isEmpty) ? null : Text('CoinGecko id: $id'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: enabled,
            onChanged: (v) => _toggle(sym, v),
          ),
          IconButton(
            tooltip: 'Remove asset',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeAsset(sym),
          ),
        ],
      ),
    );
  }
}

class _CgHit {
  final String id;
  final String name;
  final String symbol;

  const _CgHit({
    required this.id,
    required this.name,
    required this.symbol,
  });

  static _CgHit fromJson(Map<String, dynamic> json) => _CgHit(
        id: (json['id'] as String),
        name: (json['name'] as String?) ?? '',
        symbol: (json['symbol'] as String?) ?? '',
      );
}
