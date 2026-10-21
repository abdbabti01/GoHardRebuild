import 'package:flutter/foundation.dart';

import '../../core/language.dart';
import '../../data/models.dart';

/// Today background preference: a DEVICE setting, never part of the account, profile.update or the sync outbox.
enum TodayBackground { scenic, weather, plain }

/// "Scenic", "Weather", "Plain" in the current language; [TodayBackground.name] is what is stored.
String todayBackgroundLabel(AppLocalizations l, TodayBackground b) => switch (b) {
      TodayBackground.scenic => l.weatherBackgroundScenic,
      TodayBackground.weather => l.weatherBackgroundWeather,
      TodayBackground.plain => l.weatherBackgroundPlain,
    };

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
  const WeatherPrefs({this.background = TodayBackground.scenic, this.mode = WeatherLocationMode.automatic, this.city, this.fahrenheit = false});
  final TodayBackground background;
  final WeatherLocationMode mode;
  final WeatherPlace? city;

  /// Today's temperature in °F instead of °C. A display choice on this phone, like the rest of these.
  final bool fahrenheit;

  WeatherPrefs copyWith({TodayBackground? background, WeatherLocationMode? mode, WeatherPlace? city, bool? fahrenheit}) =>
      WeatherPrefs(background: background ?? this.background, mode: mode ?? this.mode, city: city ?? this.city, fahrenheit: fahrenheit ?? this.fahrenheit);

  /// Which conditions may be shown: `city:<id>` or `auto`. Cached conditions from another source are not used.
  String get source => mode == WeatherLocationMode.city ? 'city:${city?.id}' : 'auto';

  Json toJson() => {'background': background.name, 'mode': mode.name, 'city': city?.toJson(), 'fahrenheit': fahrenheit};
  static WeatherPrefs fromJson(Json j) => WeatherPrefs(
      background: TodayBackground.values.asNameMap()[j['background']] ?? TodayBackground.scenic,
      mode: WeatherLocationMode.values.asNameMap()[j['mode']] ?? WeatherLocationMode.automatic,
      city: j['city'] is Map ? WeatherPlace.fromJson((j['city'] as Map).cast<String, Object?>()) : null,
      fahrenheit: j['fahrenheit'] == true);

  @override
  bool operator ==(Object other) => other is WeatherPrefs && other.background == background && other.mode == mode && other.city == city && other.fahrenheit == fahrenheit;
  @override
  int get hashCode => Object.hash(background, mode, city, fahrenheit);
}

/// Scene families. The server's contract has six (clear, cloudy, fog, rain, snow, storm); the phone splits "cloudy"
/// by the WMO code it carries: 1–2 (mainly clear, partly cloudy) are [partly], 3 (overcast) stays cloudy. Before this
/// split a sunny, partly cloudy afternoon was painted as an overcast sky.
const weatherFamilies = ['clear', 'partly', 'cloudy', 'fog', 'rain', 'snow', 'storm'];

/// The scene family for conditions: from the WMO code where it decides more finely than the server's family.
String sceneFamily(WeatherConditions c) => switch (c.code) {
      0 => 'clear',
      1 || 2 => 'partly',
      3 => 'cloudy',
      _ => c.family,
    };

/// Current conditions as the API normalized them (the server's small contract).
@immutable
class WeatherConditions {
  const WeatherConditions({required this.family, this.code, this.description, this.isDay, required this.validAtUtc, this.temperatureC, this.timezone, this.source});
  final String family;
  final int? code;
  final String? description;
  final bool? isDay;
  final DateTime validAtUtc;
  final double? temperatureC;
  final String? timezone;

  /// Which provider answered: "open-meteo", or "met.no" when the server fell back to MET Norway.
  final String? source;

  /// The credit the answering provider asks for.
  /// MET Norway's terms: credit, a link to the licence, and whether the data was changed (symbols are mapped to codes).
  String credit(AppLocalizations l) => source == 'met.no' ? l.weatherCreditMet : l.weatherCreditOpenMeteo;

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
        temperatureC: (raw['temperatureC'] as num?)?.toDouble(), timezone: raw['timezone'] as String?, source: raw['source'] as String?);
  }

  Json toJson() => {'family': family, 'code': code, 'description': description, 'isDay': isDay, 'validAtUtc': validAtUtc.toIso8601String(),
        'temperatureC': temperatureC, 'timezone': timezone, 'source': source};
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
  static const refreshAfter = Duration(minutes: 15);

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
  const SceneSpec({required this.key, this.isWeather = false, this.label, this.code, this.family, this.isDay, this.fallback, this.temperatureC});
  final String key;
  final bool isWeather;

  /// Why Weather mode is showing the decorative scene instead of weather; null for a weather scene, Scenic and Plain.
  final WeatherFallback? fallback;

  /// The provider's own description, shown only for a real, fresh weather scene (in English; [sceneLabel] translates).
  final String? label;

  /// The WMO code of the same answer, which [sceneLabel] names in other languages.
  final int? code;
  final String? family;
  final bool? isDay;

  /// The temperature from the same fresh answer as [label], in °C as the API gives it; null when it did not say.
  final double? temperatureC;

  /// A dark sky (night, storm, rain; with no day or night given, overcast, rain, storm and fog): the header text over
  /// it is drawn light. Dusk and Plain are not weather and never dark.
  bool get dark => isWeather &&
      (isDay == false || const {'storm', 'rain'}.contains(family) || (isDay == null && const {'cloudy', 'fog'}.contains(family)));

  static const dusk = SceneSpec(key: 'dusk');
  static const plain = SceneSpec(key: 'plain');

  @override
  bool operator ==(Object other) => other is SceneSpec && other.key == key && other.label == label && other.code == code && other.fallback == fallback && other.temperatureC == temperatureC;
  @override
  int get hashCode => Object.hash(key, label, code, fallback, temperatureC);
  @override
  String toString() => 'SceneSpec($key${label == null ? '' : ', $label'}${fallback == null ? '' : ', fallback: ${fallback!.name}'})';
}

/// Why Weather mode fell back to the decorative scene. Shown in words on Today and in the setting.
enum WeatherFallback { noAnswer, otherPlace, stale, ahead, unknownCode, noArt }

String weatherFallbackText(AppLocalizations l, WeatherFallback f) => switch (f) {
      WeatherFallback.noAnswer => l.weatherFallbackNoAnswer,
      WeatherFallback.otherPlace => l.weatherFallbackOtherPlace,
      WeatherFallback.stale => l.weatherFallbackStale,
      WeatherFallback.ahead => l.weatherFallbackAhead,
      WeatherFallback.unknownCode => l.weatherFallbackUnknownCode,
      WeatherFallback.noArt => l.weatherFallbackNoArt,
    };

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
      SceneSpec fall(WeatherFallback why) => SceneSpec(key: 'dusk', fallback: why);
      final c = entry?.conditions;
      if (entry == null || c == null || entry.source != prefs.source) return fall(WeatherFallback.noAnswer);
      if (prefs.mode == WeatherLocationMode.city && entry.region != prefs.city?.region) return fall(WeatherFallback.otherPlace);
      final age = nowUtc.difference(c.validAtUtc);
      if (age > WeatherPolicy.maxAge) return fall(WeatherFallback.stale);
      if (age < -WeatherPolicy.futureTolerance) return fall(WeatherFallback.ahead);
      final family = sceneFamily(c);
      if (!weatherFamilies.contains(family)) return fall(WeatherFallback.unknownCode);
      final key = '$family-${switch (c.isDay) { true => 'day', false => 'night', null => 'neutral' }}';
      if (!(available ?? sceneKeys).contains(key)) return fall(WeatherFallback.noArt);
      return SceneSpec(key: key, isWeather: true, label: c.description ?? _familyLabel[family], code: c.code, family: family, isDay: c.isDay, temperatureC: c.temperatureC);
  }
}

const _familyLabel = {'clear': 'Clear', 'partly': 'Partly cloudy', 'cloudy': 'Overcast', 'fog': 'Fog', 'rain': 'Rain', 'snow': 'Snow', 'storm': 'Thunderstorm'};

/// "8°C", "-3°F", "0°C" ("8 °C" in French): the API's °C converted once and rounded to whole degrees (a rounded -0.4
/// is "0", never "-0").
String formatTemperature(double celsius, {required bool fahrenheit}) {
  final degrees = (fahrenheit ? celsius * 9 / 5 + 32 : celsius).round();
  return fahrenheit ? currentL10n.weatherTemperatureF(degrees) : currentL10n.weatherTemperatureC(degrees);
}

/// WMO codes the provider documents (OpenMeteoProvider.cs); each has its own wording in [AppLocalizations.weatherCondition].
const _wmoCodes = {0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 97, 99};

/// A weather scene's condition in the current language, from the cached answer alone (a language change fetches
/// nothing). English keeps the provider's own description; French and Arabic name the WMO code, else the family.
String sceneLabel(AppLocalizations l, SceneSpec s) {
  if (l.localeName == 'en' && s.label != null) return s.label!;
  if (_wmoCodes.contains(s.code)) return l.weatherCondition('c${s.code}');
  return l.weatherFamily(s.family ?? 'unknown');
}
