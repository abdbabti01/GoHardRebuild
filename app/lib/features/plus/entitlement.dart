import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/sync.dart';

/// GoHard Plus preview (docs/PLUS_PREVIEW.md): what this account may use, as its server last said. The server
/// decides and enforces; the app uses this only to explain, never as authorization.
class Entitlement {
  Entitlement(this.j, {required this.receivedAtUtc});

  /// A server from before entitlements: it limits nothing, so the app does not either.
  static final legacy = Entitlement(const {'tier': 'legacy', 'features': [progression, trendExplorer]}, receivedAtUtc: DateTime.utc(2000));

  static const capability = 'account.entitlement', progression = 'progression.suggestions', trendExplorer = 'trends.explorer';

  /// The smallest Free limits any account has: creating below them never waits for an answer.
  static const minimumPlans = 3, minimumMeals = 10;

  final Json j;
  final DateTime receivedAtUtc;

  bool get isLegacy => j['tier'] == 'legacy';
  bool get isPlus => j['tier'] == 'plus';
  bool get overrideActive => j['source'] == 'preview_override';
  bool get canManagePreview => j['canManagePreview'] == true;
  int? get savedPlans => (j['limits'] as Map?)?['savedPlans'] as int?;
  int? get savedMeals => (j['limits'] as Map?)?['savedMeals'] as int?;
  bool has(String feature) => (j['features'] as List? ?? const []).contains(feature);
  AiAllowance? get allowance => j['allowance'] is Map ? AiAllowance(Map<String, dynamic>.from(j['allowance'] as Map)) : null;

  /// Usable from when this phone received it for the server's bound. A clock set before the receipt, or past the
  /// bound, makes it unknown: changing the phone's time can shorten the cache, never extend it.
  bool validAt(DateTime nowUtc) =>
      isLegacy || (!nowUtc.isBefore(receivedAtUtc) && nowUtc.difference(receivedAtUtc) < Duration(seconds: j['validForSeconds'] as int? ?? 0));
}

/// This month's provider-backed AI requests, counted by the server.
class AiAllowance {
  const AiAllowance(this.j);
  final Json j;
  int get used => j['used'] as int? ?? 0;
  int get limit => j['limit'] as int? ?? 0;
  int get remaining => j['remaining'] as int? ?? 0;
  /// 00:00 UTC on the 1st of next month.
  DateTime? get resetsAtUtc => DateTime.tryParse(j['resetsAtUtc'] as String? ?? '')?.toUtc();
}

/// Creating one more: allowed, over this account's limit, or not known yet (no answer the app may use).
enum CreateGate { ok, limit, unknown }

CreateGate createGate(Entitlement? e, {required int existing, required int? Function(Entitlement) limitOf, required int minimum}) {
  if (e == null) return existing < minimum ? CreateGate.ok : CreateGate.unknown;
  final limit = limitOf(e);
  return limit == null || existing < limit ? CreateGate.ok : CreateGate.limit;
}

/// Saved plans count as the server counts them: every plan that is not archived.
CreateGate planGate(Entitlement? e, Iterable<Plan> plans) =>
    createGate(e, existing: plans.where((p) => !p.isArchived).length, limitOf: (e) => e.savedPlans, minimum: Entitlement.minimumPlans);

/// Saved meals and recipes together, not deleted.
CreateGate mealGate(Entitlement? e, int existing) => createGate(e, existing: existing, limitOf: (e) => e.savedMeals, minimum: Entitlement.minimumMeals);

/// The account's entitlement as the app may use it now: null while unknown (loading, never answered, expired).
final plusProvider = Provider<Entitlement?>((ref) {
  final e = ref.watch(entitlementProvider);
  return e != null && e.validAt(ref.watch(clockProvider).utcNow()) ? e : null;
});

/// Whether a Plus feature is open to this account now. Unknown is "not yet", never a paywall.
bool plusFeature(Entitlement? e, String feature) => e?.has(feature) ?? false;

/// The last answer for the signed-in owner, kept on this phone per account (record kind `entitlement`, id = owner).
final entitlementProvider = NotifierProvider<EntitlementController, Entitlement?>(EntitlementController.new);

class EntitlementController extends Notifier<Entitlement?> {
  String? _owner;
  int _turn = 0;
  Future<Entitlement?>? _fetching;

  @override
  Entitlement? build() {
    _owner = ref.watch(ownerProvider);
    final capabilities = ref.watch(compatibilityProvider).capabilities;
    final turn = ++_turn;
    if (_owner == null) return null;
    if (capabilities != null && !capabilities.contains(Entitlement.capability)) return Entitlement.legacy;
    unawaited(_restore(_owner!, turn).then((_) => refresh()));
    return null;
  }

  Future<void> _restore(String owner, int turn) async {
    try {
      final rec = await ref.read(syncProvider).get(owner, Kinds.entitlement, owner);
      if (rec == null || !ref.mounted || turn != _turn || state != null) return;
      final j = jsonDecode(rec.body) as Json;
      state = Entitlement(Map<String, dynamic>.from(j['entitlement'] as Map), receivedAtUtc: DateTime.parse(j['receivedAtUtc'] as String));
    } on Object {
      // An unreadable cache is no cache.
    }
  }

  /// Asks the account once at a time. No answer keeps what is known while it is still valid.
  Future<Entitlement?> refresh() => _fetching ??= _refresh().whenComplete(() => _fetching = null);

  Future<Entitlement?> _refresh() async {
    final owner = _owner, turn = _turn, session = ref.read(sessionsProvider).current;
    if (owner == null || session == null || state?.isLegacy == true) return state;
    ApiResponse? r;
    try {
      r = await ref.read(apiProvider).send('GET', '/entitlement').timeout(const Duration(seconds: 8));
    } on Object {
      r = null;
    }
    if (!ref.mounted || turn != _turn || ref.read(sessionsProvider).current?.epoch != session.epoch) return null;
    final now = ref.read(clockProvider).utcNow();
    if (r == null || !r.ok || r.data is! Map) {
      if (state != null && !state!.validAt(now)) state = null;
      return state;
    }
    return _adopt(owner, Map<String, dynamic>.from(r.data as Map), now);
  }

  Future<Entitlement?> _adopt(String owner, Json j, DateTime now) async {
    state = Entitlement(j, receivedAtUtc: now);
    try {
      await ref.read(syncProvider).putLocal(owner, LocalWrite(Kinds.entitlement, owner, {'entitlement': j, 'receivedAtUtc': now.toIso8601String()}));
    } on Object {
      // The answer still holds for this run.
    }
    return state;
  }

  /// The configured owner's preview controls. The server refuses anyone else (404) and the state is left as it was.
  Future<bool> setPreviewTier(bool plus) => _manage('PUT', '/preview/entitlement', {'tier': plus ? 'plus' : 'free'});
  Future<bool> resetAllowance() => _manage('POST', '/preview/allowance/reset', null);

  Future<bool> _manage(String method, String path, Json? body) async {
    final owner = _owner;
    if (owner == null) return false;
    final ApiResponse r;
    try {
      r = await ref.read(apiProvider).send(method, path, data: body).timeout(const Duration(seconds: 10));
    } on Object {
      return false;
    }
    if (!r.ok || r.data is! Map || !ref.mounted || owner != _owner) return false;
    await _adopt(owner, Map<String, dynamic>.from(r.data as Map), ref.read(clockProvider).utcNow());
    return true;
  }
}
