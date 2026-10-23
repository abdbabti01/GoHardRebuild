import 'dart:convert';

import '../../core/clock.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/sync.dart';
import 'food_item.dart';
import 'food_search.dart';

/// `offline` is "the request did not get through": the app cannot tell a phone without a connection from a
/// server that is down, so nothing built on it may claim the phone is offline. `timeout` is no answer in time.
enum LookupProblem { offline, timeout, notFound, invalid, rateLimited, notConfigured, unavailable }

/// A lookup that produced no food. The reason is kept so the screen can say something true and offer a way on.
class LookupFailure implements Exception {
  const LookupFailure(this.problem);
  final LookupProblem problem;
  @override
  String toString() => 'LookupFailure(${problem.name})';
}

/// Finds foods through the account's server, which talks to Open Food Facts and USDA. Nothing found here is
/// logged: a result only ever becomes a draft in the food form. Every food seen is kept on the phone, per owner,
/// so it can be found again without a connection.
class FoodDiscovery {
  FoodDiscovery(this._api, this._sync, this._owner, this._clock);
  final Api _api;
  final SyncEngine _sync;
  final String _owner;
  final AppClock _clock;
  final _inFlight = <String, Future<Object?>>{};

  static const maxCached = 300;
  static const _fresh = Duration(days: 7);

  /// One request per distinct question at a time: a second tap or a repeated scan joins the first.
  Future<T> _once<T>(String key, Future<T> Function() run) =>
      (_inFlight[key] ??= run().whenComplete(() {
        _inFlight.remove(key); // a block, not an arrow: returning the removed future here would make it wait for itself
      })) as Future<T>;

  Future<ApiResponse> _get(String path) async {
    try {
      return await _api.send('GET', path);
    } on TransportFailure catch (e) {
      throw LookupFailure(e.message.toLowerCase().contains('timeout') ? LookupProblem.timeout : LookupProblem.offline);
    }
  }

  static LookupFailure _failure(ApiResponse r) => LookupFailure(switch ((r.status, r.data is Map ? (r.data as Map)['code'] : null)) {
        (404, 'NOT_FOUND') => LookupProblem.notFound,
        (422, _) => LookupProblem.invalid,
        (429, _) => LookupProblem.rateLimited,
        (_, 'PROVIDER_NOT_CONFIGURED') => LookupProblem.notConfigured,
        // A server from before food lookup answers 404 with no code: the feature is simply not there.
        (404, _) => LookupProblem.notConfigured,
        _ => LookupProblem.unavailable,
      });

  /// Text search of basic and branded foods in the wider database. Never per keystroke: the screen asks on a
  /// tap, or once after a pause when the phone itself has nothing for what was typed.
  Future<List<FoodItem>> search(String query) async {
    final q = query.trim().split(RegExp(r'\s+')).join(' ');
    if (q.length < 2) throw const LookupFailure(LookupProblem.invalid);
    return _once<List<FoodItem>>('search:${q.toLowerCase()}', () async {
      final r = await _get('/foods/search?q=${Uri.encodeQueryComponent(q)}');
      if (!r.ok) throw _failure(r);
      final items = [for (final i in (r.data as Json)['results'] as List? ?? const []) FoodItem(i as Json)];
      await remember(items);
      return items;
    });
  }

  /// A packaged product by its barcode. A product looked up in the last week is answered from the phone; when
  /// the server cannot be reached, an older copy is still better than nothing and is returned as it was.
  Future<FoodItem> barcode(String raw) async {
    final code = normalizeBarcode(raw);
    if (code == null) throw const LookupFailure(LookupProblem.invalid);
    return _once<FoodItem>('barcode:$code', () async {
      final kept = (await cached()).where((c) => c.item.barcode == code).firstOrNull;
      if (kept != null && _clock.utcNow().difference(kept.at) < _fresh) return kept.item;
      try {
        final r = await _get('/foods/barcode/$code');
        if (!r.ok) throw _failure(r);
        final item = FoodItem((r.data as Json)['item'] as Json);
        await remember([item]);
        return item;
      } on LookupFailure catch (e) {
        if (kept != null && e.problem != LookupProblem.notFound) return kept.item;
        rethrow;
      }
    });
  }

  /// Foods kept on this phone for this owner, most recently seen first.
  Future<List<({FoodItem item, DateTime at})>> cached() async {
    final rows = [
      for (final r in await _sync.list(_owner, Kinds.foodCache))
        () {
          final j = jsonDecode(r.body) as Json;
          return (item: FoodItem(j['item'] as Json), at: DateTime.parse(j['cachedAtUtc'] as String));
        }(),
    ];
    return rows..sort((a, b) => b.at.compareTo(a.at));
  }

  /// Keeps `items` for offline use and drops the oldest beyond [maxCached]. A failure to keep them is not a
  /// failure of the lookup: the foods are still returned.
  Future<void> remember(List<FoodItem> items) async {
    try {
      final now = _clock.utcNow().toIso8601String();
      for (final item in items) {
        await _sync.putLocal(_owner, LocalWrite(Kinds.foodCache, item.key, {'item': item.j, 'cachedAtUtc': now}));
      }
      for (final old in (await cached()).skip(maxCached)) {
        await _sync.deleteLocal(_owner, Kinds.foodCache, old.item.key);
      }
    } on LocalSaveFailure {
      // Nothing was promised to the user about the cache.
    }
  }
}

/// Where a suggestion came from. The first four are the owner's, on this phone; `common` is the bundled catalog;
/// `found` is an answer from the wider database.
enum Origin { favourite, mine, recent, seen, common, found }

class Suggestion {
  const Suggestion(this.item, this.origin, {this.saved, this.entry, this.common});
  final FoodItem item;
  final Origin origin;

  /// The owner's saved record behind a favourite or one of their own foods.
  final Json? saved;

  /// The journal entry behind a recent food: choosing it starts from the same amount and values again.
  final FoodEntry? entry;

  /// The catalog entry when this is that very record: the everyday name and preparation it is shown by.
  final CommonFood? common;
}

/// What the phone already knows, without a connection: favourites and the owner's foods, then foods logged
/// before (newest first, each once), then provider foods seen earlier. `query` filters by name or brand.
List<Suggestion> localSuggestions({required List<Json> saved, required List<FoodEntry> journal, required List<FoodItem> seen, String query = ''}) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  bool matches(FoodItem i) {
    final text = '${i.name} ${i.brand ?? ''}'.toLowerCase();
    return words.every(text.contains);
  }

  final taken = <String>{};
  final out = <Suggestion>[];
  void add(Suggestion s, String identity) {
    if (matches(s.item) && taken.add(identity)) out.add(s);
  }

  for (final j in saved) {
    final item = FoodItem(j['item'] as Json? ?? const {});
    if (j['isDeleted'] != true && j['isFavourite'] == true) add(Suggestion(item, Origin.favourite, saved: j), item.key);
  }
  for (final j in saved) {
    final item = FoodItem(j['item'] as Json? ?? const {});
    if (j['isDeleted'] != true && item.source == 'user') add(Suggestion(item, Origin.mine, saved: j), item.key);
  }
  final newestFirst = [...journal]..sort((a, b) => b.dayKey.compareTo(a.dayKey));
  for (final e in newestFirst) {
    // A recipe portion is logged again from Saved meals & recipes, where its batch and yield are.
    if (e.isDeleted || e.isRecipePortion) continue;
    final source = e.source?['item'];
    // An entry typed by hand has no food behind it; it is offered as itself, with the amount it was logged with.
    final item = source is Map ? FoodItem(source as Json) : FoodItem({'source': 'user', 'name': e.name, 'basis': FoodItem.perServing, 'nutrients': e.macros, 'servings': [{'label': e.amountDescription}]});
    add(Suggestion(item, Origin.recent, entry: e), source is Map ? item.key : 'typed:${e.name.toLowerCase()}');
  }
  for (final item in seen) {
    add(Suggestion(item, Origin.seen), item.key);
  }
  return out;
}
