import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'coach_avatar.dart';

/// The companion's rig (docs/COACH.md › Companion): the approved painted bust (`assets/coach/<guide>-bust.png`) drawn
/// as a skinned mesh, so the head turns and nods on the neck, the brows lift and the shoulders breathe without cutting
/// the picture into parts or opening a seam. On top: the eyes as layers of their own (each iris, cut from the same
/// painting, moves inside its opening for the gaze; only the sliver of white it uncovers is repainted) and eyelids in
/// the fur's own colours. Nothing here knows about Today, greetings or preferences: it draws one [RigPose] in one
/// [RigFrame], and [RigGeometry.point] says where any part of the painting is on screen (the mouth, for a speech
/// bubble's tail).

/// One eye's moving part, as fractions of the square source (measured on the 1254 px originals in
/// design/coach/assets): the opening inside the lash line (a polygon), the iris disc, and the white's tone from its
/// lid-shadowed top to its lit bottom (sampled), for the sliver the iris uncovers.
@immutable
class RigIris {
  const RigIris(this.opening, this.center, this.radius, this.sclera);
  final List<Offset> opening;
  final Offset center;
  final double radius;
  final (Color, Color) sclera;
}

/// Where the parts of one guide's picture are, as fractions of the square source. The picture faces the viewer's
/// right.
@immutable
class RigArt {
  const RigArt({
    required this.pivot,
    required this.headFull,
    required this.headNone,
    required this.irises,
    required this.brows,
    required this.lid,
    required this.mouth,
    required this.front,
    required this.top,
    required this.bottom,
    required this.faceX,
  });

  /// The base of the skull, where the head turns and nods.
  final Offset pivot;

  /// The head bone's weight: 1 above [headFull], easing to 0 at [headNone] (the neck bends between; the shirt never moves).
  final double headFull, headNone;

  /// The eyes: each opening carries the lids (blinks, the smile's squint) and the moving iris.
  final List<RigIris> irises;
  final List<Offset> brows;

  /// The upper lid, top to edge, sampled from the fur above each eye.
  final (Color, Color) lid;

  /// The middle of the mouth: where a speech bubble's tail points.
  final Offset mouth;

  /// How far forward the muzzle reaches (source x at the mouth's height): the face's silhouette on the speaking side.
  final double front;

  /// The rows shown in the portrait: the ears to the upper shoulders.
  final double top, bottom;

  /// The face's centre across the source.
  final double faceX;

  static const leon = RigArt(
    pivot: Offset(0.518, 0.638),
    headFull: 0.50,
    headNone: 0.72,
    irises: [
      RigIris(
        [
          Offset(582.5, 415.8), Offset(593.3, 406.7), Offset(610, 403.3), Offset(630, 402.5), Offset(648.3, 406.7), Offset(660, 415), //
          Offset(668.3, 426.7), Offset(670, 450), Offset(660, 458.3), Offset(640, 455.8), Offset(618.3, 450), Offset(601.7, 443.3), Offset(586.7, 433.3),
        ],
        Offset(627.5, 429), 27, (Color(0xFFCDB3A3), Color(0xFFEBDDD4)),
      ),
      RigIris(
        [
          Offset(815, 458.3), Offset(830, 450), Offset(850, 448.3), Offset(866.7, 451.7), Offset(878.3, 461.7), Offset(880, 473.3), //
          Offset(878.3, 488.3), Offset(871.7, 498.3), Offset(855, 500), Offset(840, 498.3), Offset(828.3, 491.7), Offset(818.3, 480), Offset(814.2, 468.3),
        ],
        Offset(836.7, 473.7), 24, (Color(0xFFE8CDB6), Color(0xFFFAE6D2)),
      ),
    ],
    brows: [Offset(0.515, 0.275), Offset(0.698, 0.315)],
    lid: (Color(0xFFB8733C), Color(0xFFE29A56)),
    mouth: Offset(0.586, 0.518),
    front: 0.68,
    top: 0.0,
    bottom: 0.80,
    faceX: 0.60,
  );

  static const leona = RigArt(
    pivot: Offset(0.478, 0.622),
    headFull: 0.46,
    headNone: 0.68,
    irises: [
      RigIris(
        [
          Offset(569, 350), Offset(582, 338), Offset(602, 332), Offset(626, 330), Offset(650, 336), Offset(666, 350), Offset(676, 368), //
          Offset(680, 390), Offset(678, 414), Offset(670, 421), Offset(650, 419), Offset(630, 412), Offset(610, 404), Offset(590, 392), Offset(576, 376), Offset(570, 362),
        ],
        Offset(622.4, 373), 41, (Color(0xFFBBA49A), Color(0xFFE9DCD6)),
      ),
      RigIris(
        [
          Offset(845, 436), Offset(856, 422), Offset(874, 414), Offset(896, 412), Offset(912, 420), Offset(922, 434), Offset(924, 450), //
          Offset(921, 466), Offset(912, 480), Offset(894, 488), Offset(874, 486), Offset(860, 476), Offset(849, 460), Offset(844, 448),
        ],
        Offset(873.4, 449), 33.6, (Color(0xFFE5C7B0), Color(0xFFFAE3CC)),
      ),
    ],
    brows: [Offset(0.522, 0.219), Offset(0.735, 0.266)],
    lid: (Color(0xFFB4784A), Color(0xFFE3A062)),
    mouth: Offset(0.614, 0.510),
    front: 0.70,
    top: 0.0,
    bottom: 0.78,
    faceX: 0.62,
  );

  /// Iris measurements are in source pixels; everything else is in fractions of it.
  static const sourcePixels = 1254.0;

  static RigArt of(CoachGuide g) => switch (g) {
    CoachGuide.leon => leon,
    CoachGuide.leona => leona,
  };
}

/// How the bust sits in its box. [edge]: mirrored, so it faces left towards a bubble on its left, leaning in around
/// the box's right edge (Today's screen edge). [inline]: as painted, facing right towards a bubble on its right,
/// whole in a small box (pages and sheets). Right to left, [edge] leans in around the box's left edge instead, as
/// painted (facing the bubble on its right): the artwork itself is never flipped for a language.
enum RigFrame { edge, inline }

/// Everything the rig can show. Each value is small by design.
@immutable
class RigPose {
  const RigPose({this.slide = 1, this.lean = 0, this.tilt = 0, this.nod = 0, this.brow = 0, this.smile = 0, this.blink = 0, this.breath = 0, this.gazeX = 0, this.gazeY = 0});

  /// 1: in place; 0: tucked behind the edge it comes from.
  final double slide;

  /// Rotation of the whole bust about its bottom corner on the edge side, radians. Positive leans back behind the edge.
  final double lean;

  /// Head tilt, -1..1 (negative: towards the bubble). [nod] 0..1, [brow] 0..1 lift, [smile] 0..1 (a happy squint),
  /// [blink] 0..1 closed, [breath] -1..1.
  final double tilt, nod, brow, smile, blink, breath;

  /// Where the eyes look: 0, 0 is at the user; [gazeX] -1 towards the bubble, +1 away; [gazeY] -1 up, +1 down.
  final double gazeX, gazeY;

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

/// Where the painting lands in a [size] box in a [frame] under a pose: the one place this mapping is written, used to
/// draw and to anchor (a bubble's tail at the mouth follows the head exactly).
class RigGeometry {
  RigGeometry(this.art, this.frame, this.size, {this.direction = TextDirection.ltr}) : d = size.height / (art.bottom - art.top) {
    // The face sits at 46% of the box (edge, the back of the head runs off the edge), its mirror image 54% (edge right
    // to left) or 56% (inline, whole).
    left = mirrored
        ? size.width * 0.46 - d * (1 - art.faceX)
        : size.width * (frame == RigFrame.edge ? 0.54 : 0.56) - d * art.faceX;
  }
  final RigArt art;
  final RigFrame frame;
  final Size size;

  /// Right to left, an [RigFrame.edge] bust leans in from the left edge, as painted.
  final TextDirection direction;

  /// The source square's side in logical pixels.
  final double d;
  late final double left;

  bool get mirrored => frame == RigFrame.edge && direction == TextDirection.ltr;

  /// Max head tilt, radians, and the nod's drop and squash, as fractions of the source.
  static const tiltMax = 0.075, _nodDrop = 0.014, _nodSquash = 0.03, _browLift = 0.012, _breathLift = 0.004;

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Where source point [p] (fractions, as painted) goes under [s]: brows, then the head bone, then breathing.
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
      // Towards the bubble (negative) tops the head towards it in both frames: mirrored, the source turns the other way.
      final a = -s.tilt * tiltMax * w;
      final dx = x - art.pivot.dx, dy0 = y - art.pivot.dy;
      final dy = dy0 * (1 - w * s.nod * _nodSquash);
      x = art.pivot.dx + dx * math.cos(a) - dy * math.sin(a);
      y = art.pivot.dy + dx * math.sin(a) + dy * math.cos(a) + w * s.nod * _nodDrop;
    }
    // Breathing lifts the shoulders and everything above them a hair; the bottom row stays put.
    y = 1 - (1 - y) * (1 + s.breath * _breathLift);
    return Offset(x, y);
  }

  /// A source point (fractions) in the box, before the entrance's slide and lean.
  Offset place(Offset p) => Offset(mirrored ? left + d * (1 - p.dx) : left + d * p.dx, d * (p.dy - art.top));

  /// The entrance's slide and lean, as applied to the canvas before the bust is drawn.
  Matrix4 entrance(RigPose s) {
    final m = Matrix4.identity();
    // The edge it comes from: the right one when mirrored, otherwise the left.
    final edgeX = mirrored ? size.width : 0.0;
    m.translateByDouble((mirrored ? 1 : -1) * size.width * 0.9 * (1 - s.slide), 0, 0, 1);
    if (s.lean != 0) {
      m
        ..translateByDouble(edgeX, size.height, 0, 1)
        ..rotateZ(mirrored ? s.lean : -s.lean)
        ..translateByDouble(-edgeX, -size.height, 0, 1);
    }
    return m;
  }

  /// Where a part of the painting (fractions) is in the box under [s], entrance included: the anchor for a bubble.
  Offset point(Offset source, RigPose s) => MatrixUtils.transformPoint(entrance(s), place(deform(source, s)));

  /// The head's own turn on screen at [source] (radians), from how the pose moves a short line through it.
  double turnAt(Offset source, RigPose s) {
    const h = Offset(0.02, 0);
    final a = place(deform(source + h, s)) - place(deform(source, s));
    final b = place(source + h) - place(source);
    return math.atan2(a.dy, a.dx) - math.atan2(b.dy, b.dx);
  }
}

/// The bust in a [size] box in a [frame], faded out at the bottom (and, inline, at the sides), so there is never a
/// cut-off torso or a chopped mane. Decorative.
class RigPortrait extends ConsumerWidget {
  const RigPortrait({super.key, required this.guide, required this.pose, required this.size, this.frame = RigFrame.edge});
  final CoachGuide guide;
  final ValueListenable<RigPose> pose;
  final Size size;
  final RigFrame frame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(rigImageProvider(guide));
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: size,
        child: switch (image) {
          AsyncData(value: final ui.Image img) => ClipRect(
            child: RepaintBoundary(
              child: CustomPaint(key: Key('coach-rig-${guide.name}'), painter: RigPainter(img, RigArt.of(guide), pose, frame: frame, direction: Directionality.of(context))),
            ),
          ),
          // Missing or unreadable texture: the plain round avatar, still and quiet.
          AsyncData() || AsyncError() => Align(
            alignment: const Alignment(0.3, 0.1),
            child: CoachAvatar(key: const Key('coach-rig-fallback'), size: math.min(64, math.min(size.width, size.height)), guide: guide),
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
  RigPainter(this.image, this.art, this.pose, {this.frame = RigFrame.edge, this.direction = TextDirection.ltr}) : super(repaint: pose) {
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
  final RigFrame frame;
  final TextDirection direction;
  final ValueListenable<RigPose> pose;
  late final Float32List _tex;
  late final Uint16List _indices;
  late final ImageShader _shader;
  RigGeometry? _geo;

  RigGeometry _geometry(Size size) => _geo != null && _geo!.size == size ? _geo! : _geo = RigGeometry(art, frame, size, direction: direction);

  @override
  void paint(Canvas canvas, Size size) {
    final s = pose.value;
    if (s.slide <= 0.001) return;
    final g = _geometry(size);

    // Clipped to the box: the mesh runs past it (the rest of the shirt), and an edge row left outside the fade below
    // would show as a hard line.
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..clipRect(Offset.zero & size)
      ..save()
      ..transform(g.entrance(s).storage);

    final n = _grid + 1;
    final pos = Float32List(n * n * 2);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final q = g.place(g.deform(Offset(i / _grid, j / _grid), s));
        pos[(j * n + i) * 2] = q.dx;
        pos[(j * n + i) * 2 + 1] = q.dy;
      }
    }
    final mesh = ui.Vertices.raw(VertexMode.triangles, pos, textureCoordinates: _tex, indices: _indices);
    canvas.drawVertices(mesh, BlendMode.srcOver, Paint()..shader = _shader);
    mesh.dispose(); // the recorded picture keeps its own reference; this handle is not needed past the frame

    for (final iris in art.irises) {
      _iris(canvas, g, iris, s);
      if (s.blink > 0.02 || s.smile > 0.02) _lids(canvas, g, iris, s);
    }

    // The fade, in the box's own frame however the bust leans: no cut edge.
    canvas
      ..restore()
      ..drawRect(Offset.zero & size, Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _fadeFor(size));
    if (frame == RigFrame.inline) {
      canvas.drawRect(Offset.zero & size, Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _sidesFor(size));
    }
    canvas.restore();
  }

  Shader? _fade, _sides;
  Size? _fadeSize, _sidesSize;

  /// The bottom fade, made once per box size rather than every frame.
  Shader _fadeFor(Size size) {
    if (_fadeSize != size) {
      _fadeSize = size;
      _fade = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Color(0x00FFFFFF)], stops: [0, 0.68, 1])
          .createShader(Offset.zero & size);
    }
    return _fade!;
  }

  /// Inline, the mane's outer edges fade out instead of ending at the box.
  Shader _sidesFor(Size size) {
    if (_sidesSize != size) {
      _sidesSize = size;
      _sides = const LinearGradient(colors: [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)], stops: [0, 0.14, 0.92, 1]).createShader(Offset.zero & size);
    }
    return _sides!;
  }

  /// One eye's gaze: inside the opening (clipped to it), the original iris disc is toned to the white, then the same
  /// painted iris is drawn again moved by the gaze (up to 55% of its radius across, 22% up or down), turning with
  /// the head. Only the thin sliver the iris uncovers shows the new tone; lashes, lids and the rest are the painting.
  void _iris(Canvas canvas, RigGeometry g, RigIris iris, RigPose s) {
    if (s.blink > 0.96) return; // closed
    Offset src(Offset px) => Offset(px.dx / RigArt.sourcePixels, px.dy / RigArt.sourcePixels);
    final opening = Path()..addPolygon([for (final p in iris.opening) g.place(g.deform(src(p), s))], true);
    final center = src(iris.center);
    final c = g.place(g.deform(center, s));
    final r = iris.radius / RigArt.sourcePixels * g.d;
    // Screen direction towards the bubble: left when mirrored, right as painted.
    final towards = g.mirrored ? -1.0 : 1.0;
    final shift = Offset(-s.gazeX * towards * 0.55 * r, s.gazeY * 0.22 * r);
    final turn = g.turnAt(center, s);
    final plain = g.place(center);
    final kx = (g.mirrored ? -g.d : g.d) / image.width, ky = g.d / image.height;
    // Image pixels to screen: the undeformed placement, rotated with the head about the iris, moved to where the head
    // and the gaze put it.
    final m = Matrix4.identity()
      ..translateByDouble(c.dx + shift.dx, c.dy + shift.dy, 0, 1)
      ..rotateZ(turn)
      ..translateByDouble(-plain.dx, -plain.dy, 0, 1)
      ..translateByDouble(g.mirrored ? g.left + g.d : g.left, -g.d * g.art.top, 0, 1)
      ..scaleByDouble(kx, ky, 1, 1);
    final disc = Rect.fromCircle(center: c, radius: r * 1.04);
    canvas
      ..save()
      ..clipPath(opening)
      ..drawOval(disc, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [iris.sclera.$1, iris.sclera.$2]).createShader(disc))
      ..drawCircle(c + shift, r * 1.04, Paint()..shader = ImageShader(image, TileMode.clamp, TileMode.clamp, m.storage, filterQuality: FilterQuality.medium))
      ..restore();
  }

  /// The lids: the upper one sweeps down from corner to corner ([RigPose.blink]) over the opening and its painted lash
  /// ring, feathered into the fur, its edge a dark lash line that comes to rest on the eye's lower contour; the lower
  /// one rises a little for the smile's squint. Both follow the opening as the head moves.
  void _lids(Canvas canvas, RigGeometry g, RigIris eye, RigPose s) {
    final pts = [for (final p in eye.opening) g.place(g.deform(Offset(p.dx / RigArt.sourcePixels, p.dy / RigArt.sourcePixels), s))];
    var l = pts.first, r = pts.first, top = pts.first.dy, bottom = pts.first.dy, centre = Offset.zero;
    for (final p in pts) {
      if (p.dx < l.dx) l = p;
      if (p.dx > r.dx) r = p;
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
      centre += p / pts.length.toDouble();
    }
    final h = bottom - top, midX = (l.dx + r.dx) / 2, midY = (l.dy + r.dy) / 2;
    // The opening's upper and lower contour straight across from the corners' middle.
    var upper = bottom, lower = top;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i], q = pts[(i + 1) % pts.length];
      if ((p.dx - midX) * (q.dx - midX) > 0 || p.dx == q.dx) continue;
      final y = p.dy + (q.dy - p.dy) * (midX - p.dx) / (q.dx - p.dx);
      upper = math.min(upper, y);
      lower = math.max(lower, y);
    }
    // A quadratic from corner to corner passes through y at its middle when its control is at 2y - midY.
    double control(double y) => 2 * y - midY;
    // The opening grown over the painted lash ring, so a closed eye shows no outline of it.
    final ring = h * 0.16;
    final cover = Path()..addPolygon([for (final p in pts) p + (p - centre) / math.max(1e-6, (p - centre).distance) * ring], true);
    final box = Rect.fromLTRB(l.dx - h, top - h, r.dx + h, bottom + h);
    final soft = MaskFilter.blur(BlurStyle.normal, math.max(0.3, h * 0.05));
    final blink = s.blink.clamp(0.0, 1.0), smile = s.smile.clamp(0.0, 1.0);
    final edgeY = upper - ring + (lower - upper + ring) * blink;
    if (blink > 0.02) {
      final lid = Path()
        ..moveTo(l.dx - ring, l.dy)
        ..quadraticBezierTo(midX, control(edgeY + ring * blink), r.dx + ring, r.dy)
        ..lineTo(box.right, box.top)
        ..lineTo(box.left, box.top)
        ..close();
      canvas.drawPath(
        Path.combine(PathOperation.intersect, cover, lid),
        Paint()
          ..maskFilter = soft
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [art.lid.$1, art.lid.$2]).createShader(Rect.fromLTRB(box.left, top - ring, box.right, edgeY + 1)),
      );
    }
    if (smile > 0.02) {
      final lid = Path()
        ..moveTo(l.dx - ring, l.dy)
        ..quadraticBezierTo(midX, control(lower - h * 0.3 * smile), r.dx + ring, r.dy)
        ..lineTo(box.right, box.bottom)
        ..lineTo(box.left, box.bottom)
        ..close();
      canvas
        ..save()
        ..clipPath(Path()..addPolygon(pts, true))
        ..drawPath(lid, Paint()..color = art.lid.$2)
        ..restore();
    }
    if (blink > 0.02) {
      // The lash line rides the lid's edge, corner to corner, meeting the painted corners; closed, a gentle curve however
      // narrow the eye (no deeper than a third of its width).
      canvas.drawPath(
        Path()
          ..moveTo(l.dx, l.dy)
          ..quadraticBezierTo(midX, control(math.min(math.max(edgeY, upper), midY + (r.dx - l.dx) * 0.33)), r.dx, r.dy),
        Paint()
          ..color = const Color(0xFF2A1A12).withValues(alpha: math.min(1, blink * 4))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.7, h * 0.09)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(RigPainter old) => old.image != image || old.art != art || old.pose != pose || old.frame != frame || old.direction != direction;
}
