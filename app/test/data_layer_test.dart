import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/me/account_repository.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/plans/plan_repository.dart';
import 'package:gohard_rebuild/features/plans/schedule_rules.dart';
import 'package:gohard_rebuild/features/workout/workout_repository.dart';
import 'package:gohard_rebuild/features/workout/workout_runtime.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'support.dart';

CatalogExercise _pushUp() => CatalogExercise({'key': 'push-up', 'name': 'Push-up', 'category': 'Chest', 'equipment': 'Bodyweight', 'isTimed': false});

/// B7, B8, W3, W5, N3, R6 on the REAL Drift database file: durability across restart, immutable retries,
/// dependency order, owner isolation and conflict retention. No in-memory substitute is used.
void main() {
  late Harness h;
  late String owner;
  WorkoutRepository workouts() => WorkoutRepository(h.sync, owner, h.clock);

  setUp(() async {
    h = Harness();
    owner = await h.signIn('one');
  });
  tearDown(() => h.dispose());

  Future<(Workout, String exerciseId)> startOffline() async {
    h.server.offline = true;
    final w = await workouts().startManual('Garage session', [_pushUp()], '2026-10-09');
    return (w, w.exercises.single.id);
  }

  test('restart_retains_work_command_key_and_outbound_bytes', () async {
    final (w, exerciseId) = await startOffline();
    final set = await workouts().recordSet(w, exerciseId, reps: 8, loadKg: 60);
    await h.sync.flush(); // offline: the start is attempted and fails; nothing is lost
    final before = await h.sync.commands(owner);
    expect(before.map((c) => c.kind), ['workout.start', 'set.create']);
    expect(before.first.outbound, isNotNull, reason: 'outbound payload is persisted before the first dispatch');

    await h.restart();

    final after = await h.sync.commands(owner);
    expect(after.map((c) => c.operationId), before.map((c) => c.operationId));
    expect(after.first.outbound, before.first.outbound);
    expect((await h.bodies(owner, Kinds.set, parentId: w.id)).single['id'], set.id);
    expect((await h.sync.get(owner, Kinds.workout, w.id))!.syncState, 'pending');

    h.server.offline = false;
    await h.sync.flush();
    expect(h.server.sets.keys, [set.id]);
    expect((await h.sync.get(owner, Kinds.set, set.id))!.syncState, 'synced');
    // Every retry of the start sent byte-identical bodies under one operation ID.
    expect(h.server.callsTo('/workouts').map((c) => c.body).toSet(), hasLength(1));
  });

  test('lost_set_ack_does_not_duplicate', () async {
    final w = await workouts().startManual('Session', [_pushUp()], '2026-10-09');
    await h.sync.flush();
    h.server.loseNextResponse = true; // the server commits, the response never arrives
    await workouts().recordSet(w, w.exercises.single.id, reps: 5, loadKg: 100);
    await h.sync.flush();
    expect(h.server.sets, hasLength(1));

    await h.restart();
    await h.sync.flush();

    final setCalls = h.server.callsTo('/sets');
    expect(setCalls.length, greaterThanOrEqualTo(2), reason: "the lost response forced a retry");
    expect(setCalls.map((c) => c.body).toSet(), hasLength(1), reason: "every retry is byte-identical");
    expect(h.server.sets, hasLength(1));
    expect(await h.bodies(owner, Kinds.set, parentId: w.id), hasLength(1));
    expect(await h.sync.commands(owner), isEmpty);
  });

  test('offline_finish_waits_for_actual_sets', () async {
    final (w, exerciseId) = await startOffline();
    await workouts().recordSet(w, exerciseId, reps: 8, loadKg: 60);
    await workouts().recordSet(w, exerciseId, reps: 7, loadKg: 60);
    final result = await workouts().finish(Workout(jsonDecode((await h.sync.get(owner, Kinds.workout, w.id))!.body) as Json));
    expect((result.outcome, result.performedSets), ('manual_recorded', 2));
    await h.sync.flush();
    expect(h.server.callsTo('/finish'), isEmpty, reason: 'a finish never runs ahead of its sets');
    // The result is visible locally straight away, before any account acknowledgement.
    expect((await h.bodies(owner, Kinds.workout)).single['outcome'], 'manual_recorded');

    await h.restart();
    h.server.offline = false;
    await h.sync.flush();

    expect(h.server.calls.map((c) => c.path.split('/').last).toList(), containsAllInOrder(['workouts', 'sets', 'sets', 'finish']));
    final finish = jsonDecode(h.server.callsTo('/finish').single.body) as Json;
    expect((finish['acknowledgedSets'] as List).map((s) => (s as Json)['revision']), [1, 1]);
    expect(finish['expectedRevision'], 1);
    expect(h.server.workouts[w.id]!['performedSets'], 2);
    expect(await h.sync.commands(owner), isEmpty);
  });

  test('older_ack_keeps_newer_local_change', () async {
    final w = await workouts().startManual('Session', [_pushUp()], '2026-10-09');
    final set = await workouts().recordSet(w, w.exercises.single.id, reps: 8, loadKg: 60);
    await h.sync.flush();
    h.server.hold = Completer(); // the first edit is in flight …
    await workouts().updateSet(set, reps: 9, loadKg: 60);
    final inFlight = h.sync.flush();
    await pumpEventQueue();
    final current = WorkoutSet((await h.bodies(owner, Kinds.set)).single);
    await workouts().updateSet(current, reps: 10, loadKg: 62.5); // … when the user edits again
    h.server.hold!.complete();
    h.server.hold = null;
    await inFlight;

    // The acknowledgement of the older edit advanced the revision but did not overwrite the newer values.
    var rec = (await h.sync.get(owner, Kinds.set, set.id))!;
    final local = WorkoutSet(jsonDecode(rec.body) as Json);
    expect((local.reps, local.loadKg), (10, 62.5));
    await h.sync.flush();
    rec = (await h.sync.get(owner, Kinds.set, set.id))!;
    expect((rec.syncState, rec.revision, h.server.sets[set.id]!['reps'], h.server.sets[set.id]!['loadKg']), ('synced', 3, 10, 62.5));
  });

  test('account_switch_rejects_ack_and_keeps_each_owners_work_private', () async {
    final w = await workouts().startManual('Owner one session', [_pushUp()], '2026-10-09');
    h.server.hold = Completer();
    final inFlight = h.sync.flush();
    await pumpEventQueue();
    // Sign out and a different account signs in while owner one's request is still in flight.
    await h.sessions.signOut();
    final two = await h.signIn('two');
    h.server.hold!.complete();
    h.server.hold = null;
    await inFlight;

    // The late acknowledgement was published nowhere: owner one's command is still pending for owner one …
    expect((await h.sync.commands(owner)).single.state, 'pending');
    expect((await h.sync.get(owner, Kinds.workout, w.id))!.syncState, 'pending');
    // … and owner two sees and sends none of it.
    expect(await h.sync.list(two, Kinds.workout), isEmpty);
    expect(await h.sync.commands(two), isEmpty);
    final callsBefore = h.server.calls.length;
    await h.sync.flush();
    expect(h.server.calls.length, callsBefore, reason: 'another owner\'s queue is never dispatched');
    expect(await h.sync.pull(), isTrue);
    expect(await h.sync.list(two, Kinds.workout), hasLength(1), reason: 'the fake authority returns its only workout to whoever asks');

    // Owner one signs back in: their retained queue resumes under the same operation ID, with no duplicate.
    await h.sessions.signOut();
    await h.signIn('one');
    await h.sync.flush();
    expect(await h.sync.commands(owner), isEmpty);
    expect(h.server.workouts, hasLength(1));
    expect(h.server.callsTo('/workouts').where((c) => c.method == 'POST').map((c) => c.bearer).toSet(), {'access-one'});
  });

  test('late pull for a previous owner is dropped', () async {
    h.server.workouts['w'] = {'id': 'w', 'dayKey': '2026-10-09', 'revision': 1, 'exercises': []};
    h.server.hold = Completer();
    final pull = h.sync.pull();
    await pumpEventQueue();
    await h.sessions.signOut();
    final two = await h.signIn('two');
    h.server.hold!.complete();
    h.server.hold = null;
    expect(await pull, isFalse);
    expect(await h.sync.list(owner, Kinds.workout), isEmpty);
    expect(await h.sync.list(two, Kinds.workout), isEmpty);
  });

  test('two_device_set_conflict_retains_both_and_resolution_never_adds_a_set', () async {
    final w = await workouts().startManual('Session', [_pushUp()], '2026-10-09');
    final set = await workouts().recordSet(w, w.exercises.single.id, reps: 8, loadKg: 140);
    await h.sync.flush();
    h.server.sets[set.id]!.addAll({'reps': 6, 'loadKg': 150, 'revision': 2}); // another device changed it
    await workouts().updateSet(set, reps: 9, loadKg: 140);
    await h.sync.flush();

    var rec = (await h.sync.get(owner, Kinds.set, set.id))!;
    expect(rec.syncState, 'conflict');
    expect(WorkoutSet(jsonDecode(rec.body) as Json).reps, 9, reason: 'local version kept');
    expect(WorkoutSet(jsonDecode(rec.serverBody!) as Json).reps, 6, reason: 'account version held beside it');
    final conflict = (await h.sync.issueFor(owner, Kinds.set, set.id))!;
    expect(conflict.lastError, 'REVISION_CONFLICT');

    // A finish made while the set is unresolved is blocked rather than racing ahead.
    await workouts().finish(Workout((await h.bodies(owner, Kinds.workout)).single));
    await h.sync.flush();
    expect(h.server.callsTo('/finish'), isEmpty);

    await workouts().keepLocalSet(conflict.operationId, WorkoutSet(jsonDecode(rec.body) as Json));
    await h.sync.flush();
    rec = (await h.sync.get(owner, Kinds.set, set.id))!;
    expect((rec.syncState, h.server.sets[set.id]!['reps'], h.server.sets.length), ('synced', 9, 1));
    expect(WorkoutSet(jsonDecode(rec.alternativeBody!) as Json).reps, 6, reason: 'the alternative is retained');
    expect(await h.bodies(owner, Kinds.set), hasLength(1));
    expect(h.server.callsTo('/finish'), hasLength(1), reason: 'the dependent finish follows the replacement command');
    expect(h.server.workouts[w.id]!['performedSets'], 1);
  });

  test('choosing the account version retains the local one and adds nothing', () async {
    final food = FoodRepository(h.sync, owner);
    await food.save(FoodDraft(dayKey: '2026-10-09', meal: 'Lunch', name: 'Rice bowl', amount: '1 bowl', calories: 400));
    await h.sync.flush();
    final entry = FoodEntry((await h.bodies(owner, Kinds.food)).single);
    h.server.food[entry.id]!.addAll({'name': 'Rice bowl (other phone)', 'revision': 2});
    await food.save(FoodDraft.edit(entry)..name = 'Rice bowl (this phone)');
    await h.sync.flush();
    final conflict = (await h.sync.issueFor(owner, Kinds.food, entry.id))!;

    await h.sync.resolveUseServer(owner, conflict.operationId);

    final rec = (await h.sync.get(owner, Kinds.food, entry.id))!;
    expect((rec.syncState, FoodEntry(jsonDecode(rec.body) as Json).name), ('synced', 'Rice bowl (other phone)'));
    expect(FoodEntry(jsonDecode(rec.alternativeBody!) as Json).name, 'Rice bowl (this phone)');
    expect(await h.bodies(owner, Kinds.food), hasLength(1));
    expect(await h.sync.commands(owner), isEmpty);
  });

  test('food: blank stays null, zero stays zero, restart keeps the entry and its key, removal retries once', () async {
    final food = FoodRepository(h.sync, owner);
    h.server.offline = true;
    final receipt = await food.save(FoodDraft(dayKey: '2026-10-09', meal: 'Breakfast', name: ' Greek yogurt ', amount: '200 g', calories: 0, carbs: 9.5));
    await h.restart();
    expect((await h.sync.commands(owner)).single.operationId, receipt.operationId);
    var entry = FoodEntry((await h.bodies(owner, Kinds.food)).single);
    expect((entry.name, entry.calories, entry.protein, entry.carbs, entry.fat), ('Greek yogurt', 0, null, 9.5, null));

    h.server.offline = false;
    await h.sync.flush();
    final sent = (jsonDecode(h.server.callsTo('/food-entries').first.body) as Json)['macros'] as Json;
    expect(sent, {'calories': 0, 'protein': null, 'carbs': 9.5, 'fat': null});

    h.server.loseNextResponse = true;
    entry = FoodEntry((await h.bodies(owner, Kinds.food)).single);
    await FoodRepository(h.sync, owner).remove(entry);
    await h.sync.flush();
    await h.sync.flush();
    expect(h.server.food.values.single['isDeleted'], isTrue);
    expect(h.server.food, hasLength(1));
    expect(h.server.callsTo('/delete').map((c) => c.body).toSet(), hasLength(1));
    expect(() => FoodRepository.validate(FoodDraft(dayKey: '2026-10-09', name: 'x', amount: '1', protein: -1)), throwsA(isA<InvalidFood>()));
    expect(() => FoodRepository.validate(FoodDraft(dayKey: '2026-10-09', name: ' ', amount: '1')), throwsA(isA<InvalidFood>()));
  });

  test('local persistence failure reports not-saved and creates nothing', () async {
    final w = await workouts().startManual('Session', [_pushUp()], '2026-10-09');
    await h.db.close(); // storage is gone
    await expectLater(workouts().recordSet(w, w.exercises.single.id, reps: 8, loadKg: 60), throwsA(isA<LocalSaveFailure>()));
    await h.restart();
    expect(await h.bodies(owner, Kinds.set), isEmpty);
    expect((await h.sync.commands(owner)).map((c) => c.kind), ['workout.start']);
    expect(() => workouts().recordSet(w, w.exercises.single.id, reps: 0, loadKg: 60), throwsA(isA<InvalidSet>()));
    expect(() => workouts().recordSet(w, w.exercises.single.id, reps: 5, loadKg: -1), throwsA(isA<InvalidSet>()));
  });

  test('opening_second_workout_preserves_first', () async {
    final repo = workouts();
    final first = await repo.startManual('First', [_pushUp()], '2026-10-09');
    await repo.recordSet(first, first.exercises.single.id, reps: 8, loadKg: 60);
    final decision = await repo.requestForeground(null);
    expect((decision as ForegroundBusy).current.id, first.id);

    await repo.park(first.id); // the explicit choice
    expect(await repo.requestForeground(null), isA<ForegroundReady>());
    final second = await repo.startManual('Second', [_pushUp()], '2026-10-09');

    final all = [for (final b in await h.bodies(owner, Kinds.workout)) Workout(b)];
    expect(all.where((w) => w.isOpen), hasLength(2), reason: 'nothing was auto-completed');
    expect(await h.bodies(owner, Kinds.set, parentId: first.id), hasLength(1));
    expect((await repo.foreground())!.id, second.id);
    expect((await repo.runtime(first.id))!.isParked, isTrue);
  });

  test('restart_after_rest_deadline_does_not_log_or_advance', () async {
    final repo = workouts();
    final w = await repo.startManual('Session', [_pushUp(), _pushUp()], '2026-10-09');
    final first = w.exercises.first.id;
    h.clock.advance(const Duration(seconds: 90));
    await repo.recordSet(w, first, reps: 8, loadKg: 60);
    var rt = (await repo.runtime(w.id))!.withRest(h.clock.now, 30, first).withDraft(first, EntryDraft.of(load: '140', reps: '8', unit: 'lb'));
    await repo.saveRuntime(w.id, rt);
    expect(rt.restRemainingSeconds(h.clock.now), 30);

    await h.restart(); // process death
    h.clock.advance(const Duration(seconds: 60));

    rt = (await workouts().runtime(w.id))!;
    expect(rt.restRemainingSeconds(h.clock.now), 0, reason: 'the rest ended while the app was closed, and stays ended');
    expect(rt.elapsedSeconds(h.clock.now), 150, reason: 'backgrounding does not pause the workout');
    expect(rt.selectedExerciseId, first, reason: 'no exercise change happened by itself');
    expect(await h.bodies(owner, Kinds.set, parentId: w.id), hasLength(1), reason: 'no set was logged by itself');
    expect((rt.draftFor(first).rawLoad, rt.draftFor(first).rawReps, rt.draftFor(first).unit), ('140', '8', 'lb'));
  });

  test('pause_excludes_closed_interval_and_clock_changes_are_clamped', () {
    final t0 = DateTime.utc(2026, 10, 9, 23, 58);
    var rt = WorkoutRuntime.started(t0).withRest(t0.add(const Duration(seconds: 60)), 90, 'e');
    rt = rt.paused(t0.add(const Duration(seconds: 90))); // 90 s active, 60 s of rest left
    expect((rt.elapsedSeconds(t0.add(const Duration(hours: 5))), rt.restRemainingSeconds(t0.add(const Duration(hours: 5)))), (90, 60));
    rt = rt.resumed(t0.add(const Duration(hours: 5)));
    expect(rt.elapsedSeconds(t0.add(const Duration(hours: 5, seconds: 10))), 100);
    expect(rt.restRemainingSeconds(t0.add(const Duration(hours: 5, seconds: 10))), 50);
    expect(rt.restExtended(t0.add(const Duration(hours: 5, seconds: 10)), 30).restRemainingSeconds(t0.add(const Duration(hours: 5, seconds: 10))), 80);
    // The wall clock jumps backwards (manual change, DST): elapsed never goes negative or shrinks below the saved total.
    expect(rt.elapsedSeconds(t0), 90);
    expect(rt.withoutRest().restRemainingSeconds(t0), isNull);
    expect(rt.paused(t0.add(const Duration(hours: 6)), park: true).isParked, isTrue);
  });

  group('plans', () {
    Json planBody(String id, {String lifecycle = 'draft', String start = '2026-10-09'}) => {
          'id': id, 'title': 'Plan $id', 'lifecycle': lifecycle, 'isArchived': false, 'startDate': start, 'blockWeeks': 1, 'minRecoveryDays': 1, 'revision': 1,
          'setup': {'sessionsPerWeek': 3, 'weekdays': [1, 3, 5]},
          'occasions': [
            for (final (i, d) in ['2026-10-09', '2026-10-12', '2026-10-14'].indexed)
              {'id': '$id-o${i + 1}', 'weekNumber': 1, 'ordinal': i + 1, 'title': 'Workout ${i + 1}', 'originalDate': d, 'scheduledDate': d, 'isSkipped': false, 'resultOutcome': null, 'prescription': []},
          ],
        };

    Future<void> seed(List<Json> plans, {String? primary}) => h.db.transaction(() async {
          for (final p in plans) {
            await h.db.into(h.db.records).insert(RecordsCompanion.insert(ownerId: owner, kind: Kinds.plan, id: p['id'] as String, body: jsonEncode(p), revision: const Value(1)));
          }
          await h.db.into(h.db.records).insert(RecordsCompanion.insert(ownerId: owner, kind: Kinds.context, id: owner, body: jsonEncode({'contextRevision': 1, 'primaryPlanId': primary}), revision: const Value(1)));
        });

    Future<Plan> plan(String id) async => Plan(jsonDecode((await h.sync.get(owner, Kinds.plan, id))!.body) as Json);

    test('restart_retains_primary_and_command_key, and the open workout is untouched', () async {
      await seed([planBody('old', lifecycle: 'active'), planBody('new', start: '2026-10-23')], primary: 'old');
      final repo = PlanRepository(h.sync, owner);
      h.server.offline = true;
      final open = await workouts().startPlanned(await plan('old'), (await plan('old')).occasions.first, '2026-10-09');
      await workouts().recordSet(open, SyncEngine.newId(), reps: 5, loadKg: 100);
      final setsBefore = await h.bodies(owner, Kinds.set);

      await expectLater(repo.activate(await plan('new'), today: '2026-10-10'), throwsA(isA<ScheduleRefused>()), reason: 'replacing a primary must be explicit');
      final receipt = await repo.activate(await plan('new'), today: '2026-10-10', replacePrimaryId: 'old');
      await h.restart();

      expect(TrainingCtx((await h.bodies(owner, Kinds.context)).single).primaryPlanId, 'new');
      expect(((await plan('old')).lifecycle, (await plan('old')).pausedOn, (await plan('new')).lifecycle), ('paused', '2026-10-10', 'active'));
      final cmd = (await h.sync.commands(owner)).last;
      expect((cmd.operationId, cmd.kind, cmd.targetKind), (receipt.operationId, 'plan.activate', Kinds.context));
      final payload = jsonDecode(cmd.payload) as Json;
      expect((payload['replacePrimaryId'], payload['startDate'], (payload['reviewedDates'] as List).length), ('old', '2026-10-23', 3));
      expect(await h.bodies(owner, Kinds.set), setsBefore);
      final stillOpen = Workout((await h.bodies(owner, Kinds.workout)).single);
      expect((stillOpen.isOpen, stillOpen.planId, stillOpen.occasionId), (true, 'old', 'old-o1'));
    });

    test('move keeps identity, refuses collisions and open occasions; skip and resume are reviewed', () async {
      await seed([planBody('p', lifecycle: 'active')], primary: 'p');
      h.server.offline = true;
      final repo = PlanRepository(h.sync, owner);
      var p = await plan('p');
      final open = await workouts().startPlanned(p, p.occasions.first, '2026-10-09');
      List<ScheduleOccasion> schedule(Plan p) => scheduleOf(p, [open]);

      expect(() => repo.move(p, schedule(p), 'p-o1', '2026-10-20'), throwsA(isA<ScheduleRefused>()), reason: 'an occasion with an open workout cannot move');
      expect(() => repo.move(p, schedule(p), 'p-o2', '2026-10-13'), throwsA(isA<ScheduleRefused>()), reason: 'no recovery day before the next workout');
      await repo.move(p, schedule(p), 'p-o3', '2026-10-17');
      p = await plan('p');
      final moved = p.occasions.firstWhere((o) => o.id == 'p-o3');
      expect((p.occasions.length, moved.originalDate, moved.scheduledDate, moved.weekNumber, moved.wasMoved), (3, '2026-10-14', '2026-10-17', 1, true));

      await repo.skip(p, schedule(p), 'p-o2');
      p = await plan('p');
      expect(p.occasions.firstWhere((o) => o.id == 'p-o2').isSkipped, isTrue);
      expect(await h.bodies(owner, Kinds.set), isEmpty, reason: 'a skip creates no performed work');

      await repo.pause(p, today: '2026-10-13');
      p = await plan('p');
      final changes = PlanRepository.resumeChanges(p, schedule(p), '2026-10-24');
      expect(changes.map((c) => (c.occasionId, c.from, c.to)), [('p-o3', '2026-10-17', '2026-10-24')], reason: 'only pending occasions shift; open and skipped keep their dates');
      await repo.resume(p, schedule(p), changes, today: '2026-10-20');
      p = await plan('p');
      expect((p.lifecycle, p.occasions.firstWhere((o) => o.id == 'p-o1').scheduledDate, p.occasions.firstWhere((o) => o.id == 'p-o2').scheduledDate), ('active', '2026-10-09', '2026-10-12'));

      await repo.close(p, intent: 'stopped_early', today: '2026-10-21');
      expect(TrainingCtx((await h.bodies(owner, Kinds.context)).single).primaryPlanId, isNull);
      expect(Workout((await h.bodies(owner, Kinds.workout)).single).isOpen, isTrue, reason: 'closing a block never finishes its open workout');
      expect((await h.sync.commands(owner)).map((c) => c.kind), ['workout.start', 'plan.schedule', 'plan.schedule', 'plan.pause', 'plan.resume', 'plan.close']);
    });

    test('primary_conflict_retains_both_plans', () async {
      await seed([planBody('mine')]);
      h.server.offline = true;
      await PlanRepository(h.sync, owner).activate(await plan('mine'), today: '2026-10-09');
      h.server.offline = false;
      // Another device made a different plan primary first: the account answers with a conflict and its state.
      final theirs = planBody('theirs', lifecycle: 'active')..['revision'] = 2;
      final cmd = (await h.sync.commands(owner)).single;
      h.server.operations[cmd.operationId] = (jsonEncode(await _resolved(h, owner, cmd)), ApiResponse(409, {
        'operationId': cmd.operationId, 'status': 'conflict', 'revision': 2, 'code': 'REVISION_CONFLICT',
        'data': {'contextRevision': 2, 'primaryPlanId': 'theirs', 'plans': [theirs, planBody('mine')]},
      }));
      await h.sync.flush();

      final ctx = (await h.sync.get(owner, Kinds.context, owner))!;
      expect(ctx.syncState, 'conflict');
      expect(TrainingCtx(jsonDecode(ctx.body) as Json).primaryPlanId, 'mine', reason: 'local decision kept for review');
      expect(TrainingCtx(jsonDecode(ctx.serverBody!) as Json).primaryPlanId, 'theirs');

      await h.sync.resolveUseServer(owner, cmd.operationId);
      final after = (await h.sync.get(owner, Kinds.context, owner))!;
      expect((after.syncState, TrainingCtx(jsonDecode(after.body) as Json).primaryPlanId), ('synced', 'theirs'));
      expect(TrainingCtx(jsonDecode(after.alternativeBody!) as Json).primaryPlanId, 'mine');
      expect(((await plan('mine')).lifecycle, (await plan('theirs')).lifecycle), ('draft', 'active'), reason: 'both plans still exist');
      expect(Plan(jsonDecode((await h.sync.get(owner, Kinds.plan, 'mine'))!.alternativeBody!) as Json).lifecycle, 'active');
    });

    test('draft request retries reuse the same operation and plan IDs; changed answers do not', () async {
      final repo = PlanRepository(h.sync, owner);
      final setup = {'direction': 'strength', 'startDate': '2026-10-09'};
      h.server.offline = true;
      expect((await repo.createDraft(setup)).unreachable, isTrue);
      expect((await repo.savedSetup())!['setup'], setup, reason: 'answers are retained');
      expect((await repo.createDraft(setup)).unreachable, isTrue);
      final firstTry = h.server.callsTo('/plan-drafts');
      expect(firstTry.map((c) => c.body).toSet(), hasLength(1));

      h.server.offline = false;
      expect((await repo.createDraft({...setup, 'direction': 'muscle'})).accepted, isTrue);
      final sent = h.server.callsTo('/plan-drafts').last;
      expect(sent.body, isNot(firstTry.first.body));
      expect(await h.sync.commands(owner), isEmpty, reason: 'the superseded request can never land later');
    });
  });

  test('profile: a save belongs to the owner it was started for', () async {
    await h.db.into(h.db.records).insert(RecordsCompanion.insert(ownerId: owner, kind: Kinds.profile, id: owner, body: jsonEncode(authFor('one')['profile']), revision: const Value(1)));
    final repoOne = ProfileRepository(h.sync, owner);
    await h.sessions.signOut();
    final two = await h.signIn('two');
    await h.db.into(h.db.records).insert(RecordsCompanion.insert(ownerId: two, kind: Kinds.profile, id: two, body: jsonEncode(authFor('two')['profile']), revision: const Value(1)));

    // late_name_save_does_not_change_new_account
    await repoOne.update(Profile(authFor('one')['profile'] as Json), displayName: 'Renamed late');
    await h.sync.flush();

    expect(Profile((await h.bodies(two, Kinds.profile)).single).displayName, 'two');
    expect(Profile((await h.bodies(owner, Kinds.profile)).single).displayName, 'Renamed late');
    expect(h.server.callsTo('/me'), isEmpty, reason: 'owner one\'s change waits for owner one');
  });

  test('schema upgrade v1 to v3 keeps records and pending commands byte for byte, and adds the empty route table', () async {
    final store = TestStore();
    final raw = sql.sqlite3.open(store.file.path);
    raw.execute('''
      CREATE TABLE records (owner_id TEXT NOT NULL, kind TEXT NOT NULL, id TEXT NOT NULL, parent_id TEXT, day_key TEXT, body TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 0, local_revision INTEGER NOT NULL DEFAULT 0, sync_state TEXT NOT NULL DEFAULT 'synced', server_body TEXT,
        PRIMARY KEY (owner_id, kind, id));
      CREATE TABLE commands (seq INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, operation_id TEXT NOT NULL UNIQUE, owner_id TEXT NOT NULL, kind TEXT NOT NULL,
        method TEXT NOT NULL, path TEXT NOT NULL, payload TEXT NOT NULL, outbound TEXT, target_kind TEXT NOT NULL, target_id TEXT NOT NULL,
        captured_local_revision INTEGER NOT NULL, depends_on TEXT NOT NULL DEFAULT '[]', state TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT);
      INSERT INTO records (owner_id, kind, id, day_key, body, local_revision, sync_state) VALUES ('one', 'food', 'f1', '2026-10-09', '{"id":"f1","macros":{"calories":0,"protein":null}}', 1, 'pending');
      INSERT INTO commands (operation_id, owner_id, kind, method, path, payload, outbound, target_kind, target_id, captured_local_revision)
        VALUES ('op-1', 'one', 'food.create', 'POST', '/food-entries', '{"entryId":"f1","operationId":"op-1"}', '{"entryId":"f1","operationId":"op-1"}', 'food', 'f1', 1);
      PRAGMA user_version = 1;
    ''');
    raw.close();

    final db = AppDb(NativeDatabase(store.file));
    final cmd = await db.select(db.commands).getSingle();
    final rec = await db.select(db.records).getSingle();
    expect((cmd.operationId, cmd.state, cmd.outbound, cmd.ack), ('op-1', 'pending', '{"entryId":"f1","operationId":"op-1"}', null));
    expect((rec.syncState, rec.alternativeBody), ('pending', null));
    final entry = FoodEntry(jsonDecode(rec.body) as Json);
    expect((entry.calories, entry.protein), (0, null), reason: 'unknown stays unknown through the upgrade');
    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.single, 3);
    expect(await db.select(db.trackEntries).get(), isEmpty, reason: 'v3 adds the Run / Walk route table, empty');
    await db.close();
    store.dispose();
  });
}

/// The exact outbound body the engine will send for a command (resolving it the way dispatch does).
Future<Json> _resolved(Harness h, String owner, Cmd cmd) async {
  h.server.offline = true;
  await h.sync.flush();
  h.server.offline = false;
  return jsonDecode((await h.sync.command(cmd.operationId))!.outbound!) as Json;
}

