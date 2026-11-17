/// Help me set my targets (docs/NUTRITION_TARGETS.md): a starting estimate of daily calories and protein, with carbs
/// and fat as estimates only. Pure and offline: the same answers always give the same numbers, nothing is sent and
/// nothing is saved here.
library;

enum TargetGoal { maintain, lose, gain, recomp }

/// The sex input of the energy equations; used for this estimate only, never stored.
enum EnergySex { female, male }

/// The National Academies' physical activity level categories, which count daily life and exercise together.
enum ActivityLevel { inactive, lowActive, active, veryActive }

/// Why there is no estimate. The form says it in words and offers manual entry.
enum EstimateProblem { under19, ageRange, heightRange, weightRange, underweightForLoss }

/// Why a suggestion is what it is, said beside it.
enum EstimateNote { lossAtFloor, lossNoRoom, proteinAtCap }

class TargetEstimate {
  const TargetEstimate({required this.maintenance, required this.calories, required this.protein, required this.carbs, required this.fat, this.notes = const {}});
  final int maintenance, calories, protein, carbs, fat;
  final Set<EstimateNote> notes;
}

/// NASEM, Dietary Reference Intakes for Energy (2023), adults 19 and over (Health Canada's table of the same
/// equations): TEE kcal/day = intercept + a × age (y) + b × height (cm) + c × weight (kg).
const Map<EnergySex, Map<ActivityLevel, (double, double, double, double)>> eerCoefficients = {
  EnergySex.male: {
    ActivityLevel.inactive: (753.07, -10.83, 6.50, 14.10),
    ActivityLevel.lowActive: (581.47, -10.83, 8.30, 14.94),
    ActivityLevel.active: (1004.82, -10.83, 6.52, 15.91),
    ActivityLevel.veryActive: (-517.88, -10.83, 15.61, 19.11),
  },
  EnergySex.female: {
    ActivityLevel.inactive: (584.90, -7.01, 5.72, 11.71),
    ActivityLevel.lowActive: (575.77, -7.01, 6.60, 12.14),
    ActivityLevel.active: (710.25, -7.01, 6.54, 12.34),
    ActivityLevel.veryActive: (511.83, -7.01, 9.07, 12.56),
  },
};

/// The input bounds this estimate accepts (plausible adult values, not health ranges). Weight stops at 250 kg so the
/// highest protein suggestion stays inside the goal editor's 500 g.
const ageRange = (19, 100), heightRangeCm = (120.0, 230.0), weightRangeKg = (30.0, 250.0);

/// AHA/ACC/TOS 2013 obesity guideline: a 500–750 kcal/day deficit; the lower end is used.
const lossDeficitKcal = 500.0;

/// The same guideline's lowest prescriptions (1,200 women, 1,500 men); a loss suggestion never starts below them.
const lossFloorKcal = {EnergySex.female: 1200, EnergySex.male: 1500};

/// Slater et al. 2019: "start conservatively" at ~1,500–2,000 kJ/day; the lower end, in kcal (~359).
const gainSurplusKcal = 1500 / 4.184;

/// g per kg of body weight. ISSN 2017 (Jäger et al.): 1.4–2.0 for most exercising people; Morton et al. 2018: gains
/// level off near 1.6. Maintain at the low end, loss and gain at 1.6, recomposition at the top of the range.
const proteinPerKg = {TargetGoal.maintain: 1.4, TargetGoal.lose: 1.6, TargetGoal.gain: 1.6, TargetGoal.recomp: 2.0};

/// IOM 2005 AMDR: protein 10–35 % of energy, fat 20–35 %. Protein is capped at the top; fat sits at 30 %.
const proteinMaxShare = 0.35, fatShare = 0.30;

double maintenanceKcal(EnergySex sex, ActivityLevel activity, int age, double heightCm, double weightKg) {
  final (i, a, h, w) = eerCoefficients[sex]![activity]!;
  return i + a * age + h * heightCm + w * weightKg;
}

int _round(double v, int step) => (v / step).round() * step;

/// 1 in = 2.54 cm exactly.
double feetInchesToCm(double feet, double inches) => (feet * 12 + inches) * 2.54;

/// Carbs and fat (grams) for a day of [calories] and [protein]: fat at 30 % of calories, carbs the rest (never below 0).
(int carbs, int fat) macrosFor(int calories, int protein) {
  final fat = _round(calories * fatShare / 9, 5);
  return (_round(((calories - protein * 4 - fat * 9) / 4).clamp(0, double.infinity), 5), fat);
}

({TargetEstimate? estimate, EstimateProblem? problem}) estimateTargets({
  required TargetGoal goal, required EnergySex sex, required ActivityLevel activity, required int age, required double heightCm, required double weightKg,
}) {
  if (age < ageRange.$1) return (estimate: null, problem: EstimateProblem.under19);
  if (age > ageRange.$2) return (estimate: null, problem: EstimateProblem.ageRange);
  if (heightCm < heightRangeCm.$1 || heightCm > heightRangeCm.$2) return (estimate: null, problem: EstimateProblem.heightRange);
  if (weightKg < weightRangeKg.$1 || weightKg > weightRangeKg.$2) return (estimate: null, problem: EstimateProblem.weightRange);
  final bmi = weightKg / ((heightCm / 100) * (heightCm / 100));
  if (goal == TargetGoal.lose && bmi < 18.5) return (estimate: null, problem: EstimateProblem.underweightForLoss);

  final maintenance = maintenanceKcal(sex, activity, age, heightCm, weightKg);
  final notes = <EstimateNote>{};
  final floor = lossFloorKcal[sex]!;
  var target = switch (goal) {
    TargetGoal.maintain || TargetGoal.recomp => maintenance,
    TargetGoal.gain => maintenance + gainSurplusKcal,
    TargetGoal.lose => maintenance - lossDeficitKcal,
  };
  // Never below the guideline's lowest prescription: closer to maintenance instead, and said so.
  if (goal == TargetGoal.lose && target < floor) {
    notes.add(maintenance <= floor ? EstimateNote.lossNoRoom : EstimateNote.lossAtFloor);
    target = maintenance <= floor ? maintenance : floor.toDouble();
  }
  final calories = _round(target, 10);
  final protein = proteinPerKg[goal]! * weightKg;
  final cap = calories * proteinMaxShare / 4;
  if (protein > cap) notes.add(EstimateNote.proteinAtCap);
  // Rounded down at the cap, so the suggestion never passes 35 % of calories.
  final grams = protein > cap ? (cap / 5).floor() * 5 : _round(protein, 5);
  final (carbs, fat) = macrosFor(calories, grams);
  return (estimate: TargetEstimate(maintenance: _round(maintenance, 10), calories: calories, protein: grams, carbs: carbs, fat: fat, notes: notes), problem: null);
}
