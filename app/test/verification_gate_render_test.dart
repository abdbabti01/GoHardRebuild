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
import 'package:gohard_rebuild/features/auth/account_security.dart';
import 'package:gohard_rebuild/features/today/today_screen.dart';

import 'ui_support.dart';

/// Renders of the new account's verification step and the legacy grace notice on Today (docs/AUTHENTICATION_EMAIL.md ›
/// Required verification):
///
///   flutter test test/verification_gate_render_test.dart --dart-define=GOHARD_RENDER=true [--dart-define=GOHARD_RENDER_LANG=fr|ar]
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/verification-navigation/after${renderLanguage == '' ? '' : '-$renderLanguage'}';

Future<void> _fonts() async {
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

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  for (var i = 0; i < 40 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
  await tester.runAsync(() async {
    final file = File('$_out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
}

Future<List<Override>> _fixture(WidgetTester tester, ThemeMode mode, AccountAccess access) async {
  final store = AppearanceStore(MemorySecretStore())
    ..accent = Accent.blue
    ..mode = mode;
  return [
    ...(await tester.runAsync(() => overridesFor(day: '2026-10-23', appearance: store, profile: {'emailVerified': false})))!,
    accountAccessProvider.overrideWith((ref) => Stream.value(access)),
  ];
}

final _new = AccountAccess({'required': true, 'verified': false, 'dueAtUtc': null});
final _grace = AccountAccess({'required': false, 'verified': false, 'dueAtUtc': '2026-11-06T15:00:00Z'});

void main() {
  if (!_enabled) {
    test('verification renders are skipped without GOHARD_RENDER', () {});
    return;
  }
  setUpAll(_fonts);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('gate ${mode.name}', (tester) async {
      await pumpApp(tester, await _fixture(tester, mode, _new), home: const VerifyEmailScreen(gate: true), size: const Size(390, 844), insets: phoneInsets, settle: false);
      await _shoot(tester, 'verify-gate-${mode.name}');
      expect(tester.takeException(), isNull);
    });
    testWidgets('today grace notice ${mode.name}', (tester) async {
      await pumpApp(tester, await _fixture(tester, mode, _grace), home: const Scaffold(body: TodayScreen()), size: const Size(390, 900), insets: phoneInsets, settle: false);
      await _shoot(tester, 'today-grace-notice-${mode.name}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gate large text 320', (tester) async {
    await pumpApp(tester, await _fixture(tester, ThemeMode.light, _new), home: const VerifyEmailScreen(gate: true), size: const Size(320, 1700), textScale: 2, settle: false);
    await _shoot(tester, 'large-text-verify-gate-320');
    expect(tester.takeException(), isNull);
  });
}
