import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/sync.dart';
import '../coach/coach_client.dart' show AskFailure, AskProblem, askLanguage;
import 'restaurants.dart';

/// Eating out's state on the phone (docs/EATING_OUT.md): which catalog is in use, the order being built, and asking
/// Leon or Leona in words. Browsing, building and suggestions are worked out here with no connection; only Send asks
/// the account's server, and only that server holds the AI provider's key.

// ---------------------------------------------------------------------------- the catalog

/// The catalog in use: the newer of the copy bundled with the app and the last one the account's server sent. Versions
/// are dated ("2026-10-25.1"), so the later one compares higher.
final restaurantCatalogProvider = FutureProvider<RestaurantCatalog>((ref) async {
  final bundled = RestaurantCatalog.parse(await rootBundle.loadString('assets/data/restaurant-catalog.json'))!;
  final owner = ref.watch(ownerProvider);
  if (owner == null) return bundled;
  try {
    final rec = await ref.read(syncProvider).get(owner, Kinds.eatOut, 'catalog');
    final cached = rec == null ? null : RestaurantCatalog.parse(rec.body);
    if (cached != null && cached.version.compareTo(bundled.version) > 0) return cached;
  } on Object {
    // An unreadable cached copy is not used; the bundled one is.
  }
  return bundled;
});

/// Asks the account's server for a newer catalog once (where it declares one), keeps it on the phone and switches to
/// it. The order being built is not touched: an item the new menu no longer lists is reported on screen, never
/// replaced. True when a newer catalog was taken. Any failure keeps the catalog in use.
Future<bool> refreshRestaurantCatalog(WidgetRef ref) async {
  if (!(ref.read(compatibilityProvider).capabilities?.contains(RestaurantCatalog.capability) ?? false)) return false;
  final owner = ref.read(ownerProvider);
  final current = await ref.read(restaurantCatalogProvider.future);
  if (owner == null) return false;
  try {
    final r = await ref.read(apiProvider).send('GET', '/restaurants/catalog?have=${Uri.encodeQueryComponent(current.version)}').timeout(const Duration(seconds: 15));
    if (!r.ok || r.data is! Map || (r.data as Map)['upToDate'] == true) return false;
    final text = jsonEncode(r.data);
    final fresh = RestaurantCatalog.parse(text);
    if (fresh == null || fresh.version == current.version) return false;
    await ref.read(syncProvider).putLocal(owner, LocalWrite(Kinds.eatOut, 'catalog', jsonDecode(text) as Json));
    ref.invalidate(restaurantCatalogProvider);
    return true;
  } on Object {
    return false;
  }
}

// ---------------------------------------------------------------------------- the draft

/// What is being worked on, kept on the phone for this account after every change (so leaving, a language change or a
/// restart loses nothing) and never sent anywhere: the chain, the order, the chosen preferences and the last few
/// exchanges with the coach (for follow-ups like "keep the fries").
class EatOutDraft {
  const EatOutDraft({this.chainId, this.order = const RestaurantOrder([]), this.preferences = const OrderPreferences(), this.history = const []});
  final String? chainId;
  final RestaurantOrder order;
  final OrderPreferences preferences;
  final List<Json> history;

  EatOutDraft copyWith({String? Function()? chainId, RestaurantOrder? order, OrderPreferences? preferences, List<Json>? history}) => EatOutDraft(
      chainId: chainId == null ? this.chainId : chainId(), order: order ?? this.order, preferences: preferences ?? this.preferences, history: history ?? this.history);

  Json toJson() => {'chainId': chainId, 'order': order.toJson(), 'preferences': preferences.toJson(), 'history': history};
  static EatOutDraft fromJson(Json j) => EatOutDraft(
        chainId: j['chainId'] as String?, order: RestaurantOrder.fromJson(j['order']), preferences: OrderPreferences.fromJson(j['preferences']),
        history: [for (final h in j['history'] as List? ?? const []) if (h is Map && h['role'] is String && h['text'] is String) Map<String, dynamic>.from(h)],
      );
}

class EatOutStore {
  EatOutStore(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;
  Future<void> _saving = Future.value();

  Future<EatOutDraft> load() async {
    try {
      final r = await _sync.get(_owner, Kinds.eatOut, 'draft');
      return r == null ? const EatOutDraft() : EatOutDraft.fromJson(jsonDecode(r.body) as Json);
    } on Object {
      return const EatOutDraft(); // an unreadable draft starts again; nothing else depends on it
    }
  }

  /// Writes in order, one after another; a failed write loses nothing on screen.
  void keep(EatOutDraft d) => _saving = _saving.then((_) => _sync.putLocal(_owner, LocalWrite(Kinds.eatOut, 'draft', d.toJson()))).catchError((Object _) {});
}

final eatOutStoreProvider = Provider((ref) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) throw StateError('No signed-in owner');
  return EatOutStore(ref.watch(syncProvider), owner);
});

// ---------------------------------------------------------------------------- asking in words

/// The server's reading of one request: preferences that name only real items of the chain, already checked
/// (docs/EATING_OUT.md › AI boundary). It carries no nutrition; suggestions are worked out here from the catalog.
class Interpretation {
  const Interpretation({required this.kind, this.mode, this.chainId, required this.preferences, this.clarification, this.unknownItems = const [], this.problem, this.dropped = const []});
  /// constraints | clarify | unsupported
  final String kind;
  final String? mode, chainId, clarification, problem;
  final OrderPreferences preferences;
  final List<String> unknownItems, dropped;

  /// The answer to [request], read against [chain]: IDs it does not know are left out (the server checks them too).
  static Interpretation? read(Json body, Json request, RestaurantChain chain) {
    if (body['requestId'] != request['requestId'] || body['intent'] is! Map) return null;
    final i = body['intent'] as Map;
    final kind = i['kind'];
    if (kind is! String || !const {'constraints', 'clarify', 'unsupported'}.contains(kind)) return null;
    int? n(String k) => i[k] is int ? i[k] as int : null;
    Set<String> ids(Object? l) => {for (final v in l as List? ?? const []) if (v is String && chain.item(v) != null) v};
    Set<String> strings(Object? l) => {for (final v in l as List? ?? const []) if (v is String) v};
    return Interpretation(
      kind: kind, mode: i['mode'] as String?, chainId: i['chainId'] as String?,
      preferences: OrderPreferences(
        maxCalories: n('maxCalories'), minCalories: n('minCalories'), minProtein: n('minProtein'),
        keep: {
          for (final k in i['keep'] as List? ?? const [])
            if (k is Map && k['itemId'] is String && chain.item(k['itemId'] as String) != null) k['itemId'] as String: (k['quantity'] as int?) ?? 1,
        },
        exclude: ids(i['exclude']), prefer: strings(i['prefer']), avoid: strings(i['avoid']),
        priority: OrderPriority.values.where((p) => p.name == i['priority']).firstOrNull,
      ),
      clarification: i['clarification'] as String?, unknownItems: [for (final u in i['unknownItems'] as List? ?? const []) if (u is String) u],
      problem: i['problem'] as String?, dropped: [for (final d in i['dropped'] as List? ?? const []) if (d is String) d],
    );
  }
}

/// The server holds another catalog version than this phone: the menu is refreshed before anything is applied.
class CatalogMismatch implements Exception {
  const CatalogMismatch();
}

/// The body of one explicit Send: the request, the chain and catalog version, the order and preferences on screen
/// with the revision they had, the reply language and at most six earlier exchanges. Nothing else about the person:
/// no email, journal, body measurements or location.
Json interpretRequest({required String requestId, required RestaurantCatalog catalog, required String chainId, required String question, required EatOutDraft draft,
        required String revision, required String languageCode}) =>
    {
      'requestId': requestId, 'catalogVersion': catalog.version, 'chainId': chainId, 'question': question.length > 600 ? question.substring(0, 600) : question,
      'language': askLanguage(Locale(languageCode)),
      'history': [for (final h in draft.history.skip(draft.history.length > 6 ? draft.history.length - 6 : 0)) {'role': h['role'], 'text': h['text']}],
      'order': draft.order.toJson(), 'orderRevision': revision,
      'preferences': {
        'maxCalories': draft.preferences.maxCalories, 'minCalories': draft.preferences.minCalories, 'minProtein': draft.preferences.minProtein,
        'keep': draft.preferences.keep.keys.toList(), 'exclude': draft.preferences.exclude.toList(),
      },
    };

/// `POST /restaurants/interpret` through the signed-in owner's [Api]: a read, never a queued command.
class EatingOutClient {
  EatingOutClient(this._api);
  final Api _api;
  static const timeout = Duration(seconds: 25);

  Future<Json> interpret(Json request) async {
    final ApiResponse r;
    try {
      r = await _api.send('POST', '/restaurants/interpret', data: request).timeout(timeout);
    } on TimeoutException {
      throw const AskFailure(AskProblem.unavailable);
    } on TransportFailure catch (e) {
      throw AskFailure(e.message.toLowerCase().contains('timeout') ? AskProblem.unavailable : AskProblem.unreached);
    }
    final d = r.data;
    if (r.status == 409) throw const CatalogMismatch();
    if (r.status == 429) throw const AskFailure(AskProblem.limit);
    if (r.status == 400) throw const AskFailure(AskProblem.invalid);
    if (r.status == 503 && d is Map && d['code'] == 'COACH_BUSY') throw const AskFailure(AskProblem.busy);
    if (!r.ok || d is! Map) throw const AskFailure(AskProblem.unavailable);
    return Map<String, dynamic>.from(d);
  }
}

final eatingOutClientProvider = Provider((ref) => EatingOutClient(ref.watch(apiProvider)));
