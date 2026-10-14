import 'package:flutter/foundation.dart';

import '../../data/models.dart';

/// Today background preference: a DEVICE setting, never part of the account, profile.update or the sync outbox.
enum TodayBackground {
  scenic('Scenic'),
  weather('Weather'),
  plain('Plain');

  const TodayBackground(this.label);
  final String label;
}

enum WeatherLocationMode { automatic, city }

/// Everything weather uses is reduced to a 0.1° grid (about 10 km) on the phone too, so no finer place is ever
/// sent, stored or compared. The server rounds again.
double roundCoord(double v) => (v * 10).roundToDouble() / 10 + 0.0;

/// "46.8,-71.2". Two places share a region exactly when they share this key.
String regionKey(double lat, double lon) => '${roundCoord(lat).toStringAsFixed(1)},${roundCoord(lon).toStringAsFixed(1)}';

/// A city the user explicitly chose from the search results. [id] is the provider's identity: a name is not one.
@immutable
class WeatherPlace {
  const WeatherPlace({required this.id, required this.name, this.admin1, this.country, required this.lat, required this.lon});
  final String id, name;
  final String? admin1, country;
  final double lat, lon;

  factory WeatherPlace.fromJson(Json j) => WeatherPlace(
      id: j['id'].toString(), name: j['name'] as String, admin1: j['admin1'] as String?, country: j['country'] as String?,
      lat: roundCoord(((j['latitude'] ?? j['lat']) as num).toDouble()), lon: roundCoord(((j['longitude'] ?? j['lon']) as num).toDouble()));

  Json toJson() => {'id': id, 'name': name, 'admin1': admin1, 'country': country, 'lat': lat, 'lon': lon};

  /// "Paris, Île-de-France Region, France": enough to tell namesakes apart.
  String get fullLabel => [name, if (admin1 != null && admin1 != name) admin1!, ?country].join(', ');
  String get region => regionKey(lat, lon);

  @override
  bool operator ==(Object other) => other is WeatherPlace && other.id == id && other.lat == lat && other.lon == lon;
  @override
  int get hashCode => Object.hash(id, lat, lon);
}

@immutable
class WeatherPrefs {
  const WeatherPrefs({this.background = TodayBackground.scenic, this.mode = WeatherLocationMode.automatic, this.city});
  final TodayBackground background;
  final WeatherLocationMode mode;
  final WeatherPlace? city;

  WeatherPrefs copyWith({TodayBackground? background, WeatherLocationMode? mode, WeatherPlace? city}) =>
      WeatherPrefs(background: background ?? this.background, mode: mode ?? this.mode, city: city ?? this.city);

  /// Which conditions may be shown: `city:<id>` or `auto`. Cached conditions from another source are not used.
  String get source => mode == WeatherLocationMode.city ? 'city:${city?.id}' : 'auto';

  Json toJson() => {'background': background.name, 'mode': mode.name, 'city': city?.toJson()};
  static WeatherPrefs fromJson(Json j) => WeatherPrefs(
      background: TodayBackground.values.asNameMap()[j['background']] ?? TodayBackground.scenic,
      mode: WeatherLocationMode.values.asNameMap()[j['mode']] ?? WeatherLocationMode.automatic,
      city: j['city'] is Map ? WeatherPlace.fromJson((j['city'] as Map).cast<String, Object?>()) : null);

  @override
  bool operator ==(Object other) => other is WeatherPrefs && other.background == background && other.mode == mode && other.city == city;
  @override
  int get hashCode => Object.hash(background, mode, city);
}

const weatherFamilies = ['clear', 'cloudy', 'fog', 'rain', 'snow', 'storm'];

/// Current conditions as the API normalized them (the server's small contract).
@immutable
class WeatherConditions {
  const WeatherConditions({required this.family, this.code, this.description, this.isDay, required this.validAtUtc, this.temperatureC, this.timezone});
  final String family;
  final int? code;
  final String? description;
  final bool? isDay;
  final DateTime validAtUtc;
  final double? temperatureC;
  final String? timezone;

  /// Null when the answer is not usable at all. An unrecognised family is kept as unknown, never guessed.
  static WeatherConditions? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse(raw['validAtUtc']?.toString() ?? '');
    if (at == null || !at.isUtc) return null; // only an unambiguous instant is accepted
    final family = raw['family'];
    return WeatherConditions(
        family: weatherFamilies.contains(family) ? family as String : 'unknown',
        code: (raw['code'] as num?)?.toInt(), description: raw['description'] as String?,
        isDay: raw['isDay'] is bool ? raw['isDay'] as bool : null, validAtUtc: at,
        temperatureC: (raw['temperatureC'] as num?)?.toDouble(), timezone: raw['timezone'] as String?);
  }

  Json toJson() => {'family': family, 'code': code, 'description': description, 'isDay': isDay, 'validAtUtc': validAtUtc.toIso8601String(),
        'temperatureC': temperatureC, 'timezone': timezone};
}

/// What the phone keeps between launches: the last conditions, which source and region they were for, and when the
/// phone fetched them. The fetch time only decides when to ask again; it never makes conditions fresh.
@immutable
class WeatherEntry {
  const WeatherEntry({required this.source, required this.region, required this.conditions, required this.fetchedAtUtc});
  final String source, region;
  final WeatherConditions conditions;
  final DateTime fetchedAtUtc;

  Json toJson() => {'source': source, 'region': region, 'conditions': conditions.toJson(), 'fetchedAtUtc': fetchedAtUtc.toIso8601String()};
  static WeatherEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final c = WeatherConditions.fromJson(raw['conditions']);
    final at = DateTime.tryParse(raw['fetchedAtUtc']?.toString() ?? '');
    if (c == null || at == null || raw['source'] is! String || raw['region'] is! String) return null;
    return WeatherEntry(source: raw['source'] as String, region: raw['region'] as String, conditions: c, fetchedAtUtc: at.toUtc());
  }
}

/// The product policy, in one place.
abstract final class WeatherPolicy {
  /// Ask again when Today opens or resumes and the last fetch for this source is older than this.
  static const refreshAfter = Duration(minutes: 30);

  /// Conditions are shown only while their valid time is within this age.
  static const maxAge = Duration(minutes: 60);

  /// Model data a little ahead of the phone's clock is normal; further ahead is not "current".
  static const futureTolerance = Duration(minutes: 20);

  static bool usable(WeatherConditions c, DateTime nowUtc) {
    final age = nowUtc.difference(c.validAtUtc);
    return age <= maxAge && age >= -futureTolerance;
  }

  static bool needsRefresh(WeatherEntry? e, String source, DateTime nowUtc) =>
      e == null || e.source != source || nowUtc.difference(e.fetchedAtUtc) >= refreshAfter || nowUtc.isBefore(e.fetchedAtUtc);
}

/// What the backdrop paints. [key] names the treatment; the crossfade runs only when it changes.
@immutable
class SceneSpec {
  const SceneSpec({required this.key, this.isWeather = false, this.label, this.family, this.isDay});
  final String key;
  final bool isWeather;

  /// The provider's own description, shown only for a real, fresh weather scene.
  final String? label;
  final String? family;
  final bool? isDay;

  static const dusk = SceneSpec(key: 'dusk');
  static const plain = SceneSpec(key: 'plain');

  @override
  bool operator ==(Object other) => other is SceneSpec && other.key == key && other.label == label;
  @override
  int get hashCode => Object.hash(key, label);
  @override
  String toString() => 'SceneSpec($key${label == null ? '' : ', $label'})';
}

/// Treatment keys that exist: every family in day, night and neutral (provider did not say) light.
final Set<String> sceneKeys = {
  'dusk', 'plain',
  for (final f in weatherFamilies) ...['$f-day', '$f-night', '$f-neutral'],
};

/// Pure scene choice: no I/O, no phone clock other than [nowUtc]. Day or night comes only from the provider's
/// is_day for that place, so a distant city's night is night whatever this phone's time. Anything unknown, stale,
/// for another place/source, or without artwork is the decorative dusk scene with no weather label.
SceneSpec resolveScene({required WeatherPrefs prefs, required WeatherEntry? entry, required DateTime nowUtc, Set<String>? available}) {
  switch (prefs.background) {
    case TodayBackground.plain:
      return SceneSpec.plain;
    case TodayBackground.scenic:
      return SceneSpec.dusk;
    case TodayBackground.weather:
      final c = entry?.conditions;
      if (entry == null || c == null || entry.source != prefs.source) return SceneSpec.dusk;
      if (prefs.mode == WeatherLocationMode.city && entry.region != prefs.city?.region) return SceneSpec.dusk;
      if (!WeatherPolicy.usable(c, nowUtc) || !weatherFamilies.contains(c.family)) return SceneSpec.dusk;
      final key = '${c.family}-${switch (c.isDay) { true => 'day', false => 'night', null => 'neutral' }}';
      if (!(available ?? sceneKeys).contains(key)) return SceneSpec.dusk;
      return SceneSpec(key: key, isWeather: true, label: c.description ?? _familyLabel[c.family], family: c.family, isDay: c.isDay);
  }
}

const _familyLabel = {'clear': 'Clear', 'cloudy': 'Cloudy', 'fog': 'Fog', 'rain': 'Rain', 'snow': 'Snow', 'storm': 'Thunderstorm'};
