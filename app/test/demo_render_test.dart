import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/coach/exercise_media.dart';
import 'package:gohard_rebuild/features/coach/guide.dart';
import 'package:gohard_rebuild/features/coach/guide_sheets.dart';
import 'package:gohard_rebuild/features/workout/workout_flow.dart';

import 'ui_support.dart';

/// Renders of the exercise sheet and the picker (docs/EXERCISE_DEMOS.md) into docs/evidence/design, for looking at:
/// Blue Light and Pink Dark at 390 px, and 320 px at twice the text size. Only with --dart-define=GOHARD_RENDER=true.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/design';

final _manifest = ExerciseMediaCatalog.parse(File('assets/data/exercise-media.json').readAsStringSync());
final _guide = CoachGuideContent.parse(File('assets/data/coach-guide.json').readAsStringSync());
final _catalog = [for (final c in jsonDecode(File('../api/src/GoHard.Api/Data/exercise-catalog.json').readAsStringSync()) as List) CatalogExercise(c as Json)]
  ..sort((a, b) => a.name.compareTo(b.name));

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
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60))); // images decode in real time
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  await _settle(tester);
  final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
  await tester.runAsync(() async {
    final file = File('$_out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
}

class _Host extends StatelessWidget {
  const _Host(this.open);
  final void Function(BuildContext) open;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: TextButton(key: const Key('open'), onPressed: () => open(context), child: const Text('Open'))));
}

void main() {
  if (!_enabled) {
    test('demonstration renders (run with --dart-define=GOHARD_RENDER=true)', () {});
    return;
  }
  setUpAll(_fonts);

  Future<void> pump(WidgetTester tester, Widget home, {required Accent accent, required ThemeMode mode, Size size = const Size(390, 844), double text = 1}) async {
    final appearance = AppearanceStore(MemorySecretStore())
      ..accent = accent
      ..mode = mode;
    await pumpApp(tester, [
      ...(await tester.runAsync(() => overridesFor(day: '2026-10-18', appearance: appearance)))!,
      exerciseMediaProvider.overrideWith((ref) async => _manifest),
      coachGuideProvider.overrideWith((ref) async => _guide),
      exerciseChoicesProvider.overrideWithValue(_catalog),
      demoStoreProvider.overrideWith((ref) => DemoStore(directory: () async => Directory.systemTemp.createTempSync('render'))),
    ], home: home, size: size, textScale: text, insets: phoneInsets, settle: false);
    await _settle(tester);
  }

  Widget sheet(String key, String name) => _Host((c) => showExerciseDetails(c, exercise: (catalogKey: key, name: name, isTimed: false)));

  for (final (accent, mode, tag) in [(Accent.blue, ThemeMode.light, 'blue-light'), (Accent.pink, ThemeMode.dark, 'pink-dark')]) {
    testWidgets('$tag: sheet with a clip, a still, none; the picker', (tester) async {
      for (final (key, name) in [('bench-press', 'Bench press'), ('lateral-raise', 'Lateral raise'), ('back-squat', 'Back squat')]) {
        await pump(tester, sheet(key, name), accent: accent, mode: mode);
        await tester.tap(find.byKey(const Key('open')));
        await _save(tester, 'demo-sheet-$key-$tag');
        if (key == 'bench-press') {
          await tester.drag(find.byKey(const Key('exercise-info-sheet')), const Offset(0, -1400));
          await _save(tester, 'demo-sheet-$key-$tag-credits');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      await pump(tester, const ExercisePicker(), accent: accent, mode: mode);
      await tester.enterText(find.byKey(const Key('exercise-search')), 'press');
      await _save(tester, 'demo-picker-$tag');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('320 px at twice the text size: sheet and picker', (tester) async {
    await pump(tester, sheet('bench-press', 'Bench press'), accent: Accent.green, mode: ThemeMode.light, size: const Size(320, 700), text: 2);
    await tester.tap(find.byKey(const Key('open')));
    await _save(tester, 'demo-sheet-320-large-text');
    await tester.drag(find.byKey(const Key('exercise-info-sheet')), const Offset(0, -700));
    await _save(tester, 'demo-sheet-320-large-text-guide');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await pump(tester, const ExercisePicker(), accent: Accent.green, mode: ThemeMode.light, size: const Size(320, 700), text: 2);
    await tester.enterText(find.byKey(const Key('exercise-search')), 'bench');
    await _save(tester, 'demo-picker-320-large-text');
    expect(tester.takeException(), isNull);
  });
}
