import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/workout/progression.dart';

// Fixture: plan P with workout definitions "A" (Upper A) and "B" (Upper B). Upper A has bench press twice: e1 first,
// e3 as a second, lighter occurrence. Target 80 kg, 3 sets of 6–8. Sessions are labelled by day.
const planId = 'P';
final _defs = {'oA1': 'A', 'oA2': 'A', 'oA3': 'A', 'oA4': 'A', 'oB1': 'B'};
String? defOf(String occasionId) => _defs[occasionId];

Prescription rx({String key = 'e1', String? catalogKey = 'bench-press', double? load = 80, int? sets = 3, int? lo = 6, int? hi = 8, bool timed = false, String name = 'Bench press'}) =>
    Prescription({'occurrenceKey': key, 'catalogKey': catalogKey, 'name': name, 'isTimed': timed, 'targetSets': sets, 'targetRepsMin': lo, 'targetRepsMax': hi, 'targetLoadKg': ?load});

final sets = <WorkoutSet>[];
var _n = 0;

/// A finished planned workout on [day] for [occasion], recording [reps] at [loads] (one load for all sets unless a list).
Workout session(String day, String occasion, List<int?> reps, {Object? load = 80.0, double? frozen = 80, String outcome = 'full', bool deleted = false, int hi = 8,
    String key = 'e1', List<(String, List<int?>)> also = const []}) {
  final id = 'w-$day-$occasion-${_n++}';
  Map<String, dynamic> exercise(String k, List<int?> r) {
    final eid = '$id-$k';
    for (final (i, n) in r.indexed) {
      final l = load is List ? load[i] : load;
      sets.add(WorkoutSet({'id': '$eid-$i', 'exerciseId': eid, 'workoutId': id, 'reps': n, 'loadKg': l, 'performedAtUtc': '${day}T10:0$i:00Z', 'isDeleted': false}));
    }
    return {'id': eid, 'ordinal': k == 'e1' ? 1 : 3, 'name': 'Bench press', 'catalogKey': 'bench-press', 'occurrenceKey': k, 'isPrescribed': true,
      'targetSets': 3, 'targetRepsMin': 6, 'targetRepsMax': hi, 'targetLoadKg': frozen};
  }
  return Workout({
    'id': id, 'planId': planId, 'occasionId': occasion, 'kind': 'planned', 'title': 'Upper A', 'dayKey': day, 'startedAtUtc': '${day}T10:00:00Z',
    'finishedAtUtc': '${day}T11:00:00Z', 'outcome': outcome, 'isDeleted': deleted,
    'exercises': [exercise(key, reps), for (final (k, r) in also) exercise(k, r)],
  });
}

ProgressionResult judge(List<Workout> workouts, {Prescription? exercise, double? increment = 2.5, String definition = 'A', String? equipment = 'Barbell', List<WorkoutSet>? only}) =>
    ProgressionRules.evaluate(planId: planId, definitionId: definition, rx: exercise ?? rx(), equipment: equipment, workouts: workouts,
        sets: only ?? [for (final s in sets) if (!s.isDeleted) s], definitionOf: defOf, incrementKg: increment);

void main() {
  setUp(() {
    sets.clear();
    _n = 0;
  });

  test('two qualifying consecutive sessions propose exactly one increment on the load only', () {
    final r = judge([session('2026-10-13', 'oA1', [8, 8, 8]), session('2026-10-16', 'oA2', [8, 9, 8])]);
    expect(r.decision, ProgressionDecision.increase);
    expect((r.targetKg, r.proposedKg, r.sets, r.repsMin, r.repsMax), (80, 82.5, 3, 6, 8));
    expect([for (final s in r.sessions) s.workout.dayKey], ['2026-10-16', '2026-10-13']);
  });

  test('a more recent session that missed the top is never skipped to reach two older successes', () {
    final r = judge([session('2026-10-06', 'oA1', [8, 8, 8]), session('2026-10-09', 'oA2', [8, 8, 8]), session('2026-10-13', 'oA3', [8, 7, 6])]);
    expect((r.decision, r.reason), (ProgressionDecision.keepCurrent, ProgressionReason.belowTop));
    // The mockup's 10/9/8 at a 6–10 range would not qualify either: the last set is below the top.
    expect(judge([session('2026-10-06', 'oA1', [10, 10, 10], hi: 10), session('2026-10-09', 'oA2', [10, 9, 8], hi: 10)], exercise: rx(hi: 10)).reason, ProgressionReason.belowTop);
  });

  test('different loads, a changed prescription and another occurrence of the same movement are not evidence', () {
    expect(judge([session('2026-10-13', 'oA1', [8, 8, 8]), session('2026-10-16', 'oA2', [8, 8, 8], load: [80.0, 80.0, 77.5])]).reason, ProgressionReason.loadDiffers);
    // The newest session was frozen at 77.5 kg: it says nothing about 80 kg, and nothing older is used instead.
    final changed = judge([session('2026-10-13', 'oA1', [8, 8, 8]), session('2026-10-16', 'oA2', [8, 8, 8], frozen: 77.5, load: 77.5)]);
    expect((changed.decision, changed.reason), (ProgressionDecision.moreSessions, ProgressionReason.targetChanged));
    // Only one session at the current target so far.
    expect(judge([session('2026-10-13', 'oA1', [8, 8, 8], frozen: 77.5, load: 77.5), session('2026-10-16', 'oA2', [8, 8, 8])]).decision, ProgressionDecision.moreSessions);
    // Bench press also sits at e3 in Upper A: e3's strong sets never count for e1, and e1's misses never count for e3.
    final two = [
      session('2026-10-13', 'oA1', [6, 6, 6], also: [('e3', [8, 8, 8])]),
      session('2026-10-16', 'oA2', [6, 6, 6], also: [('e3', [8, 8, 8])]),
    ];
    expect(judge(two).reason, ProgressionReason.belowTop);
    expect(judge(two, exercise: rx(key: 'e3')).decision, ProgressionDecision.increase);
    // Upper B also has bench press: its sessions are another workout and are never mixed in.
    expect(judge([session('2026-10-13', 'oA1', [8, 8, 8]), session('2026-10-15', 'oB1', [8, 8, 8])]).decision, ProgressionDecision.moreSessions);
    expect(judge([session('2026-10-13', 'oA1', [8, 8, 8]), session('2026-10-15', 'oB1', [8, 8, 8])], definition: 'B').decision, ProgressionDecision.moreSessions);
  });

  test('missing, deleted, extra and unknown-load sets, partial and deleted workouts do not qualify', () {
    final a = session('2026-10-13', 'oA1', [8, 8, 8]);
    expect(judge([a, session('2026-10-16', 'oA2', [8, 8])]).reason, ProgressionReason.setsMissing);
    expect(judge([a, session('2026-10-16', 'oA2', [8, 8, 8, 8])]).reason, ProgressionReason.extraSets);
    expect(judge([a, session('2026-10-16', 'oA2', [8, 8, 8], load: [80.0, null, 80.0])]).reason, ProgressionReason.loadUnknown);
    expect(judge([a, session('2026-10-16', 'oA2', [8, 8, 8], outcome: 'partial')]).reason, ProgressionReason.partialWorkout);
    final b = session('2026-10-16', 'oA2', [8, 8, 8]);
    // A set removed from the newest session (a tombstone, not passed in) leaves it incomplete.
    expect(judge([a, b], only: [for (final s in sets) if (s.id != '${b.id}-e1-2') s]).reason, ProgressionReason.setsMissing);
    // A deleted workout is not a session; an open or no-data one neither.
    expect(judge([a, session('2026-10-16', 'oA2', [8, 8, 8], deleted: true)]).decision, ProgressionDecision.moreSessions);
    expect(judge([a, session('2026-10-16', 'oA2', [], outcome: 'no_data')]).decision, ProgressionDecision.moreSessions);
  });

  test('unsupported exercise types and missing targets never get a calculated load', () {
    final two = [session('2026-10-13', 'oA1', [8, 8, 8]), session('2026-10-16', 'oA2', [8, 8, 8])];
    expect(judge(two, exercise: rx(timed: true)).reason, ProgressionReason.timed);
    expect(judge(two, equipment: 'Bodyweight').reason, ProgressionReason.bodyweight);
    expect(judge(two, exercise: rx(name: 'Assisted pull-up')).reason, ProgressionReason.assisted);
    expect(judge(two, exercise: rx(catalogKey: null)).reason, ProgressionReason.noIdentity);
    final none = judge(two, exercise: rx(load: null));
    expect((none.decision, none.proposedKg, none.lastLoadKg), (ProgressionDecision.setBaseline, null, 80)); // last load offered, never chosen
    expect(judge(two, exercise: rx(lo: null, hi: null)).decision, ProgressionDecision.setBaseline);
  });

  test('a missing or unsuitable increment proposes nothing', () {
    final two = [session('2026-10-13', 'oA1', [8, 8, 8]), session('2026-10-16', 'oA2', [8, 8, 8])];
    expect(judge(two, increment: null).decision, ProgressionDecision.configureIncrement);
    expect(judge(two, increment: 4).decision, ProgressionDecision.increase); // exactly 5% of 80
    final big = judge(two, increment: 5);
    expect((big.decision, big.proposedKg), (ProgressionDecision.incrementTooLarge, null));
  });

  test('pounds convert once: a 190 lb target with a 5 lb step proposes 195 lb', () {
    final target = ProgressionRules.round3(loadInputToKg(190, LoadUnit.lb));
    final set = ProgressionRules.round3(loadInputToKg(190, LoadUnit.lb));
    final two = [session('2026-10-13', 'oA1', [8, 8, 8], load: set, frozen: target), session('2026-10-16', 'oA2', [8, 8, 8], load: set, frozen: target)];
    final r = judge(two, exercise: rx(load: target), increment: (loadInputToKg(5, LoadUnit.lb) * 100000).roundToDouble() / 100000);
    expect(r.decision, ProgressionDecision.increase);
    expect(formatLoad(r.proposedKg, LoadUnit.lb), '195 lb');
    expect(formatLoad(r.proposedKg, LoadUnit.kg), '88.5 kg'); // the same physical load in the other unit
  });

  test('a corrected set changes the result and the fingerprint, so a declined suggestion can be recomputed', () {
    final two = [session('2026-10-13', 'oA1', [8, 8, 8]), session('2026-10-16', 'oA2', [8, 8, 8])];
    final before = judge(two);
    final i = sets.indexWhere((s) => s.id == '${two[1].id}-e1-1');
    sets[i] = WorkoutSet({...sets[i].j, 'reps': 7}); // corrected afterwards: it was 7
    final after = judge(two);
    expect((before.decision, after.decision), (ProgressionDecision.increase, ProgressionDecision.keepCurrent));
    expect(before.fingerprint == after.fingerprint, isFalse);
    expect(judge(two).fingerprint, after.fingerprint); // same facts, same fingerprint
  });

  // ------------------------------------------------------------------ Suggested today (docs/PLAN_LIBRARY_OVERLOAD.md › 5)

  group('Suggested today', () {
    TodaySuggestion today(List<Workout> workouts, {Prescription? exercise, double? increment = 2.5, String? equipment = 'Barbell'}) =>
        ProgressionRules.today(planId: planId, definitionId: 'A', rx: exercise ?? rx(), equipment: equipment, workouts: workouts,
            sets: [for (final s in sets) if (!s.isDeleted) s], definitionOf: defOf, incrementKg: increment);

    test('reps: the newest comparable session at one weight, inside the range, suggests one more rep in total at that weight', () {
      final t = today([session('2026-10-09', 'oA1', [6, 6, 6]), session('2026-10-13', 'oA2', [7, 7, 6])]);
      expect((t.kind, t.loadKg, t.lastTotal, t.aimTotal), (TodayKind.reps, 80, 20, 21));
      expect([for (final s in t.sessions) s.workout.dayKey], ['2026-10-13'], reason: 'the newest session alone is the evidence');
      // Without a weight target the recorded weight is kept, never a new one.
      final free = today([session('2026-10-13', 'oA1', [7, 6, 6], frozen: null, load: 60.0)], exercise: rx(load: null));
      expect((free.kind, free.loadKg, free.lastTotal), (TodayKind.reps, 60, 19));
    });

    test('weight: the existing two-session rule and the saved increment, never more reps at the same time', () {
      final two = [session('2026-10-13', 'oA1', [8, 8, 8]), session('2026-10-16', 'oA2', [8, 8, 8])];
      final t = today(two);
      expect((t.kind, t.loadKg, t.lastTotal, t.repsMin, t.repsMax), (TodayKind.weight, 82.5, null, 6, 8));
      expect(today(two, increment: null).kind, TodayKind.chooseIncrement, reason: 'no step is ever invented');
      expect(today(two, increment: 5).kind, TodayKind.none, reason: 'a step over the 5% guard stays a manual review');
      // At the top once only: the weight rule waits for a second session, and no rep is asked beyond the range.
      final once = today([session('2026-10-13', 'oA1', [8, 8, 8])]);
      expect((once.kind, once.reason), (TodayKind.none, ProgressionReason.atTop));
    });

    test('a newer session that does not qualify is never skipped to reach an older one', () {
      final older = session('2026-10-09', 'oA1', [7, 7, 6]);
      expect(today([older, session('2026-10-13', 'oA2', [7, 7])]).reason, ProgressionReason.setsMissing);
      expect(today([older, session('2026-10-13', 'oA2', [7, 7, 6, 6])]).reason, ProgressionReason.extraSets);
      expect(today([older, session('2026-10-13', 'oA2', [7, 7, 6], load: [80.0, 77.5, 80.0])]).reason, ProgressionReason.loadDiffers, reason: 'inconsistent loads');
      expect(today([older, session('2026-10-13', 'oA2', [7, 7, 6], load: [80.0, null, 80.0])]).reason, ProgressionReason.loadUnknown);
      expect(today([older, session('2026-10-13', 'oA2', [5, 7, 7])]).reason, ProgressionReason.outsideRange, reason: 'a missed bottom of the range');
      expect(today([older, session('2026-10-13', 'oA2', [7, 7, 6], outcome: 'partial')]).reason, ProgressionReason.partialWorkout);
      // Changed targets: a session frozen at another weight, or another rep range, is not evidence for this one.
      expect(today([older, session('2026-10-13', 'oA2', [7, 7, 6], frozen: 77.5, load: 77.5)]).reason, ProgressionReason.targetChanged);
      expect(today([older, session('2026-10-13', 'oA2', [7, 7, 6], hi: 10)]).reason, ProgressionReason.targetChanged);
      // A weight recorded that is not this workout's target weight: not comparable.
      expect(today([session('2026-10-13', 'oA2', [7, 7, 6], load: 75.0)]).reason, ProgressionReason.loadDiffers);
    });

    test('no history, another workout, another occurrence or identity, and unsupported types give no personal suggestion', () {
      expect(today([]).reason, ProgressionReason.fewerSessions);
      expect(today([session('2026-10-13', 'oB1', [7, 7, 6])]).kind, TodayKind.none, reason: 'Upper B is another plan workout');
      // Bench press twice in Upper A: each occurrence has its own evidence.
      final both = [session('2026-10-13', 'oA1', [7, 6, 6], also: [('e3', [8, 8, 8])])];
      expect((today(both).kind, today(both).lastTotal), (TodayKind.reps, 19));
      expect(today(both, exercise: rx(key: 'e3')).reason, ProgressionReason.atTop);
      // A custom exercise in the same place is another identity: the bench press sessions are not its history.
      expect(today(both, exercise: rx(catalogKey: 'custom:0f6c')).reason, ProgressionReason.missingExercise);
      final one = [session('2026-10-13', 'oA1', [7, 7, 6])];
      expect(today(one, exercise: rx(timed: true)).reason, ProgressionReason.timed);
      expect(today(one, equipment: 'Bodyweight').reason, ProgressionReason.bodyweight);
      expect(today(one, exercise: rx(name: 'Assisted pull-up')).reason, ProgressionReason.assisted, reason: 'a heavier assist is not progress');
      expect(today(one, exercise: rx(lo: null, hi: null)).kind, TodayKind.none);
    });

    test('pounds: the kept weight is the recorded one, shown in either unit without changing it', () {
      final kg = ProgressionRules.round3(loadInputToKg(45, LoadUnit.lb));
      final t = today([session('2026-10-13', 'oA1', [10, 9, 8], hi: 12, frozen: kg, load: kg)], exercise: rx(load: kg, hi: 12));
      expect((t.kind, t.loadKg, t.lastTotal, t.aimTotal), (TodayKind.reps, kg, 27, 28));
      expect(formatLoad(t.loadKg, LoadUnit.lb), '45 lb');
    });
  });
}
