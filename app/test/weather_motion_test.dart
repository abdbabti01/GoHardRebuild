import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/features/weather/backdrop.dart' show SkyMotion;
import 'package:gohard_rebuild/features/weather/scene_art.dart';
import 'package:gohard_rebuild/features/weather/sky_painter.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';
import 'package:gohard_rebuild/core/language.dart';

/// The moving layer of a weather sky, driven directly (in the app it appears once the photograph has decoded):
/// it moves only while it may, and stops for Reduce Motion, a hidden tab, a page on top and the app in the background.
void main() {
  Sky sky(String key) => sceneArt[key]!.sky!;

  Widget host({required Sky of, bool animate = true, bool reduce = false}) => MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
        theme: goTheme(Accent.blue, Brightness.dark),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: SizedBox(width: 390, height: 280, child: SkyMotion(sky: of, animate: animate)),
          ),
        ),
      );

  double phase(WidgetTester tester) =>
      ((tester.widget<CustomPaint>(find.byKey(const ValueKey('sky-motion'), skipOffstage: false)).painter! as SkyMotionPainter).clock).value;

  testWidgets('every weather sky with clouds, rain, snow, fog or stars moves; a cloudless daylight sky is still', (tester) async {
    for (final key in sceneKeys.where((k) => k != 'dusk' && k != 'plain')) {
      await tester.pumpWidget(host(of: sky(key)));
      final painter = tester.widget<CustomPaint>(find.byKey(const ValueKey('sky-motion'))).painter! as SkyMotionPainter;
      final still = key == 'clear-day' || key == 'clear-neutral';
      expect(painter.moves, !still, reason: still ? '$key: nothing in a clear daytime sky to move' : '$key has something that moves');
      if (still) continue;
      final before = phase(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(phase(tester), isNot(before), reason: '$key moves over time');
      expect(tester.binding.hasScheduledFrame, isTrue);
    }
    await tester.pumpWidget(const SizedBox()); // disposes the ticker: no pending frames or timers left
  });

  testWidgets('Reduce Motion (the phone or the app) and animate: false draw one still frame and schedule nothing', (tester) async {
    for (final (reduce, animate) in [(true, true), (false, false)]) {
      await tester.pumpWidget(host(of: sky('rain-day'), reduce: reduce, animate: animate));
      final before = phase(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(phase(tester), before, reason: 'reduce: $reduce, animate: $animate');
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
  });

  testWidgets('the app in the background stops the sky; back in front it moves again', (tester) async {
    await tester.pumpWidget(host(of: sky('snow-day')));
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = phase(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(phase(tester), paused);
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(); // the ticker restarts on the next frame
    await tester.pump(const Duration(milliseconds: 400));
    expect(phase(tester), isNot(paused));
  });

  testWidgets('a page pushed over Today stops the sky until it is closed', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, navigatorKey: nav, home: SizedBox(width: 390, height: 280, child: SkyMotion(sky: sky('cloudy-day')))));
    await tester.pump(const Duration(milliseconds: 300));
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('on top'))));
    await tester.pumpAndSettle(); // settles: the sky underneath no longer schedules frames
    final covered = phase(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(phase(tester), covered);
    nav.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(phase(tester), isNot(covered));
  });
}
