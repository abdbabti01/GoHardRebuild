import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/data/session.dart' show MemorySecretStore;
import 'package:gohard_rebuild/features/nutrition/target_helper.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

/// Renders of Help me set my targets for docs/NUTRITION_TARGETS.md with the app's real fonts, on a notched phone
/// (390 × 844) and at 320 px with twice the text. FIXTURES, not phone captures: the reference man (34 y, 170 cm,
/// 199 lb typed for this estimate only, mostly seated, Lose weight).
///
///   flutter test test/target_render_test.dart --dart-define=GOHARD_RENDER=true [--dart-define=GOHARD_RENDER_LANG=fr|ar]
///
/// English renders light and dark; French and Arabic render light. Every render also fails on a layout overflow.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/nutrition-targets/${renderLanguage == '' ? 'en' : renderLanguage}';
const _day = '2026-11-17';

class _Launcher extends StatelessWidget {
  const _Launcher();
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(child: TextButton(key: const Key('open'), onPressed: () => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const TargetHelperScreen())), child: const Text('open'))));
}

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

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// [key]'s top near the top of the screen.
Future<void> _toTop(WidgetTester tester, String key) async {
  await Scrollable.ensureVisible(tester.element(find.byKey(Key(key))), alignment: 0.02);
  await tester.pumpAndSettle();
}

/// Opens the helper and answers steps 1 and 2 for the reference man; [shots] adds the goal and activity renders.
Future<void> _toResult(WidgetTester tester, String suffix, {bool shots = true}) async {
  await _tap(tester, 'open');
  await _tap(tester, 'tgt-goal-recomp');
  if (shots) await _shot(tester, 'goal-recomp-$suffix');
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
  if (shots) {
    await _toTop(tester, 'tgt-activity-help');
    await _shot(tester, 'activity-$suffix');
  }
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -4000));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tgt-continue')));
  await tester.pumpAndSettle();
}

void main() {
  if (!_enabled) {
    test('target helper renders are skipped without GOHARD_RENDER', () {});
    return;
  }
  setUpAll(loadAppFonts);

  for (final mode in renderLanguage == '' ? [ThemeMode.light, ThemeMode.dark] : [ThemeMode.light]) {
    final m = mode.name;
    testWidgets('$m: the steps and the result', (tester) async {
      final overrides = (await tester.runAsync(() => overridesFor(day: _day, appearance: AppearanceStore(MemorySecretStore())..mode = mode)))!;
      await pumpApp(tester, [...overrides, profileRepositoryProvider.overrideWithValue(RecordingProfiles())], home: const _Launcher(), size: const Size(390, 844), insets: phoneInsets);
      await _toResult(tester, m);
      await _shot(tester, 'result-top-$m');
      await _toTop(tester, 'tgt-math');
      await _shot(tester, 'result-ledger-$m');
      await _tap(tester, 'tgt-details');
      await _tap(tester, 'tgt-how');
      await _toTop(tester, 'tgt-details');
      await _shot(tester, 'result-details-$m');
      await _tap(tester, 'tgt-check');
      await _toTop(tester, 'tgt-check');
      await _shot(tester, 'result-check-$m');
    });
  }

  testWidgets('320 px, twice the text', (tester) async {
    final overrides = (await tester.runAsync(() => overridesFor(day: _day)))!;
    await pumpApp(tester, [...overrides, profileRepositoryProvider.overrideWithValue(RecordingProfiles())], home: const _Launcher(), size: const Size(320, 900), textScale: 2, insets: phoneInsets);
    await _toResult(tester, '320-2x');
    await _shot(tester, 'result-top-320-2x');
    await _toTop(tester, 'tgt-math');
    await _shot(tester, 'result-ledger-320-2x');
    await _tap(tester, 'tgt-details');
    await _toTop(tester, 'tgt-details');
    await _shot(tester, 'result-details-320-2x');
  });
}
