import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/device_prefs.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import 'location_source.dart';
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

@immutable
class RecorderView {
  const RecorderView({this.state = RecState.idle, this.run, this.analysis, this.last, this.gpsOn = false, this.problem, this.timerOnly = false, this.gpsError});
  final RecState state;

  /// The open activity this recorder owns.
  final Run? run;

  /// The live result of the one metric pipeline (TrackAnalysis), fed in order with every stored entry.
  final TrackAnalysis? analysis;

  /// The newest reading the device gave (the dot and its accuracy).
  final Reading? last;
  final bool gpsOn, timerOnly;

  /// Something the person must know: GPS points are not being saved on this phone.
  final String? problem;

  /// The GPS stream stopped with an error.
  final String? gpsError;

  bool get live => state == RecState.recording || state == RecState.paused || state == RecState.autoPaused;
  bool get open => state != RecState.idle;
  RecorderView copy({RecState? state, Run? run, Reading? last, bool? gpsOn, String? problem, bool clearProblem = false, bool? timerOnly, String? gpsError, bool clearGpsError = false}) =>
      RecorderView(state: state ?? this.state, run: run ?? this.run, analysis: analysis, last: last ?? this.last, gpsOn: gpsOn ?? this.gpsOn,
          problem: clearProblem ? null : problem ?? this.problem, timerOnly: timerOnly ?? this.timerOnly, gpsError: clearGpsError ? null : gpsError ?? this.gpsError);
}

/// The one recorder on this phone. It owns the open activity, the GPS stream and the stored route; screens only
/// show it and call it. It outlives every screen (switching screens, apps or locking the phone changes nothing).
class Recorder extends Notifier<RecorderView> {
  static const checkpointEvery = Duration(seconds: 10);
  StreamSubscription<Reading>? _sub;
  Timer? _checkpoint;
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
  }

  void _emit(RecorderView v) {
    if (ref.mounted) state = v;
  }

  // ------------------------------------------------------------------ storage

  Json _runtime(String state) => {
        'kind': 'activity', 'activityType': this.state.run?.activityType ?? 'run', 'state': state, 'checkpointMs': _now, 'timerOnly': this.state.timerOnly,
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

  static const _notSaving = 'This phone is not saving the recording right now. Keep GoHard open; it keeps trying.';

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
        _emit(state.copy(problem: _notSaving));
        return;
      }
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
      _emit(state.copy(gpsError: 'GPS stopped giving positions. The timer goes on; distance resumes when GPS does.'));
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
    if (state.state == RecState.recording && ref.read(devicePrefsProvider).autoPause) {
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

  // ------------------------------------------------------------------ actions

  /// Starts a new activity, or returns false when one is already open (it is resumed instead, never duplicated).
  Future<bool> start(String type, {required bool timerOnly}) async {
    if (_busy) return false;
    _busy = true;
    try {
      return await _start(type, timerOnly: timerOnly);
    } finally {
      _busy = false;
    }
  }

  /// Start and adopt never overlap: a just-started activity is never taken for an interrupted one.
  bool _busy = false;

  Future<bool> _start(String type, {required bool timerOnly}) async {
    final owner = _owner;
    if (state.open || owner == null) return false;
    final open = await _openRun();
    if (open != null) {
      await _adopt(open);
      return false;
    }
    final id = SyncEngine.newId();
    final now = ref.read(clockProvider).utcNow();
    final runtime = {'kind': 'activity', 'activityType': type, 'state': 'recording', 'checkpointMs': now.millisecondsSinceEpoch, 'timerOnly': timerOnly};
    final run = await ref.read(runRepositoryProvider).start(id: id, dayKey: ref.read(todayKeyProvider), startedAtUtc: now, type: type, runtime: runtime);
    _seq = 0;
    _segment = 0;
    _queue.clear();
    state = RecorderView(state: RecState.recording, run: run, analysis: TrackAnalysis(), timerOnly: timerOnly);
    _event(EntryType.start, t: now.millisecondsSinceEpoch);
    _listen();
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
    state = RecorderView(state: RecState.interrupted, run: run, analysis: analysis, timerOnly: runtime?['timerOnly'] as bool? ?? false);
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
    }
    await _saveRuntime(state.state == RecState.paused ? 'paused' : 'interrupted');
  }

  Future<void> pause() async {
    if (state.state != RecState.recording && state.state != RecState.autoPaused) return;
    _event(EntryType.pause);
    _emit(state.copy(state: RecState.paused));
    await _saveRuntime('paused');
  }

  Future<void> resume() async {
    if (state.state != RecState.paused && state.state != RecState.autoPaused && state.state != RecState.interrupted && state.state != RecState.review) return;
    _event(EntryType.resume);
    _emit(state.copy(state: RecState.recording));
    _listen();
    await _saveRuntime('recording');
  }

  /// Stops the clock and location and opens the review. The activity stays open until Save or Discard.
  Future<void> finish() async {
    if (!state.open || state.state == RecState.review) return;
    _event(EntryType.finish);
    _stopGps();
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
      final summary = ActivitySummary.of(a, now, typedMeters: typedMeters);
      await ref.read(runRepositoryProvider).save(run,
          finishedAtUtc: DateTime.fromMillisecondsSinceEpoch(a.finishT ?? now, isUtc: true), activeSeconds: summary.activeSeconds,
          distanceMeters: summary.distanceMeters, title: title, notes: notes, metrics: summary.metrics);
      _stop();
      state = const RecorderView();
      return run.id;
    } finally {
      _saving = false;
    }
  }

  /// Deletes the open activity and its route (asked for by the person, after a confirmation).
  Future<void> discard() async {
    final run = state.run;
    if (run == null) return;
    _stop();
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

  static ActivitySummary of(TrackAnalysis a, int nowMs, {double? typedMeters}) {
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
    });
  }
}

final recorderProvider = NotifierProvider<Recorder, RecorderView>(Recorder.new);
