import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/plans/plan_draft.dart';
import 'package:gohard_rebuild/features/plans/plan_projection.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support.dart';

/// Next targets (docs/PROGRESSION.md) on a real install against the local API, in two runs of this file by
/// scripts\test-android.ps1 -Only journey_progression_test (not in the default run).
///
/// Phase 1: a new account. SEEDED in the app, through its own repositories (clearly test data): an ongoing rotation
/// with one workout, "Upper body A" (bench press, 80 kg target, 3 × 6–8), and two complete sessions of 3 × 8 at 80 kg.
/// In the app: the next session's preview offers "Choose your weight increment"; 2.5 kg is chosen; the suggestion
/// 80 → 82.5 kg is reviewed and kept as it is (nothing saved); the workout is started, an entry typed, and the next
/// target accepted from the recorder with Wi-Fi and data off; three sets are recorded and the workout finished offline.
/// Phase 2 is a new process: the accepted target survived and reaches the account once; the finished workouts keep
/// 80 kg; starting the next matching session freezes 82.5 kg.
const _phase = String.fromEnvironment('GOHARD_PHASE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('progression phase $_phase', (tester) async {
    final j = Journey(tester, binding);
    final today = dayKeyOf(DateTime.now());
    final account = File('${(await getApplicationDocumentsDirectory()).path}/progression-journey-account.txt');
    ProviderContainer scope() => ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    TextEditingController field(String key) => tester.widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField))).controller!;
    Plan plan() => scope().read(planListProvider).single;
    double? planTarget() => plan().workouts.single.exercises.single.targetLoadKg;
    Occasion next() => planOccasions(plan(), today, scope().read(workoutListProvider)).firstWhere((o) => !o.isSkipped && occasionOutcome(o, scope().read(workoutListProvider)) == null);
    Future<void> openNext() async {
      scope().read(shellProvider.notifier).openWorkout(WorkoutFocus.preview(plan().id, next().id));
      await j.tapKey('nav-train');
      await j.waitFor(find.byKey(const Key('workout-preview')), what: 'the next session\'s preview');
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
      await j.settle(4);
    }

    if (_phase == '1') {
      await j.start('Progression Journey');
      await account.writeAsString(j.email);

      // --- SEEDED: the plan and two complete earlier sessions, through the app's own repositories.
      final c = scope();
      final planId = SyncEngine.newId(), workoutId = SyncEngine.newId();
      await c.read(planRepositoryProvider).createAndActivate(PlanDraft({
        'version': 1, 'mode': 'new', 'planId': planId, 'path': 'custom', 'step': 3, 'templateId': 'custom', 'title': 'Seeded upper plan',
        'preferences': {'days': <int>[], 'equipment': 'full_gym', 'timeBudgetMinutes': null, 'experience': null},
        'workouts': [
          {'id': workoutId, 'name': 'Upper body A', 'notes': null, 'exercises': [
            {'occurrenceKey': 'e1', 'catalogKey': 'bench-press', 'name': 'Bench press', 'isTimed': false, 'targetSets': 3, 'targetRepsMin': 6, 'targetRepsMax': 8,
              'targetDurationSeconds': null, 'restSeconds': 60, 'targetLoadKg': 80.0},
          ]},
        ],
        'schedule': {'mode': 'rotating', 'pattern': <Json>[], 'cycle': [workoutId], 'trainingDays': <int>[], 'cycleAnchor': 0},
        'startDate': today, 'durationWeeks': null, 'timeBudgetMinutes': null, 'effectiveDate': null,
      }), today: today);
      await watch(800);
      final wr = c.read(workoutRepositoryProvider);
      for (var session = 0; session < 2; session++) {
        final w = await wr.startPlanned(plan(), next(), today);
        for (var i = 0; i < 3; i++) {
          await wr.recordSet(w, w.exercises.single.id, loadKg: 80, reps: 8);
        }
        await wr.finish(w);
        await watch(800);
      }
      await c.read(syncProvider).flush();
      debugPrint('GOHARD_PROG seeded plan=$planId');

      // --- The next session's preview: it qualifies, but no increment is chosen, so none is invented.
      await openNext();
      await j.reveal(find.byKey(const Key('next-time')));
      expect(find.byKey(const Key('next-time-increment')), findsOneWidget);
      expect(find.byKey(const Key('next-time-proposed')), findsNothing, reason: 'no increment: no new load');
      await j.shot('prog-01-preview-choose-increment');
      await j.tapKey('next-time-increment');
      await j.waitFor(find.byKey(const Key('increment-form')), what: 'the increment sheet');
      await j.shot('prog-02-increment-sheet');
      await j.tapKey('increment-2.5');
      await j.tapKey('increment-save');
      await j.waitFor(find.byKey(const Key('next-time-proposed')), what: 'the suggestion with an increment');
      expect(tester.widget<Text>(find.byKey(const Key('next-time-proposed'))).data, '82.5 kg');
      await j.reveal(find.byKey(const Key('next-time')));
      await j.shot('prog-03-preview-suggestion');

      // --- Review, then Keep current target: nothing changes in the plan.
      await j.tapKey('next-time-review');
      await j.waitFor(find.byKey(const Key('target-review')), what: 'the review');
      await j.shot('prog-04-review');
      await j.tapKey('review-keep');
      await j.settle(4);
      expect(planTarget(), 80.0);
      expect(find.byKey(const Key('next-time')), findsNothing, reason: 'kept as it is: not offered again from the same facts');

      // --- Start; type an entry; accept from the recorder while offline.
      await j.reveal(find.byKey(const Key('preview-start')));
      await j.tapKey('preview-start');
      await j.waitFor(find.byKey(const Key('complete-set')), what: 'the recorder');
      final id = scope().read(workoutListProvider).singleWhere((w) => w.isOpen).id;
      await j.type('set-load', '85');
      FocusManager.instance.primaryFocus?.unfocus();
      await j.settle(4);
      debugPrint('GOHARD_NET:off');
      await j.waitUntil(() async => !await j.apiReachable(), what: 'the phone to be offline');
      await j.tapKey('workout-next-target-review');
      await j.waitFor(find.text('Use 82.5 kg from next session'), what: 'the suggestion in the review');
      await j.tapKey('review-confirm');
      await j.waitFor(find.byKey(const Key('review-accepted')), what: 'the accepted target');
      await j.shot('prog-05-accepted-offline');
      await j.tapKey('review-done');
      // The same workout, the same selected exercise, the typed entry, no set.
      expect(scope().read(shellProvider).workout, WorkoutFocus.session(id));
      expect(find.descendant(of: find.byKey(const Key('workout-exercise-panel')), matching: find.text('Bench press')), findsOneWidget);
      expect(field('set-load').text, '85');
      expect((await scope().read(workoutRepositoryProvider).sets(id)).where((s) => !s.isDeleted), isEmpty);
      expect(tester.widget<Text>(find.byKey(const Key('workout-target-load'))).data, '80 kg', reason: 'this workout keeps its frozen target');
      expect(tester.widget<Text>(find.byKey(const Key('workout-next-target'))).data, 'Next target · 82.5 kg');
      await j.shot('prog-06-recorder-after-accept');

      for (var i = 0; i < 3; i++) {
        await j.type('set-load', '80');
        await j.type('set-reps', '8');
        await j.tapKey('complete-set');
        await j.settle(4);
        if (find.byKey(const Key('rest-skip')).evaluate().isNotEmpty) await j.tapKey('rest-skip');
      }
      await j.tapKey('finish-workout');
      await j.confirmWith('Finish workout');
      await j.waitFor(find.byKey(const Key('workout-result')), what: 'the saved result');
      expect(find.byKey(const Key('next-time')), findsNothing, reason: 'the new target needs two sessions of its own');
      await j.shot('prog-07-result-offline');
      return;
    }

    expect(_phase, '2', reason: 'run this journey through scripts\\test-android.ps1, which sets the phase');
    j.email = await account.readAsString();
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.waitFor(find.byKey(const Key('nav-train')), what: 'the app after the process ended', seconds: 40);
    await j.waitUntil(() async => scope().read(planListProvider).isNotEmpty, what: 'the plan on this phone');
    expect(planTarget(), 82.5, reason: 'the accepted target survived the restart');
    debugPrint('GOHARD_NET:on');
    final token = await (() async {
      for (var i = 0; i < 60; i++) {
        await watch(1000);
        if (await j.apiReachable()) return j.apiToken();
      }
      fail('The API did not become reachable again.');
    })();
    await scope().read(syncProvider).flush();
    Future<Map<String, dynamic>> snap() => j.snapshot(token);
    double? accountTarget(Map<String, dynamic> s) => (((s['context'] as Map)['plans'] as List).single['workouts'] as List).single['exercises'][0]['targetLoadKg'] as double?;
    await j.waitUntil(() async => accountTarget(await snap()) == 82.5, what: 'the target on the account');
    final s = await snap();
    final done = [for (final w in s['workouts'] as List) if ((w as Map)['finishedAtUtc'] != null) w];
    expect(done, hasLength(3));
    expect(done.every((w) => (w['exercises'] as List).single['targetLoadKg'] == 80.0), isTrue, reason: 'finished workouts keep their frozen target');
    expect((s['exerciseIncrements'] as List).single['incrementKg'], 2.5);

    // --- The next matching session starts with the accepted target.
    await openNext();
    await j.reveal(find.byKey(const Key('preview-start')));
    await j.tapKey('preview-start');
    await j.waitFor(find.byKey(const Key('workout-target-load')), what: 'the recorder with its target');
    expect(tester.widget<Text>(find.byKey(const Key('workout-target-load'))).data, '82.5 kg');
    await j.shot('prog-08-next-session-started');
    final open = scope().read(workoutListProvider).singleWhere((w) => w.isOpen);
    expect(open.exercises.single.targetLoadKg, 82.5);
    debugPrint('GOHARD_PROG next workout=${open.id} target=${open.exercises.single.targetLoadKg}');
  });
}
