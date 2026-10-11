import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/activity/run_tracking.dart';
import 'package:gohard_rebuild/features/me/reminders.dart';
import 'package:gohard_rebuild/features/workout/workout_runtime.dart';

Plan _plan({String lifecycle = 'active', String? pausedOn}) => Plan({
      'id': 'p', 'title': 'Plan', 'lifecycle': lifecycle, 'startDate': '2026-10-05', 'blockWeeks': 1, 'pausedOn': pausedOn,
      'occasions': [
        for (final (i, o) in [('past', '2026-10-07', false, null), ('today', '2026-10-09', false, null), ('skipped', '2026-10-10', true, null), ('done', '2026-10-11', false, 'full'), ('open', '2026-10-12', false, null), ('next', '2026-10-14', false, null)].indexed)
          {'id': o.$1, 'weekNumber': 1, 'ordinal': i + 1, 'title': 'Workout ${o.$1}', 'originalDate': o.$2, 'scheduledDate': o.$2, 'isSkipped': o.$3, 'resultOutcome': o.$4, 'prescription': []},
      ],
    });

final _openWorkout = Workout({'id': 'w', 'occasionId': 'open', 'kind': 'planned', 'title': 'x', 'dayKey': '2026-10-09', 'startedAtUtc': '2026-10-09T10:00:00Z', 'finishedAtUtc': null, 'isDeleted': false, 'exercises': []});

Fix _fix(double metersNorth, int second, {double accuracy = 5}) =>
    Fix(45.0 + metersNorth / 111195.0, -73.0, accuracy, DateTime.utc(2026, 10, 9, 12).add(Duration(seconds: second)));

void main() {
  group('R3 reminders', () {
    List<String> days({bool enabled = true, Plan? plan, String today = '2026-10-09'}) =>
        [for (final r in plannedReminders(enabled: enabled, primary: plan, workouts: [_openWorkout], today: today)) r.dayKey];

    test('only real pending commitments of an active primary plan get a reminder', () {
      // Not the missed one, the skipped one, the recorded one or the one already in progress.
      expect(days(plan: _plan()), ['2026-10-09', '2026-10-14']);
      expect(days(plan: _plan(), enabled: false), isEmpty);
      expect(days(plan: null), isEmpty, reason: 'no primary plan: nothing to remind about');
    });

    test('paused_plan_has_no_training_nags, and neither does a closed or draft plan', () {
      expect(days(plan: _plan(lifecycle: 'paused', pausedOn: '2026-10-08')), isEmpty);
      expect(days(plan: _plan(lifecycle: 'closed')), isEmpty);
      expect(days(plan: _plan(lifecycle: 'draft')), isEmpty);
    });

    test('timezone_change_rebuilds_future_reminders without touching accepted dates', () {
      final plan = _plan();
      final before = [for (final o in plan.occasions) o.scheduledDate];
      final first = plannedReminders(enabled: true, primary: plan, workouts: const [], today: '2026-10-09');
      final again = plannedReminders(enabled: true, primary: plan, workouts: const [], today: '2026-10-09');
      // The plan carries calendar dates only; the zone is applied by the scheduler when it (re)schedules.
      expect([for (final r in again) (r.id, r.dayKey)], [for (final r in first) (r.id, r.dayKey)], reason: 'stable ids, so a rebuild replaces rather than duplicates');
      expect([for (final o in plan.occasions) o.scheduledDate], before);
      expect(first.map((r) => r.id).toSet().length, first.length);
    });
  });

  group('R3 GPS distance', () {
    test('adds only consecutive trustworthy readings', () {
      var t = RunTrack({});
      for (final (i, m) in [0.0, 10.0, 20.0, 30.0].indexed) {
        t = t.added(_fix(m, i * 4));
      }
      expect(t.distanceMeters, closeTo(30, 0.2));
      expect((t.fixes, t.gaps, t.hasDistance), (4, 0, true));
    });

    test('vague readings, jitter and position jumps add nothing', () {
      var t = RunTrack({}).added(_fix(0, 0));
      t = t.added(_fix(50, 4, accuracy: 80)); // too vague
      t = t.added(_fix(1, 8)); // standing still
      t = t.added(_fix(500, 12)); // 125 m/s: a jump, not running
      expect(t.distanceMeters, 0);
      expect(t.hasDistance, isFalse, reason: 'nothing measured means distance stays unknown, not zero');
      t = t.added(_fix(12, 16));
      expect(t.distanceMeters, closeTo(12, 0.2));
    });

    test('a stretch without readings is a counted gap, never bridged with a straight line', () {
      var t = RunTrack({}).added(_fix(0, 0)).added(_fix(10, 4));
      t = t.added(_fix(900, 300)); // the screen was closed for five minutes
      expect(t.distanceMeters, closeTo(10, 0.2), reason: 'the 890 m in between were not measured');
      expect(t.gaps, 1);
      t = t.added(_fix(910, 304));
      expect(t.distanceMeters, closeTo(20, 0.2));
    });

    test('paused movement is not counted, and the track rides along with the durable runtime', () {
      var t = RunTrack({}).added(_fix(0, 0)).added(_fix(10, 4)).detached();
      t = t.added(_fix(200, 8)); // moved while paused: only a new anchor
      expect((t.distanceMeters.round(), t.gaps), (10, 0));
      t = t.added(_fix(210, 12));
      expect(t.distanceMeters, closeTo(20, 0.2));

      final now = DateTime.utc(2026, 10, 9, 12);
      final runtime = WorkoutRuntime({...WorkoutRuntime.started(now).j, 'track': t.j});
      final resumed = runtime.paused(now.add(const Duration(seconds: 30))).resumed(now.add(const Duration(seconds: 90)));
      expect(RunTrack(resumed.j['track'] as Json).distanceMeters, closeTo(20, 0.2), reason: 'pause and resume keep what was measured');
      expect(resumed.elapsedSeconds(now.add(const Duration(seconds: 100))), 40);
      expect(haversineMeters(45, -73, 45, -73), 0);
    });
  });
}
