import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'nutrient_coverage.dart';

// Thousands are grouped for reading only ("1,400"); stored and editable values are never reformatted.
String _grouped(num v) => formatNumber(v).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

/// Calories as people read them: whole kilocalories, grouped ("1,481"). Display only: totals, goals, comparisons and
/// what is stored keep their exact values; a remainder is worked out exactly and rounded when it is shown.
String formatKcal(num v) => _grouped(v.round());

String _amount(Nutrient n, num v) => n == Nutrient.calories ? formatKcal(v) : _grouped(v);

/// The day's overview on Eat, as a photo panel in the approved Today look: the NUTRITION label, calories in the
/// serif beside the bowl, [action] (Log food) under them, then goals, protein, carbs and fat full width below the
/// photograph. Today's [NutritionSummary] is given the same coverage and goals, so the two screens can never
/// disagree. Unknown nutrients show a dash, never a zero; partial sums are labelled. The bowl is decoration, there
/// on a day with nothing logged too; it is never one of the entries.
/// A goal is drawn only when the person set one; none is ever suggested. Calories and protein are the only goals
/// the app stores, so carbs and fat are known totals and nothing more: one calorie ring, one protein bar.
class NutritionSurface extends StatelessWidget {
  const NutritionSurface({super.key, required this.entries, required this.coverage, this.calorieGoal, this.proteinGoal, this.pending = false, this.action});
  final List<FoodEntry> entries;
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;
  final bool pending;

  /// The panel's one button (Eat's Log food), built by the caller from its own context.
  final Widget? action;

  static const photo = 'assets/images/nutrition-cover.webp';

  String _value(Nutrient n) {
    final t = coverage[n]!;
    if (!t.hasAnyKnown) return '—';
    return n == Nutrient.calories ? formatKcal(t.knownTotal) : '${formatNumber(t.knownTotal)} g';
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
    final amount = '${n == Nutrient.protein ? 'Protein ' : ''}${_amount(n, eaten)} of ${_grouped(goal)} $unit';
    if (!t.hasAnyKnown) return 'No $name value entered yet · goal ${_grouped(goal)} $unit';
    if (!t.isComplete) return '$amount · known so far';
    if (eaten > goal) return '$amount · ${_amount(n, eaten - goal)} $unit over';
    return '$amount · ${_amount(n, goal - eaten)} $unit left';
  }

  // Everything is built under the panel's theme: dark ink on the pale tint, the deep button, in Light and Dark.
  @override
  Widget build(BuildContext context) => PanelTheme(child: Builder(builder: _panel));

  Widget _panel(BuildContext context) {
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
    // The figure in the serif, as on Today's panel; an unknown total is a dash and says so in words.
    final calories = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        label: _semantic(Nutrient.calories, 'Calories'),
        child: ExcludeSemantics(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
            Text(_value(Nutrient.calories), style: context.pageTitleStyle(44)),
            kcal.hasAnyKnown
                ? Text('kcal', style: context.pageTitleStyle(44))
                : Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Calories unknown', style: context.sansStyle(16, color: c.secondary, weight: FontWeight.w500))),
          ]),
        ),
      ),
      // With a ring the progress words sit beside it, below the photograph.
      if (calorieDetail != null && ring == null) Padding(padding: const EdgeInsets.only(top: 4), child: detailText(calorieDetail)),
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

    // Beside the photograph: the label, the day's calories (or that nothing is recorded) and the button.
    final words = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Semantics(header: true, child: const Overline('Nutrition')),
        // "Known totals" when some food has no value: the figures are sums of what was entered.
        if (entries.isNotEmpty) Text(heading, style: context.sansStyle(13.5, color: c.secondary, weight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      if (entries.isEmpty) ...[
        Semantics(header: true, child: Text(heading, style: context.pageTitleStyle(30))),
        const SizedBox(height: 6),
        Text('Nothing is recorded for this day. That is not the same as nothing eaten.', style: context.sansStyle(15, color: c.secondary)),
        if (goals != null) ...[const SizedBox(height: 8), Text('Your daily goal: $goals', key: const Key('goal-summary'), style: context.caption)],
      ] else
        calories,
    ]);
    final pendingLine = pending ? const StatusLine(Icons.phone_iphone, 'Saved on this phone · sync pending') : null;
    final below = entries.isEmpty
        ? [?pendingLine]
        : <Widget>[
          if (ring != null) ...[
            const SizedBox(height: 4),
            // The ring announces its words itself.
            if (large)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ring, const SizedBox(height: 8), ExcludeSemantics(child: detailText(calorieDetail!))])
            else
              Row(children: [ring, const SizedBox(width: 14), Expanded(child: ExcludeSemantics(child: detailText(calorieDetail!)))]),
          ],
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
          if (pendingLine != null) ...[const SizedBox(height: 12), pendingLine],
        ];
    // With large text the photograph gives its room to the words.
    final pictured = !large;
    return PanelSurface(
      photo: pictured ? const PanelPhoto(photo, key: Key('eat-photo-nutrition'), alignment: Alignment(0.7, 0)) : null,
      below: below,
      child: LayoutBuilder(
        builder: (context, box) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(constraints: BoxConstraints(maxWidth: pictured ? box.maxWidth * PanelSurface.wordsShare : box.maxWidth), child: words),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      ),
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

  /// [display]: the calorie figure in the serif with its unit ("513 kcal"), as Today's panel shows it, and the goal or
  /// "known" under it. Otherwise one line ("6.4 g protein").
  Widget _metric(BuildContext context, Nutrient n, String label, String unit, int? goal, {required bool display}) {
    final t = coverage[n]!;
    final known = t.hasAnyKnown, partial = known && !t.isComplete;
    final said = n == Nutrient.calories ? 'kilocalories' : 'grams';
    final value = known ? _amount(n, t.knownTotal) : '—';
    final quiet = context.sansStyle(display ? 14 : 17, color: context.c.secondary);
    return Semantics(
      label: '$label ${known ? '${_amount(n, t.knownTotal)} $said' : 'unknown'}'
          '${partial ? ', known from ${t.knownEntries} of ${t.knownEntries + t.unknownEntries} foods' : ''}${goal == null ? '' : ', goal ${_grouped(goal)} $said'}',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (display) ...[
            Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [Text(value, style: context.pageTitleStyle(44)), Text(unit, style: context.pageTitleStyle(44))]),
            if (goal != null || partial) Text(goal == null ? 'known so far' : '/ ${_grouped(goal)} $unit${partial ? ' · known' : ''}', style: quiet),
          ] else
            Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 5, children: [
              Text(value, style: context.numStyle(17, color: context.c.text)),
              Text('${goal == null ? '' : '/ ${_grouped(goal)} '}$unit${partial ? ' · known' : ''}', style: quiet),
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
        _metric(context, Nutrient.calories, 'Calories', 'kcal', calorieGoal, display: true),
        const SizedBox(height: 4),
        _metric(context, Nutrient.protein, 'Protein', 'g protein', proteinGoal, display: false),
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
