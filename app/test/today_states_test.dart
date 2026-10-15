// Today's training states (docs/TRAINING_PLANS.md › Today). The first three groups reproduce the iPhone reports of
// 15 Oct 2026 and failed before the fix: a manual workout replaced the planned one, a rotation skip pulled the next
// workout onto today, and a fixed skip read as a rest day.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/plans/plan_draft.dart';
import 'package:gohard_rebuild/features/plans/plan_projection.dart';
import 'package:gohard_rebuild/features/plans/plan_repository.dart';
import 'package:gohard_rebuild/features/today/daily.dart';
import 'package:gohard_rebuild/features/workout/workout_repository.dart';

import 'support.dart';

final _templates = PlanTemplates.parse(File('assets/data/plan-templates.json').readAsStringSync());
const _mon = '2026-10-12', _tue = '2026-10-13', _wed = '2026-10-14';

Workout _done(Plan plan, Occasion o, {String outcome = 'full', bool open = false, String? day}) => Workout({
      'id': 'w-${o.id}', 'planId': plan.id, 'occasionId': o.id, 'kind': 'planned', 'title': o.title, 'dayKey': day ?? o.scheduledDate,
      'startedAtUtc': '${day ?? o.scheduledDate}T10:00:00Z', 'finishedAtUtc': open ? null : '${day ?? o.scheduledDate}T11:00:00Z',
      'outcome': open ? null : outcome, 'qualifiedOccasion': !open && outcome != 'no_data', 'isDeleted': false, 'exercises': <Json>[],
    });

Workout _manual(String day, {bool open = false}) => Workout({
      'id': 'm-$day', 'planId': null, 'occasionId': null, 'kind': 'manual', 'title': 'My own', 'dayKey': day,
      'startedAtUtc': '${day}T07:00:00Z', 'finishedAtUtc': open ? null : '${day}T08:00:00Z',
      'outcome': open ? null : 'manual_recorded', 'qualifiedOccasion': false, 'isDeleted': false, 'exercises': <Json>[],
    });

PlanDraft _draft(String template, List<int> days) => PlanDraft.fresh(today: _mon, path: 'template')
  ..setPreferences(days: days)
  ..applyTemplate(_templates, template);

TrainingAction _today(Plan plan, String day, [List<Workout> ws = const []]) =>
    resolveTraining(today: day, ctx: TrainingCtx({'primaryPlanId': plan.id}), plans: [plan], workouts: ws);

Plan _withOccasion(Plan plan, String id, Json change) =>
    Plan(copyJson(plan.j)..['occasions'] = [for (final o in plan.j['occasions'] as List) (o as Json)['id'] == id ? ({...copyJson(o), ...change}) : o]);

void main() {
  group('report: a manual workout made the planned workout disappear', () {
    final plan = Plan(_draft('full-body', [1, 3, 5]).toPlanJson()..['lifecycle'] = 'active');
    final monday = plan.occasions.first;

    test('an open manual workout is listed apart; the planned workout stays due with its own name', () {
      final open = [_manual(_mon, open: true)];
      final a = _today(plan, _mon, open) as PlannedToday;
      expect(a.occasions.map((o) => (o.id, statusOf(o, plan, _mon, open))), [(monday.id, OccasionStatus.due)]);
      final split = openWorkouts(open, const {}, a);
      expect(split.inProgress.single.id, 'm-$_mon', reason: 'the manual session has its own Resume entry');
    });

    test('a finished manual workout is Recorded today and completes nothing', () {
      final ws = [_manual(_mon)];
      final a = _today(plan, _mon, ws) as PlannedToday;
      expect(statusOf(a.occasions.single, plan, _mon, ws), OccasionStatus.due);
      expect(occasionOutcome(monday, ws), isNull);
      final day = DailySnapshot(ownerId: 'o', dayKey: _mon, training: a, parked: const [], finishedToday: ws, food: const [], coverage: const {}, runs: const []);
      expect(day.recordedToday.map((w) => w.id), ['m-$_mon']);
    });

    test('a manual workout on a planned rest day keeps both facts', () {
      final ws = [_manual(_tue)];
      final a = _today(plan, _tue, ws);
      expect(a, isA<PlannedRest>());
      final day = DailySnapshot(ownerId: 'o', dayKey: _tue, training: a, parked: const [], finishedToday: ws, food: const [], coverage: const {}, runs: const []);
      expect(day.recordedToday.single.isManual, isTrue);
    });

    test('on the phone: starting, saving for later and finishing a manual workout leave the plan byte-identical', () async {
      final h = Harness(now: DateTime.utc(2026, 10, 12, 8));
      addTearDown(h.dispose);
      final owner = await h.signIn('one');
      final d = _draft('full-body', [1, 3, 5]);
      await PlanRepository(h.sync, owner).createAndActivate(d, today: _mon);
      await h.sync.flush();
      Future<String> planBody() async => (await h.sync.get(owner, Kinds.plan, d.planId))!.body;
      final before = await planBody();
      final workouts = WorkoutRepository(h.sync, owner, h.clock);
      final w = await workouts.startManual('My own', const [], _mon);
      await workouts.park(w.id);
      await h.sync.flush();
      await h.restart();
      expect(await planBody(), before);
      final ws = [for (final b in await h.bodies(owner, Kinds.workout)) Workout(b)];
      final p = Plan(jsonDecode(before) as Json);
      expect(statusOf((_today(p, _mon, ws) as PlannedToday).occasions.single, p, _mon, ws), OccasionStatus.due);
    });
  });

  group('report: skipping showed the next workout in its place', () {
    test('fixed weekdays: today stays "Skipped" under its own name; the next keeps its real date and is not due', () {
      var plan = Plan(_draft('full-body', [1, 3, 5]).toPlanJson()..['lifecycle'] = 'active');
      final monday = plan.occasions.first;
      plan = _withOccasion(plan, monday.id, {'isSkipped': true});
      final a = _today(plan, _mon) as PlannedToday;
      expect(a.occasions.map((o) => (o.title, statusOf(o, plan, _mon, const []))), [(monday.title, OccasionStatus.skipped)]);
      expect((a.next!.title, a.next!.scheduledDate, statusOf(a.next!, plan, _mon, const [])), (plan.occasions[1].title, _wed, OccasionStatus.upcoming));
      expect(plan.occasions.skip(1).map((o) => o.scheduledDate), plan.occasions.skip(1).map((o) => o.originalDate), reason: 'a skip moves nothing');
      expect(_today(plan, _tue), isA<PlannedRest>(), reason: 'the next day is the plan\'s rest day, not the skipped workout');
    });

    test('rotation: a skip advances once, today keeps the skipped workout, and the successor is next — not today', () async {
      final h = Harness(now: DateTime.utc(2026, 10, 12, 8));
      addTearDown(h.dispose);
      final owner = await h.signIn('one');
      final repo = PlanRepository(h.sync, owner);
      final d = _draft('upper-lower', [1, 3, 5]);
      await repo.createAndActivate(d, today: _mon);
      await h.sync.flush();
      var plan = Plan(jsonDecode((await h.sync.get(owner, Kinds.plan, d.planId))!.body) as Json);
      final head = planOccasions(plan, _mon, const []).first;
      await repo.skipOccurrence(plan, const [], head, today: _mon);
      await h.sync.flush();
      await h.sync.flush(); // a retry changes nothing
      plan = Plan(jsonDecode((await h.sync.get(owner, Kinds.plan, d.planId))!.body) as Json);

      final occ = planOccasions(plan, _mon, const []);
      final r = rotationOf(plan, occ, const [])!;
      expect((r.next!.title, r.position), ('Lower A', 1), reason: 'advanced exactly once');
      expect(r.next!.scheduledDate, _wed, reason: 'the next training day, never pulled onto today');
      final a = _today(plan, _mon) as PlannedToday;
      expect(a.occasions.map((o) => (o.title, statusOf(o, plan, _mon, const []))), [('Upper A', OccasionStatus.skipped)]);
      expect(a.next!.id, r.next!.id, reason: 'Today and Train name the same next workout');
      expect(statusOf(a.next!, plan, _mon, const []), OccasionStatus.upcoming);
    });

    test('rotation without training days: the successor is still not today\'s', () {
      final d = _draft('upper-lower', [1, 3, 5])..schedule.j['trainingDays'] = <int>[];
      var plan = Plan(d.toPlanJson()..['lifecycle'] = 'active');
      final head = planOccasions(plan, _mon, const []).first;
      plan = Plan(copyJson(plan.j)..['occasions'] = [copyJson(head.j)..remove('isVirtual')..['isSkipped'] = true]);
      final a = _today(plan, _mon) as PlannedToday;
      expect(a.occasions.single.isSkipped, isTrue);
      expect(a.next!.scheduledDate, isNot(_mon));
    });

    test('a second workout on today\'s date stays due when the first is skipped or completed', () {
      var plan = Plan(_draft('full-body', [1, 3, 5]).toPlanJson()..['lifecycle'] = 'active');
      final wed = plan.occasions[1];
      plan = _withOccasion(plan, wed.id, {'scheduledDate': _mon}); // moved onto Monday
      plan = _withOccasion(plan, plan.occasions.first.id, {'isSkipped': true});
      var a = _today(plan, _mon) as PlannedToday;
      expect(a.occasions.map((o) => statusOf(o, plan, _mon, const [])), unorderedEquals([OccasionStatus.skipped, OccasionStatus.due]));
      final done = [_done(plan, plan.occasions.firstWhere((o) => o.id == wed.id))];
      a = _today(plan, _mon, done) as PlannedToday;
      expect(a.occasions.length, 2, reason: 'completing one never hides another');
    });
  });

  group('rest days are explicit and distinct', () {
    final plan = Plan(_draft('full-body', [1, 3, 5]).toPlanJson()..['lifecycle'] = 'active');

    test('rest, skipped, completed, paused and no plan are different states', () {
      expect(_today(plan, _tue), isA<PlannedRest>());
      expect((_today(plan, _tue) as PlannedRest).next!.scheduledDate, _wed);
      expect(_today(plan, _mon, [_done(plan, plan.occasions.first)]), isA<PlannedToday>(), reason: 'completed is not rest');
      expect(_today(Plan(copyJson(plan.j)..addAll({'lifecycle': 'paused', 'pausedOn': _mon})), _tue), isA<PlanPausedAction>());
      expect(resolveTraining(today: _tue, ctx: null, plans: const [], workouts: const []), isA<CreatePlan>());
    });

    test('no rest days outside the plan: before the start it starts later, after the end the block is reviewed', () {
      expect(_today(plan, '2026-10-01'), isA<StartsLater>());
      expect(_today(plan, addDaysForTest(plan.endDate!, 1)), isA<BlockReviewDue>());
    });

    test('a rotation is never "rest" just because nothing was recorded; its waiting workout is still due', () {
      final d = _draft('upper-lower', [1, 3, 5])..schedule.j['trainingDays'] = <int>[];
      final rot = Plan(d.toPlanJson()..['lifecycle'] = 'active');
      expect(_today(rot, _tue), isA<PlannedToday>());
      expect(statusOf((_today(rot, _tue) as PlannedToday).occasions.single, rot, _tue, const []), OccasionStatus.due);
    });

    test('a rotation\'s chosen rest day skips nothing, consumes nothing, survives a restart and a pull, and can be undone', () async {
      final h = Harness(now: DateTime.utc(2026, 10, 12, 8));
      addTearDown(h.dispose);
      final owner = await h.signIn('one');
      var repo = PlanRepository(h.sync, owner);
      final d = _draft('upper-lower', [1, 3, 5]);
      await repo.createAndActivate(d, today: _mon);
      await h.sync.flush();
      Future<Plan> withRest() async {
        final p = Plan(jsonDecode((await h.sync.get(owner, Kinds.plan, d.planId))!.body) as Json);
        final days = [for (final b in await h.bodies(owner, Kinds.restDay)) if (b['planId'] == p.id) b['dayKey'] as String];
        return Plan({...p.j, 'localRestDays': days});
      }

      final commands = (await h.sync.commands(owner)).length;
      await repo.setRestDay(await withRest(), _mon, rest: true);
      await repo.setRestDay(await withRest(), _mon, rest: true); // twice is once
      await h.restart();
      repo = PlanRepository(h.sync, owner);
      await h.sync.pull();
      var plan = await withRest();
      final a = _today(plan, _mon) as PlannedRest;
      expect((a.chosen, a.next!.title, a.next!.scheduledDate), (true, 'Upper A', _wed));
      expect(plan.occasions, isEmpty, reason: 'nothing materialized, nothing skipped');
      expect(rotationOf(plan, planOccasions(plan, _mon, const []), const [])!.position, 0, reason: 'the sequence did not move');
      expect((await h.sync.commands(owner)).length, commands, reason: 'a rest choice sends nothing');
      expect(plan.j.containsKey('localRestDays') && (await h.sync.get(owner, Kinds.plan, d.planId))!.body.contains('localRestDays'), isFalse);

      await repo.setRestDay(plan, _mon, rest: false);
      plan = await withRest();
      expect(_today(plan, _mon), isA<PlannedToday>());
    });
  });

  group('identity, undo and retries', () {
    test('a repeated workout definition gives every occurrence its own identity; completing one credits only it', () {
      final plan = Plan(_draft('push-pull-legs', [1, 2, 3, 4, 5, 6]).toPlanJson()..['lifecycle'] = 'active');
      final pushes = plan.occasions.where((o) => o.title == plan.occasions.first.title).take(2).toList();
      expect(pushes[0].workoutId, pushes[1].workoutId);
      expect(pushes[0].id, isNot(pushes[1].id));
      final done = [_done(plan, pushes[0])];
      expect((occasionOutcome(pushes[0], done), occasionOutcome(pushes[1], done)), ('full', null));
    });

    test('undo skip: allowed while nothing later happened; refused once the next workout was started', () {
      var plan = Plan(_draft('upper-lower', [1, 3, 5]).toPlanJson()..['lifecycle'] = 'active');
      final head = planOccasions(plan, _mon, const []).first;
      plan = Plan(copyJson(plan.j)..['occasions'] = [copyJson(head.j)..remove('isVirtual')..['isSkipped'] = true]);
      expect(PlanRepository.canUnskip(plan, head.id, const []), isTrue);
      final next = rotationOf(plan, planOccasions(plan, _mon, const []), const [])!.next!;
      final started = [_done(plan, next, open: true, day: _mon)];
      expect(PlanRepository.canUnskip(plan, head.id, started), isFalse, reason: 'later activity: never rewound blindly');
      // The successor started now ("Train this now") is today's too, beside the skipped one.
      final a = _today(plan, _mon, started) as PlannedToday;
      expect(a.occasions.map((o) => statusOf(o, plan, _mon, started)), [OccasionStatus.skipped, OccasionStatus.inProgress]);
    });

    test('date rollover: yesterday\'s skip is history; today is today\'s own state', () {
      var plan = Plan(_draft('full-body', [1, 3, 5]).toPlanJson()..['lifecycle'] = 'active');
      plan = _withOccasion(plan, plan.occasions.first.id, {'isSkipped': true});
      expect(_today(plan, _tue), isA<PlannedRest>());
      expect((_today(plan, _wed) as PlannedToday).occasions.single.scheduledDate, _wed);
    });
  });
}

String addDaysForTest(String day, int n) => DateTime.parse('${day}T00:00:00Z').add(Duration(days: n)).toIso8601String().substring(0, 10);
