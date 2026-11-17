import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/units.dart' show LoadUnit, loadInputToKg;
import 'package:gohard_rebuild/features/nutrition/target_estimate.dart';

/// The target estimator (docs/NUTRITION_TARGETS.md): published equations, documented adjustments, honest refusals.
void main() {
  TargetEstimate est(TargetGoal goal, {EnergySex sex = EnergySex.male, ActivityLevel activity = ActivityLevel.active, int age = 30, double cm = 180, double kg = 80}) {
    final r = estimateTargets(goal: goal, sex: sex, activity: activity, age: age, heightCm: cm, weightKg: kg);
    expect(r.problem, isNull);
    return r.estimate!;
  }

  EstimateProblem? problem(TargetGoal goal, {EnergySex sex = EnergySex.female, int age = 30, double cm = 165, double kg = 60}) =>
      estimateTargets(goal: goal, sex: sex, activity: ActivityLevel.inactive, age: age, heightCm: cm, weightKg: kg).problem;

  test("reproduces the National Academies' worked example and Health Canada's published coefficients", () {
    // DRI for Energy (2023) Highlights: woman, 22 y, 165 cm, 63 kg, low active = 2,275 kcal/day.
    expect(maintenanceKcal(EnergySex.female, ActivityLevel.lowActive, 22, 165, 63), closeTo(2275.37, 0.01)); // 575.77 − 154.22 + 1,089.0 + 764.82
    expect(est(TargetGoal.maintain, sex: EnergySex.female, activity: ActivityLevel.lowActive, age: 22, cm: 165, kg: 63).calories, 2280);
    // Men, inactive: 753.07 − 10.83 × 30 + 6.50 × 180 + 14.10 × 80.
    expect(maintenanceKcal(EnergySex.male, ActivityLevel.inactive, 30, 180, 80), closeTo(2726.17, 0.01));
    // Every category rises with activity, for both sexes.
    for (final sex in EnergySex.values) {
      final kcal = [for (final a in ActivityLevel.values) maintenanceKcal(sex, a, 40, 170, 75)];
      expect(kcal, orderedEquals([...kcal]..sort()), reason: '$sex');
    }
  });

  test('each goal changes the result the way its documented adjustment says', () {
    final maintain = est(TargetGoal.maintain), lose = est(TargetGoal.lose), gain = est(TargetGoal.gain), recomp = est(TargetGoal.recomp);
    expect(maintain.maintenance, 3130); // 1,004.82 − 324.9 + 1,173.6 + 1,272.8 = 3,126.3
    expect((maintain.calories, maintain.protein), (3130, 110)); // 1.4 g/kg
    expect((lose.calories, lose.protein), (2630, 130)); // −500 kcal, 1.6 g/kg
    expect((gain.calories, gain.protein), (3480, 130)); // +1,500 kJ (≈359 kcal), 1.6 g/kg
    expect((recomp.calories, recomp.protein), (3130, 160), reason: 'recomposition keeps maintenance calories; protein is what changes'); // 2.0 g/kg
    for (final e in [maintain, lose, gain, recomp]) {
      expect(e.notes, isEmpty);
      expect(e.maintenance, 3130, reason: 'the goal never changes the maintenance estimate');
    }
    // Fat 30 % of calories, carbs the rest.
    expect((maintain.fat, maintain.carbs), (105, 435));
    expect(est(TargetGoal.lose), isA<TargetEstimate>().having((e) => (e.calories, e.protein, e.carbs, e.fat), 'same inputs', (lose.calories, lose.protein, lose.carbs, lose.fat)));
  });

  test('a loss suggestion never starts below the guideline floor, and says why', () {
    // 70 y woman, 150 cm, 45 kg, inactive: maintenance ≈ 1,479; −500 would be 979.
    final floor = est(TargetGoal.lose, sex: EnergySex.female, activity: ActivityLevel.inactive, age: 70, cm: 150, kg: 45);
    expect(floor.calories, 1200);
    expect(floor.notes, {EstimateNote.lossAtFloor});
    // Maintenance already at or below the floor: the suggestion stays at maintenance rather than going lower.
    final none = est(TargetGoal.lose, sex: EnergySex.female, activity: ActivityLevel.inactive, age: 95, cm: 140, kg: 38);
    expect((none.calories, none.maintenance), (1160, 1160));
    expect(none.notes, {EstimateNote.lossNoRoom});
    // Men's floor is 1,500.
    expect(est(TargetGoal.lose, sex: EnergySex.male, activity: ActivityLevel.inactive, age: 80, cm: 155, kg: 50).calories, greaterThanOrEqualTo(1500));
  });

  test('protein stays within 35 % of calories', () {
    final e = est(TargetGoal.recomp, sex: EnergySex.female, activity: ActivityLevel.inactive, age: 100, cm: 150, kg: 120);
    expect(e.notes, {EstimateNote.proteinAtCap});
    expect(e.protein * 4 / e.calories, lessThanOrEqualTo(0.35));
    // The heaviest accepted weight stays inside the goal editor's protein range.
    expect(est(TargetGoal.recomp, activity: ActivityLevel.veryActive, age: 19, cm: 230, kg: 250).protein, lessThanOrEqualTo(500));
  });

  test('outside the method: no numbers, a reason', () {
    expect(problem(TargetGoal.maintain, age: 18), EstimateProblem.under19);
    expect(problem(TargetGoal.maintain, age: 101), EstimateProblem.ageRange);
    expect(problem(TargetGoal.maintain, cm: 110), EstimateProblem.heightRange);
    expect(problem(TargetGoal.maintain, kg: 260), EstimateProblem.weightRange);
    // BMI 16.6: no weight-loss estimate, but the other goals still work.
    expect(problem(TargetGoal.lose, cm: 170, kg: 48), EstimateProblem.underweightForLoss);
    expect(problem(TargetGoal.maintain, cm: 170, kg: 48), isNull);
    expect(problem(TargetGoal.recomp, cm: 170, kg: 48), isNull);
  });

  test('metric and imperial inputs for the same body give the same targets', () {
    expect(feetInchesToCm(5, 11), closeTo(180.34, 1e-9));
    final metric = est(TargetGoal.gain, cm: 180.34, kg: 80);
    final imperial = est(TargetGoal.gain, cm: feetInchesToCm(5, 11), kg: loadInputToKg(176.37, LoadUnit.lb));
    expect((imperial.calories, imperial.protein, imperial.carbs, imperial.fat), (metric.calories, metric.protein, metric.carbs, metric.fat));
  });
}
