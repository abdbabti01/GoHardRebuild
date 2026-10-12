import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'nutrient_coverage.dart';

/// The nutrition summary shared by Today and Eat. Both pass the same entries and coverage, so the two
/// screens can never disagree. Unknown nutrients show a dash, never a zero; partial sums are labelled.
/// The app keeps no nutrition goals, so no target or progress is drawn against one.
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
    // Thousands are grouped for reading only ("1,400"); stored and editable values are never reformatted.
    return n == Nutrient.calories ? formatNumber(t.knownTotal).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},') : '${formatNumber(t.knownTotal)} g';
  }

  String _semantic(Nutrient n, String label) {
    final t = coverage[n]!;
    if (!t.hasAnyKnown) return '$label unknown';
    return '$label ${_value(n)}${n == Nutrient.calories ? ' kilocalories' : ''}${t.isComplete ? '' : ', from ${t.knownEntries} of ${t.knownEntries + t.unknownEntries} foods'}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final complete = NutrientCoverage.allComplete(coverage);
    final unknownSomewhere = coverage.values.any((t) => t.unknownEntries > 0);
    // Food logged with no nutrition at all is not "known totals" of anything.
    final anyKnown = coverage.values.any((t) => t.hasAnyKnown);
    final heading = entries.isEmpty ? 'No food logged yet' : complete ? 'Totals' : anyKnown ? 'Known totals' : 'No nutrition entered for this food yet';
    Widget cell(Nutrient n, String label) => Semantics(
          label: _semantic(n, label),
          child: ExcludeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: context.caption),
              Text(_value(n), style: context.titleStyle(21)),
            ]),
          ),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (entries.isEmpty) ...[
          Semantics(header: true, child: Text(heading, style: context.titleStyle(19))),
          const SizedBox(height: 6),
          Text('Nothing is recorded for this day. That is not the same as nothing eaten.', style: context.sansStyle(15, color: c.secondary)),
        ] else ...[
          Text(heading, style: context.label),
          const SizedBox(height: 8),
          Semantics(
            label: _semantic(Nutrient.calories, 'Calories'),
            child: ExcludeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Calories', style: context.caption),
                Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
                  Text(_value(Nutrient.calories), style: context.titleStyle(36)),
                  if (coverage[Nutrient.calories]!.hasAnyKnown) Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('kcal', style: context.sansStyle(16, color: c.secondary))),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          const Rule(),
          const SizedBox(height: 14),
          // Three across; with large text or a narrow phone they wrap instead of truncating.
          LayoutBuilder(
            builder: (context, box) {
              final across = MediaQuery.textScalerOf(context).scale(10) > 13 ? 2 : 3;
              return Wrap(runSpacing: 12, children: [
                for (final (n, label) in const [(Nutrient.protein, 'Protein'), (Nutrient.carbs, 'Carbs'), (Nutrient.fat, 'Fat')]) SizedBox(width: box.maxWidth / across, child: cell(n, label)),
              ]);
            },
          ),
          if (unknownSomewhere) ...[
            const SizedBox(height: 12),
            Text('Some foods have no value for a nutrient, so these are sums of what you entered, not full totals.', style: context.caption),
          ],
        ],
        if (pending) ...[const SizedBox(height: 12), const StatusLine(Icons.phone_iphone, 'Saved on this phone · sync pending')],
        if (footer != null) ...[const SizedBox(height: 12), footer!],
        if (onLogFood != null) ...[
          const SizedBox(height: 16),
          PrimaryButton('Log food', key: const Key('log-food'), icon: Icons.add_circle, onPressed: onLogFood),
        ],
      ]),
    );
  }
}
