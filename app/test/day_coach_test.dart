// Help with today and food (docs/COACH.md › Help with today): the facts, portions and suggestions Leon or Leona gives,
// worked out from records with the app's own nutrition code. Pure: no network, no AI (requests are built here as the
// server's checked intent would be).
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/day_coach.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';
import 'package:gohard_rebuild/features/today/daily.dart';
import 'package:gohard_rebuild/features/today/today_greeting.dart' show todayLine;
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;

import 'ui_support.dart' show blockPlan;

final l = lookupAppLocalizations(const Locale('en'));
const mon = '2026-10-26', tue = '2026-10-27';

FoodItem whey({double? protein = 24, double? kcal = 120}) => FoodItem({
      'source': 'user', 'sourceId': 'whey', 'name': 'Whey', 'basis': 'serving', 'nutrients': {'calories': kcal, 'protein': protein, 'carbs': 3, 'fat': 0},
      'servings': [{'label': '1 scoop', 'grams': 30}],
    });
FoodItem oats() => FoodItem({'source': 'usda', 'sourceId': 'oats', 'name': 'Oats', 'basis': '100g', 'nutrients': {'calories': 380, 'protein': 13, 'carbs': 67, 'fat': 7}, 'servings': []});

MealComponent part(FoodItem f, double q, String unit) => MealComponent({'item': f.j, 'quantity': q, 'unit': unit});
SavedMeal meal(String id, String name, List<MealComponent> parts) => SavedMeal({'id': id, 'revision': 1, 'body': {'kind': 'meal', 'name': name, 'components': [for (final p in parts) p.j]}});
SavedMeal recipe(String id, String name, {double servings = 4, double? weight}) => SavedMeal({
      'id': id, 'revision': 1,
      'body': {'kind': 'recipe', 'name': name, 'servings': servings, 'preparedWeightG': weight, 'components': [part(oats(), 400, 'g').j, part(whey(), 4, 'serving:0').j]},
    });
SavedFood yogurt() => SavedFood({
      'id': 'f-yog', 'isFavourite': true, 'isDeleted': false,
      'item': {'source': 'off', 'sourceId': 'yog', 'name': 'Greek yogurt', 'basis': '100g', 'nutrients': {'calories': 59, 'protein': 10.3, 'carbs': 3.6, 'fat': 0.4}, 'servings': [{'label': '1 pot', 'grams': 170}]},
    });

FoodEntry entry(String id, {double? kcal, double? protein, String day = tue}) =>
    FoodEntry({'id': id, 'dayKey': day, 'meal': 'Breakfast', 'name': 'Toast', 'amountDescription': '1 slice', 'macros': {'calories': kcal, 'protein': protein, 'carbs': null, 'fat': null}, 'isDeleted': false});

final shake = meal('m-shake', 'Breakfast shake', [part(whey(), 2, 'serving:0')]);
final items = coachItems([shake, recipe('r-oat', 'Overnight oats'), meal('m-cola', 'Cola', [part(whey(protein: null), 1, 'serving:0')])], [yogurt()]);

DayRecords records({String shown = tue, List<FoodEntry>? food = const [], int? kcalGoal, int? proteinGoal, List<CoachItem>? saved, int pending = 0, DailySnapshot? snapshot,
        List<Workout> workouts = const []}) =>
    DayRecords(today: tue, shown: shown, snapshot: snapshot, workouts: workouts, entries: (d) => food == null ? null : [for (final e in food) if (e.dayKey == d) e],
        calorieGoal: kcalGoal, proteinGoal: proteinGoal, items: saved ?? items, pending: pending, mealNow: 'Breakfast');

DailySnapshot snap(Plan plan, String day, {List<Workout> workouts = const []}) {
  final training = resolveTraining(today: day, ctx: TrainingCtx({'primaryPlanId': plan.id}), plans: [plan], workouts: workouts);
  final open = openWorkouts(workouts, const {}, training);
  return DailySnapshot(ownerId: 'o', dayKey: day, training: training, inProgress: open.inProgress, parked: open.parked,
      finishedToday: [for (final w in workouts) if (!w.isOpen && w.dayKey == day) w], food: const [], coverage: const {}, runs: const []);
}

Workout manual(String day, {bool open = true}) => Workout({
      'id': 'm-$day', 'planId': null, 'occasionId': null, 'kind': 'manual', 'title': 'My own', 'dayKey': day, 'startedAtUtc': '${day}T07:00:00Z',
      'finishedAtUtc': open ? null : '${day}T08:00:00Z', 'outcome': open ? null : 'manual_recorded', 'qualifiedOccasion': false, 'isDeleted': false, 'exercises': <Json>[],
    });

List<String> lines(Json reply) => (reply['lines'] as List).cast<String>();
List<Json> cards(Json reply) => (reply['cards'] as List).cast<Json>();
List<String> actionIds(Json reply) => [for (final a in (reply['actions'] as List).cast<Json>()) a['id'] as String];

void main() {
  group('daily facts come from the shared schedule projection', () {
    final plan = Plan(blockPlan(start: mon, offsets: [0, 2, 6]));   // Monday, Wednesday, Sunday

    test('a planned workout is said as Today says it, and View workout previews it without starting anything', () {
      final s = snap(plan, mon);
      final r = resolveDay(const DayIntent('today'), records(snapshot: s).copyToday(mon), l);
      expect(lines(r).first, todayLine(l, s, const []));
      expect(lines(r).first, l.todayLineDue('Lower body A'));
      final view = (r['actions'] as List).cast<Json>().firstWhere((a) => a['id'] == 'workout');
      expect((view['planId'], view['occasionId'], view['workoutId']), (plan.id, 'o1-1', null));
    });

    test('a planned rest day is a rest day, never inferred from nothing being recorded; no workout to view', () {
      final r = resolveDay(const DayIntent('today'), records(snapshot: snap(plan, tue)), l);
      expect(lines(r).first, l.todayLineRest);
      expect(actionIds(r), isNot(contains('workout')));
    });

    test('a skipped workout stays skipped: it is not replaced by the next one', () {
      final skipped = Plan(copyJson(plan.j)..['occasions'] = [for (final o in plan.j['occasions'] as List) (o as Json)['id'] == 'o1-1' ? {...o, 'isSkipped': true} : o]);
      final r = resolveDay(const DayIntent('today'), records(snapshot: snap(skipped, mon)).copyToday(mon), l);
      expect(lines(r).first, l.todayLineSkipped);
      expect(r.toString(), isNot(contains('Upper body B')));
    });

    test('an open manual workout is its own fact and its own workout; it completes nothing planned', () {
      final ws = [manual(mon)];
      final s = snap(plan, mon, workouts: ws);
      expect(statusOf(s.todaysOccasions.single, plan, mon, ws), OccasionStatus.due);
      final r = resolveDay(const DayIntent('today'), records(snapshot: s, workouts: ws).copyToday(mon), l);
      expect(lines(r).first, l.todayLineResume);
      expect((r['actions'] as List).cast<Json>().firstWhere((a) => a['id'] == 'workout')['workoutId'], 'm-$mon');
      final finished = [manual(mon, open: false)];
      final after = resolveDay(const DayIntent('today'), records(snapshot: snap(plan, mon, workouts: finished), workouts: finished).copyToday(mon), l);
      expect(lines(after), containsAll([l.todayLineDue('Lower body A'), l.dcWorkoutsRecorded('1')]));
    });

    test('paused and no-plan are said as such, never as rest', () {
      final paused = Plan({...plan.j, 'lifecycle': 'paused', 'pausedOn': mon});
      expect(lines(resolveDay(const DayIntent('today'), records(snapshot: snap(paused, tue)), l)).first, l.todayLinePaused);
      final none = DailySnapshot(ownerId: 'o', dayKey: tue, training: const CreatePlan(), parked: const [], finishedToday: const [], food: const [], coverage: const {}, runs: const []);
      expect(lines(resolveDay(const DayIntent('today'), records(snapshot: none), l)).first, l.dcTrainingNoPlan);
    });

    test('loading, empty, partial and pending journals are each said truthfully; loading is never zero', () {
      expect(lines(resolveDay(const DayIntent('today'), records(food: null), l)), containsAll([l.dcTrainingLoading, l.dcJournalLoading]));
      expect(lines(resolveDay(const DayIntent('recorded'), records(), l)), containsAll([l.dcJournalEmpty, l.dcLoggedOnly]));
      final partial = resolveDay(const DayIntent('recorded'), records(food: [entry('a', kcal: 300, protein: 20), entry('b', kcal: null, protein: 0)]), l);
      expect(lines(partial).first, l.dcJournalLine('2', l.eatKcalKnown('300'), l.eatProteinGramsValue('20')));
      expect(lines(resolveDay(const DayIntent('recorded'), records(pending: 2), l)), contains(l.dcPending));
    });

    test('an earlier Eat day is answered as that day; asking about today says the day changed', () {
      final food = [entry('a', kcal: 200, protein: 5, day: '2026-10-20')];
      final earlier = resolveDay(const DayIntent('recorded'), records(shown: '2026-10-20', food: food), l);
      expect((earlier['dayKey'], lines(earlier).first), ('2026-10-20', l.dcJournalLine('1', l.eatKcalValue('200'), l.eatProteinGramsValue('5'))));
      final switched = resolveDay(const DayIntent('recorded', today: true), records(shown: '2026-10-20', food: food), l);
      expect(switched['dayKey'], tue);
      expect(lines(switched).first, l.dcJournalEmpty);
      final briefing = resolveDay(const DayIntent('today'), records(shown: '2026-10-20'), l);
      expect(lines(briefing).first, startsWith('Switched to today'));
    });
  });

  group('goals are used only when set', () {
    test('no goal: it says so, offers Edit goals, and suggests nothing as if a target existed', () {
      final r = resolveDay(const DayIntent('goal', nutrient: Nutrient.protein), records(food: [entry('a', protein: 30)]), l);
      expect(lines(r), [l.dcGoalProteinNotSet]);
      expect(actionIds(r), ['goals']);
      expect(cards(r), isEmpty);
    });

    test('a set goal with a complete day gives the exact gap; a partial day only what is known; contribution only when exact', () {
      final complete = resolveDay(const DayIntent('goal', nutrient: Nutrient.protein), records(proteinGoal: 140, food: [entry('a', kcal: 400, protein: 80)]), l);
      expect(lines(complete).first, l.dcGoalProteinLeft('80', '140', '60'));
      expect(cards(complete).first['name'], 'Breakfast shake');   // most protein first: 48 g
      expect(cards(complete).first['toward'], l.dcAddsProtein('48', '128', '140'));
      expect(lines(complete), contains(l.dcGoalNotMealSize));
      expect(cards(complete).map((c) => c['name']), isNot(contains('Cola')), reason: 'unknown protein is never ranked');

      final partial = resolveDay(const DayIntent('goal', nutrient: Nutrient.protein), records(proteinGoal: 140, food: [entry('a', protein: 80), entry('b', protein: null)]), l);
      expect(lines(partial).first, l.dcGoalProteinPartial('80', '140'));
      expect(cards(partial).first.containsKey('toward'), isFalse);
      final none = resolveDay(const DayIntent('goal', nutrient: Nutrient.calories), records(kcalGoal: 2000), l);
      expect(lines(none).first, l.dcGoalKcalNone('2,000'));
    });

    test('a complete day past the goal is stated plainly, with no praise or blame', () {
      final r = resolveDay(const DayIntent('goal', nutrient: Nutrient.protein), records(proteinGoal: 100, food: [entry('a', protein: 120)]), l);
      expect(lines(r).first, l.dcGoalProteinReached('120', '100'));
    });
  });

  group('portions use the shared arithmetic', () {
    final shakeItem = items.firstWhere((i) => i.id == 'm-shake'), oatItem = items.firstWhere((i) => i.id == 'r-oat'), yog = items.firstWhere((i) => i.id == 'f-yog');

    test('a recipe serving is its share of the whole batch; grams need a weighed batch', () {
      final batch = MealBody(recipe('r', 'x').j['body'] as Json).totals;
      final half = CoachMath.values(oatItem, const Portion(0.5, 'serving'))!;
      expect(half[Nutrient.calories]!.knownTotal, closeTo(batch[Nutrient.calories]!.knownTotal / 8, 1e-9));
      expect(CoachMath.values(oatItem, const Portion(200, 'g')), isNull);
      expect(CoachMath.explicit(oatItem, const Portion(1, 'serving'), grams: 200), isNull);
      final weighed = coachItems([recipe('r2', 'Weighed oats', weight: 1200)], const []).single;
      expect(CoachMath.values(weighed, const Portion(300, 'g'))![Nutrient.protein]!.knownTotal, closeTo(batch[Nutrient.protein]!.knownTotal / 4, 1e-9));
      final r = resolveDay(const DayIntent('portion', items: [(kind: ItemKind.recipe, id: 'r-oat')], grams: 200), records(), l);
      expect(lines(r), contains(l.dcCantGrams));
      expect(cards(r).single['portion'], const Portion(1, 'serving').toJson(), reason: 'kept at the portion it was, never a guessed weight');
    });

    test('unknown stays unknown and a real zero stays zero at any portion', () {
      final cola = items.firstWhere((i) => i.id == 'm-cola');
      final v = CoachMath.values(cola, const Portion(2, 'x'))!;
      expect((v[Nutrient.protein]!.isComplete, v[Nutrient.protein]!.hasAnyKnown, v[Nutrient.fat]!.isComplete, v[Nutrient.fat]!.knownTotal), (false, false, true, 0.0));
      final c = cards(resolveDay(const DayIntent('portion', items: [(kind: ItemKind.meal, id: 'm-cola')]), records(), l)).single;
      expect(proteinSaid(l, c['protein'] as Json), l.dcProteinUnknown);
    });

    test('smaller and larger move through practical steps from the actual portion, and say when there is no further step', () {
      expect(CoachMath.step(shakeItem, const Portion(1, 'x'), smaller: true), const Portion(0.75, 'x'));
      expect(CoachMath.step(shakeItem, const Portion(0.5, 'x'), smaller: true), isNull);
      expect(CoachMath.step(yog, CoachMath.base(yog), smaller: true), const Portion(0.75, 'serving:0'));
      expect(CoachMath.ladder(yog, 'g').map((p) => p.amount), [85, 130, 170, 215, 255, 340], reason: 'grams in 5 g steps around one pot');
      final first = resolveDay(const DayIntent('portion', items: [(kind: ItemKind.meal, id: 'm-shake')]), records(), l);
      expect(cards(first).single['amount'], l.dcTimesSaved('1'));
      final smaller = resolveDay(const DayIntent('portion', change: 'smaller'), records(), l, focus: cards(first));
      expect(cards(smaller).single['portion'], const Portion(0.75, 'x').toJson());
      expect((cards(smaller).single['protein'] as Json)['known'], 36);
      final smallest = resolveDay(const DayIntent('portion', change: 'smaller'), records(), l, focus: [{...cards(smaller).single, 'portion': const Portion(0.5, 'x').toJson()}]);
      expect(lines(smallest), contains(l.dcSmallest));
    });
  });

  group('candidates, names and constraints', () {
    test('several matches: the person chooses, and no values are shown until then', () {
      final two = coachItems([shake, meal('m-choc', 'Chocolate shake', [part(whey(), 1, 'serving:0')])], const []);
      final r = resolveDay(const DayIntent('portion', items: [(kind: ItemKind.meal, id: 'm-shake'), (kind: ItemKind.meal, id: 'm-choc')], change: 'smaller'), records(saved: two), l);
      expect(lines(r), [l.dcChoose]);
      expect(cards(r).every((c) => c['choice'] == true && !c.containsKey('kcal')), isTrue);
      final pick = (r['actions'] as List).cast<Json>().first;
      expect(DayIntent.fromJson(pick['intent'])!.items.single.id, 'm-shake');
    });

    test('a name with no saved item is said, never pretended; an ID not on this phone is not used', () {
      final r = resolveDay(const DayIntent('portion', unknownItems: ['shake']), records(), l);
      expect(lines(r).first, l.dcNotFound('"shake"'));
      expect(cards(r), isEmpty);
      expect(actionIds(r), ['addFood', 'meals']);
      final foreign = resolveDay(const DayIntent('portion', items: [(kind: ItemKind.meal, id: 'someone-elses')]), records(), l);
      expect(lines(foreign).first, l.dcNotFound(l.dcThatItem));
      expect(cards(foreign), isEmpty);
      expect(lines(resolveDay(const DayIntent('suggest'), records(saved: const []), l)).first, l.dcNoItems);
    });

    test('targets are met exactly or the nearest are labelled with what they miss; nothing is relaxed', () {
      final fits = resolveDay(const DayIntent('suggest', maxCalories: 200, minProtein: 20), records(), l);
      expect(lines(fits).first, l.dcFitsHeading('${l.dcUnderKcal('200')}${l.dcAnd}${l.dcAtLeastProtein('20')}'));
      for (final c in cards(fits)) {
        expect(((c['kcal'] as Json)['known'] as num) <= 200 && ((c['protein'] as Json)['known'] as num) >= 20, isTrue);
      }
      final impossible = resolveDay(const DayIntent('suggest', maxCalories: 100, minProtein: 60), records(), l);
      expect(lines(impossible).first, startsWith('Nothing saved fits'));
      expect(cards(impossible), isNotEmpty);
      expect(cards(impossible).every((c) => c.containsKey('overKcal') || c.containsKey('underProtein')), isTrue);
      expect(lines(impossible), contains(l.dcChangeWhich));
    });

    test('comparing two items states only differences whose values are known', () {
      final r = resolveDay(const DayIntent('compare', items: [(kind: ItemKind.meal, id: 'm-shake'), (kind: ItemKind.food, id: 'f-yog')]), records(), l);
      expect(cards(r).length, 2);
      expect(lines(r).first, l.dcMoreProtein('Breakfast shake', '30.5', 'Greek yogurt'));
      final unknown = resolveDay(const DayIntent('compare', items: [(kind: ItemKind.meal, id: 'm-shake'), (kind: ItemKind.meal, id: 'm-cola')]), records(), l);
      expect(lines(unknown), contains(l.dcCompareUnknown));
    });

    test("the server's intent is read only from known fields: added numbers are ignored, unknown kinds are nothing", () {
      final i = DayIntent.fromJson({
        'kind': 'portion', 'day': 'today', 'items': [{'kind': 'meal', 'id': 'm-shake'}, {'kind': 'plan', 'id': 'x'}], 'portion': {'change': 'smaller', 'factor': null},
        'calories': 98765, 'protein': 4321, 'meal': 'Brunch', 'action': 'log',
      }, ai: true)!;
      expect((i.today, i.items.single.id, i.change, i.meal, i.ai), (true, 'm-shake', 'smaller', null, true));
      expect(i.toJson().toString(), isNot(contains('98765')));
      expect(DayIntent.fromJson({'kind': 'logFood'}), isNull);
    });
  });

  group('a reply knows when its records changed', () {
    test('the revision changes with the journal, the goals or a suggested item, and only then', () {
      final base = records(proteinGoal: 140, food: [entry('a', protein: 80)]);
      final r = resolveDay(const DayIntent('portion', items: [(kind: ItemKind.meal, id: 'm-shake')]), base, l);
      String again(DayRecords x) => dayRevision(x, tue, itemIds: ['m-shake']);
      expect(again(base), r['revision']);
      expect(again(records(proteinGoal: 140, food: [entry('a', protein: 80)])), r['revision'], reason: 'same records, same revision on any run');
      expect(again(records(proteinGoal: 150, food: [entry('a', protein: 80)])), isNot(r['revision']));
      expect(again(records(proteinGoal: 140, food: [entry('a', protein: 80), entry('b', protein: 5)])), isNot(r['revision']));
      final edited = coachItems([meal('m-shake', 'Breakfast shake', [part(whey(), 3, 'serving:0')])], const []);
      expect(again(records(proteinGoal: 140, food: [entry('a', protein: 80)], saved: edited)), isNot(r['revision']));
      expect(fingerprint('same'), fingerprint('same'));
    });

    test('a saved food opens its own amount form at the suggested amount, for the day and meal, with exact values', () {
      final yog = items.firstWhere((i) => i.id == 'f-yog');
      final d = foodDraft(yog, const Portion(0.75, 'serving:0'), day: tue, meal: 'Snack')!;
      expect((d.dayKey, d.meal, d.quantity, d.unitId, d.protein), (tue, 'Snack', 0.75, 'serving:0', 13.13));
      expect(FoodRepository.sourceFields(d)['provenance'], {'calories': 'imported', 'protein': 'imported', 'carbs': 'imported', 'fat': 'imported'});
    });
  });
}

extension on DayRecords {
  /// The same records on a phone whose today is [day].
  DayRecords copyToday(String day) => DayRecords(today: day, shown: day, snapshot: snapshot, workouts: workouts, entries: entries, calorieGoal: calorieGoal,
      proteinGoal: proteinGoal, items: items, pending: pending, runOpen: runOpen, mealNow: mealNow);
}
