import 'dart:convert';

import '../../core/clock.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import 'result_rules.dart';
import 'workout_runtime.dart';

/// Entered values that cannot be a performed set. The entry stays on screen; nothing is saved.
class InvalidSet implements Exception {
  const InvalidSet(this.message);
  final String message;
}

/// What a caller should do when asked to bring a workout to the foreground.
sealed class ForegroundDecision {}

class ForegroundReady extends ForegroundDecision {}

/// Another workout is already in the foreground. Resume it, or explicitly save it for later first.
class ForegroundBusy extends ForegroundDecision {
  ForegroundBusy(this.current);
  final Workout current;
}

/// Local-first actual training. Every change is saved on the phone with its command before any network
/// use, with stable IDs, so offline work survives restart and a lost response can never duplicate it.
/// Nothing here ever finishes, completes or deletes a workout on its own.
class WorkoutRepository {
  WorkoutRepository(this._sync, this._owner, this._clock);
  final SyncEngine _sync;
  final String _owner;
  final AppClock _clock;

  String get _now => _clock.utcNow().toIso8601String();
  Json _rev(String kind, String id) => {r'$rev': [kind, id]};

  Future<List<Workout>> _workouts() async => [for (final r in await _sync.list(_owner, Kinds.workout)) Workout(jsonDecode(r.body) as Json)];
  Future<List<WorkoutSet>> sets(String workoutId) async =>
      [for (final r in await _sync.list(_owner, Kinds.set, parentId: workoutId)) WorkoutSet(jsonDecode(r.body) as Json)];

  // ------------------------------------------------------------------ runtime (phone only)

  Future<WorkoutRuntime?> runtime(String workoutId) async {
    final rec = await _sync.get(_owner, Kinds.runtime, workoutId);
    return rec == null ? null : WorkoutRuntime(jsonDecode(rec.body) as Json);
  }

  Future<void> saveRuntime(String workoutId, WorkoutRuntime runtime) => _sync.putLocal(_owner, LocalWrite(Kinds.runtime, workoutId, runtime.j));

  /// The single foreground workout: open and not saved for later.
  Future<Workout?> foreground() async {
    for (final w in (await _workouts()).where((w) => w.isOpen)) {
      final r = await runtime(w.id);
      if (r == null || !r.isParked) return w;
    }
    return null;
  }

  /// One foreground workout at a time. Opening another never completes or discards the first.
  Future<ForegroundDecision> requestForeground(String? workoutId) async {
    final current = await foreground();
    return current == null || current.id == workoutId ? ForegroundReady() : ForegroundBusy(current);
  }

  /// Saved for later: timing and rest are frozen and the workout stays open and recoverable.
  Future<void> park(String workoutId) async {
    final r = await runtime(workoutId) ?? WorkoutRuntime.started(_clock.utcNow());
    await saveRuntime(workoutId, r.paused(_clock.utcNow(), park: true));
  }

  Future<void> bringToForeground(String workoutId) async {
    final r = await runtime(workoutId) ?? WorkoutRuntime.started(_clock.utcNow());
    await saveRuntime(workoutId, r.resumed(_clock.utcNow()));
  }

  // ------------------------------------------------------------------ start

  Json _exercise(int ordinal, {required String name, String? catalogKey, String? occurrenceKey, bool isPrescribed = false, bool isTimed = false,
          int? targetSets, int? repsMin, int? repsMax, int? targetSeconds, int? restSeconds, String? substitutedForKey}) =>
      {
        'id': SyncEngine.newId(), 'ordinal': ordinal, 'name': name, 'catalogKey': catalogKey, 'occurrenceKey': occurrenceKey, 'isPrescribed': isPrescribed,
        'isTimed': isTimed, 'targetSets': targetSets, 'targetRepsMin': repsMin, 'targetRepsMax': repsMax, 'targetDurationSeconds': targetSeconds,
        'restSeconds': restSeconds, 'substitutedForKey': substitutedForKey, 'isDeleted': false,
      };

  Future<Workout> _start({required String kind, required String title, required String dayKey, required List<Json> exercises,
      String? planId, String? occasionId, List<(String, String)> after = const []}) async {
    final id = SyncEngine.newId();
    final startedAt = _now;
    final body = <String, dynamic>{
      'id': id, 'planId': planId, 'occasionId': occasionId, 'kind': kind, 'title': title, 'dayKey': dayKey, 'startedAtUtc': startedAt,
      'finishedAtUtc': null, 'activeDurationSeconds': null, 'outcome': null, 'performedSets': 0, 'performedExercises': 0,
      'qualifiedOccasion': false, 'revision': 0, 'isDeleted': false, 'exercises': exercises,
    };
    // The workout, its command and its running clock are saved together: Start means it has started.
    await _sync.submit(_owner, kind: 'workout.start', path: '/workouts', targetKind: Kinds.workout, targetId: id, after: after,
        writes: [LocalWrite(Kinds.workout, id, body, dayKey: dayKey)],
        locals: [LocalWrite(Kinds.runtime, id, WorkoutRuntime.started(_clock.utcNow(), selectedExerciseId: exercises.firstOrNull?['id'] as String?).j)],
        payload: {
          'workoutId': id, 'kind': kind, 'occasionId': occasionId, 'title': title, 'dayKey': dayKey, 'startedAtUtc': startedAt,
          'exercises': [for (final e in exercises) Map.of(e)..remove('isDeleted')],
        });
    return Workout(body);
  }

  /// Starts the planned occasion, freezing its prescription into the workout. The day key is the local
  /// calendar day the user started on and never changes afterwards.
  Future<Workout> startPlanned(Plan plan, Occasion occasion, String dayKey) => _start(
        kind: 'planned', title: occasion.title, dayKey: dayKey, planId: plan.id, occasionId: occasion.id,
        after: [(Kinds.plan, plan.id), (Kinds.context, _owner)],
        exercises: [
          for (final (i, p) in occasion.prescription.indexed)
            _exercise(i + 1, name: p.name, catalogKey: p.catalogKey, occurrenceKey: p.occurrenceKey, isPrescribed: true, isTimed: p.isTimed,
                targetSets: p.targetSets, repsMin: p.targetRepsMin, repsMax: p.targetRepsMax, targetSeconds: p.targetDurationSeconds, restSeconds: p.restSeconds),
        ],
      );

  /// Manual training needs no plan or goal. It is real work, and it never ticks off a planned occasion.
  Future<Workout> startManual(String title, List<CatalogExercise> exercises, String dayKey) => _start(
        kind: 'manual', title: title.trim().isEmpty ? 'Workout' : title.trim(), dayKey: dayKey,
        exercises: [for (final (i, e) in exercises.indexed) _exercise(i + 1, name: e.name, catalogKey: e.key, isTimed: e.isTimed)],
      );

  // ------------------------------------------------------------------ exercises

  /// Adds a movement to an open workout. A substitution records the planned movement it replaced.
  Future<WorkoutExercise> addExercise(Workout workout, {required String name, String? catalogKey, bool isTimed = false, String? substitutedForKey}) async {
    final all = (workout.j['exercises'] as List).cast<Json>();
    final exercise = _exercise(all.fold<int>(0, (m, e) => (e['ordinal'] as int) > m ? e['ordinal'] as int : m) + 1,
        name: name.trim(), catalogKey: catalogKey, isTimed: isTimed, substitutedForKey: substitutedForKey);
    await _sync.submit(_owner, kind: 'exercise.add', path: '/workouts/${workout.id}/exercises', targetKind: Kinds.workout, targetId: workout.id,
        writes: [LocalWrite(Kinds.workout, workout.id, copyJson(workout.j)..['exercises'] = [...all, exercise])],
        payload: {'exercise': Map.of(exercise)..remove('isDeleted')});
    return WorkoutExercise(exercise);
  }

  /// Removes a movement that has no recorded sets.
  Future<void> removeExercise(Workout workout, String exerciseId) async {
    if ((await sets(workout.id)).any((s) => s.exerciseId == exerciseId && !s.isDeleted)) throw const InvalidSet('Remove its recorded sets first.');
    final body = copyJson(workout.j);
    (body['exercises'] as List).cast<Json>().firstWhere((e) => e['id'] == exerciseId)['isDeleted'] = true;
    await _sync.submit(_owner, kind: 'exercise.remove', path: '/exercises/$exerciseId/remove', targetKind: Kinds.workout, targetId: workout.id,
        writes: [LocalWrite(Kinds.workout, workout.id, body)], payload: {});
  }

  // ------------------------------------------------------------------ sets

  static void _validate(int? reps, double? loadKg, int? durationSeconds) {
    if (loadKg != null && (!loadKg.isFinite || loadKg < 0 || loadKg > 2000)) throw const InvalidSet('Enter a load of zero or more.');
    if ((reps ?? 0) <= 0 && (durationSeconds ?? 0) <= 0) throw const InvalidSet('Enter the reps or time you actually did.');
    if ((reps ?? 0) > 10000 || (durationSeconds ?? 0) > 86400) throw const InvalidSet('That value is out of range.');
  }

  /// Records one performed set. It is durably saved before this returns; only then may the UI show it as saved.
  /// `loadKg` is canonical kilograms: convert from the entry unit exactly once, before calling.
  Future<WorkoutSet> recordSet(Workout workout, String exerciseId, {int? reps, double? loadKg, int? durationSeconds}) async {
    _validate(reps, loadKg, durationSeconds);
    final id = SyncEngine.newId();
    final at = _now;
    final body = <String, dynamic>{
      'id': id, 'exerciseId': exerciseId, 'workoutId': workout.id, 'reps': reps, 'loadKg': loadKg, 'durationSeconds': durationSeconds,
      'performedAtUtc': at, 'revision': 0, 'isDeleted': false,
    };
    await _sync.submit(_owner, kind: 'set.create', path: '/exercises/$exerciseId/sets', targetKind: Kinds.set, targetId: id, after: [(Kinds.workout, workout.id)],
        writes: [LocalWrite(Kinds.set, id, body, parentId: workout.id)],
        payload: {'setId': id, 'reps': reps, 'loadKg': loadKg, 'durationSeconds': durationSeconds, 'performedAtUtc': at});
    return WorkoutSet(body);
  }

  Future<void> updateSet(WorkoutSet set, {int? reps, double? loadKg, int? durationSeconds}) async {
    _validate(reps, loadKg, durationSeconds);
    await _sync.submit(_owner, kind: 'set.update', method: 'PUT', path: '/sets/${set.id}', targetKind: Kinds.set, targetId: set.id,
        writes: [LocalWrite(Kinds.set, set.id, copyJson(set.j)..addAll({'reps': reps, 'loadKg': loadKg, 'durationSeconds': durationSeconds}), parentId: set.workoutId)],
        payload: {'expectedRevision': _rev(Kinds.set, set.id), 'reps': reps, 'loadKg': loadKg, 'durationSeconds': durationSeconds});
  }

  /// Removes one recorded set (also used by Undo). The set becomes a tombstone so retries cannot resurrect it.
  Future<void> deleteSet(WorkoutSet set) => _sync.submit(_owner, kind: 'set.delete', path: '/sets/${set.id}/delete', targetKind: Kinds.set, targetId: set.id,
      writes: [LocalWrite(Kinds.set, set.id, copyJson(set.j)..['isDeleted'] = true, parentId: set.workoutId)],
      payload: {'expectedRevision': _rev(Kinds.set, set.id)});

  /// Conflict choice "keep mine": re-sends this set's current local value against the account's revision,
  /// keeping the account's value as the retained alternative. The same set is resolved; none is added.
  Future<void> keepLocalSet(String conflictOperationId, WorkoutSet local) => _sync.resolveKeepLocal(_owner, conflictOperationId,
      kind: local.isDeleted ? 'set.delete' : 'set.update', method: local.isDeleted ? 'POST' : 'PUT',
      path: local.isDeleted ? '/sets/${local.id}/delete' : '/sets/${local.id}',
      payload: {'expectedRevision': _rev(Kinds.set, local.id), if (!local.isDeleted) ...{'reps': local.reps, 'loadKg': local.loadKg, 'durationSeconds': local.durationSeconds}});

  // ------------------------------------------------------------------ finish

  /// What finishing now would record, computed from actual saved sets only.
  Future<WorkoutResult> preview(Workout workout) async => WorkoutResultRules.evaluate(
        [for (final e in workout.exercises) if (e.isPrescribed) PrescribedExercise(e.id, e.targetSets)],
        [for (final s in await sets(workout.id)) PerformedSet(s.exerciseId, reps: s.reps, loadKg: s.loadKg, durationSeconds: s.durationSeconds, isDeleted: s.isDeleted)],
        isManual: workout.isManual,
      );

  /// One logical finish. The result, the frozen duration and the command are saved in one transaction, and the
  /// command waits for every one of this workout's set commands, so it can never run ahead of the performed sets.
  Future<WorkoutResult> finish(Workout workout) async {
    final result = await preview(workout);
    final now = _clock.utcNow();
    final seconds = (await runtime(workout.id))?.elapsedSeconds(now) ?? now.difference(DateTime.parse(workout.startedAtUtc)).inSeconds.clamp(0, 604800);
    final finishedAt = now.toIso8601String();
    final allSets = await sets(workout.id);
    await _sync.submit(_owner, kind: 'workout.finish', path: '/workouts/${workout.id}/finish', targetKind: Kinds.workout, targetId: workout.id,
        after: [for (final s in allSets) (Kinds.set, s.id)],
        writes: [
          LocalWrite(Kinds.workout, workout.id, copyJson(workout.j)
            ..addAll({
              'finishedAtUtc': finishedAt, 'activeDurationSeconds': seconds, 'outcome': result.outcome, 'performedSets': result.performedSets,
              'performedExercises': result.performedExercises, 'qualifiedOccasion': result.qualifiesOccasion,
            })),
        ],
        payload: {
          'expectedRevision': _rev(Kinds.workout, workout.id), 'acknowledgedSets': {r'$sets': workout.id},
          'activeDurationSeconds': seconds, 'finishedAtUtc': finishedAt,
        });
    await _sync.deleteLocal(_owner, Kinds.runtime, workout.id);
    return result;
  }

  /// Explicit removal by the user. The record becomes a tombstone; it is never cleaned up by age.
  Future<void> delete(Workout workout) async {
    await _sync.submit(_owner, kind: 'workout.delete', path: '/workouts/${workout.id}/delete', targetKind: Kinds.workout, targetId: workout.id,
        writes: [LocalWrite(Kinds.workout, workout.id, copyJson(workout.j)..addAll({'isDeleted': true, 'qualifiedOccasion': false}))],
        payload: {'expectedRevision': _rev(Kinds.workout, workout.id)});
    await _sync.deleteLocal(_owner, Kinds.runtime, workout.id);
  }

  /// A planned start the account refused (for example the occasion was already recorded on another device)
  /// can be kept as separate manual training: every entered set is preserved and no occasion is credited twice.
  Future<void> keepAsManual(String refusedOperationId, Workout workout) async {
    final body = copyJson(workout.j)..addAll({'kind': 'manual', 'planId': null, 'occasionId': null, 'qualifiedOccasion': false});
    for (final e in body['exercises'] as List) {
      (e as Json)['isPrescribed'] = false;
    }
    await _sync.putLocalPending(_owner, LocalWrite(Kinds.workout, workout.id, body));
    await _sync.resolveKeepLocal(_owner, refusedOperationId, kind: 'workout.start', path: '/workouts', payload: {
      'workoutId': workout.id, 'kind': 'manual', 'occasionId': null, 'title': workout.title, 'dayKey': workout.dayKey, 'startedAtUtc': workout.startedAtUtc,
      'exercises': [for (final e in body['exercises'] as List) Map.of(e as Json)..remove('isDeleted')],
    });
    // A finish recorded locally before the refusal is re-sent for the manual workout with its original values.
    if (workout.finishedAtUtc != null) {
      await _sync.submit(_owner, kind: 'workout.finish', path: '/workouts/${workout.id}/finish', targetKind: Kinds.workout, targetId: workout.id,
          after: [for (final s in await sets(workout.id)) (Kinds.set, s.id)],
          payload: {
            'expectedRevision': _rev(Kinds.workout, workout.id), 'acknowledgedSets': {r'$sets': workout.id},
            'activeDurationSeconds': workout.activeDurationSeconds ?? 0, 'finishedAtUtc': workout.finishedAtUtc,
          });
    }
  }
}
