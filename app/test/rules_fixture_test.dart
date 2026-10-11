import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/plans/schedule_rules.dart';
import 'package:gohard_rebuild/features/workout/result_rules.dart';

import 'support.dart';

/// B1, W1, N1, N3: the Dart rules run the same fixture file as the .NET rules (one file, read by both suites).
void main() {
  group('schedule rules match the shared fixture', () {
    for (final c in (fixture['schedule'] as List).cast<Json>()) {
      test(c['name'] as String, () {
        final occasions = [
          for (final o in (c['occasions'] as List).cast<Json>())
            ScheduleOccasion(id: o['id'] as String, originalDate: o['originalDate'] as String, scheduledDate: o['scheduledDate'] as String,
                weekNumber: o['weekNumber'] as int, isSkipped: o['isSkipped'] as bool, isRecorded: o['isRecorded'] as bool, isOpen: o['isOpen'] as bool),
        ];
        final changes = [for (final x in (c['changes'] as List).cast<Json>()) ScheduleChange(x['occasionId'] as String, x['from'] as String, x['to'] as String)];

        final result = ScheduleRules.validate(occasions, changes, c['minimumRecoveryDays'] as int);

        expect(result.errors, c['expectErrors']);
        expect([for (final o in result.changed) {'id': o.id, 'originalDate': o.originalDate, 'scheduledDate': o.scheduledDate, 'weekNumber': o.weekNumber}], c['expectChanged']);
        expect(result.blockEnd, c['expectBlockEnd']);
        expect(result.projected.length, occasions.length, reason: 'a move never adds or removes an occasion');
      });
    }
  });

  group('schedule generation matches the shared fixture', () {
    for (final c in (fixture['generate'] as List).cast<Json>()) {
      test(c['name'] as String, () {
        final r = ScheduleRules.generate(c['start'] as String, (c['weekdays'] as List).cast<int>(), c['sessionsPerWeek'] as int, c['blockWeeks'] as int, c['minimumRecoveryDays'] as int);
        expect(r.errors, c['expectErrors']);
        expect(r.dates, c['expectDates']);
      });
    }
  });

  group('workout results match the shared fixture', () {
    for (final c in (fixture['results'] as List).cast<Json>()) {
      test(c['name'] as String, () {
        final r = WorkoutResultRules.evaluate(
          [for (final p in (c['prescription'] as List).cast<Json>()) PrescribedExercise(p['exerciseId'] as String, p['targetSets'] as int?)],
          [
            for (final s in (c['sets'] as List).cast<Json>())
              PerformedSet(s['exerciseId'] as String, reps: s['reps'] as int?, loadKg: (s['loadKg'] as num?)?.toDouble(), durationSeconds: s['durationSeconds'] as int?, isDeleted: s['isDeleted'] as bool),
          ],
          isManual: c['isManual'] as bool,
        );
        final e = c['expect'] as Json;
        expect((r.outcome, r.performedSets, r.performedExercises, r.qualifiesOccasion), (e['outcome'], e['performedSets'], e['performedExercises'], e['qualifiesOccasion']));
      });
    }
  });

  group('nutrient coverage matches the shared fixture', () {
    for (final c in (fixture['coverage'] as List).cast<Json>()) {
      test(c['name'] as String, () {
        final coverage = NutrientCoverage.calculate([for (final m in (c['entries'] as List).cast<Json>()) FoodEntry({'macros': m})]);
        for (final n in Nutrient.values) {
          final e = (c['expect'] as Json)[n.name] as Json;
          final t = coverage[n]!;
          expect((t.knownTotal, t.knownEntries, t.unknownEntries, t.isComplete), ((e['knownTotal'] as num).toDouble(), e['knownEntries'], e['unknownEntries'], e['isComplete']), reason: n.name);
        }
      });
    }
  });

  test('unit conversion is exact at the boundary and round-trips without drift', () {
    for (final u in (fixture['units'] as List).cast<Json>()) {
      final kg = loadInputToKg((u['lb'] as num).toDouble(), LoadUnit.lb);
      expect(kg, closeTo((u['kg'] as num).toDouble(), 1e-9));
      expect(loadKgToDisplay(kg, LoadUnit.lb), closeTo((u['lb'] as num).toDouble(), 1e-9));
    }
    // dirty_entry_keeps_its_unit_boundary: 140 typed in lb is stored as kilograms, whatever is displayed later.
    expect(loadInputToKg(140, LoadUnit.lb), closeTo(140 * 0.45359237, 1e-9));
    expect(formatLoad(63.5029318, LoadUnit.lb), '140 lb');
    expect(formatLoad(63.5029318, LoadUnit.kg), '63.5 kg');
    expect(parseNonNegative('-1'), isNull);
    expect(parseNonNegative('12,5'), 12.5);
    expect(parseNonNegative(''), isNull);
  });

  test('wire samples: blank stays unknown, zero stays zero, dates stay calendar dates', () {
    final food = FoodEntry((fixture['wire'] as Json)['foodEntry'] as Json);
    expect(food.calories, 0);
    expect(food.protein, isNull);
    expect(food.carbs, 9.5);
    expect(food.dayKey, '2026-10-09');
    final set = WorkoutSet(((fixture['wire'] as Json)['ackAccepted'] as Json)['data'] as Json);
    expect((set.reps, set.loadKg, set.durationSeconds), (8, 63.503, null));
    expect(DateTime.parse(set.performedAtUtc).isUtc, isTrue);
  });

  test('calendar helpers never shift a date across zones or DST', () {
    expect(addDays('2026-10-31', 1), '2026-11-01');
    expect(addDays('2026-03-07', 1), '2026-03-08'); // US spring-forward day
    expect(daysBetween('2026-10-31', '2026-11-02'), 2);
    expect(ScheduleRules.isDayKey('2026-02-30'), isFalse);
    expect(ScheduleRules.validate(const [], const [], 1).blockEnd, isNull);
  });
}
