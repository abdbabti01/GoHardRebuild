import 'dart:convert';

import '../../data/db.dart' show Cmd;
import '../../data/models.dart';
import '../../data/sync.dart';
import 'body_metrics.dart';

enum BodyInputProblem { nothingEntered, outOfRange, noteTooLong, measurementsNeedServer, needsOneMeasurement, correctionNeedsServer }

/// A check-in the account would refuse, as a code the form says in words. Nothing was saved and the form keeps its input.
class BodyInputError implements Exception {
  const BodyInputError(this.problem, [this.field]);
  final BodyInputProblem problem;

  /// The field out of range.
  final BodyField? field;
}

/// Body check-ins through the outbox (docs/BODY_PROGRESS.md › Sync): saved on the phone first, one stable ID and
/// command per save, corrected in place with a revision-checked update, removed with the existing delete.
class BodyRepository {
  BodyRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  static const capability = 'body-metrics.measurements';
  static const _newKeys = ['waistCm', 'chestCm', 'leftUpperArmCm', 'rightUpperArmCm', 'leftThighCm', 'rightThighCm', 'recordedAtUtc'];

  /// A correction, or a check-in carrying anything an older server would silently drop, waits until the server
  /// declares [capability] (unknown waits too). Weight / body fat / note check-ins and deletes go to any server.
  static bool serverTakes(Cmd cmd, Set<String>? capabilities) {
    final supported = capabilities?.contains(capability) ?? false;
    if (cmd.kind == 'metric.update') return supported;
    if (cmd.kind != 'metric.create') return true;
    final payload = jsonDecode(cmd.payload) as Map;
    return supported || !_newKeys.any(payload.containsKey);
  }

  static void _check(Map<BodyField, double?> values, String? note) {
    if (!values.values.any((v) => v != null)) throw const BodyInputError(BodyInputProblem.nothingEntered);
    for (final MapEntry(key: f, value: v) in values.entries) {
      if (v != null && !f.accepts(v)) throw BodyInputError(BodyInputProblem.outOfRange, f);
    }
    if ((note?.length ?? 0) > maxNoteLength) throw const BodyInputError(BodyInputProblem.noteTooLong);
  }

  /// Saves a new check-in under [id] (made once per form, so a repeated tap can never create a second one).
  /// [measurementsServer] false: the server is known not to take circumferences or first-saved times; only weight,
  /// body fat and note are sent, in the shape it knows.
  Future<Receipt> create(String id, String dayKey, Map<BodyField, double?> values, {String? note, required DateTime nowUtc, bool measurementsServer = true}) {
    note = (note?.trim().isEmpty ?? true) ? null : note!.trim();
    _check(values, note);
    if (!measurementsServer && values.entries.any((e) => e.value != null && e.key.needsMeasurementsServer)) {
      throw const BodyInputError(BodyInputProblem.measurementsNeedServer);
    }
    final fields = <String, Object?>{
      'dayKey': dayKey, 'weightKg': values[BodyField.weight], 'bodyFatPercent': values[BodyField.bodyFat], 'note': note,
      for (final MapEntry(key: f, value: v) in values.entries)
        if (v != null && f.needsMeasurementsServer) f.key: v,
      if (measurementsServer) 'recordedAtUtc': nowUtc.toUtc().toIso8601String(),
    };
    return _sync.submit(_owner, kind: 'metric.create', path: '/body-metrics', targetKind: Kinds.metric, targetId: id,
        writes: [LocalWrite(Kinds.metric, id, {'id': id, ...fields, 'revision': 0, 'isDeleted': false}, dayKey: dayKey)],
        payload: {'metricId': id, ...fields});
  }

  /// Corrects [m] in place. [changes] holds only what the person changed: a key with null clears that value, a key
  /// left out keeps it (hidden fields, body fat, notes, the other side). Refused when nothing would stay measured.
  Future<Receipt> update(BodyMetric m, String dayKey, Map<BodyField, double?> changes, {bool noteChanged = false, String? note}) {
    note = (note?.trim().isEmpty ?? true) ? null : note!.trim();
    final next = {for (final f in BodyField.values) f: changes.containsKey(f) ? changes[f] : m.value(f.key)};
    if (!next.values.any((v) => v != null)) throw const BodyInputError(BodyInputProblem.needsOneMeasurement);
    _check(next, noteChanged ? note : m.note);
    final fields = <String, Object?>{
      'dayKey': dayKey,
      for (final MapEntry(key: f, value: v) in changes.entries) f.key: v,
      if (noteChanged) 'note': note,
    };
    return _sync.submit(_owner, kind: 'metric.update', method: 'PUT', path: '/body-metrics/${m.id}', targetKind: Kinds.metric, targetId: m.id,
        writes: [LocalWrite(Kinds.metric, m.id, {...m.j, ...fields}, dayKey: dayKey)],
        payload: {'expectedRevision': {r'$rev': [Kinds.metric, m.id]}, ...fields});
  }

  Future<Receipt> delete(BodyMetric m) => _sync.submit(_owner, kind: 'metric.delete', path: '/body-metrics/${m.id}/delete', targetKind: Kinds.metric, targetId: m.id,
      writes: [LocalWrite(Kinds.metric, m.id, copyJson(m.j)..['isDeleted'] = true, dayKey: m.dayKey)], payload: {'expectedRevision': {r'$rev': [Kinds.metric, m.id]}});

  /// "Keep the version on this phone" after the check-in changed elsewhere: one correction carrying every value of the
  /// local version against the account's revision. Only on a server that takes corrections.
  Future<Receipt?> keepLocal(String operationId, BodyMetric local) => _sync.resolveKeepLocal(_owner, operationId,
      kind: 'metric.update', method: 'PUT', path: '/body-metrics/${local.id}',
      payload: {'expectedRevision': {r'$rev': [Kinds.metric, local.id]}, 'dayKey': local.dayKey, for (final f in BodyField.values) f.key: local.value(f.key), 'note': local.note});
}
