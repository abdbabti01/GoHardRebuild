import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show loadUnitProvider, ownerProvider;
import '../../core/units.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import 'body_metrics.dart';

/// What one account chose for Body progress on this phone: the units and which fields the log form shows. Null =
/// never chosen (the defaults apply). Kept per account on this phone, like the nutrition display choice, and never
/// sent to the account: another phone keeps its own choice, and measurements themselves always sync.
@immutable
class BodyPrefs {
  const BodyPrefs({this.mass, this.length, this.shown, this.note = false});
  final LoadUnit? mass;
  final LengthUnit? length;
  final Set<BodyField>? shown;
  final bool note;

  /// Shown until changed: weight and every circumference, both sides. Body fat and the note are one tap away.
  static const defaultShown = {BodyField.weight, BodyField.waist, BodyField.chest, BodyField.leftUpperArm, BodyField.rightUpperArm, BodyField.leftThigh, BodyField.rightThigh};

  Json toJson() => {'mass': mass?.name, 'length': length?.name, 'shown': shown?.map((f) => f.name).toList(), 'note': note};
  static BodyPrefs fromJson(Json j) => BodyPrefs(
        mass: j['mass'] == null ? null : LoadUnit.parse(j['mass'] as String?),
        length: LengthUnit.values.asNameMap()[j['length']],
        shown: j['shown'] is List ? {for (final n in j['shown'] as List) ?BodyField.values.asNameMap()[n]} : null,
        note: j['note'] == true,
      );

  @override
  bool operator ==(Object other) => other is BodyPrefs && other.mass == mass && other.length == length && setEquals(other.shown, shown) && other.note == note;
  @override
  int get hashCode => Object.hash(mass, length, shown == null ? null : Object.hashAllUnordered(shown!), note);
}

class BodyPrefsStore {
  BodyPrefsStore(this._store);
  static const _key = 'gohard.rebuild.body';
  final SecretStore _store;
  Map<String, BodyPrefs> owners = const {};

  Future<void> restore() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null) return;
      owners = {for (final e in (jsonDecode(raw) as Map).entries) if (e.value is Map) '${e.key}': BodyPrefs.fromJson((e.value as Map).cast<String, dynamic>())};
    } on Object {
      // An unreadable preference is not worth failing startup for; the defaults apply.
    }
  }

  Future<void> save() => _store.write(_key, jsonEncode({for (final e in owners.entries) e.key: e.value.toJson()}));
}

/// Overridden at startup with the restored store. Left alone (tests), it is an empty in-memory one.
final bodyPrefsStoreProvider = Provider<BodyPrefsStore>((_) => BodyPrefsStore(MemorySecretStore()));

class BodyPrefsController extends Notifier<Map<String, BodyPrefs>> {
  @override
  Map<String, BodyPrefs> build() => ref.watch(bodyPrefsStoreProvider).owners;

  void update(String owner, BodyPrefs Function(BodyPrefs current) change) {
    state = {...state, owner: change(state[owner] ?? const BodyPrefs())};
    final store = ref.read(bodyPrefsStoreProvider)..owners = state;
    store.save().ignore(); // already applied; a failed write only means it is chosen again
  }
}

final bodyPrefsControllerProvider = NotifierProvider<BodyPrefsController, Map<String, BodyPrefs>>(BodyPrefsController.new);
final bodyPrefsProvider = Provider<BodyPrefs>((ref) => ref.watch(bodyPrefsControllerProvider)[ref.watch(ownerProvider)] ?? const BodyPrefs());

/// Weight follows the lifting unit until chosen here; length follows weight (lb → in, kg → cm) until chosen.
/// Choosing a body unit never changes the lifting unit.
final bodyUnitsProvider = Provider<BodyUnits>((ref) {
  final p = ref.watch(bodyPrefsProvider);
  final LoadUnit mass = p.mass ?? ref.watch(loadUnitProvider);
  return BodyUnits(mass, p.length ?? (mass == LoadUnit.lb ? LengthUnit.inch : LengthUnit.cm));
});

/// Saves [units] as this account's body units on this phone.
void setBodyUnits(WidgetRef ref, BodyUnits units) {
  final owner = ref.read(ownerProvider);
  if (owner == null) return;
  ref.read(bodyPrefsControllerProvider.notifier).update(owner, (p) => BodyPrefs(mass: units.mass, length: units.length, shown: p.shown, note: p.note));
}
