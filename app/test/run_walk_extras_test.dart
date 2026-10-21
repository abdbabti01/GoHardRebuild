import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/activity/announcer.dart';
import 'package:gohard_rebuild/features/activity/intervals.dart';
import 'package:gohard_rebuild/features/activity/location_source.dart';
import 'package:gohard_rebuild/features/activity/move_prefs.dart';
import 'package:gohard_rebuild/features/activity/recorder.dart';
import 'package:gohard_rebuild/features/activity/steps.dart';

import 'support.dart';

/// Steps, intervals and spoken cues through the real recorder, over a real database with a process restart
/// (docs/RUN_WALK.md › Steps, › Intervals, › Voice and alerts). GPS and step readings are SIMULATED and pushed by the
/// test; speech goes to a fake voice. Nothing here proves a real phone's sensor accuracy or speech.
class _Gps implements LocationSource {
  final _c = StreamController<Reading>.broadcast();
  @override
  bool get simulated => true;
  @override
  Future<GpsAccess> access() async => GpsAccess.allowed;
  @override
  Future<GpsAccess> request() async => GpsAccess.allowed;
  @override
  Future<void> openSettings({required bool app}) async {}
  @override
  Stream<Reading> watch({required bool recording, String type = 'run'}) => _c.stream;

  double _m = 0;
  void walk(FakeClock clock, int seconds, {double speed = 2.5}) {
    for (var i = 0; i < seconds; i++) {
      clock.advance(const Duration(seconds: 1));
      _m += speed;
      _c.add(Reading(lat: 46.8 + _m / 111320, lon: -71.2, acc: 5, at: clock.now, speed: speed, speedAcc: 0.3));
    }
  }
}

class _Steps implements StepSource {
  final c = StreamController<StepSample>.broadcast();
  StepAccess state = StepAccess.allowed;
  @override
  bool get simulated => true;
  @override
  Future<StepAccess> access() async => state;
  @override
  Future<StepAccess> request() async => state;
  @override
  Future<StepAccess> dailyAccess() async => state;
  @override
  Future<StepAccess> dailyRequest() async => state;
  @override
  Future<({int steps, bool recorded})?> daily(DateTime from, DateTime to) async => (steps: 0, recorded: false);
  @override
  String get dailySource => 'test';
  @override
  Stream<StepSample> watch() => c.stream;
  @override
  Future<void> vibrate() async {}
  @override
  Future<void> openSettings() async {}
  void read(int count, DateTime at) => c.add((count: count, t: at.millisecondsSinceEpoch));
}

class _Voice implements VoiceOut {
  final said = <String>[];
  int stops = 0;
  Completer<void>? hold;
  @override
  Future<void> speak(String text, {VoiceOption? voice, required double pitch}) async {
    said.add(text);
    await hold?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    final h = hold;
    hold = null;
    if (h != null && !h.isCompleted) h.complete();
  }

  @override
  // An installed offline English voice: speech is only ever in the app language (docs/RUN_WALK.md › Voice and alerts).
  Future<List<VoiceOption>> voices() async => const [(name: 'en-test', locale: 'en-US')];
}

class _Day extends TodayKey {
  @override
  String build() => '2026-10-09';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // haptics go through the platform channel
  late Harness h;
  late _Gps gps;
  late _Steps steps;
  late _Voice voice;
  late MovePrefsStore prefs;
  setUp(() {
    h = Harness(now: DateTime.utc(2026, 10, 9, 11, 20));
    gps = _Gps();
    steps = _Steps();
    voice = _Voice();
    prefs = MovePrefsStore(MemorySecretStore());
  });
  tearDown(() => h.dispose());

  ProviderContainer app() {
    final c = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(h.db), sessionsProvider.overrideWithValue(h.sessions), transportProvider.overrideWithValue(h.server),
      clockProvider.overrideWithValue(h.clock), locationSourceProvider.overrideWithValue(gps), todayKeyProvider.overrideWith(_Day.new),
      stepSourceProvider.overrideWithValue(steps), voiceOutProvider.overrideWithValue(voice), movePrefsStoreProvider.overrideWithValue(prefs),
    ], retry: (_, _) => null);
    c.listen(recorderProvider, (_, _) {});
    c.listen(announcerProvider, (_, _) {});
    return c;
  }

  Future<void> settle(ProviderContainer c) async {
    await Future<void>.delayed(Duration.zero);
    await c.read(recorderProvider.notifier).settled;
  }

  test('an interval run with steps: phases from the active clock, pause, skip, a restart without replay, one saved activity', () async {
    final owner = await h.signIn('one');
    const plan = IntervalPlan(run: 60, walk: 30, reps: 2);
    prefs.value = MovePrefs(voice: true, updates: UpdateMode.off, steps: {owner});
    var c = app();
    final rec = c.read(recorderProvider.notifier);
    expect(await rec.start('run', timerOnly: false, plan: plan), isTrue);
    expect(c.read(recorderProvider).stepsState, 'measured');
    steps.read(5000, h.clock.now); // the counter's baseline
    gps.walk(h.clock, 30);
    steps.read(5060, h.clock.now);
    rec.tickCues();
    gps.walk(h.clock, 31);
    steps.read(5100, h.clock.now); // 61 s: still recording
    await settle(c);
    rec.tickCues();
    rec.tickCues(); // the same moment again (a rebuild, a GPS batch): nothing new
    await Future<void>.delayed(Duration.zero);
    expect(voice.said, ['Walk and recover for 30 seconds.']);

    await rec.pause();
    h.clock.advance(const Duration(seconds: 20));
    steps.read(5160, h.clock.now); // walked while paused: not this run's
    expect(c.read(recorderProvider).intervalAt(h.clock.now.millisecondsSinceEpoch)!.phase!.kind, PhaseKind.walk, reason: 'a pause freezes the phase');
    await rec.resume();
    h.clock.advance(const Duration(seconds: 5));
    steps.read(5170, h.clock.now);
    await Future<void>.delayed(Duration.zero); // readings arrive asynchronously, as from the platform
    expect(c.read(recorderProvider).steps!.steps, 100 + 10);

    await rec.skipPhase();
    await Future<void>.delayed(Duration.zero);
    expect(voice.said.last, 'Final round. Run for 1 minute.');
    final skips = c.read(recorderProvider).skips;
    expect(skips, hasLength(1));
    await settle(c);

    // The process dies; the phase, the skip and the steps are on disk. Nothing due meanwhile is said on resume.
    final said = voice.said.length;
    c.dispose();
    await h.restart();
    h.clock.advance(const Duration(minutes: 3));
    c = app();
    final open = Run((await h.bodies(owner, Kinds.run)).single);
    await c.read(recorderProvider.notifier).adopt(open);
    var v = c.read(recorderProvider);
    expect(v.state, RecState.interrupted);
    expect((v.plan, v.steps!.steps), (plan, 110));
    expect(v.skips, skips);
    await c.read(recorderProvider.notifier).resume();
    c.read(recorderProvider.notifier).tickCues();
    await Future<void>.delayed(Duration.zero);
    expect(voice.said.length, said, reason: 'no backlog of old prompts after a restart');
    v = c.read(recorderProvider);
    final pos = v.intervalAt(h.clock.now.millisecondsSinceEpoch)!;
    expect((pos.phase!.kind, pos.phase!.round), (PhaseKind.run, 2), reason: 'the interrupted stretch is not active time, so the phase did not move');
    steps.read(170, h.clock.now); // the phone restarted: a new counter, a new baseline
    gps.walk(h.clock, 10);
    steps.read(190, h.clock.now);
    await settle(c);

    await c.read(recorderProvider.notifier).finish();
    expect(voice.stops, greaterThan(0), reason: 'finish cancels speech');
    await c.read(recorderProvider.notifier).save(title: 'Intervals');
    final saved = Run((await h.bodies(owner, Kinds.run)).single);
    expect(saved.activityType, 'run', reason: 'one activity, of the type chosen; never changed by its walking phases');
    final m = saved.metrics;
    expect((m['steps'], m['stepsState']), (130, 'measured'));
    expect(IntervalPlan.fromJson((m['intervals'] as Map)['plan']), plan);
    expect((m['intervals'] as Map)['skips'], skips);
    expect(m['efforts'], isA<Map<String, dynamic>>());
    c.dispose();
  });

  test('steps turned on but not allowed: the run records normally and says so; off means not counted', () async {
    final owner = await h.signIn('one');
    prefs.value = MovePrefs(steps: {owner});
    steps.state = StepAccess.blocked;
    final c = app();
    await c.read(recorderProvider.notifier).start('walk', timerOnly: false);
    gps.walk(h.clock, 20);
    await settle(c);
    expect(c.read(recorderProvider).stepsState, 'denied');
    await c.read(recorderProvider.notifier).finish();
    await c.read(recorderProvider.notifier).save(title: 'Walk');
    final m = Run((await h.bodies(owner, Kinds.run)).single).metrics;
    expect((m['stepsState'], m.containsKey('steps')), ('denied', false));
    expect(stepsText(m), 'Not counted: motion access is off');
    c.dispose();
  });

  group('announcer', () {
    late ProviderContainer c;
    setUp(() async {
      await h.signIn('one');
      prefs.value = const MovePrefs(voice: true);
      c = app();
      await Future<void>.delayed(Duration.zero); // the installed voices are read ahead
    });
    tearDown(() => c.dispose());

    test('a phase prompt cuts a routine update; an update during a phase prompt waits; each key once', () async {
      final a = c.read(announcerProvider.notifier);
      voice.hold = Completer();
      a.say(const Cue('2 km completed.', key: 'd2', priority: Cue.update));
      a.say(const Cue('Run for 1 minute.', key: 'p1', priority: Cue.phase));
      expect(voice.stops, 1, reason: 'the update is cut for the phase prompt');
      voice.hold = Completer();
      a.say(const Cue('3 km completed.', key: 'd3', priority: Cue.update));
      a.say(const Cue('Run for 1 minute.', key: 'p1', priority: Cue.phase));
      expect(voice.said, ['2 km completed.', 'Run for 1 minute.']);
      voice.hold!.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(voice.said, ['2 km completed.', 'Run for 1 minute.', '3 km completed.']);
    });

    test('a queued update goes stale and is dropped; cancel drops the queue and stops speech', () async {
      final a = c.read(announcerProvider.notifier);
      voice.hold = Completer();
      a.say(const Cue('Run for 1 minute.', key: 'p1', priority: Cue.phase));
      a.say(const Cue('1 km completed.', key: 'd1', priority: Cue.update));
      h.clock.advance(const Duration(seconds: 20));
      voice.hold!.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(voice.said, ['Run for 1 minute.'], reason: 'said 20 s late it would be wrong');
      voice.hold = Completer();
      a.say(const Cue('Walk and recover for 1 minute.', key: 'p2', priority: Cue.phase));
      a.say(const Cue('2 km completed.', key: 'd2', priority: Cue.update));
      a.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(voice.said.last, 'Walk and recover for 1 minute.');
      expect(c.read(announcerProvider), isNull);
    });

    test('voice off: the words are shown, nothing is spoken; a record is said once', () async {
      prefs.value = const MovePrefs();
      c.dispose();
      c = app();
      final a = c.read(announcerProvider.notifier);
      a.say(const Cue('Your longest walk so far, 4.00 km.', key: 'record:w2', priority: Cue.record));
      expect(c.read(announcerProvider)?.text, 'Your longest walk so far, 4.00 km.');
      a.say(const Cue('Your longest walk so far, 4.00 km.', key: 'record:w2', priority: Cue.record));
      expect(voice.said, isEmpty);
    });
  });
}
