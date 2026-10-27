@Tags(['render'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/app.dart' show UpdateRequiredScreen;
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/features/auth/auth_screen.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/workout_repository.dart';
import 'package:gohard_rebuild/features/workout/workout_runtime.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/coach/coach_avatar.dart';
import 'package:gohard_rebuild/features/coach/coach_bubble.dart';
import 'package:gohard_rebuild/features/nutrition/eating_out.dart' show restaurantCatalogProvider;
import 'package:gohard_rebuild/features/nutrition/restaurants.dart' show RestaurantCatalog;
import 'package:gohard_rebuild/features/weather/weather.dart';

import 'food_fakes.dart';
import 'support.dart';
import 'ui_support.dart';
import 'weather_fakes.dart';
import 'package:gohard_rebuild/core/language.dart';

/// Renders the real screens with the app's real fonts and photograph into PNG files for design review:
///
///   flutter test test/render_test.dart --dart-define=GOHARD_RENDER=true
///
/// Without that flag it does nothing, so the normal test run stays fast and writes no files. The data is the
/// fixture in ui_support.dart (illustrative, like the design reference), never an account's records. Every render
/// has a notched phone's safe-area insets (47 px status bar, 34 px home indicator), so the placement shows. These are
/// renders of the Flutter widgets, not captures from a phone: they show layout and colour, not device behaviour.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
// With --dart-define=GOHARD_RENDER_LANG=fr or ar the same renders are made in that language, beside the others.
const _out = renderLanguage == '' ? '../docs/evidence/design' : '../docs/evidence/localization/$renderLanguage/design';
const _today = '2026-10-11';

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await inter.load();
  await (FontLoader(serif)..addFont(File('assets/fonts/DMSerifDisplay-Regular.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
  await loadArabicFonts();
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  await (FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}

Future<ui.Image> _capture(WidgetTester tester) async {
  // The photograph decodes on a real timer; give it one, then paint.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  await _settle(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  return (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
}

/// pumpAndSettle for screens with a moving weather sky, which never settles: stops after five seconds of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 50 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

/// A manual workout finished two days ago with two movements and five recorded sets.
const Json _finished = {'id': 'w-done', 'kind': 'manual', 'title': 'Push day', 'dayKey': '2026-10-09', 'startedAtUtc': '2026-10-09T16:00:00Z', 'finishedAtUtc': '2026-10-09T16:42:00Z', 'activeDurationSeconds': 2520,
  'outcome': 'manual_recorded', 'performedSets': 5, 'performedExercises': 2, 'qualifiedOccasion': false, 'isDeleted': false,
  'exercises': [{'id': 'd1', 'ordinal': 1, 'name': 'Bench press', 'catalogKey': 'bench-press', 'isDeleted': false}, {'id': 'd2', 'ordinal': 2, 'name': 'Overhead press', 'catalogKey': 'overhead-press', 'isDeleted': false}]};
final List<Json> _finishedSets = [
  for (final (i, (exercise, load, reps)) in [('d1', 80, 6), ('d1', 80, 6), ('d1', 82.5, 5), ('d2', 50, 8), ('d2', 50, 7)].indexed)
    {'id': 'ds$i', 'exerciseId': exercise, 'workoutId': 'w-done', 'reps': reps, 'loadKg': load, 'performedAtUtc': '2026-10-09T16:${10 + i}:00Z', 'isDeleted': false},
];

/// The workout panel's recorder over the fixture's records: a running clock with a rest under way, and nothing saved.
class _QuietWorkouts extends WorkoutRepository {
  _QuietWorkouts(SyncEngine sync) : super(sync, 'one', FakeClock(DateTime.utc(2026, 10, 11, 16)));
  @override
  Future<WorkoutRuntime?> runtime(String workoutId) async => WorkoutRuntime.started(DateTime.utc(2026, 10, 11, 15, 32)).withRest(DateTime.now().toUtc(), 90, 'x');
  @override
  Future<void> saveRuntime(String workoutId, WorkoutRuntime runtime) async {}
  @override
  Future<ForegroundDecision> requestForeground(String? workoutId) async => ForegroundReady();
  @override
  Future<void> bringToForeground(String workoutId) async {}
}

List<Override> _quietWorkouts() {
  final db = AppDb(NativeDatabase.memory());
  final sessions = SessionManager(MemorySecretStore());
  return [workoutRepositoryProvider.overrideWithValue(_QuietWorkouts(SyncEngine(db, Api(FakeServer()..offline = true, sessions), sessions)))];
}

Future<List<Override>> _workoutPanel(WidgetTester t, Accent accent, ThemeMode mode, {bool inProgress = false}) async =>
    [...await _fixture(t, accent, mode, inProgress: inProgress, extraWorkouts: [_finished], extraSets: _finishedSets), ..._quietWorkouts()];

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
    case 'train-workouts' || 'workout-detail':
      await tap('nav-train');
      await tap('train-workouts');
      if (screen == 'workout-detail') {
        await tester.tap(find.text('Push day'));
        await tester.pumpAndSettle();
      }
    case 'train-plan-week-5' || 'train-plan-occasion':
      await tap('nav-train');
      await tap('train-plan');
      final key = screen == 'train-plan-week-5' ? 'week-5' : 'occasion-3-3';
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tap(key);
    case 'workout-preview':
      await tap('today-details');
    case 'workout-recording':
      // Today's Resume opens the panel; a typed, unsaved entry for the next set.
      await tap('today-resume');
      await tester.enterText(find.descendant(of: find.byKey(const Key('set-load')), matching: find.byType(TextField)), '62.5');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
    case 'workout-history':
      await tap('today-resume');
      await tester.ensureVisible(find.byKey(const Key('all-sessions')));
      await tap('all-sessions');
    case 'workout-result':
      ProviderScope.containerOf(tester.element(find.byType(HomeShell))).read(shellProvider.notifier).openWorkout(const WorkoutFocus.session('w-done'));
      await tester.pumpAndSettle();
    case 'builder-availability' || 'builder-structure':
      // A new account's plan builder: the template path, three days a week, then the suggested templates.
      await tap('nav-train');
      await tap('train-plan');
      await tap('create-plan');
      await tap('plan-path-direct');
      await tap('plan-path-template');
      await tap('days-3');
      if (screen == 'builder-structure') await tap('builder-next');
    case 'eat':
      await tap('nav-eat');
    case 'run':
      await tap('today-run');
    case 'run-history':
      await tap('nav-train');
      await tap('train-run-history');
    case 'log-food' || 'food-results' || 'food-preview' || 'food-preview-unknown' || 'scan':
      await tap('nav-eat');
      await tap('log-food');
      if (screen == 'scan') {
        await tap('food-scan');
      } else if (screen != 'log-food') {
        await tester.enterText(find.byKey(const Key('food-search')), 'rice');
        await tester.pumpAndSettle();
        // Below the fold once the phone's insets take their share of the height.
        await tester.scrollUntilVisible(find.byKey(const Key('food-search-online')), 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last);
        await tap('food-search-online');
        // The fixture already logged this rice, so it is listed once, under Your foods, and not again as a wider result.
        if (screen == 'food-preview') await tap(find.byKey(const Key('local-usda:2708402')).evaluate().isEmpty ? 'result-usda:2708402' : 'local-usda:2708402');
        if (screen == 'food-preview-unknown') await tap('result-off:5449000000996');
      }
    case 'food-common' || 'food-common-preview':
      // Everyday foods found by typing, with nothing asked of the wider database, and the preview one of them opens.
      await tap('nav-eat');
      await tap('log-food');
      await tester.enterText(find.byKey(const Key('food-search')), 'egg');
      await tester.pumpAndSettle();
      if (screen == 'food-common-preview') await tap('common-eggs');
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
      await pumpApp(tester, await _fixture(tester, Accent.blue, mode), insets: phoneInsets);
      confirm(tester.element(find.byKey(const Key('nav-today'))),
          title: 'Move this workout?', body: 'Workout: Full body (week 1)\nCurrent date: Friday, October 16\nProposed date: Saturday, October 17\n\nNo other workout changes.',
          action: 'Move workout', cancel: 'Keep current dates').ignore();
      await _save(tester, await _capture(tester), 'state-dialog-${mode.name}');
    });
  }

  // Leon and Leona in all six themes: the help entry with the guide speaking (its bubble, Ask me and one guide action),
  // both avatars and both full figures. The fur keeps its colours whatever the accent; only the bubble's controls follow
  // the theme.
  testWidgets('six themes: coach', (tester) async {
    tester.view.physicalSize = const Size(390, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final shots = <String, ui.Image>{};
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final accent in Accent.values) {
        final theme = goTheme(accent, mode == ThemeMode.light ? Brightness.light : Brightness.dark);
        // The boundary wraps the whole app: the hint is drawn in the navigator's overlay, above the page.
        await tester.pumpWidget(RepaintBoundary(key: const Key('shot'), child: ProviderScope(
          child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
                backgroundColor: theme.extension<GoColors>()!.page,
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('Upper / Lower', style: TextStyle(fontFamily: serif, fontSize: 30, color: theme.extension<GoColors>()!.text))),
                      CoachHelpButton(semanticLabel: 'Help with choosing a split', onPressed: () {}),
                    ]),
                    const SizedBox(height: 8),
                    CoachSpeaker(onClose: () {}, say: CoachSay('Unsure which split fits your week? Let\'s compare your options.', onAsk: () {},
                        guide: (label: 'Compare splits', key: const Key('render-compare'), onPressed: () {}))),
                    const SizedBox(height: 100),
                    const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      CoachAvatar(size: 40, guide: CoachGuide.leon), CoachAvatar(size: 40, guide: CoachGuide.leona),
                      CoachFigure(height: 140), CoachFigure(height: 140, guide: CoachGuide.leona),
                    ]),
                  ]),
                ),
              ),
          ),
        )));
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        shots['${accent.name[0].toUpperCase()}${accent.name.substring(1)} · ${mode == ThemeMode.light ? 'Light' : 'Dark'}'] = await _capture(tester);
        await tester.pumpWidget(const SizedBox());
      }
    }
    await _save(tester, await _sheet(tester, shots), 'six-themes-coach');
    expect(tester.takeException(), isNull);
  });

  // Every weather scene at Today's header size, one row per family, day / night / neutral (the provider did not say),
  // each with the header's own scrim and text where Today puts them. Then the decorative dusk for comparison.
  for (final (mode, accent) in [(ThemeMode.light, Accent.blue), (ThemeMode.dark, Accent.pink)]) {
    testWidgets('state: weather scenes ${mode.name}', (tester) async {
      const cell = Size(390, 240), gap = 8.0;
      final theme = goTheme(accent, mode == ThemeMode.light ? Brightness.light : Brightness.dark);
      final c = theme.extension<GoColors>()!;
      Widget scene(String key, String label) => SizedBox.fromSize(
          size: cell,
          child: Stack(children: [
            Positioned.fill(child: SceneBackdrop(spec: _spec(key), animate: false)),
            // Light text on a dark scrim over a dark sky, dark on a light one, as Today draws its header.
            Positioned(left: 16, top: 60, child: ColoredBox(
                color: _spec(key).dark ? const Color(0xFF000000).withValues(alpha: 0.3) : c.scrim,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(label, style: TextStyle(fontFamily: serif, fontSize: 34, color: _spec(key).dark ? Colors.white : (mode == ThemeMode.dark ? const Color(0xFF15171A) : c.text)))))),
          ]));
      // One scene at a time (each decodes and paints on its own), then laid out on one sheet.
      tester.view.physicalSize = cell * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final rows = [for (final f in weatherFamilies) [for (final l in ['day', 'night', 'neutral']) '$f-$l'], ['dusk']];
      final shots = <String, ui.Image>{};
      for (final key in rows.expand((r) => r)) {
        await tester.pumpWidget(MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Material(color: c.page, child: RepaintBoundary(key: const Key('shot'), child: scene(key, key.replaceAll('-', ' '))))));
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        shots[key] = await _capture(tester);
        await tester.pumpWidget(const SizedBox());
      }
      final w = (cell.width * 2).toInt(), h = (cell.height * 2).toInt(), g = (gap * 2).toInt();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(c.page, BlendMode.src);
      for (final (y, row) in rows.indexed) {
        for (final (x, key) in row.indexed) {
          canvas.drawImage(shots[key]!, Offset((g + x * (w + g)).toDouble(), (g + y * (h + g)).toDouble()), Paint());
        }
      }
      final sheet = (await tester.runAsync(() => recorder.endRecording().toImage(g + 3 * (w + g), g + rows.length * (h + g))))!;
      await _save(tester, sheet, 'state-weather-scenes-${mode.name}');
      expect(tester.takeException(), isNull);
    });
  }

  // The moving sky in stills: the same scene at 0, 0.5 and 1 second, one row per scene, so the drift of the clouds
  // and the fall of rain and snow show side by side.
  testWidgets('state: weather motion strip', (tester) async {
    const cell = Size(390, 200), gap = 8.0;
    tester.view.physicalSize = cell * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const rows = ['rain-day', 'snow-night', 'cloudy-day', 'partly-day', 'fog-day', 'storm-night'];
    final shots = <List<ui.Image>>[];
    for (final key in rows) {
      await tester.pumpWidget(MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
          debugShowCheckedModeBanner: false,
          theme: goTheme(Accent.blue, Brightness.light),
          home: RepaintBoundary(key: const Key('shot'), child: SizedBox.fromSize(size: cell, child: SceneBackdrop(spec: _spec(key))))));
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
      await tester.pump();
      final row = <ui.Image>[];
      for (var i = 0; i < 3; i++) {
        if (i > 0) await tester.pump(const Duration(milliseconds: 500));
        row.add((await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!);
      }
      shots.add(row);
      await tester.pumpWidget(const SizedBox());
    }
    final w = (cell.width * 2).toInt(), h = (cell.height * 2).toInt(), g = (gap * 2).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(const Color(0xFFDADCE0), BlendMode.src);
    for (final (y, row) in shots.indexed) {
      for (final (x, image) in row.indexed) {
        canvas.drawImage(image, Offset((g + x * (w + g)).toDouble(), (g + y * (h + g)).toDouble()), Paint());
      }
    }
    await _save(tester, (await tester.runAsync(() => recorder.endRecording().toImage(g + 3 * (w + g), g + rows.length * (h + g))))!, 'state-weather-motion');
    expect(tester.takeException(), isNull);
  });

  for (final screen in ['today', 'train-workouts', 'train-plan', 'train-progress', 'eat', 'me', 'appearance', 'log-food', 'food-results', 'food-preview', 'scan', 'goals']) {
    testWidgets('six themes: $screen', (tester) async {
      final shots = <String, ui.Image>{};
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final accent in Accent.values) {
          await pumpApp(tester, await _fixture(tester, accent, mode), insets: phoneInsets);
          await _open(tester, screen);
          final image = await _capture(tester);
          shots['${accent.name[0].toUpperCase()}${accent.name.substring(1)} · ${mode == ThemeMode.light ? 'Light' : 'Dark'}'] = image;
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
    'full-plan-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'train-plan', const Size(390, 1900), 1),
    'full-plan-dark': ((t) => _fixture(t, Accent.pink, ThemeMode.dark), 'train-plan', const Size(390, 1900), 1),
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
    'plan-16-weeks': ((t) => _fixture(t, Accent.blue, ThemeMode.light, weeks: 16), 'train-plan', const Size(390, 2200), 1),
    // Two of week 1's three workouts recorded and nothing in week 2: neither week may read Done. Green, to show the states do not lean on the accent.
    'plan-unrecorded-past-weeks-green': ((t) => _fixture(t, Accent.green, ThemeMode.light, inProgress: false, recorded: 2), 'train-plan', const Size(390, 1900), 1),
    'plan-other-week-selected': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'train-plan-week-5', const Size(390, 1900), 1),
    'plan-occasion-sheet-dark': ((t) => _fixture(t, Accent.green, ThemeMode.dark), 'train-plan-occasion', const Size(390, 844), 1),
    'workouts-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light, extraWorkouts: [_finished], extraSets: _finishedSets), 'train-workouts', const Size(390, 1150), 1),
    'workouts-dark': ((t) => _fixture(t, Accent.pink, ThemeMode.dark, extraWorkouts: [_finished], extraSets: _finishedSets), 'train-workouts', const Size(390, 1150), 1),
    'workout-detail-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light, extraWorkouts: [_finished], extraSets: _finishedSets), 'workout-detail', const Size(390, 844), 1),
    'progress-dark': ((t) => _fixture(t, Accent.green, ThemeMode.dark, extraWorkouts: [_finished], extraSets: _finishedSets), 'train-progress', const Size(390, 1100), 1),
    'large-text-workouts-320': ((t) => _fixture(t, Accent.blue, ThemeMode.light, extraWorkouts: [_finished], extraSets: _finishedSets), 'train-workouts', const Size(320, 2600), 2),
    'large-text-progress-320': ((t) => _fixture(t, Accent.blue, ThemeMode.light, extraWorkouts: [_finished], extraSets: _finishedSets), 'train-progress', const Size(320, 2800), 2),
    'new-account-workouts': ((t) async => (await t.runAsync(() => overridesFor(day: _today)))!, 'train-workouts', const Size(390, 844), 1),
    'new-account-progress': ((t) async => (await t.runAsync(() => overridesFor(day: _today)))!, 'train-progress', const Size(390, 844), 1),
    'large-text-today-320': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'today', const Size(320, 3900), 2),
    'large-text-plan-320': ((t) => _fixture(t, Accent.blue, ThemeMode.dark), 'train-plan', const Size(320, 4600), 2),
    'full-appearance-pink-dark': ((t) => _fixture(t, Accent.pink, ThemeMode.dark), 'appearance', const Size(390, 1900), 1),
    'large-text-appearance-320': ((t) => _fixture(t, Accent.pink, ThemeMode.light), 'appearance', const Size(320, 2500), 2),
    'full-appearance-green-light': ((t) => _fixture(t, Accent.green, ThemeMode.light), 'appearance', const Size(390, 1900), 1),
    'large-text-appearance-320-dark': ((t) => _fixture(t, Accent.blue, ThemeMode.dark), 'appearance', const Size(320, 2500), 2),
    'food-preview-unknown-values-dark': ((t) => _fixture(t, Accent.green, ThemeMode.dark), 'food-preview-unknown', const Size(390, 1500), 1),
    'full-food-preview-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'food-preview', const Size(390, 1500), 1),
    'scan-camera-refused-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light, cameraRefused: true), 'scan', const Size(390, 900), 1),
    'food-common-egg-light': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'food-common', const Size(390, 844), 1),
    'food-common-egg-dark': ((t) => _fixture(t, Accent.pink, ThemeMode.dark), 'food-common', const Size(390, 844), 1),
    'food-common-preview-light': ((t) => _fixture(t, Accent.green, ThemeMode.light), 'food-common-preview', const Size(390, 1500), 1),
    'food-common-preview-dark': ((t) => _fixture(t, Accent.pink, ThemeMode.dark), 'food-common-preview', const Size(390, 844), 1),
    'large-text-food-common-320': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'food-common', const Size(320, 1500), 2),
    'large-text-log-food-320': ((t) => _fixture(t, Accent.blue, ThemeMode.light), 'log-food', const Size(320, 2400), 2),
    'large-text-food-preview-320': ((t) => _fixture(t, Accent.pink, ThemeMode.dark), 'food-preview', const Size(320, 3200), 2),
    'large-text-eat-goals-320': ((t) => _fixture(t, Accent.green, ThemeMode.light), 'eat', const Size(320, 2600), 2),
    // The workout panel in Train › Workouts: preview, recording beside last time, the history sheet and the result.
    'workout-preview-blue-light': ((t) => _workoutPanel(t, Accent.blue, ThemeMode.light), 'workout-preview', const Size(390, 1700), 1),
    'workout-preview-pink-dark': ((t) => _workoutPanel(t, Accent.pink, ThemeMode.dark), 'workout-preview', const Size(390, 1700), 1),
    'workout-recording-green-light': ((t) => _workoutPanel(t, Accent.green, ThemeMode.light, inProgress: true), 'workout-recording', const Size(390, 2300), 1),
    'workout-recording-blue-dark': ((t) => _workoutPanel(t, Accent.blue, ThemeMode.dark, inProgress: true), 'workout-recording', const Size(390, 2300), 1),
    'workout-history-sheet-pink-light': ((t) => _workoutPanel(t, Accent.pink, ThemeMode.light, inProgress: true), 'workout-history', const Size(390, 844), 1),
    'workout-result-green-dark': ((t) => _workoutPanel(t, Accent.green, ThemeMode.dark), 'workout-result', const Size(390, 1300), 1),
    'large-text-workout-preview-320': ((t) => _workoutPanel(t, Accent.blue, ThemeMode.light), 'workout-preview', const Size(320, 3600), 2),
    'large-text-workout-recording-320': ((t) => _workoutPanel(t, Accent.pink, ThemeMode.dark, inProgress: true), 'workout-recording', const Size(320, 4800), 2),
    'new-account-today': ((t) async => (await t.runAsync(() => overridesFor(day: _today)))!, 'today', const Size(390, 844), 1),
    'new-account-plan': ((t) async => (await t.runAsync(() => overridesFor(day: _today)))!, 'train-plan', const Size(390, 844), 1),
    'builder-availability-light': ((t) async => [...(await t.runAsync(() => overridesFor(day: _today)))!, dbProvider.overrideWithValue(AppDb(NativeDatabase.memory())), transportProvider.overrideWithValue(FakeServer()..offline = true)], 'builder-availability', const Size(390, 1400), 1),
    'builder-structure-light': ((t) async => [...(await t.runAsync(() => overridesFor(day: _today)))!, dbProvider.overrideWithValue(AppDb(NativeDatabase.memory())), transportProvider.overrideWithValue(FakeServer()..offline = true)], 'builder-structure', const Size(390, 1600), 1),
    'large-text-builder-availability-320': ((t) async => [...(await t.runAsync(() => overridesFor(day: _today)))!, dbProvider.overrideWithValue(AppDb(NativeDatabase.memory())), transportProvider.overrideWithValue(FakeServer()..offline = true)], 'builder-availability', const Size(320, 3200), 2),
    'new-account-eat': ((t) async => (await t.runAsync(() => overridesFor(day: _today)))!, 'eat', const Size(390, 1000), 1),
  };
  // Today over the weather scenes, with fixed fake conditions for a selected city: the scene changes, nothing else.
  for (final family in weatherFamilies) {
    for (final (isDay, mode) in [for (final d in [true, false]) for (final m in [ThemeMode.light, ThemeMode.dark]) (d, m)]) {
      final name = 'today-weather-$family-${isDay ? 'day' : 'night'}-${mode.name}';
      states[name] = ((t) async {
        final w = WeatherFakes(now: DateTime.utc(2026, 10, 11, isDay ? 15 : 23));
        w.answer = (_, _) => w.conditions(family, isDay: isDay);
        return [
          ...await _fixture(t, mode == ThemeMode.light ? Accent.blue : Accent.pink, mode),
          ...(await t.runAsync(() => w.overrides(prefs: const WeatherPrefs(background: TodayBackground.weather, mode: WeatherLocationMode.city, city: quebec))))!,
        ];
      }, 'today', const Size(390, 844), 1);
    }
  }
  for (final MapEntry(key: name, value: (fixture, screen, size, scale)) in states.entries) {
    testWidgets('state: $name', (tester) async {
      // The bundled restaurant catalog read from the file, so Eat's Eating out panel names its chains in every render.
      final catalog = restaurantCatalogProvider.overrideWith((ref) async => RestaurantCatalog.parse(File('assets/data/restaurant-catalog.json').readAsStringSync())!);
      await pumpApp(tester, [...await fixture(tester), catalog], size: size, textScale: scale, insets: phoneInsets, settle: false);
      await _settle(tester);
      await _open(tester, screen);
      await _save(tester, await _capture(tester), 'state-$name');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox()); // stops an open run screen's display timer
    });
  }

  // The original badge where the app shows its brand (docs/BRANDING.md): sign-in, registration and the update notice.
  // The header's GH mark is in every tab render above.
  for (final (mode, accent) in [(ThemeMode.light, Accent.blue), (ThemeMode.dark, Accent.pink)]) {
    for (final (name, home, size, scale) in [
      ('sign-in', const AuthScreen(), const Size(390, 844), 1.0),
      ('register', const AuthScreen(), const Size(390, 844), 1.0),
      ('update-notice', const UpdateRequiredScreen(), const Size(390, 844), 1.0),
      if (mode == ThemeMode.light) ('sign-in-large-text-320', const AuthScreen(), const Size(320, 1900), 2.0),
    ]) {
      testWidgets('brand: $name ${mode.name}', (tester) async {
        await pumpApp(tester, await _fixture(tester, accent, mode), home: home, size: size, textScale: scale, insets: phoneInsets);
        if (name == 'register') {
          await tester.tap(find.byKey(const Key('auth-toggle')));
          await tester.pumpAndSettle();
        }
        await _save(tester, await _capture(tester), 'brand-$name-${mode.name}');
        expect(tester.takeException(), isNull);
      });
    }
  }
}

SceneSpec _spec(String key) => key == 'dusk'
    ? SceneSpec.dusk
    : SceneSpec(key: key, isWeather: true, family: key.split('-').first, isDay: key.endsWith('-day') ? true : key.endsWith('-night') ? false : null);
