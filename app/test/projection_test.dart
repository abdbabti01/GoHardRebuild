import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/today/daily.dart';
import 'package:gohard_rebuild/features/workout/progress.dart';

import 'support.dart';

Occasion _occ(String id, String date, {int week = 1, bool skipped = false, String? outcome, String? original}) => Occasion({
      'id': id, 'weekNumber': week, 'ordinal': 1, 'title': 'Workout $id', 'originalDate': original ?? date, 'scheduledDate': date,
      'isSkipped': skipped, 'resultOutcome': outcome, 'prescription': [],
    });

Plan _plan(List<Occasion> occasions, {String lifecycle = 'active', String start = '2026-10-05', String? pausedOn, String id = 'p'}) => Plan({
      'id': id, 'title': 'Plan', 'lifecycle': lifecycle, 'startDate': start, 'blockWeeks': 4, 'pausedOn': pausedOn, 'occasions': [for (final o in occasions) o.j],
    });

Workout _workout(String id, {String? occasionId, String? outcome, String day = '2026-10-09', String kind = 'planned', bool qualified = false, List<Json> exercises = const [], String? startedAt}) => Workout({
      'id': id, 'occasionId': occasionId, 'planId': occasionId == null ? null : 'p', 'kind': kind, 'title': 'W $id', 'dayKey': day,
      'startedAtUtc': startedAt ?? '${day}T10:00:00Z', 'finishedAtUtc': outcome == null ? null : '${day}T11:00:00Z', 'outcome': outcome,
      'qualifiedOccasion': qualified, 'isDeleted': false, 'exercises': exercises,
    });

Json _ex(String id, String key, int ordinal) => {'id': id, 'ordinal': ordinal, 'name': key, 'catalogKey': key, 'isDeleted': false};
WorkoutSet _set(String exerciseId, {int reps = 8, double load = 60, String at = '2026-10-09T10:05:00Z'}) =>
    WorkoutSet({'id': '$exerciseId-$reps-$load-$at', 'exerciseId': exerciseId, 'workoutId': 'w', 'reps': reps, 'loadKg': load, 'performedAtUtc': at, 'isDeleted': false});

void main() {
  group('A2 shared calendar date', () {
    // A fixed UTC-4 zone: local midnight is 04:00 UTC, so a UTC date would be wrong for four hours every evening.
    DateTime toLocal(DateTime utc) => utc.subtract(const Duration(hours: 4));

    test('midnight_preserves_pinned_entry_date', () {
      final clock = FakeClock(DateTime.utc(2026, 10, 10, 3, 59)); // 23:59 local on Friday the 9th
      final service = BusinessDateService(clock, toLocal);
      final emitted = <String>[];
      service.changes.listen(emitted.add);
      final pinnedEntryDay = service.dayKey; // a food form or workout captures its day when it opens

      clock.now = DateTime.utc(2026, 10, 10, 4, 1); // 00:01 local on Saturday
      service.refresh();
      service.refresh(); // repeated refresh emits once

      return Future<void>.delayed(Duration.zero, () {
        expect(service.dayKey, '2026-10-10');
        expect(pinnedEntryDay, '2026-10-09');
        expect(emitted, ['2026-10-10']);
        service.dispose();
      });
    });

    test('resume_refreshes_day_without_utc_shift, and disposal prevents publication', () async {
      final clock = FakeClock(DateTime.utc(2026, 10, 10, 1, 30)); // already Saturday in UTC, still Friday 21:30 local
      final service = BusinessDateService(clock, toLocal);
      expect(service.dayKey, '2026-10-09');
      final emitted = <String>[];
      service.changes.listen(emitted.add);
      service.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty, reason: 'same local day: nothing to publish');
      service.dispose();
      clock.now = DateTime.utc(2026, 10, 11, 12);
      service.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);
    });
  });

  group('A3/A4 Today priority', () {
    const today = '2026-10-09';
    final ctx = TrainingCtx({'contextRevision': 1, 'primaryPlanId': 'p'});

    test('an open workout stays reachable, even when its plan is paused or replaced, without changing the plan\'s state', () {
      final plan = _plan([_occ('a', today)], lifecycle: 'paused', pausedOn: today);
      final open = [_workout('w1', occasionId: 'a')];
      final action = resolveTraining(today: today, ctx: ctx, plans: [plan], workouts: open);
      expect(action, isA<PlanPausedAction>());
      // pause_still_offers_resume_workout; a parked workout is listed as saved for later instead.
      expect(openWorkouts(open, const {}, action).inProgress.single.id, 'w1');
      expect(openWorkouts(open, {'w1'}, action).parked.single.id, 'w1');
    });

    test('due, done, rest, future start, review due, draft and no plan are distinct', () {
      final due = _plan([_occ('a', today), _occ('b', '2026-10-12')]);
      expect((resolveTraining(today: today, ctx: ctx, plans: [due], workouts: []) as PlannedToday).occasions.single.id, 'a');

      // A finish saved on the phone resolves the occasion immediately, before the account acknowledges it.
      final partial = [_workout('w', occasionId: 'a', outcome: 'partial', qualified: true)];
      final done = resolveTraining(today: today, ctx: ctx, plans: [due], workouts: partial) as PlannedToday;
      expect((statusOf(done.occasions.single, due, today, partial), done.next!.id), (OccasionStatus.partial, 'b'));
      // A no-data finish gives no credit: the occasion is still due.
      final noData = [_workout('w', occasionId: 'a', outcome: 'no_data')];
      expect(statusOf((resolveTraining(today: today, ctx: ctx, plans: [due], workouts: noData) as PlannedToday).occasions.single, due, today, noData), OccasionStatus.due);
      // Manual work never satisfies a planned occasion.
      final manual = [_workout('m', kind: 'manual', outcome: 'manual_recorded')];
      expect(statusOf((resolveTraining(today: today, ctx: ctx, plans: [due], workouts: manual) as PlannedToday).occasions.single, due, today, manual), OccasionStatus.due);

      final recovery = resolveTraining(today: today, ctx: ctx, plans: [_plan([_occ('missed', '2026-10-07'), _occ('skip', '2026-10-08', skipped: true), _occ('next', '2026-10-12')])], workouts: []) as PlannedRest;
      expect((recovery.next!.id, recovery.missed.map((o) => o.id).join(",")), ("next", "missed"), reason: 'missed work stays on its date and never takes over Today');

      expect(resolveTraining(today: today, ctx: ctx, plans: [_plan([_occ('a', '2026-10-16')], start: '2026-10-16')], workouts: []), isA<StartsLater>());
      expect(resolveTraining(today: today, ctx: ctx, plans: [_plan([_occ('a', '2026-10-01', outcome: 'full')])], workouts: []), isA<BlockReviewDue>());
      expect(resolveTraining(today: '2026-12-01', ctx: ctx, plans: [_plan([_occ('a', '2026-10-01')])], workouts: []), isA<BlockReviewDue>(), reason: 'past the end date is review-due, not achieved');

      final none = TrainingCtx({'contextRevision': 1, 'primaryPlanId': null});
      expect(resolveTraining(today: today, ctx: none, plans: [_plan([_occ('a', today)], lifecycle: 'draft')], workouts: []), isA<ReviewDraft>());
      expect(resolveTraining(today: today, ctx: none, plans: [], workouts: []), isA<CreatePlan>());
      // A draft never displaces the primary plan's action.
      expect(resolveTraining(today: today, ctx: ctx, plans: [due, _plan([_occ('z', today)], lifecycle: 'draft', id: 'd')], workouts: []), isA<PlannedToday>());
    });

    test('the workout that is today\'s planned result is not listed again under Recorded today; other recorded work is', () {
      final plan = _plan([_occ('a', today), _occ('b', '2026-10-12')]);
      final credited = _workout('w', occasionId: 'a', outcome: 'partial', qualified: true);
      final noData = _workout('w0', occasionId: 'a', outcome: 'no_data'); // an earlier attempt that earned nothing
      final manual = _workout('m', kind: 'manual', outcome: 'manual_recorded');
      DailySnapshot day(List<Workout> finished) => DailySnapshot(ownerId: 'o', dayKey: today,
          training: resolveTraining(today: today, ctx: ctx, plans: [plan], workouts: finished), parked: const [], finishedToday: finished, food: const [], coverage: const {}, runs: const []);

      final done = day([credited, noData, manual]);
      expect(done.training, isA<PlannedToday>());
      expect(done.recordedToday.map((w) => w.id), ['w0', 'm'], reason: 'identity, not title: only the credited workout is left out');
      // Before the module shows it as done (a manual workout alone), nothing is hidden.
      expect(day([manual]).recordedToday.map((w) => w.id), ['m']);
    });

    test('occasion statuses are honest text states', () {
      final plan = _plan([_occ('a', '2026-10-07'), _occ('b', '2026-10-09'), _occ('c', '2026-10-12'), _occ('d', '2026-10-05', outcome: 'full'), _occ('e', '2026-10-06', skipped: true)]);
      String status(String id, {Plan? p, List<Workout> w = const []}) => statusOf((p ?? plan).occasions.firstWhere((o) => o.id == id), p ?? plan, today, w).label;
      expect([status('a'), status('b'), status('c'), status('d'), status('e')], ['Missed', 'Due', 'Planned', 'Completed', 'Skipped']);
      expect(status('b', w: [_workout('w', occasionId: 'b')]), 'In progress');
      expect(status('b', w: [_workout('w', occasionId: 'b', outcome: 'partial', qualified: true)]), 'Partial');
      final paused = _plan([_occ('a', '2026-10-07'), _occ('b', '2026-10-09')], lifecycle: 'paused', pausedOn: '2026-10-08');
      expect([status('a', p: paused), status('b', p: paused)], ['Missed', 'Paused'], reason: 'expectations do not accumulate after the pause date');
      expect((planWeek(plan, '2026-10-04'), planWeek(plan, '2026-10-05'), planWeek(plan, '2026-10-12'), planWeek(plan, '2027-01-01')), (0, 1, 2, 4));
    });
  });

  group('W7 progress and previous performance', () {
    test('partial_work_counts_once and no history gives no insights', () {
      final plan = _plan([_occ('a', '2026-10-05'), _occ('b', '2026-10-07'), _occ('c', '2026-10-09'), _occ('d', '2026-10-12')]);
      final workouts = [
        _workout('w1', occasionId: 'a', outcome: 'partial', qualified: true, day: '2026-10-05'),
        _workout('w0', occasionId: 'a', outcome: 'no_data', day: '2026-10-05'), // an earlier empty attempt at the same occasion
        _workout('m', kind: 'manual', outcome: 'manual_recorded', day: '2026-10-06'),
      ];
      final p = TrainingProgressProjection.build(today: '2026-10-09', primary: plan, workouts: workouts, sets: const []);
      expect((p.dueOccasions, p.recorded, p.partial, p.full, p.missed, p.skipped), (2, 1, 1, 0, 1, 0), reason: 'today\'s due workout and future ones are not outcomes yet');
      expect(p.sessions, 2, reason: 'manual work is training; the no-data record is not');
      expect(p.weeks.last.$2, 2);
      expect(p.insights, isEmpty);

      final none = TrainingProgressProjection.build(today: '2026-10-09', primary: null, workouts: const [], sets: const []);
      expect((none.hasEvidence, none.insights.length, none.dueOccasions), (false, 0, 0));
    });

    test('duplicate_templates_keep_distinct_previous_sets and strength compares like with like', () {
      final earlier = _workout('w1', outcome: 'full', day: '2026-10-02', exercises: [_ex('a1', 'bench-press', 1), _ex('a2', 'bench-press', 2), _ex('a3', 'plank', 3)]);
      final unfinished = _workout('w-open', day: '2026-10-05', exercises: [_ex('o1', 'bench-press', 1)]);
      final current = _workout('w2', day: '2026-10-09', exercises: [_ex('b1', 'bench-press', 1), _ex('b2', 'bench-press', 2), _ex('b3', 'custom', 3)..['catalogKey'] = null]);
      final sets = [
        _set('a1', reps: 5, load: 100, at: '2026-10-02T10:01:00Z'), _set('a2', reps: 8, load: 80, at: '2026-10-02T10:10:00Z'),
        _set('o1', reps: 1, load: 200, at: '2026-10-05T10:00:00Z'),
        _set('b1', reps: 5, load: 102.5), _set('b2', reps: 9, load: 80),
      ];
      final all = [earlier, unfinished, current];
      final first = previousPerformance(current, current.exercises[0], all, sets)!;
      final second = previousPerformance(current, current.exercises[1], all, sets)!;
      expect((first.sets.single.reps, first.sets.single.loadKg, first.dayKey), (5, 100, '2026-10-02'));
      expect((second.sets.single.reps, second.sets.single.loadKg), (8, 80), reason: 'the second occurrence has its own history');
      expect(previousPerformance(current, current.exercises[2], all, sets), isNull, reason: 'no catalog identity: no guessing by name');
      expect(previousPerformance(earlier, earlier.exercises[2], all, sets), isNull, reason: 'missing history is absent, not invented');

      final finished = Workout({...current.j, 'outcome': 'full', 'finishedAtUtc': '2026-10-09T11:00:00Z'});
      final p = TrainingProgressProjection.build(today: '2026-10-09', primary: null, workouts: [earlier, unfinished, finished], sets: sets);
      final bench = p.insights.single;
      expect((bench.sessions, bench.first.loadKg, bench.latest.loadKg, bench.firstDay, bench.latestDay), (2, 100, 102.5, '2026-10-02', '2026-10-09'));
      expect(countsAsTraining(unfinished), isFalse);
    });

    test('calendar keys', () {
      expect(dayKeyOf(DateTime(2026, 3, 8, 23, 59)), '2026-03-08');
      expect(addDays('2026-12-31', 1), '2027-01-01');
    });
  });
}
