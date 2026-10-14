import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';

/// Renders the real photograph under every scene treatment in all six looks, with the header's own scrim
/// (GoColors.scrim, which TabHeader(onBackdrop: true) paints solid behind its lines) over the band the date, title
/// and greeting occupy, and measures pixel by pixel the contrast of the colour that text is drawn in (c.text).
/// Above that band the scene shows with only the backdrop's light veil, and carries no text.
void main() {
  double ratio(double a, double b) => (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
  double channel(int v) {
    final c = v / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  // Where Today's date, title and greeting sit within its header (60 px of open scene above them).
  const textTop = 60, textBottom = 200;
  final keys = ['dusk', for (final f in weatherFamilies) ...['$f-day', '$f-night', '$f-neutral']];
  SceneSpec spec(String k) =>
      k == 'dusk' ? SceneSpec.dusk : SceneSpec(key: k, isWeather: true, family: k.split('-').first, isDay: k.endsWith('-day') ? true : k.endsWith('-night') ? false : null);

  for (final accent in Accent.values) {
    for (final brightness in Brightness.values) {
      testWidgets('header text stays readable over every scene: ${accent.name} ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 220);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = goTheme(accent, brightness);
        final colors = theme.extension<GoColors>()!;
        final boundary = GlobalKey();
        for (final k in keys) {
          await tester.pumpWidget(MaterialApp(
              theme: theme,
              home: RepaintBoundary(
                  key: boundary,
                  child: SizedBox(
                      width: 390,
                      height: 220,
                      child: Stack(children: [
                        Positioned.fill(child: SceneBackdrop(spec: spec(k))),
                        Positioned(left: 0, right: 0, top: textTop.toDouble(), bottom: 220.0 - textBottom, child: ColoredBox(color: colors.scrim)),
                      ])))));
          await tester.runAsync(() async {
            for (final e in find.byType(Image).evaluate()) {
              await precacheImage((e.widget as Image).image, e);
            }
          });
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('scene-photo')), findsOneWidget);
          final worst = await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
            final raw = (await image.toByteData())!;
            var text = 99.0;
            for (var y = textTop; y < textBottom; y += 2) {
              for (var x = 0; x < image.width; x += 2) {
                final o = (y * image.width + x) * 4;
                final l = 0.2126 * channel(raw.getUint8(o)) + 0.7152 * channel(raw.getUint8(o + 1)) + 0.0722 * channel(raw.getUint8(o + 2));
                text = math.min(text, ratio(l, colors.text.computeLuminance()));
              }
            }
            image.dispose();
            return text;
          });
          // 7:1 against the worst pixel: comfortably above 4.5:1 for the date and greeting and 3:1 for the title.
          expect(worst!, greaterThanOrEqualTo(7), reason: '$k: header text over the scene');
        }
      });
    }
  }
}
