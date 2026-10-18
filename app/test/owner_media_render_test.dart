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
import 'package:gohard_rebuild/features/coach/media_manager.dart';

import 'ui_support.dart';

/// Renders of the owner's manager (docs/OWNER_EXERCISE_VIDEOS.md) into docs/evidence/design, for looking at: Blue Light
/// and Pink Dark, and 320 px at twice the text size. Only with --dart-define=GOHARD_RENDER=true. The server is scripted.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/design';
final _bundled = ExerciseMediaCatalog.parse(File('assets/data/exercise-media.json').readAsStringSync());
final _catalog = [for (final c in jsonDecode(File('../api/src/GoHard.Api/Data/exercise-catalog.json').readAsStringSync()) as List) CatalogExercise(c as Json)]
  ..sort((a, b) => a.name.compareTo(b.name));

Json _draft(String id, String key, String status, {String? error}) => {
      'id': id, 'catalogKey': key, 'status': status, 'variant': 'Barbell on a flat bench, side view', 'title': 'Bench press', 'creator': 'GoHard',
      'rightsKind': 'original', 'rightsNotice': 'Original footage, published by GoHard.', 'rightsConfirmed': true, 'declaredBytes': 31000000,
      'bytes': 2326838, 'durationSeconds': 8.6, 'width': 1280, 'height': 720, 'error': error, 'revision': 3,
    };

class _Server implements Transport {
  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer, Map<String, String>? headers}) async => switch (path) {
        '/exercise-media/manage' => ApiResponse(200, {
            'drafts': [_draft('d1', 'bench-press', 'ready'), _draft('d2', 'dip', 'failed', error: 'UNSUPPORTED_HDR'), _draft('d3', 'back-squat', 'processing'),
              {..._draft('d4', 'face-pull', 'published'), 'creator': 'Goulart', 'rightsKind': 'licensed', 'licenceName': 'CC BY-SA 4.0'}],
            'active': [
              {'id': 'v1', 'catalogKey': 'face-pull', 'title': 'Face pull', 'variant': 'Cable face pull with a rope, standing; side view', 'creator': 'Goulart',
                'rightsKind': 'licensed', 'licenceName': 'CC BY-SA 4.0'},
            ],
          }),
        '/exercise-media/manage/drafts/d1/preview' => const ApiResponse(200, {'clipUrl': 'https://storage.test/p.mp4', 'posterUrl': 'https://storage.test/p.jpg'}),
        _ => const ApiResponse(404, null),
      };
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

Future<void> _save(WidgetTester tester, String name) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 120));
  }
  final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
  await tester.runAsync(() async {
    final file = File('$_out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
}

void main() {
  if (!_enabled) {
    test('owner video renders (run with --dart-define=GOHARD_RENDER=true)', () {});
    return;
  }
  setUpAll(_fonts);

  Future<void> pump(WidgetTester tester, Widget home, {required Accent accent, required ThemeMode mode, Size size = const Size(390, 844), double text = 1}) async {
    final appearance = AppearanceStore(MemorySecretStore())
      ..accent = accent
      ..mode = mode;
    await pumpApp(tester, [
      ...(await tester.runAsync(() => overridesFor(day: '2026-10-18', appearance: appearance)))!,
      transportProvider.overrideWithValue(_Server()),
      mediaAccessProvider.overrideWith((ref) async => const MediaAccess(canManage: true, ready: true)),
      bundledMediaProvider.overrideWith((ref) async => _bundled),
      exerciseMediaProvider.overrideWith((ref) async => _bundled),
      exerciseChoicesProvider.overrideWithValue(_catalog),
    ], home: home, size: size, textScale: text, insets: phoneInsets, settle: false);
  }

  for (final (accent, mode, tag) in [(Accent.blue, ThemeMode.light, 'blue-light'), (Accent.pink, ThemeMode.dark, 'pink-dark')]) {
    testWidgets('$tag: the manager, a draft ready to publish, a published video', (tester) async {
      await pump(tester, const ManageExerciseVideosScreen(), accent: accent, mode: mode, size: const Size(390, 1400));
      await _save(tester, 'owner-videos-list-$tag');
      await pump(tester, const ManageExerciseVideoScreen(catalogKey: 'bench-press'), accent: accent, mode: mode, size: const Size(390, 1500));
      await _save(tester, 'owner-videos-ready-$tag');
      await pump(tester, const ManageExerciseVideoScreen(catalogKey: 'face-pull'), accent: accent, mode: mode);
      await _save(tester, 'owner-videos-published-$tag');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('320 px at twice the text size: the manager and a failed draft', (tester) async {
    await pump(tester, const ManageExerciseVideosScreen(), accent: Accent.green, mode: ThemeMode.light, size: const Size(320, 1400), text: 2);
    await _save(tester, 'owner-videos-list-320-large-text');
    expect(tester.takeException(), isNull);
    await pump(tester, const ManageExerciseVideoScreen(catalogKey: 'dip'), accent: Accent.green, mode: ThemeMode.light, size: const Size(320, 1400), text: 2);
    await _save(tester, 'owner-videos-failed-320-large-text');
    expect(tester.takeException(), isNull);
  });
}
