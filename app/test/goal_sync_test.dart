import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/progress/goal_repository.dart';
import 'package:gohard_rebuild/features/progress/weekly.dart';

import 'support.dart';

/// Weekly goals on the REAL Drift database file and the fake account authority: offline through restart, a lost
/// response, the effective week after a late sync, a second phone converging, a stale edit kept for review, and the
/// older-server gate.
void main() {
  late Harness h;
  late String owner;
  GoalRepository goals([Harness? on, String? who]) => GoalRepository((on ?? h).sync, who ?? owner);
  Future<List<WeeklyGoal>> rows([Harness? on, String? who]) async => [for (final b in await (on ?? h).bodies(who ?? owner, Kinds.weeklyGoal)) WeeklyGoal(b)];

  setUp(() async {
    h = Harness();
    owner = await h.signIn('one');
  });
  tearDown(() => h.dispose());

  test('saved offline on Sunday: survives restart, keeps its week after a late sync, is sent once, converges on a second phone', () async {
    h.server.offline = true;
    final receipt = await goals().set('2026-10-05', workouts: 3, runWalk: null);
    await h.sync.flush();
    await h.restart();
    expect((await h.sync.commands(owner)).single.operationId, receipt.operationId);
    expect((await rows()).single.workoutsTarget, 3);

    // Online again in the next week: the goal still belongs to the week it was made in.
    h.clock.advance(const Duration(days: 2));
    h.server
      ..offline = false
      ..loseNextResponse = true;
    await h.sync.flush();
    await h.sync.flush();
    expect(h.server.weeklyGoals.keys, ['2026-10-05']);
    expect((h.server.weeklyGoals['2026-10-05']!['workoutsTarget'], h.server.weeklyGoals['2026-10-05']!['revision']), (3, 1));
    expect(h.server.callsTo('/weekly-goals').map((c) => c.body).toSet(), hasLength(1), reason: 'every retry is byte-identical');
    expect((await h.sync.get(owner, Kinds.weeklyGoal, '2026-10-05'))!.syncState, 'synced');

    // Another phone signed in to the same account: nothing to upload (no defaults), then the account's goals.
    final second = Harness(server: h.server);
    addTearDown(second.dispose);
    final there = await second.signIn('one');
    expect(await second.sync.commands(there), isEmpty);
    expect(await second.sync.pull(), isTrue);
    expect((await rows(second, there)).single.workoutsTarget, 3);

    // The second phone changes it in the next week: week A keeps 3, week B has 4.
    await goals(second, there).set('2026-10-12', workouts: 4, runWalk: 2);
    await second.sync.flush();
    await h.sync.pull();
    final all = await rows();
    expect(goalFor('2026-10-05', all)!.workoutsTarget, 3);
    expect((goalFor('2026-10-12', all)!.workoutsTarget, goalFor('2026-10-19', all)!.runWalkTarget), (4, 2));
  });

  test('a stale edit of the same week is kept for review, never silently written over the other phone\'s choice', () async {
    final second = Harness(server: h.server);
    addTearDown(second.dispose);
    final there = await second.signIn('one');
    await goals(second, there).set('2026-10-05', workouts: 5, runWalk: null);
    await second.sync.flush();

    // This phone never pulled that record: its save expects to create the week, and the account says it exists.
    await goals().set('2026-10-05', workouts: 2, runWalk: 1);
    await h.sync.flush();
    final rec = await h.sync.get(owner, Kinds.weeklyGoal, '2026-10-05');
    expect(rec!.syncState, 'conflict');
    expect(WeeklyGoal(jsonDecode(rec.body) as Json).workoutsTarget, 2, reason: 'this phone\'s choice is kept');
    expect(WeeklyGoal(jsonDecode(rec.serverBody!) as Json).workoutsTarget, 5, reason: 'the account\'s choice is held beside it');
    expect(h.server.weeklyGoals['2026-10-05']!['workoutsTarget'], 5);

    // Keeping this phone's version is an explicit choice: one new command against the account's revision.
    final cmd = (await h.sync.issueFor(owner, Kinds.weeklyGoal, '2026-10-05'))!;
    await goals().keepLocal(cmd.operationId, WeeklyGoal(jsonDecode(rec.body) as Json));
    await h.sync.flush();
    expect((h.server.weeklyGoals['2026-10-05']!['workoutsTarget'], h.server.weeklyGoals['2026-10-05']!['runWalkTarget'], h.server.weeklyGoals['2026-10-05']!['revision']), (2, 1, 2));
  });

  test('clearing is sent as explicit nulls; a server without weekly goals is never sent one', () async {
    await goals().set('2026-10-05', workouts: 3, runWalk: 2);
    await goals().set('2026-10-12', workouts: null, runWalk: null);
    await h.sync.flush();
    expect(jsonDecode(h.server.callsTo('/weekly-goals/2026-10-12').single.body), containsPair('workoutsTarget', null));
    expect(h.server.weeklyGoals['2026-10-12']!['runWalkTarget'], isNull);
    expect(goalFor('2026-10-19', await rows())!.isEmpty, isTrue, reason: 'cleared from week B on; week A\'s 3 does not come back');

    Cmd command(String kind) => Cmd(seq: 1, operationId: 'x', ownerId: owner, kind: kind, method: 'PUT', path: '/', payload: '{}', targetKind: Kinds.weeklyGoal, targetId: 'x',
        capturedLocalRevision: 0, dependsOn: '[]', state: 'pending', attempts: 0);
    expect(GoalRepository.serverTakes(command('weeklygoal.put'), {'runs.routes'}), isFalse, reason: 'an older server');
    expect(GoalRepository.serverTakes(command('weeklygoal.put'), null), isFalse, reason: 'not known yet: it waits');
    expect(GoalRepository.serverTakes(command('weeklygoal.put'), {'goals.weekly'}), isTrue);
    expect(GoalRepository.serverTakes(command('water.create'), {'runs.routes'}), isTrue, reason: 'nothing else is held');
    expect(() => goals().set('2026-10-19', workouts: 0, runWalk: null), throwsArgumentError);
  });
}
