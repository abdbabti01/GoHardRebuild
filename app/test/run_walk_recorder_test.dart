import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/compatibility.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/activity/location_source.dart';
import 'package:gohard_rebuild/features/activity/recorder.dart';
import 'package:gohard_rebuild/features/activity/track_math.dart';

import 'support.dart';

/// The recorder over a real on-disk database, process restarts and the fake account (docs/RUN_WALK.md).
/// GPS is SIMULATED: readings are pushed by the test; no device location is involved.
class _Gps implements LocationSource {
  final _c = StreamController<Reading>.broadcast();
  var watchers = 0;
  bool lastRecording = false;
  @override
  bool get simulated => true;
  @override
  Future<GpsAccess> access() async => GpsAccess.allowed;
  @override
  Future<GpsAccess> request() async => GpsAccess.allowed;
  @override
  Future<void> openSettings({required bool app}) async {}
  @override
  Stream<Reading> watch({required bool recording, String type = 'run'}) {
    watchers++;
    lastRecording = recording;
    return _c.stream;
  }

  bool get listening => _c.hasListener;

  /// [seconds] readings one second apart, walking north at [speed] m/s from [fromMeters].
  void walk(FakeClock clock, int seconds, {double speed = 1.4, double fromMeters = 0, double acc = 5}) {
    for (var i = 1; i <= seconds; i++) {
      clock.advance(const Duration(seconds: 1));
      _c.add(Reading(lat: 46.8 + (fromMeters + i * speed) / 111320, lon: -71.2, acc: acc, at: clock.now, speed: speed, speedAcc: 0.3));
    }
  }
}

class _Day extends TodayKey {
  @override
  String build() => '2026-10-09';
}

const _caps = {'contractVersion': 1, 'minimumClientContract': 1, 'capabilities': ['runs.activity-type', 'runs.routes', 'water.entries']};

void main() {
  late Harness h;
  late _Gps gps;
  setUp(() {
    h = Harness(now: DateTime.utc(2026, 10, 9, 11, 20));
    gps = _Gps();
  });
  tearDown(() => h.dispose());

  ProviderContainer app() {
    final c = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(h.db), sessionsProvider.overrideWithValue(h.sessions), transportProvider.overrideWithValue(h.server),
      clockProvider.overrideWithValue(h.clock), locationSourceProvider.overrideWithValue(gps), todayKeyProvider.overrideWith(_Day.new),
    ], retry: (_, _) => null);
    c.listen(recorderProvider, (_, _) {}); // keeps the recorder alive like the app does
    return c;
  }

  Future<void> settle(ProviderContainer c) async {
    await Future<void>.delayed(Duration.zero);
    await c.read(recorderProvider.notifier).settled;
  }

  Future<List<Json>> runs(String owner) => h.bodies(owner, Kinds.run);

  test('record, process death, Interrupted, resume, offline save, then sync without duplicates (a Walk waits for a server that knows walks)', () async {
    final owner = await h.signIn('one');
    var c = app();
    final rec = c.read(recorderProvider.notifier);
    expect(await rec.start('walk', timerOnly: false), isTrue);
    expect(await rec.start('run', timerOnly: false), isFalse, reason: 'one open activity: a second Start is refused');
    expect((gps.listening, gps.lastRecording), (true, true), reason: 'the recording stream (foreground service on Android)');
    gps.walk(h.clock, 120);
    await settle(c);
    final before = c.read(recorderProvider).analysis!;
    expect(before.distance, closeTo(168, 168 * 0.08));
    final runId = c.read(recorderProvider).run!.id;
    expect((await runs(owner)).single['activityType'], 'walk');

    // The process dies: nothing in memory survives; the route and the open activity are on disk.
    c.dispose();
    expect(gps.listening, isFalse, reason: 'no location after the recorder is gone');
    await h.restart();
    h.clock.advance(const Duration(minutes: 5)); // five minutes pass with nothing recording
    c = app();
    final open = Run((await runs(owner)).single);
    await c.read(recorderProvider.notifier).adopt(open);
    var view = c.read(recorderProvider);
    expect(view.state, RecState.interrupted);
    expect(view.analysis!.distance, before.distance, reason: 'the stored route gives the same distance after a restart');
    expect(view.analysis!.activeMs(h.clock.now.millisecondsSinceEpoch), before.activeMs(h.clock.now.millisecondsSinceEpoch - 300000),
        reason: 'the five minutes after the last checkpoint are a gap, not active time');
    expect(gps.listening, isFalse, reason: 'an interrupted activity does not start location by itself');

    // Resume: a new segment, nothing joined across the gap.
    await c.read(recorderProvider.notifier).resume();
    gps.walk(h.clock, 60, fromMeters: 900);
    await settle(c);
    await c.read(recorderProvider.notifier).pause();
    gps.walk(h.clock, 30, fromMeters: 1100); // moving while paused is not counted
    await settle(c);
    await c.read(recorderProvider.notifier).finish();
    expect(gps.listening, isFalse, reason: 'finishing stops location');
    view = c.read(recorderProvider);
    expect(view.analysis!.segments, hasLength(2));
    expect(view.analysis!.distance, closeTo(168 + 84, 252 * 0.1), reason: 'no straight line across the 5 minutes or the pause');

    // Saved offline: committed on this phone first.
    h.server.offline = true;
    final id = await c.read(recorderProvider.notifier).save(title: 'Morning walk', notes: 'Plains');
    expect(id, runId);
    expect(c.read(recorderProvider).state, RecState.idle);
    final saved = Run((await runs(owner)).single);
    expect((saved.isOpen, saved.isWalk, saved.title, saved.distanceSource, saved.metrics['routeState']), (false, true, 'Morning walk', 'gps', 'partial'));
    expect(saved.movingSeconds, greaterThan(150));
    expect(saved.activeDurationSeconds, lessThan(220), reason: 'the interruption and the pause are not active time');
    expect(saved.elapsedSeconds, greaterThan(500), reason: 'elapsed includes them');
    expect(await h.sync.get(owner, Kinds.runtime, runId), isNull);
    expect((await h.sync.get(owner, Kinds.route, runId))!.syncState, 'pending');
    final kinds = [for (final cmd in await h.sync.commands(owner)) cmd.kind];
    expect(kinds, ['run.start', 'run.finish', 'route.chunk', 'route.complete']);

    // Online again, but the server has not said it knows walks and routes: nothing is sent as a plain run.
    h.server.offline = false;
    await c.read(syncProvider).flush();
    expect(h.server.callsTo('/runs'), isEmpty);
    // The held walk asked the server what it supports; that answer (no walks yet) arrives first.
    await c.read(compatibilityProvider.notifier).check();
    expect(h.server.callsTo('/runs'), isEmpty, reason: 'the answer did not include walks');

    // It says so: everything goes, once, in order.
    h.server.capabilities = _caps;
    await c.read(compatibilityProvider.notifier).check();
    await c.read(syncProvider).flush();
    expect([for (final x in h.server.callsTo('/runs')) x.path], ['/runs', '/runs/$runId/finish', '/runs/$runId/route/chunks/0', '/runs/$runId/route/complete']);
    final chunk = jsonDecode(h.server.callsTo('/route/chunks/0').single.body) as Json;
    expect((chunk['entries'] as List).length, (await c.read(trackStoreProvider).all(owner, runId)).length);
    expect((await h.sync.get(owner, Kinds.route, runId))!.syncState, 'synced', reason: 'route synced is its own state');
    expect((await h.sync.commands(owner)), isEmpty);
    final acked = (await h.db.select(h.db.commands).get()).firstWhere((x) => x.kind == 'route.chunk');
    expect((acked.payload, acked.outbound), ('{}', '{}'), reason: 'an acknowledged chunk keeps no copy of the route');
    expect(await c.read(trackStoreProvider).all(owner, runId), isNotEmpty, reason: 'the phone keeps its route');
    c.dispose();
  });

  test('a lost chunk response is retried with the same operation and bytes, and completes once', () async {
    final owner = await h.signIn('one');
    h.server.capabilities = _caps;
    final c = app();
    await c.read(compatibilityProvider.notifier).check();
    await c.read(recorderProvider.notifier).start('run', timerOnly: false);
    gps.walk(h.clock, 40, speed: 3);
    await settle(c);
    await c.read(recorderProvider.notifier).finish();
    var lost = false;
    c.read(syncProvider).beforeDispatch = (cmd) async {
      if (cmd.kind == 'route.chunk' && !lost) h.server.loseNextResponse = lost = true;
    };
    await c.read(recorderProvider.notifier).save(title: 'Morning run');
    await c.read(syncProvider).flush();
    await c.read(syncProvider).flush();
    final sent = h.server.callsTo('/route/chunks/0');
    expect(sent, hasLength(2));
    expect(sent[0].body, sent[1].body, reason: 'the retry is byte-for-byte the same command');
    final runId = (await runs(owner)).single['id'] as String;
    expect(h.server.callsTo('/route/complete'), hasLength(1));
    expect((await h.sync.get(owner, Kinds.route, runId))!.syncState, 'synced');
    c.dispose();
  });

  test('an open run from the build before routes keeps its identity, time and distance; its route starts on resume', () async {
    final owner = await h.signIn('one');
    const id = 'legacy-run';
    await h.sync.submit(owner, kind: 'run.start', path: '/runs', targetKind: Kinds.run, targetId: id, payload: {'runId': id},
        writes: [LocalWrite(Kinds.run, id, {'id': id, 'dayKey': '2026-10-09', 'startedAtUtc': '2026-10-09T10:30:00.000Z', 'finishedAtUtc': null, 'isDeleted': false})]);
    await h.sync.putLocal(owner, LocalWrite(Kinds.runtime, id,
        {'accumulatedActiveSeconds': 1860, 'runningAnchorUtc': null, 'isPaused': true, 'track': {'distanceMeters': 5200.0, 'fixes': 40, 'gaps': 0}}));
    final c = app();
    await c.read(recorderProvider.notifier).adopt(Run((await runs(owner)).single));
    final view = c.read(recorderProvider);
    expect((view.state, view.run!.id, view.analysis!.legacyDistance, view.analysis!.activeMs(0)), (RecState.interrupted, id, 5200.0, 1860000));
    expect(await c.read(recorderProvider.notifier).start('run', timerOnly: false), isFalse, reason: 'resumed, never duplicated');
    await c.read(recorderProvider.notifier).resume();
    gps.walk(h.clock, 60, speed: 3);
    await settle(c);
    await c.read(recorderProvider.notifier).finish();
    await c.read(recorderProvider.notifier).save(title: 'Morning run');
    final saved = Run((await runs(owner)).single);
    expect(saved.isWalk, isFalse);
    expect(saved.distanceMeters, closeTo(5200 + 180, 20));
    expect((saved.metrics['legacyDistanceMeters'], saved.metrics['routeState']), (5200.0, 'partial'));
    expect(saved.activeDurationSeconds, closeTo(1860 + 60, 2));
    c.dispose();
  });

  test('timer only: no route, distance unknown unless typed, and typed is labelled typed', () async {
    final owner = await h.signIn('one');
    final c = app();
    await c.read(recorderProvider.notifier).start('walk', timerOnly: true);
    expect(gps.watchers, 0, reason: 'no GPS when the person chose the timer only');
    h.clock.advance(const Duration(minutes: 20));
    await c.read(recorderProvider.notifier).finish();
    await c.read(recorderProvider.notifier).save(title: 'Evening walk', typedMeters: 1500);
    final saved = Run((await runs(owner)).single);
    expect((saved.distanceMeters, saved.distanceSource, saved.metrics['routeState'], saved.metrics['gpsDistanceMeters']), (1500.0, 'manual', 'none', null));
    expect([for (final cmd in await h.sync.commands(owner)) cmd.kind], ['run.start', 'run.finish'], reason: 'no route to upload');
    c.dispose();
  });

  test('discard and delete erase the route and withdraw its queued upload; nothing is resurrected', () async {
    final owner = await h.signIn('one');
    h.server.offline = true;
    final c = app();
    await c.read(recorderProvider.notifier).start('run', timerOnly: false);
    gps.walk(h.clock, 30, speed: 3);
    await settle(c);
    await c.read(recorderProvider.notifier).finish();
    await c.read(recorderProvider.notifier).save(title: 'Run');
    final run = Run((await runs(owner)).single);
    await c.read(runRepositoryProvider).delete(run);
    expect(await c.read(trackStoreProvider).all(owner, run.id), isEmpty);
    expect(await h.sync.get(owner, Kinds.route, run.id), isNull);
    expect([for (final cmd in await h.sync.commands(owner)) cmd.kind], ['run.start', 'run.finish', 'run.delete']);
    h.server
      ..offline = false
      ..capabilities = _caps;
    await c.read(compatibilityProvider.notifier).check();
    await c.read(syncProvider).flush();
    expect(h.server.callsTo('/route'), isEmpty, reason: 'a deleted route is never uploaded');

    // Discarding an activity being reviewed does the same and stops location.
    await c.read(recorderProvider.notifier).start('walk', timerOnly: false);
    gps.walk(h.clock, 10);
    await settle(c);
    await c.read(recorderProvider.notifier).finish();
    final open = c.read(recorderProvider).run!;
    await c.read(recorderProvider.notifier).discard();
    expect((c.read(recorderProvider).state, gps.listening), (RecState.idle, false));
    expect(await c.read(trackStoreProvider).all(owner, open.id), isEmpty);
    expect(Run((await runs(owner)).firstWhere((r) => r['id'] == open.id)).isDeleted, isTrue);
    c.dispose();
  });

  test('another account sees nothing of this one\'s activity, and its recorder starts empty', () async {
    final a = await h.signIn('one');
    final c = app();
    await c.read(recorderProvider.notifier).start('run', timerOnly: false);
    gps.walk(h.clock, 20, speed: 3);
    await settle(c);
    final id = c.read(recorderProvider).run!.id;
    final b = await h.signIn('two');
    expect(c.read(recorderProvider).state, RecState.idle);
    expect(gps.listening, isFalse);
    expect(await c.read(trackStoreProvider).all(b, id), isEmpty);
    expect(await runs(b), isEmpty);
    expect(await c.read(trackStoreProvider).all(a, id), isNotEmpty, reason: 'the first account keeps its route');
    c.dispose();
  });

  test('auto-pause pauses after standing still and resumes on walking away, recorded as its own events', () async {
    final owner = await h.signIn('one');
    final c = app();
    c.read(devicePrefsProvider.notifier).setAutoPause(true);
    await c.read(recorderProvider.notifier).start('walk', timerOnly: false);
    gps.walk(h.clock, 30, speed: 1.2);
    gps.walk(h.clock, 20, speed: 0, fromMeters: 36);
    await settle(c);
    expect(c.read(recorderProvider).state, RecState.autoPaused);
    gps.walk(h.clock, 15, speed: 1.2, fromMeters: 36);
    await settle(c);
    expect(c.read(recorderProvider).state, RecState.recording);
    final types = [for (final e in await c.read(trackStoreProvider).all(owner, c.read(recorderProvider).run!.id)) if (e.type != EntryType.fix) e.type];
    expect(types, [EntryType.start, EntryType.autopause, EntryType.autoresume]);
    c.dispose();
  });
}
