import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/weather/scene_art.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';

import 'weather_fakes.dart';

/// The pure scene resolver and the small weather contract on the phone. No I/O.
void main() {
  final now = DateTime.utc(2026, 10, 14, 3, 20);
  const city = WeatherPrefs(background: TodayBackground.weather, mode: WeatherLocationMode.city, city: quebec);
  const auto = WeatherPrefs(background: TodayBackground.weather);

  WeatherEntry entry(String family, {bool? isDay = true, Duration age = const Duration(minutes: 10), String source = 'city:6325494', String region = '46.8,-71.2', int? code}) =>
      WeatherEntry(source: source, region: region, fetchedAtUtc: now,
          conditions: WeatherConditions(family: family, code: code, isDay: isDay, validAtUtc: now.subtract(age), description: '$family words'));

  SceneSpec scene(WeatherEntry? e, {WeatherPrefs prefs = city, Set<String>? available}) => resolveScene(prefs: prefs, entry: e, nowUtc: now, available: available);

  test('every family picks its own day, night and neutral scene, with the provider wording as the label', () {
    for (final family in weatherFamilies) {
      for (final (isDay, light) in [(true, 'day'), (false, 'night'), (null, 'neutral')]) {
        final s = scene(entry(family, isDay: isDay));
        expect(s.key, '$family-$light');
        expect((s.isWeather, s.label, s.family, s.isDay), (true, '$family words', family, isDay));
        expect(sceneArt.containsKey(s.key), isTrue, reason: 'every scene the resolver returns has artwork');
      }
    }
    expect(sceneKeys.every(sceneArt.containsKey), isTrue);
  });

  test('anything unknown, stale, ahead of time, for another place or without artwork is the dusk scene with no label, and says why', () {
    for (final (e, why) in [
      (null, WeatherFallback.noAnswer),
      (entry('unknown'), WeatherFallback.unknownCode),
      (entry('clear', age: const Duration(minutes: 61)), WeatherFallback.stale), // beyond the maximum age
      (entry('clear', age: const Duration(minutes: -30)), WeatherFallback.ahead), // "valid" half an hour from now
      (entry('clear', region: '48.9,2.3'), WeatherFallback.otherPlace), // another region than the chosen city
      (entry('clear', source: 'auto'), WeatherFallback.noAnswer), // conditions for this phone's location, not the city
    ]) {
      final s = scene(e);
      expect((s.key, s.isWeather, s.label, s.fallback), ('dusk', false, null, why));
    }
    expect(scene(entry('rain'), available: {'dusk'}).fallback, WeatherFallback.noArt);
    expect(scene(entry('clear', age: const Duration(minutes: 60))).key, 'clear-day'); // exactly at the limit is still fresh
    expect(scene(entry('snow', source: 'auto', region: '45.5,-73.6'), prefs: auto).key, 'snow-day');
  });

  // The diagnosed cause of "wrong weather": the server's family "cloudy" covers WMO 2 (partly cloudy) and 3
  // (overcast), and the scene used to be chosen by family alone, so a sunny partly cloudy sky was painted overcast.
  test('the scene follows the WMO code: mainly clear and partly cloudy are not overcast', () {
    for (final (family, code, expected) in [
      ('clear', 0, 'clear'), ('clear', 1, 'partly'), ('cloudy', 2, 'partly'), ('cloudy', 3, 'cloudy'),
      ('fog', 45, 'fog'), ('rain', 61, 'rain'), ('rain', 80, 'rain'), ('snow', 73, 'snow'), ('storm', 95, 'storm'),
      ('cloudy', null, 'cloudy'), // no code: the family decides
    ]) {
      final s = scene(entry(family, code: code));
      expect((s.key, s.family, s.isWeather), ('$expected-day', expected, true), reason: '$family / WMO $code');
    }
  });

  test('a dark sky follows the place\'s day and night and the weather, never the app\'s Light or Dark mode', () {
    String key(SceneSpec s) => '${s.key}:${s.dark}';
    expect([for (final f in weatherFamilies) key(scene(entry(f)))],
        ['clear-day:false', 'partly-day:false', 'cloudy-day:false', 'fog-day:false', 'rain-day:true', 'snow-day:false', 'storm-day:true']);
    expect([for (final f in weatherFamilies) scene(entry(f, isDay: false)).dark], everyElement(isTrue));
    expect(SceneSpec.dusk.dark, isFalse, reason: 'Scenic follows the app\'s mode');
    expect(SceneSpec.plain.dark, isFalse);
  });

  test('scenic and plain never depend on weather', () {
    for (final e in [null, entry('storm')]) {
      expect(scene(e, prefs: city.copyWith(background: TodayBackground.scenic)), SceneSpec.dusk);
      expect(scene(e, prefs: city.copyWith(background: TodayBackground.plain)), SceneSpec.plain);
    }
  });

  test('a distant city at night is night, whatever the phone clock says', () {
    // 03:20 UTC is mid-afternoon in Sydney but night in Paris; only the provider's is_day for the place counts.
    final paris = WeatherPrefs(background: TodayBackground.weather, mode: WeatherLocationMode.city, city: parisFr);
    final e = WeatherEntry(source: 'city:2988507', region: parisFr.region, fetchedAtUtc: now,
        conditions: WeatherConditions(family: 'clear', isDay: false, validAtUtc: now.subtract(const Duration(minutes: 5))));
    for (final at in [now, now.add(const Duration(minutes: 40))]) {
      expect(resolveScene(prefs: paris, entry: e, nowUtc: at).key, 'clear-night');
    }
    final noon = WeatherEntry(source: e.source, region: e.region, fetchedAtUtc: now,
        conditions: WeatherConditions(family: 'clear', isDay: true, validAtUtc: now.subtract(const Duration(minutes: 5))));
    expect(resolveScene(prefs: paris, entry: noon, nowUtc: now).key, 'clear-day'); // and day is day, at any phone hour
  });

  test('the wire contract: unknown family, missing or odd day/night, and only unambiguous UTC instants', () {
    final ok = WeatherConditions.fromJson({'family': 'rain', 'code': 61, 'description': 'Slight rain', 'isDay': false, 'validAtUtc': '2026-10-14T03:15:00Z'})!;
    expect((ok.family, ok.code, ok.isDay, ok.validAtUtc), ('rain', 61, false, DateTime.utc(2026, 10, 14, 3, 15)));
    expect(WeatherConditions.fromJson({'family': 'hail', 'validAtUtc': '2026-10-14T03:15:00Z'})!.family, 'unknown');
    expect(WeatherConditions.fromJson({'family': 'clear', 'isDay': 1, 'validAtUtc': '2026-10-14T03:15:00Z'})!.isDay, isNull);
    expect(WeatherConditions.fromJson({'family': 'clear', 'validAtUtc': '2026-10-13T23:15'}), isNull); // local time without an offset
    expect(WeatherConditions.fromJson({'family': 'clear', 'validAtUtc': 'soon'}), isNull);
    expect(WeatherConditions.fromJson('clear'), isNull);
    final back = WeatherEntry.fromJson(entry('fog', isDay: null).toJson())!;
    expect((back.conditions.family, back.conditions.isDay, back.region), ('fog', null, '46.8,-71.2'));
  });

  test('coordinates are reduced to the 0.1 degree grid and preferences survive a round trip', () {
    expect(regionKey(46.81234, -71.21567), '46.8,-71.2');
    expect(regionKey(-0.04, 0.04), '0.0,0.0');
    expect(WeatherPlace.fromJson({'id': '1', 'name': 'X', 'latitude': 48.85341, 'longitude': 2.3488}).region, '48.9,2.3');
    expect(WeatherPrefs.fromJson(city.toJson()), city);
    expect(WeatherPrefs.fromJson({'background': 'sepia'}), const WeatherPrefs()); // unreadable -> Scenic
    expect(parisFr.fullLabel, 'Paris, Île-de-France Region, France');
    expect(parisTx.fullLabel, 'Paris, Texas, United States');
  });

  test('freshness policy: ask again after 15 minutes, show for 60, and a new fetch never makes old conditions fresh', () {
    final e = entry('clear', age: const Duration(minutes: 70));
    expect(WeatherPolicy.needsRefresh(e, 'city:6325494', now), isFalse); // fetched just now
    expect(WeatherPolicy.usable(e.conditions, now), isFalse); // ...but the conditions themselves are old
    expect(WeatherPolicy.needsRefresh(e, 'city:6325494', now.add(const Duration(minutes: 14))), isFalse);
    expect(WeatherPolicy.needsRefresh(e, 'city:6325494', now.add(const Duration(minutes: 15))), isTrue);
    expect(WeatherPolicy.needsRefresh(e, 'auto', now), isTrue);
    expect(WeatherPolicy.needsRefresh(null, 'auto', now), isTrue);
  });

  test('the grades are real colour matrices', () {
    for (final art in sceneArt.values) {
      if (art.matrix != null) expect(art.matrix!.length, 20);
    }
    expect(grade(), [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]); // neutral grade is the identity
    expect(sceneArt['plain']!.asset, isNull);
    expect(sceneArt['dusk']!.sky, isNull); // the photograph's own sky
    for (final k in sceneKeys.where((k) => k != 'dusk' && k != 'plain')) {
      expect(sceneArt[k]!.sky, isNotNull, reason: '$k paints its own sky');
    }
  });
}
