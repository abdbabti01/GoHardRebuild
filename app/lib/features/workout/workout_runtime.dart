import 'dart:math';

import '../../data/models.dart';

/// Durable timing and unsaved input for one open workout. It is stored on the phone only.
///
/// Time is never counted by a ticker: elapsed and rest are computed from persisted UTC anchors, so
/// backgrounding, process death and restart all recover the same values. A display timer only redraws.
/// Wall-clock jumps backwards are clamped to zero; nothing here ever logs a set or changes the exercise.
extension type WorkoutRuntime(Json j) {
  static WorkoutRuntime started(DateTime nowUtc, {String? selectedExerciseId}) => WorkoutRuntime({
        'accumulatedActiveSeconds': 0,
        'runningAnchorUtc': nowUtc.toIso8601String(),
        'isPaused': false,
        'isParked': false,
        'selectedExerciseId': selectedExerciseId,
        'drafts': <String, dynamic>{},
      });

  int get _accumulated => j['accumulatedActiveSeconds'] as int? ?? 0;
  DateTime? get _anchor => j['runningAnchorUtc'] == null ? null : DateTime.parse(j['runningAnchorUtc'] as String);
  DateTime? get restDeadlineUtc => j['restDeadlineUtc'] == null ? null : DateTime.parse(j['restDeadlineUtc'] as String);
  bool get isPaused => j['isPaused'] as bool? ?? false;

  /// Saved for later: timing frozen and no longer the foreground workout.
  bool get isParked => j['isParked'] as bool? ?? false;
  String? get selectedExerciseId => j['selectedExerciseId'] as String?;
  String? get restExerciseId => j['restExerciseId'] as String?;
  int get restTotalSeconds => j['restTotalSeconds'] as int? ?? 0;
  bool get hasRest => restDeadlineUtc != null || j['restRemainingSeconds'] != null;

  /// Active seconds, excluding every paused or parked interval.
  int elapsedSeconds(DateTime nowUtc) => _accumulated + (_anchor == null ? 0 : max(0, nowUtc.difference(_anchor!).inSeconds));

  /// Seconds of rest left; 0 = the rest has ended (it stays ended, it never restarts); null = no rest.
  int? restRemainingSeconds(DateTime nowUtc) {
    if (j['restRemainingSeconds'] != null) return j['restRemainingSeconds'] as int; // frozen while paused
    final deadline = restDeadlineUtc;
    if (deadline == null) return null;
    return max(0, (deadline.difference(nowUtc).inMilliseconds / 1000).ceil());
  }

  Json _copy() => copyJson(j);

  WorkoutRuntime paused(DateTime nowUtc, {bool park = false}) {
    final next = _copy();
    if (!isPaused) {
      next['accumulatedActiveSeconds'] = elapsedSeconds(nowUtc);
      next['runningAnchorUtc'] = null;
      next['isPaused'] = true;
      final rest = restRemainingSeconds(nowUtc);
      if (restDeadlineUtc != null) {
        next['restDeadlineUtc'] = null;
        next['restRemainingSeconds'] = rest;
      }
    }
    if (park) next['isParked'] = true;
    return WorkoutRuntime(next);
  }

  WorkoutRuntime resumed(DateTime nowUtc) {
    final next = _copy()
      ..['isParked'] = false
      ..['isPaused'] = false;
    if (isPaused || _anchor == null) next['runningAnchorUtc'] = nowUtc.toIso8601String();
    final frozen = j['restRemainingSeconds'] as int?;
    if (frozen != null) {
      next['restRemainingSeconds'] = null;
      // An already-ended rest stays ended; a frozen one continues with what was left.
      next['restDeadlineUtc'] = nowUtc.add(Duration(seconds: frozen)).toIso8601String();
    }
    return WorkoutRuntime(next);
  }

  /// A newly completed set replaces any earlier rest with its own prescribed rest.
  WorkoutRuntime withRest(DateTime nowUtc, int seconds, String exerciseId) => WorkoutRuntime(_copy()
    ..['restDeadlineUtc'] = nowUtc.add(Duration(seconds: seconds)).toIso8601String()
    ..['restRemainingSeconds'] = null
    ..['restTotalSeconds'] = seconds
    ..['restExerciseId'] = exerciseId);

  WorkoutRuntime restExtended(DateTime nowUtc, int seconds) {
    final remaining = restRemainingSeconds(nowUtc) ?? 0;
    return WorkoutRuntime(_copy()
      ..['restTotalSeconds'] = restTotalSeconds + seconds
      ..['restRemainingSeconds'] = isPaused ? remaining + seconds : null
      ..['restDeadlineUtc'] = isPaused ? null : nowUtc.add(Duration(seconds: remaining + seconds)).toIso8601String());
  }

  WorkoutRuntime withoutRest() => WorkoutRuntime(_copy()
    ..['restDeadlineUtc'] = null
    ..['restRemainingSeconds'] = null
    ..['restExerciseId'] = null);

  /// Changing exercise is always the user's explicit choice.
  WorkoutRuntime selecting(String exerciseId) => WorkoutRuntime(_copy()..['selectedExerciseId'] = exerciseId);

  /// Raw, unsubmitted entry text for an exercise, with the unit it was typed in. It is not a set.
  EntryDraft draftFor(String exerciseId) => EntryDraft((j['drafts'] as Json? ?? const {})[exerciseId] as Json? ?? const {});

  WorkoutRuntime withDraft(String exerciseId, EntryDraft draft) {
    final next = _copy();
    (next['drafts'] as Json)[exerciseId] = draft.j;
    return WorkoutRuntime(next);
  }
}

extension type EntryDraft(Json j) {
  static EntryDraft of({String load = '', String reps = '', String duration = '', required String unit}) =>
      EntryDraft({'rawLoad': load, 'rawReps': reps, 'rawDuration': duration, 'unit': unit});
  String get rawLoad => j['rawLoad'] as String? ?? '';
  String get rawReps => j['rawReps'] as String? ?? '';
  String get rawDuration => j['rawDuration'] as String? ?? '';

  /// The unit the load was typed in. It stays pinned while the entry is dirty, even if the preference changes.
  String? get unit => j['unit'] as String?;
  bool get isEmpty => rawLoad.isEmpty && rawReps.isEmpty && rawDuration.isEmpty;
}
