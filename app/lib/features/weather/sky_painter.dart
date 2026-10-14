import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import 'scene_art.dart';

/// The bundled photograph's aspect ratio (1536 x 1024).
const photoAspect = 1.5;

/// Where the ridge meets the sky, and where the lake begins, as fractions of the photograph's height.
const _ridge = 0.44;

/// Which part of a [Sky] to paint. The photograph sits between [back] and [top]:
/// - [back]: the painted sky and its reflection in the lake, seen wherever the photograph is bright (its own sky).
/// - [top]: the same sky over the top of the photograph, where its dusk sky is too dark to be let through.
/// - [front]: still weather in front of the landscape: mist and fog bands, snow cover.
/// What moves (clouds, stars, drifting fog, rain, snow) is [SkyMotionPainter], over all three.
enum SkyLayer { back, top, front }

/// Paints one layer of a [Sky] over the photograph's area (BoxFit.cover, aligned to the top), so the sky lines up
/// with the photograph at any size. Static: painted once, repainted only when the sky changes.
class SkyPainter extends CustomPainter {
  const SkyPainter(this.sky, this.layer);
  final Sky sky;
  final SkyLayer layer;

  static Rect photoRect(Size size) {
    final w = math.max(size.width, size.height * photoAspect);
    return Rect.fromLTWH((size.width - w) / 2, 0, w, w / photoAspect);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = photoRect(size);
    canvas.clipRect(Offset.zero & size);
    switch (layer) {
      case SkyLayer.back:
        _sky(canvas, r);
      case SkyLayer.top:
        canvas.saveLayer(r, Paint());
        _sky(canvas, r);
        canvas.drawRect(r, Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _vertical(r, const [0, 0.28, 0.37], const [Colors.black, Colors.black, Colors.transparent]));
        canvas.restore();
      case SkyLayer.front:
        _weather(canvas, r);
    }
  }

  static Shader _vertical(Rect r, List<double> stops, List<Color> colors) =>
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: stops, colors: colors).createShader(r);

  void _sky(Canvas canvas, Rect r) {
    final w = r.width, h = r.height;
    Offset at(double x, double y) => Offset(r.left + x * w, r.top + y * h);
    canvas.drawRect(r, Paint()..shader = _vertical(r, [0, _ridge, _ridge + 0.02, 1], [sky.zenith, sky.horizon, sky.water[0], sky.water[1]]));

    if (sky.sun > 0) {
      canvas.drawCircle(at(0.8, 0.12), 0.5 * w, Paint()
        ..shader = RadialGradient(stops: const [0, 0.07, 0.3, 1], colors: [
          const Color(0xFFFFFCF2).withValues(alpha: 0.95 * sky.sun),
          const Color(0xFFFFF3D6).withValues(alpha: 0.6 * sky.sun),
          const Color(0xFFFFF3D6).withValues(alpha: 0.18 * sky.sun),
          const Color(0x00FFF3D6),
        ]).createShader(Rect.fromCircle(center: at(0.8, 0.12), radius: 0.5 * w)));
    }

    if (sky.moon) {
      final c = at(0.76, 0.12), m = 0.022 * w;
      canvas.drawCircle(c, m * 7, Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFDDE4F5).withValues(alpha: 0.2), const Color(0x00DDE4F5)])
            .createShader(Rect.fromCircle(center: c, radius: m * 7)));
      canvas.drawCircle(c, m, Paint()..color = const Color(0xFFF1EEE2));
      // A soft shadow over one side turns the disc into a waxing moon.
      canvas.drawCircle(c + Offset(-m * 0.55, -m * 0.1), m * 0.9, Paint()
        ..color = sky.zenith.withValues(alpha: 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m * 0.25));
    }
  }

  void _weather(Canvas canvas, Rect r) {
    final h = r.height;
    void band(double y, double half, double alpha, Color color) => canvas.drawRect(
        Rect.fromLTRB(r.left, r.top + (y - half) * h, r.right, r.top + (y + half) * h),
        Paint()..shader = _vertical(Rect.fromLTRB(r.left, r.top + (y - half) * h, r.right, r.top + (y + half) * h), const [0, 0.5, 1],
            [color.withValues(alpha: 0), color.withValues(alpha: alpha), color.withValues(alpha: 0)]));

    if (sky.ground > 0) {
      final g = Rect.fromLTRB(r.left, r.top + 0.38 * h, r.right, r.bottom);
      canvas.drawRect(g, Paint()..shader = _vertical(g, const [0, 0.25, 1],
          [sky.groundColor.withValues(alpha: 0), sky.groundColor.withValues(alpha: sky.ground), sky.groundColor.withValues(alpha: sky.ground * 0.8)]));
    }
    if (sky.fog) {
      // Layered banks: thickest along the ridge and the far shore, so the hills all but disappear.
      for (final (y, half, a) in const [(0.12, 0.14, 0.35), (0.3, 0.1, 0.7), (0.4, 0.09, 0.9), (0.48, 0.08, 0.85), (0.58, 0.1, 0.6), (0.74, 0.14, 0.45)]) {
        band(y, half, a, sky.hazeColor);
      }
    }
    if (sky.haze > 0) band(_ridge + 0.02, 0.12, sky.haze, sky.hazeColor);
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.sky != sky || old.layer != layer;
}

/// The moving parts of a [Sky], over the photograph and its still layers: twinkling stars, drifting clouds, sliding
/// fog, falling rain and snow. Driven by one repeating [clock] (0..1 over [period]) through `repaint:`, so a frame
/// repaints this layer only. Every particle is placed once from a fixed seed; a frame only moves the precomputed
/// points into reused buffers and draws them in a few batched calls (one per depth layer), with Paints made once per
/// size and only recoloured. Every motion completes a whole number of cycles per [period], so the loop has no seam.
class SkyMotionPainter extends CustomPainter {
  SkyMotionPainter(this.sky, this.clock) : super(repaint: clock) {
    final rnd = math.Random(5);
    // Stars sit in the clear top of the sky, away from the moon, in six groups that each twinkle on their own beat.
    for (var i = 0; i < sky.stars; i++) {
      final x = rnd.nextDouble(), y = 0.01 + rnd.nextDouble() * rnd.nextDouble() * 0.2;
      if (sky.moon && (x - 0.76).abs() < 0.07 && (y - 0.12).abs() < 0.09) continue;
      _stars.add((x, y, i % 6));
    }
    final c = math.Random(17);
    for (var i = 0; i < sky.clouds; i++) {
      // Near clouds (every third) are larger and drift twice as fast as far ones: a slow parallax.
      final near = i % 3 == 0;
      final x = c.nextDouble(), y = sky.puffy ? 0.07 + c.nextDouble() * (sky.cloudLow - 0.2) : 0.02 + c.nextDouble() * (sky.cloudLow - 0.08);
      final rw = sky.puffy ? 0.11 + c.nextDouble() * 0.13 : (0.18 + c.nextDouble() * 0.3) * (near ? 1.2 : 1);
      final rh = sky.puffy ? 0.0 : 0.03 + c.nextDouble() * 0.05;
      _clouds.add((x, y, rw, rh, near ? 2 : 1, c.nextInt(1 << 20)));
    }
    if (sky.fog) {
      final f = math.Random(23);
      for (var i = 0; i < 8; i++) {
        _fog.add((f.nextDouble(), 0.24 + f.nextDouble() * 0.42, 0.45 + f.nextDouble() * 0.5, 0.03 + f.nextDouble() * 0.035, i.isEven ? 1 : -1, f.nextDouble()));
      }
    }
    // Rain: far, middle and near streaks; heavier rain (storm) is denser, up to 120 streaks.
    if (sky.rain > 0) {
      final r = math.Random(9);
      for (final n in [40, 30, 20]) {
        final count = (n * math.min(sky.rain, 4 / 3)).round();
        _rain.add(([for (var i = 0; i < count; i++) (r.nextDouble(), r.nextDouble(), 0.7 + r.nextDouble() * 0.6)], Float32List(count * 4)));
      }
    }
    // Snow: small far flakes to larger near ones, 84 in all, each swaying on its own phase.
    if (sky.snow > 0) {
      final r = math.Random(13);
      for (final n in [34, 28, 22]) {
        _snow.add(([for (var i = 0; i < n; i++) (r.nextDouble(), r.nextDouble(), r.nextDouble())], Float32List(n * 2)));
      }
    }
  }

  /// One loop of the clock. Long, so the slowest drift (the far clouds: their width and the view's in a loop) stays
  /// gentle, about 5 px a second on a phone.
  static const period = Duration(seconds: 120);

  final Sky sky;
  final Animation<double> clock;

  final _stars = <(double, double, int)>[];
  final _clouds = <(double, double, double, double, int, int)>[];
  final _fog = <(double, double, double, double, int, double)>[];
  final _rain = <(List<(double, double, double)>, Float32List)>[];
  final _snow = <(List<(double, double, double)>, Float32List)>[];

  /// Particle counts, for tests and the performance budget.
  int get rainStreaks => _rain.fold(0, (n, l) => n + l.$1.length);
  int get snowFlakes => _snow.fold(0, (n, l) => n + l.$1.length);

  /// Whether anything moves at all: a clear day is a still picture and needs no clock.
  bool get moves => _stars.isNotEmpty || _clouds.isNotEmpty || _fog.isNotEmpty || _rain.isNotEmpty || _snow.isNotEmpty;

  // Made once per size (blur radii and stroke widths follow it).
  Size? _size;
  final _starPoints = <Float32List>[];
  final _starPaints = List.generate(6, (_) => Paint()..strokeCap = StrokeCap.round);
  final _cloudShapes = <(List<Rect>, List<Paint>)>[];
  final _fogShapes = <(Rect, Paint)>[];
  final _rainPaints = List.generate(3, (_) => Paint()..strokeCap = StrokeCap.round);
  final _snowPaints = List.generate(3, (_) => Paint()..strokeCap = StrokeCap.round);

  static const _turn = 2 * math.pi;
  static double _wrap(double v) => v - v.floorToDouble();

  void _layout(Size size, Rect r) {
    _size = size;
    final w = r.width, h = r.height, s = w / 390;
    _starPoints.clear();
    for (var g = 0; g < 6; g++) {
      _starPoints.add(Float32List.fromList([for (final st in _stars.where((st) => st.$3 == g)) ...[r.left + st.$1 * w, r.top + st.$2 * h]]));
      _starPaints[g].strokeWidth = (0.9 + g * 0.22) * s;
    }
    _cloudShapes.clear();
    for (final (_, _, rw, rh, _, seed) in _clouds) {
      final cw = rw * w, rnd = math.Random(seed);
      final rects = <Rect>[], paints = <Paint>[];
      if (sky.puffy) {
        // A row of rounded puffs, the middle ones highest, over a flat shaded base.
        final ch = cw * 0.36;
        rects.add(Rect.fromCenter(center: Offset(0, ch * 0.3), width: cw, height: ch * 0.55));
        paints.add(Paint()
          ..color = sky.cloudShadow!.withValues(alpha: 0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, ch * 0.12));
        for (var k = 0; k < 4; k++) {
          final t = (k + 0.5) / 4, rad = cw * (0.13 + 0.09 * math.sin(t * math.pi)) * (0.85 + rnd.nextDouble() * 0.3);
          rects.add(Rect.fromCircle(center: Offset((t - 0.5) * cw * 0.74, ch * 0.2 - rad * 0.6), radius: rad));
          paints.add(Paint()
            ..color = sky.cloud!.withValues(alpha: 0.85)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.16));
        }
      } else {
        final ch = rh * h;
        rects.add(Rect.fromCenter(center: Offset(0, ch * 0.35), width: cw, height: ch));
        paints.add(Paint()
          ..color = sky.cloudShadow!.withValues(alpha: 0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, ch * 0.45));
        rects.add(Rect.fromCenter(center: Offset(0, -ch * 0.2), width: cw * 0.8, height: ch * 0.7));
        paints.add(Paint()
          ..color = sky.cloud!.withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, ch * 0.4));
      }
      _cloudShapes.add((rects, paints));
    }
    _fogShapes.clear();
    for (final (_, _, fw, fh, _, _) in _fog) {
      final ch = fh * h;
      _fogShapes.add((Rect.fromCenter(center: Offset.zero, width: fw * w, height: ch), Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, ch * 0.6)));
    }
    final rainColor = Color.lerp(sky.horizon, Colors.white, 0.6)!;
    for (var l = 0; l < 3; l++) {
      _rainPaints[l]
        ..strokeWidth = (0.55 + l * 0.3) * s
        ..color = rainColor.withValues(alpha: math.min(1, const [0.14, 0.2, 0.28][l] * math.sqrt(sky.rain)));
      _snowPaints[l]
        ..strokeWidth = (1.4 + l * 1.1) * s
        ..color = Colors.white.withValues(alpha: const [0.5, 0.64, 0.76][l] * sky.snow);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = SkyPainter.photoRect(size);
    if (size != _size) _layout(size, r);
    final t = clock.value, w = r.width, h = r.height, s = w / 390;
    canvas.clipRect(Offset.zero & size);

    // Stars: each group's brightness rises and falls by a quarter, every 3 to 5 seconds. Never a flash.
    for (var g = 0; g < _starPoints.length; g++) {
      if (_starPoints[g].isEmpty) continue;
      final beat = 0.75 + 0.25 * math.sin(_turn * ((24 + g * 5) * t + g / 6));
      canvas.drawRawPoints(PointMode.points, _starPoints[g], _starPaints[g]..color = Color.fromRGBO(232, 238, 255, 0.6 * beat));
    }

    // Clouds drift to the right and wrap: in a loop each travels the view's width plus its own (twice, for near ones),
    // so it enters on the left as it leaves on the right.
    for (var i = 0; i < _clouds.length; i++) {
      final (x0, y, rw, _, laps, _) = _clouds[i];
      final x = _wrap(x0 + laps * t) * (1 + rw) - rw / 2;
      final (rects, paints) = _cloudShapes[i];
      canvas
        ..save()
        ..translate(r.left + x * w, r.top + y * h);
      for (var k = 0; k < rects.length; k++) {
        canvas.drawOval(rects[k], paints[k]);
      }
      canvas.restore();
    }

    // Fog: soft banks slide very slowly, alternating directions, and thicken and thin over about 20 seconds.
    for (var i = 0; i < _fog.length; i++) {
      final (x0, y, fw, _, dir, phase) = _fog[i];
      final x = _wrap(x0 + dir * t) * (1 + fw) - fw / 2;
      final (rect, paint) = _fogShapes[i];
      canvas
        ..save()
        ..translate(r.left + x * w, r.top + y * h)
        ..drawOval(rect, paint..color = sky.hazeColor.withValues(alpha: 0.42 + 0.14 * math.sin(_turn * (6 * t + phase))))
        ..restore();
    }

    // Rain falls through the header itself (not the whole photograph), in fine streaks leaning left as they fall:
    // about 280, 370 and 460 px a second for the far, middle and near layers on a phone header, a little faster when
    // heavy.
    final fallW = size.width, fallH = size.height;
    for (var l = 0; l < _rain.length; l++) {
      final (drops, buf) = _rain[l];
      final len = (8 + l * 5) * s, laps = ((280 + l * 90) * math.min(sky.rain, 1.4) * 120 / 230).round();
      for (var i = 0; i < drops.length; i++) {
        final (x0, y0, k) = drops[i];
        final y = _wrap(y0 + laps * t) * (fallH + len * k) - len * k;
        final x = _wrap(x0 - 0.28 * y / fallW) * fallW;
        buf
          ..[i * 4] = x
          ..[i * 4 + 1] = y
          ..[i * 4 + 2] = x - len * k * 0.28
          ..[i * 4 + 3] = y + len * k;
      }
      canvas.drawRawPoints(PointMode.lines, buf, _rainPaints[l]);
    }

    // Snow drifts down slowly (about 14 to 32 px a second, far flakes slowest), each flake swaying a few pixels on its
    // own six-second beat.
    for (var l = 0; l < _snow.length; l++) {
      final (flakes, buf) = _snow[l];
      final laps = ((14 + l * 9) * 120 / 230).round(), sway = (3 + l * 2) * s;
      for (var i = 0; i < flakes.length; i++) {
        final (x0, y0, phase) = flakes[i];
        buf
          ..[i * 2] = _wrap(x0 + sway * math.sin(_turn * (20 * t + phase)) / fallW) * fallW
          ..[i * 2 + 1] = _wrap(y0 + laps * t) * (fallH + 8) - 4;
      }
      canvas.drawRawPoints(PointMode.points, buf, _snowPaints[l]);
    }
  }

  @override
  bool shouldRepaint(SkyMotionPainter old) => old.sky != sky || old.clock != clock;
}
