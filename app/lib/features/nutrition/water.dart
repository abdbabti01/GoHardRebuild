import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../app/providers.dart' show ownerProvider, profileProvider, profileRepositoryProvider;
import '../../core/compatibility.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/units.dart' show parseNonNegative, parsePositiveInt;
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/sync.dart';

/// Water the person logged themselves (docs/FOOD_DATA.md › Water). Stored in millilitres, the one canonical volume,
/// with at most three decimals; fluid ounces exist only at the input and display boundary. Nothing is counted from
/// foods or other drinks.
enum VolumeUnit {
  ml,
  flOz;

  /// "Millilitres", "US fluid ounces", in the app's language. [name] stays the stored identifier.
  String get label => this == ml ? currentL10n.waterUnitMlName : currentL10n.waterUnitFlOzName;

  /// One US fluid ounce in millilitres (exact by definition). A volume, not the ounce of weight.
  static const mlPerFlOz = 29.5735295625;

  /// The three quick additions, in this unit: round numbers people pour.
  List<double> get quick => this == ml ? const [100, 250, 500] : const [4, 8, 16];

  /// One ordinary drink, logged with one tap: 250 mL or 8 fl oz (236.588 mL stored, what 8 fl oz is). Shown and stored
  /// as the same amount, converted once by [toMl]. A convenience, not a recommendation.
  double get everyday => quick[1];

  /// Millilitres for an amount typed or tapped in this unit, kept to three decimals.
  double toMl(double amount) => roundMl(this == ml ? amount : amount * mlPerFlOz);

  /// A typed amount in this unit as it is read back: whole millilitres, or ounces to one decimal.
  String amount(double v) => this == ml ? formatGrouped(v.round()) : localDecimal(_trim(v.toStringAsFixed(1)));

  /// What was typed in this unit: "1,500", "1 500" and "١٥٠٠" mL are 1500; ounces may have a decimal mark ("8,5").
  /// Null for blank, ambiguous or malformed input ([parseNonNegative]).
  double? parseAmount(String raw) =>
      (this == ml ? parsePositiveInt(raw, grouping: true)?.toDouble() : null) ?? parseNonNegative(raw, grouping: true);

  /// "250 mL", "2,000 mL", "8 fl oz": always the chosen unit, never switching to litres. The total is converted once
  /// from the stored millilitres, never summed from rounded figures.
  String format(double ml) => withUnit(number(ml), short);

  /// The figure alone, in this unit: "1,250" or "42.3".
  String number(double ml) => this == flOz ? localDecimal(_trim((ml / mlPerFlOz).toStringAsFixed(1))) : formatGrouped(ml.round());

  /// "750 / 2,000 mL": what was logged against the goal, the real amount also above it.
  String progress(double ml, double goalMl) => '${number(ml)} / ${format(goalMl)}';

  /// The general starting point offered when no water goal is set (never saved without the person choosing it).
  static const suggestedGoalMl = 2000;

  /// "mL" or "fl oz", for a field's suffix.
  String get short => this == ml ? currentL10n.waterUnitMl : currentL10n.waterUnitFlOz;

  static VolumeUnit parse(String? name) => values.asNameMap()[name] ?? ml;
}

double roundMl(double ml) => (ml * 1000).round() / 1000;
String _trim(String s) => s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;

/// One logged amount of water on a day.
extension type WaterEntry(Json j) {
  String get id => j['id'] as String;
  String get dayKey => j['dayKey'] as String;
  double get volumeMl => (j['volumeMl'] as num).toDouble();
  bool get isDeleted => j['isDeleted'] as bool? ?? false;
  String? get createdAtUtc => j['createdAtUtc'] as String?;
}

/// The day's water: the exact sum of what was logged, in millilitres. Rounded only when shown.
double waterTotal(Iterable<WaterEntry> entries) => roundMl(entries.where((e) => !e.isDeleted).fold(0.0, (s, e) => s + e.volumeMl));

/// Why an amount of water cannot be logged; the screen says it in the app's language.
enum WaterProblem { notAboveZero, overMax }

class InvalidWater implements Exception {
  const InvalidWater(this.problem);
  final WaterProblem problem;
  @override
  String toString() => 'InvalidWater(${problem.name})';
}

/// The owner's water log, saved on this phone first and sent through the same outbox as food: a retry reuses its
/// operation, so an entry is never recorded twice.
class WaterRepository {
  WaterRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  /// The most one entry may hold (the account refuses more).
  static const maxMl = 5000.0;

  static double validate(double ml) {
    final v = roundMl(ml);
    if (!ml.isFinite || v <= 0) throw const InvalidWater(WaterProblem.notAboveZero);
    if (v > maxMl) throw const InvalidWater(WaterProblem.overMax);
    return v;
  }

  /// Logs [ml] on [dayKey], the day pinned when the sheet opened.
  Future<Receipt> add(String dayKey, double ml, {String? id}) {
    final volume = validate(ml);
    final entryId = id ?? SyncEngine.newId();
    final fields = {'dayKey': dayKey, 'volumeMl': volume};
    return _sync.submit(_owner, kind: 'water.create', path: '/water-entries', targetKind: Kinds.water, targetId: entryId,
        writes: [LocalWrite(Kinds.water, entryId, {'id': entryId, 'isDeleted': false, ...fields}, dayKey: dayKey)], payload: {'entryId': entryId, ...fields});
  }

  /// Corrects the amount of one entry. Its day stays the day it was logged on.
  Future<Receipt> update(WaterEntry e, double ml) {
    final volume = validate(ml);
    final fields = {'dayKey': e.dayKey, 'volumeMl': volume};
    return _sync.submit(_owner, kind: 'water.update', method: 'PUT', path: '/water-entries/${e.id}', targetKind: Kinds.water, targetId: e.id,
        writes: [LocalWrite(Kinds.water, e.id, {...e.j, ...fields}, dayKey: e.dayKey)],
        payload: {'expectedRevision': {r'$rev': [Kinds.water, e.id]}, ...fields});
  }

  /// Removes exactly this entry; the day's others stay.
  Future<Receipt> remove(WaterEntry e) => _sync.submit(_owner, kind: 'water.delete', path: '/water-entries/${e.id}/delete', targetKind: Kinds.water, targetId: e.id,
      writes: [LocalWrite(Kinds.water, e.id, copyJson(e.j)..['isDeleted'] = true, dayKey: e.dayKey)],
      payload: {'expectedRevision': {r'$rev': [Kinds.water, e.id]}});
}

/// What one account chose to see in its nutrition: water is off until turned on; carbs and fat are shown, as before.
/// Hiding is presentation only: no entry, goal or logged value changes.
@immutable
class NutritionDisplay {
  const NutritionDisplay({this.water = false, this.carbs = true, this.fat = true});
  final bool water, carbs, fat;

  NutritionDisplay copy({bool? water, bool? carbs, bool? fat}) => NutritionDisplay(water: water ?? this.water, carbs: carbs ?? this.carbs, fat: fat ?? this.fat);
  Json toJson() => {'water': water, 'carbs': carbs, 'fat': fat};
  static NutritionDisplay fromJson(Json j) => NutritionDisplay(water: j['water'] == true, carbs: j['carbs'] != false, fat: j['fat'] != false);

  @override
  bool operator ==(Object other) => other is NutritionDisplay && other.water == water && other.carbs == carbs && other.fat == fat;
  @override
  int get hashCode => Object.hash(water, carbs, fat);
  @override
  String toString() => 'NutritionDisplay(water: $water, carbs: $carbs, fat: $fat)';
}

/// Tracking preferences on this phone: the volume unit (a display unit, like °C/°F) and, per account, the explicit
/// choice of what is shown made here (an account that keeps its choice overrides it: [rawNutritionDisplayProvider]).
/// Kept in the same platform store as the appearance and the coach, read before the first frame.
@immutable
class TrackingPrefs {
  const TrackingPrefs({this.unit = VolumeUnit.ml, this.owners = const {}});
  final VolumeUnit unit;
  final Map<String, NutritionDisplay> owners;

  NutritionDisplay of(String? owner) => owners[owner] ?? const NutritionDisplay();

  @override
  bool operator ==(Object other) => other is TrackingPrefs && other.unit == unit && mapEquals(other.owners, owners);
  @override
  int get hashCode => Object.hash(unit, Object.hashAllUnordered(owners.entries.map((e) => Object.hash(e.key, e.value))));
}

class TrackingPrefsStore {
  TrackingPrefsStore(this._store);
  static const _key = 'gohard.rebuild.tracking';
  final SecretStore _store;

  TrackingPrefs value = const TrackingPrefs();

  Future<void> restore() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Json;
      value = TrackingPrefs(
        unit: VolumeUnit.parse(j['unit'] as String?),
        owners: {for (final e in ((j['owners'] as Map?) ?? const {}).entries) if (e.value is Map) e.key.toString(): NutritionDisplay.fromJson((e.value as Map).cast<String, dynamic>())},
      );
    } on Object {
      // An unreadable preference is not worth failing startup for; the defaults apply.
    }
  }

  Future<void> save() => _store.write(_key, jsonEncode({'unit': value.unit.name, 'owners': {for (final e in value.owners.entries) e.key: e.value.toJson()}}));
}

/// Overridden at startup with the restored store. Left alone (tests), it is an empty in-memory one.
final trackingPrefsStoreProvider = Provider<TrackingPrefsStore>((_) => TrackingPrefsStore(MemorySecretStore()));

class TrackingPrefsController extends Notifier<TrackingPrefs> {
  @override
  TrackingPrefs build() => ref.watch(trackingPrefsStoreProvider).value;

  void setUnit(VolumeUnit unit) => _apply(TrackingPrefs(unit: unit, owners: state.owners));

  /// Changes what [owner] sees. Nothing logged or set is touched.
  void setDisplay(String owner, NutritionDisplay display) => _apply(TrackingPrefs(unit: state.unit, owners: {...state.owners, owner: display}));

  void _apply(TrackingPrefs next) {
    state = next;
    ref.read(trackingPrefsStoreProvider).value = next;
    ref.read(trackingPrefsStoreProvider).save().ignore(); // already applied; a failed write only means it is chosen again
  }
}

final trackingPrefsProvider = NotifierProvider<TrackingPrefsController, TrackingPrefs>(TrackingPrefsController.new);

/// Whether the account's server keeps water (capability `water.entries`). Unknown counts as yes, as elsewhere.
final waterSupportedProvider = Provider<bool>((ref) => ref.watch(compatibilityProvider).supports('water.entries'));

/// Whether the account keeps the display choices (capability `profile.tracking-display`). Unknown counts as no here:
/// the choice is then only kept on this phone, and no server is sent fields it was never said to understand.
final displaySyncProvider = Provider<bool>((ref) => ref.watch(compatibilityProvider).capabilities?.contains('profile.tracking-display') ?? false);

/// What the signed-in account chose, field by field: the account's choice when it has one (the profile record, which
/// also holds an edit made offline until it is sent), else the choice made on this phone, else the defaults. A fresh
/// phone has no choice of its own, so it shows the account's and never sends its defaults.
final rawNutritionDisplayProvider = Provider<NutritionDisplay>((ref) {
  final local = ref.watch(trackingPrefsProvider).owners[ref.watch(ownerProvider)];
  final p = ref.watch(profileProvider).value;
  const none = NutritionDisplay();
  return NutritionDisplay(water: p?.showWater ?? local?.water ?? none.water, carbs: p?.showCarbs ?? local?.carbs ?? none.carbs, fat: p?.showFat ?? local?.fat ?? none.fat);
});

/// What the signed-in account sees in its nutrition. Water is shown only where the server can keep it, so nothing is
/// logged that could never sync.
final nutritionDisplayProvider = Provider<NutritionDisplay>((ref) {
  final d = ref.watch(rawNutritionDisplayProvider);
  return ref.watch(waterSupportedProvider) ? d : d.copy(water: false);
});

/// Changes what the signed-in account sees: at once on this phone (kept here too, for an account whose server does
/// not keep it), and on the account through the outbox where it can, so the account's other phones follow.
/// [read] is a `ref.read` (a widget's or a container's).
Future<void> setNutritionDisplay(T Function<T>(ProviderListenable<T>) read, NutritionDisplay next) async {
  final owner = read(ownerProvider);
  if (owner == null) return;
  read(trackingPrefsProvider.notifier).setDisplay(owner, next);
  final profile = read(profileProvider).value;
  if (profile != null && read(displaySyncProvider)) await read(profileRepositoryProvider).setDisplay(profile, water: next.water, carbs: next.carbs, fat: next.fat);
}

/// A choice made on this phone before the account could keep it is sent once, when the account has none. A choice
/// already on the account is never replaced this way, and a phone without a choice of its own sends nothing.
/// [sent] holds the owners already handled, so a profile emitted again before the edit lands sends nothing twice.
void uploadLocalDisplayChoice(Ref ref, Profile p, Set<String> sent) {
  final owner = ref.read(ownerProvider);
  final local = ref.read(trackingPrefsProvider).owners[owner];
  if (owner == null || local == null || !ref.read(displaySyncProvider)) return;
  if (p.showWater != null || p.showCarbs != null || p.showFat != null || !sent.add(owner)) return;
  ref.read(profileRepositoryProvider).setDisplay(p, water: local.water, carbs: local.carbs, fat: local.fat).ignore();
}

/// Kept alive by the shell while someone is signed in: watches the account's profile for [uploadLocalDisplayChoice].
final displayMigrationProvider = Provider<void>((ref) {
  final sent = <String>{};
  ref.listen(profileProvider, (_, next) {
    if (next.value case final p?) uploadLocalDisplayChoice(ref, p, sent);
  }, fireImmediately: true);
  ref.listen(displaySyncProvider, (_, on) {
    final p = ref.read(profileProvider).value;
    if (on && p != null) uploadLocalDisplayChoice(ref, p, sent);
  });
});
final volumeUnitProvider = Provider<VolumeUnit>((ref) => ref.watch(trackingPrefsProvider.select((p) => p.unit)));
