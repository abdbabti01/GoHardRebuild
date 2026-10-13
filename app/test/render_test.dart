@Tags(['render'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

/// Renders the real screens with the app's real fonts and photograph into PNG files for design review:
///
///   flutter test test/render_test.dart --dart-define=GOHARD_RENDER=true
///
/// Without that flag it does nothing, so the normal test run stays fast and writes no files. The data is the
/// fixture in ui_support.dart (illustrative, like the design reference), never an account's records. These are
/// renders of the Flutter widgets, not captures from a phone: they show layout and colour, not device behaviour.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/design';
const _today = '2026-10-11';

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await inter.load();
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  await (FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}

Future<ui.Image> _capture(WidgetTester tester) async {
  // The photograph decodes on a real timer; give it one, then paint.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  return (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
}

Future<void> _save(WidgetTester tester, ui.Image image, String name) => tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_out/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });

/// Lays the six theme renders of one screen side by side: light on top, dark below.
Future<ui.Image> _sheet(WidgetTester tester, Map<String, ui.Image> shots) async {
  final images = shots.values.toList();
  final w = images.first.width, h = images.first.height;
  const gap = 36, label = 64;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(const Color(0xFFDADCE0), BlendMode.src);
  for (final (i, entry) in shots.entries.indexed) {
    final x = (gap + (i % 3) * (w + gap)).toDouble(), y = (gap + (i ~/ 3) * (h + gap + label)).toDouble();
    final text = TextPainter(text: TextSpan(text: entry.key, style: const TextStyle(fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFF121417))), textDirection: TextDirection.ltr)..layout();
    text.paint(canvas, Offset(x, y));
    canvas.drawImage(entry.value, Offset(x, y + label), Paint());
  }
  return (await tester.runAsync(() => recorder.endRecording().toImage(gap + 3 * (w + gap), gap + 2 * (h + gap + label))))!;
}

Future<List<Override>> _fixture(WidgetTester tester, Accent accent, ThemeMode mode, {int weeks = 8, bool inProgress = true, String? start, bool cameraRefused = false, bool withFood = true, List<Json> runs = const [], List<Json> extraWorkouts = const [], List<Json> extraSets = const [], int recorded = 8}) async {
  final plan = blockPlan(start: start ?? '2026-09-21', weeks: weeks, recorded: recorded);
  final open = openWorkout(plan, 'o3-3', day: _today, recordedSets: 6);
  final food = [
    foodEntry('f1', _today, 'Breakfast', 'Greek yogurt, berries, granola', '1 bowl', calories: 380, protein: 24, carbs: 46, fat: 9),
    foodEntry('f2', _today, 'Lunch', 'Chicken, rice, vegetables', '1 plate', calories: 650, protein: 48, carbs: 70, fat: 16),
    foodEntry('f3', _today, 'Snack', 'Protein shake, banana', '1 shake', calories: 370, protein: 23, carbs: 42),
    // An earlier day, logged from a searched food: it is what "Recent" offers again.
    {...foodEntry('f0', '2026-10-09', 'Dinner', 'Rice, cooked, NFS', '1 cup, cooked', calories: 203.82, protein: 4.22, carbs: 44.22, fat: 0.44), 'source': {'item': riceCooked().j, 'quantity': 1, 'unit': 'serving:0'}},
  ];
  // The scanner render stands in for the camera with a flat panel: there is no camera in a widget render.
  final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [chickenRaw(), riceCooked(), sparseDrink()], products: {'3017620422003': hazelnutSpread()}), cameraRefused: cameraRefused ? true : null);
  final store = AppearanceStore(MemorySecretStore())
    ..accent = accent
    ..mode = mode;
  return [
    ...(await tester.runAsync(() => overridesFor(
        day: _today, plans: [plan], primaryPlanId: 'p1', workouts: [if (inProgress) open.workout, ...extraWorkouts], sets: [if (inProgress) ...open.sets, ...extraSets], food: withFood ? food : [food.last], runs: runs, appearance: store,
        calorieGoal: 2200, proteinGoal: 140, savedFoods: [savedFood('s-nut', hazelnutSpread(), favourite: true), savedFood('s-oats', ownOats())])))!,
    ...fakes.overrides,
  ];
}

Json _run(String id, {bool open = false}) => {'id': id, 'dayKey': _today, 'startedAtUtc': '${_today}T07:00:00Z', 'finishedAtUtc': open ? null : '${_today}T07:31:00Z', 'activeDurationSeconds': open ? null : 1860, 'distanceMeters': open ? null : 5200, 'isDeleted': false};

/// A manual workout in progress with one movement, no targets, and one recorded set.
const Json _manual = {'id': 'w-manual', 'kind': 'manual', 'title': 'Back', 'dayKey': _today, 'startedAtUtc': '2026-10-11T16:00:00Z', 'finishedAtUtc': null, 'isDeleted': false,
  'exercises': [{'id': 'm1', 'ordinal': 1, 'name': 'Barbell row', 'catalogKey': 'barbell-row', 'isDeleted': false}]};
const Json _manualSet = {'id': 'ms1', 'exerciseId': 'm1', 'workoutId': 'w-manual', 'reps': 8, 'loadKg': 60, 'performedAtUtc': '2026-10-11T16:05:00Z', 'isDeleted': false};

Future<void> _open(WidgetTester tester, String screen) async {
  Future<void> tap(String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  switch (screen) {
    case 'train-plan':
      await tap('nav-train');
      await tap('train-plan');
    case 'train-progress':
      await tap('nav-train');
      await tap('train-progress');
    case 'eat':
      await tap('nav-eat');
    case 'run':
      await tap('today-run');
    case 'run-history':
      await tap('today-run-history');
    case 'log-food' || 'food-results' || 'food-preview' || 'food-preview-unknown' || 'scan':
      await tap('nav-eat');
      await tap('log-food');
      if (screen == 'scan') {
        await tap('food-scan');
      } else if (screen != 'log-food') {
        await tester.enterText(find.byKey(const Key('food-search')), 'rice');
        await tester.pumpAndSettle();
        await tap('food-search-online');
        if (screen == 'food-preview') await tap('result-usda:2708402');
        if (screen == 'food-preview-unknown') await tap('result-off:5449000000996');
      }
    case 'goals':
      await tap('nav-me');
      await tester.scrollUntilVisible(find.byKey(const Key('me-goals')), 200, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(find.byKey(const Key('me-goals')));
      await tester.pumpAndSettle();
      await tap('me-goals');
    case 'me':
      await tap('nav-me');
    case 'motion' || 'units' || 'edit-profile' || 'delete-account':
      await tap('nav-me');
      final key = const {'motion': 'me-motion', 'units': 'me-units', 'edit-profile': 'me-edit-name', 'delete-account': 'me-delete-account'}[screen]!;
      await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tap(key);
    case 'appearance':
      await tap('nav-me');
      await tester.scrollUntilVisible(find.byKey(const Key('me-appearance')), 200, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(find.byKey(const Key('me-appearance')));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tap('me-appearance');
  }
}

void main() {
  if (!_enabled) return;
  setUpAll(_loadFonts);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('state: confirmation dialog ${mode.name}', (tester) async {
      await pumpApp(tester, await _fixture(tester, Accent.blue, mode));
      confirm(tester.element(find.byKey(const Key('nav-today'))),
          title: 'Move this workout?', body: 'Workout: Full body (week 1)\nCurrent date: Friday, October 16\nProposed date: Saturday, October 17\n\nNo other workout changes.',
          action: 'Move workout', cancel: 'Keep current dates').ignore();
      await _save(tester, await _capture(tester), 'state-dialog-${mode.name}');
    });
  }

  for (final screen in ['today', 'train-plan', 'eat', 'me', 'appearance', 'log-food', 'food-results', 'food-preview', 'scan', 'goals']) {
    testWidgets('six themes: $screen', (tester) async {
      final shots = <String, ui.Image>{};
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final accent in Accent.values) {
          await pumpApp(tester, await _fixture(tester, accent, mode));
          await _open(tester, screen);
          final image = await _capture(tester);
          shots['${accent.label} · ${mode == ThemeMode.light ? 'Light' : 'Dark'}'] = image;
          if (accent == Accent.blue) await _save(tester, image, '$screen-blue-${mode.name}');
          await tester.pumpWidget(const SizedBox()); // a fresh app for the next theme
        }
      }
      await _save(tester, await _sheet(tester, shots), 'six-themes-$screen');
    });
  }

  // Whole pages and other states, for checking what sits below the fold and the states a fixture can reach.
  final states = <String, (Future<List<Override>> Function(WidgetTester), String, Size, double)>{
    'full-today-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'today', const Size(390, 1500), 1),
    'full-today-dark': ((t) => _fixture(t, Accent.green, ThemeMode.dark), 'today', const Size(390, 1500), 1),
    'full-plan-light': ((t) => _fixture(t, Accent.pink, ThemeMode.light), 'train-plan', const Size(390, 1900), 1),
    'full-plan-dark': ((t) => _fixture(t, Accent.blue, ThemeMode.dark), 'train-plan', const Size(390, 1900), 1),
    'full-me-light': ((t) => _fixture(t, Accent.green, ThemeMode.light), 'me', const Size(390, 1250), 1),
    'full-me-dark': ((t) => _fixture(t, Accent.pink, ThemeMode.dark), 'me', const Size(390, 1250), 1),
    'large-text-me-320': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'me', const Size(320, 2700), 2),
    'new-account-me': ((t) async => (await t.runAsync(() => overridesFor(day: _today)))!, 'me', const Size(390, 1250), 1),
    'me-motion-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'motion', const Size(390, 844), 1),
    'me-units-sheet-dark': ((t) => _fixture(t, Accent.green, ThemeMode.dark), 'units', const Size(390, 844), 1),
    'me-edit-profile-light': ((t) => _fixture(t, Accent.pink, ThemeMode.light), 'edit-profile', const Size(390, 844), 1),
    'me-delete-account-dark': ((t) => _fixture(t, Accent.blue, ThemeMode.dark), 'delete-account', const Size(390, 844), 1),
    'full-eat-dark': ((t) => _fixture(t, Accent.pink, ThemeMode.dark), 'eat', const Size(390, 1300), 1),
    'full-eat-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'eat', const Size(390, 1300), 1),
    'today-due-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light, inProgress: false), 'today', const Size(390, 1400), 1),
    // Nothing logged yet, an open run, and a pink accent to show nothing is hard-coded blue.
    'today-due-no-food-open-run-pink-dark': ((t) => _fixture(t, Accent.pink, ThemeMode.dark, inProgress: false, withFood: false, runs: [_run('r1', open: true)]), 'today', const Size(390, 1050), 1),
    'today-due-no-food-green-light': ((t) => _fixture(t, Accent.green, ThemeMode.light, inProgress: false, withFood: false, runs: [_run('r0')]), 'today', const Size(390, 1050), 1),
    'run-open-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light, runs: [_run('r1', open: true)]), 'run', const Size(390, 844), 1),
    'run-history-dark': ((t) => _fixture(t, Accent.green, ThemeMode.dark, runs: [_run('r1', open: true), _run('r0')]), 'run-history', const Size(390, 844), 1),
    'today-done-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light, inProgress: false, recorded: 9), 'today', const Size(390, 1300), 1),
    'today-manual-one-exercise-dark': ((t) => _fixture(t, Accent.blue, ThemeMode.dark, inProgress: false, start: '2026-09-22', withFood: false, extraWorkouts: [_manual], extraSets: [_manualSet]), 'today', const Size(390, 1000), 1),
    'today-narrow-320-no-food': ((t) => _fixture(t, Accent.blue, ThemeMode.light, inProgress: false, withFood: false), 'today', const Size(320, 1300), 1),
    'today-rest-dark': ((t) => _fixture(t, Accent.blue, ThemeMode.dark, inProgress: false, start: '2026-09-22'), 'today', const Size(390, 1150), 1),
    'progress-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'train-progress', const Size(390, 1100), 1),
    'plan-12-weeks-mid-week-start': ((t) => _fixture(t, Accent.green, ThemeMode.light, weeks: 12, start: '2026-09-23'), 'train-plan', const Size(390, 1900), 1),
    'plan-16-weeks-collapsed': ((t) => _fixture(t, Accent.blue, ThemeMode.light, weeks: 16), 'train-plan', const Size(390, 1500), 1),
    'large-text-today-320': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'today', const Size(320, 3900), 2),
    'large-text-plan-320': ((t) => _fixture(t, Accent.blue, ThemeMode.dark), 'train-plan', const Size(320, 3400), 2),
    'large-text-appearance-320': ((t) => _fixture(t, Accent.pink, ThemeMode.light), 'appearance', const Size(320, 1900), 2),
    'food-preview-unknown-values-dark': ((t) => _fixture(t, Accent.green, ThemeMode.dark), 'food-preview-unknown', const Size(390, 1500), 1),
    'full-food-preview-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'food-preview', const Size(390, 1500), 1),
    'scan-camera-refused-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light, cameraRefused: true), 'scan', const Size(390, 900), 1),
    'large-text-log-food-320': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'log-food', const Size(320, 2400), 2),
    'large-text-food-preview-320': ((t) => _fixture(t, Accent.pink, ThemeMode.dark), 'food-preview', const Size(320, 3200), 2),
    'large-text-eat-goals-320': ((t) => _fixture(t, Accent.green, ThemeMode.light), 'eat', const Size(320, 2600), 2),
    'new-account-today': ((t) async => (await t.runAsync(() => overridesFor(day: _today)))!, 'today', const Size(390, 844), 1),
    'new-account-plan': ((t) async => (await t.runAsync(() => overridesFor(day: _today)))!, 'train-plan', const Size(390, 844), 1),
    'new-account-eat': ((t) async => (await t.runAsync(() => overridesFor(day: _today)))!, 'eat', const Size(390, 1000), 1),
  };
  for (final MapEntry(key: name, value: (fixture, screen, size, scale)) in states.entries) {
    testWidgets('state: $name', (tester) async {
      await pumpApp(tester, await fixture(tester), size: size, textScale: scale);
      await _open(tester, screen);
      await _save(tester, await _capture(tester), 'state-$name');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox()); // stops an open run screen's display timer
    });
  }
}
