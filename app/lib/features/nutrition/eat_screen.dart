import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'food_form.dart';
import 'nutrient_coverage.dart';
import 'nutrition_surface.dart';

/// The dated food journal: Breakfast, Lunch, Dinner and Snack, built only from food the user logged.
class EatScreen extends ConsumerStatefulWidget {
  const EatScreen({super.key});
  @override
  ConsumerState<EatScreen> createState() => _EatScreenState();
}

class _EatScreenState extends ConsumerState<EatScreen> {
  /// Null = follow the shared "today"; a picked day stays put when midnight passes.
  String? _picked;

  static String _known(FoodEntry e) {
    final parts = [
      if (e.calories != null) '${formatNumber(e.calories!)} kcal',
      if (e.protein != null) 'P ${formatNumber(e.protein!)} g',
      if (e.carbs != null) 'C ${formatNumber(e.carbs!)} g',
      if (e.fat != null) 'F ${formatNumber(e.fat!)} g',
    ];
    return parts.isEmpty ? 'No nutrition entered' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayKeyProvider);
    final day = _picked ?? today;
    final rows = ref.watch(foodProvider(day));
    final live = [for (final r in rows.value ?? const <Stored<FoodEntry>>[]) if (!r.value.isDeleted) r];
    final entries = [for (final r in live) r.value];
    final pendingCount = live.where((r) => r.isPending).length;

    return RefreshIndicator(
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.inset, 12, context.inset, 28),
        children: [
          Row(children: [
            const Expanded(child: Serif('Eat')),
            IconButton(key: const Key('eat-add'), tooltip: 'Log food', icon: const Icon(Icons.add), onPressed: () => openFoodForm(context, dayKey: day)),
          ]),
          Row(children: [
            IconButton(tooltip: 'Previous day', icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _picked = addDays(day, -1))),
            Expanded(child: Text(day == today ? 'Today · ${longDate(day)}' : longDate(day), textAlign: TextAlign.center, style: context.sansStyle(14, color: context.ec.secondary))),
            IconButton(tooltip: 'Next day', icon: const Icon(Icons.chevron_right), onPressed: day.compareTo(today) >= 0 ? null : () => setState(() => _picked = addDays(day, 1) == today ? null : addDays(day, 1))),
          ]),
          if (day != today) Center(child: TextButton(onPressed: () => setState(() => _picked = null), child: const Text('Back to today'))),
          const SizedBox(height: 8),
          if (rows.hasError)
            const StatusLine(Icons.error_outline, 'Your food journal could not be read from this phone. Pull down to try again.', tone: Tone.error)
          else if (!rows.hasValue)
            const StatusLine(Icons.hourglass_empty, 'Loading your journal…')
          else ...[
            NutritionSurface(entries: entries, coverage: NutrientCoverage.calculate(entries), pending: pendingCount > 0, onLogFood: () => openFoodForm(context, dayKey: day)),
            const SizedBox(height: 26),
            const Serif('Your food journal', size: 27),
            const SizedBox(height: 4),
            Text('Only food you logged as eaten appears here.', style: context.caption),
            for (final meal in meals) ...[
              const SizedBox(height: 20),
              Text(meal, style: context.sansStyle(13, color: context.ec.secondary, weight: FontWeight.w600)),
              if (live.where((r) => r.value.meal == meal).isEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('Nothing logged for ${meal.toLowerCase()}.', style: context.caption)),
              for (final r in live.where((r) => r.value.meal == meal))
                ListRow(
                  key: Key('food-row-${r.value.id}'),
                  title: r.value.name,
                  subtitle: '${r.value.amountDescription} · ${_known(r.value)}${r.needsReview ? ' · needs review' : r.isPending ? ' · sync pending' : ''}',
                  onTap: () => openFoodForm(context, dayKey: day, entry: r.value),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(onPressed: () => openFoodForm(context, dayKey: day, meal: meal), icon: const Icon(Icons.add, size: 18), label: Text('Add to ${meal.toLowerCase()}')),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
