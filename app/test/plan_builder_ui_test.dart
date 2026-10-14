import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/plans/builder/plan_builder_screen.dart';
import 'package:gohard_rebuild/features/plans/plan_draft.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/workout_flow.dart';

import 'support.dart';
import 'ui_support.dart';

/// The plan builder over the real repository and a real on-disk store (no network: the outbox is held back, so
/// every command it queues can be read). Today is Wednesday 14 October 2026.
const _day = '2026-10-14';
const _owner = 'one';
const _oldId = '0b9f3c6e-1d2a-4c5b-9e8f-7a6b5c4d3e2f';
final _templates = PlanTemplates.parse(File('assets/data/plan-templates.json').readAsStringSync());
final _catalog = [for (final c in jsonDecode(File('../api/src/GoHard.Api/Data/exercise-catalog.json').readAsStringSync()) as List) CatalogExercise(c as Json)]
  ..sort((a, b) => a.name.compareTo(b.name));

/// One install: the database file and the signed-in owner. [open] is a launch; [close] ends the process.
class _Install {
  _Install() : store = TestStore();
  final TestStore store;
  final sessions = SessionManager(MemorySecretStore());
  final appearance = AppearanceStore(MemorySecretStore());
  AppDb? db;
  final _opened = <AppDb>[];

  Future<void> signIn() => sessions.signIn(authFor(_owner));

  List<Override> open({String unit = 'kg', List<CatalogExercise>? catalog}) {
    final db = this.db = store.open();
    _opened.add(db);
    return [
      sessionsProvider.overrideWithValue(sessions),
      dbProvider.overrideWithValue(db),
      appearanceStoreProvider.overrideWithValue(appearance),
      syncProvider.overrideWith((ref) {
        final engine = SyncEngine(db, Api(FakeServer(), sessions), sessions)..isBlocked = () => true;
        ref.onDispose(engine.dispose);
        return engine;
      }),
      todayKeyProvider.overrideWith(() => FixedDay(_day)),
      profileProvider.overrideWith((ref) => Stream.value(Profile({...authFor(_owner)['profile'] as Json, 'loadUnit': unit}))),
      catalogProvider.overrideWith((ref) => Stream.value(catalog ?? _catalog)),
      planTemplatesProvider.overrideWith((ref) async => _templates),
    ];
  }

  Future<void> close() async {
    for (final d in _opened) {
      await d.close();
    }
    _opened.clear();
  }
  void dispose() => store.dispose();

  SyncEngine _sync() => SyncEngine(db!, Api(FakeServer(), sessions), sessions)..isBlocked = () => true;
  Future<List<Json>> records(String kind) async => [for (final r in await _sync().list(_owner, kind)) jsonDecode(r.body) as Json];
  Future<List<Cmd>> commands() => _sync().commands(_owner);
  Future<void> put(String kind, String id, Json body) => _sync().putLocal(_owner, LocalWrite(kind, id, body));
}

/// The shell root stands in for Home: the builder returns to it.
class _Root extends ConsumerWidget {
  const _Root({this.plan, this.occasion, this.duplicate = false});
  final Plan? plan;
  final Occasion? occasion;
  final bool duplicate;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('open'),
            onPressed: () => plan == null
                ? push<void>(context, const CreatePlanScreen())
                : occasion != null
                    ? openOccurrenceEditor(context, ref, plan!, occasion!)
                    : openPlanEditor(context, ref, plan!, duplicate: duplicate),
            child: const Text('Open'),
          ),
        ),
      );
}

Future<ProviderContainer> _launch(WidgetTester tester, _Install install,
    {Widget home = const _Root(), String unit = 'kg', List<CatalogExercise>? catalog, Size size = const Size(390, 1400), double textScale = 1}) async {
  final c = await pumpApp(tester, install.open(unit: unit, catalog: catalog), home: home, size: size, textScale: textScale);
  await _tap(tester, 'open');
  return c;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  expect(f, findsOneWidget, reason: key);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  // A field scrolled away in a lazy list is no longer built: go back to the top first.
  if (find.byKey(Key(key)).evaluate().isEmpty) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

/// Waits for the saves queued on the phone to land.
Future<void> _settleStore(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pumpAndSettle();
}

Future<PlanDraft?> _draft(WidgetTester tester, ProviderContainer c, [String id = 'new']) async {
  await _settleStore(tester);
  return tester.runAsync<PlanDraft?>(() => c.read(planRepositoryProvider).builderDraft(id));
}

/// A fixed-weekday plan the user already follows, built like the builder builds one.
Json _activePlan({String title = 'Old plan', String start = '2026-10-05'}) {
  final d = PlanDraft.fresh(today: start, path: 'template')..setPreferences(days: [1, 3, 5]);
  d.j['planId'] = _oldId;
  d.applyTemplate(_templates, 'full-body');
  d.title = title;
  return {...d.toPlanJson(), 'lifecycle': 'active'};
}

Future<void> _seedPrimary(WidgetTester tester, _Install install, Json plan) async {
  install.db = install.store.open();
  await tester.runAsync(() async {
    await install.put(Kinds.plan, plan['id'] as String, plan);
    await install.put(Kinds.context, _owner, {'contextRevision': 1, 'primaryPlanId': plan['id']});
    await install.db!.close();
  });
}

void main() {
  // A restart opens a second connection to the same file, as the next process would.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late _Install install;
  setUp(() async {
    install = _Install();
    await install.signIn();
  });
  tearDown(() async {
    await install.close();
    install.dispose();
  });

  testWidgets('template path: previews create nothing; Activate creates one active plan with the template workouts and pauses the current plan only after confirming',
      (tester) async {
    await _seedPrimary(tester, install, _activePlan());
    final c = await _launch(tester, install);

    await _tap(tester, 'plan-path-template');
    expect(find.text('Step 1 of 4 · Availability'.toUpperCase()), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 4: Availability'), findsOneWidget);
    await _tap(tester, 'days-4');
    await _tap(tester, 'equipment-dumbbells');
    await _tap(tester, 'budget-60');
    await _tap(tester, 'builder-next');

    expect(find.bySemanticsLabel('Step 2 of 4: Structure'), findsOneWidget);
    expect(find.text('Upper / Lower · Suggested'), findsOneWidget);
    expect(find.textContaining(splitEvidenceNote), findsOneWidget);
    expect(find.textContaining('Your 4 days: Upper A, Lower A, Upper B, Lower B'), findsOneWidget);
    // Preview another template, then come back: still nothing exists on the account or as a plan.
    await _tap(tester, 'template-push-pull-legs');
    expect(find.textContaining('Rotates Push → Pull → Legs over your 4 days'), findsOneWidget);
    await _tap(tester, 'template-upper-lower');
    expect((await tester.runAsync(() => install.records(Kinds.plan)))!.map((p) => p['id']), [_oldId]);
    expect(await tester.runAsync(install.commands), isEmpty);

    await _tap(tester, 'builder-next');
    expect(find.bySemanticsLabel('Step 3 of 4: Workouts'), findsOneWidget);
    expect(find.text('Upper A'), findsOneWidget);
    expect(find.text('1. Dumbbell bench press'), findsOneWidget, reason: 'the dumbbell variant of the starting routine');
    await _tap(tester, 'builder-next');

    expect(find.bySemanticsLabel('Step 4 of 4: Review'), findsOneWidget);
    expect(find.byKey(const Key('review-replaces')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('review-day-2026-10-14')), matching: find.text('Rest')), findsOneWidget, reason: 'today, a Wednesday, is not a training day');
    expect(find.descendant(of: find.byKey(const Key('review-day-2026-10-17')), matching: find.text('Rest')), findsOneWidget, reason: 'a Saturday is a rest day');
    expect(find.descendant(of: find.byKey(const Key('review-day-2026-10-15')), matching: find.text('Upper A')), findsOneWidget, reason: 'the first training day from the start gets the first workout');
    expect(find.descendant(of: find.byKey(const Key('review-day-2026-10-19')), matching: find.text('Upper B')), findsOneWidget);

    await _tap(tester, 'plan-activate');
    expect(find.text('Pause Old plan and activate this plan?'), findsOneWidget);
    await _tapText(tester, 'Cancel');
    expect(await tester.runAsync(install.commands), isEmpty, reason: 'nothing happens without the confirmation');

    await _tap(tester, 'plan-activate');
    await _tapText(tester, 'Pause and activate');
    await _settleStore(tester);
    final plans = {for (final p in (await tester.runAsync(() => install.records(Kinds.plan)))!) p['id']: p};
    expect(plans.length, 2);
    final made = plans.values.firstWhere((p) => p['id'] != _oldId);
    expect(made['lifecycle'], 'active');
    expect(made['title'], 'Upper / Lower');
    expect(made['timeBudgetMinutes'], 60);
    expect([for (final w in made['workouts'] as List) (w as Json)['name']], ['Upper A', 'Lower A', 'Upper B', 'Lower B']);
    expect(plans[_oldId]!['lifecycle'], 'paused', reason: 'paused, with its history kept');
    expect([for (final c in (await tester.runAsync(install.commands))!) c.kind], ['plan.create', 'plan.activate']);
    expect(c.read(shellProvider).tab, 1, reason: 'back on Train');
    expect(c.read(shellProvider).trainView, TrainView.plan);
    expect(find.byKey(const Key('open')), findsOneWidget);
    expect(await _draft(tester, c), isNull, reason: 'the draft is done with');
  });

  testWidgets('custom path: name workouts, assign weekdays with a repeat, add exercises and activate', (tester) async {
    await _launch(tester, install);
    await _tap(tester, 'plan-path-custom');
    await _tap(tester, 'builder-next'); // Mon, Wed, Fri

    // Three workouts laid out from the start date: Wednesday gets the first.
    expect(find.descendant(of: find.byKey(const Key('day-assign-3')), matching: find.text('Workout A')), findsOneWidget);
    await _type(tester, 'custom-workout-name-0', 'Push');
    await _type(tester, 'custom-workout-name-1', 'Pull');
    await _tap(tester, 'custom-workout-remove-2');
    expect(find.descendant(of: find.byKey(const Key('day-assign-1')), matching: find.text('Rest')), findsOneWidget, reason: 'its Monday became a rest day');
    await _tap(tester, 'custom-add-workout');
    await _type(tester, 'custom-workout-name-2', 'Legs');
    await _type(tester, 'plan-title', 'My split');
    await _tap(tester, 'day-assign-1');
    await _tap(tester, 'day-assign-1-2');
    await _tap(tester, 'day-assign-6');
    await _tap(tester, 'day-assign-6-0');
    expect(find.descendant(of: find.byKey(const Key('day-assign-6')), matching: find.text('Push')), findsOneWidget, reason: 'a workout can repeat');
    await _tap(tester, 'builder-next');

    for (final (i, key) in [(0, 'push-up'), (1, 'pull-up'), (2, 'goblet-squat')]) {
      await _tap(tester, 'exercise-add-$i');
      await _type(tester, 'exercise-search', key);
      await _tap(tester, 'exercise-$key');
    }
    expect(find.text('3 × 8–12 · 90 s rest'), findsNWidgets(3));
    await _tap(tester, 'builder-next');
    expect(find.byKey(const Key('review-draft')), findsNothing);
    expect(find.byKey(const Key('review-replaces')), findsNothing, reason: 'no plan is active yet');
    expect(find.descendant(of: find.byKey(const Key('review-day-2026-10-17')), matching: find.text('Push')), findsOneWidget);
    await _tap(tester, 'plan-activate'); // nothing to replace: no confirmation needed
    await _settleStore(tester);

    final plan = Plan((await tester.runAsync(() => install.records(Kinds.plan)))!.single);
    expect((plan.title, plan.lifecycle, plan.templateId), ('My split', 'active', 'custom'));
    final names = {for (final w in plan.workouts) w.id: w.name};
    expect([for (final p in plan.schedule!.pattern) '${p.weekday}:${names[p.workoutId]}'], ['1:Legs', '3:Push', '5:Pull', '6:Push']);
    expect(plan.occasions.length, 4 * 8);
    expect(plan.occasions.map((o) => o.id).toSet().length, plan.occasions.length, reason: 'each repeat is its own occurrence');
  });

  testWidgets('the workout editor: rename, duplicate, delete, reorder by buttons, add, replace, remove and reorder exercises, and prescriptions with a target in lb stored as kg',
      (tester) async {
    final c = await _launch(tester, install, unit: 'lb');
    await _tap(tester, 'plan-path-template');
    await _tap(tester, 'days-4');
    await _tap(tester, 'builder-next');
    await _tap(tester, 'builder-next');

    await _tap(tester, 'workout-menu-0');
    await _tap(tester, 'workout-rename-0');
    await _type(tester, 'workout-name-field', 'Upper heavy');
    await _tap(tester, 'workout-name-save');
    await _tap(tester, 'workout-menu-1');
    await _tap(tester, 'workout-duplicate-1');
    expect(find.text('Lower A (copy)'), findsOneWidget);
    expect(find.text('Not scheduled yet. Choose its days in Structure.'), findsOneWidget);
    await _tap(tester, 'workout-menu-2');
    await _tap(tester, 'workout-delete-2');
    await _tapText(tester, 'Delete workout');
    await _tap(tester, 'workout-down-0');
    var d = (await _draft(tester, c))!;
    expect([for (final w in d.workouts) w.name], ['Lower A', 'Upper heavy', 'Upper B', 'Lower B']);

    // Lower A is now workout 0.
    await _tap(tester, 'exercise-down-0-0');
    expect(find.text('1. Romanian deadlift'), findsOneWidget);
    expect(find.text('2. Back squat'), findsOneWidget);
    await _tap(tester, 'exercise-menu-0-0');
    await _tap(tester, 'exercise-remove-0-0');
    expect(find.text('1. Back squat'), findsOneWidget);
    await _tap(tester, 'exercise-menu-0-0');
    await _tap(tester, 'exercise-replace-0-0');
    await _type(tester, 'exercise-search', 'goblet');
    await _tap(tester, 'exercise-goblet-squat');
    expect(find.text('1. Goblet squat'), findsOneWidget);
    expect(find.text('3 × 6–10 · 150 s rest'), findsWidgets, reason: 'the replacement keeps sets, reps and rest');
    await _tap(tester, 'exercise-add-0');
    await _type(tester, 'exercise-search', 'side plank');
    await _tap(tester, 'exercise-side-plank');
    d = (await _draft(tester, c))!;
    final lower = d.workouts.first.exercises;
    expect(lower.last.name, 'Side plank');
    expect(find.text('${lower.length}. Side plank'), findsOneWidget);
    expect(find.text('3 × 30 s · 90 s rest'), findsOneWidget, reason: 'a timed exercise shows its time');

    await _tap(tester, 'exercise-0-${lower.length - 1}');
    expect(find.byKey(const Key('rx-seconds')), findsOneWidget);
    expect(find.byKey(const Key('rx-reps-min')), findsNothing);
    await _type(tester, 'rx-seconds', '45');
    await _tap(tester, 'rx-save');
    expect(find.text('3 × 45 s · 90 s rest'), findsOneWidget);

    await _tap(tester, 'exercise-0-0');
    await _type(tester, 'rx-sets', '4');
    await _type(tester, 'rx-reps-min', '5');
    await _type(tester, 'rx-reps-max', '3');
    await _type(tester, 'rx-rest', '1000');
    await _tap(tester, 'rx-save');
    expect(find.text('The highest reps cannot be fewer than the lowest.'), findsOneWidget);
    expect(find.text('Rest: 0 to 900 seconds (15 minutes).'), findsOneWidget);
    await _type(tester, 'rx-reps-max', '8');
    await _type(tester, 'rx-rest', '120');
    expect(find.text('Target weight (lb), optional'), findsOneWidget);
    await _type(tester, 'rx-load', '135');
    await _type(tester, 'rx-notes', 'Slow down');
    await _tap(tester, 'rx-save');
    expect(find.text('4 × 5–8 · 120 s rest'), findsOneWidget);
    expect(find.text('Target 135 lb'), findsOneWidget);
    expect(find.text('Slow down'), findsOneWidget);
    d = (await _draft(tester, c))!;
    final first = d.workouts.first.exercises.first;
    expect(first.targetLoadKg, closeTo(61.235, 0.001), reason: 'stored in kilograms');
    expect((first.targetSets, first.targetRepsMin, first.targetRepsMax, first.restSeconds, first.notes), (4, 5, 8, 120, 'Slow down'));

    await _tap(tester, 'exercise-up-0-1');
    d = (await _draft(tester, c))!;
    expect(d.workouts.first.exercises[1].name, 'Goblet squat');
  });

  testWidgets('copy a workout from another of your plans and from this plan', (tester) async {
    await _seedPrimary(tester, install, _activePlan());
    final c = await _launch(tester, install);
    await _tap(tester, 'plan-path-custom');
    await _tap(tester, 'builder-next');
    await _tap(tester, 'builder-next');
    await _tap(tester, 'workout-copy');
    expect(find.text('Old plan'), findsOneWidget);
    await _tap(tester, 'copy-plan-$_oldId-0');
    expect(find.text('Full body A'), findsOneWidget);
    await _tap(tester, 'workout-copy');
    await _tap(tester, 'copy-this-3');
    final d = (await _draft(tester, c))!;
    expect([for (final w in d.workouts) w.name], ['Workout A', 'Workout B', 'Workout C', 'Full body A', 'Full body A (copy)']);
    expect(d.workouts[3].exercises.map((e) => e.name), ['Back squat', 'Bench press', 'Barbell row', 'Plank']);
    expect(d.workouts[4].exercises.map((e) => e.name), d.workouts[3].exercises.map((e) => e.name));
    final old = Plan((await tester.runAsync(() => install.records(Kinds.plan)))!.single);
    expect(old.workouts.first.exercises.length, 4, reason: 'the source is untouched');
  });

  testWidgets('picker: search ignores case and hyphens, filters by muscle and equipment, and a new exercise of your own is chosen and found again', (tester) async {
    final c = await _launch(tester, install);
    await _tap(tester, 'plan-path-custom');
    await _tap(tester, 'builder-next');
    await _tap(tester, 'builder-next');
    await _tap(tester, 'exercise-add-0');

    await _type(tester, 'exercise-search', 'PUSHUP');
    expect(find.byKey(const Key('exercise-push-up')), findsOneWidget);
    await _type(tester, 'exercise-search', 'push up');
    expect(find.byKey(const Key('exercise-push-up')), findsOneWidget);
    expect(find.byKey(const Key('exercise-pike-push-up')), findsOneWidget);
    expect(find.byKey(const Key('exercise-feet-elevated-push-up')), findsOneWidget);
    await _type(tester, 'exercise-search', 'bench');
    expect(find.byKey(const Key('exercise-bench-press')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('exercise-dumbbell-bench-press')), matching: find.text('Chest · Dumbbell')), findsOneWidget, reason: 'variants are told apart');
    await _tap(tester, 'filter-equipment-Dumbbell');
    expect(find.byKey(const Key('exercise-bench-press')), findsNothing);
    expect(find.byKey(const Key('exercise-dumbbell-bench-press')), findsOneWidget);
    await _type(tester, 'exercise-search', '');
    await _tap(tester, 'filter-muscle-Arms');
    expect(find.byKey(const Key('exercise-biceps-curl')), findsOneWidget);
    expect(find.byKey(const Key('exercise-dumbbell-bench-press')), findsNothing);
    await _tap(tester, 'filter-muscle-Arms');
    await _tap(tester, 'filter-equipment-Dumbbell');

    await _type(tester, 'exercise-search', 'Landmine press');
    expect(find.text('Create “Landmine press” as your own exercise'), findsOneWidget);
    await _tap(tester, 'exercise-create-custom');
    expect(find.textContaining('Only you can see your own exercises'), findsOneWidget);
    await _tap(tester, 'custom-category-Shoulders');
    await _tap(tester, 'custom-equipment-Barbell');
    await _tap(tester, 'custom-save');
    expect(find.text('1. Landmine press'), findsOneWidget, reason: 'chosen straight away');

    final made = (await tester.runAsync(() => install.records(Kinds.customExercise)))!.single;
    expect((made['name'], made['category'], made['equipment']), ('Landmine press', 'Shoulders', 'Barbell'));
    final d = (await _draft(tester, c))!;
    expect(d.workouts.first.exercises.single.catalogKey, 'custom:${made['id']}');

    await _tap(tester, 'exercise-add-1');
    await _type(tester, 'exercise-search', 'landmine');
    final row = find.byKey(Key('exercise-custom:${made['id']}'));
    expect(find.descendant(of: row, matching: find.text('Shoulders · Barbell · Your exercise')), findsOneWidget);
    await _tap(tester, 'exercise-custom:${made['id']}');
    expect(find.text('1. Landmine press'), findsNWidgets(2), reason: 'usable like any other exercise');
  });

  testWidgets('picker without a downloaded catalog says so and still creates your own exercise', (tester) async {
    await pumpApp(tester, install.open(catalog: const []), home: const ExercisePicker());
    expect(find.textContaining('has not been downloaded'), findsOneWidget);
    await _tap(tester, 'exercise-create-custom');
    await _type(tester, 'custom-name', 'Sled push');
    await _tap(tester, 'custom-timed');
    await _tap(tester, 'custom-save');
    final made = (await tester.runAsync(() => install.records(Kinds.customExercise)))!.single;
    expect((made['name'], made['isTimed']), ('Sled push', true));
    expect([for (final c in (await tester.runAsync(install.commands))!) c.kind], ['customexercise.put']);
  });

  testWidgets('the draft is saved on every change and survives a theme change, leaving the screen and a process restart', (tester) async {
    final c = await _launch(tester, install);
    await _tap(tester, 'plan-path-template');
    await _tap(tester, 'days-5');
    await _tap(tester, 'builder-next');
    await _type(tester, 'plan-title', 'Five days');

    c.read(appearanceProvider.notifier).setMode(ThemeMode.light);
    await tester.pumpAndSettle();
    c.read(appearanceProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 2 of 4: Structure'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('plan-title'))).controller!.text, 'Five days');

    // Leave (system back goes to the previous step first), then come back.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 1 of 4: Availability'), findsOneWidget);
    await _tap(tester, 'builder-back');
    expect(find.byKey(const Key('open')), findsOneWidget);
    await _tap(tester, 'open');
    expect(find.text('Five days'), findsOneWidget);
    expect(find.textContaining('Step 1 of 4 · Availability'), findsOneWidget);
    await _settleStore(tester);

    // The process ends and the app starts again over the same file.
    // (A second connection to the same file: what the next process reads.)
    await tester.pumpWidget(const SizedBox());
    await _launch(tester, install);
    await _tap(tester, 'plan-draft-resume');
    expect(find.bySemanticsLabel('Step 1 of 4: Availability'), findsOneWidget);
    await _tap(tester, 'builder-next');
    expect(tester.widget<TextField>(find.byKey(const Key('plan-title'))).controller!.text, 'Five days');
    expect(find.text('Upper / Lower + Push / Pull / Legs · Suggested'), findsOneWidget);
    expect(await tester.runAsync(install.commands), isEmpty, reason: 'saving a draft never creates or activates anything');

    // Start over removes it.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, 'builder-back');
    await _tap(tester, 'open');
    await _tap(tester, 'plan-draft-discard');
    await _tapText(tester, 'Discard it');
    expect(find.byKey(const Key('plan-path-template')), findsOneWidget);
    expect(await tester.runAsync(() => install.records(Kinds.planBuilder)), isEmpty);
  });

  testWidgets('Save draft leaves without creating or activating a plan', (tester) async {
    final c = await _launch(tester, install);
    await _tap(tester, 'plan-path-template');
    await _tap(tester, 'builder-next');
    await _tap(tester, 'builder-next');
    await _tap(tester, 'builder-next');
    expect(find.byKey(const Key('plan-activate')), findsOneWidget);
    await _tap(tester, 'plan-save-draft');
    expect(find.text('Draft saved on this phone. Nothing is active yet.'), findsOneWidget);
    expect(await tester.runAsync(() => install.records(Kinds.plan)), isEmpty);
    expect(await tester.runAsync(install.commands), isEmpty);
    expect((await _draft(tester, c))!.step, 3);
    expect(c.read(shellProvider).tab, 0, reason: 'nothing moved the user to Train');
  });

  testWidgets('an empty structure is labelled Draft and cannot be activated', (tester) async {
    await _launch(tester, install);
    await _tap(tester, 'plan-path-template');
    await _tap(tester, 'builder-next');
    await _tap(tester, 'template-with-exercises');
    expect(find.textContaining('The plan stays a draft until every scheduled workout has an exercise'), findsOneWidget);
    await _tap(tester, 'builder-next');
    expect(find.text('No exercises yet. Add at least one so this workout can be scheduled.'), findsNWidgets(3));
    await _tap(tester, 'builder-next');
    expect(find.text('Draft — add exercises to Full body A, Full body B, Full body C before this plan can be activated.'), findsOneWidget);
    expect(find.byKey(const Key('plan-activate')), findsNothing);
    expect(find.byKey(const Key('plan-save-draft')), findsOneWidget);
  });

  testWidgets('a rotating plan reviews its cycle with projected dates that carry on across the week', (tester) async {
    await _launch(tester, install);
    await _tap(tester, 'plan-path-template');
    await _tap(tester, 'days-2'); // Mon and Thu
    await _tap(tester, 'builder-next');
    await _tap(tester, 'template-push-pull-legs');
    expect(find.textContaining('Rotates Push → Pull → Legs over your 2 days'), findsOneWidget);
    expect(find.text('The cycle'), findsOneWidget);
    await _tap(tester, 'cycle-down-0');
    await _tap(tester, 'cycle-up-1');
    await _tap(tester, 'duration-ongoing');
    await _tap(tester, 'builder-next');
    await _tap(tester, 'builder-next');
    expect(find.textContaining('Rotating sequence · ongoing'), findsOneWidget);
    expect(find.text('Cycle: Push → Pull → Legs, then it starts again.'), findsOneWidget);
    for (final (i, date, title) in [(0, 'Thu, Oct 15', 'Push'), (1, 'Mon, Oct 19', 'Pull'), (2, 'Thu, Oct 22', 'Legs'), (3, 'Mon, Oct 26', 'Push'), (4, 'Thu, Oct 29', 'Pull')]) {
      final row = find.byKey(Key('review-next-$i'));
      expect(find.descendant(of: row, matching: find.text(date)), findsOneWidget, reason: 'step $i');
      expect(find.descendant(of: row, matching: find.text(title)), findsOneWidget, reason: 'step $i');
    }
  });

  testWidgets('editing a plan states its scope and sends one revise from the chosen effective date', (tester) async {
    final old = _activePlan();
    await _seedPrimary(tester, install, old);
    await _launch(tester, install, home: _Root(plan: Plan(old)));
    expect(find.text('Edit plan'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 4: Structure'), findsOneWidget);
    expect(find.text('An active plan keeps its start date.'), findsOneWidget);
    await _tap(tester, 'builder-next');
    await _tap(tester, 'workout-menu-0');
    await _tap(tester, 'workout-rename-0');
    await _type(tester, 'workout-name-field', 'Full body heavy');
    await _tap(tester, 'workout-name-save');
    await _tap(tester, 'builder-next');

    expect(find.descendant(of: find.byKey(const Key('plan-effective-date')), matching: find.text('Wednesday, October 14')), findsOneWidget);
    expect(find.textContaining('Workouts you recorded or skipped, and one in progress, stay exactly as they are'), findsOneWidget);
    expect(find.byKey(const Key('plan-activate')), findsNothing);
    await _tap(tester, 'plan-effective-date');
    await _tapText(tester, '21');
    await _tapText(tester, 'OK');
    expect(find.descendant(of: find.byKey(const Key('plan-effective-date')), matching: find.text('Wednesday, October 21')), findsOneWidget);
    await _tap(tester, 'plan-save-changes');
    await _settleStore(tester);

    final cmds = (await tester.runAsync(install.commands))!;
    expect([for (final c in cmds) c.kind], ['plan.revise']);
    final payload = jsonDecode(cmds.single.payload) as Json;
    expect(payload['effectiveDate'], '2026-10-21');
    expect(((payload['workouts'] as List).first as Json)['name'], 'Full body heavy');
    final saved = Plan((await tester.runAsync(() => install.records(Kinds.plan)))!.single);
    expect(saved.occasions.firstWhere((o) => o.scheduledDate == '2026-10-19').title, 'Full body A', reason: 'before the effective date nothing changes');
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  testWidgets('this workout only: one occurrence gets its own name and exercises; the rest of the plan is unchanged', (tester) async {
    final old = _activePlan();
    await _seedPrimary(tester, install, old);
    final o = Plan(old).occasions.firstWhere((o) => o.scheduledDate == '2026-10-16');
    await _launch(tester, install, home: _Root(plan: Plan(old), occasion: o));
    expect(find.textContaining('The rest of "Old plan" stays as it is'), findsOneWidget);
    await _type(tester, 'occurrence-title', 'Short day');
    await _tap(tester, 'exercise-menu-0-0');
    await _tap(tester, 'exercise-remove-0-0');
    await _tap(tester, 'occurrence-save');
    await _settleStore(tester);
    expect([for (final c in (await tester.runAsync(install.commands))!) c.kind], ['plan.occasion']);
    final saved = Plan((await tester.runAsync(() => install.records(Kinds.plan)))!.single);
    final edited = saved.occasions.firstWhere((x) => x.id == o.id);
    expect((edited.title, edited.prescription.length, edited.isCustomised), ('Short day', o.prescription.length - 1, true));
    expect(saved.occasions.where((x) => x.id != o.id && x.title == 'Short day'), isEmpty);
  });

  testWidgets('duplicating a plan ends in the normal review, and asks before replacing another plan in progress', (tester) async {
    final old = _activePlan();
    await _seedPrimary(tester, install, old);
    final c = await _launch(tester, install, home: _Root(plan: Plan(old), duplicate: true));
    expect(find.text('Duplicate plan'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 3 of 4: Workouts'), findsOneWidget);
    await _tap(tester, 'builder-next');
    expect(find.text('Old plan (copy)'), findsOneWidget);
    expect(find.byKey(const Key('plan-activate')), findsOneWidget);
    expect(find.byKey(const Key('plan-effective-date')), findsNothing);
    await _tap(tester, 'plan-save-draft');
    expect((await _draft(tester, c))!.title, 'Old plan (copy)');

    await _tap(tester, 'open');
    expect(find.text('Replace your plan in progress?'), findsOneWidget);
    await _tapText(tester, 'Cancel');
    expect(find.byKey(const Key('open')), findsOneWidget, reason: 'nothing replaced');
    expect(await tester.runAsync(install.commands), isEmpty);
  });

  for (final accent in Accent.values) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${accent.name} ${mode.name}: every builder step meets contrast, target and label guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        install.appearance
          ..accent = accent
          ..mode = mode;
        await _launch(tester, install, size: const Size(390, 3000));
        await _tap(tester, 'plan-path-template');
        for (var step = 1; step <= 4; step++) {
          await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'step $step');
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: 'step $step');
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: 'step $step');
          if (step < 4) await _tap(tester, 'builder-next');
        }
        handle.dispose();
      });
    }
  }

  testWidgets('every step fits 320 px at twice the text size, and the keyboard never hides the field or the action', (tester) async {
    await _launch(tester, install, size: const Size(320, 640), textScale: 2);
    await _tap(tester, 'plan-path-template');
    for (var step = 1; step <= 4; step++) {
      expect(tester.takeException(), isNull, reason: 'step $step');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'step $step, further down');
      if (step == 2) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.showKeyboard(find.byKey(const Key('plan-title')));
        await tester.pumpAndSettle();
        final field = tester.getRect(find.byKey(const Key('plan-title')));
        final next = tester.getRect(find.byKey(const Key('builder-next')));
        expect(next.bottom, lessThanOrEqualTo(340), reason: 'the action rides above the keyboard');
        expect(field.top >= 0 && field.top + 60 <= next.top, isTrue, reason: 'the input line of the focused field is in view: $field above $next');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
      }
      if (step < 4) await _tap(tester, 'builder-next');
    }
    expect(find.byKey(const Key('plan-activate')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, install.open(), home: const ExercisePicker(), size: const Size(320, 640), textScale: 2);
    expect(tester.takeException(), isNull, reason: 'picker');
  });
}
