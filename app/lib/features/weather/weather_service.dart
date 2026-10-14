import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:geolocator/geolocator.dart';

import '../../app/providers.dart' show apiProvider, clockProvider;
import '../../data/models.dart';
import '../../data/session.dart';
import '../nutrition/food_discovery.dart' show LookupFailure, LookupProblem;
import 'weather_model.dart';

// ---------------------------------------------------------------------------- device store

/// The Today background preference and the last weather answer, in the same platform store as the appearance.
/// Read before the first frame, so Today never opens on one background and then switches.
class WeatherStore {
  WeatherStore(this._store);
  static const _prefsKey = 'gohard.rebuild.today-background', _cacheKey = 'gohard.rebuild.weather-cache';
  final SecretStore _store;

  WeatherPrefs prefs = const WeatherPrefs();
  WeatherEntry? entry;

  Future<void> restore() async {
    try {
      final raw = await _store.read(_prefsKey);
      // Nothing saved: a fresh install, or an upgrade from before this setting. Both start on Scenic; a saved
      // choice is always read back as it was.
      if (raw != null) prefs = WeatherPrefs.fromJson(jsonDecode(raw) as Json);
    } on Object {
      // An unreadable preference is not worth failing startup for; Scenic applies.
    }
    try {
      final raw = await _store.read(_cacheKey);
      if (raw != null) entry = WeatherEntry.fromJson(jsonDecode(raw));
    } on Object {
      entry = null;
    }
  }

  Future<void> savePrefs() => _store.write(_prefsKey, jsonEncode(prefs.toJson()));
  Future<void> saveEntry() => entry == null ? _store.delete(_cacheKey) : _store.write(_cacheKey, jsonEncode(entry!.toJson()));
}

/// Overridden at startup with the restored store. Left alone (tests), it is an empty in-memory one.
final weatherStoreProvider = Provider<WeatherStore>((_) => WeatherStore(MemorySecretStore()));

/// Call once in main.dart before runApp, like the other device stores, and add the returned override.
Future<Override> restoreWeatherPrefs(SecretStore store) async {
  final s = WeatherStore(store);
  await s.restore();
  return weatherStoreProvider.overrideWithValue(s);
}

class WeatherPrefsController extends Notifier<WeatherPrefs> {
  WeatherStore get _saved => ref.read(weatherStoreProvider);

  @override
  WeatherPrefs build() => ref.watch(weatherStoreProvider).prefs;

  void setBackground(TodayBackground b) => _apply(state.copyWith(background: b));
  void setMode(WeatherLocationMode m) => _apply(state.copyWith(mode: m));
  void selectCity(WeatherPlace city) => _apply(state.copyWith(mode: WeatherLocationMode.city, city: city));

  void _apply(WeatherPrefs next) {
    if (next == state) return;
    _saved.prefs = next;
    state = next;
    _saved.savePrefs().ignore(); // already applied; a failed write only means it is chosen again next launch
  }
}

final weatherPrefsProvider = NotifierProvider<WeatherPrefsController, WeatherPrefs>(WeatherPrefsController.new);

/// "Scenic" | "Weather · Montréal" | "Weather · Automatic" | "Plain", for the Appearance row.
final todayBackgroundSummaryProvider = Provider<String>((ref) {
  final p = ref.watch(weatherPrefsProvider);
  if (p.background != TodayBackground.weather) return p.background.label;
  return switch (p.mode) {
    WeatherLocationMode.automatic => 'Weather · Automatic',
    WeatherLocationMode.city => p.city == null ? 'Weather' : 'Weather · ${p.city!.name}',
  };
});

// ---------------------------------------------------------------------------- boundaries

/// Where conditions and places come from. The app's one implementation goes through the account's server.
abstract interface class WeatherSource {
  Future<WeatherConditions> current(double lat, double lon);
  Future<List<WeatherPlace>> places(String query);
}

class ApiWeatherSource implements WeatherSource {
  ApiWeatherSource(this._api);
  final Api _api;
  static const timeout = Duration(seconds: 10);

  Future<Object?> _get(String path) async {
    final ApiResponse r;
    try {
      r = await _api.send('GET', path).timeout(timeout);
    } on TimeoutException {
      throw const LookupFailure(LookupProblem.timeout);
    } on TransportFailure {
      throw const LookupFailure(LookupProblem.offline);
    }
    if (r.ok) return r.data;
    final code = r.data is Map ? (r.data as Map)['code'] : null;
    throw LookupFailure(switch ((r.status, code)) {
      (422, _) => LookupProblem.invalid,
      (429, _) => LookupProblem.rateLimited,
      (_, 'PROVIDER_NOT_CONFIGURED') || (404, _) => LookupProblem.notConfigured, // a server from before weather
      _ => LookupProblem.unavailable,
    });
  }

  @override
  Future<WeatherConditions> current(double lat, double lon) async =>
      WeatherConditions.fromJson(await _get('/weather/current?lat=${roundCoord(lat)}&lon=${roundCoord(lon)}')) ??
      (throw const LookupFailure(LookupProblem.unavailable));

  @override
  Future<List<WeatherPlace>> places(String query) async {
    final data = await _get('/weather/places?q=${Uri.encodeQueryComponent(query)}');
    return [for (final p in (data is Map ? data['results'] as List? : null) ?? const []) WeatherPlace.fromJson((p as Map).cast<String, Object?>())];
  }
}

final weatherSourceProvider = Provider<WeatherSource>((ref) => ApiWeatherSource(ref.watch(apiProvider)));

enum LocatorPermission { granted, denied, deniedForever }

/// A coarse fix: already reduced to the weather grid.
typedef CoarseFix = ({double lat, double lon});

/// The phone's location, only as much as weather needs: foreground, low accuracy, one reading.
abstract interface class WeatherLocator {
  Future<bool> servicesEnabled();
  Future<LocatorPermission> check();

  /// Shows the system prompt. Only ever called after the person chose Automatic and read why.
  Future<LocatorPermission> request();

  /// One reading, or null when none came in time.
  Future<CoarseFix?> locate();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class GeolocatorWeatherLocator implements WeatherLocator {
  const GeolocatorWeatherLocator();
  static const timeLimit = Duration(seconds: 10);

  static LocatorPermission _map(LocationPermission p) => switch (p) {
        LocationPermission.always || LocationPermission.whileInUse => LocatorPermission.granted,
        LocationPermission.deniedForever => LocatorPermission.deniedForever,
        _ => LocatorPermission.denied,
      };

  @override
  Future<bool> servicesEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocatorPermission> check() async => _map(await Geolocator.checkPermission());
  @override
  Future<LocatorPermission> request() async => _map(await Geolocator.requestPermission());

  @override
  Future<CoarseFix?> locate() async {
    // A recent reading the phone already has is good enough for a 10 km grid and costs nothing.
    final last = await Geolocator.getLastKnownPosition();
    Position? p = last != null && DateTime.now().difference(last.timestamp) < WeatherPolicy.refreshAfter ? last : null;
    try {
      p ??= await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: timeLimit))
          .timeout(timeLimit + const Duration(seconds: 2));
    } on TimeoutException {
      return null;
    }
    return (lat: roundCoord(p.latitude), lon: roundCoord(p.longitude));
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

final weatherLocatorProvider = Provider<WeatherLocator>((_) => const GeolocatorWeatherLocator());

// ---------------------------------------------------------------------------- refresh

/// Why there is no fresh weather scene right now. Quiet text in the settings page only; never a banner, and never
/// connected to the account's sync state.
enum WeatherIssue { needsPermission, denied, deniedForever, servicesOff, timeout, offline, unavailable, noCity }

class WeatherState {
  const WeatherState({this.entry, this.issue, this.busy = false});
  final WeatherEntry? entry;
  final WeatherIssue? issue;
  final bool busy;
}

/// Fetches and keeps current conditions for the chosen source. Only ever asked: on Today appearing or the app
/// resuming (refresh-if-stale) and on a settings change. No timers, no polling, nothing while Weather is off.
/// Every change of preference supersedes the request in flight: its late answer is dropped.
class WeatherController extends Notifier<WeatherState> {
  int _token = 0;
  Future<void>? _inFlight;

  /// When the last attempt started. After a failed one, Today appearing again does not ask again for [retryAfter].
  DateTime? _attemptAt;
  static const retryAfter = Duration(minutes: 5);

  WeatherStore get _store => ref.read(weatherStoreProvider);

  @override
  WeatherState build() {
    ref.listen(weatherPrefsProvider, (before, after) {
      _token++; // anything still in flight belongs to the old choice
      _inFlight = null;
      _attemptAt = null;
      state = WeatherState(entry: state.entry);
      if (after.background == TodayBackground.weather) refresh(force: before?.source != after.source).ignore();
    });
    return WeatherState(entry: ref.watch(weatherStoreProvider).entry);
  }

  /// Asks for current conditions when Weather is on and the last answer for this source is old enough.
  /// Never prompts for permission. Joins a request already in flight for the same choice.
  Future<void> refresh({bool force = false}) {
    final prefs = ref.read(weatherPrefsProvider);
    if (prefs.background != TodayBackground.weather) return Future.value();
    final now = ref.read(clockProvider).utcNow();
    if (!force && !WeatherPolicy.needsRefresh(state.entry, prefs.source, now)) return Future.value();
    if (!force && _attemptAt != null && now.difference(_attemptAt!) < retryAfter && _inFlight == null) return Future.value();
    return _inFlight ??= () {
      _attemptAt = now;
      return _run(prefs, _token).whenComplete(() => _inFlight = null);
    }();
  }

  /// The person chose Automatic and read why: ask the system once, then fetch.
  Future<void> allowLocation() async {
    final token = _token;
    final permission = await ref.read(weatherLocatorProvider).request();
    if (token != _token) return;
    if (permission != LocatorPermission.granted) {
      state = WeatherState(entry: state.entry, issue: permission == LocatorPermission.deniedForever ? WeatherIssue.deniedForever : WeatherIssue.denied);
      return;
    }
    _token++;
    _inFlight = null;
    _attemptAt = null;
    await refresh(force: true);
  }

  Future<void> _run(WeatherPrefs prefs, int token) async {
    bool current() => token == _token && ref.mounted;
    void fail(WeatherIssue issue) {
      if (current()) state = WeatherState(entry: state.entry, issue: issue);
    }

    state = WeatherState(entry: state.entry, busy: true);
    try {
      final CoarseFix fix;
      if (prefs.mode == WeatherLocationMode.city) {
        final city = prefs.city;
        if (city == null) return fail(WeatherIssue.noCity);
        fix = (lat: city.lat, lon: city.lon);
      } else {
        final locator = ref.read(weatherLocatorProvider);
        if (!await locator.servicesEnabled()) return fail(WeatherIssue.servicesOff);
        final permission = await locator.check();
        if (!current()) return;
        if (permission == LocatorPermission.deniedForever) return fail(WeatherIssue.deniedForever);
        if (permission != LocatorPermission.granted) return fail(WeatherIssue.needsPermission);
        final found = await locator.locate();
        if (found == null) return fail(WeatherIssue.timeout);
        fix = found;
      }
      if (!current()) return;
      final conditions = await ref.read(weatherSourceProvider).current(fix.lat, fix.lon);
      if (!current()) return; // a late answer for a previous city or choice is dropped
      final entry = WeatherEntry(source: prefs.source, region: regionKey(fix.lat, fix.lon), conditions: conditions, fetchedAtUtc: ref.read(clockProvider).utcNow());
      _store.entry = entry;
      _store.saveEntry().ignore();
      state = WeatherState(entry: entry);
    } on LookupFailure catch (e) {
      // Healthy, still-fresh data stays usable: the entry is kept as it was.
      fail(switch (e.problem) { LookupProblem.offline => WeatherIssue.offline, LookupProblem.timeout => WeatherIssue.timeout, _ => WeatherIssue.unavailable });
    } on Object {
      fail(WeatherIssue.unavailable);
    } finally {
      if (current() && state.busy) state = WeatherState(entry: state.entry, issue: state.issue);
    }
  }
}

final weatherProvider = NotifierProvider<WeatherController, WeatherState>(WeatherController.new);

/// The scene Today should show now. Pure resolution over the preference and the kept conditions, re-evaluated on
/// every weather state change (each refresh attempt on Today appearing or resuming), so age is re-checked then.
// ponytail: age is not re-checked while Today stays on screen with no resume; add a one-shot timer at expiry if needed.
final todaySceneProvider = Provider<SceneSpec>((ref) =>
    resolveScene(prefs: ref.watch(weatherPrefsProvider), entry: ref.watch(weatherProvider).entry, nowUtc: ref.read(clockProvider).utcNow()));
