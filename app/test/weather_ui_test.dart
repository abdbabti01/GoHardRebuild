import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/weather/scene_art.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';

import 'ui_support.dart';
import 'weather_fakes.dart';

/// The Today background page and the backdrops, on the app's real themes, with fake location and server.
void main() {
  final now = DateTime.utc(2026, 10, 14, 3, 20);

  Future<(ProviderContainer, WeatherFakes)> open(WidgetTester tester, {WeatherPrefs? prefs, WeatherFakes? fakes, Widget home = const TodayBackgroundScreen()}) async {
    final w = fakes ?? WeatherFakes(now: now);
    final c = await pumpApp(tester, [...await w.overrides(prefs: prefs), sessionsProvider.overrideWithValue(SessionManager(MemorySecretStore()))], home: home, size: const Size(390, 1600)); // tall enough that the whole page is built
    return (c, w);
  }

  testWidgets('choosing Weather explains location before the one system prompt, then shows the conditions and credit', (tester) async {
    final (c, w) = await open(tester);
    expect(find.text('Location'), findsNothing);
    final scenic = tester.getSemantics(find.byKey(const Key('today-background-scenic')));
    expect(scenic.flagsCollection.isChecked, CheckedState.isTrue);

    await tester.tap(find.byKey(const Key('today-background-weather')));
    await tester.pumpAndSettle();
    expect(find.text('Location'), findsOneWidget);
    expect(find.byKey(const Key('weather-issue')), findsOneWidget); // needs permission: said quietly
    expect((w.requests, w.locates, w.currentCalls.length), (0, 0, 0)); // choosing Weather alone never prompts
    expect(find.text('No current weather. Showing the decorative dusk scene.'), findsOneWidget);

    w.answer = (_, _) => w.conditions('cloudy', isDay: false, description: 'Overcast');
    await tester.tap(find.byKey(const Key('weather-location-automatic')));
    await tester.pumpAndSettle();
    expect(find.text('Use your approximate location?'), findsOneWidget);
    expect(w.requests, 0); // the purpose is on screen before the system asks
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(w.requests, 1);
    expect(find.byKey(const Key('weather-condition')), findsOneWidget);
    expect(find.text('Overcast'), findsOneWidget);
    expect(find.textContaining('As of '), findsOneWidget);
    expect(find.textContaining('Weather data by Open-Meteo.com'), findsOneWidget);
    expect(find.textContaining('not a forecast'), findsOneWidget);
    expect(c.read(todaySceneProvider).key, 'cloudy-night');
    expect(c.read(connectionProvider), isNull);
  });

  testWidgets('a permanent refusal offers Settings and a city, and Today keeps its dusk scene', (tester) async {
    final w = WeatherFakes(now: now)..permission = LocatorPermission.deniedForever;
    final (c, _) = await open(tester, prefs: const WeatherPrefs(background: TodayBackground.weather), fakes: w);
    await c.read(weatherProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.textContaining('Allow it in Settings'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect((w.settingsOpened, w.requests), (1, 0));
    await tester.tap(find.byKey(const Key('weather-location-automatic')));
    await tester.pumpAndSettle();
    expect(find.text('Use your approximate location?'), findsNothing); // only Settings can change it now
    expect((c.read(todaySceneProvider).key, c.read(todaySceneProvider).isWeather), ('dusk', false));
  });

  testWidgets('city search shows namesakes apart, and the chosen one is kept with its own coordinates', (tester) async {
    final w = WeatherFakes(now: now)..placesResult = const [parisFr, parisTx];
    w.answer = (lat, lon) => w.conditions('clear', isDay: lat < 40 ? true : false, description: 'Clear sky');
    final (c, _) = await open(tester, prefs: const WeatherPrefs(background: TodayBackground.weather), fakes: w);

    await tester.tap(find.byKey(const Key('weather-location-city')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('city-search-field')), '  Paris ');
    await tester.tap(find.byKey(const Key('city-search-go')));
    await tester.pumpAndSettle();
    expect(w.placesCalls, ['Paris']);
    expect(find.text('Île-de-France Region, France'), findsOneWidget);
    expect(find.text('Texas, United States'), findsOneWidget);

    await tester.tap(find.byKey(const Key('city-result-4717560')));
    await tester.pumpAndSettle();
    expect(c.read(weatherPrefsProvider).city, parisTx);
    expect(c.read(todayBackgroundSummaryProvider), 'Weather · Paris');
    expect(find.text('Paris, Texas, United States'), findsOneWidget);
    expect(w.currentCalls.last, '33.7,-95.6');
    expect(c.read(todaySceneProvider).key, 'clear-day');

    final reopened = WeatherStore(w.secrets);
    await reopened.restore();
    expect((reopened.prefs.mode, reopened.prefs.city), (WeatherLocationMode.city, parisTx));
    expect(reopened.entry!.region, '33.7,-95.6');
  });

  Widget header(Widget backdrop, {bool reduce = false}) => Builder(
      builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: Scaffold(body: Align(alignment: Alignment.topCenter, child: SizedBox(height: 280, width: double.infinity, child: backdrop)))));

  testWidgets('the backdrop crossfades only when the scene changes, instantly under reduced motion, and stays out of semantics', (tester) async {
    for (final reduce in [false, true]) {
      final w = WeatherFakes(now: now);
      final (c, _) = await open(tester, fakes: w, home: header(const TodayBackdrop(), reduce: reduce));
      final switcher = tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      expect(switcher.duration, reduce ? Duration.zero : Motion.progress);
      expect(find.ancestor(of: find.byType(AnimatedSwitcher), matching: find.byType(ExcludeSemantics)), findsWidgets);
      expect(w.currentCalls, isEmpty); // Scenic: nothing is asked

      c.read(weatherPrefsProvider.notifier).setBackground(TodayBackground.plain);
      await tester.pump();
      expect(tester.hasRunningAnimations, !reduce);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scene-photo')), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse); // nothing keeps animating
    }
  });

  testWidgets('Today asks once when it appears and on resume only when stale; rebuilds and the static backdrop ask nothing', (tester) async {
    final w = WeatherFakes(now: now);
    w.answer = (_, _) => w.conditions('snow', isDay: true);
    final (c, _) = await open(tester,
        prefs: const WeatherPrefs(background: TodayBackground.weather, mode: WeatherLocationMode.city, city: quebec),
        fakes: w,
        home: header(const Column(children: [Expanded(child: TodayBackdrop()), Expanded(child: SceneBackdrop(spec: SceneSpec.dusk))])));
    await tester.pumpAndSettle();
    expect(w.currentCalls, ['46.8,-71.2']);
    expect(c.read(todaySceneProvider).key, 'snow-day');

    for (var i = 0; i < 3; i++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }
    expect(w.currentCalls, hasLength(1));

    w.clock.advance(const Duration(minutes: 16));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(w.currentCalls, hasLength(2));
    expect(w.locates, 0); // a selected city never uses the phone's location
  });

  testWidgets('a photograph that cannot be decoded leaves the plain page colour', (tester) async {
    final real = sceneArt['dusk']!;
    sceneArt['dusk'] = const SceneArt(asset: 'assets/scenes/missing.webp');
    addTearDown(() => sceneArt['dusk'] = real);
    await open(tester, home: header(const SceneBackdrop(spec: SceneSpec.dusk)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scene-failed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
