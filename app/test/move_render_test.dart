import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/activity/activity_detail.dart';
import 'package:gohard_rebuild/features/activity/announcer.dart';
import 'package:gohard_rebuild/features/activity/intervals.dart';
import 'package:gohard_rebuild/features/activity/location_source.dart';
import 'package:gohard_rebuild/features/activity/move_prefs.dart';
import 'package:gohard_rebuild/features/activity/move_widgets.dart';
import 'package:gohard_rebuild/features/activity/recorder.dart';
import 'package:gohard_rebuild/features/activity/run_walk_screens.dart';
import 'package:gohard_rebuild/features/activity/steps.dart';
import 'package:gohard_rebuild/features/activity/track_math.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/nutrition/water.dart';
import 'package:gohard_rebuild/app/providers.dart' show waterProvider, waterEntriesProvider;
import 'package:gohard_rebuild/features/shell/home_shell.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

/// Renders of the steps, intervals, coach-line and personal-best screens (docs/RUN_WALK.md) in all six themes and at a
/// narrow width with large text, for design review:
///
///   flutter test test/move_render_test.dart --dart-define=GOHARD_RENDER=true
///
/// Without the flag it does nothing. Recorder states, GPS and steps are SIMULATED fixtures; these are renders of the
/// Flutter widgets, not captures from a phone (the map is the drawn route: no map key in a widget test).
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/design';
const _day = '2026-10-11';
const _plan = IntervalPlan.preset;

class _Rec extends Recorder {
  _Rec(this.view);
  final RecorderView view;
  @override
  RecorderView build() => view;
  @override
  Future<void> adopt(Run run) async {}
}

class _Saying extends Announcer {
  @override
  Cue? build() => const Cue('Walk and recover for 1 minute 30 seconds.', key: 'r', priority: Cue.phase);
}

TrackAnalysis _route(int seconds, int startMs) {
  final a = TrackAnalysis()..add(TrackEntry(seq: 0, type: EntryType.start, segment: 0, t: startMs));
  for (var i = 1; i <= seconds; i++) {
    a.add(TrackEntry(seq: i, type: EntryType.fix, segment: 0, t: startMs + i * 1000, lat: 46.8 + i * 2.2 / 111320, lon: -71.2 + (i % 400) * 0.000004, acc: 5, speed: 2.2));
  }
  return a;
}

Json _saved(String id, String day, {required double meters, required double k1, bool intervals = false}) => {
      'id': id, 'dayKey': day, 'startedAtUtc': '${day}T07:00:00Z', 'finishedAtUtc': '${day}T07:40:00Z', 'activeDurationSeconds': 1800, 'distanceMeters': meters,
      'isDeleted': false, 'activityType': 'run', 'title': intervals ? 'Morning intervals' : 'Morning run',
      'metrics': {
        'distanceSource': 'gps', 'gpsDistanceMeters': meters, 'movingSeconds': 1700, 'elapsedSeconds': 1900, 'routeState': 'recorded', 'pointCount': 1500, 'gaps': 0,
        'interrupted': 0, 'stepsState': 'measured', 'steps': 4210, 'efforts': {'1000': k1},
        if (intervals) 'intervals': {'plan': _plan.toJson(), 'skips': [700000]},
      },
    };

Future<List<Override>> _fixture(WidgetTester tester, Accent accent, ThemeMode mode,
    {RecorderView? view, bool saying = false, MovePrefs? prefs, bool coach = true, List<Json>? runs, bool water = false}) async {
  final store = AppearanceStore(MemorySecretStore())
    ..accent = accent
    ..mode = mode;
  final move = MovePrefsStore(MemorySecretStore())..value = prefs ?? const MovePrefs(voice: true, intervals: true, plan: _plan, steps: {'one'}, stepGoals: {'one': 8000});
  // A returning account (greeted on an earlier day), so Today's one-time Steps introduction can show.
  final coachStore = CoachPrefsStore(MemorySecretStore())..value = CoachPrefs(onTabs: coach, onToday: coach, greeted: 'one|2026-10-10');
  return [
    ...(await tester.runAsync(() => overridesFor(day: _day, appearance: store, runs: runs ?? [
          _saved('a1', '2026-10-04', meters: 4100, k1: 352),
          _saved('a2', _day, meters: 5250, k1: 338, intervals: true),
        ],
        // The supplied screenshot's state: a workout due, nothing logged today, water tracked against a 2,000 mL goal;
        // earlier days with food and water for History.
        plans: water ? [blockPlan(start: '2026-09-21', recorded: 8)] : const [], primaryPlanId: water ? 'p1' : null,
        profile: water ? const {'waterGoalMl': 2000, 'showWater': true} : const {},
        food: water ? [foodEntry('h1', '2026-10-10', 'Dinner', 'Salmon and rice', '1 plate', calories: 640, protein: 42), foodEntry('h2', '2026-10-09', 'Lunch', 'Soup', '1 bowl')] : const [])))!,
    if (water) ...[
      waterProvider.overrideWith((ref, d) => Stream.value([for (final w in _water) if (w['dayKey'] == d) stored(WaterEntry(w), Kinds.water, w['id'] as String, w)])),
      waterEntriesProvider.overrideWith((ref) => Stream.value([for (final w in _water) stored(WaterEntry(w), Kinds.water, w['id'] as String, w)])),
    ],
    coachPrefsStoreProvider.overrideWithValue(coachStore),
    ...FoodFakes().overrides,
    movePrefsStoreProvider.overrideWithValue(move),
    stepSourceProvider.overrideWithValue(SimulatedStepSource(state: StepAccess.allowed, dailyTotal: 6342)),
    locationSourceProvider.overrideWithValue(SimulatedLocationSource(const [(46.8, -71.2, 5.0, null)])),
    if (view != null) recorderProvider.overrideWith(() => _Rec(view)),
    if (saying) announcerProvider.overrideWith(_Saying.new),
  ];
}

RecorderView _recording() {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  // 9 min 20 s in: round 2's walk of the preset (warm-up 5:00, run 1:00, walk 1:30 …).
  final start = now - 560000;
  return RecorderView(
    state: RecState.recording, run: Run({'id': 'open', 'dayKey': _day, 'startedAtUtc': DateTime.fromMillisecondsSinceEpoch(start, isUtc: true).toIso8601String(), 'activityType': 'run', 'isDeleted': false}),
    analysis: _route(559, start), gpsOn: true, plan: _plan, steps: StepTally(steps: 1184), stepsState: 'measured',
    last: Reading(lat: 46.8 + 559 * 2.2 / 111320, lon: -71.2, acc: 5, at: DateTime.now().toUtc()),
  );
}

Future<void> _fonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await inter.load();
  await (FontLoader(serif)..addFont(File('assets/fonts/DMSerifDisplay-Regular.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  await (FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ui.Image> _capture(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  await _settle(tester);
  return (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
}

Future<void> _save(WidgetTester tester, ui.Image image, String name) => tester.runAsync(() async {
      final file = File('$_out/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    });

Future<ui.Image> _sheet(WidgetTester tester, Map<String, ui.Image> shots) async {
  final images = shots.values.toList();
  final w = images.first.width, h = images.first.height;
  const gap = 36, label = 64;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(const Color(0xFFDADCE0), BlendMode.src);
  for (final (i, entry) in shots.entries.indexed) {
    final x = (gap + (i % 3) * (w + gap)).toDouble(), y = (gap + (i ~/ 3) * (h + gap + label)).toDouble();
    (TextPainter(text: TextSpan(text: entry.key, style: const TextStyle(fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFF121417))), textDirection: TextDirection.ltr)..layout())
        .paint(canvas, Offset(x, y));
    canvas.drawImage(entry.value, Offset(x, y + label), Paint());
  }
  return (await tester.runAsync(() => recorder.endRecording().toImage(gap + 3 * (w + gap), gap + 2 * (h + gap + label))))!;
}

/// Each screen: how it is reached, its recorder state and whether the coach is mid-sentence.
final _screens = <String, (Widget, RecorderView? Function(), bool, Future<void> Function(WidgetTester))>{
  'runwalk-ready-intervals': (const RunWalkScreen(), () => null, false, (_) async {}),
  'runwalk-recording-intervals': (const RunWalkScreen(), _recording, true, (_) async {}),
  'runwalk-recording-map': (const RunWalkScreen(), _recording, true, (t) async {
    await t.tap(find.byKey(const Key('runwalk-view-true')));
    await t.pump(const Duration(milliseconds: 300));
  }),
  'activity-intervals-best': (const ActivityDetailScreen(runId: 'a2'), () => null, false, (_) async {}),
  'today-steps': (const SizedBox(), () => null, false, (t) async {
    await t.dragUntilVisible(find.byKey(const Key('today-steps')), find.byKey(const Key('today-module-run')), const Offset(0, -200));
  }),
  'interval-setup': (Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => showIntervalSetup(c), child: const Text('open'))))), () => null, false, (t) async {
    await t.tap(find.text('open'));
    await t.pump(const Duration(milliseconds: 500));
  }),
};

/// Before/after states of the Steps and Ready corrections (GoHard_Steps_RunWalk_UX_Corrections), at a 390 × 844 phone with
/// its notch and home-indicator insets, written as `ux-<GOHARD_RENDER_TAG>-<state>.png` in docs/evidence/ux-corrections.
const _tag = String.fromEnvironment('GOHARD_RENDER_TAG', defaultValue: 'after');
const _water = [
  {'id': 'w1', 'dayKey': '2026-10-10', 'volumeMl': 1500.0, 'revision': 1, 'isDeleted': false},
  {'id': 'w2', 'dayKey': '2026-10-09', 'volumeMl': 750.0, 'revision': 1, 'isDeleted': false},
];

/// After states of GoHard_Today_History_Water_Corrections, in docs/evidence/today-history-water: Today as in the supplied
/// screenshot (390 × 844, notch and home indicator) in Blue Light and Pink Dark, Eat's History and an earlier day,
/// Train's Workouts, and 320 px at twice the text.
final _water2 = <String, (Accent, ThemeMode, Size, double, Future<void> Function(WidgetTester))>{
  'today-blue-light': (Accent.blue, ThemeMode.light, const Size(390, 844), 1, (_) async {}),
  'today-blue-light-scrolled': (Accent.blue, ThemeMode.light, const Size(390, 844), 1, (t) async {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await t.pump(const Duration(milliseconds: 400));
  }),
  'today-pink-dark-full': (Accent.pink, ThemeMode.dark, const Size(390, 1500), 1, (_) async {}),
  'today-blue-light-full': (Accent.blue, ThemeMode.light, const Size(390, 1500), 1, (_) async {}),
  'today-large-text-320': (Accent.blue, ThemeMode.light, const Size(320, 3400), 2, (_) async {}),
  'eat-today-green-dark': (Accent.green, ThemeMode.dark, const Size(390, 1300), 1, (t) async {
    await t.tap(find.byKey(const Key('nav-eat')));
    await t.pump(const Duration(milliseconds: 600));
  }),
  'eat-history-blue-light': (Accent.blue, ThemeMode.light, const Size(390, 1100), 1, (t) async {
    await t.tap(find.byKey(const Key('nav-eat')));
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byKey(const Key('eat-history')));
    await t.pump(const Duration(milliseconds: 600));
  }),
  'eat-earlier-day-blue-light': (Accent.blue, ThemeMode.light, const Size(390, 1100), 1, (t) async {
    await t.tap(find.byKey(const Key('nav-eat')));
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byKey(const Key('eat-history')));
    await t.pump(const Duration(milliseconds: 600));
    await _settle(t);
    await t.ensureVisible(find.byKey(const Key('trends-calendar')));
    await t.tap(find.byKey(const Key('trends-calendar')));
    await t.pump(const Duration(milliseconds: 600));
    await _settle(t);
    await t.tap(find.byKey(const Key('history-day-2026-10-10')));
    await t.pump(const Duration(milliseconds: 600));
  }),
  'train-workouts-pink-dark': (Accent.pink, ThemeMode.dark, const Size(390, 1100), 1, (t) async {
    await t.tap(find.byKey(const Key('nav-train')));
    await t.pump(const Duration(milliseconds: 600));
  }),
};

/// GoHard_Today_Option_2_Polish, in docs/evidence/today-option-2: the photo-header tiles with a walk completed today
/// and steps against a goal (the approved mockup's state), steps without a goal and off, and 320 px at twice the text.
final _option2 = <String, (Accent, ThemeMode, Size, double, MovePrefs)>{
  'today-blue-light': (Accent.blue, ThemeMode.light, const Size(390, 844), 1, const MovePrefs(steps: {'one'}, stepGoals: {'one': 8000})),
  'today-blue-light-full': (Accent.blue, ThemeMode.light, const Size(390, 1500), 1, const MovePrefs(steps: {'one'}, stepGoals: {'one': 8000})),
  'today-blue-dark-full': (Accent.blue, ThemeMode.dark, const Size(390, 1500), 1, const MovePrefs(steps: {'one'}, stepGoals: {'one': 8000})),
  'today-pink-dark-no-goal': (Accent.pink, ThemeMode.dark, const Size(390, 1500), 1, const MovePrefs(steps: {'one'})),
  'today-green-light-steps-off': (Accent.green, ThemeMode.light, const Size(390, 1500), 1, const MovePrefs()),
  'today-large-text-320': (Accent.blue, ThemeMode.light, const Size(320, 3400), 2, const MovePrefs(steps: {'one'}, stepGoals: {'one': 8000})),
};

final _ux = <String, (Widget, MovePrefs, bool, Size, double)>{
  'today-first-use': (const HomeShell(), const MovePrefs(), true, const Size(390, 844), 1),
  'today-first-use-coach-off': (const HomeShell(), const MovePrefs(), false, const Size(390, 844), 1),
  'today-steps-on': (const HomeShell(), const MovePrefs(steps: {'one'}, stepGoals: {'one': 8000}), true, const Size(390, 844), 1),
  'today-first-use-full': (const HomeShell(), const MovePrefs(), true, const Size(390, 1500), 1),
  'today-steps-on-full': (const HomeShell(), const MovePrefs(steps: {'one'}, stepGoals: {'one': 8000}), false, const Size(390, 1500), 1),
  'today-large-text-320': (const HomeShell(), const MovePrefs(), true, const Size(320, 3200), 2),
  'ready-default': (const RunWalkScreen(), const MovePrefs(), true, const Size(390, 844), 1),
  'ready-default-coach-off': (const RunWalkScreen(), const MovePrefs(), false, const Size(390, 844), 1),
  'ready-configured': (const RunWalkScreen(), const MovePrefs(voice: true, intervals: true, plan: _plan, steps: {'one'}), true, const Size(390, 844), 1),
  'ready-large-text-320': (const RunWalkScreen(), const MovePrefs(), true, const Size(320, 640), 2),
};

void main() {
  if (_enabled) {
    for (final MapEntry(key: name, value: (accent, mode, size, scale, prefs)) in _option2.entries) {
      testWidgets('option 2 $name', (tester) async {
        await pumpApp(tester, await _fixture(tester, accent, mode, prefs: prefs, water: true), size: size, textScale: scale, insets: phoneInsets, settle: false);
        await _settle(tester);
        final image = await _capture(tester);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final file = File('../docs/evidence/today-option-2/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox());
      });
    }
    for (final MapEntry(key: name, value: (accent, mode, size, scale, reach)) in _water2.entries) {
      testWidgets('water $name', (tester) async {
        await pumpApp(tester, await _fixture(tester, accent, mode, prefs: const MovePrefs(steps: {'one'}), runs: const [], water: true),
            size: size, textScale: scale, insets: phoneInsets, settle: false);
        await _settle(tester);
        await reach(tester);
        await _settle(tester);
        final image = await _capture(tester);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final file = File('../docs/evidence/today-history-water/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox());
      });
    }
    for (final MapEntry(key: name, value: (home, prefs, coach, size, scale)) in _ux.entries) {
      testWidgets('ux $_tag: $name', (tester) async {
        await pumpApp(tester, await _fixture(tester, Accent.green, ThemeMode.dark, prefs: prefs, coach: coach, runs: const []),
            home: home, size: size, textScale: scale, insets: phoneInsets, settle: false);
        await _settle(tester);
        final image = await _capture(tester);
        await tester.runAsync(() async {
          final file = File('../docs/evidence/ux-corrections/ux-$_tag-$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  if (!_enabled) {
    test('move renders (run with --dart-define=GOHARD_RENDER=true)', () {});
    return;
  }
  setUpAll(_fonts);

  for (final MapEntry(key: name, value: (home, view, saying, reach)) in _screens.entries) {
    testWidgets('six themes: $name', (tester) async {
      final shots = <String, ui.Image>{};
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final accent in Accent.values) {
          await pumpApp(tester, await _fixture(tester, accent, mode, view: view(), saying: saying), home: home is SizedBox ? const HomeShell() : home, insets: phoneInsets, settle: false);
          await _settle(tester);
          await reach(tester);
          shots['${accent.name[0].toUpperCase()}${accent.name.substring(1)} · ${mode == ThemeMode.light ? 'Light' : 'Dark'}'] = await _capture(tester);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
      await _save(tester, await _sheet(tester, shots), 'six-themes-$name');
    });
  }

  for (final name in ['runwalk-ready-intervals', 'runwalk-recording-intervals', 'today-steps']) {
    testWidgets('narrow large text: $name', (tester) async {
      final (home, view, saying, reach) = _screens[name]!;
      await pumpApp(tester, await _fixture(tester, Accent.blue, ThemeMode.light, view: view(), saying: saying),
          home: home is SizedBox ? const HomeShell() : home, size: const Size(320, 1400), textScale: 2, insets: phoneInsets, settle: false);
      await _settle(tester);
      await reach(tester);
      await _save(tester, await _capture(tester), 'state-large-text-320-$name');
      expect(tester.takeException(), isNull, reason: 'no overflow at twice the text size on a 320 px phone');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
