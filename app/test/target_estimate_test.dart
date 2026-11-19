import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/units.dart' show LoadUnit, loadInputToKg;
import 'package:gohard_rebuild/features/nutrition/target_estimate.dart';

/// The target estimator (docs/NUTRITION_TARGETS.md). Expected numbers are worked out by hand from the published
/// equations (Health Canada's table of the NASEM 2023 adult equations) and the documented rules, and were cross-checked
/// with a separate script that shares no code with the app; they are not read back from this implementation.
void main() {
  TargetEstimate est(TargetGoal goal, {RecompPriority? priority, EnergySex sex = EnergySex.male, ActivityLevel activity = ActivityLevel.active, int age = 30, double cm = 180, double kg = 80}) {
    final r = estimateTargets(goal: goal, priority: priority, sex: sex, activity: activity, age: age, heightCm: cm, weightKg: kg);
    expect(r.problem, isNull);
    return r.estimate!;
  }

  EstimateProblem? problem(TargetGoal goal, {RecompPriority? priority, EnergySex sex = EnergySex.female, int age = 30, double cm = 165, double kg = 60}) =>
      estimateTargets(goal: goal, priority: priority, sex: sex, activity: ActivityLevel.inactive, age: age, heightCm: cm, weightKg: kg).problem;

  // Every goal, in a fixed order: maintain, lose, gain, recomposition (weight steady), recomposition (fat loss first).
  const goals = [(TargetGoal.maintain, null), (TargetGoal.lose, null), (TargetGoal.gain, null), (TargetGoal.recomp, RecompPriority.steady), (TargetGoal.recomp, RecompPriority.fatLoss)];

  test("reproduces the National Academies' worked example and the published coefficients", () {
    // DRI for Energy (2023): woman, 22 y, 165 cm, 63 kg, low active = 2,275 kcal/day (575.77 − 154.22 + 1,089.00 + 764.82).
    expect(maintenanceKcal(EnergySex.female, ActivityLevel.lowActive, 22, 165, 63), closeTo(2275.37, 0.01));
    expect(est(TargetGoal.maintain, sex: EnergySex.female, activity: ActivityLevel.lowActive, age: 22, cm: 165, kg: 63).calories, 2280);
    // Every category rises with activity, for both sexes.
    for (final sex in EnergySex.values) {
      final kcal = [for (final a in ActivityLevel.values) maintenanceKcal(sex, a, 40, 170, 75)];
      expect(kcal, orderedEquals([...kcal]..sort()), reason: '$sex');
    }
  });

  group('reference people, every activity category and goal', () {
    // 199 lb = 90.26488 kg (1 lb = 0.45359237 kg). Protein 1.4 × 90.26 = 126.4 → 125; 1.6 × = 144.4 → 145; 2.0 × = 180.5 → 180.
    test('man, 34 y, 170 cm, 199 lb', () {
      final kg = loadInputToKg(199, LoadUnit.lb);
      expect(kg, closeTo(90.26488, 1e-5));
      final tee = {
        ActivityLevel.inactive: 2762.58, // 753.07 − 368.22 + 1,105.00 + 1,272.73
        ActivityLevel.lowActive: 2972.81, // 581.47 − 368.22 + 1,411.00 + 1,348.56
        ActivityLevel.active: 3181.11, // 1,004.82 − 368.22 + 1,108.40 + 1,436.11
        ActivityLevel.veryActive: 3492.56, // −517.88 − 368.22 + 2,653.70 + 1,724.96
      };
      // (calories, protein) per goal, in the order of [goals].
      final expected = {
        ActivityLevel.inactive: [(2760, 125), (2260, 145), (3120, 145), (2760, 180), (2260, 180)],
        ActivityLevel.lowActive: [(2970, 125), (2470, 145), (3330, 145), (2970, 180), (2470, 180)],
        ActivityLevel.active: [(3180, 125), (2680, 145), (3540, 145), (3180, 180), (2680, 180)],
        ActivityLevel.veryActive: [(3490, 125), (2990, 145), (3850, 145), (3490, 180), (2990, 180)],
      };
      for (final a in ActivityLevel.values) {
        expect(maintenanceKcal(EnergySex.male, a, 34, 170, kg), closeTo(tee[a]!, 0.01), reason: '$a');
        final got = [for (final (g, p) in goals) est(g, priority: p, activity: a, age: 34, cm: 170, kg: kg)];
        expect([for (final e in got) (e.calories, e.protein)], expected[a], reason: '$a');
        for (final e in got) {
          expect(e.notes, isEmpty, reason: '$a: no floor or cap applies');
        }
      }
      // The ledger the screen shows, for the inactive man losing weight: 2,760 − 500 = 2,260; carbs and fat 250 / 75 g.
      final lose = est(TargetGoal.lose, activity: ActivityLevel.inactive, age: 34, cm: 170, kg: kg);
      expect((lose.maintenance, lose.adjustment, lose.calories, lose.proteinPerKg, lose.carbs, lose.fat), (2760, -500, 2260, 1.6, 250, 75));
      expect(est(TargetGoal.gain, activity: ActivityLevel.inactive, age: 34, cm: 170, kg: kg).adjustment, 360);
    });

    // 5 ft 4 in = 162.56 cm; 222 lb = 100.69751 kg. Protein 1.4 × = 141.0 → 140; 1.6 × = 161.1 → 160; 2.0 × = 201.4 → 200.
    test('woman, 28 y, 5 ft 4 in, 222 lb', () {
      final cm = feetInchesToCm(5, 4), kg = loadInputToKg(222, LoadUnit.lb);
      expect(cm, closeTo(162.56, 1e-9));
      expect(kg, closeTo(100.69751, 1e-5));
      final tee = {
        ActivityLevel.inactive: 2497.63, // 584.90 − 196.28 + 929.84 + 1,179.17
        ActivityLevel.lowActive: 2674.85, // 575.77 − 196.28 + 1,072.90 + 1,222.47
        ActivityLevel.active: 2819.72, // 710.25 − 196.28 + 1,063.14 + 1,242.61
        ActivityLevel.veryActive: 3054.73, // 511.83 − 196.28 + 1,474.42 + 1,264.76
      };
      final expected = {
        // Fat loss first at 2,000 / 2,170 kcal: 200 g would pass 35 % of calories, so 175 / 185 g (rounded down).
        ActivityLevel.inactive: [(2500, 140), (2000, 160), (2860, 160), (2500, 200), (2000, 175)],
        ActivityLevel.lowActive: [(2670, 140), (2170, 160), (3030, 160), (2670, 200), (2170, 185)],
        ActivityLevel.active: [(2820, 140), (2320, 160), (3180, 160), (2820, 200), (2320, 200)],
        ActivityLevel.veryActive: [(3050, 140), (2550, 160), (3410, 160), (3050, 200), (2550, 200)],
      };
      for (final a in ActivityLevel.values) {
        expect(maintenanceKcal(EnergySex.female, a, 28, cm, kg), closeTo(tee[a]!, 0.01), reason: '$a');
        final got = [for (final (g, p) in goals) est(g, priority: p, sex: EnergySex.female, activity: a, age: 28, cm: cm, kg: kg)];
        expect([for (final e in got) (e.calories, e.protein)], expected[a], reason: '$a');
        final capped = a == ActivityLevel.inactive || a == ActivityLevel.lowActive;
        expect(got.last.notes, capped ? {EstimateNote.proteinAtCap} : isEmpty, reason: '$a: the cap is said, not applied silently');
      }
    });

    test('equivalent metric and imperial answers give the same targets', () {
      for (final (g, p) in goals) {
        final metric = est(g, priority: p, sex: EnergySex.female, age: 28, cm: 162.56, kg: 100.69751);
        final imperial = est(g, priority: p, sex: EnergySex.female, age: 28, cm: feetInchesToCm(5, 4), kg: loadInputToKg(222, LoadUnit.lb));
        expect((imperial.maintenance, imperial.calories, imperial.protein, imperial.carbs, imperial.fat), (metric.maintenance, metric.calories, metric.protein, metric.carbs, metric.fat));
      }
    });
  });

  test('maintenance → adjustment → target always add up, the goal never changes maintenance, and the same answers give the same numbers', () {
    for (final sex in EnergySex.values) {
      for (final a in ActivityLevel.values) {
        final all = [for (final (g, p) in goals) est(g, priority: p, sex: sex, activity: a, age: 45, cm: 168, kg: 77)];
        for (final e in all) {
          expect(e.calories, e.maintenance + e.adjustment);
          expect(e.maintenance % 10, 0);
          expect(e.maintenance, all.first.maintenance);
        }
        expect([for (final e in all) e.adjustment], [0, -500, 360, 0, -500]);
      }
    }
    final once = est(TargetGoal.lose), again = est(TargetGoal.lose);
    expect((again.calories, again.protein, again.carbs, again.fat), (once.calories, once.protein, once.carbs, once.fat));
  });

  test('a deficit never starts below the floor, and says why', () {
    // Woman, 70 y, 150 cm, 45 kg, inactive: 584.90 − 490.70 + 858.00 + 526.95 = 1,479.15 → 1,480; −500 would be 980.
    final floor = est(TargetGoal.lose, sex: EnergySex.female, activity: ActivityLevel.inactive, age: 70, cm: 150, kg: 45);
    expect((floor.maintenance, floor.adjustment, floor.calories), (1480, -280, 1200));
    expect(floor.notes, {EstimateNote.lossAtFloor});
    // Fat loss first follows the same rule.
    expect(est(TargetGoal.recomp, priority: RecompPriority.fatLoss, sex: EnergySex.female, activity: ActivityLevel.inactive, age: 70, cm: 150, kg: 45).calories, 1200);
    // Woman, 95 y, 140 cm, 38 kg, inactive: 584.90 − 665.95 + 800.80 + 444.98 = 1,164.73 → 1,160, already under 1,200: no cut.
    final none = est(TargetGoal.lose, sex: EnergySex.female, activity: ActivityLevel.inactive, age: 95, cm: 140, kg: 38);
    expect((none.maintenance, none.adjustment, none.calories), (1160, 0, 1160));
    expect(none.notes, {EstimateNote.lossNoRoom});
    // Man, 80 y, 155 cm, 50 kg, inactive: 753.07 − 866.40 + 1,007.50 + 705.00 = 1,599.17 → 1,600; men's floor is 1,500.
    final man = est(TargetGoal.lose, sex: EnergySex.male, activity: ActivityLevel.inactive, age: 80, cm: 155, kg: 50);
    expect((man.calories, man.adjustment), (1500, -100));
    expect(man.notes, {EstimateNote.lossAtFloor});
  });

  test('protein stays within 35 % of calories and inside the goal editor', () {
    // Woman, 100 y, 150 cm, 120 kg, inactive: 584.90 − 701.00 + 858.00 + 1,405.20 = 2,147.10 → 2,150. 2.0 × 120 = 240 g;
    // 35 % of 2,150 kcal is 188.1 g → 185 g.
    final e = est(TargetGoal.recomp, priority: RecompPriority.steady, sex: EnergySex.female, activity: ActivityLevel.inactive, age: 100, cm: 150, kg: 120);
    expect((e.calories, e.protein), (2150, 185));
    expect(e.notes, {EstimateNote.proteinAtCap});
    // The heaviest accepted weight: 2.0 × 250 = 500 g, the goal editor's top.
    expect(est(TargetGoal.recomp, priority: RecompPriority.steady, activity: ActivityLevel.veryActive, age: 19, cm: 230, kg: 250).protein, 500);
  });

  test('carbs and fat follow the saved numbers and add up', () {
    // Fat 30 % → 2,260 × 0.3 / 9 = 75.3 → 75 g; carbs (2,260 − 580 − 675) / 4 = 251.25 → 250 g; total 2,255 kcal.
    expect(macrosFor(2260, 145), (carbs: 250, fat: 75, over: false));
    for (var cal = 1200; cal <= 4000; cal += 70) {
      for (final pro in [60, 125, 200]) {
        final m = macrosFor(cal, pro);
        expect((pro * 4 + m.fat * 9 + m.carbs * 4 - cal).abs(), lessThanOrEqualTo(10), reason: '$cal kcal, $pro g');
      }
    }
    // An edited protein that, with the fat share, passes the calories: no carbs, and said so.
    expect(macrosFor(1000, 300), (carbs: 0, fat: 35, over: true));
  });

  test('outside the method: no numbers, a reason', () {
    expect(problem(TargetGoal.maintain, age: 18), EstimateProblem.under19);
    expect(problem(TargetGoal.maintain, age: 19), isNull);
    expect(problem(TargetGoal.maintain, age: 100), isNull);
    expect(problem(TargetGoal.maintain, age: 101), EstimateProblem.ageRange);
    expect(problem(TargetGoal.maintain, cm: 119.9, kg: 40), EstimateProblem.heightRange);
    expect(problem(TargetGoal.maintain, cm: 120, kg: 40), isNull);
    expect(problem(TargetGoal.maintain, cm: 230, kg: 100), isNull);
    expect(problem(TargetGoal.maintain, cm: 230.1, kg: 100), EstimateProblem.heightRange);
    expect(problem(TargetGoal.maintain, cm: 150, kg: 29.9), EstimateProblem.weightRange);
    expect(problem(TargetGoal.maintain, cm: 150, kg: 30), isNull);
    expect(problem(TargetGoal.maintain, cm: 200, kg: 250), isNull);
    expect(problem(TargetGoal.maintain, cm: 200, kg: 250.1), EstimateProblem.weightRange);
    // BMI under 18.5 (170 cm: 53.47 kg is 18.5): no deficit of any kind, but the other goals still work.
    expect(problem(TargetGoal.lose, cm: 170, kg: 53.4), EstimateProblem.underweightForLoss);
    expect(problem(TargetGoal.lose, cm: 170, kg: 53.5), isNull);
    expect(problem(TargetGoal.recomp, priority: RecompPriority.fatLoss, cm: 170, kg: 48), EstimateProblem.underweightForLoss);
    for (final (g, p) in [(TargetGoal.maintain, null), (TargetGoal.gain, null), (TargetGoal.recomp, RecompPriority.steady)]) {
      expect(problem(g, priority: p, cm: 170, kg: 48), isNull);
    }
    // Recomposition has no default priority.
    expect(() => problem(TargetGoal.recomp), throwsArgumentError);
  });
}
