import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/plans/plan_draft.dart';
import 'package:gohard_rebuild/features/plans/plan_projection.dart';
import 'package:gohard_rebuild/features/plans/plan_repository.dart';
import 'package:gohard_rebuild/features/plans/plan_rules.dart';
import 'package:gohard_rebuild/features/today/daily.dart';
import 'package:gohard_rebuild/features/workout/workout_repository.dart';

import 'support.dart';

final _templates = PlanTemplates.parse(File('assets/data/plan-templates.json').readAsStringSync());
final _catalog = {
  for (final c in jsonDecode(File('../api/src/GoHard.Api/Data/exercise-catalog.json').readAsStringSync()) as List) (c as Json)['key'] as String: c,
};
CatalogExercise _ex(String key) => CatalogExercise(_catalog[key]!);

/// A credited workout for an occurrence, as a finished planned workout looks on the phone before the account answers.
Workout _done(Plan plan, Occasion o, {String outcome = 'full', bool open = false}) => Workout({
      'id': 'w-${o.id}', 'planId': plan.id, 'occasionId': o.id, 'kind': 'planned', 'title': o.title, 'dayKey': o.scheduledDate,
      'startedAtUtc': '${o.scheduledDate}T10:00:00Z', 'finishedAtUtc': open ? null : '${o.scheduledDate}T11:00:00Z',
      'outcome': open ? null : outcome, 'qualifiedOccasion': !open && outcome != 'no_data', 'isDeleted': false, 'exercises': <Json>[],
    });

Plan _rotating({String start = '2026-10-12', List<int> days = const [1, 3, 5], int? weeks}) {
  final d = PlanDraft.fresh(today: start, path: 'template')..setPreferences(days: days);
  d.applyTemplate(_templates, 'upper-lower'); // 4 workouts over 3 days → a rotation
  d.durationWeeks = weeks;
  return Plan(d.toPlanJson()..['lifecycle'] = 'active');
}

void main() {
  group('plan rules match the shared fixture', () {
    for (final c in (fixture['planIds'] as List).cast<Json>()) {
      test('id ${c['name']}', () {
        final name = c['name'] as String;
        final id = name.startsWith('d:') ? PlanRules.fixedId(c['planId'] as String, name.substring(2)) : PlanRules.sequenceId(c['planId'] as String, int.parse(name.substring(2)));
        expect(id, c['expect']);
      });
    }
    for (final c in (fixture['planFixed'] as List).cast<Json>()) {
      test(c['name'] as String, () {
        final pattern = [for (final p in (c['pattern'] as List).cast<Json>()) (weekday: p['weekday'] as int, workoutId: p['workoutId'] as String)];
        final out = PlanRules.fixedDates(c['planId'] as String, c['start'] as String, c['durationWeeks'] as int, pattern);
        expect([for (final o in out) {'id': o.id, 'date': o.date, 'weekNumber': o.weekNumber, 'ordinal': o.ordinal, 'workoutId': o.workoutId}], c['expect']);
        expect(out.map((o) => o.id).toSet().length, out.length, reason: 'a repeated workout still gives every occurrence its own identity');
      });
    }
    for (final c in (fixture['planRotating'] as List).cast<Json>()) {
      test(c['name'] as String, () {
        for (final e in (c['expect'] as List).cast<List>()) {
          expect(PlanRules.workoutFor((c['cycle'] as List).cast<String>(), c['cycleAnchor'] as int, e[0] as int), e[1], reason: 'index ${e[0]}');
        }
      });
    }
    for (final c in (fixture['planValidate'] as List).cast<Json>()) {
      test(c['name'] as String, () {
        expect(PlanRules.validate(c['plan'] as Json), c['expectErrors']);
        expect(PlanRules.usable(c['plan'] as Json), c['expectUsable']);
      });
    }
    for (final c in (fixture['planRevise'] as List).cast<Json>()) {
      test(c['name'] as String, () {
        final occasions = (c['occasions'] as List).cast<Json>();
        final out = PlanRules.revise(planId: c['planId'] as String, start: c['start'] as String, weeks: c['durationWeeks'] as int, effective: c['effectiveDate'] as String,
            occasions: occasions, pending: {for (final o in occasions) if (o['pending'] == true) o['id'] as String},
            workouts: (c['workouts'] as List).cast<Json>(), schedule: c['schedule'] as Json);
        expect([
          for (final o in out)
            {'id': o['id'], 'originalDate': o['originalDate'], 'scheduledDate': o['scheduledDate'], 'workoutId': o['workoutId'], 'title': o['title'],
              'weekNumber': o['weekNumber'], 'ordinal': o['ordinal'], 'firstExercise': ((o['prescription'] as List).first as Json)['name']},
        ], c['expect']);
      });
    }
  });

  group('starter templates', () {
    test('every starter exercise is a real catalog exercise with its catalog name and timing, and no weight', () {
      for (final t in _templates.templates) {
        for (final w in t.workouts) {
          for (final e in w.exercises) {
            final c = _catalog[e['catalogKey']];
            expect(c, isNotNull, reason: '${t.id}/${w.key}: ${e['catalogKey']}');
            expect((e['name'], e['isTimed']), (c!['name'], c['isTimed']), reason: '${t.id}/${w.key}');
            expect(e.containsKey('targetLoadKg'), isFalse, reason: 'starters never invent a weight');
          }
        }
        for (final seq in t.sequences.values) {
          expect(seq.every((k) => t.workouts.any((w) => w.key == k)), isTrue, reason: t.id);
        }
      }
    });

    test('equipment variants use only that equipment, never repeat an exercise, and stay valid', () {
      const allowed = {'dumbbells': {'Dumbbell', 'Bodyweight'}, 'bodyweight': {'Bodyweight'}};
      for (final t in _templates.templates) {
        for (final w in t.workouts) {
          for (final eq in allowed.keys) {
            final list = _templates.exercisesFor(w, eq);
            expect(list, isNotEmpty, reason: '${t.id}/${w.key}/$eq');
            expect(list.map((e) => e['catalogKey']).toSet().length, list.length, reason: '${t.id}/${w.key}/$eq repeats');
            for (final e in list) {
              expect(allowed[eq], contains(_catalog[e['catalogKey']]!['equipment']), reason: '${t.id}/${w.key}/$eq: ${e['catalogKey']}');
              expect(e['isTimed'], _catalog[e['catalogKey']]!['isTimed']);
            }
          }
        }
      }
    });

    test('suggestion follows the days available and every suggestion exists', () {
      expect([for (final d in [2, 3, 4, 5, 6, 7]) suggestTemplate(d).templateId], ['full-body', 'full-body', 'upper-lower', 'upper-lower-ppl', 'push-pull-legs', 'push-pull-legs']);
      for (final d in [2, 3, 4, 5, 6, 7]) {
        expect(_templates.byId(suggestTemplate(d).templateId).name, isNotEmpty);
      }
    });

    test('push/pull/legs on six days: three definitions, six occurrences a week, each with its own identity', () {
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..setPreferences(days: [1, 2, 3, 4, 5, 6]);
      d.applyTemplate(_templates, 'push-pull-legs');
      expect(d.workouts.map((w) => w.name), ['Push', 'Pull', 'Legs']);
      expect(d.schedule.mode, 'fixed');
      final week1 = [for (final o in d.occurrences()) if (o['weekNumber'] == 1) o];
      expect(week1.map((o) => o['title']), ['Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs']);
      expect(week1.map((o) => o['id']).toSet().length, 6);
      expect(week1.map((o) => o['workoutId']).toSet().length, 3);
      expect(d.isUsable, isTrue);

      // Completing Monday's Push credits that occurrence only, not Thursday's.
      final plan = Plan(d.toPlanJson()..['lifecycle'] = 'active');
      final monday = plan.occasions.first, thursday = plan.occasions[3];
      final status = statusOf(thursday, plan, '2026-10-12', [_done(plan, monday)]);
      expect((statusOf(monday, plan, '2026-10-12', [_done(plan, monday)]), status), (OccasionStatus.finished, OccasionStatus.upcoming));
    });

    test('the first training day from the start date gets the first workout', () {
      final d = PlanDraft.fresh(today: '2026-10-16', path: 'template')..setPreferences(days: [1, 3, 5]); // a Friday
      d.applyTemplate(_templates, 'full-body');
      expect(d.occurrences().take(3).map((o) => (o['scheduledDate'], o['title'])),
          [('2026-10-16', 'Full body A'), ('2026-10-19', 'Full body B'), ('2026-10-21', 'Full body C')]);
      expect(d.sequence.map((id) => d.workout(id)!.name), ['Full body A', 'Full body B', 'Full body C']);
    });

    test('a different number of days rotates the template instead of dropping a workout', () {
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..setPreferences(days: [1, 3, 5]);
      d.applyTemplate(_templates, 'upper-lower');
      expect((d.schedule.mode, d.workouts.length), ('rotating', 4));
      expect(d.schedule.trainingDays, [1, 3, 5]);
    });

    test('an empty structure is a draft until every scheduled workout has an exercise', () {
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body', withExercises: false);
      expect(d.errors, isEmpty);
      expect(d.isUsable, isFalse);
      for (final w in d.workouts) {
        d.addExercise(w.id, _ex('push-up'));
      }
      expect(d.isUsable, isTrue);
    });

    test('choosing a template makes a personal copy: editing it never changes the starter', () {
      final before = jsonEncode(_templates.byId('full-body').workouts.first.exercises);
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body');
      final w = d.workouts.first;
      d.setPrescription(w.id, w.exercises.first.occurrenceKey, sets: 5, repsMin: 3, repsMax: 5, restSeconds: 200, targetLoadKg: 80);
      d.renameWorkout(w.id, 'Heavy day');
      expect(jsonEncode(_templates.byId('full-body').workouts.first.exercises), before);
      expect(PlanDraft.fresh(today: '2026-10-12', path: 'template').copy().workouts, isEmpty);
    });
  });

  group('the workout editor', () {
    test('rename, duplicate, delete and reorder workouts; add, replace, remove and reorder exercises', () {
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'custom')..setPreferences(days: [1, 4]);
      d.setCustomStructure(['Strength', 'Conditioning']);
      final a = d.workouts.first.id;
      d.renameWorkout(a, ' Heavy ');
      final copy = d.duplicateWorkout(a);
      d.moveWorkout(copy, 1);
      expect(d.workouts.map((w) => w.name), ['Heavy', 'Conditioning', 'Heavy (copy)']);

      final squat = d.addExercise(a, _ex('back-squat'));
      d.addExercise(a, _ex('plank'));
      d.setPrescription(a, squat, sets: 4, repsMin: 5, repsMax: 8, restSeconds: 180, targetLoadKg: 100, notes: 'Belt');
      d.moveExercise(a, squat, 1);
      expect(d.workout(a)!.exercises.map((e) => e.name), ['Plank', 'Back squat']);
      expect(targetText(sets: 4, repsMin: 5, repsMax: 8), '4 sets · 5–8 reps');

      d.replaceExercise(a, squat, _ex('goblet-squat'));
      final replaced = d.workout(a)!.exercises.last;
      expect((replaced.name, replaced.targetSets, replaced.targetRepsMin, replaced.restSeconds, replaced.targetLoadKg), ('Goblet squat', 4, 5, 180, null),
          reason: 'the new exercise keeps the prescription but not the old weight target');
      expect(replaced.occurrenceKey, isNot(squat), reason: 'a replacement is a new identity');

      d.removeExercise(a, replaced.occurrenceKey);
      d.deleteWorkout(copy);
      expect(d.workouts.length, 2);
      expect(d.schedule.pattern.map((p) => p.workoutId), isNot(contains(copy)));
    });

    test('a workout can be copied from another plan or a recorded workout without linking back', () {
      final source = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'push-pull-legs');
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'custom')..setCustomStructure(['A']);
      final id = d.copyWorkout('Push from my old plan', source.workouts.first.exercises);
      expect(d.workout(id)!.exercises.length, source.workouts.first.exercises.length);
      d.removeExercise(id, d.workout(id)!.exercises.first.occurrenceKey);
      expect(source.workouts.first.exercises.length, d.workout(id)!.exercises.length + 1);
    });
  });

  group('rotation', () {
    test('the cycle continues across weeks and never restarts on Monday', () {
      final plan = _rotating();
      final first = planOccasions(plan, '2026-10-12', const []);
      expect(first.take(4).map((o) => (o.title, o.scheduledDate)),
          [('Upper A', '2026-10-12'), ('Lower A', '2026-10-14'), ('Upper B', '2026-10-16'), ('Lower B', '2026-10-19')]);
      // Mon, Wed and Fri done: the next Monday is Lower B, not Upper A.
      final done = <Workout>[];
      for (final o in first.take(3)) {
        done.add(_done(plan, o));
      }
      final next = planOccasions(plan, '2026-10-19', done).where((o) => occasionOutcome(o, done) == null).first;
      expect((next.title, next.scheduledDate, next.sequenceIndex), ('Lower B', '2026-10-19', 3));
      expect(rotationOf(plan, planOccasions(plan, '2026-10-19', done), done)!.position, 3);
    });

    test('opening, recording without finishing, a no-data finish and manual training do not advance it', () {
      final plan = _rotating();
      final head = planOccasions(plan, '2026-10-12', const []).first;
      String nextTitle(List<Workout> ws) => rotationOf(plan, planOccasions(plan, '2026-10-12', ws), ws)!.next?.title ?? '';
      final open = _done(plan, head, open: true);
      expect(statusOf(planOccasions(plan, '2026-10-12', [open]).first, plan, '2026-10-12', [open]), OccasionStatus.inProgress);
      final noData = _done(plan, head, outcome: 'no_data');
      expect(nextTitle([noData]), 'Upper A');
      final manual = Workout({..._done(plan, head).j, 'kind': 'manual', 'planId': null, 'occasionId': null, 'qualifiedOccasion': false});
      expect(nextTitle([manual]), 'Upper A');
      expect(statusOf((resolveTraining(today: '2026-10-12', ctx: TrainingCtx({'primaryPlanId': plan.id}), plans: [plan], workouts: [manual]) as PlannedToday).occasions.single, plan, '2026-10-12', [manual]), OccasionStatus.due);
    });

    test('a workout saved for later is still the next step: Train and Today agree and nothing after it is offered', () {
      final plan = _rotating();
      final head = planOccasions(plan, '2026-10-12', const []).first;
      final parked = [_done(plan, head, open: true)];
      final occ = planOccasions(plan, '2026-10-12', parked);
      final r = rotationOf(plan, occ, parked)!;
      expect((r.next!.title, r.position), ('Upper A', 0), reason: 'saving for later never moves the cycle on');
      final today = resolveTraining(today: '2026-10-12', ctx: TrainingCtx({'primaryPlanId': plan.id}), plans: [plan], workouts: parked);
      expect((today as PlannedToday).occasions.single.id, r.next!.id);
      expect(openWorkouts(parked, {parked.single.id}, today).parked, isEmpty, reason: 'shown once, as the plan entry\'s own state');
    });

    test('undo skip in a rotation only on the latest step, counting steps started on this phone', () {
      var plan = _rotating();
      final occ = planOccasions(plan, '2026-10-12', const []);
      plan = Plan(copyJson(plan.j)..['occasions'] = [copyJson(occ[0].j)..remove('isVirtual')..['isSkipped'] = true]);
      expect(PlanRepository.canUnskip(plan, occ[0].id, const []), isTrue);
      final laterStarted = [_done(plan, planOccasions(plan, '2026-10-12', const []).firstWhere((o) => o.isVirtual), open: true)];
      expect(PlanRepository.canUnskip(plan, occ[0].id, laterStarted), isFalse);
    });

    test('a waiting workout is due, never missed, and the next is projected onto training days', () {
      final plan = _rotating();
      final o = planOccasions(plan, '2026-10-13', const []).first; // Tuesday: not a training day
      expect((o.title, o.scheduledDate), ('Upper A', '2026-10-14'));
      final a = resolveTraining(today: '2026-10-13', ctx: TrainingCtx({'primaryPlanId': plan.id}), plans: [plan], workouts: const []);
      expect(a, isA<PlannedRest>());
      expect((a as PlannedRest).next!.title, 'Upper A');
    });

    test('an ongoing rotation has no end and no review; a finite one ends', () {
      final ongoing = _rotating();
      expect((ongoing.isOngoing, ongoing.endDate, ongoing.blockWeeks), (true, null, 1));
      expect(resolveTraining(today: '2027-06-01', ctx: TrainingCtx({'primaryPlanId': ongoing.id}), plans: [ongoing], workouts: const []), isNot(isA<BlockReviewDue>()));
      final finite = _rotating(weeks: 2);
      expect(finite.endDate, '2026-10-25');
      expect(planOccasions(finite, '2026-10-24', const []).every((o) => o.scheduledDate.compareTo('2026-10-25') <= 0), isTrue);
    });
  });

  group('on the phone (real Drift, restart)', () {
    late Harness h;
    late String owner;
    late PlanRepository repo;
    setUp(() async {
      h = Harness(now: DateTime.utc(2026, 10, 12, 8));
      owner = await h.signIn('one');
      repo = PlanRepository(h.sync, owner);
    });
    tearDown(() => h.dispose());

    Future<Plan> stored(String id) async => Plan(jsonDecode((await h.sync.get(owner, Kinds.plan, id))!.body) as Json);

    test('a template preview and a saved draft create no plan and no command, and the draft survives a restart', () async {
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body');
      await repo.saveBuilderDraft(d);
      await h.restart();
      repo = PlanRepository(h.sync, owner);
      expect(await h.sync.list(owner, Kinds.plan), isEmpty);
      expect(await h.sync.commands(owner), isEmpty);
      final back = await repo.builderDraft('new');
      expect(jsonEncode(back!.j), jsonEncode(d.j));
    });

    test('activation offline creates an independent active plan that survives a restart; create is sent before activate', () async {
      h.server.offline = true;
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'push-pull-legs');
      await repo.saveBuilderDraft(d);
      await repo.createAndActivate(d, today: '2026-10-12');
      await h.restart();
      repo = PlanRepository(h.sync, owner);

      final plan = await stored(d.planId);
      expect((plan.lifecycle, plan.isBuilt, plan.workouts.length, plan.occasions.length), ('active', true, 3, 24));
      expect(TrainingCtx((await h.bodies(owner, Kinds.context)).single).primaryPlanId, d.planId);
      final cmds = await h.sync.commands(owner);
      expect(cmds.map((c) => c.kind), ['plan.create', 'plan.activate']);
      expect((jsonDecode(cmds.last.dependsOn) as List), contains(cmds.first.operationId));
      expect(await repo.builderDraft('new'), isNull, reason: 'the draft is done once activated');

      final tried = h.server.calls.length;
      h.server.offline = false;
      await h.sync.flush();
      expect(h.server.calls.skip(tried).map((c) => c.path), ['/plans', '/plans/${d.planId}/activate']);
    });

    test('a refused activation does not replace a current plan without naming it', () async {
      final first = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body');
      await repo.createAndActivate(first, today: '2026-10-12');
      final second = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'upper-lower');
      await expectLater(repo.createAndActivate(second, today: '2026-10-12'), throwsA(isA<ScheduleRefused>()));
      expect(await h.sync.get(owner, Kinds.plan, second.planId), isNull, reason: 'nothing half-created');
      await repo.createAndActivate(second, today: '2026-10-12', replacePrimaryId: first.planId);
      expect(((await stored(first.planId)).lifecycle, (await stored(second.planId)).lifecycle), ('paused', 'active'));
    });

    test('editing future workouts leaves completed history and an open session untouched', () async {
      h.server.offline = true;
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body');
      await repo.createAndActivate(d, today: '2026-10-12');
      var plan = await stored(d.planId);
      final workouts = WorkoutRepository(h.sync, owner, h.clock);
      final done = await workouts.startPlanned(plan, plan.occasions[0], '2026-10-12');
      await workouts.recordSet(done, done.exercises.first.id, reps: 8, loadKg: 60);
      await workouts.finish(done);
      final open = await workouts.startPlanned(plan, plan.occasions[1], '2026-10-14');
      await workouts.recordSet(open, open.exercises.first.id, reps: 10, loadKg: 70);
      final setsBefore = jsonEncode(await h.bodies(owner, Kinds.set));
      final workoutsBefore = jsonEncode([for (final b in await h.bodies(owner, Kinds.workout)) b]);

      // From Wednesday on: Full body A gets a new first exercise, every remaining A follows it.
      final edit = PlanDraft.fromPlan(plan, duplicate: false, today: '2026-10-14');
      final a = edit.workouts.first;
      edit.replaceExercise(a.id, a.exercises.first.occurrenceKey, _ex('goblet-squat'));
      final all = [for (final b in await h.bodies(owner, Kinds.workout)) Workout(b)];
      await repo.revise(plan, edit, workouts: all, today: '2026-10-14');
      plan = await stored(d.planId);

      final mondayA = plan.occasions[0], wednesdayB = plan.occasions[1];
      expect(mondayA.prescription.first.name, 'Back squat', reason: 'the completed occurrence keeps its content');
      expect(wednesdayB.prescription.first.name, 'Romanian deadlift', reason: 'the open session keeps its snapshot');
      final nextA = plan.occasions.where((o) => o.title == 'Full body A' && o.scheduledDate.compareTo('2026-10-14') > 0).first;
      expect(nextA.prescription.first.name, 'Goblet squat');
      expect(jsonEncode(await h.bodies(owner, Kinds.set)), setsBefore);
      expect(jsonEncode(await h.bodies(owner, Kinds.workout)), workoutsBefore, reason: 'recorded workouts and their frozen exercises are never rewritten');
      expect((await h.sync.commands(owner)).last.kind, 'plan.revise');
    });

    test('a resumed edit of a plan that changed since is refused, and an old effective date is never used', () async {
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body');
      await repo.createAndActivate(d, today: '2026-10-12');
      final plan = await stored(d.planId);
      final edit = PlanDraft.fromPlan(plan, duplicate: false, today: '2026-10-12');
      final newer = Plan(copyJson(plan.j)..['revision'] = plan.revision + 1);
      await expectLater(repo.revise(newer, edit, workouts: const [], today: '2026-10-15'), throwsA(isA<ScheduleRefused>()));

      edit.assignDay(weekdayIs('2026-10-14'), null); // no more Wednesdays, from an edit begun on Monday ...
      await repo.revise(plan, edit, workouts: const [], today: '2026-10-15'); // ... saved on Thursday
      final cmd = jsonDecode((await h.sync.commands(owner)).last.payload) as Json;
      expect(cmd['effectiveDate'], '2026-10-15');
      expect((await stored(d.planId)).occasions.any((o) => o.originalDate == '2026-10-14'), isTrue, reason: 'Wednesday, already missed, stays on its date');
    });

    test('moving one occurrence keeps its identity; changing the pattern regenerates only what is pending from the effective date', () async {
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body');
      await repo.createAndActivate(d, today: '2026-10-12');
      var plan = await stored(d.planId);
      final friday = plan.occasions[2];
      await repo.move(plan, scheduleOf(plan, const []), friday.id, '2026-10-17');
      plan = await stored(d.planId);
      final moved = plan.occasions.firstWhere((o) => o.id == friday.id);
      expect((moved.scheduledDate, moved.originalDate, plan.occasions.length), ('2026-10-17', '2026-10-16', 24));

      final edit = PlanDraft.fromPlan(plan, duplicate: false, today: '2026-10-19')..effectiveDate = '2026-10-19';
      edit.assignDay(5, null); // no more Fridays from the 19th
      await repo.revise(plan, edit, workouts: const [], today: '2026-10-19');
      plan = await stored(d.planId);
      expect(plan.occasions.where((o) => o.originalDate.compareTo('2026-10-19') >= 0).every((o) => weekdayIs(o.originalDate) != 5), isTrue);
      expect(plan.occasions.firstWhere((o) => o.id == friday.id).scheduledDate, '2026-10-17', reason: 'the earlier one-off move is kept');
      expect(plan.occasions.length, 2 + 1 + 2 * 7);
    });

    test('rotation: a skip advances once; retrying it cannot advance again, and a lost response is replayed', () async {
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')
        ..setPreferences(days: [1, 3, 5])
        ..applyTemplate(_templates, 'upper-lower');
      await repo.createAndActivate(d, today: '2026-10-12');
      await h.sync.flush();
      var plan = await stored(d.planId);
      final head = planOccasions(plan, '2026-10-12', const []).first;
      h.server.loseNextResponse = true;
      await repo.skipOccurrence(plan, const [], head, today: '2026-10-12');
      await h.sync.flush(); // lost
      await h.sync.flush(); // retried with the same operation ID and bytes
      final skips = h.server.callsTo('/schedule-changes');
      expect(skips.length, 2);
      expect(skips.first.body, skips.last.body);

      plan = await stored(d.planId);
      final occ = planOccasions(plan, '2026-10-12', const []);
      expect((occ.first.isSkipped, occ.first.sequenceIndex, rotationOf(plan, occ, const [])!.next!.title), (true, 0, 'Lower A'));
      expect(() => repo.skipOccurrence(plan, const [], occ.first, today: '2026-10-12'), throwsA(isA<ScheduleRefused>()), reason: 'already skipped');
      expect(() => repo.move(plan, scheduleOf(plan, const []), occ.first.id, '2026-10-20'), throwsA(isA<ScheduleRefused>()));
    });

    test('a virtual rotation step starts with its plan and index, and the account is asked to materialize it', () async {
      h.server.offline = true;
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')
        ..setPreferences(days: [1, 3, 5])
        ..applyTemplate(_templates, 'upper-lower');
      await repo.createAndActivate(d, today: '2026-10-12');
      final plan = await stored(d.planId);
      final head = planOccasions(plan, '2026-10-12', const []).first;
      await WorkoutRepository(h.sync, owner, h.clock).startPlanned(plan, head, '2026-10-12');
      final start = (await h.sync.commands(owner)).last;
      final payload = jsonDecode(start.payload) as Json;
      expect((payload['occasionId'], payload['planId'], payload['sequenceIndex']), (head.id, plan.id, 0));
      expect(jsonDecode(start.dependsOn) as List, isNotEmpty, reason: 'the start waits for the plan to exist on the account');
    });

    test('custom exercises are private to their owner and prescriptions wait for them', () async {
      h.server.offline = true;
      final mine = await repo.saveCustomExercise(name: 'Sled push', category: 'Legs', equipment: 'Other', isTimed: true);
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'custom')..setCustomStructure(['Conditioning', 'Strength', 'Mobility']);
      for (final w in d.workouts) {
        d.addExercise(w.id, CatalogExercise({'key': mine.key, 'name': mine.name, 'category': 'Legs', 'equipment': 'Other', 'isTimed': true}));
      }
      await repo.createAndActivate(d, today: '2026-10-12');
      final create = (await h.sync.commands(owner, states: const ['pending', 'accepted'])).firstWhere((c) => c.kind == 'plan.create');
      final put = (await h.sync.commands(owner, states: const ['pending', 'accepted'])).firstWhere((c) => c.kind == 'customexercise.put');
      expect(jsonDecode(create.dependsOn) as List, contains(put.operationId));

      final other = await h.signIn('two');
      expect(await h.sync.list(other, Kinds.customExercise), isEmpty);
      expect((await h.sync.list(owner, Kinds.customExercise)).single.id, mine.id);
    });
  });

  group('Today and Train agree', () {
    test('due, rest, paused, skipped and completed read the same from the shared projection', () {
      final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body');
      var plan = Plan(d.toPlanJson()..['lifecycle'] = 'active');
      final ctx = TrainingCtx({'primaryPlanId': plan.id});
      TrainingAction today(String day, List<Workout> ws) => resolveTraining(today: day, ctx: ctx, plans: [plan], workouts: ws);
      final monday = planOccasions(plan, '2026-10-12', const []).first;

      expect((today('2026-10-12', const []) as PlannedToday).occasions.single.id, monday.id);
      expect(statusOf(monday, plan, '2026-10-12', const []), OccasionStatus.due);
      expect(today('2026-10-13', const []), isA<PlannedRest>());
      final done = [_done(plan, monday)];
      expect((today('2026-10-12', done) as PlannedToday).occasions.single.id, monday.id);
      expect(statusOf(monday, plan, '2026-10-12', done), OccasionStatus.finished);

      plan = Plan(copyJson(plan.j)..['occasions'] = [for (final o in plan.j['occasions'] as List) (o as Json)['id'] == monday.id ? (copyJson(o)..['isSkipped'] = true) : o]);
      expect(statusOf(plan.occasions.first, plan, '2026-10-12', const []), OccasionStatus.skipped);
      expect((today('2026-10-12', const []) as PlannedToday).occasions.single.isSkipped, isTrue, reason: 'a skipped workout is not due, not done and not a rest day');

      plan = Plan(copyJson(plan.j)..addAll({'lifecycle': 'paused', 'pausedOn': '2026-10-12'}));
      expect(today('2026-10-14', const []), isA<PlanPausedAction>());
      expect(statusOf(plan.occasions[1], plan, '2026-10-14', const []), OccasionStatus.paused);
    });
  });
}

int weekdayIs(String dayKey) => DateTime.parse('${dayKey}T00:00:00Z').weekday;
