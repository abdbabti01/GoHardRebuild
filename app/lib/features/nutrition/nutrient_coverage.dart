import '../../data/models.dart';

enum Nutrient { calories, protein, carbs, fat }

/// What is honestly known about one nutrient across the consumed entries of a day, or across the parts of one
/// saved meal or recipe.
class NutrientTotal {
  const NutrientTotal(this.knownTotal, this.knownEntries, this.unknownEntries, [this.partialEntries = 0]);
  final double knownTotal;
  final int knownEntries, unknownEntries;

  /// Of [unknownEntries], those (a recipe portion) whose own value is a known sum with some ingredient missing:
  /// that sum is in [knownTotal], and the entry still counts as unknown.
  final int partialEntries;

  /// Complete only when at least one entry exists and every entry has a known value.
  bool get isComplete => knownEntries > 0 && unknownEntries == 0;
  bool get hasAnyKnown => knownEntries > 0 || partialEntries > 0;

  /// The same knowledge for [factor] times the amount (a share of a batch, a multiplied meal): nothing becomes known.
  NutrientTotal times(double factor) => NutrientTotal(knownTotal * factor, knownEntries, unknownEntries, partialEntries);
}

abstract final class NutrientCoverage {
  /// Sums only values the user actually entered. Blank stays unknown; an entered zero is a known zero. An entry whose
  /// value is a partial sum adds what is known of it and stays unknown.
  static Map<Nutrient, NutrientTotal> calculate(List<FoodEntry> consumed) => {
        for (final n in Nutrient.values) n: _total([for (final e in consumed) (_value(e, n), e.partial(n.name))]),
      };

  /// The same rules over the values of parts (a saved meal's foods, a recipe's ingredients), by nutrient key.
  static Map<Nutrient, NutrientTotal> ofParts(Iterable<Map<String, double?>> parts) => {
        for (final n in Nutrient.values) n: _total([for (final p in parts) (p[n.name], null)]),
      };

  static double? _value(FoodEntry e, Nutrient n) => switch (n) {
        Nutrient.calories => e.calories,
        Nutrient.protein => e.protein,
        Nutrient.carbs => e.carbs,
        Nutrient.fat => e.fat,
      };

  static NutrientTotal _total(List<(double?, double?)> values) {
    var sum = 0.0;
    var known = 0, partial = 0;
    for (final (v, p) in values) {
      if (v != null) {
        sum += v;
        known++;
      } else if (p != null) {
        sum += p;
        partial++;
      }
    }
    return NutrientTotal(sum, known, values.length - known, partial);
  }

  static bool allComplete(Map<Nutrient, NutrientTotal> c) => c.values.every((t) => t.isComplete);
}
