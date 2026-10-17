import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/device_prefs.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'activity_detail.dart';
import 'route_map.dart';
import 'run_walk_screens.dart';
import 'track_math.dart';

/// A small drawing of a saved route for a history row: presentation geometry only (at most ~80 points); the stored
/// route itself is never simplified.
final routeThumbProvider = FutureProvider.autoDispose.family<List<List<TrackPoint>>, String>((ref, id) async {
  final owner = ref.watch(ownerProvider);
  if (owner == null) return const [];
  final segs = (await ref.watch(trackStoreProvider).analyze(owner, id)).segments;
  final total = segs.fold<int>(0, (n, s) => n + s.length);
  final stride = (total / 80).ceil().clamp(1, 1 << 20);
  return [
    for (final s in segs)
      if (s.length > 1) [for (var i = 0; i < s.length; i += stride) s[i], if ((s.length - 1) % stride != 0) s.last],
  ];
});

enum _Filter { all, run, walk }

class ActivityHistoryScreen extends ConsumerStatefulWidget {
  const ActivityHistoryScreen({super.key});
  @override
  ConsumerState<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends ConsumerState<ActivityHistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(devicePrefsProvider.select((p) => p.distance));
    final today = parseDayKey(ref.watch(todayKeyProvider));
    final all = [for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) if (!r.value.isDeleted) r.value]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    final open = all.where((r) => r.isOpen).firstOrNull;
    final saved = [for (final r in all) if (!r.isOpen && (_filter == _Filter.all || r.activityType == _filter.name)) r];
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    bool inWeek(Run r) => !parseDayKey(r.dayKey).isBefore(weekStart);
    bool inMonth(Run r) => parseDayKey(r.dayKey).year == today.year && parseDayKey(r.dayKey).month == today.month;
    final noun = switch (_filter) {
      _Filter.all => 'activities',
      _Filter.run => 'runs',
      _Filter.walk => 'walks',
    };

    final header = <Widget>[
      Heading('History', size: 36, serif: true),
      const SizedBox(height: 14),
      Segmented<_Filter>(keyPrefix: 'history-filter', values: _Filter.values, selected: _filter, label: (f) => switch (f) {
            _Filter.all => 'All',
            _Filter.run => 'Run',
            _Filter.walk => 'Walk',
          }, onChanged: (f) => setState(() => _filter = f)),
      const SizedBox(height: 14),
      if (open != null) ...[
        GroupCard(children: [
          GroupRow(key: const Key('history-open'), icon: Icons.timelapse, title: '${activityTitle(open.activityType)} in progress', subtitle: 'Started ${shortDate(open.dayKey)}',
              onTap: () => push(context, const RunWalkScreen())),
        ]),
        const SizedBox(height: 14),
      ],
      if (saved.isNotEmpty) ...[
        Row(children: [
          Expanded(child: _Totals(key: const Key('history-week'), label: 'This week', runs: saved.where(inWeek).toList(), unit: unit)),
          const SizedBox(width: 10),
          Expanded(child: _Totals(key: const Key('history-month'), label: 'This month', runs: saved.where(inMonth).toList(), unit: unit)),
        ]),
        const SizedBox(height: 16),
      ],
      if (saved.isEmpty)
        EmptyState('No $noun yet', 'Saved ${_filter == _Filter.all ? 'runs and walks' : noun} appear here, every one of them.',
            action: SecondaryButton('Start one', onPressed: () => push(context, const RunWalkScreen()))),
    ];

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        // Built lazily: a long history only builds the rows on screen.
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 28),
          itemCount: header.length + saved.length,
          itemBuilder: (context, i) => i < header.length ? header[i] : Padding(padding: const EdgeInsets.only(bottom: 8), child: _Row(run: saved[i - header.length], unit: unit)),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({super.key, required this.label, required this.runs, required this.unit});
  final String label;
  final List<Run> runs;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final measured = runs.where((r) => r.distanceMeters != null);
    final distance = measured.fold<double>(0, (s, r) => s + r.distanceMeters!);
    final seconds = runs.fold<int>(0, (s, r) => s + (r.activeDurationSeconds ?? 0));
    final said = '$label: ${runs.length} saved, ${unit.distance(distance)}${measured.length < runs.length ? ' where distance is known' : ''}, ${durationText(seconds)} active';
    return Semantics(
      label: said,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: GoColors.panelOf(context.c).page, borderRadius: BorderRadius.circular(Radii.tile)),
          child: PanelTheme(
            child: Builder(
              builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: context.caption),
                Text(unit.distance(distance), style: context.pageTitleStyle(24)),
                Text('${runs.length} · ${durationText(seconds)} active', style: context.sansStyle(13.5, color: context.c.secondary)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.run, required this.unit});
  final Run run;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(routeThumbProvider(run.id)).value;
    final time = run.movingSeconds ?? run.activeDurationSeconds ?? 0;
    final subtitle = [
      '${shortDate(run.dayKey)} · ${activityTitle(run.activityType)}',
      [if (run.distanceMeters != null) unit.distance(run.distanceMeters), durationText(time), if (run.isLegacy) 'Route not recorded'].join(' · '),
    ];
    return Pressable(
      key: Key('history-${run.id}'),
      onTap: () => push(context, ActivityDetailScreen(runId: run.id)),
      semanticLabel: '${activityName(run)}. ${subtitle.join('. ')}',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(Radii.panel), border: Border.all(color: context.c.divider)),
        child: Row(children: [
          thumb != null && thumb.isNotEmpty
              ? RouteThumb(segments: thumb)
              : Container(width: 56, height: 56, decoration: BoxDecoration(color: context.c.sunken, borderRadius: BorderRadius.circular(12)),
                  child: Icon(run.isWalk ? Icons.directions_walk : Icons.directions_run, color: context.c.secondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(activityName(run), style: context.sansStyle(16, weight: FontWeight.w600)),
              for (final s in subtitle) Text(s, style: context.caption),
            ]),
          ),
          Icon(Icons.chevron_right, color: context.c.secondary),
        ]),
      ),
    );
  }
}
