import '../../data/models.dart';

enum Nutrient { calories, protein, carbs, fat }

/// What is honestly known about one nutrient across the consumed entries of a day.
class NutrientTotal {
  const NutrientTotal(this.knownTotal, this.knownEntries, this.unknownEntries);
  final double knownTotal;
  final int knownEntries, unknownEntries;

  /// Complete only when at least one entry exists and every entry has a known value.
  bool get isComplete => knownEntries > 0 && unknownEntries == 0;
  bool get hasAnyKnown => knownEntries > 0;
}

abstract final class NutrientCoverage {
  /// Sums only values the user actually entered. Blank stays unknown; an entered zero is a known zero.
  static Map<Nutrient, NutrientTotal> calculate(List<FoodEntry> consumed) => {
        for (final n in Nutrient.values) n: _total(consumed.map((e) => _value(e, n)).toList()),
      };

  static double? _value(FoodEntry e, Nutrient n) => switch (n) {
        Nutrient.calories => e.calories,
        Nutrient.protein => e.protein,
        Nutrient.carbs => e.carbs,
        Nutrient.fat => e.fat,
      };

  static NutrientTotal _total(List<double?> values) {
    final known = values.whereType<double>().toList();
    return NutrientTotal(known.fold(0, (a, b) => a + b), known.length, values.length - known.length);
  }

  static bool allComplete(Map<Nutrient, NutrientTotal> c) => c.values.every((t) => t.isComplete);
}
