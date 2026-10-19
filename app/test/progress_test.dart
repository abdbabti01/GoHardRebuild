import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/progress/goal_repository.dart';
import 'package:gohard_rebuild/features/progress/trends.dart';
import 'package:gohard_rebuild/features/progress/weekly.dart';

/// The weekly projection, goal history and exercise trends (docs/PROGRESS.md). Fixture data only.

Workout _w(String id, String day, {String? outcome = 'manual_recorded', bool open = false, bool deleted = false, String time = '10:00', List<Json> exercises = const []}) => Workout({
      'id': id, 'kind': 'manual', 'title': 'Session $id', 'dayKey': day, 'startedAtUtc': '${day}T$time:00Z', 'finishedAtUtc': open ? null : '${day}T$time:30Z',
      'outcome': open ? null : outcome, 'isDeleted': deleted, 'exercises': exercises, 'performedSets': 3,
    });
Json _e(String id, String? key, {String name = 'Bench press', bool timed = false, int ordinal = 1}) => {'id': id, 'ordinal': ordinal, 'name': name, 'catalogKey': key, 'isTimed': timed};
WorkoutSet _s(String id, String exercise, String workout, String at, {int? reps, num? kg, int? secs, bool deleted = false}) =>
    WorkoutSet({'id': id, 'exerciseId': exercise, 'workoutId': workout, 'reps': reps, 'loadKg': kg, 'durationSeconds': secs, 'performedAtUtc': at, 'isDeleted': deleted});
Run _r(String id, String day, {String type = 'walk', int? secs = 1800, num? meters = 2000, bool open = false, bool deleted = false}) => Run({
      'id': id, 'dayKey': day, 'startedAtUtc': '${day}T07:00:00Z', 'finishedAtUtc': open ? null : '${day}T07:40:00Z', 'activeDurationSeconds': open ? null : secs,
      'distanceMeters': meters, 'isDeleted': deleted, 'activityType': type,
    });
WeeklyGoal _g(String week, int? workouts, int? runWalk) => WeeklyGoal({'weekStart': week, 'workoutsTarget': workouts, 'runWalkTarget': runWalk});

void main() {
  test('weeks are Monday to Sunday by calendar date, across daylight-saving changes and the year end', () {
    for (final (day, monday) in [
      ('2026-10-19', '2026-10-19'), ('2026-10-25', '2026-10-19'), ('2026-10-26', '2026-10-26'),
      ('2026-03-29', '2026-03-23'), ('2026-03-30', '2026-03-30'), // EU clocks change on Sunday 29 March
      ('2026-11-01', '2026-10-26'), ('2026-03-08', '2026-03-02'), // US changes
      ('2026-12-31', '2026-12-28'), ('2027-01-03', '2026-12-28'), ('2027-01-04', '2027-01-04'),
      ('2028-02-29', '2028-02-28'),
    ]) {
      expect(mondayOf(day), monday, reason: day);
    }
    final w = summarizeWeek(monday: '2026-12-28', today: '2027-01-05', workouts: [_w('a', '2026-12-31'), _w('b', '2027-01-03'), _w('c', '2027-01-04'), _w('d', '2026-12-27')], runs: const [], goals: const []);
    expect((w.sunday, w.workouts.map((x) => x.id).join(','), w.isComplete), ('2027-01-03', 'a,b', true));
    expect(summarizeWeek(monday: '2027-01-04', today: '2027-01-05', workouts: const [], runs: const [], goals: const []).isComplete, isFalse);
  });

  test('goals apply from their week until changed; older weeks keep theirs; clearing is a record of its own', () {
    final goals = [_g('2026-10-05', 3, null), _g('2026-10-12', 4, 2), _g('2026-10-26', null, null)];
    expect(goalFor('2026-09-28', goals), isNull, reason: 'no goal existed yet: never today\'s target');
    expect(goalFor('2026-10-05', goals)!.workoutsTarget, 3, reason: 'a later edit does not rewrite week A');
    expect((goalFor('2026-10-19', goals)!.workoutsTarget, goalFor('2026-10-19', goals)!.runWalkTarget), (4, 2), reason: 'inherited');
    expect(goalFor('2026-11-02', goals)!.isEmpty, isTrue, reason: 'cleared, not an older target restored');
    final cleared = summarizeWeek(monday: '2026-11-02', today: '2026-11-03', workouts: const [], runs: const [], goals: goals);
    expect(cleared.hasGoals, isFalse);
  });

  test('only distinct finished, non-deleted performed training and saved Run / Walk activities count', () {
    final workouts = [
      _w('full', '2026-10-19', outcome: 'full'), _w('partial', '2026-10-20', outcome: 'partial'), _w('manual', '2026-10-21'),
      _w('nodata', '2026-10-21', outcome: 'no_data'), _w('open', '2026-10-22', open: true), _w('deleted', '2026-10-22', deleted: true),
      _w('manual', '2026-10-21'), // the same record delivered twice (a retry, a pull) counts once
      _w('next', '2026-10-26'),
    ];
    final runs = [
      _r('walk', '2026-10-19', meters: 2500), _r('run', '2026-10-20', type: 'run', meters: null, secs: 1200), _r('intervals', '2026-10-21', type: 'run', meters: 3000, secs: 1500),
      _r('open', '2026-10-22', open: true), _r('deleted', '2026-10-22', deleted: true), _r('zero', '2026-10-23', secs: 0), _r('walk', '2026-10-19', meters: 2500),
    ];
    final w = summarizeWeek(monday: '2026-10-19', today: '2026-10-22', workouts: workouts, runs: runs, goals: [_g('2026-10-19', 3, 2)]);
    expect(w.workouts.map((x) => x.id), ['full', 'partial', 'manual']);
    expect(w.activities.map((x) => x.id), ['walk', 'run', 'intervals'], reason: 'one interval session is one activity; open, deleted and zero-time ones do not count');
    expect((w.runs.length, w.walks.length, w.activityWord), (2, 1, 'Run / Walk'));
    expect((w.distance.value, w.distance.counted, w.distance.missing, w.distance.incomplete), (5500.0, 2, 1, true), reason: 'unknown distance is not zero');
    expect(w.activeSeconds.value, 1800 + 1200 + 1500);
    expect((w.workoutsTarget, w.runWalkTarget, w.isComplete), (3, 2, false));

    final walks = summarizeWeek(monday: '2026-10-19', today: '2026-10-30', workouts: const [], runs: [_r('a', '2026-10-19'), _r('b', '2026-10-20', meters: 1000)], goals: const []);
    expect((walks.activityWord, walks.distance.value, walks.distance.incomplete), ('Walking', 3000.0, false));
    final empty = summarizeWeek(monday: '2026-10-12', today: '2026-10-30', workouts: const [], runs: const [], goals: const []);
    expect((empty.isEmpty, empty.distance.known, empty.hasGoals), (true, false, false));
  });

  test('completed weeks run from last week back to the first recorded one; the current week is never among them', () {
    expect(completedWeeks(today: '2026-10-21', workouts: const [], runs: const []), ['2026-10-12']);
    expect(completedWeeks(today: '2026-10-21', workouts: [_w('a', '2026-09-30'), _w('now', '2026-10-20')], runs: [_r('r', '2026-10-01')]), ['2026-10-12', '2026-10-05', '2026-09-28']);
  });

  group('exercise trends', () {
    // Bench (catalog) twice on one day, once a week later; a private custom exercise with the same name; free text.
    final workouts = [
      _w('w1', '2026-09-21', time: '07:00', exercises: [_e('w1-a', 'bench-press'), _e('w1-b', 'bench-press', ordinal: 2)]),
      _w('w2', '2026-09-21', time: '18:00', exercises: [_e('w2-a', 'bench-press')]),
      _w('w3', '2026-10-05', exercises: [_e('w3-a', 'bench-press'), _e('w3-c', 'custom:abc'), _e('w3-f', null, name: 'Bench press')]),
      _w('w4', '2026-10-19', exercises: [_e('w4-a', 'bench-press'), _e('w4-p', 'plank', name: 'Plank', timed: true), _e('w4-u', 'pull-up', name: 'Pull-up')]),
      _w('open', '2026-10-20', open: true, exercises: [_e('o-a', 'bench-press')]),
    ];
    final sets = [
      _s('1', 'w1-a', 'w1', '2026-09-21T07:01:00Z', reps: 8, kg: 80), _s('2', 'w1-b', 'w1', '2026-09-21T07:20:00Z', reps: 8, kg: 85), _s('3', 'w1-a', 'w1', '2026-09-21T07:05:00Z', reps: 5, kg: 95),
      _s('4', 'w2-a', 'w2', '2026-09-21T18:01:00Z', reps: 8, kg: 82.5),
      _s('5', 'w3-a', 'w3', '2026-10-05T10:01:00Z', reps: 5, kg: 100), _s('6', 'w3-c', 'w3', '2026-10-05T10:02:00Z', reps: 8, kg: 40), _s('7', 'w3-f', 'w3', '2026-10-05T10:03:00Z', reps: 8, kg: 70),
      _s('8', 'w4-a', 'w4', '2026-10-19T10:01:00Z', reps: 8, kg: 90), _s('9', 'w4-a', 'w4', '2026-10-19T10:02:00Z', reps: 8, kg: 90),
      _s('10', 'w4-a', 'w4', '2026-10-19T10:03:00Z', reps: 8, kg: 120, deleted: true), _s('11', 'w4-a', 'w4', '2026-10-19T10:04:00Z', reps: 6, kg: null),
      _s('12', 'w4-p', 'w4', '2026-10-19T10:05:00Z', secs: 45), _s('13', 'w4-p', 'w4', '2026-10-19T10:06:00Z', secs: 60),
      _s('14', 'w4-u', 'w4', '2026-10-19T10:07:00Z', reps: 7), _s('15', 'w4-u', 'w4', '2026-10-19T10:08:00Z', reps: 9, kg: 0),
      _s('16', 'o-a', 'open', '2026-10-20T10:01:00Z', reps: 8, kg: 200),
    ];
    final index = TrendIndex.build(workouts: workouts, sets: sets);

    test('group by exact identity only; free text and open workouts give no evidence', () {
      expect(index.trends.keys.toSet(), {'bench-press', 'custom:abc', 'plank', 'pull-up'});
      expect(index.trends['custom:abc']!.sessions.single.sets.single.loadKg, 40, reason: 'a private exercise is never merged with the catalog one of the same name');
      expect(index.trends['bench-press']!.sessions.map((s) => s.workout.id), ['w1', 'w2', 'w3', 'w4']);
    });

    test('one point per workout at the exact reps: the heaviest set, two sessions on one day kept apart', () {
      final bench = index.trends['bench-press']!;
      expect((bench.metric, bench.repOptions.join(','), bench.defaultReps), (TrendMetric.load, '5,8', 8), reason: 'the most recent loaded set was 8 reps');
      final eight = bench.points(reps: 8);
      expect(eight.map((p) => (p.workoutId, p.value)), [('w1', 85.0), ('w2', 82.5), ('w4', 90.0)], reason: 'w1 counts its second appearance; w3 has no 8-rep set');
      expect(eight.last.set.id, '8', reason: 'a tie goes to the set performed first');
      expect(bench.points(reps: 5).map((p) => p.value), [95.0, 100.0]);
      expect(bench.excluded, 1, reason: 'the unloaded set is left out of the load chart, and said to be');
      expect(changeOf(eight), 5.0);
    });

    test('ranges are the last 28 / 84 calendar days including today; a change needs two points', () {
      final eight = index.trends['bench-press']!.points(reps: 8);
      expect(inRange(eight, TrendRange.weeks4, '2026-10-19').map((p) => p.workoutId), ['w4']);
      expect(changeOf(inRange(eight, TrendRange.weeks4, '2026-10-19')), isNull);
      expect(inRange(eight, TrendRange.weeks12, '2026-10-19').length, 3);
      expect(TrendRange.weeks4.from('2026-10-19'), '2026-09-22');
      expect(TrendRange.weeks12.from('2026-10-19'), '2026-07-28');
      expect(inRange(eight, TrendRange.all, '2026-10-19').length, 3);
    });

    test('timed and bodyweight exercises use honest measures, never a zero load', () {
      final plank = index.trends['plank']!, pullUp = index.trends['pull-up']!;
      expect((plank.metric, plank.points().single.value), (TrendMetric.duration, 60.0));
      expect((pullUp.metric, pullUp.points().single.value, pullUp.repOptions.length), (TrendMetric.reps, 9.0, 0), reason: 'no added load: most reps');
    });

    test('a week\'s strength highlight needs two comparable sessions in it and a real increase', () {
      final w = [
        _w('a', '2026-10-12', exercises: [_e('a1', 'bench-press')]), _w('b', '2026-10-15', exercises: [_e('b1', 'bench-press')]),
        _w('c', '2026-10-13', exercises: [_e('c1', 'squat', name: 'Squat')]), _w('d', '2026-10-16', exercises: [_e('d1', 'squat', name: 'Squat')]),
      ];
      final s = [
        _s('1', 'a1', 'a', '2026-10-12T10:00:00Z', reps: 8, kg: 88.5), _s('2', 'b1', 'b', '2026-10-15T10:00:00Z', reps: 8, kg: 93),
        _s('3', 'c1', 'c', '2026-10-13T10:00:00Z', reps: 5, kg: 120), _s('4', 'd1', 'd', '2026-10-16T10:00:00Z', reps: 5, kg: 120),
      ];
      final idx = TrendIndex.build(workouts: w, sets: s);
      final week = summarizeWeek(monday: '2026-10-12', today: '2026-10-20', workouts: w, runs: const [], goals: const []);
      final h = strengthHighlight(week, idx)!;
      expect((h.trend.key, h.reps, h.first.value, h.last.value, h.first.dayKey, h.last.dayKey), ('bench-press', 8, 88.5, 93.0, '2026-10-12', '2026-10-15'));
      final flat = TrendIndex.build(workouts: w.sublist(2), sets: s.sublist(2));
      expect(strengthHighlight(summarizeWeek(monday: '2026-10-12', today: '2026-10-20', workouts: w.sublist(2), runs: const [], goals: const []), flat), isNull, reason: 'flat: no achievement invented');
    });
  });

  test('a target is blank or a whole number from 1 to 21, the account\'s own rule', () {
    for (final (raw, value, ok) in [('', null, true), ('  ', null, true), ('3', 3, true), (' 21 ', 21, true), ('1', 1, true),
        ('0', null, false), ('22', null, false), ('-1', null, false), ('2.5', null, false), ('three', null, false), ('100', null, false)]) {
      final (v, error) = GoalRepository.parse(raw);
      expect((v, error == null), (value, ok), reason: '"$raw"');
    }
  });
}
