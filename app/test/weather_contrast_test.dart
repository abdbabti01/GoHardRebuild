import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';
import 'package:gohard_rebuild/core/language.dart';

/// Renders the real photograph under every scene treatment in all six looks, with the header's own scrim
/// (GoColors.scrim, which TabHeader(onBackdrop: true) paints solid behind its lines) over the band the date, title
/// and greeting occupy, and measures pixel by pixel the contrast of the colour that text is drawn in (c.text).
/// Above that band the scene shows with only the backdrop's light veil, and carries no text. The header runs to the
/// top edge of a notched phone (47 px status bar): there the shell's StatusBarVeil keeps the system icons (white in
/// Dark, black in Light, from the theme's overlay style) at 3:1 or more over every pixel of the band they sit in.
///
/// Over a weather scene the header follows the sky, not the app mode, like Apple Weather: light text, scrim and
/// status-bar icons (the Dark look's) over a [SceneSpec.dark] sky, dark ones (the Light look's) over the others; the
/// scene itself is still rendered in the app's mode. Dusk keeps the app's own look.
void main() {
  double ratio(double a, double b) => (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
  double channel(int v) {
    final c = v / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  // Today's header on a 390 × 844 phone with a 47 px status bar: 200 px from the top edge, its date, title and
  // guide's bubble and the sky line at 71–290 px (24 px of open scene below the status bar; checked in today_ui_test).
  const status = 47, height = 300, textTop = 71, textBottom = 290;
  // The rows the status-bar icons occupy: the veil's solid part.
  final iconBottom = (status * StatusBarVeil.solid).floor();
  final keys = ['dusk', for (final f in weatherFamilies) ...['$f-day', '$f-night', '$f-neutral']];
  SceneSpec spec(String k) =>
      k == 'dusk' ? SceneSpec.dusk : SceneSpec(key: k, isWeather: true, family: k.split('-').first, isDay: k.endsWith('-day') ? true : k.endsWith('-night') ? false : null);

  for (final accent in Accent.values) {
    for (final brightness in Brightness.values) {
      testWidgets('header text and status-bar icons stay readable over every scene: ${accent.name} ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390, height + 0.0);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = goTheme(accent, brightness);
        final boundary = GlobalKey();
        for (final k in keys) {
          final look = spec(k).isWeather ? goTheme(accent, spec(k).dark ? Brightness.dark : Brightness.light) : theme;
          final colors = look.extension<GoColors>()!;
          final icons = look.appBarTheme.systemOverlayStyle!.statusBarIconBrightness == Brightness.light ? Colors.white : Colors.black;
          await tester.pumpWidget(MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
              theme: theme,
              home: MediaQuery(
                  data: const MediaQueryData(size: Size(390, height + 0.0), padding: EdgeInsets.only(top: status + 0.0)),
                  child: RepaintBoundary(
                      key: boundary,
                      child: SizedBox(
                          width: 390,
                          height: height + 0.0,
                          child: Stack(children: [
                            Positioned.fill(child: SceneBackdrop(spec: spec(k), animate: false)),
                            Positioned(left: 0, right: 0, top: textTop.toDouble(), bottom: height - textBottom + 0.0, child: ColoredBox(color: colors.scrim)),
                            Positioned(top: 0, left: 0, right: 0, child: Theme(data: look, child: const StatusBarVeil())),
                          ]))))));
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
            double lum(int o) => 0.2126 * channel(raw.getUint8(o)) + 0.7152 * channel(raw.getUint8(o + 1)) + 0.0722 * channel(raw.getUint8(o + 2));
            var bar = 99.0;
            for (var y = 0; y < iconBottom; y += 2) {
              for (var x = 0; x < image.width; x += 2) {
                bar = math.min(bar, ratio(lum((y * image.width + x) * 4), icons.computeLuminance()));
              }
            }
            var text = 99.0;
            for (var y = textTop; y < textBottom; y += 2) {
              for (var x = 0; x < image.width; x += 2) {
                final o = (y * image.width + x) * 4;
                final l = 0.2126 * channel(raw.getUint8(o)) + 0.7152 * channel(raw.getUint8(o + 1)) + 0.0722 * channel(raw.getUint8(o + 2));
                text = math.min(text, ratio(l, colors.text.computeLuminance()));
              }
            }
            image.dispose();
            return (text, bar);
          });
          final (text, bar) = worst!;
          debugPrint('${accent.name} ${brightness.name} $k: text ${text.toStringAsFixed(1)}:1, status bar ${bar.toStringAsFixed(1)}:1');
          // 7:1 against the worst pixel over dusk: comfortably above 4.5:1 for the date and greeting and 3:1 for the
          // title. A weather sky has no page veil, and its worst pixel is a single snowflake under the scrim or the last
          // rows of the fade into a light page under light text (measured 6.4:1): 6:1 there, still well above 4.5:1.
          expect(text, greaterThanOrEqualTo(spec(k).isWeather ? 6 : 7), reason: '$k: header text over the scene');
          expect(bar, greaterThanOrEqualTo(3), reason: '$k: status-bar icons over the scene');
        }
      });
    }
  }
}
