import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart' show Accent;
import 'package:gohard_rebuild/data/models.dart' show Json;
import 'package:gohard_rebuild/data/session.dart' show MemorySecretStore;
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart' show NutritionSurface;
import 'package:gohard_rebuild/features/nutrition/target_helper.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

/// Renders of Today's and Eat's nutrition summaries for docs/NUTRITION_RINGS.md, with the app's real fonts on a notched
/// phone (390 × 844) and at 320 px with twice the text. FIXTURES, not phone captures. Only keys that exist before and
/// after the change are used, so the same file renders `main` (before) and the branch (after):
///
///   flutter test test/nutrition_rings_render_test.dart --dart-define=GOHARD_RENDER=true [--dart-define=GOHARD_RENDER_TAG=before]
///       [--dart-define=GOHARD_RENDER_LANG=fr|ar]
///
/// Every render also fails on a layout overflow.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _tag = String.fromEnvironment('GOHARD_RENDER_TAG', defaultValue: 'after');
const _out = '../docs/evidence/nutrition-rings/$_tag/${renderLanguage == '' ? 'en' : renderLanguage}';
const _day = '2026-11-19';

Json _f(String id, String name, {num? kcal, num? protein, num? carbs, num? fat}) => foodEntry(id, _day, 'Lunch', name, '1 plate', calories: kcal, protein: protein, carbs: carbs, fat: fat);

/// Each state: the day's food and the goals.
final _states = <String, (List<Json>, int?, int?)>{
  'below': ([_f('a', 'Chicken and rice', kcal: 1020, protein: 60, carbs: 120, fat: 38)], 2300, 160),
  'approaching': ([_f('a', 'Chicken and rice', kcal: 1950, protein: 135, carbs: 210, fat: 62)], 2300, 160),
  'reached': ([_f('a', 'Chicken and rice', kcal: 2300, protein: 160, carbs: 250, fat: 75)], 2300, 160),
  // 2,461 / 2,300 kcal = 107 %; the macros give 2,595 kcal, so the recorded total and the split differ (said so).
  'above': ([_f('a', 'Chicken and rice', kcal: 2461, protein: 175, carbs: 260, fat: 95)], 2300, 160),
  'nogoals': ([_f('a', 'Chicken and rice', kcal: 1650, protein: 120, carbs: 180, fat: 50)], null, null),
  // Calories and fat unknown for one food; protein complete.
  'incomplete': ([_f('a', 'Chicken and rice', kcal: 1200, protein: 90, carbs: 130, fat: 40), _f('b', 'Corner shop flapjack', protein: 6, carbs: 30)], 2300, 160),
};

Future<void> _shot(WidgetTester tester, String name) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.takeException(), isNull, reason: name);
  final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
  await tester.runAsync(() async {
    final file = File('$_out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
}

/// [key]'s top at [alignment] of the screen (the first of [keys] that exists).
Future<void> _to(WidgetTester tester, List<String> keys, {double alignment = 0.02}) => _toFinder(tester, [for (final k in keys) find.byKey(Key(k))], alignment: alignment);

Future<void> _toFinder(WidgetTester tester, List<Finder> finders, {double alignment = 0.02}) async {
  // The lists are lazy: scroll down until one of them is built.
  for (var i = 0; i < 20 && !finders.any((f) => f.evaluate().isNotEmpty); i++) {
    await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  final found = finders.firstWhere((f) => f.evaluate().isNotEmpty);
  await tester.runAsync(() => Scrollable.ensureVisible(tester.element(found), alignment: alignment));
  await tester.pumpAndSettle();
}

Future<void> _app(WidgetTester tester, String state, {ThemeMode mode = ThemeMode.light, Accent accent = Accent.blue, Size size = const Size(390, 844), double text = 1}) async {
  final (food, kcal, protein) = _states[state]!;
  final appearance = AppearanceStore(MemorySecretStore())
    ..mode = mode
    ..accent = accent;
  final overrides = (await tester.runAsync(() => overridesFor(day: _day, food: food, calorieGoal: kcal, proteinGoal: protein, appearance: appearance)))!;
  final c = await pumpApp(tester, [...overrides, ...FoodFakes().overrides], size: size, textScale: text, insets: phoneInsets);
  // The one-time Eat hints are not what these renders are about.
  for (final id in ['eat.first', 'eat.saved.new', 'eat.saved.shortcut', 'eat.history', 'eat.meals', 'eat.out', 'eat.habits', 'eat.reminders', 'eat.trends']) {
    c.read(coachPrefsProvider.notifier).markSeen('one', id);
  }
  await tester.pumpAndSettle();
}

Future<void> _eat(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-eat')));
  await tester.pumpAndSettle();
}

class _Launcher extends StatelessWidget {
  const _Launcher();
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(child: TextButton(key: const Key('open'), onPressed: () => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const TargetHelperScreen())), child: const Text('open'))));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  if (!_enabled) {
    test('nutrition ring renders are skipped without GOHARD_RENDER', () {});
    return;
  }
  setUpAll(loadAppFonts);

  if (renderLanguage == '') {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final m = mode.name;
      for (final state in _states.keys) {
        testWidgets('$m $state: Today and Eat', (tester) async {
          await _app(tester, state, mode: mode);
          await _to(tester, ['today-module-nutrition'], alignment: 0.3);
          await _shot(tester, 'today-$state-$m');
          await _eat(tester);
          await _to(tester, ['eat-nutrition-heading'], alignment: 0.1);
          await _shot(tester, 'eat-$state-$m');
          if (state == 'above' || state == 'incomplete') {
            await _tap(tester, 'eat-details'); // the composition is in Nutrition details
            await _to(tester, ['eat-macros', 'eat-more-nutrients'], alignment: 0.35);
            await _shot(tester, 'eat-macros-$state-$m');
          }
        });
      }

      testWidgets('$m: the estimated target split', (tester) async {
        final overrides = (await tester.runAsync(() => overridesFor(day: _day, appearance: AppearanceStore(MemorySecretStore())..mode = mode)))!;
        await pumpApp(tester, [...overrides, profileRepositoryProvider.overrideWithValue(RecordingProfiles())], home: const _Launcher(), size: const Size(390, 844), insets: phoneInsets);
        await _tap(tester, 'open');
        await _tap(tester, 'tgt-goal-lose');
        await _tap(tester, 'tgt-continue');
        await tester.enterText(find.byKey(const Key('tgt-age')), '34');
        await tester.enterText(find.byKey(const Key('tgt-height-cm')), '170');
        await _tap(tester, 'tgt-weight-unit-lb');
        await tester.enterText(find.byKey(const Key('tgt-weight')), '199');
        await _tap(tester, 'tgt-sex-male');
        await _tap(tester, 'tgt-activity-inactive');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -4000));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tgt-continue')));
        await tester.pumpAndSettle();
        await _tap(tester, 'tgt-macros');
        await _to(tester, ['tgt-macros']);
        await _shot(tester, 'target-split-$m');
      });
    }

    // Every theme: Eat's panel above the target, where all three goal colours and the macro colours meet the panel.
    for (final accent in Accent.values) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('theme ${accent.name} ${mode.name}', (tester) async {
          await _app(tester, 'above', mode: mode, accent: accent);
          await _eat(tester);
          await _to(tester, ['eat-nutrition-heading'], alignment: 0.02);
          await _shot(tester, 'theme-${accent.name}-${mode.name}');
        });
      }
    }
  }

  // Every language at a typical width with normal text: the longest wording side by side.
  for (final state in ['above', 'incomplete']) {
    testWidgets('390 px, normal text: $state', (tester) async {
      await _app(tester, state);
      await _to(tester, ['today-module-nutrition'], alignment: 0.3);
      await _shot(tester, 'today-$state-390');
      await _eat(tester);
      await _toFinder(tester, [find.byType(NutritionSurface)]);
      await _shot(tester, 'eat-$state-390');
    });
  }

  // French and Arabic (and English) at 320 px with twice the text.
  for (final state in ['below', 'incomplete']) {
    testWidgets('320 px, twice the text: $state', (tester) async {
      await _app(tester, state, size: const Size(320, 900), text: 2);
      await _to(tester, ['today-module-nutrition']);
      await _shot(tester, 'today-$state-320-2x');
      await _eat(tester);
      // The panel's own top (Eat's summary has no photograph).
      await _toFinder(tester, [find.byType(NutritionSurface)]);
      await _shot(tester, 'eat-$state-320-2x');
      await _tap(tester, 'eat-details'); // the composition is in Nutrition details
      await _to(tester, ['eat-macros', 'eat-more-nutrients']);
      await _shot(tester, 'eat-macros-$state-320-2x');
    });
  }
}
