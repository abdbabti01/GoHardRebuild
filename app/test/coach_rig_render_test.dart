@Tags(['render'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/coach/coach_avatar.dart';
import 'package:gohard_rebuild/features/coach/coach_companion.dart';
import 'package:gohard_rebuild/features/coach/coach_rig.dart';

/// Frame strips of the companion rig for review (docs/evidence/coach/): each guide's entrance, greeting (tilt, brow,
/// nod, blink), an acknowledgement and the exit, sampled at fixed motion times, drawn at 2.5× over a light and a dark
/// sky. Renders of the Flutter widget in the test engine, not captures from a phone.
///
///   flutter test test/coach_rig_render_test.dart --dart-define=GOHARD_RENDER=true
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/coach';
const _size = Size(92, 112);

class _Harness extends StatefulWidget {
  const _Harness(this.guide, this.sky);
  final CoachGuide guide;
  final List<Color> sky;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int ack = 0;
  bool leaving = false;
  void acknowledge() => setState(() => ack++);
  void leave() => setState(() => leaving = true);
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: const Key('shot'),
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: widget.sky)),
              child: Padding(
                padding: const EdgeInsets.only(left: 40, top: 8),
                child: CoachCompanion(guide: widget.guide, size: _size, greet: true, ack: ack, leaving: leaving),
              ),
            ),
          ),
        ),
      );
}

void main() {
  testWidgets('companion frame strips', (tester) async {
    if (!_enabled) return;
    final frames = <(String, ui.Image)>[];
    for (final guide in CoachGuide.values) {
      for (final (skyName, sky) in [('light', const [Color(0xFFBFD6EA), Color(0xFFF2E6D8)]), ('dark', const [Color(0xFF151A2C), Color(0xFF2C2A3A)])]) {
        final container = ProviderContainer();
        await tester.runAsync(() => container.read(rigImageProvider(guide).future));
        await tester.pumpWidget(UncontrolledProviderScope(container: container, child: _Harness(guide, sky)));
        final state = tester.state<_HarnessState>(find.byType(_Harness));
        var t = 0;
        Future<void> shot(String label) async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
          frames.add(('${guide.label} $skyName $label', (await tester.runAsync(() => boundary.toImage(pixelRatio: 2.5)))!));
        }

        Future<void> to(int ms) async {
          while (t < ms) {
            await tester.pump(const Duration(milliseconds: 16));
            t += 16;
          }
        }

        for (final ms in [0, 120, 240, 360, 480, 640, 760, 1090, 1700, 3000]) {
          await to(ms);
          await shot('${ms}ms');
        }
        state.acknowledge();
        final a = t;
        for (final ms in [200, 450]) {
          await to(a + ms);
          await shot('ack+${ms}ms');
        }
        await to(a + 1600);
        state.leave();
        final e = t;
        for (final ms in [100, 200, 300]) {
          await to(e + ms);
          await shot('exit+${ms}ms');
        }
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
    }
    // One sheet: a row per guide and sky.
    final w = frames.first.$2.width, h = frames.first.$2.height;
    const perRow = 15, label = 40;
    final rows = (frames.length / perRow).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    for (final (i, (name, img)) in frames.indexed) {
      final x = (i % perRow) * (w + 8.0), y = (i ~/ perRow) * (h + label + 8.0);
      canvas.drawImage(img, Offset(x, y + label), Paint());
      (TextPainter(text: TextSpan(text: name, style: const TextStyle(fontSize: 16, color: Color(0xFF000000))), textDirection: TextDirection.ltr)..layout(maxWidth: w.toDouble())).paint(canvas, Offset(x + 4, y + 4));
    }
    final sheet = await tester.runAsync(() => recorder.endRecording().toImage(perRow * (w + 8), rows * (h + label + 8)));
    await tester.runAsync(() async {
      await Directory(_out).create(recursive: true);
      await File('$_out/companion-frames.png').writeAsBytes((await sheet!.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    });
  });
}
