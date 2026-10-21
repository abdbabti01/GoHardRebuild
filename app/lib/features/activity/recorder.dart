import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/device_prefs.dart';
import '../../core/language.dart' show appL10nProvider;
import '../../data/models.dart';
import '../../data/sync.dart';
import 'announcer.dart';
import 'intervals.dart';
import 'location_source.dart';
import 'move_prefs.dart';
import 'records.dart';
import 'steps.dart';
import 'track_math.dart';
import 'track_store.dart';

/// docs/RUN_WALK.md › Recording state machine.
enum RecState {
  /// No open activity on this phone.
  idle,
  recording,

  /// Paused by the person.
  paused,

  /// Paused by auto-pause; resumes by itself on sustained movement.
  autoPaused,

  /// Open, but its recorder stopped (the app was closed or the phone restarted): Resume or Finish.
  interrupted,

  /// Finished, waiting for Save or Discard in the review.
  review,
}

/// What the recording screen must say: entries are not being stored, or the GPS stream stopped (shown in the app language).
enum RecIssue { notSaving, gpsStopped }

@immutable
class RecorderView {
  const RecorderView({this.state = RecState.idle, this.run, this.analysis, this.last, this.gpsOn = false, this.problem, this.timerOnly = false, this.gpsError,
      this.plan, this.skips = const [], this.free = false, this.steps, this.stepsState = 'off'});
  final RecState state;

  /// The open activity this recorder owns.
  final Run? run;

  /// The live result of the one metric pipeline (TrackAnalysis), fed in order with every stored entry.
  final TrackAnalysis? analysis;

  /// The newest reading the device gave (the dot and its accuracy).
  final Reading? last;
  final bool gpsOn, timerOnly;

  /// Something the person must know: GPS points are not being saved on this phone.
  final RecIssue? problem;

  /// The GPS stream stopped with an error.
  final RecIssue? gpsError;

  /// The interval setup this session follows (null: a free Run / Walk), the active times (ms) of its skips, and
  /// whether the person chose to continue freely after the last phase.
  final IntervalPlan? plan;
  final List<int> skips;
  final bool free;

  /// The steps counted so far, and how they stand: off · denied · unavailable · measured · partial.
  final StepTally? steps;
  final String stepsState;

  IntervalPosition? intervalAt(int nowMs) => plan == null || analysis == null ? null : IntervalClock.at(plan!, skips, analysis!.activeMs(nowMs));

  bool get live => state == RecState.recording || state == RecState.paused || state == RecState.autoPaused;
  bool get open => state != RecState.idle;
  RecorderView copy({RecState? state, Run? run, Reading? last, bool? gpsOn, RecIssue? problem, bool clearProblem = false, bool? timerOnly, RecIssue? gpsError, bool clearGpsError = false,
          List<int>? skips, bool? free, String? stepsState}) =>
      RecorderView(state: state ?? this.state, run: run ?? this.run, analysis: analysis, last: last ?? this.last, gpsOn: gpsOn ?? this.gpsOn,
          problem: clearProblem ? null : problem ?? this.problem, timerOnly: timerOnly ?? this.timerOnly, gpsError: clearGpsError ? null : gpsError ?? this.gpsError,
          plan: plan, skips: skips ?? this.skips, free: free ?? this.free, steps: steps, stepsState: stepsState ?? this.stepsState);
}

/// The one recorder on this phone. It owns the open activity, the GPS stream and the stored route; screens only
/// show it and call it. It outlives every screen (switching screens, apps or locking the phone changes nothing).
class Recorder extends Notifier<RecorderView> {
  static const checkpointEvery = Duration(seconds: 10);
  StreamSubscription<Reading>? _sub;
  StreamSubscription<StepSample>? _stepSub;
  Timer? _checkpoint, _cues;
  var _marks = CueMarks();
  Future<void> _writes = Future.value();
  final _queue = <TrackEntry>[];
  int _seq = 0, _segment = 0;
  TrackEntry? _autoFrom;
  int? _autoCandidate;
  bool _saving = false;
  String? _owner;

  @override
  RecorderView build() {
    _owner = ref.watch(ownerProvider); // another account starts from nothing; this one's open activity is adopted again
    ref.onDispose(_stop);
    return const RecorderView();
  }

  /// Completes when every entry received so far has been written (or has failed and been kept for retry).
  @visibleForTesting
  Future<void> get settled => _writes;

  TrackStore get _store => ref.read(trackStoreProvider);
  SyncEngine get _sync => ref.read(syncProvider);
  LocationSource get _source => ref.read(locationSourceProvider);
  int get _now => ref.read(clockProvider).utcNow().millisecondsSinceEpoch;

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _checkpoint?.cancel();
    _checkpoint = null;
    _stopSteps();
    _cues?.cancel();
    _cues = null;
  }

  void _stopSteps() {
    _stepSub?.cancel();
    _stepSub = null;
  }

  void _emit(RecorderView v) {
    if (ref.mounted) state = v;
  }

  // ------------------------------------------------------------------ storage

  Json _runtime(String state) => {
        'kind': 'activity', 'activityType': this.state.run?.activityType ?? 'run', 'state': state, 'checkpointMs': _now, 'timerOnly': this.state.timerOnly,
        if (this.state.plan != null) 'intervals': {'plan': this.state.plan!.toJson(), 'skips': this.state.skips, 'free': this.state.free},
        'steps': {'state': this.state.stepsState, ...?this.state.steps?.toJson()},
      };

  Future<void> _saveRuntime(String s) async {
    final run = state.run, owner = _owner;
    if (run == null || owner == null) return;
    try {
      await _sync.putLocal(owner, LocalWrite(Kinds.runtime, run.id, _runtime(s)));
    } on LocalSaveFailure {
      _emit(state.copy(problem: _notSaving));
    }
  }

  static const _notSaving = RecIssue.notSaving;

  /// Entries are written one by one, in order. A failed write is kept and retried before the next one, and the
  /// screen says so until it succeeds.
  void _write(TrackEntry e) {
    _queue.add(e);
    _writes = _writes.then((_) => _drain());
  }

  Future<void> _drain() async {
    final run = state.run, owner = _owner;
    if (run == null || owner == null) return;
    while (_queue.isNotEmpty) {
      try {
        await _store.append(owner, run.id, _queue.first);
        _queue.removeAt(0);
      } on LocalSaveFailure {
        if (ref.mounted) _emit(state.copy(problem: _notSaving));
        return;
      }
      if (!ref.mounted) return; // the recorder went away (another account, the app ending) during the write
    }
    if (state.problem != null) _emit(state.copy(clearProblem: true));
  }

  TrackEntry _entry(EntryType type, {int? t, Map<String, dynamic>? meta, Reading? r}) {
    if (type == EntryType.resume || type == EntryType.autoresume) _segment++;
    return TrackEntry(
        seq: _seq++, type: type, segment: _segment, t: t ?? r?.at.millisecondsSinceEpoch ?? _now, meta: meta,
        lat: r?.lat, lon: r?.lon, acc: r?.acc, alt: r?.alt, altAcc: r?.altAcc, speed: r?.speed, speedAcc: r?.speedAcc, heading: r?.heading);
  }

  void _event(EntryType type, {int? t, Map<String, dynamic>? meta}) {
    final e = _entry(type, t: t, meta: meta);
    _write(e);
    state.analysis!.add(e);
  }

  // ------------------------------------------------------------------ GPS

  void _listen() {
    if (_sub != null || state.timerOnly) return;
    _sub = _source.watch(recording: true, type: state.run?.activityType ?? 'run').listen(_onReading, onError: (Object _) {
      _emit(state.copy(gpsError: RecIssue.gpsStopped));
    });
    _emit(state.copy(gpsOn: true, clearGpsError: true));
    _checkpoint ??= Timer.periodic(checkpointEvery, (_) {
      if (state.state == RecState.recording || state.state == RecState.autoPaused) _saveRuntime(state.state == RecState.autoPaused ? 'autopaused' : 'recording');
    });
  }

  void _stopGps() {
    _stop();
    _emit(state.copy(gpsOn: false));
  }

  void _onReading(Reading r) {
    if (!state.live) return;
    final e = _entry(EntryType.fix, r: r);
    _write(e);
    final a = state.analysis!..add(e);
    var next = state.copy(last: r, clearGpsError: true);
    if (state.state == RecState.recording && state.plan == null && ref.read(devicePrefsProvider).autoPause) {
      final at = AutoPauseRule.pauseAt(a, e.t);
      if (at != null) {
        _autoFrom = a.lastAccepted;
        _autoCandidate = null;
        _event(EntryType.autopause, t: at);
        next = next.copy(state: RecState.autoPaused);
        _saveRuntime('autopaused');
      }
    } else if (state.state == RecState.autoPaused && _autoFrom != null) {
      final c = AutoPauseRule.check(_autoFrom!, e, _autoCandidate);
      _autoCandidate = c.candidate;
      if (c.resume) {
        _event(EntryType.autoresume);
        next = next.copy(state: RecState.recording);
        _saveRuntime('recording');
      }
    }
    _emit(next);
  }

  // ------------------------------------------------------------------ steps

  /// How steps stand when a recording starts: off unless the account turned them on; never asked for here.
  Future<String> _stepsAtStart() async {
    if (!ref.read(stepsEnabledProvider)) return 'off';
    return switch (await ref.read(stepSourceProvider).access()) {
      StepAccess.allowed => 'measured',
      StepAccess.unavailable => 'unavailable',
      _ => 'denied',
    };
  }

  /// Readings are received for the whole open recording (pauses included, so a delayed batch is split truthfully);
  /// only recorded time counts them.
  void _listenSteps() {
    final tally = state.steps;
    if (_stepSub != null || tally == null || (state.stepsState != 'measured' && state.stepsState != 'partial')) return;
    _stepSub = ref.read(stepSourceProvider).watch().listen((s) {
      final a = state.analysis;
      if (a == null || !state.open || state.state == RecState.review) return;
      tally.add(s, a.recordingShare);
      _emit(state.copy(stepsState: tally.partial ? 'partial' : null));
    }, onError: (Object _) {
      tally.partial = true;
      _stopSteps();
      _emit(state.copy(stepsState: 'partial'));
    });
  }

  // ------------------------------------------------------------------ cues

  /// Samples the recorder's own active clock every second while recording, for phase prompts, countdowns and updates.
  /// The screen's redraw timer plays no part, so a rebuild or a tab change cannot change what is said.
  void _startCues() {
    _cues ??= Timer.periodic(const Duration(seconds: 1), (_) => _cueTick());
    _cueTick();
  }

  /// One look at the cues now (tests drive the clock themselves).
  @visibleForTesting
  void tickCues() => _cueTick();

  void _cueTick() {
    final run = state.run, a = state.analysis;
    if (run == null || a == null || state.state != RecState.recording) return;
    final unit = ref.read(devicePrefsProvider).distance;
    final now = _now;
    final step = recordingCues(
      marks: _marks, activityId: run.id, plan: state.free ? null : state.plan, skips: state.skips, activeMs: a.activeMs(now),
      distanceMeters: a.measured || a.hasLegacy ? a.distance + a.legacyDistance : null, paceSecondsPerUnit: a.avgMovingPace(unit.meters), unit: unit,
      prefs: ref.read(movePrefsProvider), l: ref.read(appL10nProvider),
    );
    final announcer = ref.read(announcerProvider.notifier);
    if (step.tick) announcer.tick();
    if (step.cue != null) announcer.say(step.cue!);
  }

  // ------------------------------------------------------------------ actions

  /// Starts a new activity, or returns false when one is already open (it is resumed instead, never duplicated).
  Future<bool> start(String type, {required bool timerOnly, IntervalPlan? plan}) async {
    if (_busy) return false;
    _busy = true;
    try {
      return await _start(type, timerOnly: timerOnly, plan: plan);
    } finally {
      _busy = false;
    }
  }

  /// Start and adopt never overlap: a just-started activity is never taken for an interrupted one.
  bool _busy = false;

  Future<bool> _start(String type, {required bool timerOnly, IntervalPlan? plan}) async {
    final owner = _owner;
    if (state.open || owner == null) return false;
    final open = await _openRun();
    if (open != null) {
      await _adopt(open);
      return false;
    }
    final id = SyncEngine.newId();
    final now = ref.read(clockProvider).utcNow();
    final steps = await _stepsAtStart();
    final tally = steps == 'measured' ? StepTally() : null;
    final runtime = {
      'kind': 'activity', 'activityType': type, 'state': 'recording', 'checkpointMs': now.millisecondsSinceEpoch, 'timerOnly': timerOnly,
      if (plan != null) 'intervals': {'plan': plan.toJson(), 'skips': const <int>[], 'free': false},
      'steps': {'state': steps, ...?tally?.toJson()},
    };
    final run = await ref.read(runRepositoryProvider).start(id: id, dayKey: ref.read(todayKeyProvider), startedAtUtc: now, type: type, runtime: runtime);
    _seq = 0;
    _segment = 0;
    _queue.clear();
    state = RecorderView(state: RecState.recording, run: run, analysis: TrackAnalysis(), timerOnly: timerOnly, plan: plan, steps: tally, stepsState: steps);
    _event(EntryType.start, t: now.millisecondsSinceEpoch);
    _listen();
    _listenSteps();
    _marks = CueMarks();
    _startCues();
    if (timerOnly) _checkpoint ??= Timer.periodic(checkpointEvery, (_) => _saveRuntime('recording'));
    return true;
  }

  Future<Run?> _openRun() async {
    for (final r in await _sync.list(_owner!, Kinds.run)) {
      final run = Run(_decode(r.body));
      if (run.isOpen) return run;
    }
    return null;
  }

  static Json _decode(String body) => (jsonDecode(body) as Map).cast<String, dynamic>();

  /// Takes ownership of an open activity found on this phone (after a restart, or from the build before routes).
  /// A recording whose process stopped becomes Interrupted at its last checkpoint: the stretch since is a gap.
  Future<void> adopt(Run run) async {
    if (_busy) return;
    _busy = true;
    try {
      await _adopt(run);
    } finally {
      _busy = false;
    }
  }

  Future<void> _adopt(Run run) async {
    final owner = _owner;
    if (owner == null || state.open) return; // one recorder, one open activity
    final rt = await _sync.get(owner, Kinds.runtime, run.id);
    final runtime = rt == null ? null : _decode(rt.body);
    final analysis = await _store.analyze(owner, run.id);
    final (_, top) = await _store.extent(owner, run.id);
    _seq = top + 1;
    final entries = top < 0 ? const <TrackEntry>[] : await _store.entries(owner, run.id, fromSeq: top).toList();
    _segment = entries.isEmpty ? 0 : entries.last.segment;
    _queue.clear();
    final iv = runtime?['intervals'] as Map?;
    final st = runtime?['steps'] as Map?;
    final counted = st != null && (st['state'] == 'measured' || st['state'] == 'partial');
    final tally = counted ? (StepTally.fromJson(st)..rebase()) : null;
    state = RecorderView(
      state: RecState.interrupted, run: run, analysis: analysis, timerOnly: runtime?['timerOnly'] as bool? ?? false,
      plan: IntervalPlan.fromJson(iv?['plan']), skips: [for (final v in (iv?['skips'] as List? ?? const [])) if (v is num) v.toInt()], free: iv?['free'] == true,
      steps: tally, stepsState: tally == null ? (st?['state'] as String? ?? 'off') : (tally.partial ? 'partial' : 'measured'),
    );
    _marks = CueMarks(); // the first tick after this notes where it stands: nothing due before is said
    final startedMs = DateTime.parse(run.startedAtUtc).millisecondsSinceEpoch;
    if (runtime == null || runtime['kind'] != 'activity') {
      // An open run from the build before routes (or from another phone): its identity, start, clock and measured
      // distance are kept as one "before routes" entry; a new segment starts when it is resumed.
      final old = runtime ?? const <String, dynamic>{};
      final paused = old['isPaused'] as bool? ?? true;
      final anchor = old['runningAnchorUtc'] == null ? null : DateTime.parse(old['runningAnchorUtc'] as String).millisecondsSinceEpoch;
      final activeMs = ((old['accumulatedActiveSeconds'] as int? ?? 0) * 1000) + (paused || anchor == null ? 0 : max(0, _now - anchor));
      final distance = ((old['track'] as Map?)?['distanceMeters'] as num?)?.toDouble() ?? run.distanceMeters ?? 0;
      _event(EntryType.legacy, meta: {'distanceMeters': distance, 'activeMs': activeMs, 'startedAtMs': startedMs});
    } else if (runtime['state'] == 'recording' || runtime['state'] == 'autopaused') {
      final last = max(runtime['checkpointMs'] as int? ?? startedMs, entries.isEmpty ? startedMs : entries.last.t);
      _event(EntryType.interrupt, t: last, meta: {'reason': 'recorder-stopped'});
    } else if (runtime['state'] == 'paused') {
      state = state.copy(state: RecState.paused);
      _listenSteps();
    }
    _cues ??= Timer.periodic(const Duration(seconds: 1), (_) => _cueTick());
    await _saveRuntime(state.state == RecState.paused ? 'paused' : 'interrupted');
  }

  Future<void> pause() async {
    if (state.state != RecState.recording && state.state != RecState.autoPaused) return;
    _event(EntryType.pause);
    _emit(state.copy(state: RecState.paused));
    ref.read(announcerProvider.notifier).cancel();
    await _saveRuntime('paused');
  }

  Future<void> resume() async {
    if (state.state != RecState.paused && state.state != RecState.autoPaused && state.state != RecState.interrupted && state.state != RecState.review) return;
    if (state.state == RecState.review) state.steps?.rebase(); // readings stopped at Finish
    _event(EntryType.resume);
    _emit(state.copy(state: RecState.recording));
    _listen();
    _listenSteps();
    _startCues();
    await _saveRuntime('recording');
  }

  /// Ends the current interval phase now (the person's explicit Skip phase). Never finishes or logs anything.
  Future<void> skipPhase() async {
    final a = state.analysis;
    if (a == null || state.plan == null || state.free || !state.live) return;
    final pos = state.intervalAt(_now);
    if (pos == null || pos.done) return;
    _emit(state.copy(skips: [...state.skips, a.activeMs(_now)]));
    await _saveRuntime(_stateName);
    _cueTick();
  }

  /// After the last phase: keep recording without intervals (nothing more is prompted).
  Future<void> continueFreely() async {
    if (state.plan == null || state.free) return;
    _emit(state.copy(free: true));
    await _saveRuntime(_stateName);
  }

  String get _stateName => switch (state.state) {
        RecState.paused => 'paused',
        RecState.autoPaused => 'autopaused',
        RecState.interrupted => 'interrupted',
        RecState.review => 'review',
        _ => 'recording',
      };

  /// Stops the clock and location and opens the review. The activity stays open until Save or Discard.
  Future<void> finish() async {
    if (!state.open || state.state == RecState.review) return;
    _event(EntryType.finish);
    _stopGps();
    ref.read(announcerProvider.notifier).cancel();
    _emit(state.copy(state: RecState.review));
    await _saveRuntime('review');
    await _writes;
  }

  /// Commits the activity on this phone, then reports success. Throws [LocalSaveFailure] when that was not
  /// possible; everything is kept and the review stays open.
  /// Returns the saved activity's id.
  Future<String> save({required String title, String? notes, double? typedMeters}) async {
    final run = state.run, a = state.analysis;
    if (_saving || run == null || a == null || state.state != RecState.review) throw StateError('Nothing to save');
    _saving = true;
    try {
      await _writes;
      if (_queue.isNotEmpty) throw const LocalSaveFailure('route entries not stored');
      final now = _now;
      final summary = ActivitySummary.of(a, now, typedMeters: typedMeters, steps: state.steps, stepsState: state.stepsState, plan: state.plan, skips: state.skips);
      final finished = DateTime.fromMillisecondsSinceEpoch(a.finishT ?? now, isUtc: true);
      await ref.read(runRepositoryProvider).save(run,
          finishedAtUtc: finished, activeSeconds: summary.activeSeconds, distanceMeters: summary.distanceMeters, title: title, notes: notes, metrics: summary.metrics);
      _stop();
      state = const RecorderView();
      _celebrate(Run(copyJson(run.j)..addAll({'finishedAtUtc': finished.toIso8601String(), 'distanceMeters': summary.distanceMeters, 'metrics': summary.metrics})));
      return run.id;
    } finally {
      _saving = false;
    }
  }

  /// A new personal best, from this save's own success path only (never from a sync, a rebuild or a restart): once.
  void _celebrate(Run saved) {
    final others = ref.read(runsProvider).value;
    if (others == null) return; // history not read yet: nothing is called a best
    final records = newRecords(saved, [for (final r in others) r.value]);
    if (records.isEmpty) return;
    final unit = ref.read(devicePrefsProvider).distance;
    final text = recordMessage(records, unit.distance, l10n: ref.read(appL10nProvider));
    ref.read(recordCueProvider.notifier).set((runId: saved.id, text: text));
    ref.read(announcerProvider.notifier).say(Cue(text, key: 'record:${saved.id}', priority: Cue.record));
  }

  /// Deletes the open activity and its route (asked for by the person, after a confirmation).
  Future<void> discard() async {
    final run = state.run;
    if (run == null) return;
    _stop();
    ref.read(announcerProvider.notifier).cancel();
    await _writes;
    await ref.read(runRepositoryProvider).delete(run);
    state = const RecorderView();
  }

  /// Back from a review to recording.
  Future<void> reopen() => resume();
}

/// The saved summary of an activity, from the one pipeline (docs/RUN_WALK.md › Activity record).
class ActivitySummary {
  const ActivitySummary(this.activeSeconds, this.distanceMeters, this.metrics);
  final int activeSeconds;
  final double? distanceMeters;
  final Json metrics;

  static ActivitySummary of(TrackAnalysis a, int nowMs, {double? typedMeters, StepTally? steps, String stepsState = 'off', IntervalPlan? plan, List<int> skips = const []}) {
    final gps = a.measured || a.hasLegacy ? a.distance + a.legacyDistance : null;
    final source = typedMeters != null ? (gps != null ? 'corrected' : 'manual') : gps != null ? 'gps' : 'none';
    final gl = a.elevationGainLoss();
    double r1(double v) => (v * 10).round() / 10;
    return ActivitySummary((a.activeMs(nowMs) / 1000).round(), typedMeters ?? (gps == null ? null : r1(gps)), {
      'elapsedSeconds': ((a.elapsedMs(nowMs) ?? 0) / 1000).round(),
      'movingSeconds': a.moving.round(),
      'gpsDistanceMeters': gps == null ? null : r1(gps),
      if (gl != null) 'elevationGainMeters': r1(gl.$1),
      if (gl != null) 'elevationLossMeters': r1(gl.$2),
      'distanceSource': source,
      'routeState': !a.measured ? 'none' : (a.gaps > 0 || a.interruptions > 0 || a.hasLegacy ? 'partial' : 'recorded'),
      'pointCount': a.accepted,
      'rejectedCount': a.rejected,
      'gaps': a.gaps,
      'interrupted': a.interruptions,
      if (a.hasLegacy) 'legacyDistanceMeters': r1(a.legacyDistance),
      'stepsState': stepsState,
      if (steps != null && (stepsState == 'measured' || stepsState == 'partial')) 'steps': steps.steps,
      if (plan != null) 'intervals': {'plan': plan.toJson(), 'skips': skips.take(100).toList()},
      if (a.measured) 'efforts': bestEfforts(a),
    });
  }
}

final recorderProvider = NotifierProvider<Recorder, RecorderView>(Recorder.new);

/// The personal best just set by a save, for the Saved screen's coach (in memory only; another sign-in clears it).
typedef RecordCue = ({String runId, String text});

class RecordCueController extends Notifier<RecordCue?> {
  @override
  RecordCue? build() {
    ref.watch(ownerProvider);
    return null;
  }

  void set(RecordCue c) => state = c;
  void played() => state = null;
}

final recordCueProvider = NotifierProvider<RecordCueController, RecordCue?>(RecordCueController.new);
