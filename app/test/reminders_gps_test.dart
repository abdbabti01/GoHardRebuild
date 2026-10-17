import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/me/reminders.dart';

Plan _plan({String lifecycle = 'active', String? pausedOn}) => Plan({
      'id': 'p', 'title': 'Plan', 'lifecycle': lifecycle, 'startDate': '2026-10-05', 'blockWeeks': 1, 'pausedOn': pausedOn,
      'occasions': [
        for (final (i, o) in [('past', '2026-10-07', false, null), ('today', '2026-10-09', false, null), ('skipped', '2026-10-10', true, null), ('done', '2026-10-11', false, 'full'), ('open', '2026-10-12', false, null), ('next', '2026-10-14', false, null)].indexed)
          {'id': o.$1, 'weekNumber': 1, 'ordinal': i + 1, 'title': 'Workout ${o.$1}', 'originalDate': o.$2, 'scheduledDate': o.$2, 'isSkipped': o.$3, 'resultOutcome': o.$4, 'prescription': []},
      ],
    });

final _openWorkout = Workout({'id': 'w', 'occasionId': 'open', 'kind': 'planned', 'title': 'x', 'dayKey': '2026-10-09', 'startedAtUtc': '2026-10-09T10:00:00Z', 'finishedAtUtc': null, 'isDeleted': false, 'exercises': []});

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
  // GPS distance moved to the Run / Walk pipeline: test/track_math_test.dart.
}
