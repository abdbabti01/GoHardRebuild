@Tags(['render'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/coach/coach_avatar.dart';
import 'package:gohard_rebuild/features/coach/coach_rig.dart';

/// Pose sheets of the companion rig for review (docs/evidence/coach/): each guide in both frames, at fixed poses —
/// at the user, eyes towards the bubble, away, up, down, a blink half-closed and closed, the smile's squint, the head
/// tilted towards the bubble and nodding — drawn large (the portrait at 3×, the eyes' detail visible) on a plain
/// ground. Renders of the Flutter painter in the test engine, not captures from a phone.
///
///   flutter test test/coach_rig_render_test.dart --dart-define=GOHARD_RENDER=true
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/coach';

const _poses = <(String, RigPose)>[
  ('at the user', RigPose.settled),
  ('to the bubble', RigPose(tilt: -0.3, gazeX: -1, gazeY: 0.3)),
  ('away', RigPose(tilt: -0.3, gazeX: 1)),
  ('up', RigPose(tilt: -0.3, gazeY: -1)),
  ('down', RigPose(tilt: -0.3, gazeY: 1)),
  ('blink half', RigPose(tilt: -0.3, blink: 0.5)),
  ('blink', RigPose(tilt: -0.3, blink: 1)),
  ('smile', RigPose(tilt: -0.3, smile: 1, brow: 0.6)),
  ('head to bubble', RigPose(tilt: -1, gazeX: -1, gazeY: 0.3)),
  ('nod', RigPose(tilt: -0.3, nod: 1)),
];

void main() {
  testWidgets('companion pose sheets', (tester) async {
    if (!_enabled) return;
    final container = ProviderContainer();
    for (final g in CoachGuide.values) {
      await tester.runAsync(() => container.read(rigImageProvider(g).future));
    }
    final frames = <ui.Image>[];
    for (final g in CoachGuide.values) {
      for (final frame in RigFrame.values) {
        for (final (_, pose) in _poses) {
          final size = frame == RigFrame.edge ? const Size(92, 114) : const Size(62, 72);
          await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: const Key('shot'),
                  child: ColoredBox(color: const Color(0xFFE9E2DA), child: RigPortrait(guide: g, pose: ValueNotifier(pose), size: size, frame: frame)),
                ),
              ),
            ),
          ));
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
          frames.add((await tester.runAsync(() => boundary.toImage(pixelRatio: frame == RigFrame.edge ? 3 : 4.5)))!);
        }
      }
    }
    // One sheet: a row per guide and frame, a column per pose.
    final cols = _poses.length;
    final w = frames.map((f) => f.width).reduce((a, b) => a > b ? a : b), h = frames.map((f) => f.height).reduce((a, b) => a > b ? a : b);
    final rows = frames.length ~/ cols;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    for (final (i, img) in frames.indexed) {
      canvas.drawImage(img, Offset((i % cols) * (w + 6.0), (i ~/ cols) * (h + 6.0)), Paint());
    }
    final sheet = await tester.runAsync(() => recorder.endRecording().toImage(cols * (w + 6), rows * (h + 6)));
    await tester.runAsync(() async {
      await Directory(_out).create(recursive: true);
      final old = File('$_out/companion-frames.png');
      if (old.existsSync()) old.deleteSync(); // the earlier strips (no moving eyes) are replaced by these poses
      await File('$_out/companion-poses.png').writeAsBytes((await sheet!.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
