import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../me/account_repository.dart';
import '../workout/workout_runtime.dart';
import 'run_tracking.dart';

/// Start run creates the owned run record first and navigates only once it exists. An open run is resumed
/// rather than duplicated; a failed create leaves the user where they were.
Future<void> startRunFlow(BuildContext context, WidgetRef ref) async {
  final open = [for (final r in ref.read(runsProvider).value ?? const <Stored<Run>>[]) if (r.value.isOpen) r.value].firstOrNull;
  if (open != null) {
    await push(context, RunScreen(runId: open.id));
    return;
  }
  try {
    final run = await ref.read(activityRepositoryProvider).startRun(ref.read(todayKeyProvider));
    final sync = ref.read(syncProvider);
    await sync.putLocal(ref.read(ownerProvider)!, LocalWrite(Kinds.runtime, run.id, WorkoutRuntime.started(ref.read(clockProvider).utcNow()).j));
    if (context.mounted) await push(context, RunScreen(runId: run.id));
  } on LocalSaveFailure {
    if (context.mounted) toast(context, 'The run could not be started on this phone. Nothing was recorded.');
  }
}

/// A timed run with GPS distance. The clock is computed from saved anchors, so it survives backgrounding and
/// restart; distance comes only from real location readings taken while this screen is open.
// ponytail: GPS is foreground-only (no background service). Time away from this screen becomes a counted gap,
// never an estimate. Add a foreground location service when continuous background tracking is wanted.
class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key, required this.runId});
  final String runId;
  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> {
  Timer? _ticker;
  StreamSubscription<Position>? _gps;
  final _km = TextEditingController();
  String? _error, _gpsNote;
  WorkoutRuntime? _rt;
  bool _closed = false;
  // Captured once: late location readings and dispose() must not reach for ref, and stay with this owner.
  late final _sync = ref.read(syncProvider);
  late final _owner = ref.read(ownerProvider)!;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _startGps(ask: false); // continues silently if permission was already given; never prompts on its own
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _gps?.cancel();
    _km.dispose();
    super.dispose();
  }

  Future<void> _save(WorkoutRuntime r) {
    _rt = r;
    return _sync.putLocal(_owner, LocalWrite(Kinds.runtime, widget.runId, r.j));
  }

  RunTrack _track(WorkoutRuntime? r) => RunTrack(r?.j['track'] as Json? ?? const {});

  Future<void> _startGps({required bool ask}) async {
    if (_gps != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (ask && mounted) setState(() => _gpsNote = 'Location is turned off on this phone. Turn it on to measure distance.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (ask && mounted) setState(() => _gpsNote = 'Location permission was not given, so distance is not measured. You can still time the run and type a distance.');
        return;
      }
      _gps = Geolocator.getPositionStream(
          // Android is asked for a reading every 2 s; without this it may batch readings further apart than the gap limit.
          locationSettings: defaultTargetPlatform == TargetPlatform.android
              ? AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 3, intervalDuration: const Duration(seconds: 2), forceLocationManager: true)
              : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3)).listen(_onFix, onError: (Object _) {});
      if (mounted) setState(() => _gpsNote = null);
    } on Object {
      if (ask && mounted) setState(() => _gpsNote = 'Location is not available on this device.');
    }
  }

  void _onFix(Position p) {
    final r = _rt;
    if (r == null || r.isPaused || _closed) return; // paused movement is not part of the run
    final track = _track(r).added(Fix(p.latitude, p.longitude, p.accuracy, p.timestamp.toUtc()));
    _save(WorkoutRuntime(copyJson(r.j)..['track'] = track.j)).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final run = (ref.watch(runsProvider).value ?? const <Stored<Run>>[]).where((r) => r.value.id == widget.runId).firstOrNull?.value;
    final runtimeRow = (ref.watch(runtimesProvider).value ?? const <Stored<Json>>[]).where((r) => r.rec.id == widget.runId).firstOrNull;
    if (run == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final now = ref.read(clockProvider).utcNow();
    final runtime = runtimeRow == null ? null : WorkoutRuntime(runtimeRow.value);
    if (!_closed) _rt = runtime;
    final track = _track(runtime);
    final elapsed = run.isOpen ? (runtime?.elapsedSeconds(now) ?? now.difference(DateTime.parse(run.startedAtUtc)).inSeconds.clamp(0, 604800)) : run.activeDurationSeconds ?? 0;
    String km(double meters) => '${(meters / 1000).toStringAsFixed(2)} km';

    return EveningPage(title: run.isOpen ? 'Run' : 'Run recorded', children: [
      Text(longDate(run.dayKey), style: context.caption),
      const SizedBox(height: 10),
      Semantics(
        label: 'Run time ${durationText(elapsed)}',
        child: ExcludeSemantics(child: Text(clockText(elapsed), style: context.sansStyle(context.display(70), weight: FontWeight.w300).copyWith(fontFeatures: const [FontFeature.tabularFigures()]))),
      ),
      if (run.isOpen) ...[
        if (_gps != null) ...[
          Text(km(track.distanceMeters), key: const Key('run-gps-distance'), style: context.serifStyle(33)),
          StatusLine(Icons.gps_fixed, track.fixes == 0
              ? 'Waiting for a GPS position…'
              : 'Measured by GPS while this screen is open.${track.gaps > 0 ? ' ${track.gaps} stretch${track.gaps == 1 ? '' : 'es'} without readings ${track.gaps == 1 ? 'was' : 'were'} left out, not estimated.' : ''}'),
        ] else ...[
          SecondaryButton('Measure distance with GPS', key: const Key('run-gps-start'), icon: Icons.gps_not_fixed, onPressed: () => _startGps(ask: true)),
          const SizedBox(height: 6),
          Text('Distance is only recorded from real GPS readings, or from what you type below.', style: context.caption),
        ],
        if (_gpsNote != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.info_outline, _gpsNote!, tone: Tone.warning)),
        const SizedBox(height: 18),
        SecondaryButton(runtime?.isPaused ?? false ? 'Resume' : 'Pause', icon: runtime?.isPaused ?? false ? Icons.play_arrow : Icons.pause,
            onPressed: runtime == null
                ? null
                : () => _save(runtime.isPaused ? runtime.resumed(now) : WorkoutRuntime(copyJson(runtime.paused(now).j)..['track'] = track.detached().j))),
        const SizedBox(height: 16),
        TextField(key: const Key('run-distance'), controller: _km, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: track.hasDistance ? 'Correct the distance (optional)' : 'Distance (optional)', suffixText: 'km', hintText: track.hasDistance ? (track.distanceMeters / 1000).toStringAsFixed(2) : 'Unknown')),
        const SizedBox(height: 12),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        PrimaryButton('Finish run', key: const Key('run-finish'), onPressed: () async {
          final typed = parseNonNegative(_km.text);
          if (_km.text.trim().isNotEmpty && typed == null) return setState(() => _error = 'Enter the distance as a number, or leave it blank.');
          // What you typed wins; otherwise the measured distance; otherwise distance stays unknown.
          final meters = typed != null ? typed * 1000 : track.hasDistance ? double.parse(track.distanceMeters.toStringAsFixed(1)) : null;
          try {
            _closed = true;
            await ref.read(activityRepositoryProvider).finishRun(run, activeSeconds: elapsed, distanceMeters: meters);
            await _sync.deleteLocal(_owner, Kinds.runtime, run.id);
            if (context.mounted) Navigator.pop(context);
          } on LocalSaveFailure {
            _closed = false;
            setState(() => _error = 'The run could not be saved on this phone. It is still open.');
          }
        }),
      ] else
        Text('${durationText(elapsed)}${run.distanceMeters == null ? ' · distance not recorded' : ' · ${km(run.distanceMeters!)}'}', style: context.body),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: () async {
            if (!await confirm(context, title: 'Remove this run?', body: 'This removes the run from ${longDate(run.dayKey)} from your history.', action: 'Remove run')) return;
            _closed = true;
            await ref.read(activityRepositoryProvider).deleteRun(run);
            await _sync.deleteLocal(_owner, Kinds.runtime, run.id);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Remove run'),
        ),
      ),
    ]);
  }
}

class RunHistoryScreen extends ConsumerWidget {
  const RunHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = [for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) if (!r.value.isDeleted) r.value]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return EveningPage(title: 'Run history', children: [
      if (runs.isEmpty) EmptyState('No runs yet', 'Runs you record appear here, every one of them.', action: SecondaryButton('Start a run', onPressed: () => startRunFlow(context, ref))),
      for (final r in runs)
        ListRow(
          icon: Icons.directions_run, title: shortDate(r.dayKey),
          subtitle: r.isOpen ? 'In progress' : '${durationText(r.activeDurationSeconds ?? 0)}${r.distanceMeters == null ? '' : ' · ${(r.distanceMeters! / 1000).toStringAsFixed(2)} km'}',
          onTap: () => push(context, RunScreen(runId: r.id)),
        ),
    ]);
  }
}

/// Optional body measurements. Weight is stored in kilograms and shown in the chosen unit.
class BodyMetricsScreen extends ConsumerStatefulWidget {
  const BodyMetricsScreen({super.key});
  @override
  ConsumerState<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends ConsumerState<BodyMetricsScreen> {
  final _weight = TextEditingController(), _fat = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _weight.dispose();
    _fat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(loadUnitProvider);
    final metrics = [for (final r in ref.watch(metricsProvider).value ?? const <Stored<BodyMetric>>[]) if (!r.value.isDeleted) r.value]..sort((a, b) => b.dayKey.compareTo(a.dayKey));
    return EveningPage(title: 'Body measurements', children: [
      Text('Optional. Add a measurement only when it helps you; nothing here is required for a plan.', style: context.caption),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: TextField(key: const Key('metric-weight'), controller: _weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Weight', suffixText: unit.name))),
        const SizedBox(width: 10),
        Expanded(child: TextField(key: const Key('metric-fat'), controller: _fat, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Body fat', suffixText: '%'))),
      ]),
      const SizedBox(height: 12),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      PrimaryButton('Add today\'s measurement', key: const Key('metric-save'), onPressed: () async {
        final w = parseNonNegative(_weight.text), f = parseNonNegative(_fat.text);
        if ((_weight.text.trim().isNotEmpty && w == null) || (_fat.text.trim().isNotEmpty && f == null)) return setState(() => _error = 'Enter numbers of zero or more, or leave a field blank.');
        try {
          await ref.read(activityRepositoryProvider).addMetric(ref.read(todayKeyProvider), weightKg: w == null ? null : loadInputToKg(w, unit), bodyFatPercent: f);
          _weight.clear();
          _fat.clear();
          setState(() => _error = null);
        } on AuthFailure catch (e) {
          setState(() => _error = e.message);
        } on LocalSaveFailure {
          setState(() => _error = 'That could not be saved on this phone. Your entry is still here.');
        }
      }),
      const SizedBox(height: 22),
      const SectionLabel('History'),
      if (metrics.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('No measurements recorded.', style: context.caption)),
      for (final m in metrics)
        ListRow(
          title: [if (m.weightKg != null) formatLoad(m.weightKg, unit), if (m.bodyFatPercent != null) '${formatNumber(m.bodyFatPercent!)} % body fat'].join(' · '),
          subtitle: longDate(m.dayKey),
          trailing: IconButton(tooltip: 'Remove measurement', icon: const Icon(Icons.close, size: 18), onPressed: () async {
            if (await confirm(context, title: 'Remove this measurement?', body: 'The measurement from ${longDate(m.dayKey)} will be removed.', action: 'Remove')) await ref.read(activityRepositoryProvider).deleteMetric(m);
          }),
        ),
    ]);
  }
}
