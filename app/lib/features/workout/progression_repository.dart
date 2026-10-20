import 'dart:convert';

import '../../data/db.dart' show Cmd;
import '../../data/models.dart';
import '../../data/sync.dart';

/// Equipment increments (synced through the outbox) and this phone's next-target notes (docs/PROGRESSION.md).
class ProgressionRepository {
  ProgressionRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  static const capability = 'exercises.load-increment';
  static const maxIncrementKg = 50.0;

  /// An increment command waits until the account's server declares increments (unknown waits too).
  static bool serverTakes(Cmd cmd, Set<String>? capabilities) => !cmd.kind.startsWith('exerciseincrement.') || (capabilities?.contains(capability) ?? false);

  static String noteId(String planId, String workoutId, String occurrenceKey) => '$planId|$workoutId|$occurrenceKey';

  /// The step the person chose for [exerciseKey], in kilograms (null clears it). Converted from the entry unit once,
  /// before calling; kept to the account's precision so a pound step stays exact.
  Future<Receipt> setIncrement(String exerciseKey, double? kg) {
    if (kg != null && (!kg.isFinite || kg <= 0 || kg > maxIncrementKg)) throw ArgumentError.value(kg, 'increment');
    final value = kg == null ? null : (kg * 100000).roundToDouble() / 100000;
    return _sync.submit(_owner, kind: 'exerciseincrement.put', method: 'PUT', path: '/exercise-increments/${Uri.encodeComponent(exerciseKey)}',
        targetKind: Kinds.exerciseIncrement, targetId: exerciseKey,
        writes: [LocalWrite(Kinds.exerciseIncrement, exerciseKey, {'exerciseKey': exerciseKey, 'incrementKg': value})],
        payload: {'expectedRevision': {r'$rev': [Kinds.exerciseIncrement, exerciseKey]}, 'incrementKg': value});
  }

  /// "Keep the version on this phone" after another phone chose this exercise's increment.
  Future<Receipt?> keepLocal(String operationId, ExerciseIncrement local) => _sync.resolveKeepLocal(_owner, operationId,
      kind: 'exerciseincrement.put', method: 'PUT', path: '/exercise-increments/${Uri.encodeComponent(local.exerciseKey)}',
      payload: {'expectedRevision': {r'$rev': [Kinds.exerciseIncrement, local.exerciseKey]}, 'incrementKg': local.incrementKg});

  Future<Json> _note(String id) async {
    final rec = await _sync.get(_owner, Kinds.progression, id);
    return rec == null ? <String, dynamic>{} : copyJson(jsonDecode(rec.body) as Map);
  }

  /// Keep current target: this suggestion, from these facts, is not offered again. Nothing in the plan changes.
  Future<void> dismiss(String id, String fingerprint) async =>
      _sync.putLocal(_owner, LocalWrite(Kinds.progression, id, (await _note(id))..['dismissed'] = fingerprint));

  /// Remembers the target an accepted one replaced, so it can be restored while the plan still holds [accepted].
  Future<void> rememberAccepted(String id, {required Json previous, required Json accepted}) async =>
      _sync.putLocal(_owner, LocalWrite(Kinds.progression, id, (await _note(id))..['previous'] = previous..['accepted'] = accepted));

  Future<void> forgetAccepted(String id) async => _sync.putLocal(_owner, LocalWrite(Kinds.progression, id, (await _note(id))..remove('previous')..remove('accepted')));
}
