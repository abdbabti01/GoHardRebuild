import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'coach_avatar.dart';

/// The companion's rig (docs/COACH.md › Companion): the approved painted bust (`assets/coach/<guide>-bust.png`) drawn
/// as a skinned mesh, so the head turns and nods on the neck, the brows lift and the shoulders breathe without
/// cutting the picture into parts or opening a seam. The eyelids are painted over the eyes in the fur's own colours.
/// Nothing here knows about Today, greetings or preferences: it draws one [RigPose].

/// Where the parts of one guide's picture are, as fractions of the square source (measured on the 1254 px original
/// in design/coach/assets, so any texture size works). The picture faces the viewer's right; the rig mirrors it so
/// the guide looks in towards the page from the right edge.
@immutable
class RigArt {
  const RigArt({
    required this.pivot,
    required this.headFull,
    required this.headNone,
    required this.eyes,
    required this.brows,
    required this.lid,
    required this.top,
    required this.bottom,
    required this.faceX,
  });

  /// The base of the skull, where the head turns and nods.
  final Offset pivot;

  /// The head bone's weight: 1 above [headFull], easing to 0 at [headNone] (the neck bends between; the shirt never moves).
  final double headFull, headNone;
  final List<RigEye> eyes;
  final List<Offset> brows;

  /// The upper lid, top to edge, sampled from the fur above each eye.
  final (Color, Color) lid;

  /// The rows shown in the portrait: the ears to the upper shoulders.
  final double top, bottom;

  /// The face's centre across the source, which the portrait places a little left of the middle.
  final double faceX;

  static const leon = RigArt(
    pivot: Offset(0.518, 0.638),
    headFull: 0.50,
    headNone: 0.72,
    eyes: [RigEye(Offset(0.498, 0.341), 0.042, 0.028, 0.18), RigEye(Offset(0.679, 0.376), 0.033, 0.025, 0.25)],
    brows: [Offset(0.515, 0.275), Offset(0.698, 0.315)],
    lid: (Color(0xFFB8733C), Color(0xFFE29A56)),
    top: 0.0,
    bottom: 0.80,
    faceX: 0.60,
  );

  static const leona = RigArt(
    pivot: Offset(0.478, 0.622),
    headFull: 0.46,
    headNone: 0.68,
    eyes: [RigEye(Offset(0.499, 0.301), 0.048, 0.038, 0.20), RigEye(Offset(0.707, 0.356), 0.034, 0.034, 0.25)],
    brows: [Offset(0.522, 0.219), Offset(0.735, 0.266)],
    lid: (Color(0xFFB4784A), Color(0xFFE3A062)),
    top: 0.0,
    bottom: 0.78,
    faceX: 0.62,
  );

  static RigArt of(CoachGuide g) => switch (g) {
    CoachGuide.leon => leon,
    CoachGuide.leona => leona,
  };
}

/// One eye: centre, radii and tilt, as fractions of the source.
@immutable
class RigEye {
  const RigEye(this.center, this.rx, this.ry, this.tilt);
  final Offset center;
  final double rx, ry, tilt;
}

/// Everything the rig can show. Each value is small by design: the companion leans, tilts and nods a little.
@immutable
class RigPose {
  const RigPose({this.slide = 1, this.lean = 0, this.tilt = 0, this.nod = 0, this.brow = 0, this.smile = 0, this.blink = 0, this.breath = 0});

  /// 1: in place; 0: tucked behind the right edge.
  final double slide;

  /// Rotation of the whole bust about the bottom right corner, radians. Positive leans back behind the edge.
  final double lean;

  /// Head tilt, -1..1 (negative: towards the page). [nod] 0..1, [brow] 0..1 lift, [smile] 0..1 (a happy squint),
  /// [blink] 0..1 closed, [breath] -1..1.
  final double tilt, nod, brow, smile, blink, breath;

  static const settled = RigPose(tilt: -0.3);
  static const hidden = RigPose(slide: 0, lean: 0.2);
}

/// The guide's bust texture, decoded once at its own size and kept for the session (two guides, 400 px each).
/// Null when the file is missing or unreadable: the portrait then shows the plain avatar.
final rigImageProvider = FutureProvider.family<ui.Image?, CoachGuide>((ref, g) async {
  try {
    final data = await rootBundle.load('assets/coach/${g.name}-bust.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  } on Object {
    return null;
  }
});

/// The bust in a [size] box whose right edge is the screen's edge: drawn larger than the box and clipped there, so the
/// guide leans in around the edge, and faded out at the bottom, so there is never a cut-off torso. Decorative.
class RigPortrait extends ConsumerWidget {
  const RigPortrait({super.key, required this.guide, required this.pose, required this.size});
  final CoachGuide guide;
  final ValueListenable<RigPose> pose;
  final Size size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(rigImageProvider(guide));
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: size,
        child: switch (image) {
          AsyncData(value: final ui.Image img) => ClipRect(
            child: RepaintBoundary(
              child: CustomPaint(key: Key('coach-rig-${guide.name}'), painter: RigPainter(img, RigArt.of(guide), pose)),
            ),
          ),
          // Missing or unreadable texture: the plain round avatar, still and quiet.
          AsyncData() || AsyncError() => Align(
            alignment: const Alignment(0.3, 0.1),
            child: CoachAvatar(key: const Key('coach-rig-fallback'), size: math.min(64, size.width), guide: guide),
          ),
          _ => const SizedBox.shrink(), // decoding: the text beside it is already there
        },
      ),
    );
  }
}

/// Grid resolution of the mesh: 18 × 18 cells, 361 vertices, enough for a smooth neck bend at this size.
const _grid = 18;

class RigPainter extends CustomPainter {
  RigPainter(this.image, this.art, this.pose) : super(repaint: pose) {
    final n = _grid + 1;
    _tex = Float32List(n * n * 2);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        _tex[(j * n + i) * 2] = i / _grid * image.width;
        _tex[(j * n + i) * 2 + 1] = j / _grid * image.height;
      }
    }
    _indices = Uint16List(_grid * _grid * 6);
    var k = 0;
    for (var j = 0; j < _grid; j++) {
      for (var i = 0; i < _grid; i++) {
        final a = j * n + i, b = a + 1, c = a + n, d = c + 1;
        _indices.setAll(k, [a, b, c, b, d, c]);
        k += 6;
      }
    }
    _shader = ImageShader(image, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage, filterQuality: FilterQuality.medium);
  }

  final ui.Image image;
  final RigArt art;
  final ValueListenable<RigPose> pose;
  late final Float32List _tex;
  late final Uint16List _indices;
  late final ImageShader _shader;

  /// Max head tilt, radians, and the nod's drop and squash, as fractions of the source.
  static const _tiltMax = 0.075, _nodDrop = 0.014, _nodSquash = 0.03, _browLift = 0.012, _breathLift = 0.004;

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Where source point [p] (fractions, unmirrored) goes under [s]: brows, then the head bone, then breathing.
  Offset deform(Offset p, RigPose s) {
    var x = p.dx, y = p.dy;
    if (s.brow != 0) {
      for (final b in art.brows) {
        final w = 1 - _smooth(0, 0.08, (Offset(x, y) - b).distance);
        y -= w * s.brow * _browLift;
      }
    }
    final w = 1 - _smooth(art.headFull, art.headNone, p.dy);
    if (w > 0) {
      // The tilt is drawn mirrored, so towards the page (negative) turns the source the other way.
      final a = -s.tilt * _tiltMax * w;
      final dx = x - art.pivot.dx, dy0 = y - art.pivot.dy;
      final dy = dy0 * (1 - w * s.nod * _nodSquash);
      x = art.pivot.dx + dx * math.cos(a) - dy * math.sin(a);
      y = art.pivot.dy + dx * math.sin(a) + dy * math.cos(a) + w * s.nod * _nodDrop;
    }
    // Breathing lifts the shoulders and everything above them a hair; the bottom row stays put.
    y = 1 - (1 - y) * (1 + s.breath * _breathLift);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = pose.value;
    if (s.slide <= 0.001) return;
    final d = size.height / (art.bottom - art.top); // the source square's side in logical pixels
    // Mirrored: source x becomes d * (1 - x); the face sits at 46% of the box, the back of the head runs off the edge.
    final left = size.width * 0.46 - d * (1 - art.faceX);
    Offset place(Offset p) => Offset(left + d * (1 - p.dx), d * (p.dy - art.top));

    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..save();
    // Entrance and exit: slide in from behind the right edge, leaning around it on the bottom right corner.
    canvas.translate(size.width * 0.9 * (1 - s.slide), 0);
    if (s.lean != 0) {
      canvas
        ..translate(size.width, size.height)
        ..rotate(s.lean)
        ..translate(-size.width, -size.height);
    }

    final n = _grid + 1;
    final pos = Float32List(n * n * 2);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final q = place(deform(Offset(i / _grid, j / _grid), s));
        pos[(j * n + i) * 2] = q.dx;
        pos[(j * n + i) * 2 + 1] = q.dy;
      }
    }
    final mesh = ui.Vertices.raw(VertexMode.triangles, pos, textureCoordinates: _tex, indices: _indices);
    canvas.drawVertices(mesh, BlendMode.srcOver, Paint()..shader = _shader);
    mesh.dispose(); // the recorded picture keeps its own reference; this handle is not needed past the frame

    if (s.blink > 0.02 || s.smile > 0.02) {
      for (final e in art.eyes) {
        _lids(canvas, place(deform(e.center, s)), e, d, s);
      }
    }

    // The bottom fades out over the upper shoulders, in the box's own frame however the bust leans: no cut edge.
    canvas
      ..restore()
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _fadeFor(size),
      );
    canvas.restore();
  }

  Shader? _fade;
  Size? _fadeSize;

  /// The bottom fade, made once per box size rather than every frame.
  Shader _fadeFor(Size size) {
    if (_fadeSize != size) {
      _fadeSize = size;
      _fade = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Color(0x00FFFFFF)], stops: [0, 0.68, 1])
          .createShader(Offset.zero & size);
    }
    return _fade!;
  }

  /// The upper lid coming down over the eye ([RigPose.blink]) and the lower lid rising a little ([RigPose.smile]),
  /// clipped to the eye, in the fur's colours with a soft lash line at the edge.
  void _lids(Canvas canvas, Offset c, RigEye e, double d, RigPose s) {
    final rx = e.rx * d * 1.12, ry = e.ry * d * 1.18;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      // Mirrored tilt, plus the head's own turn at the eyes.
      ..rotate(-e.tilt + s.tilt * _tiltMax);
    final eye = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    canvas.clipPath(Path()..addOval(eye));
    final upper = (s.blink.clamp(0.0, 1.0) * 2 * ry * 1.02);
    final lower = s.smile.clamp(0.0, 1.0) * 0.28 * 2 * ry;
    final fur = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [art.lid.$1, art.lid.$2]).createShader(eye);
    final lash = Paint()
      ..color = const Color(0xFF2A1A12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, ry * 0.18)
      ..strokeCap = StrokeCap.round;
    if (upper > 0.05) {
      final edge = -ry + upper;
      // The lid's edge curves down a little in the middle, as a lid does.
      final lid = Path()
        ..moveTo(-rx, -ry)
        ..lineTo(rx, -ry)
        ..lineTo(rx, edge - ry * 0.25)
        ..quadraticBezierTo(0, edge + ry * 0.25, -rx, edge - ry * 0.25)
        ..close();
      canvas
        ..drawPath(lid, fur)
        ..drawPath(
          Path()
            ..moveTo(rx, edge - ry * 0.25)
            ..quadraticBezierTo(0, edge + ry * 0.25, -rx, edge - ry * 0.25),
          lash,
        );
    }
    if (lower > 0.05) {
      final edge = ry - lower;
      canvas.drawPath(
        Path()
          ..moveTo(-rx, ry)
          ..lineTo(rx, ry)
          ..lineTo(rx, edge + ry * 0.2)
          ..quadraticBezierTo(0, edge - ry * 0.2, -rx, edge + ry * 0.2)
          ..close(),
        Paint()..color = art.lid.$2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RigPainter old) => old.image != image || old.art != art || old.pose != pose;
}
