import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/macro_composition.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart' show NutritionSurface;
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;

/// The macro composition (docs/NUTRITION_RINGS.md › Macro composition): shares by energy, never by grams; no split from
/// partial or missing values; a genuine zero without dividing by it; the recorded calories never rewritten.
void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  MacroComposition of(double? p, double? c, double? f) => MacroComposition({Nutrient.protein: p, Nutrient.carbs: c, Nutrient.fat: f});
  // Coverage of one food per nutrient (a known value) or one food without it (unknown).
  Map<Nutrient, NutrientTotal> coverage({double? kcal, double? p, double? c, double? f}) => {
        for (final (n, v) in [(Nutrient.calories, kcal), (Nutrient.protein, p), (Nutrient.carbs, c), (Nutrient.fat, f)]) n: v == null ? const NutrientTotal(0, 0, 1) : NutrientTotal(v, 1, 0),
      };

  test('percentages come from energy (4, 4, 9 kcal/g), not grams, and add up to 100', () {
    final m = of(100, 100, 100);
    expect(m.kcal, 1700);
    // By grams it would be a third each; by energy fat is more than half.
    expect(m.percents, {Nutrient.protein: 24, Nutrient.carbs: 23, Nutrient.fat: 53});
    expect(m.fractions[Nutrient.fat], closeTo(900 / 1700, 1e-9));
    for (final g in [(175.0, 260.0, 95.0), (60.0, 120.0, 38.0), (1.0, 1.0, 1.0), (33.3, 0.0, 0.1)]) {
      expect(of(g.$1, g.$2, g.$3).percents!.values.fold(0, (s, v) => s + v), 100, reason: '$g');
    }
    expect(of(160, 0, 0).percents, {Nutrient.protein: 100, Nutrient.carbs: 0, Nutrient.fat: 0});
  });

  test('missing or partial values give grams and no split; known values are kept, unknown ones are not dropped', () {
    final missing = MacroComposition.recorded(coverage(kcal: 900, p: 40, c: 100));
    expect((missing.complete, missing.percents, missing.fractions), (false, null, const <Nutrient, double>{}));
    expect(missing.grams, {Nutrient.protein: 40, Nutrient.carbs: 100, Nutrient.fat: null}, reason: 'fat unknown, never zero');

    // One food with fat, one without: a partial sum, marked partial.
    final partial = MacroComposition.recorded({
      ...coverage(kcal: 900, p: 40, c: 100),
      Nutrient.fat: const NutrientTotal(12, 1, 1),
    });
    expect((partial.complete, partial.grams[Nutrient.fat], partial.percents), (false, 12.0, null));
    expect(partial.partial, {Nutrient.fat});
    expect(NutritionSurface.macroNotes(l, partial, coverage(kcal: 900)[Nutrient.calories]!), [l.nrMacroPartial]);
  });

  test('a genuine zero: neutral, no division by zero', () {
    final zero = MacroComposition.recorded(coverage(kcal: 0, p: 0, c: 0, f: 0));
    expect((zero.complete, zero.kcal, zero.percents, zero.fractions), (true, 0.0, null, const <Nutrient, double>{}));
    expect(NutritionSurface.macroNotes(l, zero, coverage(kcal: 0)[Nutrient.calories]!), [l.nrMacroZero]);
  });

  test('the recorded calories stay authoritative: a difference is explained, never adjusted away', () {
    // 175 g protein, 260 g carbs, 95 g fat = 2,595 kcal against 2,461 kcal recorded.
    final c = coverage(kcal: 2461, p: 175, c: 260, f: 95);
    final m = MacroComposition.recorded(c);
    expect(m.kcal, 2595);
    expect(c[Nutrient.calories]!.knownTotal, 2461, reason: 'the composition reads the record and changes nothing');
    expect(NutritionSurface.macroNotes(l, m, c[Nutrient.calories]!), [l.nrMacroBasis('2,595'), l.nrMacroDiffers('2,461')]);
    // A rounding-sized difference (1,062 vs 1,020 kcal, under 5 %) is not called out.
    final close = coverage(kcal: 1020, p: 60, c: 120, f: 38);
    expect(NutritionSurface.macroNotes(l, MacroComposition.recorded(close), close[Nutrient.calories]!), [l.nrMacroBasis('1,062')]);
    // Unknown calories: nothing to compare with, so no claim about a difference.
    final unknown = coverage(p: 60, c: 120, f: 38);
    expect(NutritionSurface.macroNotes(l, MacroComposition.recorded(unknown), unknown[Nutrient.calories]!), [l.nrMacroBasis('1,062')]);
  });
}
