import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/intake_history.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_history.dart';
import 'package:gohard_rebuild/features/nutrition/water.dart';

import 'ui_support.dart';

/// Eat › History & trends: the daily projection, totals, averages and calendar periods (docs/FOOD_DATA.md). Fixture
/// data only; the figures are the handoff's illustrative week, never app defaults.

const _today = '2026-10-20'; // a Tuesday

Stored<FoodEntry> _food(String id, String day, {num? kcal, num? protein, String state = 'synced', bool deleted = false}) {
  final j = {...foodEntry(id, day, 'Lunch', 'Food $id', '1 serving', calories: kcal, protein: protein), 'isDeleted': deleted};
  return stored(FoodEntry(j), Kinds.food, id, j, state: state);
}

Stored<WaterEntry> _water(String id, String day, double ml) {
  final j = {'id': id, 'dayKey': day, 'volumeMl': ml, 'isDeleted': false};
  return stored(WaterEntry(j), Kinds.water, id, j);
}

FoodDays _group(List<Stored<FoodEntry>> rows) {
  final out = <String, List<Stored<FoodEntry>>>{};
  for (final r in rows) {
    if (!r.value.isDeleted) (out[r.value.dayKey] ??= []).add(r);
  }
  return out;
}

/// The handoff's week of Oct 12–18, 2026: Wednesday and Sunday not logged, Thursday partial.
final _week = _group([
  _food('m', '2026-10-12', kcal: 2100),
  _food('t', '2026-10-13', kcal: 1950),
  _food('h1', '2026-10-15', kcal: 2230, protein: 140),
  _food('h2', '2026-10-15'), // homemade sauce, calories not entered
  _food('f', '2026-10-16', kcal: 2050),
  _food('s', '2026-10-17', kcal: 2380),
]);

void main() {
  group('daily states', () {
    test('the illustrative week: 10,710 kcal known over 5 days, 2,142 average including Thursday\'s partial sum', () {
      final s = IntakeSummary.build(Period.containing(PeriodKind.week, '2026-10-15'), IntakeMetric.calories, today: _today, food: _week);
      expect([for (final d in s.days) d.state], [DayState.recorded, DayState.recorded, DayState.notLogged, DayState.partial, DayState.recorded, DayState.recorded, DayState.notLogged]);
      expect((s.total, s.known.length, s.average, s.partialDays, s.elapsed.length, s.current), (10710, 5, 2142, 1, 7, false));
      expect(s.days[2].value, isNull, reason: 'not logged is no value, not zero');
    });

    test('an unknown-only day is outside the average; an explicit zero day is inside it', () {
      final food = _group([_food('a', '2026-10-12', kcal: 1000), _food('b', '2026-10-13'), _food('c', '2026-10-14', kcal: 0)]);
      final s = IntakeSummary.build(Period.containing(PeriodKind.week, '2026-10-12'), IntakeMetric.calories, today: _today, food: food);
      expect((s.days[1].state, s.days[2].state, s.days[2].isZero), (DayState.unknown, DayState.recorded, true));
      expect((s.total, s.known.length, s.average, s.loggedDays, s.unknownDays), (1000, 2, 500, 3, 1));
      expect(intakeDayText(s.days[2], IntakeMetric.calories, VolumeUnit.ml), '0 kcal recorded');
      expect(intakeDayText(s.days[1], IntakeMetric.calories, VolumeUnit.ml), 'Calories not entered · 1 food logged');
    });

    test('nothing known in a period: no total and no average, never zero', () {
      final s = IntakeSummary.build(Period.containing(PeriodKind.month, '2026-09-10'), IntakeMetric.calories, today: _today, food: _group([_food('b', '2026-09-13')]));
      expect((s.total, s.average, s.known.length, s.loggedDays), (null, null, 0, 1));
    });

    test('each nutrient has its own coverage: calories unknown while protein is known on the same day', () {
      final food = _group([_food('a', '2026-10-12', protein: 30)]);
      expect(intakeDay('2026-10-12', IntakeMetric.calories, today: _today, food: food).state, DayState.unknown);
      final p = intakeDay('2026-10-12', IntakeMetric.protein, today: _today, food: food);
      expect((p.state, p.value), (DayState.recorded, 30));
      final thu = intakeDay('2026-10-15', IntakeMetric.protein, today: _today, food: _week);
      expect((thu.state, thu.value, thu.unknownFoods), (DayState.partial, 140, 1));
    });

    test('a water-only day is food not logged; a food-only day is no water logged; water sums its entries in mL', () {
      final water = {'2026-10-14': [_water('w1', '2026-10-14', 500), _water('w2', '2026-10-14', 236.588)]};
      final wed = intakeDay('2026-10-14', IntakeMetric.calories, today: _today, food: _week, water: water);
      expect((wed.state, wed.waterEntries), (DayState.notLogged, 2));
      final w = intakeDay('2026-10-14', IntakeMetric.water, today: _today, food: _week, water: water);
      expect((w.state, w.value), (DayState.recorded, 736.588));
      expect(intakeDay('2026-10-12', IntakeMetric.water, today: _today, food: _week, water: water).state, DayState.notLogged);
      final s = IntakeSummary.build(Period.containing(PeriodKind.week, '2026-10-14'), IntakeMetric.water, today: _today, food: _week, water: water);
      expect((s.known.length, s.loggedDays), (1, 1), reason: 'water denominators count water days, not food days');
      expect(intakeAmount(IntakeMetric.water, s.total!, VolumeUnit.flOz), '24.9 fl oz', reason: 'converted once from the exact sum');
    });

    test('pending and review states are carried; deleted entries are gone; future days are Future', () {
      final food = _group([_food('a', '2026-10-19', kcal: 500, state: 'pending'), _food('b', '2026-10-19', kcal: 900, deleted: true), _food('c', '2026-10-18', kcal: 300, state: 'conflict')]);
      final mon = intakeDay('2026-10-19', IntakeMetric.calories, today: _today, food: food);
      expect((mon.value, mon.foods, mon.pending), (500, 1, true));
      expect(intakeDayText(mon, IntakeMetric.calories, VolumeUnit.ml), '500 kcal · 1 food · sync pending');
      expect(intakeDay('2026-10-18', IntakeMetric.calories, today: _today, food: food).review, isTrue);
      expect(intakeDay('2026-10-21', IntakeMetric.calories, today: _today, food: food).state, DayState.future);
    });

    test('the grouped history follows the account\'s records: a deletion or correction changes the totals once', () async {
      final rows = [_food('a', '2026-10-12', kcal: 100), _food('b', '2026-10-12', kcal: 200)];
      final container = ProviderContainer(overrides: [foodJournalProvider.overrideWith((ref) => Stream.value(rows))]);
      addTearDown(container.dispose);
      container.listen(foodDaysProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(intakeDay('2026-10-12', IntakeMetric.calories, today: _today, food: container.read(foodDaysProvider).value!).value, 300);
      rows[1] = _food('b', '2026-10-12', kcal: 200, deleted: true);
      rows[0] = _food('a', '2026-10-12', kcal: 150);
      container.invalidate(foodJournalProvider);
      await Future<void>.delayed(Duration.zero);
      expect(intakeDay('2026-10-12', IntakeMetric.calories, today: _today, food: container.read(foodDaysProvider).value!).value, 150);
    });

    test('grams round only for display, from the exact sum', () {
      expect(intakeAmount(IntakeMetric.protein, 140.25 + 0.0001, VolumeUnit.ml), '140.3 g');
      expect(intakeAmount(IntakeMetric.calories, 10710.4, VolumeUnit.ml), '10,710 kcal');
    });
  });

  group('calendar periods', () {
    test('weeks run Monday to Sunday, across months and years', () {
      final w = Period.containing(PeriodKind.week, '2025-12-31');
      expect((w.start, w.end, w.length), ('2025-12-29', '2026-01-04', 7));
      expect(periodLabel(w), 'Dec 29, 2025 – Jan 4, 2026');
      expect(periodLabel(Period.containing(PeriodKind.week, '2026-10-01')), 'Sep 28 – Oct 4, 2026');
      expect(periodLabel(Period.containing(PeriodKind.week, '2026-10-15')), 'Oct 12 – 18, 2026');
      expect(Period.containing(PeriodKind.week, '2026-10-18').start, '2026-10-12', reason: 'Sunday ends its week');
      expect(Period.containing(PeriodKind.week, '2026-03-29').length, 7, reason: 'a DST change is still seven calendar days');
    });

    test('months are the real calendar month: 28, 29, 30 and 31 days', () {
      expect(Period.containing(PeriodKind.month, '2026-02-14').length, 28);
      expect(Period.containing(PeriodKind.month, '2028-02-01').length, 29);
      expect(Period.containing(PeriodKind.month, '2026-04-30').length, 30);
      expect(Period.containing(PeriodKind.month, '2026-10-31').days.last, '2026-10-31');
      expect(Period.containing(PeriodKind.month, '2026-01-31').shift(1).start, '2026-02-01', reason: 'no day overflow into March');
      expect(Period.containing(PeriodKind.month, '2026-01-05').shift(-1).end, '2025-12-31');
      expect(periodLabel(Period.containing(PeriodKind.month, '2026-10-05')), 'October 2026');
    });

    test('the current period is so far: future positions are Future, coverage counts elapsed days including today', () {
      final food = _group([_food('a', '2026-10-19', kcal: 2000), _food('b', _today, kcal: 0)]);
      final week = IntakeSummary.build(Period.containing(PeriodKind.week, _today), IntakeMetric.calories, today: _today, food: food);
      expect((week.current, week.elapsed.length, week.days.where((d) => d.state == DayState.future).length), (true, 2, 5));
      expect((week.total, week.average), (2000, 1000), reason: 'today\'s explicit zero counts; future days never do');
      final month = IntakeSummary.build(Period.containing(PeriodKind.month, _today), IntakeMetric.calories, today: _today, food: food);
      expect((month.elapsed.length, month.days.length), (20, 31));
      // At midnight the shared today moves on and the same records project one more elapsed day.
      expect(IntakeSummary.build(month.period, IntakeMetric.calories, today: '2026-10-21', food: food).elapsed.length, 21);
    });
  });
}
