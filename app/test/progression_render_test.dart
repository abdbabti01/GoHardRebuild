import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/plans/plan_rules.dart';
import 'package:gohard_rebuild/features/workout/next_target.dart';
import 'package:gohard_rebuild/features/workout/progression.dart';

import 'ui_support.dart';

/// Renders of next targets (docs/PROGRESSION.md) in all six themes and at 320 px with twice the text, for design
/// review:
///
///   flutter test test/progression_render_test.dart --dart-define=GOHARD_RENDER=true
///
/// Without the flag it does nothing. FIXTURES, not phone captures: an "Upper body A" plan with bench press at 190 lb
/// (3 × 6–8), two complete sessions of 3 × 8 at 190 lb (16 and 19 Oct) and a 5 lb increment.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/progression';
const _day = '2026-10-20', _pid = '8b2c3d4e-5f60-4a71-8b92-a3b4c5d6e7f8', _wid = 'upper-a';
final _target = ProgressionRules.round3(loadInputToKg(190, LoadUnit.lb));

Json _plan() {
  final workouts = [
    {'id': _wid, 'name': 'Upper body A', 'notes': null, 'exercises': [
      {'occurrenceKey': 'e1', 'catalogKey': 'bench-press', 'name': 'Bench press', 'isTimed': false, 'targetSets': 3, 'targetRepsMin': 6, 'targetRepsMax': 8, 'targetDurationSeconds': null, 'restSeconds': 120, 'targetLoadKg': _target},
      {'occurrenceKey': 'e2', 'catalogKey': 'barbell-row', 'name': 'Barbell row', 'isTimed': false, 'targetSets': 3, 'targetRepsMin': 8, 'targetRepsMax': 10, 'targetDurationSeconds': null, 'restSeconds': 90, 'targetLoadKg': ProgressionRules.round3(loadInputToKg(135, LoadUnit.lb))},
    ]},
  ];
  final schedule = {'mode': 'fixed', 'cycle': <String>[], 'trainingDays': <int>[], 'cycleAnchor': 0, 'pattern': [{'weekday': 1, 'workoutId': _wid}, {'weekday': 4, 'workoutId': _wid}]};
  return {'id': _pid, 'title': 'Strength plan', 'lifecycle': 'active', 'startDate': '2026-10-12', 'blockWeeks': 4, 'minRecoveryDays': 0, 'isOngoing': false, 'revision': 2,
    'timeBudgetMinutes': null, 'templateId': null, 'workouts': workouts, 'schedule': schedule, 'occasions': PlanRules.generate(_pid, '2026-10-12', 4, schedule, workouts)};
}

(List<Json>, List<Json>) _history() {
  final plan = Plan(_plan());
  final workouts = <Json>[], sets = <Json>[];
  for (final day in ['2026-10-15', '2026-10-19']) {
    final o = plan.occasions.firstWhere((x) => x.scheduledDate == day);
    final id = 'w-$day';
    workouts.add({'id': id, 'planId': _pid, 'occasionId': o.id, 'kind': 'planned', 'title': 'Upper body A', 'dayKey': day, 'startedAtUtc': '${day}T17:00:00Z',
      'finishedAtUtc': '${day}T18:00:00Z', 'outcome': 'full', 'isDeleted': false,
      'exercises': [for (final (i, p) in o.prescription.indexed) {...p.j, 'id': '$id-$i', 'ordinal': i + 1, 'isPrescribed': true, 'isDeleted': false}]});
    for (final (i, p) in o.prescription.indexed) {
      for (var n = 0; n < 3; n++) {
        sets.add({'id': '$id-$i-$n', 'exerciseId': '$id-$i', 'workoutId': id, 'reps': i == 0 ? 8 : 9, 'loadKg': p.targetLoadKg, 'performedAtUtc': '${day}T17:${10 * i + n}0:00Z', 'isDeleted': false});
      }
    }
  }
  return (workouts, sets);
}

Future<List<Override>> _fixture(WidgetTester tester, Accent accent, ThemeMode mode) async {
  final store = AppearanceStore(MemorySecretStore())
    ..accent = accent
    ..mode = mode;
  final (workouts, sets) = _history();
  final inc = {'exerciseKey': 'bench-press', 'incrementKg': loadInputToKg(5, LoadUnit.lb), 'revision': 1};
  return [
    ...(await tester.runAsync(() => overridesFor(day: _day, appearance: store, plans: [_plan()], primaryPlanId: _pid, workouts: workouts, sets: sets, profile: {'loadUnit': 'lb'})))!,
    incrementsProvider.overrideWith((ref) => Stream.value({'bench-press': stored(ExerciseIncrement(inc), Kinds.exerciseIncrement, 'bench-press', inc)})),
    progressionNotesProvider.overrideWith((ref) => Stream.value(const <String, Json>{})),
  ];
}

/// A page that opens [open] once it is shown: the real sheet over a plain page.
class _Opens extends StatefulWidget {
  const _Opens(this.open);
  final void Function(BuildContext context) open;
  @override
  State<_Opens> createState() => _OpensState();
}

class _OpensState extends State<_Opens> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

const _key = (planId: _pid, workoutId: _wid, occurrenceKey: 'e1');
final _bench = Prescription(_plan()['workouts'][0]['exercises'][0] as Json);

final _screens = <String, (Widget, Size)>{
  'next-time': (Scaffold(body: Builder(builder: (c) => ListView(padding: EdgeInsets.fromLTRB(c.inset, 40, c.inset, 40), children: const [NextTimeSection(planId: _pid, workoutId: _wid)]))), const Size(390, 820)),
  'review': (_Opens((c) => showTargetReview(c, _key)), const Size(390, 1100)),
  'increment': (_Opens((c) => showIncrementSheet(c, _bench)), const Size(390, 760)),
  'help': (_Opens(showProgressionHelp), const Size(390, 900)),
};

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

Future<ui.Image> _capture(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  for (var i = 0; i < 40 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

void main() {
  if (!_enabled) {
    test('progression renders are skipped without GOHARD_RENDER', () {});
    return;
  }
  setUpAll(_fonts);

  for (final MapEntry(key: name, value: (screen, size)) in _screens.entries) {
    testWidgets('six themes: $name', (tester) async {
      final shots = <String, ui.Image>{};
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final accent in Accent.values) {
          await pumpApp(tester, await _fixture(tester, accent, mode), home: screen, size: size, insets: phoneInsets, settle: false);
          final image = await _capture(tester);
          shots['${accent.label} · ${mode == ThemeMode.light ? 'Light' : 'Dark'}'] = image;
          if (accent == Accent.blue) await _save(tester, image, '$name-blue-${mode.name}');
          await tester.pumpWidget(const SizedBox());
        }
      }
      await _save(tester, await _sheet(tester, shots), 'six-themes-$name');
      expect(tester.takeException(), isNull);
    });
  }

  for (final name in ['next-time', 'review']) {
    testWidgets('large text 320: $name', (tester) async {
      await pumpApp(tester, await _fixture(tester, Accent.blue, ThemeMode.light), home: _screens[name]!.$1, size: const Size(320, 2400), textScale: 2, settle: false);
      await _save(tester, await _capture(tester), 'large-text-$name-320');
      expect(tester.takeException(), isNull);
    });
  }
}
