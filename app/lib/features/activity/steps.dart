/// Steps (docs/RUN_WALK.md › Steps): measured by the phone's own motion hardware, never estimated from GPS distance,
/// pace or a stride length. Two uses: the steps of a recorded Run / Walk, counted over its recording time only, and an
/// optional daily total read from the phone's step history (iOS Core Motion; Android Health Connect).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'move_prefs.dart';

/// Whether this phone can count steps for GoHard.
enum StepAccess { unavailable, notAllowed, blocked, allowed }

/// One reading of a cumulative counter: [count] steps since the counter's own origin (Android: since the phone
/// started; iOS: since updates began), at [t] (UTC epoch ms, the time of the reading, not of its delivery).
typedef StepSample = ({int count, int t});

/// The day's total from the phone's history.
sealed class DailySteps {
  const DailySteps();
}

class DailyOff extends DailySteps {
  const DailyOff();
}

class DailyLoading extends DailySteps {
  const DailyLoading();
}

/// No source on this phone (no motion hardware, or Health Connect missing). [why] says what is needed.
class DailyUnavailable extends DailySteps {
  const DailyUnavailable(this.why);
  final String why;
}

class DailyNotAllowed extends DailySteps {
  const DailyNotAllowed({required this.blocked});
  final bool blocked;
}

class DailyFailed extends DailySteps {
  const DailyFailed();
}

/// A total. [source] names it ("This iPhone", "Health Connect"); [recorded] is false when the source holds no step
/// data for the day at all (nothing on the phone records steps), which is not a genuine zero.
class DailyValue extends DailySteps {
  const DailyValue(this.steps, {required this.source, required this.at, required this.recorded});
  final int steps;
  final String source;
  final DateTime at;
  final bool recorded;
}

/// The phone's step hardware and history. Channel `gohard/steps` (Android MainActivity.kt, iOS AppDelegate.swift).
abstract class StepSource {
  bool get simulated;
  Future<StepAccess> access();

  /// Asks for Motion & Fitness (iOS) or Physical activity (Android) access.
  Future<StepAccess> request();

  /// Live readings while listened to. Errors when the sensor stops.
  Stream<StepSample> watch();

  /// The daily source's own access (Android asks Health Connect separately; iOS uses Motion & Fitness).
  Future<StepAccess> dailyAccess();
  Future<StepAccess> dailyRequest();

  /// Steps from [from] to [to] by the daily source, or null when it could not be read.
  Future<({int steps, bool recorded})?> daily(DateTime from, DateTime to);
  String get dailySource;

  /// The vibration for an interval change, where the platform allows it (also with the screen locked on Android).
  Future<void> vibrate();
  Future<void> openSettings();
}

class DeviceStepSource implements StepSource {
  const DeviceStepSource();
  static const _ch = MethodChannel('gohard/steps');
  static const _live = EventChannel('gohard/steps/live');

  @override
  bool get simulated => false;

  static StepAccess _parse(Object? v) => StepAccess.values.asNameMap()[v] ?? StepAccess.unavailable;

  Future<StepAccess> _call(String m) async {
    try {
      return _parse(await _ch.invokeMethod<String>(m));
    } on Object {
      return StepAccess.unavailable; // no channel (tests, an older native build): said as unavailable, never as zero
    }
  }

  @override
  Future<StepAccess> access() => _call('access');
  @override
  Future<StepAccess> request() => _call('request');
  @override
  Future<StepAccess> dailyAccess() => _call('dailyAccess');
  @override
  Future<StepAccess> dailyRequest() => _call('dailyRequest');

  @override
  Stream<StepSample> watch() => _live.receiveBroadcastStream().map((e) {
        final m = (e as Map).cast<String, Object?>();
        return (count: (m['c'] as num).toInt(), t: (m['t'] as num).toInt());
      });

  @override
  Future<({int steps, bool recorded})?> daily(DateTime from, DateTime to) async {
    try {
      final m = (await _ch.invokeMethod<Map>('daily', {'from': from.millisecondsSinceEpoch, 'to': to.millisecondsSinceEpoch}))?.cast<String, Object?>();
      if (m == null) return null;
      return (steps: (m['steps'] as num).toInt(), recorded: m['recorded'] as bool? ?? true);
    } on Object {
      return null;
    }
  }

  @override
  String get dailySource => defaultTargetPlatformIsIOS ? 'This iPhone' : 'Health Connect';

  @override
  Future<void> vibrate() async {
    try {
      await _ch.invokeMethod<void>('vibrate');
    } on Object {
      // No vibration on this phone.
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _ch.invokeMethod<void>('openSettings');
    } on Object {
      // Nothing to open; the screen keeps saying what is needed.
    }
  }
}

bool get defaultTargetPlatformIsIOS => defaultTargetPlatform == TargetPlatform.iOS;

/// Simulated steps for tests and the labelled emulator journey (`--dart-define=GOHARD_SIM_STEPS=true`): about 2.6
/// steps a second while listened to, readings every [interval]. Never used by the app on its own.
class SimulatedStepSource implements StepSource {
  SimulatedStepSource({this.state = StepAccess.notAllowed, this.interval = const Duration(seconds: 2), this.dailyTotal = 3480});
  StepAccess state;
  final Duration interval;
  int dailyTotal;
  int _count = 41000; // a counter that started long before the activity
  final _clock = Stopwatch();

  @override
  bool get simulated => true;
  @override
  Future<StepAccess> access() async => state;
  @override
  Future<StepAccess> request() async => state == StepAccess.notAllowed ? state = StepAccess.allowed : state;
  @override
  Future<StepAccess> dailyAccess() async => state;
  @override
  Future<StepAccess> dailyRequest() => request();
  @override
  String get dailySource => 'This phone (simulated)';
  @override
  Future<({int steps, bool recorded})?> daily(DateTime from, DateTime to) async => (steps: dailyTotal, recorded: true);
  @override
  Future<void> vibrate() async {}
  @override
  Future<void> openSettings() async {}

  @override
  Stream<StepSample> watch() {
    late StreamController<StepSample> c;
    Timer? timer;
    var last = 0;
    c = StreamController<StepSample>(onListen: () {
      _clock.start();
      last = _clock.elapsedMilliseconds;
      timer = Timer.periodic(interval, (_) {
        final now = _clock.elapsedMilliseconds;
        _count += ((now - last) * 2.6 / 1000).round();
        last = now;
        c.add((count: _count, t: DateTime.now().toUtc().millisecondsSinceEpoch));
      });
    }, onCancel: () => timer?.cancel());
    return c.stream;
  }
}

final stepSourceProvider = Provider<StepSource>((_) => const bool.fromEnvironment('GOHARD_SIM_STEPS') ? SimulatedStepSource(state: StepAccess.allowed) : const DeviceStepSource());

/// The steps of one recording, from a cumulative counter's readings (docs/RUN_WALK.md › Steps › During Run / Walk).
/// A reading's increase since the previous one is counted by how much of that stretch was recorded: wholly recorded,
/// all of it; wholly paused or interrupted, none. A stretch across a pause boundary (a batch delivered late) is split
/// by time when it is short, and otherwise left out and the count marked partial. A counter that went backwards (the
/// phone restarted) starts a new baseline. Nothing is ever estimated: no reading, no step.
class StepTally {
  StepTally({this.steps = 0, this.partial = false, this.readings = 0, this.lastCount, this.lastT});
  int steps, readings;
  bool partial;
  int? lastCount, lastT;

  /// The longest stretch split across a pause boundary (a sensor batch); longer ones are not guessed at.
  static const maxSplitMs = 10000;

  /// Steps left out of such a longer stretch before the count is called partial. Readings arrive with every few steps
  /// while walking, so a long stretch normally means standing still around Pause or Resume (a step or two).
  // ponytail: calibration knob from the sensor's behaviour, not measured on many phones; tune from device checks.
  static const ignorableSteps = 10;

  void add(StepSample s, double Function(int from, int to) recorded) {
    readings++;
    final c0 = lastCount, t0 = lastT;
    lastCount = s.count;
    lastT = t0 == null ? s.t : max(t0, s.t);
    if (c0 == null || t0 == null) return; // the first reading is the baseline
    if (s.count < c0) {
      if (recorded(t0, max(t0, s.t)) > 0) partial = true; // the counter restarted: steps since the last reading are unknown
      return;
    }
    final d = s.count - c0;
    if (d == 0) return;
    final t = max(t0, s.t), f = recorded(t0, t);
    if (f >= 0.999) {
      steps += d;
    } else if (f > 0.001) {
      if (t - t0 <= maxSplitMs) {
        steps += (d * f).round();
      } else if (d > ignorableSteps) {
        partial = true;
      }
    }
  }

  /// The next reading is a new baseline (after the readings stopped: a restart, or recording reopened after Finish).
  void rebase() {
    lastCount = null;
    lastT = null;
  }

  Map<String, dynamic> toJson() => {'n': steps, 'p': partial, 'k': readings, 'c': ?lastCount, 't': ?lastT};

  static StepTally fromJson(Object? j) {
    if (j is! Map) return StepTally();
    int? v(String k) => (j[k] as num?)?.toInt();
    return StepTally(steps: max(0, v('n') ?? 0), partial: j['p'] == true, readings: v('k') ?? 0, lastCount: v('c'), lastT: v('t'));
  }
}

/// How an activity's steps stand: `off` (not turned on), `denied`, `unavailable`, `measured`, `partial`.
/// Activities saved before steps existed have none of these: their steps are unknown, never zero.
String stepsText(Map<String, dynamic> metrics) => switch (metrics['stepsState']) {
      'measured' => _n(metrics['steps']),
      'partial' => '${_n(metrics['steps'])} (part of the time)',
      'denied' => 'Not counted: motion access is off',
      'unavailable' => 'Not counted: no step sensor',
      'off' => 'Not counted',
      _ => 'Not recorded',
    };

String _n(Object? v) => formatSteps((v as num?)?.toInt() ?? 0);

String formatSteps(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Today's steps for the signed-in account, when it turned them on. Read when watched and when the row showing it asks
/// ([refresh]: on the app's return to the foreground and every few minutes while shown). Local calendar day from
/// midnight, re-derived on every read, so midnight, a time zone change or a restart start the right day. Never stored
/// or sent anywhere.
class DailyStepsController extends Notifier<DailySteps> {
  @override
  DailySteps build() {
    final on = ref.watch(stepsEnabledProvider);
    ref.watch(todayKeyProvider);
    if (!on) return const DailyOff();
    Future.microtask(refresh);
    return const DailyLoading();
  }

  Future<void> refresh() async {
    if (!ref.read(stepsEnabledProvider)) return;
    final src = ref.read(stepSourceProvider);
    final access = await src.dailyAccess();
    if (!ref.mounted) return;
    switch (access) {
      case StepAccess.unavailable:
        state = DailyUnavailable(defaultTargetPlatformIsIOS ? 'This iPhone cannot count steps.' : 'Daily steps on Android come from Health Connect, which is not available on this phone.');
        return;
      case StepAccess.notAllowed || StepAccess.blocked:
        state = DailyNotAllowed(blocked: access == StepAccess.blocked);
        return;
      case StepAccess.allowed:
    }
    final now = ref.read(clockProvider).utcNow().toLocal();
    final midnight = DateTime(now.year, now.month, now.day);
    final r = await src.daily(midnight, now);
    if (!ref.mounted) return;
    state = r == null ? const DailyFailed() : DailyValue(r.steps, source: src.dailySource, at: now, recorded: r.recorded);
  }
}

/// Disposed with the row that shows it, so nothing is read or polled while it is not on screen.
final dailyStepsProvider = NotifierProvider.autoDispose<DailyStepsController, DailySteps>(DailyStepsController.new);
