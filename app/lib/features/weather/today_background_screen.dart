import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../nutrition/food_discovery.dart' show LookupFailure;
import 'backdrop.dart';
import 'weather_model.dart';
import 'weather_service.dart';

/// Me > Appearance > Today background: Scenic / Weather / Plain, the weather location, and what the current scene
/// is based on. Every state is quiet text; nothing here is a banner or blocks the page.
class TodayBackgroundScreen extends ConsumerWidget {
  const TodayBackgroundScreen({super.key});

  static const _subtitles = {
    TodayBackground.scenic: 'A decorative dusk scene. Works without a connection.',
    TodayBackground.weather: 'A scene for the current weather where you choose. Dusk when none is available.',
    TodayBackground.plain: 'The plain page colour.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(weatherPrefsProvider);
    final scene = ref.watch(todaySceneProvider);
    final set = ref.read(weatherPrefsProvider.notifier);
    return AppPage(title: 'Today background', subtitle: 'Only the top of Today uses it. Changes apply immediately.', children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.panel),
        child: SizedBox(height: 120, child: SceneBackdrop(key: const Key('today-background-preview'), spec: scene)),
      ),
      const SizedBox(height: 16),
      for (final b in TodayBackground.values)
        ChoiceTile<TodayBackground>(
            key: Key('today-background-${b.name}'), value: b, groupValue: prefs.background, onChanged: set.setBackground, title: b.label, subtitle: _subtitles[b]),
      if (prefs.background == TodayBackground.weather) ...[
        const SizedBox(height: 14),
        const SectionLabel('Location'),
        const SizedBox(height: 8),
        ChoiceTile<WeatherLocationMode>(
            key: const Key('weather-location-automatic'), value: WeatherLocationMode.automatic, groupValue: prefs.mode,
            onChanged: (_) => chooseAutomatic(context, ref), title: 'Automatic', subtitle: 'This phone\'s approximate location, about 10 km'),
        ChoiceTile<WeatherLocationMode>(
            key: const Key('weather-location-city'), value: WeatherLocationMode.city, groupValue: prefs.mode,
            onChanged: (_) => prefs.city == null ? _searchCity(context, ref) : set.setMode(WeatherLocationMode.city),
            title: 'Selected city', subtitle: prefs.city?.fullLabel ?? 'Search for a city'),
        if (prefs.mode == WeatherLocationMode.city && prefs.city != null)
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(key: const Key('weather-change-city'), onPressed: () => _searchCity(context, ref), child: const Text('Change city'))),
        const _Issue(),
        const SizedBox(height: 14),
        const SectionLabel('Now'),
        const SizedBox(height: 8),
        const _Details(),
      ],
    ]);
  }

  /// Automatic is chosen. If the phone has not given location yet, say why it is wanted before the system asks.
  static Future<void> chooseAutomatic(BuildContext context, WidgetRef ref) async {
    ref.read(weatherPrefsProvider.notifier).setMode(WeatherLocationMode.automatic);
    final locator = ref.read(weatherLocatorProvider);
    if (await locator.check() != LocatorPermission.denied || !context.mounted) return; // granted, or only Settings can change it
    final go = await confirm(context,
        title: 'Use your approximate location?',
        body: 'GoHard uses this phone\'s location only to choose a weather scene for the top of Today. It is rounded to about '
            '10 km before it leaves the phone and is not kept as a history. You can choose a city instead.',
        action: 'Continue',
        cancel: 'Not now');
    if (go) await ref.read(weatherProvider.notifier).allowLocation();
  }

  static Future<void> _searchCity(BuildContext context, WidgetRef ref) async {
    final place = await showGoSheet<WeatherPlace>(context, title: 'Choose a city', builder: (_) => const _CitySearch());
    if (place != null) ref.read(weatherPrefsProvider.notifier).selectCity(place);
  }
}

class _Issue extends ConsumerWidget {
  const _Issue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issue = ref.watch(weatherProvider.select((s) => s.issue));
    final locator = ref.read(weatherLocatorProvider);
    final (text, action, onAction) = switch (issue) {
      null => (null, null, null),
      WeatherIssue.needsPermission => ('Automatic needs permission to use this phone\'s approximate location.', 'Use my location',
          () => TodayBackgroundScreen.chooseAutomatic(context, ref)),
      WeatherIssue.denied => ('Location was not allowed. Choose a city, or try again.', 'Use my location', () => TodayBackgroundScreen.chooseAutomatic(context, ref)),
      WeatherIssue.deniedForever => ('Location is turned off for GoHard. Allow it in Settings, or choose a city.', 'Open Settings', locator.openAppSettings),
      WeatherIssue.servicesOff => ('Location is turned off on this phone. Turn it on, or choose a city.', 'Location settings', locator.openLocationSettings),
      WeatherIssue.timeout => ('This phone did not find its location in time. Dusk shows until it does.', null, null),
      WeatherIssue.noCity => ('Choose a city to see its weather.', null, null),
      WeatherIssue.offline || WeatherIssue.unavailable => ('Weather could not be reached just now. Dusk shows until it can.', null, null),
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StatusLine(Icons.info_outline, text, key: const Key('weather-issue')),
        if (action != null) TextButton(key: const Key('weather-issue-action'), onPressed: () => onAction!(), child: Text(action)),
      ]),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(todaySceneProvider);
    final prefs = ref.watch(weatherPrefsProvider);
    final weather = ref.watch(weatherProvider);
    final c = weather.entry?.conditions;
    final place = prefs.mode == WeatherLocationMode.city ? prefs.city?.fullLabel : 'Your approximate location';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (scene.isWeather && c != null) ...[
        Text(scene.label!, key: const Key('weather-condition'), style: context.sansStyle(16, weight: FontWeight.w600)),
        Text('As of ${TimeOfDay.fromDateTime(c.validAtUtc.toLocal()).format(context)}${place == null ? '' : ' · $place'}',
            key: const Key('weather-as-of'), style: context.caption),
      ] else
        Text(weather.busy ? 'Checking the weather…' : 'No current weather. Showing the decorative dusk scene.', key: const Key('weather-none'), style: context.caption),
      const SizedBox(height: 10),
      Text('Weather data by Open-Meteo.com (CC BY 4.0). Conditions are model data.', style: context.caption),
      Text('Scenes are illustrative: not a forecast or a view of your location.', style: context.caption),
    ]);
  }
}

class _CitySearch extends ConsumerStatefulWidget {
  const _CitySearch();
  @override
  ConsumerState<_CitySearch> createState() => _CitySearchState();
}

class _CitySearchState extends ConsumerState<_CitySearch> {
  final _query = TextEditingController();
  List<WeatherPlace>? _results;
  String? _note;
  int _token = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return setState(() => _note = 'Type at least two letters.');
    final token = ++_token;
    setState(() => _note = 'Searching…');
    try {
      final found = await ref.read(weatherSourceProvider).places(q);
      if (!mounted || token != _token) return; // an older search answering late
      setState(() {
        _results = found;
        _note = found.isEmpty ? 'No places found for "$q".' : null;
      });
    } on LookupFailure {
      if (!mounted || token != _token) return;
      setState(() {
        _results = null;
        _note = 'Cities could not be searched just now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        TextField(
          key: const Key('city-search-field'),
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
              labelText: 'City', suffixIcon: IconButton(key: const Key('city-search-go'), tooltip: 'Search', icon: const Icon(Icons.search), onPressed: _search)),
          onSubmitted: (_) => _search(),
        ),
        if (_note != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_note!, key: const Key('city-search-note'), style: context.caption)),
        if (_results case final results? when results.isNotEmpty) ...[
          const SizedBox(height: 12),
          GroupCard(children: [
            for (final p in results)
              GroupRow(
                  key: Key('city-result-${p.id}'), title: p.name, subtitle: [if (p.admin1 != null && p.admin1 != p.name) p.admin1!, ?p.country].join(', '),
                  onTap: () => Navigator.pop(context, p)),
          ]),
        ],
      ]);
}
