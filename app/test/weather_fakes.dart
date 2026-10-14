import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/nutrition/food_discovery.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';

import 'support.dart';

/// Test doubles for the two weather boundaries, so any test can drive the Today scene without a phone or a network.
///
///     final w = WeatherFakes(now: DateTime.utc(2026, 10, 14, 3, 20));
///     w.answer = (lat, lon) => w.conditions('rain', isDay: false);
///     ProviderContainer(overrides: [...await w.overrides(prefs: const WeatherPrefs(background: TodayBackground.weather, ...))]);
class WeatherFakes implements WeatherSource, WeatherLocator {
  WeatherFakes({required DateTime now}) : clock = FakeClock(now);
  final FakeClock clock;
  final secrets = MemorySecretStore();

  // ---- source
  final currentCalls = <String>[];
  final placesCalls = <String>[];
  WeatherConditions Function(double lat, double lon)? answer;
  Object? failWith;

  /// When true, every current() waits on a completer in [held] until the test completes it.
  bool hold = false;
  final held = <({String region, Completer<WeatherConditions> done})>[];
  List<WeatherPlace> placesResult = const [];

  WeatherConditions conditions(String family, {bool? isDay = true, Duration age = const Duration(minutes: 5), String? description, int? code}) =>
      WeatherConditions(family: family, isDay: isDay, validAtUtc: clock.now.subtract(age), description: description ?? '$family description', code: code);

  @override
  Future<WeatherConditions> current(double lat, double lon) {
    currentCalls.add(regionKey(lat, lon));
    if (failWith != null) return Future.error(failWith!);
    if (hold) {
      final c = Completer<WeatherConditions>();
      held.add((region: regionKey(lat, lon), done: c));
      return c.future;
    }
    return Future.value((answer ?? (_, _) => conditions('clear'))(lat, lon));
  }

  @override
  Future<List<WeatherPlace>> places(String query) async {
    placesCalls.add(query);
    if (failWith != null) throw failWith!;
    return placesResult;
  }

  // ---- locator
  bool services = true;
  LocatorPermission permission = LocatorPermission.denied;

  /// What the system prompt answers.
  LocatorPermission onRequest = LocatorPermission.granted;
  CoarseFix? fix = (lat: 46.8, lon: -71.2);
  int requests = 0, locates = 0, checks = 0, settingsOpened = 0;

  @override
  Future<bool> servicesEnabled() async => services;
  @override
  Future<LocatorPermission> check() async {
    checks++;
    return permission;
  }

  @override
  Future<LocatorPermission> request() async {
    requests++;
    return permission = onRequest;
  }

  @override
  Future<CoarseFix?> locate() async {
    locates++;
    return fix;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;
  @override
  Future<void> openLocationSettings() async => settingsOpened++;

  /// Overrides for a container or `pumpApp`, with the store restored from [secrets] as main.dart does.
  Future<List<Override>> overrides({WeatherPrefs? prefs}) async {
    if (prefs != null) {
      final s = WeatherStore(secrets)..prefs = prefs;
      await s.savePrefs();
    }
    return [
      await restoreWeatherPrefs(secrets),
      weatherSourceProvider.overrideWithValue(this),
      weatherLocatorProvider.overrideWithValue(this),
      clockProvider.overrideWithValue(clock),
    ];
  }
}

const offline = LookupFailure(LookupProblem.offline);

const quebec = WeatherPlace(id: '6325494', name: 'Québec', admin1: 'Quebec', country: 'Canada', lat: 46.8, lon: -71.2);
const parisFr = WeatherPlace(id: '2988507', name: 'Paris', admin1: 'Île-de-France Region', country: 'France', lat: 48.9, lon: 2.3);
const parisTx = WeatherPlace(id: '4717560', name: 'Paris', admin1: 'Texas', country: 'United States', lat: 33.7, lon: -95.6);
