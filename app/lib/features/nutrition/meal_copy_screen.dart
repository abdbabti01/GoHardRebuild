import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import 'food_form.dart';
import 'food_repository.dart';
import 'log_food_screen.dart';
import 'meal_copy.dart';
import 'nutrient_coverage.dart';
import 'nutrition_surface.dart' show formatKcal;
import 'saved_meals.dart';
import 'saved_meals_screens.dart';

/// Reviews a copy of one logged meal before it is logged again (docs/MEAL_COPY_WORKOUT_PANEL.md). The destination
/// is always on screen and changeable; the foods are copies of the logged entries, changed for this time only. Only
/// Log this time records anything, once per review. Pops the destination when it was logged.
class MealCopyScreen extends ConsumerStatefulWidget {
  const MealCopyScreen({super.key, required this.source, required this.sourceDay, required this.sourceMeal, required this.day, required this.meal});
  final List<FoodEntry> source;
  final String sourceDay, sourceMeal, day, meal;
  @override
  ConsumerState<MealCopyScreen> createState() => _MealCopyScreenState();
}

class _MealCopyScreenState extends ConsumerState<MealCopyScreen> {
  /// One operation per review: a second tap, or a retry after the first was written, logs nothing more.
  final _op = SyncEngine.newId();
  late String _day = widget.day, _meal = meals.contains(widget.meal) ? widget.meal : meals.first;
  late List<FoodDraft> _items = [for (final e in widget.source) FoodDraft.copy(e, dayKey: widget.day, meal: widget.meal)];
  bool _busy = false;
  String? _error;

  void _replace(int i, FoodDraft d) => setState(() => _items = [..._items]..[i] = d);

  Future<void> _edit(int i) async {
    final d = _items[i];
    switch (copyChange(d)) {
      case CopyChange.amount:
        // The food's own snapshot, scaled by the ordinary form; nothing is looked up again.
        final changed = await push<FoodDraft>(context, FoodFormScreen(draft: d, pick: true));
        if (changed != null && mounted) _replace(i, changed);
      case CopyChange.portion:
        final changed = await _portion(d);
        if (changed != null && mounted) _replace(i, changed);
      case CopyChange.none:
        final l = context.l10n;
        // Never a silent substitute: a matching food only when the person picks one.
        if (await confirm(context, title: l.copyFixedTitle, body: l.copyFixedBody(d.name), action: l.copyChooseFood, cancel: l.copyKeepAsLogged) && mounted) {
          final picked = await push<FoodDraft>(context, LogFoodScreen(dayKey: _day, meal: _meal, pick: true));
          if (picked != null && mounted) _replace(i, picked);
        }
    }
  }

  /// A recipe portion at another amount, from the batch frozen into the logged entry (never the recipe as it is now).
  Future<FoodDraft?> _portion(FoodDraft d) async {
    final r = d.recipe!, recipe = MealBody(r['recipe'] as Json), p = r['portion'] as Json? ?? const {};
    final start = (amount: (p['quantity'] as num?)?.toDouble() ?? 1, measure: p['unit'] == 'g' ? PortionMeasure.gram : PortionMeasure.serving);
    final got = await showDialog<({double amount, PortionMeasure measure})>(
      context: context,
      builder: (_) => _PortionDialog(recipe: recipe, start: start),
    );
    if (got == null || !mounted) return null;
    final l = context.l10n;
    final said = got.measure == PortionMeasure.gram ? l.eatGramsValue(formatNumber2(got.amount)) : l.mealsServingsAmount(got.amount, MealMath.count(got.amount));
    return MealMath.portion(
      recipe,
      amount: got.amount,
      measure: got.measure,
      dayKey: _day,
      meal: _meal,
      amountText: said,
      recipeId: recipe.j['id'] as String?,
      recipeRevision: recipe.j['revision'] as int?,
      name: d.name,
    );
  }

  Future<void> _add() async {
    final d = await push<FoodDraft>(context, LogFoodScreen(dayKey: _day, meal: _meal, pick: true));
    if (d != null && mounted) setState(() => _items = [..._items, d]);
  }

  Future<void> _pickDate() async {
    final today = parseDayKey(ref.read(todayKeyProvider));
    // The existing rule for logging ahead: up to tomorrow.
    final picked = await showDatePicker(context: context, initialDate: parseDayKey(_day), firstDate: DateTime.utc(2020), lastDate: today.add(const Duration(days: 1)));
    if (picked != null) setState(() => _day = dayKeyOf(picked)); // changing the day records nothing
  }

  Future<void> _log() async {
    if (_busy) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_items.isEmpty) throw const InvalidMeal(MealProblem.noComponents);
      await ref
          .read(foodRepositoryProvider)
          .logMeal(
            placed(_items, day: _day, meal: _meal),
            operationId: _op,
          );
      if (mounted) Navigator.pop(context, (day: _day, meal: _meal));
      return;
    } on InvalidMeal catch (e) {
      _error = mealProblemText(l, e.problem);
    } on InvalidFood catch (e) {
      _error = foodProblemText(l, e);
    } on LocalSaveFailure {
      _error = l.foodSaveFailedLocal;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = context.c;
    final supported = ref.watch(savedMealsSupportedProvider);
    final there = [
      for (final r in ref.watch(foodProvider(_day)).value ?? const <Stored<FoodEntry>>[])
        if (!r.value.isDeleted && r.value.meal == _meal) r.value,
    ];
    final same = _day == widget.sourceDay && _meal == widget.sourceMeal;
    final totals = NutrientCoverage.calculate([for (final d in _items) previewEntry(d)]);
    return AppPage(
      title: l.copyTitle,
      subtitle: l.copyFrom(mealLabel(l, widget.sourceMeal), longDate(widget.sourceDay)),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StatusLine(Icons.error_outline, _error!, key: const Key('copy-error'), tone: Tone.error),
            ),
          PrimaryButton(l.mealsLogThisTime, key: const Key('copy-log'), busy: _busy, onPressed: supported && _items.isNotEmpty ? _log : null),
        ],
      ),
      children: [
        if (!supported)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StatusLine(Icons.cloud_off_outlined, l.mealsServerUnavailable, tone: Tone.warning),
          ),
        // Where this goes, always on screen; changing it records nothing.
        Semantics(header: true, child: Text(l.copyTo, style: context.titleStyle(20))),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const Key('copy-meal'),
          initialValue: _meal,
          isExpanded: true,
          dropdownColor: c.surface,
          decoration: InputDecoration(
            labelText: l.foodMealLabel,
            prefixIcon: const Padding(padding: EdgeInsets.all(7), child: IconTile(Icons.restaurant, circle: true, size: 34)),
          ),
          items: [for (final m in meals) DropdownMenuItem(value: m, child: Text(mealLabel(l, m)))],
          onChanged: (m) => setState(() => _meal = m ?? _meal),
        ),
        InkWell(
          key: const Key('copy-date'),
          onTap: _pickDate,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: StatusLine(Icons.event, l.foodForDateTapToChange(longDate(_day)))),
        ),
        if (same)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: StatusLine(Icons.warning_amber_rounded, l.copySame, key: const Key('copy-same'), tone: Tone.warning),
          )
        else if (there.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: StatusLine(Icons.info_outline, l.copyAdds(there.length, mealLabel(l, _meal), longDate(_day)), key: const Key('copy-adds')),
          ),
        const SizedBox(height: 14),
        Semantics(header: true, child: Text(l.mealsFoodsHeading, style: context.titleStyle(20))),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(l.copyFoodsHint, style: context.caption),
        ),
        if (_items.isNotEmpty)
          GroupCard(
            children: [
              for (final (i, d) in _items.indexed)
                GroupRow(
                  key: Key('copy-item-$i'),
                  title: d.name,
                  subtitle: copyChange(d) == CopyChange.none ? '${d.amount} · ${l.copyFixedTag}' : d.amount,
                  value: _kcal(l, previewEntry(d)),
                  onTap: () => _edit(i),
                  trailing: _items.length > 1
                      ? IconButton(
                          key: Key('copy-remove-$i'),
                          tooltip: l.mealsRemoveFood(d.name),
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _items = [..._items]..removeAt(i)),
                        )
                      : null,
                ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('copy-add'),
            onPressed: _items.length >= FoodRepository.maxBatch ? null : _add,
            icon: const Icon(Icons.add),
            label: Text(l.mealsAddFood),
          ),
        ),
        const SizedBox(height: 10),
        MealNutrition(l.mealsThisTimeTotal, totals, key: const Key('copy-totals')),
      ],
    );
  }

  /// One food's calories as the journal says them: a value, a known part ("400 kcal known") or a dash.
  static String _kcal(AppLocalizations l, FoodEntry e) {
    final part = e.partial('calories');
    return e.calories == null && part != null ? l.eatKcalKnown(formatKcal(part)) : l.eatKcalValue(e.calories == null ? '—' : formatKcal(e.calories!));
  }
}

/// How much of a recipe this time: servings of its yield, or grams of the finished batch when it was weighed.
class _PortionDialog extends StatefulWidget {
  const _PortionDialog({required this.recipe, required this.start});
  final MealBody recipe;
  final ({double amount, PortionMeasure measure}) start;
  @override
  State<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends State<_PortionDialog> {
  late final _text = TextEditingController(text: formatNumber2(widget.start.amount));
  late PortionMeasure _measure = widget.start.measure;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  double? get _amount {
    final v = parseNonNegative(_text.text.trim());
    return v == null || !v.isFinite || v <= 0 ? null : v;
  }

  void _measureTo(PortionMeasure to) {
    final now = _amount;
    final converted = now == null ? null : MealMath.convert(widget.recipe, now, _measure, to);
    setState(() {
      if (converted != null) _text.text = formatNumber2(converted);
      _measure = to;
    });
  }

  void _done() {
    final a = _amount;
    if (a == null || MealMath.share(widget.recipe, a, _measure) == null) return setState(() => _error = context.l10n.mealsProblemBadPortion);
    Navigator.pop(context, (amount: a, measure: _measure));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, r = widget.recipe;
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 4,
      title: Text(l.copyPortionTitle(r.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.copyPortionNote, style: context.caption),
            const SizedBox(height: 12),
            if (r.preparedWeightG != null) ...[
              Segmented<PortionMeasure>(
                keyPrefix: 'copy-measure',
                values: PortionMeasure.values,
                selected: _measure,
                label: (m) => m == PortionMeasure.gram ? l.mealsMeasureGrams : l.mealsMeasureServings,
                onChanged: _measureTo,
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              key: const Key('copy-portion'),
              controller: _text,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => _done(),
              decoration: InputDecoration(
                labelText: l.mealsPortionAmount,
                suffixText: _measure == PortionMeasure.gram ? l.eatUnitGram : null,
                helperText: r.servings == null ? null : l.mealsMakesServings(r.servings!, MealMath.count(r.servings!)),
                helperMaxLines: 2,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: StatusLine(Icons.error_outline, _error!, tone: Tone.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(key: const Key('copy-portion-apply'), onPressed: _done, child: Text(l.actionOk)),
      ],
    );
  }
}

/// Other days for [meal]: each earlier day's meal on its own (never a mix), newest first, with saved meals and Add
/// food one tap away. Choosing a day opens its review; nothing is logged here.
Future<void> showMealSources(
  BuildContext context, {
  required String day,
  required String meal,
  required void Function(String sourceDay, List<FoodEntry> entries) onPick,
  required VoidCallback onSaved,
  required VoidCallback onAdd,
}) {
  final l = context.l10n;
  return showGoSheet<void>(
    context,
    title: l.copySourcesTitle(mealLabel(l, meal)),
    builder: (sheet) => Consumer(
      builder: (sheet, ref, _) {
        final journal = ref.watch(foodJournalProvider);
        if (!journal.hasValue) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        final sources = mealSources([for (final r in journal.value!) r.value], before: day, meal: meal);
        return Column(
          key: const Key('copy-sources'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sources.isEmpty) Text(l.copySourcesNone, style: sheet.caption),
            if (sources.isNotEmpty)
              GroupCard(
                children: [
                  for (final s in sources)
                    GroupRow(
                      key: Key('copy-source-${s.day}'),
                      title: longDate(s.day),
                      subtitle: foodNames(l, s.entries),
                      onTap: () {
                        Navigator.pop(sheet);
                        onPick(s.day, s.entries);
                      },
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Wrap(
              children: [
                TextButton.icon(
                  key: const Key('copy-sources-saved'),
                  icon: const Icon(Icons.menu_book_outlined, size: 20),
                  label: Text(l.mealsLibraryTitle),
                  onPressed: () {
                    Navigator.pop(sheet);
                    onSaved();
                  },
                ),
                TextButton.icon(
                  key: const Key('copy-sources-add'),
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(l.eatAddFood),
                  onPressed: () {
                    Navigator.pop(sheet);
                    onAdd();
                  },
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// A meal's foods in their logged order, said briefly: "2 eggs · Egg whites · Baguette", "… +2 more".
String foodNames(AppLocalizations l, List<FoodEntry> entries, {int shown = 3}) {
  final names = [for (final e in entries.take(shown)) e.name];
  return [...names, if (entries.length > shown) l.copyMore(entries.length - shown)].join(' · ');
}
