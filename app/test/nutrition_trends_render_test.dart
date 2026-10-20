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
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_history.dart';

import 'ui_support.dart';

/// Renders of Eat › History & trends (docs/FOOD_DATA.md) in all six themes and at 320 px with twice the text, for design
/// review:
///
///   flutter test test/nutrition_trends_render_test.dart --dart-define=GOHARD_RENDER=true
///
/// Without the flag it does nothing. The food is a FIXTURE (the reference board's illustrative week and month); these
/// are renders of the Flutter widgets, not captures from a phone.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/nutrition-trends';
const _day = '2026-10-19';

Json _f(String id, String day, String meal, String name, num? kcal, [num? protein]) => foodEntry(id, day, meal, name, '1 serving', calories: kcal, protein: protein);

final _food = [
  for (final (d, k) in [('01', 2030), ('02', 2150), ('05', 1980), ('06', 2240), ('08', 1850), ('09', 2100), ('10', 1780)]) _f('o$d', '2026-10-$d', 'Lunch', 'Logged meal', k, k / 16),
  _f('m', '2026-10-12', 'Lunch', 'Rice bowl', 2100, 120),
  _f('t', '2026-10-13', 'Lunch', 'Pasta', 1950, 95),
  _f('b', '2026-10-15', 'Breakfast', 'Eggs and oats', 450, 25),
  _f('l', '2026-10-15', 'Lunch', 'Chicken and rice', 720, 50),
  _f('d1', '2026-10-15', 'Dinner', 'Pasta', 860, 50),
  _f('d2', '2026-10-15', 'Dinner', 'Homemade sauce', null),
  _f('s', '2026-10-15', 'Snack', 'Yogurt', 200, 15),
  _f('fr', '2026-10-16', 'Lunch', 'Curry', 2050, 110),
  _f('sa', '2026-10-17', 'Lunch', 'Burrito', 2380, 125),
  _f('u', '2026-10-11', 'Lunch', 'Homemade stew', null),
  _f('z', '2026-10-19', 'Snack', 'Black coffee', 0, 0),
];

Future<List<Override>> _fixture(WidgetTester tester, Accent accent, ThemeMode mode) async {
  final store = AppearanceStore(MemorySecretStore())
    ..accent = accent
    ..mode = mode;
  return [
    ...(await tester.runAsync(() => overridesFor(day: _day, appearance: store, food: _food)))!,
    waterEntriesProvider.overrideWith((ref) => Stream.value(const [])),
    waterProvider.overrideWith((ref, d) => Stream.value(const [])),
  ];
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

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await _settle(tester);
}

/// Each view: the day Eat showed when History & trends opened, then how it is reached.
final _views = <String, (String, Future<void> Function(WidgetTester))>{
  'week': ('2026-10-15', (_) async {}),
  'month': ('2026-10-15', (t) => _tap(t, 'trends-kind-month')),
  'week-unknown-day': ('2026-10-11', (_) async {}),
  'week-protein': ('2026-10-15', (t) => _tap(t, 'trends-metric-protein')),
};

void main() {
  if (!_enabled) {
    test('nutrition trends renders are skipped without GOHARD_RENDER', () {});
    return;
  }
  setUpAll(_fonts);

  for (final MapEntry(key: name, value: (day, reach)) in _views.entries) {
    testWidgets('six themes: $name', (tester) async {
      final shots = <String, ui.Image>{};
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final accent in Accent.values) {
          await pumpApp(tester, await _fixture(tester, accent, mode), home: NutritionHistoryScreen(selected: day), size: const Size(390, 1500), insets: phoneInsets, settle: false);
          await _settle(tester);
          await reach(tester);
          final image = await _capture(tester);
          shots['${accent.label} · ${mode == ThemeMode.light ? 'Light' : 'Dark'}'] = image;
          if (accent == Accent.blue || name == 'week') await _save(tester, image, '$name-${accent.name}-${mode.name}');
          await tester.pumpWidget(const SizedBox());
        }
      }
      await _save(tester, await _sheet(tester, shots), 'six-themes-$name');
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, reach) in [('week', (WidgetTester _) async {}), ('month', (WidgetTester t) => _tap(t, 'trends-kind-month'))]) {
    testWidgets('large text 320: $name', (tester) async {
      await pumpApp(tester, await _fixture(tester, Accent.blue, ThemeMode.light), home: const NutritionHistoryScreen(selected: '2026-10-15'), size: const Size(320, 3600), textScale: 2, settle: false);
      await _settle(tester);
      await reach(tester);
      await _save(tester, await _capture(tester), 'large-text-$name-320');
      expect(tester.takeException(), isNull);
    });
  }
}
