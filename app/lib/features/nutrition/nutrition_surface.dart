import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'nutrient_coverage.dart';

/// The pale nutrition surface shared by Today and Eat. Both pass the same entries and coverage, so the two
/// screens can never disagree. Unknown nutrients show a dash, never a zero; partial sums are labelled.
class NutritionSurface extends StatelessWidget {
  const NutritionSurface({super.key, required this.entries, required this.coverage, this.onLogFood, this.pending = false, this.footer});
  final List<FoodEntry> entries;
  final Map<Nutrient, NutrientTotal> coverage;
  final VoidCallback? onLogFood;
  final bool pending;
  final Widget? footer;

  String _value(Nutrient n) {
    final t = coverage[n]!;
    if (!t.hasAnyKnown) return '—';
    return n == Nutrient.calories ? formatNumber(t.knownTotal) : '${formatNumber(t.knownTotal)} g';
  }

  String _semantic(Nutrient n, String label) {
    final t = coverage[n]!;
    if (!t.hasAnyKnown) return '$label unknown';
    return '$label ${_value(n)}${t.isComplete ? '' : ', from ${t.knownEntries} of ${t.knownEntries + t.unknownEntries} foods'}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ec;
    final complete = NutrientCoverage.allComplete(coverage);
    final unknownSomewhere = coverage.values.any((t) => t.unknownEntries > 0);
    final heading = entries.isEmpty ? 'No food logged yet' : complete ? 'Totals' : 'Known totals';
    Widget cell(Nutrient n, String label) => Expanded(
          child: Semantics(
            label: _semantic(n, label),
            child: ExcludeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: context.sansStyle(12, color: c.nutritionSecondary)),
                const SizedBox(height: 2),
                Text(_value(n), style: context.serifStyle(27, color: c.nutritionText)),
              ]),
            ),
          ),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.nutritionSurface, borderRadius: BorderRadius.circular(Radii.nutrition)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Semantics(header: true, child: Text('Nourish your day', style: context.serifStyle(27, color: c.nutritionText)))),
          Icon(Icons.restaurant, size: 20, color: c.nutritionText),
        ]),
        const SizedBox(height: 6),
        Text(heading, style: context.sansStyle(13, color: c.nutritionSecondary)),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Nothing is recorded for this day. That is not the same as nothing eaten.', style: context.sansStyle(14, color: c.nutritionText)),
          )
        else ...[
          const SizedBox(height: 14),
          Row(children: [cell(Nutrient.calories, 'Calories'), cell(Nutrient.protein, 'Protein')]),
          const SizedBox(height: 12),
          Row(children: [cell(Nutrient.carbs, 'Carbs'), cell(Nutrient.fat, 'Fat')]),
          if (unknownSomewhere) ...[
            const SizedBox(height: 12),
            Text('Some foods have no value for a nutrient, so these are sums of what you entered, not full totals.', style: context.sansStyle(12, color: c.nutritionSecondary)),
          ],
        ],
        if (pending) ...[const SizedBox(height: 10), StatusLine(Icons.phone_iphone, 'Saved on this phone · sync pending', onColor: c.nutritionSecondary)],
        if (footer != null) ...[const SizedBox(height: 10), footer!],
        if (onLogFood != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('log-food'),
              style: FilledButton.styleFrom(backgroundColor: c.nutritionText, foregroundColor: c.nutritionSurface),
              onPressed: onLogFood,
              child: const Text('Log food'),
            ),
          ),
        ],
      ]),
    );
  }
}
