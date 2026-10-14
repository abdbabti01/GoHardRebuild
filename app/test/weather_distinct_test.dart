import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';

/// "Distinct" measured, not asserted: every scene key is rendered at Today's header size (390 x 280) over the real
/// photograph, in Light and Dark, and compared two ways: the mean per-pixel colour difference (0..1 of full scale;
/// every scene shares one camera, so this is how far apart the two pictures look) and a colour histogram (8 x 8 x 8
/// bins, half the L1 distance: 0 = the same colours, 1 = none in common). Each pair of families in the same light, day
/// and night of each family, and every weather scene against the dusk default must differ by more than [minPixel]
/// per pixel and [minHistogram] in colour.
///
/// The same renders check [SceneSpec.dark]: the header text is drawn light over a dark scene and dark over the
/// others, in both app modes, so the band it sits in (below the status bar, above where the scene fades into the page)
/// must measure dark or light accordingly. Mean relative luminance at most [darkMax] against white text is better than
/// 8:1; at least [lightMin] against near-black text (about 0.01) is better than 5:1, before the header's own scrim.
void main() {
  const darkMax = 0.08, lightMin = 0.25;
  // The lower part of the header fades into the page, which dilutes the per-pixel figure: 0.03 here is roughly twice
  // that over the visible scene. Measured minimums: 0.034 per pixel (fog vs snow by day, Dark) and 0.19 histogram.
  const minPixel = 0.03, minHistogram = 0.15;
  const w = 390, h = 280;
  SceneSpec spec(String k) =>
      k == 'dusk' ? SceneSpec.dusk : SceneSpec(key: k, isWeather: true, family: k.split('-').first, isDay: k.endsWith('-day') ? true : k.endsWith('-night') ? false : null);

  testWidgets('a weather scene leaves the page around it untouched', (tester) async {
    tester.view.physicalSize = const Size(100, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: goTheme(Accent.blue, Brightness.light),
        home: RepaintBoundary(
            key: boundary,
            child: const Stack(children: [
              Positioned.fill(child: ColoredBox(color: Color(0xFFFF0000))),
              Positioned(left: 0, right: 0, top: 0, height: 100, child: SceneBackdrop(spec: SceneSpec(key: 'clear-night', isWeather: true, family: 'clear', isDay: false), animate: false)),
            ]))));
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pumpAndSettle();
    final raw = (await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      final bytes = (await image.toByteData())!;
      image.dispose();
      return bytes;
    }))!;
    final o = (250 * 100 + 50) * 4;
    expect([raw.getUint8(o), raw.getUint8(o + 1), raw.getUint8(o + 2)], [255, 0, 0], reason: 'the colour filter must not reach outside the photograph');
  });

  for (final brightness in Brightness.values) {
    testWidgets('every scene renders and the conditions, and day and night, look different: ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final hist = <String, List<double>>{}, lum = <String, double>{}, pixels = <String, ByteData>{}, band = <String, double>{};
      for (final k in sceneKeys.where((k) => k != 'plain')) {
        await tester.pumpWidget(MaterialApp(
            theme: goTheme(Accent.blue, brightness),
            home: RepaintBoundary(key: boundary, child: SizedBox(width: w.toDouble(), height: h.toDouble(), child: SceneBackdrop(spec: spec(k), animate: false)))));
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: k);
        expect(find.byKey(const ValueKey('scene-photo')), findsOneWidget, reason: k);
        final raw = (await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
          final bytes = (await image.toByteData())!;
          image.dispose();
          return bytes;
        }))!;
        final (bins, mean) = _measure(raw);
        hist[k] = bins;
        pixels[k] = raw;
        lum[k] = mean;
        band[k] = _bandLuminance(raw, w, 47, (h * 0.6).round());
      }

      double d(String a, String b) => [for (var i = 0; i < 512; i++) (hist[a]![i] - hist[b]![i]).abs()].reduce((x, y) => x + y) / 2;
      double px(String a, String b) {
        final x = pixels[a]!, y = pixels[b]!;
        var sum = 0;
        for (var o = 0; o < x.lengthInBytes; o++) {
          if (o % 4 != 3) sum += (x.getUint8(o) - y.getUint8(o)).abs();
        }
        return sum / (x.lengthInBytes * 0.75 * 255);
      }
      final pairs = <(String, String)>[
        for (final light in ['day', 'night'])
          for (var i = 0; i < weatherFamilies.length; i++)
            for (var j = i + 1; j < weatherFamilies.length; j++) ('${weatherFamilies[i]}-$light', '${weatherFamilies[j]}-$light'),
        for (final f in weatherFamilies) ('$f-day', '$f-night'),
        for (final f in weatherFamilies) for (final light in ['day', 'night']) ('$f-$light', 'dusk'),
      ];
      final report = StringBuffer('${brightness.name}: per-pixel / histogram / mean luminance difference\n');
      var worst = (1.0, ''), worstH = (1.0, '');
      for (final (a, b) in pairs) {
        final v = px(a, b), hd = d(a, b);
        report.writeln('  $a vs $b: ${v.toStringAsFixed(3)} / ${hd.toStringAsFixed(2)} / ${(lum[a]! - lum[b]!).abs().toStringAsFixed(3)}');
        if (v < worst.$1) worst = (v, '$a vs $b');
        if (hd < worstH.$1) worstH = (hd, '$a vs $b');
      }
      for (final k in band.keys.where((k) => k != 'dusk')) {
        report.writeln('  band $k ${spec(k).dark ? 'dark' : 'light'}: ${band[k]!.toStringAsFixed(3)}');
      }
      report.writeln('  smallest per-pixel: ${worst.$2} ${worst.$1.toStringAsFixed(3)}; smallest histogram: ${worstH.$2} ${worstH.$1.toStringAsFixed(2)}');
      // ignore: avoid_print
      print(report);
      for (final k in band.keys.where((k) => k != 'dusk')) {
        if (spec(k).dark) {
          expect(band[k], lessThanOrEqualTo(darkMax), reason: '$k is a dark scene: light text goes over it');
        } else {
          expect(band[k], greaterThanOrEqualTo(lightMin), reason: '$k is a light scene: dark text goes over it');
        }
      }
      for (final (a, b) in pairs) {
        expect(px(a, b), greaterThan(minPixel), reason: '$a and $b look too alike');
        expect(d(a, b), greaterThan(minHistogram), reason: '$a and $b have too alike colours');
      }
    });
  }
}

/// A normalised 512-bin colour histogram and the mean relative luminance of one RGBA image.
(List<double>, double) _measure(ByteData raw) {
  final bins = List<double>.filled(512, 0);
  var sum = 0.0, n = 0;
  for (var o = 0; o < raw.lengthInBytes; o += 4) {
    final r = raw.getUint8(o), g = raw.getUint8(o + 1), b = raw.getUint8(o + 2);
    bins[(r >> 5) * 64 + (g >> 5) * 8 + (b >> 5)]++;
    sum += 0.2126 * math.pow(r / 255, 2.2) + 0.7152 * math.pow(g / 255, 2.2) + 0.0722 * math.pow(b / 255, 2.2);
    n++;
  }
  return ([for (final v in bins) v / n], sum / n);
}

/// Mean sRGB relative luminance of rows [top]..[bottom] of a [width]-wide RGBA image.
double _bandLuminance(ByteData raw, int width, int top, int bottom) {
  double channel(int v) {
    final c = v / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }
  var sum = 0.0;
  for (var y = top; y < bottom; y++) {
    for (var x = 0; x < width; x++) {
      final o = (y * width + x) * 4;
      sum += 0.2126 * channel(raw.getUint8(o)) + 0.7152 * channel(raw.getUint8(o + 1)) + 0.0722 * channel(raw.getUint8(o + 2));
    }
  }
  return sum / ((bottom - top) * width);
}
