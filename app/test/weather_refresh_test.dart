import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';

import 'weather_fakes.dart';

/// Fetching, keeping and superseding weather, through the controller with fake location and a fake server.
void main() {
  final now = DateTime.utc(2026, 10, 14, 3, 20);
  const cityPrefs = WeatherPrefs(background: TodayBackground.weather, mode: WeatherLocationMode.city, city: quebec);

  Future<(ProviderContainer, WeatherFakes)> start({WeatherPrefs? prefs, WeatherFakes? fakes}) async {
    final w = fakes ?? WeatherFakes(now: now);
    final c = ProviderContainer(overrides: [
      ...await w.overrides(prefs: prefs),
      // Weather must work without the account: these would throw if it reached for sync, the database or a session.
      syncProvider.overrideWith((ref) => throw StateError('weather touched sync')),
      sessionsProvider.overrideWith((ref) => throw StateError('weather touched the session')),
    ]);
    addTearDown(c.dispose);
    c.read(weatherProvider);
    return (c, w);
  }

  WeatherController controller(ProviderContainer c) => c.read(weatherProvider.notifier);

  test('Scenic and Plain never locate, prompt or ask the server, and work from a fresh store', () async {
    for (final b in [TodayBackground.scenic, TodayBackground.plain]) {
      final (c, w) = await start(prefs: WeatherPrefs(background: b));
      await controller(c).refresh(force: true);
      expect((w.checks, w.requests, w.locates, w.currentCalls.length), (0, 0, 0, 0));
      expect(c.read(todaySceneProvider).key, b == TodayBackground.plain ? 'plain' : 'dusk');
    }
    final (c, w) = await start(); // nothing ever saved: a fresh install or an upgrade from before this setting
    expect(c.read(weatherPrefsProvider).background, TodayBackground.scenic);
    expect(c.read(todayBackgroundSummaryProvider), 'Scenic');
    await controller(c).refresh();
    expect(w.currentCalls, isEmpty);
  });

  test('a selected city is fetched once, kept across a restart and refreshed only after 15 minutes', () async {
    final (c, w) = await start(prefs: cityPrefs);
    w.answer = (_, _) => w.conditions('rain', isDay: false);
    await controller(c).refresh();
    expect(w.currentCalls, ['46.8,-71.2']);
    expect(c.read(todaySceneProvider).key, 'rain-night');
    expect(c.read(todayBackgroundSummaryProvider), 'Weather · Québec');

    await controller(c).refresh(); // Today appearing again, a tab tap, a rebuild
    await controller(c).refresh();
    expect(w.currentCalls, hasLength(1));

    // Restart: a new container over the same device store, no network.
    w.failWith = offline;
    final (again, _) = await start(fakes: w);
    expect(again.read(todaySceneProvider).key, 'rain-night');

    w.clock.advance(const Duration(minutes: 16));
    await controller(again).refresh();
    expect(w.currentCalls, hasLength(2)); // stale enough to ask; the failure keeps the still-fresh scene
    expect(again.read(todaySceneProvider).key, 'rain-night');
    expect(again.read(weatherProvider).issue, WeatherIssue.offline);

    await controller(again).refresh();
    expect(w.currentCalls, hasLength(2)); // no retry storm: the next attempt waits

    w.clock.advance(const Duration(minutes: 45)); // the kept conditions are now more than 60 minutes old
    await controller(again).refresh();
    expect((again.read(todaySceneProvider).key, again.read(todaySceneProvider).label, again.read(todaySceneProvider).fallback), ('dusk', null, WeatherFallback.stale));
  });

  test('changing city drops the late answer for the old one', () async {
    final (c, w) = await start(prefs: cityPrefs);
    w.hold = true;
    final first = controller(c).refresh();
    expect(w.held.single.region, '46.8,-71.2');

    c.read(weatherPrefsProvider.notifier).selectCity(parisFr);
    await pumpEventQueue();
    expect(w.held.last.region, '48.9,2.3');

    w.held.last.done.complete(w.conditions('clear', isDay: false));
    await pumpEventQueue();
    w.held.first.done.complete(w.conditions('snow', isDay: true)); // Québec answering last
    await first;
    await pumpEventQueue();
    expect(c.read(todaySceneProvider).key, 'clear-night');
    expect(c.read(weatherProvider).entry!.region, '48.9,2.3');

    // Turning Weather off while a request is out: its answer is dropped too.
    w.clock.advance(const Duration(minutes: 31));
    final late = controller(c).refresh();
    c.read(weatherPrefsProvider.notifier).setBackground(TodayBackground.scenic);
    w.held.last.done.complete(w.conditions('storm'));
    await late;
    expect(c.read(weatherProvider).entry!.conditions.family, 'clear');
    expect(c.read(todaySceneProvider), SceneSpec.dusk); // Scenic now: no weather, and nothing to explain
  });

  test('Automatic never prompts by itself, and every refusal leaves a usable Today', () async {
    final (c, w) = await start(prefs: const WeatherPrefs(background: TodayBackground.weather));
    await controller(c).refresh();
    expect((w.requests, w.locates, w.currentCalls.length), (0, 0, 0));
    expect(c.read(weatherProvider).issue, WeatherIssue.needsPermission);
    expect(c.read(todaySceneProvider).fallback, WeatherFallback.noAnswer);

    w.onRequest = LocatorPermission.denied;
    await controller(c).allowLocation(); // the person chose Automatic and read why
    expect((w.requests, c.read(weatherProvider).issue), (1, WeatherIssue.denied));

    w.onRequest = LocatorPermission.deniedForever;
    await controller(c).allowLocation();
    expect(c.read(weatherProvider).issue, WeatherIssue.deniedForever);
    await controller(c).refresh(force: true);
    expect((w.requests, c.read(weatherProvider).issue), (2, WeatherIssue.deniedForever));

    w.permission = LocatorPermission.granted;
    w.services = false;
    await controller(c).refresh(force: true);
    expect(c.read(weatherProvider).issue, WeatherIssue.servicesOff);

    w.services = true;
    w.fix = null; // no reading in time
    await controller(c).refresh(force: true);
    expect(c.read(weatherProvider).issue, WeatherIssue.timeout);
    expect(c.read(todaySceneProvider).fallback, WeatherFallback.noAnswer);

    w.fix = (lat: 45.5, lon: -73.6);
    w.answer = (_, _) => w.conditions('cloudy', isDay: null);
    await controller(c).refresh(force: true);
    expect((c.read(weatherProvider).issue, c.read(todaySceneProvider).key), (null, 'cloudy-neutral'));
    expect(w.currentCalls.single, '45.5,-73.6');
    expect(c.read(todayBackgroundSummaryProvider), 'Weather · Automatic');

    // The same conditions do not follow the person to a selected city.
    c.read(weatherPrefsProvider.notifier).selectCity(parisTx);
    expect(c.read(todaySceneProvider).fallback, WeatherFallback.noAnswer);
  });

  test('Automatic asks again when the phone has moved to another area, before the answer is old, without a prompt', () async {
    final w = WeatherFakes(now: now)..permission = LocatorPermission.granted;
    final (c, _) = await start(prefs: const WeatherPrefs(background: TodayBackground.weather), fakes: w);
    w.answer = (_, _) => w.conditions('clear');
    await controller(c).refresh();
    expect(w.currentCalls, ['46.8,-71.2']);

    w.last = (lat: 46.8, lon: -71.2); // still here: a recent answer is kept
    await controller(c).refresh();
    expect(w.currentCalls, hasLength(1));

    w.last = (lat: 45.5, lon: -73.6); // the phone now knows it is ~250 km away
    w.fix = (lat: 45.5, lon: -73.6);
    w.answer = (_, _) => w.conditions('rain', isDay: true);
    await controller(c).refresh();
    expect(w.currentCalls, ['46.8,-71.2', '45.5,-73.6']);
    expect(c.read(todaySceneProvider).key, 'rain-day');
    expect(w.requests, 0, reason: 'never a prompt for this check');

    w.permission = LocatorPermission.denied; // without permission nothing is read at all
    w.last = (lat: 48.9, lon: 2.3);
    await controller(c).refresh();
    expect(w.currentCalls, hasLength(2));
  });

  test('weather never reports into the connection state and never writes outside its own two device keys', () async {
    final w = WeatherFakes(now: now);
    final (c, _) = await start(prefs: cityPrefs, fakes: w);
    w.failWith = offline;
    await controller(c).refresh();
    expect(c.read(connectionProvider), isNull);
    w.failWith = null;
    w.clock.advance(const Duration(minutes: 6));
    await controller(c).refresh();
    expect(c.read(connectionProvider), isNull);
    expect(w.secrets.values.keys, unorderedEquals(['gohard.rebuild.today-background', 'gohard.rebuild.weather-cache']));
    expect(SessionManager(w.secrets).current, isNull);
  });
}
