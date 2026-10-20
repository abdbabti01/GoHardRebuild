import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Switching exercise in the recorder (iPhone report: Next exercise and the All movements rows did nothing once the
/// first movement had its three sets). Not in the default run: scripts\test-android.ps1 -Only journey_switch_test.
/// A manual workout of the report's movements: three sets on Triceps pushdown and a typed draft, Next to Lat pulldown, Skull crusher directly, back to Triceps
/// pushdown: its sets and draft are intact, and it is the same workout with the same clock and rest.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switching exercise keeps the workout, sets and drafts', (tester) async {
    final j = Journey(tester, binding);
    TextEditingController field(String key) => tester.widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField))).controller!;
    Future<void> showing(String name) async {
      await j.waitFor(find.descendant(of: find.byKey(const Key('workout-exercise-panel')), matching: find.text(name)), what: '$name as the selected exercise', seconds: 8);
      expect(find.descendant(of: find.byKey(const Key('workout-exercise-panel')), matching: find.text(name)).hitTestable(), findsOneWidget, reason: '$name is on screen');
    }

    Future<void> add(String name, {bool custom = false}) async {
      await j.tapKey('manual-add-exercise');
      await j.type('exercise-search', name);
      if (custom) {
        await j.tapKey('exercise-create-custom');
        await j.tapKey('custom-save');
      } else {
        await j.tap(find.descendant(of: find.byType(ListRow), matching: find.text(name)));
      }
      await j.waitFor(find.byKey(const Key('manual-start')));
    }

    await j.start('Switch Journey');
    await j.tapKey('nav-train');
    await j.tapKey('start-manual');
    await j.type('manual-title', 'Arms and back');
    await add('Triceps pushdown');
    await add('Lat pulldown');
    await add('Skull crusher', custom: true);
    await add('Barbell row');
    await j.tapKey('manual-start');
    await j.waitFor(find.byKey(const Key('complete-set')), what: 'the recorder');
    await showing('Triceps pushdown');

    for (final reps in ['12', '10', '10']) {
      await j.type('set-load', '45');
      await j.type('set-reps', reps);
      await j.tapKey('complete-set');
      await j.settle(4);
    }
    // A manual workout has no planned set count, so no target line here; workout_panel_test covers the planned 3 of 3.
    await j.waitFor(find.byKey(const Key('set-row-2')), what: 'three recorded sets');
    // A typed draft for the fourth set, not recorded.
    await j.type('set-reps', '8');
    FocusManager.instance.primaryFocus?.unfocus();
    await j.settle(4);
    await j.shot('sw-01-triceps-three-sets');

    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('complete-set'))));
    final repo = container.read(workoutRepositoryProvider);
    final id = container.read(workoutListProvider).singleWhere((w) => w.isOpen).id;
    // Everything but the panel's own selection and drafts: the clock and rest anchors.
    Future<String> anchors() async => jsonEncode((await repo.runtime(id))!.j..remove('selectedExerciseId')..remove('drafts'));
    final before = await anchors();
    debugPrint('GOHARD_SWITCH workout=$id anchors=$before');

    await j.tapKey('next-exercise');
    await showing('Lat pulldown');
    expect(find.byKey(const Key('set-row-0')), findsNothing);
    await j.shot('sw-02-next-lat-pulldown');

    await j.tapKey('exercise-row-3');
    await showing('Skull crusher');
    await j.shot('sw-03-direct-skull-crusher');

    await j.tapKey('exercise-row-1');
    await showing('Triceps pushdown');
    expect(field('set-load').text, '45');
    expect(field('set-reps').text, '8', reason: 'the typed draft came back with its own exercise');
    for (final i in [0, 1, 2]) {
      expect(find.byKey(Key('set-row-$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('set-row-3')), findsNothing, reason: 'switching recorded nothing');
    expect(find.textContaining('45 kg × 12'), findsWidgets);
    await j.shot('sw-04-back-to-triceps');

    expect(container.read(workoutListProvider).where((w) => w.isOpen).map((w) => w.id), [id], reason: 'the same workout, no second one');
    expect((await repo.sets(id)).where((s) => !s.isDeleted), hasLength(3));
    final after = await anchors();
    debugPrint('GOHARD_SWITCH workout=$id anchors=$after');
    expect(after, before, reason: 'the clock and rest anchors did not change');
  });
}
