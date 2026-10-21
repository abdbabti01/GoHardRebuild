import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show clockProvider;
import '../../core/format.dart' show ltr;
import '../../core/language.dart';
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

  static String _subtitle(AppLocalizations l, TodayBackground b) => switch (b) {
        TodayBackground.scenic => l.weatherBackgroundScenicDetail,
        TodayBackground.weather => l.weatherBackgroundWeatherDetail,
        TodayBackground.plain => l.weatherBackgroundPlainDetail,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(weatherPrefsProvider);
    final scene = ref.watch(todaySceneProvider);
    final set = ref.read(weatherPrefsProvider.notifier);
    final l = context.l10n;
    return AppPage(title: l.weatherBackgroundTitle, subtitle: l.weatherBackgroundSubtitle, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.panel),
        child: SizedBox(height: 120, child: SceneBackdrop(key: const Key('today-background-preview'), spec: scene)),
      ),
      const SizedBox(height: 16),
      for (final b in TodayBackground.values)
        ChoiceTile<TodayBackground>(
            key: Key('today-background-${b.name}'), value: b, groupValue: prefs.background, onChanged: set.setBackground, title: todayBackgroundLabel(l, b), subtitle: _subtitle(l, b)),
      if (prefs.background == TodayBackground.weather) ...[
        const SizedBox(height: 14),
        SectionLabel(l.weatherLocationSection),
        const SizedBox(height: 8),
        ChoiceTile<WeatherLocationMode>(
            key: const Key('weather-location-automatic'), value: WeatherLocationMode.automatic, groupValue: prefs.mode,
            onChanged: (_) => chooseAutomatic(context, ref), title: l.weatherAutomatic, subtitle: l.weatherAutomaticDetail),
        ChoiceTile<WeatherLocationMode>(
            key: const Key('weather-location-city'), value: WeatherLocationMode.city, groupValue: prefs.mode,
            onChanged: (_) => prefs.city == null ? _searchCity(context, ref) : set.setMode(WeatherLocationMode.city),
            title: l.weatherSelectedCity, subtitle: prefs.city?.fullLabel ?? l.weatherSearchForCity),
        if (prefs.mode == WeatherLocationMode.city && prefs.city != null)
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(key: const Key('weather-change-city'), onPressed: () => _searchCity(context, ref), child: Text(l.weatherChangeCity))),
        const _Issue(),
        const SizedBox(height: 14),
        SectionLabel(l.weatherNowSection),
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
    final l = context.l10n;
    final go = await confirm(context, title: l.weatherConsentTitle, body: l.weatherConsentBody, action: l.actionContinue, cancel: l.weatherNotNow);
    if (go) await ref.read(weatherProvider.notifier).allowLocation();
  }

  static Future<void> _searchCity(BuildContext context, WidgetRef ref) async {
    final place = await showGoSheet<WeatherPlace>(context, title: context.l10n.weatherChooseCity, builder: (_) => const _CitySearch());
    if (place != null) ref.read(weatherPrefsProvider.notifier).selectCity(place);
  }
}

class _Issue extends ConsumerWidget {
  const _Issue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issue = ref.watch(weatherProvider.select((s) => s.issue));
    final locator = ref.read(weatherLocatorProvider);
    final l = context.l10n;
    final (text, action, onAction) = switch (issue) {
      null => (null, null, null),
      WeatherIssue.needsPermission => (l.weatherIssueNeedsPermission, l.weatherUseMyLocation, () => TodayBackgroundScreen.chooseAutomatic(context, ref)),
      WeatherIssue.denied => (l.weatherIssueDenied, l.weatherUseMyLocation, () => TodayBackgroundScreen.chooseAutomatic(context, ref)),
      WeatherIssue.deniedForever => (l.weatherIssueDeniedForever, l.weatherOpenSettings, locator.openAppSettings),
      WeatherIssue.servicesOff => (l.weatherIssueServicesOff, l.weatherLocationSettings, locator.openLocationSettings),
      WeatherIssue.timeout => (l.weatherIssueTimeout, null, null),
      WeatherIssue.noCity => (l.weatherIssueNoCity, null, null),
      WeatherIssue.offline || WeatherIssue.unavailable => (l.weatherIssueUnreachable, null, null),
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
    final l = context.l10n;
    final place = prefs.mode == WeatherLocationMode.city ? prefs.city?.fullLabel : l.weatherApproximateLocation;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (scene.isWeather && c != null) ...[
        Text(sceneLabel(l, scene), key: const Key('weather-condition'), style: context.sansStyle(16, weight: FontWeight.w600)),
        Text(place == null ? l.weatherAsOf(TimeOfDay.fromDateTime(c.validAtUtc.toLocal()).format(context)) : l.weatherAsOfPlace(TimeOfDay.fromDateTime(c.validAtUtc.toLocal()).format(context), place),
            key: const Key('weather-as-of'), style: context.caption),
      ] else
        Text(weather.busy ? l.weatherChecking : l.weatherNone, key: const Key('weather-none'), style: context.caption),
      const SizedBox(height: 10),
      const _Basis(),
      const SizedBox(height: 10),
      Text('${c?.credit(l) ?? l.weatherCreditDefault} ${l.weatherModelData}', style: context.caption),
      Text(l.weatherIllustrative, style: context.caption),
    ]);
  }
}

/// "What the scene is based on": everything needed to see why Today shows what it shows, on the phone itself.
/// No coordinates: the area is described, never located.
class _Basis extends ConsumerWidget {
  const _Basis();

  static String _ago(AppLocalizations l, Duration d) => d.inMinutes < 1 ? l.weatherJustNow : d.inMinutes < 120 ? l.weatherMinutesAgo(d.inMinutes) : l.weatherHoursAgo(d.inHours);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(weatherPrefsProvider);
    if (prefs.background != TodayBackground.weather) return const SizedBox.shrink();
    final scene = ref.watch(todaySceneProvider);
    final weather = ref.watch(weatherProvider);
    final now = ref.watch(clockProvider).utcNow();
    final e = weather.entry, c = e?.conditions;
    final l = context.l10n;
    // Technical values (scene and issue ids, the provider's own description, WMO code, time zone) stay as they are.
    final rows = <(String, String)>[
      (l.weatherLocationSection, prefs.mode == WeatherLocationMode.city ? (prefs.city?.fullLabel ?? l.weatherNoCityChosen) : l.weatherAutomaticBasis),
      if (weather.issue != null) (l.weatherBasisLastAttempt, weather.issue!.name),
      (l.weatherBasisScene, scene.isWeather ? l.weatherBasisSceneWeather(scene.key) : scene.fallback != null ? l.weatherBasisSceneScenic(weatherFallbackText(l, scene.fallback!)) : scene.key),
      if (c != null) ...[
        (l.weatherBasisCondition, ltr('${c.description ?? c.family}${c.code == null ? '' : ' · WMO ${c.code}'}')),
        (l.weatherBasisSource, c.source == 'met.no' ? 'MET Norway' : 'Open-Meteo'),
        (l.weatherBasisDayNight, switch (c.isDay) { true => l.weatherDay, false => l.weatherNight, null => l.weatherNotGiven }),
        (l.weatherBasisValid, l.weatherValidAt(TimeOfDay.fromDateTime(c.validAtUtc.toLocal()).format(context), _ago(l, now.difference(c.validAtUtc)))),
        if (c.timezone != null) (l.weatherBasisTimezone, ltr(c.timezone!)),
        (l.weatherBasisFetched, _ago(l, now.difference(e!.fetchedAtUtc))),
        (l.weatherBasisKeptFor, e.source == prefs.source ? (prefs.mode == WeatherLocationMode.city ? l.weatherKeptThisCity : l.weatherAutomatic) : l.weatherKeptOther),
      ],
    ];
    return Semantics(
      container: true, label: l.weatherBasisTitle,
      child: Column(key: const Key('weather-basis'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.weatherBasisTitle, style: context.label),
        const SizedBox(height: 4),
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(TextSpan(children: [TextSpan(text: '$k  ', style: context.caption), TextSpan(text: v, style: context.sansStyle(14))])),
          ),
      ]),
    );
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
    final l = context.l10n;
    if (q.length < 2) return setState(() => _note = l.weatherTypeTwoLetters);
    final token = ++_token;
    setState(() => _note = l.weatherSearching);
    try {
      final found = await ref.read(weatherSourceProvider).places(q);
      if (!mounted || token != _token) return; // an older search answering late
      setState(() {
        _results = found;
        _note = found.isEmpty ? l.weatherNoPlaces(q) : null;
      });
    } on LookupFailure {
      if (!mounted || token != _token) return;
      setState(() {
        _results = null;
        _note = l.weatherCitySearchFailed;
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
              labelText: context.l10n.weatherCityLabel, suffixIcon: IconButton(key: const Key('city-search-go'), tooltip: context.l10n.weatherSearchTooltip, icon: const Icon(Icons.search), onPressed: _search)),
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
