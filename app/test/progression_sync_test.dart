import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/plans/plan_draft.dart';
import 'package:gohard_rebuild/features/plans/plan_repository.dart';
import 'package:gohard_rebuild/features/workout/progression_repository.dart';
import 'package:gohard_rebuild/features/workout/workout_repository.dart';

import 'support.dart';

final _templates = PlanTemplates.parse(File('assets/data/plan-templates.json').readAsStringSync());

/// Next targets and equipment increments on the REAL Drift database file and the fake account authority.
void main() {
  late Harness h;
  late String owner;
  setUp(() async {
    h = Harness(now: DateTime.utc(2026, 10, 12, 8));
    owner = await h.signIn('one');
  });
  tearDown(() => h.dispose());

  Future<Plan> stored(String id) async => Plan(jsonDecode((await h.sync.get(owner, Kinds.plan, id))!.body) as Json);
  Future<List<Workout>> workouts() async => [for (final b in await h.bodies(owner, Kinds.workout)) Workout(b)];
  double? squatTarget(Occasion o) => o.prescription.firstWhere((e) => e.catalogKey == 'back-squat').targetLoadKg;

  test('an accepted target is saved once offline, survives restart, reaches the next matching start and changes no started or recorded workout', () async {
    h.server.offline = true;
    final repo = PlanRepository(h.sync, owner), wr = WorkoutRepository(h.sync, owner, h.clock);
    final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body'); // A Mon, B Wed, C Fri
    await repo.createAndActivate(d, today: '2026-10-12');
    var plan = await stored(d.planId);
    final a = plan.workouts.first, squat = a.exercises.firstWhere((e) => e.catalogKey == 'back-squat');
    Future<Receipt?> target(double kg, String today) async => repo.setNextTarget(await stored(d.planId),
        workoutId: a.id, occurrenceKey: squat.occurrenceKey, loadKg: kg, sets: 3, repsMin: 6, repsMax: 10, workouts: await workouts(), today: today);

    // A baseline target, then Monday's A recorded and finished at it.
    await target(100, '2026-10-12');
    plan = await stored(d.planId);
    final done = await wr.startPlanned(plan, plan.occasions[0], '2026-10-12');
    for (var i = 0; i < 3; i++) {
      await wr.recordSet(done, done.exercises.first.id, reps: 10, loadKg: 100);
    }
    await wr.finish(done);

    // The next Monday's A is open with a set in it when the next target is accepted.
    h.clock.advance(const Duration(days: 7));
    plan = await stored(d.planId);
    final mon19 = plan.occasions.firstWhere((o) => o.originalDate == '2026-10-19');
    final open = await wr.startPlanned(plan, mon19, '2026-10-19');
    await wr.recordSet(open, open.exercises.first.id, reps: 8, loadKg: 100);
    final workoutsBefore = jsonEncode(await h.bodies(owner, Kinds.workout)), setsBefore = jsonEncode(await h.bodies(owner, Kinds.set));

    final receipt = await target(102.5, '2026-10-19');
    expect(receipt, isNotNull);
    expect(await target(102.5, '2026-10-19'), isNull, reason: 'a second confirmation changes nothing and queues nothing');
    expect((await h.sync.commands(owner)).where((c) => c.kind == 'plan.revise').length, 2);

    await h.restart();
    plan = await stored(d.planId);
    expect(plan.workouts.first.exercises.firstWhere((e) => e.occurrenceKey == squat.occurrenceKey).targetLoadKg, 102.5);
    expect(squatTarget(plan.occasions.firstWhere((o) => o.originalDate == '2026-10-12')), 100, reason: 'the recorded occurrence keeps its content');
    expect(squatTarget(plan.occasions.firstWhere((o) => o.originalDate == '2026-10-19')), 100, reason: 'the open session keeps its snapshot');
    final mon26 = plan.occasions.firstWhere((o) => o.originalDate == '2026-10-26');
    expect(squatTarget(mon26), 102.5);
    expect(plan.occasions.where((o) => o.title != a.name).every((o) => o.prescription.every((e) => e.targetLoadKg == null)), isTrue,
        reason: 'Full body B and C, which also squat, are other workouts and keep no target');
    expect(jsonEncode(await h.bodies(owner, Kinds.workout)), workoutsBefore, reason: 'started and recorded workouts are never rewritten');
    expect(jsonEncode(await h.bodies(owner, Kinds.set)), setsBefore);

    // Starting the next matching session freezes the accepted target.
    final wr2 = WorkoutRepository(h.sync, owner, h.clock);
    await wr2.finish(Workout((await h.bodies(owner, Kinds.workout)).firstWhere((w) => w['id'] == open.id)));
    final next = await wr2.startPlanned(plan, mon26, '2026-10-26');
    expect(next.exercises.firstWhere((e) => e.catalogKey == 'back-squat').targetLoadKg, 102.5);

    // Online with a lost response: every plan edit reaches the account once, each retry byte-identical.
    h.server
      ..offline = false
      ..loseNextResponse = true;
    await h.sync.flush();
    await h.sync.flush();
    final revises = h.server.calls.where((c) => c.method == 'PUT' && c.path == '/plans/${d.planId}').toList();
    expect({for (final c in revises) jsonDecode(c.body)['operationId']}, hasLength(2));
    expect({for (final c in revises) c.body}, hasLength(2), reason: 'a retry resends the same bytes');
    expect(jsonDecode(revises.last.body)['expectedPlanRevision'], isA<int>(), reason: 'revision-checked by the account');
  });

  test('an edit made elsewhere first is a conflict kept for review, never written over', () async {
    final repo = PlanRepository(h.sync, owner);
    final d = PlanDraft.fresh(today: '2026-10-12', path: 'template')..applyTemplate(_templates, 'full-body');
    await repo.createAndActivate(d, today: '2026-10-12');
    await h.sync.flush();
    final plan = await stored(d.planId);
    final a = plan.workouts.first, squat = a.exercises.first;
    h.server.planChangedElsewhere = true;
    await repo.setNextTarget(plan, workoutId: a.id, occurrenceKey: squat.occurrenceKey, loadKg: 90, sets: 3, repsMin: 6, repsMax: 10, workouts: const [], today: '2026-10-12');
    await h.sync.flush();
    final rec = (await h.sync.get(owner, Kinds.plan, d.planId))!;
    expect(rec.syncState, 'conflict');
    expect(Plan(jsonDecode(rec.body) as Json).workouts.first.exercises.first.targetLoadKg, 90, reason: 'this phone\'s choice is kept for the review');
    expect((await h.sync.issueFor(owner, Kinds.plan, d.planId))!.lastError, 'REVISION_CONFLICT');
  });

  test('an increment is kept through restart, sent once, isolated per account, kept for review on a conflict and held from an older server', () async {
    h.server.offline = true;
    final inc = ProgressionRepository(h.sync, owner);
    await inc.setIncrement('bench-press', 2.26796185); // 5 lb
    await h.restart();
    expect(ExerciseIncrement((await h.bodies(owner, Kinds.exerciseIncrement)).single).incrementKg, 2.26796);

    h.server
      ..offline = false
      ..loseNextResponse = true;
    await h.sync.flush();
    await h.sync.flush();
    expect(h.server.callsTo('/exercise-increments').map((c) => c.body).toSet(), hasLength(1));
    expect((h.server.exerciseIncrements['bench-press']!['incrementKg'], h.server.exerciseIncrements['bench-press']!['revision']), (2.26796, 1));

    // Another account on this phone sees none of it; a second phone of the same account gets it from the account.
    final other = await h.signIn('two');
    expect(await h.bodies(other, Kinds.exerciseIncrement), isEmpty);
    final second = Harness(server: h.server);
    addTearDown(second.dispose);
    final there = await second.signIn('one');
    await second.sync.pull();
    expect(ExerciseIncrement((await second.bodies(there, Kinds.exerciseIncrement)).single).incrementKg, 2.26796);

    // That phone changes it; this one, not yet updated, saves another: kept for review beside the account's.
    await ProgressionRepository(second.sync, there).setIncrement('bench-press', 2.5);
    await second.sync.flush();
    final third = Harness(server: h.server);
    addTearDown(third.dispose);
    final mine = await third.signIn('one');
    await ProgressionRepository(third.sync, mine).setIncrement('bench-press', 1);
    await third.sync.flush();
    final rec = (await third.sync.get(mine, Kinds.exerciseIncrement, 'bench-press'))!;
    expect((rec.syncState, ExerciseIncrement(jsonDecode(rec.serverBody!) as Json).incrementKg), ('conflict', 2.5));
    expect(h.server.exerciseIncrements['bench-press']!['incrementKg'], 2.5);

    Cmd command(String kind) => Cmd(seq: 1, operationId: 'x', ownerId: owner, kind: kind, method: 'PUT', path: '/', payload: '{}', targetKind: Kinds.exerciseIncrement, targetId: 'x',
        capturedLocalRevision: 0, dependsOn: '[]', state: 'pending', attempts: 0);
    expect(ProgressionRepository.serverTakes(command('exerciseincrement.put'), {'goals.weekly'}), isFalse, reason: 'an older server is never sent one');
    expect(ProgressionRepository.serverTakes(command('exerciseincrement.put'), null), isFalse, reason: 'unknown yet: it waits');
    expect(ProgressionRepository.serverTakes(command('exerciseincrement.put'), {'exercises.load-increment'}), isTrue);
    expect(ProgressionRepository.serverTakes(command('plan.revise'), {'goals.weekly'}), isTrue, reason: 'targets need nothing new from the server');
    expect(() => inc.setIncrement('bench-press', 0), throwsArgumentError);
  });
}
