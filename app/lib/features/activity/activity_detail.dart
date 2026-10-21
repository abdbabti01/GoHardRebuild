import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/device_prefs.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/db.dart' show Rec;
import '../../data/models.dart';
import '../../data/sync.dart' show LocalSaveFailure;
import '../coach/coach_bubble.dart';
import 'gpx.dart';
import 'intervals.dart';
import 'recorder.dart' show recordCueProvider;
import 'records.dart';
import 'route_map.dart';
import 'steps.dart';
import 'run_walk_screens.dart' show StatFigure, activityTitle;
import 'track_math.dart';

/// The stored route of a saved activity, analysed by the one pipeline. A route recorded on another phone is read
/// from the account once, page by page, and kept here. Opening details never starts location.
final routeAnalysisProvider = FutureProvider.autoDispose.family<TrackAnalysis, String>((ref, id) async {
  final owner = ref.watch(ownerProvider);
  if (owner == null) return TrackAnalysis();
  final store = ref.watch(trackStoreProvider);
  var a = await store.analyze(owner, id);
  if (a.startT == null && a.fixes == 0) {
    final run = [for (final r in ref.read(runsProvider).value ?? const <Stored<Run>>[]) if (r.value.id == id) r.value].firstOrNull;
    if (run != null && run.routeState != 'none' && await ref.read(runRepositoryProvider).fetchRoute(run)) a = await store.analyze(owner, id);
  }
  return a;
});

/// The upload state of a saved route (kind `route`): null when none was queued from this phone.
final routeSyncProvider = StreamProvider.autoDispose.family<Rec?, String>((ref, id) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) return Stream.value(null);
  return ref.watch(syncProvider).watch(owner, Kinds.route).map((l) => l.where((r) => r.id == id).firstOrNull);
});

/// "Sat, Oct 17, 2026 · 7:20 AM"
String activityWhen(BuildContext context, Run run) {
  final t = DateTime.parse(run.startedAtUtc).toLocal();
  final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
  return context.l10n.runActivityWhen(shortDate(run.dayKey), '${t.year}', time);
}

/// The person's title (user content, never translated), or the activity type for one saved without a title.
String activityName(Run run) => run.title ?? activityTitle(run.activityType);

class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({super.key, required this.runId, this.justSaved = false});
  final String runId;
  final bool justSaved;
  @override
  ConsumerState<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

enum _Tab { overview, splits, charts }

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  _Tab _tab = _Tab.overview;
  int? _selectedNo;

  /// The split shown on the map; splits are recomputed on each build, so it is kept by number.
  TrackSplit? _selectedIn(TrackAnalysis? a, DistanceUnit unit) => _selectedNo == null ? null : a?.splits(unit.meters).where((s) => s.number == _selectedNo).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final stored = [for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) if (r.value.id == widget.runId) r].firstOrNull;
    if (stored == null || stored.value.isDeleted) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final run = stored.value;
    final unit = ref.watch(devicePrefsProvider.select((p) => p.distance));
    final analysis = ref.watch(routeAnalysisProvider(run.id));
    final a = analysis.value;
    final hasRoute = a != null && a.points.length > 1;
    final moving = run.movingSeconds;
    final distance = run.distanceMeters;
    final pace = moving != null && distance != null && distance >= 50 && moving >= 20 ? moving / distance * unit.meters : null;
    final gain = run.elevationGainMeters;
    final selected = _selectedIn(a, unit);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(actions: [
        PopupMenuButton<String>(
          key: const Key('activity-menu'), tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
          onSelected: (v) => switch (v) {
            'edit' => _edit(run, a),
            'gpx' => _export(run),
            _ => _delete(run),
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
            if (hasRoute) PopupMenuItem(value: 'gpx', child: Text(l.runExportGpx)),
            PopupMenuItem(value: 'delete', child: Text(l.actionDelete)),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 12, start: 4),
          child: FilledButton(key: const Key('activity-done'), onPressed: () => Navigator.of(context).maybePop(), child: Text(l.actionDone)),
        ),
      ]),
      body: SafeArea(
        child: ListView(padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 28), children: [
          Heading(activityName(run), size: 36, serif: true),
          const SizedBox(height: 4),
          Text([activityWhen(context, run), activityTitle(run.activityType), if (run.metrics['intervals'] != null) l.runSetupIntervals].join(' · '), style: context.sansStyle(16, color: context.c.secondary)),
          ..._records(run),
          const SizedBox(height: 14),
          if (analysis.isLoading)
            const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
          else if (hasRoute)
            SizedBox(
              height: 240,
              child: RouteMap(
                key: const Key('activity-map'), segments: a.segments, controls: true,
                highlight: selected == null ? null : (selected.startMeters, selected.endMeters),
                onExpand: () => push(context, _FullMap(title: activityName(run), segments: a.segments, highlight: selected == null ? null : (selected.startMeters, selected.endMeters))),
                semanticLabel: l.runRecordedRoute,
              ),
            )
          else
            _NoRoute(run: run),
          const SizedBox(height: 16),
          StatFigure(distance == null ? '—' : unit.number(distance), unit.label,
              distance == null ? l.runDistanceNotRecorded : run.distanceSource == 'manual' ? l.runDistanceTyped : run.distanceSource == 'corrected' ? l.runDistanceCorrected : l.runDistance,
              key: const Key('activity-distance'), size: 52),
          const SizedBox(height: 10),
          Wrap(spacing: 28, runSpacing: 10, children: [
            if (moving != null)
              StatFigure(clockText(moving), null, l.runMovingTime, said: l.runMovingTimeSaid(durationText(moving)))
            else
              StatFigure(clockText(run.activeDurationSeconds ?? 0), null, l.runTime, said: l.runTimeSaid(durationText(run.activeDurationSeconds ?? 0))),
            if (!run.isLegacy) StatFigure(unit.paceNumber(pace), '/${unit.label}', l.runAvgMovingPace),
          ]),
          if (!run.isLegacy) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(Radii.field), border: Border.all(color: context.c.divider)),
              child: Text(
                [
                  l.runElapsed(ltr(clockText(run.elapsedSeconds ?? 0))),
                  gain == null ? l.runElevationGainNotMeasured : l.runElevationGain(unit.elevation(gain)),
                ].join('  ·  '),
                textAlign: TextAlign.center, style: context.sansStyle(14.5),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Segmented<_Tab>(keyPrefix: 'activity-tab', values: _Tab.values, selected: _tab, label: (t) => switch (t) {
                _Tab.overview => l.runTabOverview,
                _Tab.splits => l.runTabSplits,
                _Tab.charts => l.runTabCharts,
              }, onChanged: (t) => setState(() => _tab = t)),
          const SizedBox(height: 14),
          ...switch (_tab) {
            _Tab.overview => _overview(context, stored, a, unit),
            _Tab.splits => _splits(context, a, unit),
            _Tab.charts => _charts(context, a, unit),
          },
        ]),
      ),
    );
  }

  /// The personal bests this activity holds now (derived, so an edit or a deletion elsewhere is reflected), and the
  /// coach's one calm word about a record this save just set.
  List<Widget> _records(Run run) {
    final runs =[for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) r.value];
    final bests = personalBests(runs);
    final held = [for (final b in bests.by.values) if (b.run.id == run.id && (bests.qualifying[b.benchmark.id] ?? 0) >= 2) b];
    final cue = ref.watch(recordCueProvider);
    return [
      if (held.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 8, runSpacing: 6, children: [
            for (final b in held)
              StatusPill(context.l10n.runBestPill(benchmarkLabel(context.l10n, b.benchmark)), key: Key('activity-best-${b.benchmark.id}'), icon: Icons.emoji_events_outlined, tone: Tone.accent),
          ]),
        ),
      if (widget.justSaved && cue != null && cue.runId == run.id)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CoachSpeaker(key: const Key('activity-record-coach'), say: CoachSay(cue.text), introduce: true, onClose: () => ref.read(recordCueProvider.notifier).played()),
        ),
    ];
  }

  List<Widget> _overview(BuildContext context, Stored<Run> stored, TrackAnalysis? a, DistanceUnit unit) {
    final run = stored.value;
    final m = run.metrics;
    final routeRec = ref.watch(routeSyncProvider(run.id)).value;
    final speed = run.movingSeconds != null && run.distanceMeters != null && run.movingSeconds! > 0 ? run.distanceMeters! / run.movingSeconds! : null;
    final l = context.l10n;
    String summarySync() => switch (stored.rec.syncState) {
          'pending' => l.runSyncPending,
          'conflict' || 'rejected' => l.runSyncReview,
          _ => l.runSyncSaved,
        };
    String routeSync() {
      if ((m['routeState'] ?? 'none') == 'none' && routeRec == null) return run.routeState == 'complete' ? l.runRouteSyncSaved : l.runRouteSyncNone;
      if (routeRec == null) return run.routeState == 'complete' ? l.runRouteSyncSaved : l.runRouteSyncKept;
      return switch (routeRec.syncState) {
        'synced' => l.runRouteSyncSaved,
        'conflict' || 'rejected' => l.runRouteSyncAttention,
        _ => l.runRouteSyncWaiting,
      };
    }

    final rejected = (m['rejectedCount'] as num? ?? 0).toInt();
    final rows = <(String, String)>[
      (l.runActiveTime, clockText(run.activeDurationSeconds ?? 0)),
      (l.runSteps, stepsText(m)),
      if (speed != null) (l.runAvgSpeed, unit.speed(speed)),
      if (m['elevationLossMeters'] != null) (l.runElevationLoss, unit.elevation((m['elevationLossMeters'] as num).toDouble())),
      if (run.distanceSource == 'corrected' && m['gpsDistanceMeters'] != null) (l.runMeasuredByGps, unit.distance((m['gpsDistanceMeters'] as num).toDouble())),
      if (m['pointCount'] != null) (l.runGpsPointsUsed, rejected > 0 ? l.runGpsPointsRejected('${m['pointCount']}', rejected) : '${m['pointCount']}'),
      if ((m['gaps'] ?? 0) > 0 || (m['interrupted'] ?? 0) > 0)
        (l.runGaps, l.runGapsValue((m['gaps'] as int? ?? 0) + (m['interrupted'] as int? ?? 0))),
      if (m['legacyDistanceMeters'] != null) (l.runBeforeRoutes, l.runBeforeRoutesValue(unit.distance((m['legacyDistanceMeters'] as num).toDouble()))),
      (l.runSummary, summarySync()),
      (l.runRoute, routeSync()),
    ];
    return [
      if (run.notes != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(run.notes!, style: context.sansStyle(16))),
      if (run.metrics['routeState'] == 'partial')
        Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.info_outline, l.runPartialRoute)),
      GroupCard(children: [for (final (k, v) in rows) GroupRow(title: k, value: v)]),
      ..._intervals(context, run),
    ];
  }

  /// The phase timeline of an interval session: one activity, its phases as recorded (a skipped phase is marked).
  List<Widget> _intervals(BuildContext context, Run run) {
    final iv = run.metrics['intervals'] as Map?;
    final plan = IntervalPlan.fromJson(iv?['plan']);
    if (plan == null) return const [];
    final skips = [for (final v in (iv?['skips'] as List? ?? const [])) if (v is num) v.toInt()];
    final tl = IntervalClock.timeline(plan, skips, (run.activeDurationSeconds ?? 0) * 1000);
    final runs = tl.where((p) => p.phase.kind == PhaseKind.run && !p.skipped).length;
    final l = context.l10n;
    return [
      const SizedBox(height: 16),
      Text(l.runSetupIntervals, style: context.sansStyle(16, weight: FontWeight.w600)),
      Text('${l.runPlanRepeats(plan.reps, phaseClock(plan.run), phaseClock(plan.walk))} · ${l.runIntervalsRunsCompleted(runs, plan.reps)}', style: context.caption),
      const SizedBox(height: 8),
      GroupCard(key: const Key('activity-intervals'), children: [
        for (final p in tl)
          GroupRow(
            title: [phaseName(l, p.phase.kind), if (p.phase.round != null) '${p.phase.round}'].join(' '), icon: p.phase.kind == PhaseKind.run ? Icons.directions_run : Icons.directions_walk,
            tone: p.phase.kind == PhaseKind.run ? Tone.accent : Tone.neutral,
            subtitle: p.skipped ? l.runEndedEarly(phaseClock(p.phase.seconds)) : null, value: phaseClock(p.seconds),
          ),
      ]),
    ];
  }

  List<Widget> _splits(BuildContext context, TrackAnalysis? a, DistanceUnit unit) {
    final splits = a?.splits(unit.meters) ?? const <TrackSplit>[];
    final l = context.l10n;
    if (splits.isEmpty) return [Text(l.runNoSplits, style: context.caption)];
    return [
      Text(l.runSelectSplit, style: context.caption),
      const SizedBox(height: 8),
      GroupCard(children: [
        for (final s in splits)
          GroupRow(
            key: Key('split-${s.number}'),
            title: s.partial ? l.runSplitLast(s.number, unit.distance(s.distanceMeters)) : '${s.number}',
            subtitle: s.partial ? l.runPartialSplit : s.number == _selectedNo ? l.runShownOnMap : null,
            icon: s.number == _selectedNo ? Icons.place : Icons.flag_outlined, tone: s.number == _selectedNo ? Tone.accent : Tone.neutral,
            value: unit.pace(s.paceFor(unit.meters)),
            onTap: () => setState(() => _selectedNo = s.number == _selectedNo ? null : s.number),
          ),
      ]),
    ];
  }

  List<Widget> _charts(BuildContext context, TrackAnalysis? a, DistanceUnit unit) {
    final l = context.l10n;
    if (a == null || a.points.length < 2) return [Text(l.runNoCharts, style: context.caption)];
    final pace = a.paceProfile(unit.meters / 10, unit.meters);
    final ele = a.elevationProfile();
    final gl = a.elevationGainLoss();
    return [
      Text(l.runChartPace, style: context.sansStyle(16, weight: FontWeight.w600)),
      Text(l.runChartPaceNote(unit == DistanceUnit.km ? withUnit('100', l.unitMetre) : withUnit(localDecimal('0.1'), l.unitMi)), style: context.caption),
      const SizedBox(height: 8),
      pace.isEmpty ? Text(l.runChartPaceTooShort, style: context.caption) : _Chart(key: const Key('chart-pace'), series: pace, unit: unit, invert: true, y: unit.paceNumber),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: Text(l.runChartElevation, style: context.sansStyle(16, weight: FontWeight.w600))),
        Text(gl == null ? l.runGainNotMeasured : l.runGainShort(unit.elevation(gl.$1)), style: context.caption),
      ]),
      const SizedBox(height: 8),
      ele.isEmpty
          ? Text(l.runNoAltitude, style: context.caption)
          : _Chart(key: const Key('chart-elevation'), series: ele, unit: unit, y: (v) => unit.elevation(v)),
    ];
  }

  Future<void> _edit(Run run, TrackAnalysis? a) async {
    final unit = ref.read(devicePrefsProvider).distance;
    final gps = (run.metrics['gpsDistanceMeters'] as num?)?.toDouble();
    final title = TextEditingController(text: activityName(run)), notes = TextEditingController(text: run.notes ?? '');
    final distance = TextEditingController(text: run.distanceSource == 'gps' || run.distanceMeters == null ? '' : unit.number(run.distanceMeters!));
    var type = run.activityType;
    String? error;
    final l = context.l10n;
    await showGoSheet<void>(context, title: l.actionEdit, builder: (sheet) => StatefulBuilder(
          builder: (sheet, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Segmented<String>(keyPrefix: 'edit-type', values: const ['run', 'walk'], selected: type, label: activityTitle, onChanged: (t) => set(() => type = t)),
            const SizedBox(height: 12),
            TextField(key: const Key('edit-title'), controller: title, maxLength: 80, decoration: InputDecoration(labelText: l.runTitleField)),
            TextField(key: const Key('edit-notes'), controller: notes, maxLength: 1000, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: l.runNotesField)),
            TextField(
              key: const Key('edit-distance'), controller: distance, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: gps == null ? l.runDistanceOptional : l.runCorrectDistance, suffixText: unit.label,
                  helperText: gps == null ? l.runDistanceTypedHelper : l.runBlankKeepsGps(unit.distance(gps)), helperMaxLines: 2),
            ),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.error_outline, error!, tone: Tone.error)),
            const SizedBox(height: 14),
            PrimaryButton(l.runSaveChanges, key: const Key('edit-save'), onPressed: () async {
              final typed = parseNonNegative(distance.text);
              if (distance.text.trim().isNotEmpty && (typed == null || typed > 1000)) return set(() => error = l.runDistanceInvalid);
              if (title.text.trim().isEmpty) return set(() => error = l.runTitleRequired);
              final meters = typed == null ? gps : typed * unit.meters;
              final source = typed == null ? (gps == null ? 'none' : 'gps') : (gps == null ? 'manual' : 'corrected');
              try {
                await ref.read(runRepositoryProvider).update(run, type: type, title: title.text.trim(), notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                    distanceMeters: meters == null ? null : (meters * 10).round() / 10, metrics: {...run.metrics, 'distanceSource': source});
                if (sheet.mounted) Navigator.pop(sheet);
              } on LocalSaveFailure {
                set(() => error = l.runEditSaveFailed);
              }
            }),
          ]),
        ));
  }

  Future<void> _delete(Run run) async {
    final type = run.activityType, l = context.l10n;
    if (!await confirm(context, title: l.runDeleteTitle(type), body: l.runDeleteBody(type, longDate(run.dayKey)), action: l.runDeleteAction(type), destructive: true)) {
      return;
    }
    try {
      await ref.read(runRepositoryProvider).delete(run);
      if (mounted) Navigator.of(context).maybePop();
    } on LocalSaveFailure {
      if (mounted) toast(context, l.runDeleteFailed);
    }
  }

  Future<void> _export(Run run) async {
    final owner = ref.read(ownerProvider);
    if (owner == null) return;
    final failed = context.l10n.runGpxFailed;
    try {
      final entries = await ref.read(trackStoreProvider).all(owner, run.id);
      final dir = await getTemporaryDirectory();
      final name = activityName(run).replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
      final file = File('${dir.path}/${name.isEmpty ? 'activity' : name} ${run.dayKey}.gpx');
      await file.writeAsBytes(utf8.encode(toGpx(run, entries, name: activityName(run))));
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/gpx+xml')], subject: activityName(run)));
    } on Object {
      if (mounted) toast(context, failed);
    }
  }
}

class _NoRoute extends StatelessWidget {
  const _NoRoute({required this.run});
  final Run run;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('activity-no-route'),
        constraints: const BoxConstraints(minHeight: 120), alignment: Alignment.center, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.c.sunken, borderRadius: BorderRadius.circular(Radii.panel)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.route_outlined, color: context.c.secondary),
          const SizedBox(height: 6),
          Text(context.l10n.runRouteNotRecorded, style: context.sansStyle(16, weight: FontWeight.w600)),
          Text(
              run.isLegacy
                  ? context.l10n.runNoRouteLegacy
                  : run.distanceSource == 'manual'
                      ? context.l10n.runNoRouteManual
                      : context.l10n.runNoRoutePositions(run.activityType),
              textAlign: TextAlign.center, style: context.caption),
        ]),
      );
}

class _FullMap extends StatelessWidget {
  const _FullMap({required this.title, required this.segments, this.highlight});
  final String title;
  final List<List<TrackPoint>> segments;
  final (double, double)? highlight;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 12),
            child: RouteMap(key: const Key('activity-map-full'), segments: segments, controls: true, zoomButtons: true, highlight: highlight, semanticLabel: context.l10n.runRecordedRoute),
          ),
        ),
      );
}

/// A line chart of measured values only, one line per series (a gap or pause breaks it). x is metres.
class _Chart extends StatelessWidget {
  const _Chart({super.key, required this.series, required this.unit, required this.y, this.invert = false});
  final List<List<(double, double)>> series;
  final DistanceUnit unit;
  final String Function(double) y;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final all = [for (final s in series) ...s];
    final lo = all.map((p) => p.$2).reduce(min), hi = all.map((p) => p.$2).reduce(max);
    final maxX = all.map((p) => p.$1).reduce(max);
    final top = invert ? lo : hi, bottom = invert ? hi : lo;
    return Semantics(
      label: context.l10n.runChartSaid(y(bottom), y(top), unit.distance(maxX)),
      child: ExcludeSemantics(
        // Distance runs left to right in every language; the labels stay at the data they name (0 at its left end,
        // the total at its right, the values on the right edge).
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
          height: 150,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Column(children: [
                Expanded(child: CustomPaint(size: Size.infinite, painter: _ChartPainter(series, lo, hi, maxX, invert, context.c.accent, context.c.tint, context.c.divider))),
                const SizedBox(height: 4),
                Row(children: [Text('0', style: context.caption), const Spacer(), Text(unit.distance(maxX), style: context.caption)]),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(y(top), style: context.caption), const Spacer(), Text(y(bottom), style: context.caption), const SizedBox(height: 20)]),
          ]),
        ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.series, this.lo, this.hi, this.maxX, this.invert, this.line, this.fill, this.grid);
  final List<List<(double, double)>> series;
  final double lo, hi, maxX;
  final bool invert;
  final Color line, fill, grid;

  @override
  void paint(Canvas canvas, Size size) {
    final range = max(1e-6, hi - lo);
    Offset at((double, double) p) {
      final t = (p.$2 - lo) / range;
      return Offset(maxX <= 0 ? 0 : p.$1 / maxX * size.width, invert ? t * size.height * 0.9 + size.height * 0.05 : size.height - (t * size.height * 0.9 + size.height * 0.05));
    }

    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), Paint()..color = grid);
    for (final s in series) {
      if (s.length < 2) {
        canvas.drawCircle(at(s.first), 2.5, Paint()..color = line);
        continue;
      }
      final path = Path()..moveTo(at(s.first).dx, at(s.first).dy);
      for (final p in s.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      final area = Path.from(path)
        ..lineTo(at(s.last).dx, size.height)
        ..lineTo(at(s.first).dx, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = fill.withValues(alpha: 0.5));
      canvas.drawPath(path, Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.series != series;
}
