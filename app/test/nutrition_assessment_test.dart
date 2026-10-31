// The shared nutrition assessment (docs/EAT_COMPANION.md › Shared assessment): goal states and bar colours, the coach
// assessing before suggesting, the briefing once goals are reached, and the weekly report's calculations. Pure: no
// network, no AI. Every figure here is a labelled fixture, never an app default.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart' show Stored;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart' show Nutrient;
import 'package:gohard_rebuild/features/coach/day_coach.dart';
import 'package:gohard_rebuild/features/nutrition/eat_briefing.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/intake_history.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_assessment.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart' show goalStatus;
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;

import 'ui_support.dart' show foodEntry, stored;

final l = lookupAppLocalizations(const Locale('en'));
const today = '2026-10-30'; // a Friday

var _n = 0;
FoodEntry e({double? kcal, double? protein, String day = today}) =>
    FoodEntry({'id': 'e${_n++}', 'dayKey': day, 'meal': 'Lunch', 'name': 'x', 'amountDescription': '1', 'macros': {'calories': kcal, 'protein': protein, 'carbs': null, 'fat': null}, 'isDeleted': false});

NutrientAssessment kcalAt(double kcal, {int goal = 2000}) => DayAssessment.of([e(kcal: kcal, protein: 1)], calorieGoal: goal).calories;
NutrientAssessment proteinAt(double g, {int goal = 140}) => DayAssessment.of([e(kcal: 1, protein: g)], proteinGoal: goal).protein;

// Saved items for the coach: a shake (240 kcal, 48 g), oats (500 kcal, 37 g a serving), yogurt.
FoodItem whey() => FoodItem({'source': 'user', 'sourceId': 'whey', 'name': 'Whey', 'basis': 'serving', 'nutrients': {'calories': 120, 'protein': 24, 'carbs': 3, 'fat': 0}, 'servings': [{'label': '1 scoop', 'grams': 30}]});
FoodItem oatsItem() => FoodItem({'source': 'usda', 'sourceId': 'oats', 'name': 'Oats', 'basis': '100g', 'nutrients': {'calories': 380, 'protein': 13, 'carbs': 67, 'fat': 7}, 'servings': []});
MealComponent part(FoodItem f, double q, String unit) => MealComponent({'item': f.j, 'quantity': q, 'unit': unit});
final shake = SavedMeal({'id': 'm-shake', 'revision': 1, 'body': {'kind': 'meal', 'name': 'Breakfast shake', 'components': [part(whey(), 2, 'serving:0').j]}});
final oats = SavedMeal({'id': 'r-oat', 'revision': 1, 'body': {'kind': 'recipe', 'name': 'Overnight oats', 'servings': 4, 'components': [part(oatsItem(), 400, 'g').j, part(whey(), 4, 'serving:0').j]}});
final items = coachItems([shake, oats], const []);

DayRecords records({List<FoodEntry> food = const [], int? kcalGoal, int? proteinGoal}) =>
    DayRecords(today: today, shown: today, entries: (d) => [for (final f in food) if (f.dayKey == d) f], calorieGoal: kcalGoal, proteinGoal: proteinGoal, items: items, mealNow: 'Lunch');

List<String> lines(Json r) => (r['lines'] as List).cast<String>();
List<Json> cards(Json r) => (r['cards'] as List).cast<Json>();
List<String> actionIds(Json r) => [for (final a in (r['actions'] as List).cast<Json>()) a['id'] as String];

void main() {
  group('goal states and colours', () {
    test('calories: below 80 % green, from 80 % yellow, reached green, above red; percent and fill', () {
      expect((kcalAt(1599).state, kcalAt(1599).tone, kcalAt(1599).percent), (GoalState.below, GoalTone.green, 79));
      expect((kcalAt(1600).state, kcalAt(1600).tone, kcalAt(1600).percent), (GoalState.near, GoalTone.yellow, 80), reason: 'exactly 80 % is approaching');
      expect((kcalAt(2000).state, kcalAt(2000).tone, kcalAt(2000).percent, kcalAt(2000).left), (GoalState.reached, GoalTone.green, 100, null));
      final over = kcalAt(2450, goal: 2300);
      expect((over.state, over.tone, over.percent, over.over, over.fill), (GoalState.over, GoalTone.red, 107, 150, 1.0), reason: '2,450 / 2,300 kcal · 107 %, the bar capped');
      expect(goalStatus(l, over), '150 kcal over target');
      expect(goalStatus(l, kcalAt(1000)), 'Room remaining');
      expect(goalStatus(l, kcalAt(1900)), 'Approaching target');
    });

    test('display resolution: the label never contradicts the rounded figures beside it', () {
      // 79.995 %: below, shown as 79 % (never "80 %" beside "room remaining").
      expect((kcalAt(1599.9).state, kcalAt(1599.9).percent), (GoalState.below, 79));
      // 1,999.4 shows as 1,999: approaching, 99 %, 0.6 kcal left (shown as 1).
      expect((kcalAt(1999.4).state, kcalAt(1999.4).percent), (GoalState.near, 99));
      expect(kcalAt(1999.4).left, closeTo(0.6, 1e-9));
      // 1,999.6 and 2,000.4 show as 2,000: reached, 100 %, nothing left and nothing over.
      for (final v in [1999.6, 2000.4]) {
        expect((kcalAt(v).state, kcalAt(v).percent, kcalAt(v).left, kcalAt(v).over), (GoalState.reached, 100, null, null), reason: '$v');
      }
      // 2,000.6 shows as 2,001: over by 1, 101 % (never "100 %" beside "over").
      expect((kcalAt(2000.6).state, kcalAt(2000.6).percent, kcalAt(2000.6).over), (GoalState.over, 101, 1));
      // Protein at tenths: 139.96 shows as 140.0, reached.
      expect(proteinAt(139.96).state, GoalState.reached);
      expect(proteinAt(139.94).state, GoalState.near);
    });

    test('protein: yellow below the goal, green at or above it, never red for exceeding it', () {
      expect((proteinAt(100).state, proteinAt(100).tone), (GoalState.below, GoalTone.yellow));
      expect((proteinAt(112).state, proteinAt(112).tone), (GoalState.near, GoalTone.yellow), reason: '80 % of 140');
      expect((proteinAt(140).state, proteinAt(140).tone), (GoalState.reached, GoalTone.green));
      final above = proteinAt(155);
      expect((above.state, above.tone, above.over), (GoalState.over, GoalTone.green, 15));
      expect(goalStatus(l, above), 'Goal reached · 15 g above target');
      expect((goalStatus(l, proteinAt(100)), goalStatus(l, proteinAt(120))), ('Below target', 'Nearly there'));
    });

    test('completeness per nutrient: unknown is not zero, known values can establish reached, never an amount left', () {
      final partial = DayAssessment.of([e(kcal: 1000, protein: 30), e(kcal: null, protein: 20)], calorieGoal: 2000, proteinGoal: 140);
      expect((partial.calories.state, partial.calories.tone, partial.calories.left), (GoalState.incomplete, GoalTone.neutral, null), reason: 'no reassuring green');
      expect((partial.protein.complete, partial.protein.left), (true, 90), reason: 'a missing calorie never makes known protein unknown');
      expect(goalStatus(l, partial.calories), 'Known intake');
      final knownOver = DayAssessment.of([e(kcal: 2100, protein: 1), e(kcal: null, protein: 1)], calorieGoal: 2000).calories;
      expect((knownOver.state, knownOver.tone, knownOver.over), (GoalState.over, GoalTone.red, 100));
      expect(goalStatus(l, knownOver), '100 kcal over target · Known intake', reason: 'the incomplete label stays');
      final zero = DayAssessment.of([e(kcal: 0, protein: 0)], calorieGoal: 2000, proteinGoal: 140);
      expect((zero.calories.complete, zero.calories.known, zero.calories.state, zero.protein.state), (true, 0, GoalState.below, GoalState.below), reason: 'an entered zero is a known zero');
      final none = DayAssessment.of(const [], calorieGoal: 2000);
      expect((none.calories.complete, none.calories.left), (true, 2000), reason: 'nothing logged, judged against what was logged');
      final noGoal = DayAssessment.of([e(kcal: 500, protein: 20)]);
      expect((noGoal.calories.state, noGoal.calories.tone, noGoal.calories.percent, noGoal.calories.fill), (GoalState.noGoal, GoalTone.neutral, null, 0.0));
    });

    test('every goal combination gives one situation', () {
      DaySituation s(double kcal, double protein, {int? k, int? p, bool unknownKcal = false}) =>
          DayAssessment.of([e(kcal: kcal, protein: protein), if (unknownKcal) e(kcal: null, protein: 0)], calorieGoal: k, proteinGoal: p).situation;
      expect(s(500, 20), DaySituation.noGoals);
      expect(s(500, 20, k: 2000, p: 140), DaySituation.remaining);
      expect(s(500, 20, k: 2000), DaySituation.remaining, reason: 'calorie goal only');
      expect(s(500, 20, p: 140), DaySituation.remaining, reason: 'protein goal only');
      expect(s(2000, 100, k: 2000, p: 140), DaySituation.caloriesReachedProteinLeft);
      expect(s(2300, 100, k: 2000, p: 140), DaySituation.caloriesReachedProteinLeft, reason: 'exceeded counts as reached');
      expect(s(1600, 150, k: 2000, p: 140), DaySituation.proteinReachedCaloriesLeft);
      expect(s(2000, 150, k: 2000, p: 140), DaySituation.bothReached);
      expect(s(2100, 20, k: 2000), DaySituation.bothReached, reason: 'the only goal set is reached');
      expect(s(500, 150, p: 140), DaySituation.bothReached);
      expect(s(500, 20, k: 2000, p: 140, unknownKcal: true), DaySituation.uncertain);
    });
  });

  group('What could I eat? assesses before suggesting', () {
    Json eat(DayRecords r, {bool proceed = false, Nutrient? nutrient}) => resolveDay(DayIntent('eat', proceed: proceed, nutrient: nutrient), r, l);

    test('no goals: said without inventing an allowance; Edit goals offered; options still given', () {
      final r = eat(records(food: [e(kcal: 400, protein: 20)]));
      expect(lines(r).first, l.dcAssessNoGoals);
      expect(actionIds(r).first, 'goals');
      expect(cards(r), isNotEmpty);
      expect(cards(r).every((c) => !c.containsKey('toward')), isTrue, reason: 'no target to measure against');
    });

    test('both remaining: the exact amounts, then options that fit within the calories left, most protein first', () {
      final r = eat(records(food: [e(kcal: 400, protein: 48)], kcalGoal: 2000, proteinGoal: 140));
      expect(lines(r).first, l.dcAssessBothLeft('1,600', '92'));
      expect(lines(r), contains(l.dcFitsLeft('1,600')));
      expect(cards(r).first['name'], 'Breakfast shake', reason: '48 g before 37 g');
      expect(cards(r).first['toward'], '${l.dcAddsKcal('240', '640', '2,000')}\n${l.dcAddsProtein('48', '96', '140')}');
    });

    test('nothing fits: the trade-off is said and the nearest options carry what they miss; the limit is never relaxed', () {
      final r = eat(records(food: [e(kcal: 1950, protein: 48)], kcalGoal: 2000, proteinGoal: 140));
      expect(lines(r).first, l.dcAssessBothLeft('50', '92'));
      expect(lines(r), contains(l.dcNoneFitsLeft('50')));
      expect(cards(r).every((c) => c['overKcal'] is num), isTrue);
    });

    test('calories reached, protein left: the trade-off first, no options until the person chooses; then protein per kcal with the added calories', () {
      final day = records(food: [e(kcal: 2000, protein: 115)], kcalGoal: 2000, proteinGoal: 140);
      final ask = eat(day);
      expect(lines(ask), [l.dcAssessKcalReachedProteinLeft('25')]);
      expect(cards(ask), isEmpty);
      expect(actionIds(ask), ['proteinOptions', 'proceed', 'summary']);
      final go = eat(day, proceed: true, nutrient: Nutrient.protein);
      expect(lines(go), containsAll([l.dcAddsToCalories, l.dcProteinFocused]));
      expect(cards(go).first['name'], 'Breakfast shake', reason: '0.2 g/kcal before 0.07 g/kcal');
      expect(cards(go).first['toward'], contains(l.dcAddsKcal('240', '2,240', '2,000')), reason: 'the real calories it adds, above the target');
    });

    test('protein reached, calories left: protein is acknowledged and no longer the ranking', () {
      final r = eat(records(food: [e(kcal: 1500, protein: 150)], kcalGoal: 2000, proteinGoal: 140));
      expect(lines(r).first, l.dcAssessProteinReachedKcalLeft('500'));
      expect(cards(r).first['name'], 'Overnight oats', reason: 'nearest the calories left, not most protein');
      expect(cards(r).first['toward'], l.dcAddsKcal('500', '2,000', '2,000'), reason: 'no protein line once it is reached');
    });

    test('both reached: said before any food; continuing works and is never blocked', () {
      final day = records(food: [e(kcal: 2000, protein: 150)], kcalGoal: 2000, proteinGoal: 140);
      final ask = eat(day);
      expect(lines(ask), [l.dcAssessAllReached]);
      expect(lines(ask).join(' '), isNot(contains('done eating')));
      expect(cards(ask), isEmpty);
      expect(actionIds(ask), ['proceed', 'summary']);
      final go = eat(day, proceed: true);
      expect(cards(go), isNotEmpty);
      expect(lines(go), contains(l.dcAddsToCalories));
    });

    test('incomplete values: each nutrient on its own; no exact calories left; protein left when every protein value is known', () {
      final r = eat(records(food: [e(kcal: 1000, protein: 50), e(kcal: null, protein: 10)], kcalGoal: 2000, proteinGoal: 140));
      expect(lines(r).take(2), [l.dcAssessKcalUnknown('1,000'), l.dcAssessProteinLeft('80')]);
      expect(lines(r).any((s) => s.contains('fit within')), isFalse, reason: 'no calorie limit can be known');
    });

    test('a reply is recognised as stale after an edit, and "proceed" is the phone\'s own: a server answer cannot set it', () {
      final before = records(food: [e(kcal: 2000, protein: 150)], kcalGoal: 2000, proteinGoal: 140);
      final reply = eat(before);
      final after = records(food: [...before.entries!(today)!, e(kcal: 100, protein: 5)], kcalGoal: 2000, proteinGoal: 140);
      expect(dayRevision(after, today) == reply['revision'], isFalse);
      expect(dayRevision(records(food: before.entries!(today)!, kcalGoal: 2100, proteinGoal: 140), today) == reply['revision'], isFalse, reason: 'a goal change too');
      expect(DayIntent.fromJson(const DayIntent('eat', proceed: true).toJson())!.proceed, isTrue);
      expect(DayIntent.fromJson({'kind': 'eat', 'proceed': true}, ai: true)!.proceed, isFalse);
    });
  });

  group('briefing reads the same assessment', () {
    Briefing brief(List<FoodEntry> f, {int? k, int? p, String day = today, int minute = 600}) =>
        eatBriefing(day: day, today: today, entries: f, kcalGoal: k, proteinGoal: p, nowMinute: minute, nextMeal: 'Dinner', seen: const {'2026-10-30|protein', '2026-10-30|over'});

    test('both reached: said plainly, with no question asking to eat more; never "done eating"', () {
      final b = brief([e(kcal: 2000, protein: 150)], k: 2000, p: 140);
      expect((b.kind, b.allReached, briefingText(l, b, dayLabel: '')), (BriefKind.reached, true, l.ebAllReached));
    });

    test('calories at the target at display resolution: "reached", never "0 kcal left"; no options offered', () {
      final text = briefingText(l, brief([e(kcal: 1999.6, protein: 100)], k: 2000, p: 140), dayLabel: '');
      expect(text, '${l.ebKcalReachedPlain} ${l.ebProteinLeft('40')}');
    });

    test('the near heads-up never contradicts a green bar', () {
      // 360 of 500 is 72 % (green, room remaining) though only 140 kcal are left.
      final b = eatBriefing(day: today, today: today, entries: [e(kcal: 360, protein: 1)], kcalGoal: 500, nowMinute: 600, nextMeal: 'Dinner');
      expect(b.headsUp, isNull);
    });

    test('an earlier day is compared only with a goal recorded for it', () {
      final past = [e(kcal: 2300, protein: 90, day: '2026-10-29')];
      expect(briefingText(l, brief(past, day: '2026-10-29'), dayLabel: 'Thursday'), l.ebPast('Thursday', '2,300 kcal and 90 g protein'), reason: 'no goal recorded: nothing compared');
      expect(briefingText(l, brief(past, k: 2000, day: '2026-10-29'), dayLabel: 'Thursday'), endsWith(l.ebPastOver('300')));
    });
  });

  group('weekly report', () {
    Stored<FoodEntry> f(String id, String day, {num? kcal, num? protein}) {
      final j = foodEntry(id, day, 'Lunch', 'Food $id', '1 serving', calories: kcal, protein: protein);
      return stored(FoodEntry(j), Kinds.food, id, j);
    }

    FoodDays group(List<Stored<FoodEntry>> rows) {
      final out = <String, List<Stored<FoodEntry>>>{};
      for (final r in rows) {
        (out[r.value.dayKey] ??= []).add(r);
      }
      return out;
    }

    // Week of Mon Oct 19 – Sun Oct 25, 2026 (completed when today is Oct 30). Wed and Sun not logged; Thu partial calories.
    final week = group([
      f('m', '2026-10-19', kcal: 2100, protein: 150),
      f('t', '2026-10-20', kcal: 1900, protein: 120),
      f('h1', '2026-10-22', kcal: 1800, protein: 100),
      f('h2', '2026-10-22', protein: 10), // calories not entered
      f('fr', '2026-10-23', kcal: 2000, protein: 0), // an explicit zero protein
      f('s', '2026-10-24', kcal: 2500, protein: 145),
    ]);
    final period = Period.containing(PeriodKind.week, '2026-10-21');

    test('averages state their denominators; unlogged days are never zero; the known-value average may be understated', () {
      final r = WeeklyReport.build(period, today: today, food: week);
      final c = r.calories;
      expect((r.current, r.elapsed, r.loggedDays, r.unloggedDays), (false, 7, 5, 2));
      expect((c.summary.known.length, c.summary.total, c.summary.average, c.understated), (5, 10300, 2060, true));
      expect((c.completeDays.length, c.completeAverage), (4, 2125), reason: 'complete days only: Mon, Tue, Fri, Sat');
      final p = r.protein;
      expect((p.summary.known.length, p.completeDays.length, p.summary.days[4].isZero), (5, 5, true), reason: 'a genuine zero is a known value');
      expect(r.steps.map((s) => s.$1), [NextStepKind.completeValues, NextStepKind.logDays]);
    });

    test('no goal history: no goal comparison at all (never today\'s goal laid over earlier days)', () {
      final r = WeeklyReport.build(period, today: today, food: week);
      expect((r.goalDays, r.calories.compared, r.protein.compared), (0, 0, 0));
      expect(r.observations.map((o) => o.$1), isNot(contains(ObservationKind.proteinGoal)));
    });

    test('recorded goals: each day against its own goal; a changed day and an undeterminable day are left out', () {
      final goals = {
        '2026-10-19': const GoalDay(2000, 140), // 2,100 over; 150 reached
        '2026-10-20': const GoalDay(2000, 140), // 1,900 under; 120 not reached
        '2026-10-22': const GoalDay(2000, 140), // calories incomplete below: undetermined; 110 not reached
        '2026-10-23': const GoalDay(2000, 140, changed: true), // goals changed that day: not compared
        '2026-10-24': const GoalDay(2600, 140), // 2,500 under its own goal; 145 reached
      };
      final r = WeeklyReport.build(period, today: today, food: week, goals: goals);
      expect((r.goalDays, r.calories.compared, r.calories.over, r.calories.undetermined), (4, 3, 1, 1));
      expect((r.protein.compared, r.protein.reached), (4, 2));
      expect(r.observations.map((o) => o.$1), containsAll([ObservationKind.coverage, ObservationKind.proteinGoal]));
      expect(r.observations.length, lessThanOrEqualTo(WeeklyReport.maxObservations));
    });

    test('the current week is "so far" and excludes future days; spread is said only with enough complete days in both weeks', () {
      final now = WeeklyReport.build(Period.containing(PeriodKind.week, today), today: today, food: const {});
      expect((now.current, now.elapsed), (true, 5), reason: 'Mon–Fri elapsed');
      expect([...now.observations, ...now.steps], isEmpty, reason: 'nothing logged, nothing claimed');
      final steady = group([for (var i = 0; i < 5; i++) f('a$i', '2026-10-1${2 + i}', kcal: 2000, protein: 100 + i.toDouble())]);
      final varied = group([for (final (i, d) in ['2026-10-19', '2026-10-20', '2026-10-21', '2026-10-22', '2026-10-23'].indexed) f('b$i', d, kcal: 2000, protein: i.isEven ? 60 : 160)]);
      final both = {...steady, ...varied};
      final r = WeeklyReport.build(Period.containing(PeriodKind.week, '2026-10-19'), today: today, food: both,
          previousProtein: IntakeSummary.build(Period.containing(PeriodKind.week, '2026-10-12'), IntakeMetric.protein, today: today, food: both));
      expect(r.observations.map((o) => o.$1), contains(ObservationKind.variedMore));
      final sparse = WeeklyReport.build(period, today: today, food: week,
          previousProtein: IntakeSummary.build(period.shift(-1), IntakeMetric.protein, today: today, food: week));
      expect(sparse.observations.map((o) => o.$1), isNot(anyOf(contains(ObservationKind.variedMore), contains(ObservationKind.steadier))), reason: 'no previous week to compare');
    });
  });
}
