import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'nutrient_coverage.dart';

// Thousands are grouped for reading only ("1,400"); stored and editable values are never reformatted.
String _grouped(num v) => formatNumber(v).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

/// The full nutrition panel of Eat. Today's [NutritionSummary] is given the same entries, coverage and goals, so
/// the two screens can never disagree. Unknown nutrients show a dash, never a zero; partial sums are labelled.
/// A goal is drawn only when the person set one; none is ever suggested.
class NutritionSurface extends StatelessWidget {
  const NutritionSurface({super.key, required this.entries, required this.coverage, this.calorieGoal, this.proteinGoal, this.onLogFood, this.pending = false, this.footer});
  final List<FoodEntry> entries;
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;
  final VoidCallback? onLogFood;
  final bool pending;
  final Widget? footer;

  String _value(Nutrient n) {
    final t = coverage[n]!;
    if (!t.hasAnyKnown) return '—';
    return n == Nutrient.calories ? _grouped(t.knownTotal) : '${formatNumber(t.knownTotal)} g';
  }

  String _semantic(Nutrient n, String label) {
    final t = coverage[n]!;
    if (!t.hasAnyKnown) return '$label unknown';
    return '$label ${_value(n)}${n == Nutrient.calories ? ' kilocalories' : ''}${t.isComplete ? '' : ', from ${t.knownEntries} of ${t.knownEntries + t.unknownEntries} foods'}';
  }

  /// Progress toward one goal. The rail stops at full; the words always carry the real number. What is left is
  /// stated only when every food has a value: a remainder worked out from a partial sum would be invented.
  Widget _goal(BuildContext context, Nutrient n, int goal, {required String name, required String unit, required String key}) {
    final t = coverage[n]!;
    final eaten = t.knownTotal;
    // The protein rail sits under three values, so its words say which one it is about.
    final amount = '${n == Nutrient.protein ? 'Protein ' : ''}${_grouped(eaten)} of ${_grouped(goal)} $unit';
    final String detail;
    if (!t.hasAnyKnown) {
      detail = 'No $name value entered yet · goal ${_grouped(goal)} $unit';
    } else if (!t.isComplete) {
      detail = '$amount · known so far';
    } else if (eaten > goal) {
      detail = '$amount · ${_grouped(eaten - goal)} $unit over';
    } else {
      detail = '$amount · ${_grouped(goal - eaten)} $unit left';
    }
    return Column(key: Key(key), crossAxisAlignment: CrossAxisAlignment.start, children: [
      ProgressRail(t.hasAnyKnown ? eaten / goal : 0, label: '${name[0].toUpperCase()}${name.substring(1)} goal: $detail'),
      const SizedBox(height: 6),
      ExcludeSemantics(child: Text(detail, style: context.caption)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final complete = NutrientCoverage.allComplete(coverage);
    final unknownSomewhere = coverage.values.any((t) => t.unknownEntries > 0);
    // Food logged with no nutrition at all is not "known totals" of anything.
    final anyKnown = coverage.values.any((t) => t.hasAnyKnown);
    final heading = entries.isEmpty ? 'No food logged yet' : complete ? 'Totals' : anyKnown ? 'Known totals' : 'No nutrition entered for this food yet';
    final goals = [if (calorieGoal != null) '${_grouped(calorieGoal!)} kcal', if (proteinGoal != null) '$proteinGoal g protein'];
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
          if (goals.isNotEmpty) ...[const SizedBox(height: 8), Text('Your daily goal: ${goals.join(' · ')}', key: const Key('goal-summary'), style: context.caption)],
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
          if (calorieGoal != null) ...[const SizedBox(height: 10), _goal(context, Nutrient.calories, calorieGoal!, name: 'calorie', unit: 'kcal', key: 'goal-calories-progress')],
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
          if (proteinGoal != null) ...[const SizedBox(height: 12), _goal(context, Nutrient.protein, proteinGoal!, name: 'protein', unit: 'g', key: 'goal-protein-progress')],
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

/// Today's glance at the same day: calories and protein, their goals when the person set them, and Log food.
/// It reads the coverage Eat reads. An unknown value is a dash, a partial sum is called "known" and never gets a
/// remainder, and the full breakdown and explanation stay in Eat, one tap away.
class NutritionSummary extends StatelessWidget {
  const NutritionSummary({super.key, required this.entries, required this.coverage, this.calorieGoal, this.proteinGoal, required this.onLogFood, required this.onDetails});
  final List<FoodEntry> entries;
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;
  final VoidCallback onLogFood, onDetails;

  Widget _cell(BuildContext context, Nutrient n, String label, String unit, int? goal) {
    final t = coverage[n]!;
    final partial = t.hasAnyKnown && !t.isComplete;
    final of = goal == null ? '' : 'of ${_grouped(goal)}'; // the unit is beside the value above
    final note = goal == null
        ? null
        : !t.hasAnyKnown
            ? 'Goal ${_grouped(goal)} $unit'
            : partial
                ? '$of · known so far'
                : t.knownTotal > goal
                    ? '$of · ${_grouped(t.knownTotal - goal)} over'
                    : '$of · ${_grouped(goal - t.knownTotal)} left';
    return Semantics(
      label: '$label ${t.hasAnyKnown ? '${_grouped(t.knownTotal)} ${unit == 'kcal' ? 'kilocalories' : 'grams'}' : 'unknown'}'
          '${partial ? ', from ${t.knownEntries} of ${t.knownEntries + t.unknownEntries} foods' : ''}${note == null ? '' : ', $note'}',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(partial ? '$label · known' : label, style: context.caption),
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 5, children: [
            Text(t.hasAnyKnown ? _grouped(t.knownTotal) : '—', style: context.titleStyle(26)),
            if (t.hasAnyKnown) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(unit, style: context.sansStyle(14.5, color: context.c.secondary))),
          ]),
          if (goal != null)
            Column(key: Key('today-goal-${n.name}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 6),
              ProgressRail(t.hasAnyKnown ? t.knownTotal / goal : 0, label: '$label goal', height: 6),
              const SizedBox(height: 4),
              Text(note!, style: context.caption),
            ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goals = [if (calorieGoal != null) '${_grouped(calorieGoal!)} kcal', if (proteinGoal != null) '$proteinGoal g protein'];
    final calories = _cell(context, Nutrient.calories, 'Calories', 'kcal', calorieGoal), protein = _cell(context, Nutrient.protein, 'Protein', 'g', proteinGoal);
    // Side by side; one under the other when the text is large.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (entries.isEmpty) ...[
          Text('No food logged yet', style: context.sansStyle(16, weight: FontWeight.w600)),
          if (goals.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Your daily goal: ${goals.join(' · ')}', style: context.caption)),
        ] else ...[
          if (stacked) ...[calories, const SizedBox(height: 12), protein] else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: calories), const SizedBox(width: 16), Expanded(child: protein)]),
          // Any food without a value for any nutrient: said here in a line, explained in Eat.
          if (coverage.values.any((t) => t.unknownEntries > 0))
            Semantics(
              button: true, hint: 'Opens the food journal',
              child: InkWell(
                key: const Key('today-nutrition-missing'),
                onTap: onDetails,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Targets.minimum),
                  child: Row(children: [
                    Expanded(child: StatusLine(Icons.info_outline, coverage.values.any((t) => t.hasAnyKnown) ? 'Some nutrition values are missing' : 'No nutrition values entered yet')),
                    Icon(Icons.chevron_right, size: 22, color: context.c.secondary),
                  ]),
                ),
              ),
            ),
        ],
        const SizedBox(height: 12),
        SecondaryButton('Log food', key: const Key('log-food'), icon: Icons.add, onPressed: onLogFood),
      ]),
    );
  }
}
