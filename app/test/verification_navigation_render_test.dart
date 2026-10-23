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

import 'ui_support.dart';

/// Renders of Eat (History & trends entry), Train › Workouts (Recent workouts and its history) and Train › Progress for
/// design review (docs/AUTHENTICATION_EMAIL.md › Navigation):
///
///   flutter test test/verification_navigation_render_test.dart --dart-define=GOHARD_RENDER=true [--dart-define=GOHARD_RENDER_TAG=before]
///
/// Without the flag it does nothing. Fixture data; renders of the Flutter widgets, not phone captures. The tag names the
/// folder, so the same file run on an older checkout gives the "before" pictures.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _tag = String.fromEnvironment('GOHARD_RENDER_TAG', defaultValue: 'after');
const _out = '../docs/evidence/verification-navigation/$_tag${renderLanguage == '' ? '' : '-$renderLanguage'}';
const _day = '2026-10-19';

Json _finished(String id, String day, String title) => {
      'id': id, 'kind': 'manual', 'title': title, 'dayKey': day, 'startedAtUtc': '${day}T16:00:00Z', 'finishedAtUtc': '${day}T16:40:00Z', 'activeDurationSeconds': 2400,
      'outcome': 'manual_recorded', 'performedSets': 3, 'performedExercises': 1, 'qualifiedOccasion': false, 'isDeleted': false,
      'exercises': [{'id': '$id-e', 'ordinal': 1, 'name': 'Bench press', 'catalogKey': 'bench-press', 'isDeleted': false}],
    };

final _workouts = [
  _finished('w1', '2026-10-13', 'Push day'),
  _finished('w2', '2026-10-15', 'Pull day'),
  _finished('w3', '2026-10-17', 'Leg day'),
  _finished('w4', '2026-10-18', 'Full body'),
];
final _food = [
  foodEntry('b', _day, 'Breakfast', 'Eggs and oats', '1 bowl', calories: 450, protein: 25),
  foodEntry('l', _day, 'Lunch', 'Chicken and rice', '1 plate', calories: 720, protein: 50),
];

Future<List<Override>> _fixture(WidgetTester tester, ThemeMode mode, {bool empty = false}) async {
  final store = AppearanceStore(MemorySecretStore())
    ..accent = Accent.blue
    ..mode = mode;
  return [
    ...(await tester.runAsync(() => overridesFor(day: _day, appearance: store, food: empty ? const [] : _food, workouts: empty ? const [] : _workouts)))!,
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
  await loadArabicFonts();
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  await (FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  await _settle(tester);
  final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
  await tester.runAsync(() async {
    final file = File('$_out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await _settle(tester);
}

/// Each screen: how it is reached from the shell.
final _screens = <String, Future<void> Function(WidgetTester)>{
  'eat': (t) => _tap(t, 'nav-eat'),
  'train-workouts': (t) async {
    await _tap(t, 'nav-train');
    await _tap(t, 'train-workouts');
  },
  'train-progress': (t) async {
    await _tap(t, 'nav-train');
    await _tap(t, 'train-progress');
  },
};

void main() {
  if (!_enabled) {
    test('verification and navigation renders are skipped without GOHARD_RENDER', () {});
    return;
  }
  setUpAll(_fonts);

  for (final MapEntry(key: name, value: reach) in _screens.entries) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$name ${mode.name}', (tester) async {
        await pumpApp(tester, await _fixture(tester, mode), size: Size(390, name == 'train-progress' ? 2700 : 1500), insets: phoneInsets, settle: false);
        await _settle(tester);
        await reach(tester);
        await _shoot(tester, '$name-${mode.name}');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('train-workouts with nothing recorded', (tester) async {
    await pumpApp(tester, await _fixture(tester, ThemeMode.light, empty: true), size: const Size(390, 1100), insets: phoneInsets, settle: false);
    await _settle(tester);
    await _screens['train-workouts']!(tester);
    await _shoot(tester, 'train-workouts-empty-light');
    expect(tester.takeException(), isNull);
  });

  for (final name in ['eat', 'train-workouts']) {
    testWidgets('large text 320: $name', (tester) async {
      await pumpApp(tester, await _fixture(tester, ThemeMode.light), size: const Size(320, 3400), textScale: 2, settle: false);
      await _settle(tester);
      await _screens[name]!(tester);
      await _shoot(tester, 'large-text-$name-320');
      expect(tester.takeException(), isNull);
    });
  }
}
