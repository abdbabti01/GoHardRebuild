import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/activity/activity_screens.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart';
import 'package:gohard_rebuild/features/plans/week_widgets.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/today/daily.dart';
import 'package:gohard_rebuild/features/today/today_screen.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';

import 'support.dart';
import 'ui_support.dart';
import 'weather_fakes.dart';

const day = '2026-10-11'; // week 3 of the fixture block, with "Upper body A" due

Json manualDone() => {
      'id': 'm1', 'kind': 'manual', 'title': 'Quick pull-ups', 'dayKey': day, 'startedAtUtc': '${day}T09:00:00Z', 'finishedAtUtc': '${day}T09:10:00Z',
      'outcome': 'manual_recorded', 'performedSets': 1, 'performedExercises': 1, 'qualifiedOccasion': false, 'isDeleted': false, 'exercises': const [],
    };

Json run(String id, String startedDay, {bool open = true, num? meters = 5000}) => {
      'id': id, 'dayKey': startedDay, 'startedAtUtc': '${startedDay}T07:00:00Z', 'finishedAtUtc': open ? null : '${startedDay}T07:30:00Z',
      'activeDurationSeconds': open ? null : 1800, 'distanceMeters': open ? null : meters, 'isDeleted': false,
    };

/// The phone-only runtime rows (a run's saved clock and measured distance, a parked workout's flag).
Override runtimes(Map<String, Json> byId) => runtimesProvider.overrideWith((ref) => Stream.value([for (final e in byId.entries) stored(e.value, Kinds.runtime, e.key, e.value)]));

/// A paused clock at 31 minutes with 5.2 km measured: values that do not move while the test runs.
const Json pausedRun = {'accumulatedActiveSeconds': 1860, 'runningAnchorUtc': null, 'isPaused': true, 'track': {'distanceMeters': 5200.0, 'fixes': 40, 'gaps': 0}};

final food = [foodEntry('f1', day, 'Lunch', 'Rice', '1 bowl', calories: 400, protein: 25, carbs: 80, fat: 2), foodEntry('f2', day, 'Snack', 'Toast', '2 slices', calories: 110)];

Finder photo(String module) => find.byKey(Key('today-photo-$module'));
double height(WidgetTester tester, String module) => tester.getSize(find.byKey(Key('today-module-$module'))).height;

Future<List<Override>> fixture(WidgetTester tester, {List<Json> plans = const [], List<Json> workouts = const [], List<Json> sets = const [], List<Json> food = const [], List<Json> runs = const [],
        int? calorieGoal, int? proteinGoal, Json profile = const {}, bool profileLoaded = true, Map<String, Json>? runtime, int pending = 0, List<Override> more = const []}) async =>
    [
      for (final (i, o) in (await tester.runAsync(() => overridesFor(day: day, plans: plans, primaryPlanId: plans.isEmpty ? null : 'p1', workouts: workouts, sets: sets, food: food, runs: runs,
              calorieGoal: calorieGoal, proteinGoal: proteinGoal, profile: profile, profileLoaded: profileLoaded, pending: pending)))!
          .indexed)
        // overridesFor gives an empty runtime list at this position; a test that needs runtimes replaces it.
        if (runtime == null || i != _runtimeIndex) o,
      if (runtime != null) runtimes(runtime),
      ...more,
    ];

/// Where `runtimesProvider` sits in the list overridesFor returns (checked by the first test below).
const _runtimeIndex = 11;

void main() {
  // The app's real font, so the measured heights and wrapping are the ones a phone shows.
  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await inter.load();
  });
  final plan = blockPlan(start: '2026-09-21', recorded: 8);

  testWidgets('the header says the local date and greets by the first name on the profile, at the local time of day', (tester) async {
    Future<void> at(int hour, {Json profile = const {}, bool loaded = true}) async =>
        pumpApp(tester, await fixture(tester, profile: profile, profileLoaded: loaded, more: [clockProvider.overrideWithValue(FakeClock(DateTime(2026, 10, 11, hour).toUtc()))]));
    await at(9);
    expect(find.text('Sunday, October 11'), findsOneWidget);
    expect(find.text('Good morning, Alex'), findsOneWidget, reason: 'the fixture profile is "Alex Sample"');
    expect(find.bySemanticsLabel('GoHard'), findsOneWidget, reason: 'the small mark');
    await at(14, profile: {'displayName': '  Sam  '});
    expect(find.text('Good afternoon, Sam'), findsOneWidget);
    await at(21, profile: {'displayName': ''});
    expect(find.text('Good evening'), findsOneWidget, reason: 'no name is no name; none is invented');
    await at(2, loaded: false);
    expect(find.text('Good evening'), findsOneWidget, reason: 'the profile has not been read yet');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the three sections are near their target heights at 390 × 844 with a notch, and nutrition starts on the first screen', (tester) async {
    final open = openWorkout(plan, 'o3-3', day: day, recordedSets: 6);
    await pumpApp(tester, await fixture(tester, plans: [plan], workouts: [open.workout], sets: open.sets, food: food.take(1).toList(), calorieGoal: 2200, proteinGoal: 140,
        runs: [run('r1', day)], runtime: {'r1': pausedRun}), insets: phoneInsets);
    expect(find.text('5.20 km'), findsOneWidget, reason: 'the runtime override reached the Run module');
    final (w, r, n) = (height(tester, 'workout'), height(tester, 'run'), height(tester, 'nutrition'));
    debugPrint('module heights, full state: workout $w, run $r, nutrition $n');
    expect(w, inInclusiveRange(225, 255), reason: 'workout, in progress with a planned total and its ring');
    expect(r, inInclusiveRange(130, 165), reason: 'run, open with a distance and a time: no taller than its photograph needs');
    expect(n, inInclusiveRange(195, 230), reason: 'nutrition, two goals');
    expect(w, lessThan(1.7 * r), reason: 'the workout does not dominate: comparable weight');
    final header = tester.getSize(find.byKey(const Key('today-header'))).height;
    debugPrint('header region $header');
    expect(header, inInclusiveRange(160, 280), reason: 'the date, title, greeting and sky line, then the surface');
    final navTop = tester.getTopLeft(find.byKey(const Key('nav-today'))).dy;
    // The nutrition label and its calorie figure are on the first screen, above the navigation bar.
    final nutritionTop = tester.getTopLeft(find.byKey(const Key('today-module-nutrition'))).dy;
    final calories = tester.getBottomLeft(find.descendant(of: find.byKey(const Key('today-module-nutrition')), matching: find.textContaining('2,200 kcal'))).dy;
    debugPrint('full state: nutrition starts at $nutritionTop, its calorie figure ends at $calories, the navigation bar starts at $navTop');
    // The brief: nothing is squeezed to fit the first screen. The nutrition section starts on it, its label visible.
    expect(nutritionTop + 36, lessThan(navTop), reason: 'the nutrition section and its label start on the first screen');
    expect(tester.getBottomLeft(find.byKey(const Key('today-run'))).dy, lessThan(navTop));

    // The quietest day: a due workout, no run, nothing logged.
    await pumpApp(tester, await fixture(tester, plans: [plan]), insets: phoneInsets);
    final quiet = (height(tester, 'workout'), height(tester, 'run'), height(tester, 'nutrition'));
    debugPrint('module heights, quiet state: workout ${quiet.$1}, run ${quiet.$2}, nutrition ${quiet.$3}');
    expect(quiet.$1, inInclusiveRange(160, 215));
    expect(quiet.$2, inInclusiveRange(120, 150), reason: 'no run: the label and one line beside the photograph');
    expect(quiet.$3, inInclusiveRange(115, 190));
    expect(tester.getBottomLeft(find.byKey(const Key('log-food'))).dy, lessThan(navTop), reason: 'all three sections, actions included, are on the first screen');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today\'s scene fills the whole screen, behind the status bar and the floating bar, and stays put while the page scrolls over it', (tester) async {
    await pumpApp(tester, await fixture(tester, plans: [plan], workouts: [manualDone()], food: food), insets: phoneInsets);
    final top = phoneInsets.top;
    final screen = const Offset(0, 0) & tester.view.physicalSize / tester.view.devicePixelRatio;
    // One veil behind the status bar, over every tab.
    expect(tester.getRect(find.byType(StatusBarVeil)), const Rect.fromLTWH(0, 0, 390, 47));
    expect(tester.getRect(find.byType(TodayBackdrop)), screen, reason: 'top edge to bottom edge, under the navigation bar too');
    // weather_contrast_test measures the header's text band at 71–197 px; this keeps the two in step.
    final lines = tester.getRect(find.byType(TabHeader));
    expect(lines.top, top + 24);
    expect(lines.bottom, lessThanOrEqualTo(197));

    // Every section sits on the one surface, below the header; nothing of the day is drawn on the scene itself.
    final surface = find.byKey(const Key('today-surface'));
    expect(surface, findsOneWidget);
    for (final k in ['today-module-workout', 'today-module-run', 'today-module-nutrition']) {
      expect(find.descendant(of: surface, matching: find.byKey(Key(k))), findsOneWidget, reason: '$k on the surface');
    }
    expect(find.descendant(of: surface, matching: find.text('Quick pull-ups')), findsOneWidget, reason: 'recorded today, on the surface too');
    expect(tester.getTopLeft(surface).dy, greaterThan(lines.bottom), reason: 'the surface starts below the header');
    expect(find.descendant(of: surface, matching: find.byType(BackdropFilter)), findsOneWidget, reason: 'one blur for the whole surface');

    // Scrolled to the end: the scene has not moved, and the last control clears the floating bar.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(TodayBackdrop)), screen, reason: 'the scene is fixed to the screen, not to the page');
    final navTop = tester.getTopLeft(find.byKey(const Key('nav-today'))).dy;
    expect(tester.getBottomLeft(surface).dy, lessThan(navTop), reason: 'the end of the page clears the navigation bar');
    expect(tester.getBottomLeft(find.text('Quick pull-ups')).dy, lessThan(navTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('only Today has a scene: Train and Eat sit on the calm wash and Me on the plain page, each title where Today has it', (tester) async {
    await pumpApp(tester, await fixture(tester, plans: [plan]), insets: phoneInsets);
    final top = phoneInsets.top;
    expect(find.byType(SceneBackdrop, skipOffstage: false), findsOneWidget, reason: 'one scene in the whole shell, Today\'s');
    for (final (tab, title, wash) in [('train', 'Train', true), ('eat', 'Eat', true), ('me', 'Me', false)]) {
      await tester.tap(find.byKey(Key('nav-$tab')));
      await tester.pumpAndSettle();
      final header = find.byWidgetPredicate((w) => w is TabHeader && w.title == title);
      expect(tester.getTopLeft(header).dy, top + 24, reason: '$tab: the title where every tab has it');
      expect(tester.widget<TabHeader>(header).onBackdrop, isFalse, reason: '$tab: no scrim, there is no scene');
      expect(find.ancestor(of: header, matching: find.byType(QuietBackground)), wash ? findsOneWidget : findsNothing, reason: '$tab background');
      expect(find.ancestor(of: header, matching: find.byType(SceneBackdrop)), findsNothing);
    }
    // The end of a long page clears the floating bar on every tab, not only Today.
    await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byKey(const Key('me-sign-out'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('nav-me'))).dy));
    expect(tester.takeException(), isNull);
  });

  group('workout', () {
    testWidgets('due: name, state, a compact summary, one Start and a quiet Details; no exercise list', (tester) async {
      await pumpApp(tester, await fixture(tester, plans: [plan], workouts: [manualDone()]));
      expect(find.text('Upper body A'), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);
      expect(find.text('5 exercises · 18 planned sets'), findsOneWidget);
      expect(find.text('Week 3 · 50 min planned'), findsOneWidget, reason: 'the plan\'s chosen session length, not an estimate');
      expect(find.textContaining('about'), findsNothing);
      expect(photo('workout'), findsOneWidget);
      for (final gone in ['Bench press', 'Overhead press', 'Barbell row', '4 × 6–8', 'Workout preview', 'Your week', 'Body measurements']) {
        expect(find.text(gone), findsNothing, reason: '$gone belongs to the workout sheet, Train or Me');
      }
      expect(find.textContaining('sets recorded'), findsNothing, reason: 'nothing was recorded for a workout that has not started');
      expect(find.byType(FilledButton), findsOneWidget, reason: 'one filled button on Today');
      expect(find.byKey(const Key('today-start')).hitTestable(), findsOneWidget, reason: 'still due after an unrelated manual workout');
      expect(find.text('Done for today'), findsNothing);
      // The manual workout is its own record, in its own words.
      await tester.scrollUntilVisible(find.text('Manual workout · Recorded · 1 set'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('RECORDED TODAY'), findsOneWidget);

      // Details is the quiet way to the existing workout sheet, where the exercises are (opened in the native journey).
      expect(tester.widget<TextButton>(find.byKey(const Key('today-details'))).onPressed, isNotNull);
      expect(find.widgetWithText(TextButton, 'Details'), findsOneWidget);
    });

    testWidgets('in progress with a plan: recorded sets against the planned total, a ring and one Resume', (tester) async {
      final handle = tester.ensureSemantics();
      final open = openWorkout(plan, 'o3-3', day: day, recordedSets: 6);
      await pumpApp(tester, await fixture(tester, plans: [plan], workouts: [open.workout], sets: open.sets));
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('5 exercises · 18 planned sets'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('of 18 sets'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('recorded'), findsOneWidget, reason: 'recorded, not completed');
      expect(find.byType(ProgressRing), findsOneWidget, reason: 'one restrained ring');
      expect(find.bySemanticsLabel(RegExp('6 of 18 planned sets recorded')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing, reason: 'recorded sets are not a completed workout');
      expect(find.textContaining('completed'), findsNothing);
      expect(find.text('Bench press'), findsNothing, reason: 'no exercise list on Today');
      expect(photo('workout'), findsOneWidget);
      expect(find.byKey(const Key('today-resume')).hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('today-start')), findsNothing);
      expect(find.byKey(const Key('today-details')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('manual, no targets: a count of sets, no percentage and no made-up total', (tester) async {
      Json exercise(int i, String name) => {'id': 'e$i', 'ordinal': i, 'name': name, 'catalogKey': null, 'isDeleted': false};
      Json workout(List<Json> exercises) => {'id': 'w1', 'kind': 'manual', 'title': 'Back', 'dayKey': day, 'startedAtUtc': '${day}T15:00:00Z', 'finishedAtUtc': null, 'isDeleted': false, 'exercises': exercises};
      Json set(int i, String exerciseId) => {'id': 's$i', 'exerciseId': exerciseId, 'workoutId': 'w1', 'reps': 8, 'loadKg': 60, 'performedAtUtc': '${day}T15:0$i:00Z', 'isDeleted': false};

      await pumpApp(tester, await fixture(tester, workouts: [workout([exercise(1, 'Barbell row')])], sets: [set(1, 'e1')]));
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('1 exercise'), findsOneWidget);
      expect(find.text('1 set recorded'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining(' of '), findsNothing, reason: 'no planned total exists, so none is shown');
      expect(find.byType(LinearProgressIndicator), findsNothing, reason: 'nothing to measure against');
      expect(find.byType(ProgressRing), findsNothing);
      expect(find.text('Resume workout'), findsOneWidget);

      await pumpApp(tester, await fixture(tester, workouts: [workout([exercise(1, 'Row'), exercise(2, 'Lat pulldown'), exercise(3, 'Cable row')])], sets: [set(1, 'e1'), set(2, 'e1'), set(3, 'e3')]));
      expect(find.text('3 exercises'), findsOneWidget);
      expect(find.text('3 sets recorded'), findsOneWidget);

      // Nothing added yet: still one honest module and one action.
      await pumpApp(tester, await fixture(tester, workouts: [workout(const [])]));
      expect(find.text('No exercise added yet'), findsOneWidget);
      expect(find.textContaining('recorded'), findsNothing);
    });

    testWidgets('done, rest, paused and no plan are said in words, with no training photograph', (tester) async {
      await pumpApp(tester, await fixture(tester, plans: [blockPlan(start: '2026-09-21', recorded: 9)]));
      expect(find.text('Done for today'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget, reason: 'an icon and a word, not a colour alone');
      expect(find.textContaining('Finished: all planned sets recorded.'), findsOneWidget);
      expect(photo('workout'), findsNothing);
      expect(find.byKey(const Key('today-start')), findsNothing);
      expect(find.byKey(const Key('today-resume')), findsNothing);

      await pumpApp(tester, await fixture(tester, plans: [blockPlan(start: '2026-09-22', recorded: 8)]));
      expect(find.text('Rest today'), findsOneWidget);
      expect(find.text('Recovery day'), findsOneWidget);
      expect(photo('workout'), findsNothing);
      expect(find.byKey(const Key('today-start')), findsNothing);
      expect(find.byKey(const Key('today-manual')), findsOneWidget, reason: 'a manual workout stays one tap away');
      expect(find.byKey(const Key('today-run')), findsOneWidget, reason: 'running stays available on a rest day');
      expect(photo('run'), findsOneWidget);

      await pumpApp(tester, await fixture(tester, plans: [{...plan, 'lifecycle': 'paused', 'pausedOn': '2026-10-10'}]));
      expect(find.text('Plan paused'), findsOneWidget);
      expect(find.text('Strength block'), findsOneWidget);
      expect(photo('workout'), findsNothing);
      expect(find.byKey(const Key('today-start')), findsNothing);
      expect(find.byKey(const Key('today-manual')), findsOneWidget);

      await pumpApp(tester, await fixture(tester));
      expect(find.text('No plan yet'), findsOneWidget);
      expect(photo('workout'), findsNothing);
      expect(find.byKey(const Key('today-create-plan')), findsOneWidget);
      expect(find.byKey(const Key('today-manual')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a workout saved for later stays reachable without taking over the day', (tester) async {
      final open = openWorkout(plan, 'o3-3', day: day);
      await pumpApp(tester, await fixture(tester, plans: [plan], workouts: [open.workout], runtime: {'w-open': {'isPaused': true, 'isParked': true}}));
      expect(find.byKey(const Key('today-resume')), findsNothing);
      expect(find.text('Saved for later · started Sun, Oct 11'), findsOneWidget);
    });

    test('a manual workout recorded today never completes the scheduled workout', () {
      final p = Plan(plan);
      TrainingAction resolve(List<Json> workouts) => resolveTraining(today: day, ctx: TrainingCtx({'contextRevision': 1, 'primaryPlanId': 'p1'}), plans: [p], workouts: [for (final w in workouts) Workout(w)]);
      final due = resolve([manualDone()]);
      expect(due, isA<WorkoutDue>());
      expect((due as WorkoutDue).occasion.title, 'Upper body A');
      // Not even a manual workout that happens to carry a full outcome: it is tied to no occasion.
      expect(resolve([{...manualDone(), 'outcome': 'full', 'qualifiedOccasion': true}]), isA<WorkoutDue>());
      // Only a workout recorded for that occasion does.
      final done = resolve([{...manualDone(), 'kind': 'planned', 'planId': 'p1', 'occasionId': 'o3-3', 'outcome': 'partial', 'qualifiedOccasion': true}]);
      expect(done, isA<DoneToday>());
      expect((done as DoneToday).outcome, 'partial');
    });
  });

  group('run', () {
    testWidgets('one Start run on a day without a run; no target, percentage or route is made up', (tester) async {
      await pumpApp(tester, await fixture(tester));
      expect(find.widgetWithText(OutlinedButton, 'Start run'), findsOneWidget);
      expect(find.text('No run today'), findsOneWidget);
      expect(find.byKey(const Key('today-run')), findsOneWidget, reason: 'one running entry point');
      final module = find.byKey(const Key('today-module-run'));
      for (final invented in ['Distance', 'Time']) {
        expect(find.descendant(of: module, matching: find.text(invented)), findsNothing, reason: invented);
      }
      expect(find.descendant(of: module, matching: find.textContaining('%')), findsNothing);
      expect(find.descendant(of: module, matching: find.byType(LinearProgressIndicator)), findsNothing);

      await tester.tap(find.byKey(const Key('today-run-history')));
      await tester.pumpAndSettle();
      expect(find.byType(RunHistoryScreen), findsOneWidget, reason: 'history is the existing screen');
    });

    testWidgets('a run finished today shows its saved distance and time, and is not repeated below', (tester) async {
      await pumpApp(tester, await fixture(tester, runs: [run('r0', day, open: false)]));
      expect(find.text('Finished today'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Start run'), findsOneWidget);
      expect(find.text('RECORDED TODAY'), findsNothing, reason: 'a single run is said once, on its module');

      await pumpApp(tester, await fixture(tester, runs: [run('r0', day, open: false, meters: null)]));
      expect(find.text('Distance'), findsNothing, reason: 'a distance that was not recorded is not shown as zero');
      expect(find.text('30 min'), findsOneWidget);
    });

    testWidgets('an open run is continued, whatever day it began, with only what was saved', (tester) async {
      // A rest day, with a run begun yesterday and still open (as after closing and reopening the app).
      final rest = blockPlan(start: '2026-09-22', recorded: 8);
      await pumpApp(tester, await fixture(tester, plans: [rest], runs: [run('r1', '2026-10-10'), run('r0', day, open: false)]));
      expect(find.text('Rest today'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Continue run'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Started Sat, Oct 10'), findsOneWidget);
      expect(find.text('Distance'), findsNothing, reason: 'no distance is claimed before one was measured');
      expect(find.text('Time'), findsNothing, reason: 'no saved clock on this phone, so no time is guessed');
      expect(find.text('5.00 km'), findsNothing, reason: 'the finished run does not lend its values to the open one');
      expect(find.text('Start run'), findsNothing, reason: 'an open run is never started twice');
      expect(find.byKey(const Key('today-run')), findsOneWidget, reason: 'one way into the open run, not two');
      expect(find.text('RECORDED TODAY'), findsNothing, reason: 'the open run is not listed as recorded');

      // The same run with its saved clock and measured distance.
      await pumpApp(tester, await fixture(tester, runs: [run('r1', '2026-10-10')], runtime: {'r1': pausedRun}));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('5.20 km'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('31 min'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Continue run'), findsOneWidget);

      // Continue opens that run, not a new one.
      await tester.tap(find.byKey(const Key('today-run')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<RunScreen>(find.byType(RunScreen)).runId, 'r1');
      expect(find.byKey(const Key('run-finish')), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // stops the run screen's display timer
      expect(tester.takeException(), isNull);
    });

    testWidgets('several runs finished today are listed once each under Recorded today', (tester) async {
      await pumpApp(tester, await fixture(tester, runs: [run('r0', day, open: false), run('r2', day, open: false, meters: 3000)]), size: const Size(390, 1400));
      expect(find.text('RECORDED TODAY'), findsOneWidget);
      expect(find.text('30 min · 5.00 km'), findsOneWidget);
      expect(find.text('30 min · 3.00 km'), findsOneWidget);
    });
  });

  group('nutrition', () {
    Widget summary(List<FoodEntry> entries, {int? calorieGoal, int? proteinGoal}) {
      final coverage = NutrientCoverage.calculate(entries);
      return Scaffold(body: Column(children: [NutritionSummary(coverage: coverage, calorieGoal: calorieGoal, proteinGoal: proteinGoal), NutritionMissingNote(coverage: coverage, onDetails: () {})]));
    }

    double rail(WidgetTester tester, String nutrient) =>
        tester.widget<LinearProgressIndicator>(find.descendant(of: find.byKey(Key('today-goal-$nutrient')), matching: find.byType(LinearProgressIndicator))).value!;

    testWidgets('unknown is a dash and never zero; a partial sum is called known', (tester) async {
      await pumpApp(tester, const [], home: summary([FoodEntry(foodEntry('a', day, 'Lunch', 'Rice', '1 bowl', calories: 400)), FoodEntry(foodEntry('b', day, 'Lunch', 'Toast', '2 slices'))], calorieGoal: 2200, proteinGoal: 140));
      expect(find.text('400'), findsOneWidget);
      expect(find.text('/ 2,200 kcal · known'), findsOneWidget);
      expect(find.text('—'), findsOneWidget, reason: 'protein is unknown, not zero');
      expect(find.text('/ 140 g protein'), findsOneWidget);
      expect(rail(tester, 'protein'), 0);
      expect(find.textContaining('left'), findsNothing, reason: 'what is left is Eat\'s to say, and only from complete totals');
      expect(find.text('Some nutrition values are missing'), findsOneWidget);

      await pumpApp(tester, const [], home: summary([FoodEntry(foodEntry('c', day, 'Lunch', 'Mystery', '1'))]));
      expect(find.text('No nutrition values entered yet'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a bar only for a goal that was set; over the goal it stays full and the number is the real one', (tester) async {
      final entries = [FoodEntry(foodEntry('a', day, 'Lunch', 'Feast', '1', calories: 2500, protein: 70, carbs: 200, fat: 90))];
      await pumpApp(tester, const [], home: summary(entries));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('2,500'), findsOneWidget);
      expect(find.text('kcal'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
      expect(find.text('g protein'), findsOneWidget);
      expect(find.byKey(const Key('today-nutrition-missing')), findsNothing, reason: 'every value is known');

      await pumpApp(tester, const [], home: summary(entries, proteinGoal: 140));
      expect(find.byKey(const Key('today-goal-calories')), findsNothing);
      expect(rail(tester, 'protein'), 0.5);

      await pumpApp(tester, const [], home: summary(entries, calorieGoal: 2200, proteinGoal: 140));
      expect(rail(tester, 'calories'), 1.0);
      expect(find.text('2,500'), findsOneWidget);
      expect(find.text('/ 2,200 kcal'), findsOneWidget);
    });

    testWidgets('Today: a calm empty state, real values once food is logged, one Log food, and missing values lead to Eat', (tester) async {
      await pumpApp(tester, await fixture(tester, plans: [plan], calorieGoal: 2200));
      expect(find.text('No food logged today'), findsOneWidget);
      expect(find.text('Your daily goal: 2,200 kcal'), findsOneWidget, reason: 'a goal that was set is named; none is invented');
      final module = find.byKey(const Key('today-module-nutrition'));
      expect(find.descendant(of: module, matching: find.byType(LinearProgressIndicator)), findsNothing, reason: 'nothing logged is not zero eaten');
      expect(find.descendant(of: module, matching: find.text('0')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('log-food')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('log-food')).hitTestable(), findsOneWidget);

      final container = await pumpApp(tester, await fixture(tester, plans: [plan], food: food, calorieGoal: 2200));
      expect(find.text('510'), findsOneWidget);
      expect(find.text('/ 2,200 kcal'), findsOneWidget, reason: 'calories are complete');
      expect(find.text('25'), findsOneWidget);
      expect(find.text('g protein · known'), findsOneWidget, reason: 'one food has no protein value');
      expect(find.byKey(const Key('today-goal-calories')), findsOneWidget);
      expect(find.byKey(const Key('today-goal-protein')), findsNothing, reason: 'no protein goal was set, so no bar');
      await tester.ensureVisible(find.byKey(const Key('log-food')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('log-food')).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('today-nutrition-missing')));
      await tester.pumpAndSettle();
      expect(container.read(shellProvider).tab, 2, reason: 'the details are in Eat');
    });
  });

  testWidgets('photographs are decoded for the small crop they are drawn in, and are not announced', (tester) async {
    final handle = tester.ensureSemantics();
    final open = openWorkout(plan, 'o3-3', day: day, recordedSets: 6);
    await pumpApp(tester, await fixture(tester, plans: [plan], workouts: [open.workout], sets: open.sets, food: food));
    for (final module in ['workout', 'run', 'nutrition']) {
      final box = tester.getSize(photo(module));
      expect(box.width, 84, reason: 'a supporting crop, not a header');
      final image = tester.widget<Image>(find.descendant(of: photo(module), matching: find.byType(Image)));
      expect(image.fit, BoxFit.cover);
      final decoded = (image.image as ResizeImage).width!;
      expect(decoded, lessThan(390), reason: '$module is not decoded at the width of the screen');
      expect(decoded, greaterThanOrEqualTo(box.height * 1.5), reason: 'enough pixels to cover a ${box.width} × ${box.height} crop of a 3:2 picture');
      expect(find.descendant(of: photo(module), matching: find.bySemanticsLabel(RegExp('.'))), findsNothing);
    }
    handle.dispose();
  });

  testWidgets('nothing overflows at twice the text size on a 320 px phone, and the photographs give way to the words', (tester) async {
    final open = openWorkout(plan, 'o3-3', day: day, recordedSets: 6);
    final long = {...open.workout, 'title': 'Upper body pulling strength with long accessory work'};
    await pumpApp(tester, await fixture(tester, plans: [plan], workouts: [long, manualDone()], sets: open.sets, food: food, calorieGoal: 2200, proteinGoal: 140, runs: [run('r1', day)], runtime: {'r1': pausedRun}),
        size: const Size(320, 3600), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(photo('workout'), findsNothing);
    expect(photo('run'), findsNothing);
    for (final text in ['of 18 sets', '5.20 km', '510', 'Some nutrition values are missing', 'Resume workout', 'Continue run', 'Log food']) {
      expect(find.text(text), findsOneWidget, reason: '$text is still there, not hidden to save space');
    }
    for (final state in [
      await fixture(tester, plans: [blockPlan(start: '2026-09-22', recorded: 8)], runs: [run('r0', day, open: false)]),
      await fixture(tester, calorieGoal: 2200, proteinGoal: 140),
      await fixture(tester, plans: [plan], food: food),
    ]) {
      await pumpApp(tester, state, size: const Size(320, 640), textScale: 2);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    // A narrow phone at normal text keeps a smaller crop.
    await pumpApp(tester, await fixture(tester, plans: [plan]), size: const Size(320, 800));
    expect(tester.getSize(photo('workout')).width, 72);
    expect(tester.takeException(), isNull);
  });

  group('weather', () {
    /// Today in progress on every module, with Weather on for a selected city and fake conditions. Motion is Reduced so
    /// the sky holds still and the screen settles (weather_motion_test covers the moving sky over Today).
    Future<(ProviderContainer, WeatherFakes)> today(WidgetTester tester, {ThemeMode mode = ThemeMode.light}) async {
      final w = WeatherFakes(now: DateTime.utc(2026, 10, 11, 15));
      final store = AppearanceStore(MemorySecretStore())
        ..accent = Accent.pink
        ..mode = mode;
      final open = openWorkout(plan, 'o3-3', day: day, recordedSets: 6);
      final c = await pumpApp(tester, [
        ...await fixture(tester, plans: [plan], workouts: [open.workout], sets: open.sets, food: food, calorieGoal: 2200, proteinGoal: 140, runs: [run('r1', day)], runtime: {'r1': pausedRun},
            more: [appearanceStoreProvider.overrideWithValue(store), devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(MemorySecretStore())..motion = MotionPref.reduced)]),
        ...(await tester.runAsync(() => w.overrides(prefs: const WeatherPrefs(background: TodayBackground.weather, mode: WeatherLocationMode.city, city: quebec))))!,
      ]);
      return (c, w);
    }

    Future<void> weather(WidgetTester tester, ProviderContainer c, WeatherFakes w, String family, bool isDay) async {
      w.answer = (_, _) => w.conditions(family, isDay: isDay);
      await c.read(weatherProvider.notifier).refresh(force: true);
      await tester.pumpAndSettle();
      expect(c.read(todaySceneProvider).key, '$family-${isDay ? 'day' : 'night'}');
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mode.name}: every scene changes the backdrop only; layout, states, accent and navigation stay, and the header keeps its scrim', (tester) async {
        final (c, w) = await today(tester, mode: mode);
        const keys = ['today-header', 'today-greeting', 'today-module-workout', 'today-module-run', 'today-module-nutrition', 'today-resume', 'today-details', 'today-run', 'log-food', 'nav-today'];
        Map<String, Rect> layout() => {for (final k in keys) k: tester.getRect(find.byKey(Key(k)))};
        // Everything but the line naming the weather, which is meant to change with it.
        List<String?> words() => [
              for (final e in find.descendant(of: find.byType(TodayScreen), matching: find.byType(Text)).evaluate())
                if (find.descendant(of: find.byKey(const Key('today-sky-line')), matching: find.byWidget(e.widget)).evaluate().isEmpty) (e.widget as Text).data
            ];
        GoColors colors() => Theme.of(tester.element(find.byType(TodayScreen))).extension<GoColors>()!;
        final (before, said, look) = (layout(), words(), colors().accent);
        expect(said, containsAll(['In progress', 'Paused', '33%', 'Resume workout', 'Continue run', '/ 2,200 kcal']));
        for (final family in weatherFamilies) {
          for (final isDay in [true, false]) {
            await weather(tester, c, w, family, isDay);
            final where = '$family ${isDay ? 'day' : 'night'}';
            expect(layout(), before, reason: '$where: nothing moves');
            expect(words(), said, reason: '$where: the same states and values');
            expect(colors().accent, look, reason: '$where: the chosen accent stays');
            expect(c.read(shellProvider).tab, 0);
            // The scene fills the tab behind everything. The sections keep the app's own look on their surface whatever
            // the sky; the header's lines sit on its page-coloured scrim in the sky's text colour (weather_contrast_test
            // measures both over every scene and theme).
            expect(tester.getRect(find.byType(SceneBackdrop)), Offset.zero & tester.getSize(find.byType(TodayScreen)));
            expect(Theme.of(tester.element(find.byKey(const Key('today-module-workout')))).brightness, mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
                reason: '$where: the sections keep the app\'s look');
            expect(tester.widget<TabHeader>(find.descendant(of: find.byType(TodayScreen), matching: find.byType(TabHeader))).onBackdrop, isTrue);
            // The header's lines follow the sky, not the app's mode: light over a dark sky, dark over a light one.
            final sky = goTheme(Accent.pink, c.read(todaySceneProvider).dark ? Brightness.dark : Brightness.light).extension<GoColors>()!;
            expect(tester.widget<Text>(find.byKey(const Key('today-greeting'))).style!.color, sky.text, reason: '$where: header text follows the sky');
            expect(find.descendant(of: find.byKey(const Key('today-sky-line')), matching: find.text(c.read(todaySceneProvider).label!)), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        }
        expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no scene keeps animating');
      });
    }

    testWidgets('a clear night stays a night with light text in Light mode, and a clear day keeps dark text in Dark mode', (tester) async {
      Color greeting() => tester.widget<Text>(find.byKey(const Key('today-greeting'))).style!.color!;
      final light = goTheme(Accent.pink, Brightness.light).extension<GoColors>()!, dark = goTheme(Accent.pink, Brightness.dark).extension<GoColors>()!;
      final (c, w) = await today(tester, mode: ThemeMode.light);
      await weather(tester, c, w, 'clear', false);
      expect(greeting(), dark.text, reason: 'night at the place: light lines, although the app is in Light mode');
      await weather(tester, c, w, 'clear', true);
      expect(greeting(), light.text);
    });

    testWidgets('the sky line names real weather, or says it is the scenic view and why; nothing for Scenic', (tester) async {
      final (c, w) = await today(tester);
      w.answer = (_, _) => w.conditions('cloudy', code: 2, description: 'Partly cloudy');
      await c.read(weatherProvider.notifier).refresh(force: true);
      await tester.pumpAndSettle();
      expect(c.read(todaySceneProvider).key, 'partly-day', reason: 'WMO 2 is partly cloudy, not overcast');
      expect(find.descendant(of: find.byKey(const Key('today-sky-line')), matching: find.text('Partly cloudy')), findsOneWidget);

      w.clock.advance(const Duration(minutes: 70)); // the kept answer is now too old, and the next attempt fails
      w.failWith = offline;
      await c.read(weatherProvider.notifier).refresh(force: true);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('today-sky-line')), matching: find.text('Scenic view · Weather could not be reached')), findsOneWidget);

      c.read(weatherPrefsProvider.notifier).setBackground(TodayBackground.scenic);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-sky-line')), findsNothing);
    });

    testWidgets('a new scene keeps the scroll position and what is open', (tester) async {
      final (c, w) = await today(tester);
      c.read(connectionProvider.notifier).report(false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today-connection')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-connection-retry')), findsOneWidget);
      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -150));
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(list).position.pixels;
      expect(offset, greaterThan(0));
      await weather(tester, c, w, 'rain', false);
      await weather(tester, c, w, 'snow', true);
      expect(tester.state<ScrollableState>(list).position.pixels, offset);
      expect(find.byKey(const Key('today-connection-retry')), findsOneWidget, reason: 'the open details stay open');
    });
  });

  testWidgets('the week calendar and its progress are in Train › Plan', (tester) async {
    await pumpApp(tester, await fixture(tester, plans: [plan]), size: const Size(390, 1900));
    expect(find.byType(WeekDayStrip), findsNothing);
    await tester.tap(find.byKey(const Key('nav-train')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('train-plan')));
    await tester.pumpAndSettle();
    expect(find.byType(WeekDayStrip), findsOneWidget);
    expect(find.text('2 of 3 completed'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
  });

  testWidgets('an unreachable account is one line until it is opened, and keeps the count of waiting changes', (tester) async {
    final container = await pumpApp(tester, await fixture(tester));
    expect(find.byKey(const Key('today-connection')), findsNothing, reason: 'nothing is claimed before an attempt has failed');
    container.read(connectionProvider.notifier).report(false);
    await tester.pumpAndSettle();
    expect(find.text('Can\'t sync right now'), findsOneWidget);
    expect(find.textContaining('Offline'), findsNothing, reason: 'a failed attempt does not prove the phone is offline');
    expect(find.text('Try again'), findsNothing);
    await tester.tap(find.byKey(const Key('today-connection')));
    await tester.pumpAndSettle();
    expect(find.textContaining('saved on this phone'), findsOneWidget);
    expect(find.byKey(const Key('today-connection-retry')), findsOneWidget);

    // Me says the same thing in the same words, and does not claim the account has everything while it cannot be asked.
    await tester.tap(find.byKey(const Key('nav-me')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('me-sync')), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Can\'t sync right now · tap to try again'), findsOneWidget);
    expect(find.text('Everything is saved to your account'), findsNothing);
    expect(find.textContaining('Offline'), findsNothing);

    final waiting = await pumpApp(tester, await fixture(tester, pending: 2));
    waiting.read(connectionProvider.notifier).report(false);
    await tester.pumpAndSettle();
    expect(find.text('Can\'t sync right now · 2 changes waiting to sync'), findsOneWidget);
  });
}
