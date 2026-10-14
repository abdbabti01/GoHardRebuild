import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'nutrient_coverage.dart';

// Thousands are grouped for reading only ("1,400"); stored and editable values are never reformatted.
String _grouped(num v) => formatNumber(v).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

/// The day's overview on Eat. Today's [NutritionSummary] is given the same coverage and goals, so the two screens
/// can never disagree. Unknown nutrients show a dash, never a zero; partial sums are labelled.
/// A goal is drawn only when the person set one; none is ever suggested. Calories and protein are the only goals
/// the app stores, so carbs and fat are known totals and nothing more: one calorie ring, one protein bar.
class NutritionSurface extends StatelessWidget {
  const NutritionSurface({super.key, required this.entries, required this.coverage, this.calorieGoal, this.proteinGoal, this.pending = false});
  final List<FoodEntry> entries;
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;
  final bool pending;

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

  /// Progress toward one goal, in words. What is left is stated only when every food has a value: a remainder
  /// worked out from a partial sum would be invented.
  String _detail(Nutrient n, int goal, {required String name, required String unit}) {
    final t = coverage[n]!;
    final eaten = t.knownTotal;
    // The protein line sits under three values, so its words say which one it is about.
    final amount = '${n == Nutrient.protein ? 'Protein ' : ''}${_grouped(eaten)} of ${_grouped(goal)} $unit';
    if (!t.hasAnyKnown) return 'No $name value entered yet · goal ${_grouped(goal)} $unit';
    if (!t.isComplete) return '$amount · known so far';
    if (eaten > goal) return '$amount · ${_grouped(eaten - goal)} $unit over';
    return '$amount · ${_grouped(goal - eaten)} $unit left';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final complete = NutrientCoverage.allComplete(coverage);
    final unknownSomewhere = coverage.values.any((t) => t.unknownEntries > 0);
    // Food logged with no nutrition at all is not "known totals" of anything.
    final anyKnown = coverage.values.any((t) => t.hasAnyKnown);
    final heading = entries.isEmpty ? 'No food logged yet' : complete ? 'Totals' : anyKnown ? 'Known totals' : 'No nutrition entered for this food yet';
    final goals = NutritionSummary.goalsText(calorieGoal, proteinGoal);
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final kcal = coverage[Nutrient.calories]!;
    final calorieDetail = calorieGoal == null ? null : _detail(Nutrient.calories, calorieGoal!, name: 'calorie', unit: 'kcal');
    final proteinDetail = proteinGoal == null ? null : _detail(Nutrient.protein, proteinGoal!, name: 'protein', unit: 'g');
    Text detailText(String text) => Text(text, style: context.numStyle(13.5, color: c.secondary, weight: FontWeight.w400));

    // The one calorie ring, only with a goal and a known value: an empty ring would say "nothing eaten". Over the
    // goal it is full while its centre and the words carry the real figure.
    final ring = calorieGoal == null || !kcal.hasAnyKnown
        ? null
        : ProgressRing(
            key: const Key('goal-calories-progress'), value: kcal.knownTotal / calorieGoal!, size: 76, stroke: 7, label: 'Calorie goal: $calorieDetail',
            center: Text('${(kcal.knownTotal / calorieGoal! * 100).round()}%', style: context.numStyle(19, weight: FontWeight.w700)));
    final calories = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        label: _semantic(Nutrient.calories, 'Calories'),
        child: ExcludeSemantics(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
            Text(_value(Nutrient.calories), style: context.titleStyle(40)),
            Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(kcal.hasAnyKnown ? 'kcal' : 'Calories unknown', style: context.sansStyle(17, color: c.secondary, weight: FontWeight.w500))),
          ]),
        ),
      ),
      if (calorieDetail != null) Padding(padding: const EdgeInsets.only(top: 4), child: ExcludeSemantics(excluding: ring != null, child: detailText(calorieDetail))),
    ]);

    Widget cell(Nutrient n, String label) {
      final goal = n == Nutrient.protein ? proteinGoal : null;
      final t = coverage[n]!;
      return Semantics(
        label: goal == null ? _semantic(n, label) : '${_semantic(n, label)}. Protein goal: $proteinDetail',
        child: ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: context.caption),
            if (goal == null)
              Text(_value(n), style: context.titleStyle(21))
            else ...[
              Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 4, children: [
                Text(t.hasAnyKnown ? formatNumber(t.knownTotal) : '—', style: context.titleStyle(21)),
                Padding(padding: const EdgeInsets.only(bottom: 1.5), child: Text('/ ${_grouped(goal)} g', style: context.numStyle(15, color: c.secondary, weight: FontWeight.w400))),
              ]),
              const SizedBox(height: 6),
              // A bar only for the goal that was set; it stops at full, the words above carry the real number.
              ProgressRail(t.hasAnyKnown ? t.knownTotal / goal : 0, key: const Key('goal-protein-progress'), label: 'Protein goal', height: 6),
            ],
          ]),
        ),
      );
    }

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (entries.isEmpty) ...[
          Semantics(header: true, child: Text(heading, style: context.titleStyle(19))),
          const SizedBox(height: 6),
          Text('Nothing is recorded for this day. That is not the same as nothing eaten.', style: context.sansStyle(15, color: c.secondary)),
          if (goals != null) ...[const SizedBox(height: 8), Text('Your daily goal: $goals', key: const Key('goal-summary'), style: context.caption)],
        ] else ...[
          Text(heading, style: context.label),
          const SizedBox(height: 6),
          if (ring == null)
            calories
          else if (large)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [calories, const SizedBox(height: 12), ring])
          else
            Row(children: [Expanded(child: calories), const SizedBox(width: 12), ring]),
          const SizedBox(height: 14),
          const Rule(),
          const SizedBox(height: 14),
          // Three across with a thin rule between them (protein a little wider when it has a bar); with large text
          // they wrap two across instead of truncating.
          LayoutBuilder(
            builder: (context, box) {
              final weights = large ? const [1.0, 1.0, 1.0] : [if (proteinGoal != null) 1.5 else 1.0, 1.0, 1.0];
              final total = large ? 2 : weights.reduce((a, b) => a + b);
              return Wrap(runSpacing: 12, children: [
                for (final (i, (n, label)) in const [(Nutrient.protein, 'Protein'), (Nutrient.carbs, 'Carbs'), (Nutrient.fat, 'Fat')].indexed)
                  Container(
                    width: box.maxWidth * weights[i] / total,
                    padding: EdgeInsets.only(left: i > 0 && !large ? 14 : 0, right: i == 0 && !large ? 14 : 0),
                    decoration: i > 0 && !large ? BoxDecoration(border: Border(left: BorderSide(color: c.divider))) : null,
                    child: cell(n, label),
                  ),
              ]);
            },
          ),
          if (proteinDetail != null) ...[const SizedBox(height: 10), ExcludeSemantics(child: detailText(proteinDetail))],
          if (unknownSomewhere) ...[
            const SizedBox(height: 12),
            Text('Some foods have no value for a nutrient, so these are sums of what you entered, not full totals.', style: context.caption),
          ],
        ],
        if (pending) ...[const SizedBox(height: 12), const StatusLine(Icons.phone_iphone, 'Saved on this phone · sync pending')],
      ]),
    );
  }
}

/// Today's glance at the same day, for the Nutrition module: calories and protein, each against its goal when the
/// person set one ("1,480 / 2,200 kcal" over a thin bar). It reads the coverage Eat reads. An unknown value is a
/// dash, a partial sum is called "known", an over-goal bar stays full while the number is the real one. What is
/// left or over, carbs, fat and the explanations stay in Eat. Shown only when something was logged.
class NutritionSummary extends StatelessWidget {
  const NutritionSummary({super.key, required this.coverage, this.calorieGoal, this.proteinGoal});
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;

  /// "2,200 kcal · 140 g protein" for the goals that were set; null when none was.
  static String? goalsText(int? calorieGoal, int? proteinGoal) {
    final goals = [if (calorieGoal != null) '${_grouped(calorieGoal)} kcal', if (proteinGoal != null) '$proteinGoal g protein'];
    return goals.isEmpty ? null : goals.join(' · ');
  }

  Widget _metric(BuildContext context, Nutrient n, String label, String unit, int? goal, double size) {
    final t = coverage[n]!;
    final known = t.hasAnyKnown, partial = known && !t.isComplete;
    final said = n == Nutrient.calories ? 'kilocalories' : 'grams';
    return Semantics(
      label: '$label ${known ? '${_grouped(t.knownTotal)} $said' : 'unknown'}'
          '${partial ? ', known from ${t.knownEntries} of ${t.knownEntries + t.unknownEntries} foods' : ''}${goal == null ? '' : ', goal ${_grouped(goal)} $said'}',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 5, children: [
            Text(known ? _grouped(t.knownTotal) : '—', style: context.titleStyle(size)),
            Padding(
              padding: const EdgeInsets.only(bottom: 1.5),
              child: Text('${goal == null ? '' : '/ ${_grouped(goal)} '}$unit${partial ? ' · known' : ''}', style: context.numStyle(14, color: context.c.secondary, weight: FontWeight.w400)),
            ),
          ]),
          if (goal != null)
            Padding(
              key: Key('today-goal-${n.name}'), padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(child: ProgressRail(known ? t.knownTotal / goal : 0, label: '$label goal', height: 6)),
                // The real share, also over 100 %; nothing for an unknown value.
                ConstrainedBox(constraints: const BoxConstraints(minWidth: 48), child: Text(known ? '${(t.knownTotal / goal * 100).round()}%' : '', textAlign: TextAlign.end, style: context.numStyle(13, color: context.c.secondary, weight: FontWeight.w500))),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _metric(context, Nutrient.calories, 'Calories', 'kcal', calorieGoal, 26),
        const SizedBox(height: 10),
        _metric(context, Nutrient.protein, 'Protein', 'g protein', proteinGoal, 22),
      ]);
}

/// One line under Today's nutrition values when any food has no value for any nutrient. It says so and leads to
/// Eat, where the journal explains which. Nothing is drawn when every value is known.
class NutritionMissingNote extends StatelessWidget {
  const NutritionMissingNote({super.key, required this.coverage, required this.onDetails});
  final Map<Nutrient, NutrientTotal> coverage;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => !coverage.values.any((t) => t.unknownEntries > 0)
      ? const SizedBox.shrink()
      : Semantics(
          button: true, hint: 'Opens the food journal',
          child: InkWell(
            key: const Key('today-nutrition-missing'),
            borderRadius: BorderRadius.circular(Radii.field),
            onTap: onDetails,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Targets.minimum),
              child: Row(children: [
                Expanded(child: StatusLine(Icons.info_outline, coverage.values.any((t) => t.hasAnyKnown) ? 'Some nutrition values are missing' : 'No nutrition values entered yet')),
                Icon(Icons.chevron_right, size: 22, color: context.c.secondary),
              ]),
            ),
          ),
        );
}
