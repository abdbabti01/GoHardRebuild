import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scene_art.dart';

/// The bundled photograph's aspect ratio (1536 x 1024).
const photoAspect = 1.5;

/// Where the ridge meets the sky, and where the lake begins, as fractions of the photograph's height.
const _ridge = 0.44;

/// Which part of a [Sky] to paint. The photograph sits between [back] and [top]:
/// - [back]: the painted sky and its reflection in the lake, seen wherever the photograph is bright (its own sky).
/// - [top]: the same sky over the top of the photograph, where its dusk sky is too dark to be let through.
/// - [front]: weather in front of the landscape: mist and fog bands, snow cover, rain streaks, snow.
enum SkyLayer { back, top, front }

/// Paints one layer of a [Sky] over the photograph's area (BoxFit.cover, aligned to the top), so the sky lines up
/// with the photograph at any size. Static and deterministic: fixed seeds, painted once, never animated.
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
    final w = r.width, h = r.height, s = w / 390;
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

    if (sky.stars > 0) {
      final rnd = math.Random(5), star = Paint();
      for (var i = 0; i < sky.stars; i++) {
        final x = rnd.nextDouble(), y = rnd.nextDouble() * rnd.nextDouble() * 0.36, size = (0.35 + rnd.nextDouble() * 0.7) * s;
        canvas.drawCircle(at(x, y), size, star..color = const Color(0xFFE8EEFF).withValues(alpha: 0.2 + rnd.nextDouble() * 0.45));
      }
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

    if (sky.cloud != null && sky.clouds > 0) {
      final rnd = math.Random(17);
      for (var i = 0; i < sky.clouds; i++) {
        final cx = -0.15 + rnd.nextDouble() * 1.3, cy = 0.02 + rnd.nextDouble() * (sky.cloudLow - 0.06);
        final rw = (0.16 + rnd.nextDouble() * 0.3) * w, rh = (0.03 + rnd.nextDouble() * 0.05) * h;
        final c = at(cx, cy);
        canvas.drawOval(Rect.fromCenter(center: c + Offset(0, rh * 0.35), width: rw, height: rh), Paint()
          ..color = sky.cloudShadow!.withValues(alpha: 0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rh * 0.45));
        canvas.drawOval(Rect.fromCenter(center: c - Offset(0, rh * 0.2), width: rw * 0.8, height: rh * 0.7), Paint()
          ..color = sky.cloud!.withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rh * 0.4));
      }
    }
  }

  void _weather(Canvas canvas, Rect r) {
    final w = r.width, h = r.height, s = w / 390;
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
      final rnd = math.Random(23);
      for (var i = 0; i < 9; i++) {
        final c = Offset(r.left + rnd.nextDouble() * w, r.top + (0.28 + rnd.nextDouble() * 0.4) * h), rh = (0.025 + rnd.nextDouble() * 0.03) * h;
        canvas.drawOval(Rect.fromCenter(center: c, width: (0.4 + rnd.nextDouble() * 0.5) * w, height: rh), Paint()
          ..color = sky.hazeColor.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rh * 0.6));
      }
    }
    if (sky.haze > 0) band(_ridge + 0.02, 0.12, sky.haze, sky.hazeColor);

    if (sky.rain > 0) {
      final rnd = math.Random(9), p = Paint()
        ..strokeWidth = 0.8 * s
        ..strokeCap = StrokeCap.round;
      final color = Color.lerp(sky.horizon, Colors.white, 0.6)!;
      for (var i = 0; i < 240 * sky.rain; i++) {
        final a = Offset(r.left + rnd.nextDouble() * w, r.top + rnd.nextDouble() * h), len = (9 + rnd.nextDouble() * 14) * s;
        canvas.drawLine(a, a + Offset(-len * 0.28, len), p..color = color.withValues(alpha: (0.1 + rnd.nextDouble() * 0.16) * sky.rain));
      }
    }
    if (sky.snow > 0) {
      final rnd = math.Random(13), p = Paint();
      for (var i = 0; i < 160 * sky.snow; i++) {
        final c = Offset(r.left + rnd.nextDouble() * w, r.top + rnd.nextDouble() * h);
        canvas.drawCircle(c, (0.7 + rnd.nextDouble() * 1.3) * s, p..color = Colors.white.withValues(alpha: (0.45 + rnd.nextDouble() * 0.45) * sky.snow));
      }
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.sky != sky || old.layer != layer;
}
