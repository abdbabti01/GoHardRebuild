import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/body/body_metrics.dart';
import 'package:gohard_rebuild/features/body/body_prefs.dart';
import 'package:gohard_rebuild/features/body/body_screens.dart';

import 'ui_support.dart';

/// Renders of Body progress (docs/BODY_PROGRESS.md) in all six themes and at 320 px with twice the text, for design
/// review:
///
///   flutter test test/body_render_test.dart --dart-define=GOHARD_RENDER=true
///
/// Without the flag it does nothing. The check-ins are FIXTURES (the reference board's illustrative values); these are
/// renders of the Flutter widgets, not captures from a phone.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/body-progress';
const _day = '2026-10-19';

double _lb(double v) => v * kgPerLb;
double _in(double v) => v * cmPerInch;
Json _m(String id, String day, Map<String, Object?> v, {String? at}) => {'id': id, 'dayKey': day, 'revision': 1, 'isDeleted': false, 'recordedAtUtc': at, ...v};

final _checkIns = [
  _m('a', '2026-09-21', {'weightKg': _lb(202.4)}),
  _m('b', '2026-09-28', {'weightKg': _lb(201.6)}),
  _m('c', '2026-10-05', {'weightKg': _lb(200.0), 'waistCm': _in(36), 'chestCm': _in(43), 'leftUpperArmCm': _in(16.25), 'leftThighCm': _in(24)}, at: '2026-10-05T12:00:00Z'),
  _m('d', '2026-10-13', {'weightKg': _lb(199.0)}),
  _m('e', '2026-10-15', {'weightKg': _lb(198.8)}),
  _m('f', '2026-10-17', {'weightKg': _lb(198.6)}),
  _m('g', '2026-10-19', {'weightKg': _lb(198.0), 'waistCm': _in(35.5), 'chestCm': _in(43), 'leftUpperArmCm': _in(16.5), 'leftThighCm': _in(24)}, at: '2026-10-19T12:00:00Z'),
];

/// Measurement-only and legacy: no weight at all, and two older entries on one day with no saved time.
final _legacy = [
  _m('l1', '2026-10-05', {'waistCm': 91.4, 'rightThighCm': 61.0}),
  _m('l2', '2026-10-12', {'waistCm': 90.8}),
  _m('l3', '2026-10-12', {'waistCm': 90.2, 'bodyFatPercent': 21.5, 'note': 'after travel'}),
];

Future<List<Override>> _fixture(WidgetTester tester, Accent accent, ThemeMode mode, List<Json> checkIns) async {
  final store = AppearanceStore(MemorySecretStore())
    ..accent = accent
    ..mode = mode;
  final prefs = BodyPrefsStore(MemorySecretStore())..owners = {'one': const BodyPrefs(mass: LoadUnit.lb, length: LengthUnit.inch)};
  return [
    ...(await tester.runAsync(() => overridesFor(day: _day, appearance: store, bodyMetrics: checkIns)))!,
    bodyPrefsStoreProvider.overrideWithValue(prefs),
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

final _screens = <String, (Widget, List<Json>, Size)>{
  'overview': (const BodyProgressScreen(), _checkIns, const Size(390, 1500)),
  'log': (const CheckInScreen(), _checkIns, const Size(390, 1000)),
  'compare': (const CompareScreen(), _checkIns, const Size(390, 1100)),
  'legacy-overview': (const BodyProgressScreen(), _legacy, const Size(390, 1300)),
};

void main() {
  if (!_enabled) {
    test('body renders are skipped without GOHARD_RENDER', () {});
    return;
  }
  setUpAll(_fonts);

  for (final MapEntry(key: name, value: (screen, checkIns, size)) in _screens.entries) {
    testWidgets('six themes: $name', (tester) async {
      final shots = <String, ui.Image>{};
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final accent in Accent.values) {
          await pumpApp(tester, await _fixture(tester, accent, mode, checkIns), home: screen, size: size, insets: phoneInsets, settle: false);
          final image = await _capture(tester);
          shots['${accent.name[0].toUpperCase()}${accent.name.substring(1)} · ${mode == ThemeMode.light ? 'Light' : 'Dark'}'] = image;
          if (accent == Accent.blue) await _save(tester, image, '$name-blue-${mode.name}');
          await tester.pumpWidget(const SizedBox());
        }
      }
      await _save(tester, await _sheet(tester, shots), 'six-themes-$name');
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, screen, checkIns, height) in [('overview', const BodyProgressScreen(), _checkIns, 3600.0), ('log', const CheckInScreen(), _checkIns, 2600.0), ('compare', const CompareScreen(), _checkIns, 2600.0)]) {
    testWidgets('large text 320: $name', (tester) async {
      await pumpApp(tester, await _fixture(tester, Accent.blue, ThemeMode.light, checkIns), home: screen, size: Size(320, height), textScale: 2, settle: false);
      await _save(tester, await _capture(tester), 'large-text-$name-320');
      expect(tester.takeException(), isNull);
    });
  }
}
