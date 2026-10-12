import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/nutrition/food_form.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/plans/plan_progress.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';

import 'ui_support.dart';

const _day = '2026-10-11';

/// WCAG contrast ratio of `fg` drawn on `bg` (a translucent `fg` is blended first).
double contrast(Color fg, Color bg) {
  final a = Color.alphaBlend(fg, bg).computeLuminance(), b = bg.computeLuminance();
  return ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _openAppearance(WidgetTester tester) async {
  await _tap(tester, 'nav-me');
  await tester.scrollUntilVisible(find.byKey(const Key('me-appearance')), 200, scrollable: find.byType(Scrollable).last);
  await tester.ensureVisible(find.byKey(const Key('me-appearance')));
  await tester.pumpAndSettle();
  await _tap(tester, 'me-appearance');
}

/// The appearance controller over a given store, outside any widget.
class ProviderContainerFor {
  ProviderContainerFor(AppearanceStore store) : _c = ProviderContainer(overrides: [appearanceStoreProvider.overrideWithValue(store)]);
  final ProviderContainer _c;
  AppearanceController get controller => _c.read(appearanceProvider.notifier);
  Appearance get state => _c.read(appearanceProvider);
}

GoColors _colors(WidgetTester tester) => Theme.of(tester.element(find.byType(Scaffold).first)).extension<GoColors>()!;

void main() {
  group('measured contrast of every token pair the app draws', () {
    for (final accent in Accent.values) {
      for (final brightness in Brightness.values) {
        for (final high in [false, true]) {
          test('${accent.name} ${brightness.name}${high ? ' increased contrast' : ''}', () {
            final c = GoColors.of(accent, brightness, highContrast: high);
            void atLeast(double min, Color fg, Color bg, String what) =>
                expect(contrast(fg, bg), greaterThanOrEqualTo(min), reason: '$what is ${contrast(fg, bg).toStringAsFixed(2)}:1');
            // Text: 4.5:1 on every surface it is drawn on.
            for (final (name, bg) in [('page', c.page), ('surface', c.surface), ('sunken', c.sunken), ('selection tint', c.accentSoft)]) {
              atLeast(4.5, c.text, bg, 'text on $name');
              atLeast(4.5, c.secondary, bg, 'secondary text on $name');
              atLeast(4.5, c.success, bg, 'success on $name');
              atLeast(4.5, c.warning, bg, 'warning on $name');
              atLeast(4.5, c.error, bg, 'error on $name');
            }
            for (final (name, bg) in [('page', c.page), ('surface', c.surface), ('selection tint', c.accentSoft)]) {
              atLeast(4.5, c.accent, bg, 'accent text on $name');
            }
            atLeast(4.5, c.onAccent, c.accent, 'label on a filled accent control');
            atLeast(4.5, GoColors.onPass, c.passTop, 'text on the pass');
            atLeast(4.5, const Color(0xE6FFFFFF), c.passTop, 'secondary text on the pass');
            // Controls and graphics: 3:1 against what they sit next to.
            atLeast(3, c.outline, c.page, 'control boundary on page');
            atLeast(3, c.outline, c.surface, 'control boundary on surface');
            atLeast(3, c.accent, c.sunken, 'selected segment / progress fill against its track');
            atLeast(3, c.passFill, Color.alphaBlend(const Color(0x59000000), c.passBottom), 'pass progress fill against its track');
            atLeast(3, c.passFill, Color.alphaBlend(const Color(0x59000000), c.passTop), 'pass progress fill against its track (top)');
            // White text on the photograph sits on a floor of at least 82% black, whatever is behind it.
            atLeast(4.5, Colors.white, Color.alphaBlend(const Color(0xD1000000), Colors.white), 'hero text over the brightest possible photograph');
            atLeast(4.5, const Color(0xE6FFFFFF), Color.alphaBlend(const Color(0xD1000000), Colors.white), 'hero secondary text');
          });
        }
      }
    }

    test('status colours are not the accent, and the dark pass is a deep shade, not the bright control colour', () {
      for (final accent in Accent.values) {
        for (final b in Brightness.values) {
          final c = GoColors.of(accent, b);
          expect({c.success, c.warning, c.error}.contains(c.accent), isFalse);
        }
        final dark = GoColors.of(accent, Brightness.dark);
        expect(dark.passTop.computeLuminance(), lessThan(0.08));
        expect(dark.passTop.computeLuminance(), lessThan(dark.accent.computeLuminance() / 4));
      }
    });
  });

  group('appearance preference', () {
    test('a fresh install is Blue + System, and both choices survive a restart', () async {
      final disk = MemorySecretStore();
      final first = AppearanceStore(disk);
      await first.restore(signedIn: false);
      expect((first.accent, first.mode), (Accent.blue, null), reason: 'no mode chosen yet means follow the phone');

      first
        ..accent = Accent.pink
        ..mode = ThemeMode.dark;
      await first.save();
      final relaunched = AppearanceStore(disk);
      await relaunched.restore(signedIn: true);
      expect((relaunched.accent, relaunched.mode), (Accent.pink, ThemeMode.dark));
    });

    test('an unreadable saved value falls back to the defaults instead of failing startup', () async {
      final disk = MemorySecretStore()..values['gohard.rebuild.appearance'] = 'teal|sideways|x';
      final store = AppearanceStore(disk);
      await store.restore(signedIn: false);
      expect((store.accent, store.mode), (Accent.blue, null));
    });

    testWidgets('choices apply at once everywhere, are saved, and do not reset navigation', (tester) async {
      final disk = MemorySecretStore();
      final store = AppearanceStore(disk);
      final plan = blockPlan(start: '2026-09-21', recorded: 8);
      final container = await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1', appearance: store)))!);
      await _tap(tester, 'nav-train');
      await _tap(tester, 'train-plan');
      await _openAppearance(tester);

      await _tap(tester, 'accent-green');
      await _tap(tester, 'appearance-dark');
      expect(_colors(tester).accent, GoColors.of(Accent.green, Brightness.dark).accent);
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
      // The selected segment uses the chosen accent, not a fixed blue.
      final segment = tester.widget<AnimatedContainer>(find.descendant(of: find.byKey(const Key('appearance-dark')), matching: find.byType(AnimatedContainer)));
      expect((segment.decoration! as BoxDecoration).color, GoColors.of(Accent.green, Brightness.dark).accent);
      expect(tester.getSemantics(find.byKey(const Key('accent-green'))), isSemantics(isSelected: true, label: 'Green accent'));
      expect(tester.getSemantics(find.byKey(const Key('accent-blue'))), isSemantics(isSelected: false));

      expect(disk.values['gohard.rebuild.appearance'], 'green|dark');
      expect(container.read(shellProvider).trainView, TrainView.plan, reason: 'changing the look does not reset where you were');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Green · Dark'), findsOneWidget);
    });

    testWidgets('System follows the phone as it changes and keeps the accent', (tester) async {
      final store = AppearanceStore(MemorySecretStore())..accent = Accent.pink;
      await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, appearance: store)))!);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(_colors(tester).accent, GoColors.of(Accent.pink, Brightness.dark).accent);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(_colors(tester).accent, GoColors.of(Accent.pink, Brightness.light).accent);
      expect(_colors(tester).page, const Color(0xFFF6F6F4));
    });

    test('upgrade: the look an existing install had (Light, Dark or following the phone) is kept exactly', () async {
      for (final (account, expected) in [('light', ThemeMode.light), ('dark', ThemeMode.dark), ('system', ThemeMode.system)]) {
        final disk = MemorySecretStore();
        final store = AppearanceStore(disk);
        await store.restore(signedIn: true); // first launch of this version over a signed-in install
        final app = ProviderContainerFor(store);
        expect(app.state, const Appearance(Accent.blue, ThemeMode.system), reason: 'until the saved profile is read');
        app.controller.adoptAccountAppearance(null); // profile not loaded yet: nothing is decided
        expect(store.migratesAccountMode, isTrue);
        app.controller.adoptAccountAppearance(account);
        expect(app.state, Appearance(Accent.blue, expected), reason: 'account said $account');

        // It is carried over once. After a restart the device setting stands, whatever the account says later.
        final relaunched = AppearanceStore(disk);
        await relaunched.restore(signedIn: true);
        final again = ProviderContainerFor(relaunched);
        again.controller.adoptAccountAppearance(account == 'light' ? 'dark' : 'light');
        expect(again.state.mode, expected);
      }
    });

    test('upgrade interrupted before the profile was read is still an upgrade on the next launch', () async {
      final disk = MemorySecretStore();
      await AppearanceStore(disk).restore(signedIn: true);
      final relaunched = AppearanceStore(disk);
      await relaunched.restore(signedIn: true);
      final app = ProviderContainerFor(relaunched)..controller.adoptAccountAppearance('dark');
      expect(app.state.mode, ThemeMode.dark);
    });

    test('fresh install: Blue + System, and signing in to an account that says dark does not change it', () async {
      final disk = MemorySecretStore();
      final store = AppearanceStore(disk);
      await store.restore(signedIn: false);
      final app = ProviderContainerFor(store)..controller.adoptAccountAppearance('dark');
      expect(app.state, const Appearance(Accent.blue, ThemeMode.system));

      final relaunched = AppearanceStore(disk);
      await relaunched.restore(signedIn: true); // now signed in, but this is not an upgrade
      final again = ProviderContainerFor(relaunched)..controller.adoptAccountAppearance('dark');
      expect(again.state, const Appearance(Accent.blue, ThemeMode.system));
    });

    test('a choice made on this device is never overwritten by the account', () async {
      final store = AppearanceStore(MemorySecretStore());
      await store.restore(signedIn: true);
      final app = ProviderContainerFor(store)..controller.setMode(ThemeMode.dark);
      app.controller.adoptAccountAppearance('light');
      expect(app.state.mode, ThemeMode.dark);
    });

    testWidgets('an open form keeps what was typed when the phone changes mode and when the accent changes', (tester) async {
      final store = AppearanceStore(MemorySecretStore());
      final container = await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, appearance: store)))!,
          home: FoodFormScreen(draft: FoodDraft(dayKey: _day, meal: 'Lunch')));
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.enterText(find.byKey(const Key('food-name')), 'Chicken and rice');
      await tester.enterText(find.byKey(const Key('food-calories')), '650');

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      container.read(appearanceProvider.notifier).setAccent(Accent.pink);
      await tester.pumpAndSettle();

      expect(_colors(tester).accent, GoColors.of(Accent.pink, Brightness.dark).accent, reason: 'the look really changed under the form');
      expect(find.text('Chicken and rice'), findsOneWidget);
      expect(find.text('650'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Log food'), findsOneWidget, reason: 'still the same form, not a rebuilt one');
    });
  });

  group('accessibility of the main destinations', () {
    for (final accent in Accent.values) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('${accent.name} ${mode.name}: rendered text contrast, tap targets and labels', (tester) async {
          final handle = tester.ensureSemantics();
          final plan = blockPlan(start: '2026-09-21', recorded: 8);
          final open = openWorkout(plan, 'o3-3', day: _day, recordedSets: 6);
          final store = AppearanceStore(MemorySecretStore())
            ..accent = accent
            ..mode = mode;
          await pumpApp(
              tester,
              (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1', workouts: [open.workout], sets: open.sets, appearance: store,
                  food: [foodEntry('f1', _day, 'Lunch', 'Chicken and rice', '1 plate', calories: 650, protein: 48)])))!,
              size: const Size(390, 1800));
          for (final tab in ['today', 'train', 'eat', 'me']) {
            await _tap(tester, 'nav-$tab');
            if (tab == 'train') await _tap(tester, 'train-plan');
            await expectLater(tester, meetsGuideline(textContrastGuideline), reason: tab);
            await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: tab);
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline), reason: tab);
            await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: tab);
          }
          handle.dispose();
        });
      }
    }

    testWidgets('progress and selection are announced in words', (tester) async {
      final handle = tester.ensureSemantics();
      final plan = blockPlan(start: '2026-09-21', recorded: 8);
      await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1')))!, size: const Size(390, 1800));
      expect(find.bySemanticsLabel(RegExp('Workouts complete this week')), findsOneWidget);
      await _tap(tester, 'nav-train');
      await _tap(tester, 'train-plan');
      expect(find.bySemanticsLabel(RegExp(r'Strength block\. Week\s+3 of 8\. 8 / 24 workouts completed, 33%')), findsOneWidget);
      expect(find.bySemanticsLabel('Week 3, Oct 5 – 11, this week, 2 of 3 workouts completed'), findsOneWidget);
      expect(tester.getSemantics(find.byKey(const Key('week-3'))), isSemantics(isSelected: true, isButton: true));
      expect(find.bySemanticsLabel(RegExp('Sunday, October 11, today, Upper body A, Due')), findsOneWidget);
      handle.dispose();
    });
  });

  group('progress is built from recorded work', () {
    final plan = Plan(blockPlan(start: '2026-09-23', weeks: 12, offsets: const [0, 2, 4], recorded: 4)); // starts on a Wednesday

    test('weeks follow the plan start in seven-day steps, with real boundaries and any length', () {
      final weeks = planWeeks(plan, '2026-10-06', const []);
      expect(weeks.length, 12, reason: 'not capped at eight');
      expect((weeks[0].start, weeks[0].end, weeks[0].range), ('2026-09-23', '2026-09-29', 'Sep 23 – 29'));
      expect(weeks[1].range, 'Sep 30 – Oct 6', reason: 'a week that crosses a month names both');
      expect([for (final w in weeks) if (w.isCurrent) w.number], [2], reason: 'the last day of week 2');
      expect([for (final w in planWeeks(plan, '2026-10-07', const [])) if (w.isCurrent) w.number], [3], reason: 'the first day of week 3');
      expect(focusWeek(planWeeks(plan, '2026-09-01', const []))!.number, 1, reason: 'before the start');
      expect(focusWeek(planWeeks(plan, '2027-03-01', const []))!.number, 12, reason: 'after the end');
    });

    test('completion counts recorded results only; skipped is neither completed nor expected', () {
      final j = copyJson(plan.j);
      (j['occasions'] as List)[4]['isSkipped'] = true; // week 2, second workout
      final weeks = planWeeks(Plan(j), '2026-11-20', const []);
      expect((weeks[0].completion.completed, weeks[0].completion.eligible), (3, 3));
      expect((weeks[1].completion.completed, weeks[1].completion.eligible), (1, 2), reason: 'four recorded in all; one skipped');
      expect(weeks[2].completion.completed, 0, reason: 'weeks that have passed without a recorded workout stay at zero');
      final block = Completion.of(Plan(j).occasions, const []);
      expect((block.completed, block.eligible), (4, 35));
    });

    test('a locally finished workout counts before the account acknowledges it; an open one does not', () {
      Workout w(String occasion, {String? outcome}) => Workout({'id': 'w-$occasion', 'occasionId': occasion, 'kind': 'planned', 'title': 't', 'dayKey': _day, 'startedAtUtc': '2026-10-11T10:00:00Z',
            'finishedAtUtc': outcome == null ? null : '2026-10-11T11:00:00Z', 'outcome': outcome, 'qualifiedOccasion': outcome != null});
      expect(Completion.of(plan.occasions, [w('o2-2', outcome: 'partial')]).completed, 5);
      expect(Completion.of(plan.occasions, [w('o2-2')]).completed, 4);
    });

    test('set progress counts recorded sets, never targets, extras or deleted sets', () {
      final open = openWorkout(plan.j, 'o2-2', day: _day, recordedSets: 6);
      final workout = Workout(open.workout);
      expect((SetProgress.of(workout, const []).counted, SetProgress.of(workout, const []).planned), (0, 18), reason: 'targets alone are not performed sets');
      final sets = [for (final s in open.sets) WorkoutSet(s)];
      expect(SetProgress.of(workout, sets).counted, 6);
      // Two extra sets on the first movement (target 4, already has 4) and one deleted set elsewhere.
      final extra = [
        ...sets,
        for (final id in ['x1', 'x2']) WorkoutSet({...open.sets.first, 'id': id}),
        WorkoutSet({...open.sets.last, 'id': 'gone', 'isDeleted': true}),
      ];
      final p = SetProgress.of(workout, extra);
      expect((p.counted, p.recorded, p.planned), (6, 8, 18));
      final manual = Workout({...open.workout, 'exercises': [for (final e in open.workout['exercises'] as List) {...e as Json, 'isPrescribed': false}]});
      expect(SetProgress.of(manual, sets).planned, isNull, reason: 'a manual workout has no planned total to measure against');
    });
  });
}
