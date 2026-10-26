import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../coach/coach_bubble.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import 'food_item.dart';
import 'food_repository.dart';
import 'food_search.dart';
import 'log_food_screen.dart';
import 'restaurants.dart' show RestaurantOrigin;
import 'saved_meals_screens.dart' show MealReviewScreen;
import 'nutrition_surface.dart' show formatKcal;

/// Why a food could not be saved, in [l]'s language.
String foodProblemText(AppLocalizations l, InvalidFood e) => switch (e.problem) {
      FoodProblem.noName => l.foodProblemNoName,
      FoodProblem.noAmount => l.foodProblemNoAmount,
      FoodProblem.tooLong => l.foodProblemTooLong,
      FoodProblem.noMeal => l.foodProblemNoMeal,
      FoodProblem.noQuantity => l.foodProblemNoQuantity,
      FoodProblem.badValues => l.foodProblemBadValues,
      FoodProblem.badValue => l.foodProblemBadValue(nutrientLabel(l, e.nutrient ?? '')),
      FoodProblem.badSavedName => l.foodProblemBadSavedName,
      FoodProblem.tooLarge => l.foodProblemTooLarge,
      FoodProblem.mealSize => l.mealsProblemTooMany,
    };

/// A nutrient key ("protein") as it is named in [l]'s language ("Protein").
String nutrientLabel(AppLocalizations l, String key) => switch (key) {
      'calories' => l.eatCalories,
      'protein' => l.eatProtein,
      'carbs' => l.eatCarbs,
      'fat' => l.eatFat,
      _ => key,
    };

/// Logging food from Today or Eat. A new entry starts at the place where a food is found (search, scan, saved,
/// recent or manual entry); an existing one opens straight in the form. Either way nothing is logged until the
/// form's own button is pressed, and the user comes back to where they started.
/// A logged recipe portion opens on its own frozen batch instead (features/nutrition/saved_meals_screens.dart).
Future<void> openFoodForm(BuildContext context, {required String dayKey, FoodEntry? entry, String? meal}) => entry == null
    ? push(context, LogFoodScreen(dayKey: dayKey, meal: meal ?? 'Breakfast'))
    : entry.isRecipePortion
        ? push(context, MealReviewScreen.entry(entry))
        : push(context, FoodFormScreen(draft: FoodDraft.edit(entry), existing: entry));

/// The one form every way of finding a food leads to: review the food and its source, say how much, pick the
/// meal and date, then confirm. Pops `true` when an entry was logged or changed.
class FoodFormScreen extends ConsumerStatefulWidget {
  const FoodFormScreen({super.key, required this.draft, this.existing, this.pick = false});

  /// Selection only: confirming pops the reviewed [FoodDraft] (a food for a saved meal or recipe) and logs nothing.
  /// The meal and date are not asked for.
  final bool pick;

  /// The date in this draft was pinned when the form opened. Midnight passing does not change it.
  final FoodDraft draft;
  final FoodEntry? existing;
  @override
  ConsumerState<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends ConsumerState<FoodFormScreen> {
  late final _name = TextEditingController(text: widget.draft.name);
  late final _amount = TextEditingController(text: widget.draft.amount);
  late final _quantity = TextEditingController(text: _text(widget.draft.quantity));
  late final _macros = {for (final e in widget.draft.macros.entries) e.key: TextEditingController(text: _text(e.value))};
  late String _meal = widget.draft.meal, _dayKey = widget.draft.dayKey;
  /// The food being logged. It only ever changes by gaining a portion the user defines here.
  late FoodItem? _item = widget.draft.item;
  late String? _unitId = widget.draft.item == null ? null : FoodScaling.unit(widget.draft.item!, widget.draft.unitId).id;

  /// How much, exactly. The field shows it to two decimals; this is what is converted and scaled, so saying an
  /// amount in another unit and back returns the amount it started as. Typing in the field replaces it.
  late double? _exact = widget.draft.quantity;

  /// Nutrients whose value is the user's own rather than the source's for this amount. Changing the amount
  /// rescales every other value and leaves these alone.
  late final Set<String> _corrected = {
    if (widget.draft.item != null && (widget.draft.quantity ?? 0) > 0)
      for (final e in FoodScaling.scale(widget.draft.item!, widget.draft.quantity!, FoodScaling.unit(widget.draft.item!, widget.draft.unitId)).entries)
        if (widget.draft.macros[e.key] != e.value) e.key,
  };
  String? _error;
  bool _busy = false;

  /// Counts portions defined here, so the unit list is rebuilt with the new one selected.
  int _portions = 0;

  static String _text(double? v) => v == null ? '' : formatNumber2(v);

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _quantity.dispose();
    for (final c in _macros.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Blank → null (unknown). "0" → 0 (a known zero). Anything else must be a non-negative number.
  double? _macro(String key) {
    final raw = _macros[key]!.text.trim();
    if (raw.isEmpty) return null;
    final v = parseNonNegative(raw);
    if (v == null) throw InvalidFood(FoodProblem.badValue, key);
    return v;
  }

  double? get _amountEaten => _exact;

  /// The amount as shown when that is what it is but for float noise (100, not 100.00000000000001); otherwise
  /// the exact amount, whose display is only its rounding (0.63 cup for 100 g of a 158 g cup).
  static double _settled(double q) {
    final shown = double.parse(formatNumber2(q));
    return (shown - q).abs() < 1e-9 ? shown : q;
  }

  /// The source's values for the amount now entered, written into every field the user has not corrected.
  void _rescale() {
    final item = _item, quantity = _amountEaten;
    if (item == null || quantity == null) return;
    final scaled = FoodScaling.scale(item, quantity, FoodScaling.unit(item, _unitId));
    for (final e in scaled.entries) {
      if (!_corrected.contains(e.key)) _macros[e.key]!.text = _text(e.value);
    }
  }

  /// Says the same amount in another unit: 1 serving of 30 g becomes 30 g, never 1 g. Every unit offered for a
  /// food is defined against the same basis, so the conversion always exists; a unit without one is not offered.
  void _changeUnit(String? id) {
    final item = _item, quantity = _amountEaten;
    if (item == null || id == null || id == _unitId) return;
    final from = FoodScaling.unit(item, _unitId), to = FoodScaling.unit(item, id);
    if ((quantity ?? 0) > 0) {
      _exact = _settled(FoodScaling.exact(quantity!, from, to));
      _quantity.text = _text(_exact);
    }
    _unitId = to.id;
    _rescale();
  }

  /// "1 slice = 30 g": a portion of this food in the user's own words and with the user's own measure. It joins
  /// the food's units here and on the copies of this food the user keeps. Nothing is logged by defining it.
  Future<void> _definePortion() async {
    final item = _item;
    if (item == null) return;
    final defined = await showDialog<(String, double)>(context: context, builder: (_) => _PortionDialog(item));
    if (defined == null || !mounted) return;
    final next = FoodScaling.withPortion(item, defined.$1, defined.$2);
    final kept = [for (final r in ref.read(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]) if (!r.value.isDeleted && r.value.item.key == item.key) r.value];
    setState(() {
      _item = next;
      _portions++;
      _changeUnit('serving:${next.servings.length - 1}');
    });
    await _guarded(() async {
      for (final food in kept) {
        await ref.read(savedFoodRepositoryProvider).keepPortions(food, next);
      }
    });
  }

  FoodDraft _draft() {
    final item = _item;
    final quantity = _amountEaten;
    if (item != null && !((quantity ?? 0) > 0)) throw const InvalidFood(FoodProblem.noQuantity);
    return FoodDraft(
        id: widget.draft.id, dayKey: _dayKey, meal: _meal, name: _name.text,
        // Kept as it reads now: a later language change never rewrites a logged amount.
        amount: item == null ? _amount.text : _describe(item, quantity!, ref.read(commonFoodsProvider).value?.of(item)),
        calories: _macro('calories'), protein: _macro('protein'), carbs: _macro('carbs'), fat: _macro('fat'), item: item, quantity: item == null ? null : quantity, unitId: _unitId);
  }

  /// The amount in words, a catalog food's start portion in the app's language.
  String _describe(FoodItem item, double quantity, CommonFood? common) =>
      describeAmount(item, quantity, FoodScaling.unit(item, _unitId), common, foodLang(context.l10n));

  /// Runs one save. Whatever goes wrong, everything typed stays in the fields and nothing claims to be saved.
  Future<bool> _guarded(Future<void> Function() save) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await save();
      return true;
    } on InvalidFood catch (e) {
      if (mounted) setState(() => _error = foodProblemText(context.l10n, e));
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = context.l10n.foodSaveFailedLocal);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<void> _save() async {
    if (_busy) return; // a second tap while the first is saving must not log the food twice
    if (widget.pick) {
      FoodDraft? chosen;
      if (await _guarded(() async => FoodRepository.validate(chosen = _draft())) && mounted) Navigator.pop(context, chosen);
      return;
    }
    if (await _guarded(() => ref.read(foodRepositoryProvider).save(_draft())) && mounted) Navigator.pop(context, true);
  }

  SavedFood? _saved({required bool mine}) {
    final item = _item;
    for (final r in ref.read(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]) {
      if (r.value.isDeleted || item == null || r.value.item.key != item.key) continue;
      if (mine ? r.value.isMine : r.value.isFavourite) return r.value;
    }
    return null;
  }

  /// Keeps this food for next time. It is not eaten by being kept: no journal entry is written.
  Future<void> _saveReusable() async {
    final ok = await _guarded(() async {
      final d = _draft();
      FoodRepository.validate(d);
      final mine = _saved(mine: true);
      await ref.read(savedFoodRepositoryProvider).saveMine(
          id: mine?.id, name: d.name, values: d.macros, from: d.item, quantity: d.quantity, unitId: d.unitId, amount: d.amount, isFavourite: mine?.isFavourite ?? false);
    });
    if (ok && mounted) toast(context, context.l10n.foodSavedToMine);
  }

  Future<void> _toggleFavourite() async {
    final item = _item;
    if (item == null) return;
    final existing = _saved(mine: false) ?? _saved(mine: true);
    await _guarded(() => existing?.isFavourite ?? false
        ? ref.read(savedFoodRepositoryProvider).unfavourite(existing!)
        : ref.read(savedFoodRepositoryProvider).favourite(item, existing: existing));
  }

  Future<void> _remove() async {
    final e = widget.existing!;
    final l = context.l10n;
    if (!await confirm(context, title: l.foodRemoveTitle(e.name), body: l.foodRemoveBody(e.name, e.amountDescription, mealLabel(l, e.meal), longDate(e.dayKey)), action: l.foodRemoveAction)) return;
    await ref.read(foodRepositoryProvider).remove(e);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: parseDayKey(_dayKey), firstDate: DateTime.utc(2020), lastDate: parseDayKey(ref.read(todayKeyProvider)).add(const Duration(days: 1)));
    if (picked != null) setState(() => _dayKey = dayKeyOf(picked));
  }

  /// The source in full (provider title, values per basis, brand, credit, barcode), on demand.
  void _details(FoodItem item) => showGoSheet<void>(context, title: context.l10n.foodDetailsTitle, builder: (_) => FoodSourceCard(item));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = foodLang(l);
    final editing = widget.existing != null;
    final item = _item;
    final common = item == null ? null : ref.watch(commonFoodsProvider).value?.of(item);
    final favourite = item != null && (ref.watch(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]).any((r) => !r.value.isDeleted && r.value.isFavourite && r.value.item.key == item.key);
    // "2 eggs (100 g)": what will be logged, in words. Null until there is a food and an amount above zero.
    String? amountLine;
    if (item != null && (_amountEaten ?? 0) > 0) {
      amountLine = _describe(item, _amountEaten!, common);
    }
    final unit = item == null ? null : FoodScaling.unit(item, _unitId);
    // A unit's label as its source gives it, except a catalog food's start portion, said in the app's language.
    String named(FoodUnit u) => u.label == common?.portion ? common!.portionIn(lang)! : u.label;
    // "1 egg = 50 g": what one of the chosen unit is, said only when its source (or the user) states it.
    final definition = unit == null || unit.size == null || unit.label.contains(unit.size!) ? null : '${named(unit)} = ${unit.size}';
    final title = editing ? l.foodEditTitle : item == null ? l.foodNewTitle : (widget.draft.name.trim().isEmpty ? item.name : widget.draft.name);
    final qualifier = editing ? widget.draft.name : item == null ? null : common?.qualifierIn(lang) ?? item.brand;
    final missing = [if (item != null) for (final k in FoodItem.nutrientKeys) if (item.nutrient(k) == null) nutrientLabel(l, k).toLowerCase()];
    // Side by side, or one under the other when the text is large or the phone narrow.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 350;

    // One line of the read-out: the value is its own field, so tapping it corrects it. Blank reads as a dash.
    Widget macro(String key, String label, String suffix) {
      // The visible label is read as the field's own label.
      final field = Semantics(label: label, child: TextField(
        key: Key('food-$key'), controller: _macros[key], keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: stacked ? TextAlign.start : TextAlign.end, style: context.numStyle(17),
        onChanged: (_) => setState(() => _corrected.add(key)),
        decoration: InputDecoration(
          filled: false, hintText: '—', suffixText: suffix, contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none, enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.c.accent, width: 2)),
        ),
      ));
      final name = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: Text(label, style: context.sansStyle(16, color: context.c.secondary))),
        if (item != null && _corrected.contains(key)) Text(l.foodYourValue, style: context.sansStyle(13, color: context.c.accent, weight: FontWeight.w600)),
      ]);
      return Padding(
          padding: EdgeInsets.fromLTRB(16, stacked ? 10 : 0, 16, 0),
          child: stacked
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [name, field])
              : Row(children: [Expanded(child: name), SizedBox(width: 140, child: field)]),
      );
    }

    Widget pair(Widget a, Widget b) => stacked ? Column(children: [a, const SizedBox(height: 12), b]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: a), const SizedBox(width: 10), Expanded(flex: 3, child: b)]);
    final nameField = TextField(key: const Key('food-name'), controller: _name, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: item == null ? l.foodWhatDidYouEat : l.foodNameInJournal));

    final mealAndDate = [
      DropdownButtonFormField<String>(
        key: const Key('food-meal'), initialValue: _meal, isExpanded: true, dropdownColor: context.c.surface,
        decoration: InputDecoration(labelText: l.foodMealLabel, prefixIcon: const Padding(padding: EdgeInsets.all(7), child: IconTile(Icons.restaurant, circle: true, size: 34))),
        items: [for (final m in meals) DropdownMenuItem(value: m, child: Text(mealLabel(l, m)))],
        onChanged: (m) => setState(() => _meal = m ?? _meal),
      ),
      InkWell(
        onTap: _pickDate,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: StatusLine(Icons.event, l.foodForDateTapToChange(longDate(_dayKey)))),
      ),
    ];

    // A food from a source is headed by a compact panel (no photograph: there is none of this food), which is also
    // the way into its details. A food typed in by hand keeps the plain page title.
    final shownName = editing ? widget.draft.name : title;
    final header = item == null
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Heading(title, size: 36, serif: true),
            if (qualifier != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(qualifier, style: context.sansStyle(16, color: context.c.secondary))),
          ])
        : _FoodHeader(item, name: shownName, overline: editing ? l.foodEditTitle : null, qualifier: editing ? null : qualifier, onTap: () => _details(item));

    return _FormPage(
      header: header,
      actions: [
        if (item != null) CoachHelpEntry(id: 'food.portion', label: l.foodHelpPortions),
        if (item != null && !editing)
          IconButton(
            key: const Key('food-favourite'), tooltip: favourite ? l.foodFavouriteRemove : l.foodFavouriteAdd,
            icon: Icon(favourite ? Icons.star : Icons.star_border, color: favourite ? context.c.accent : null), onPressed: _toggleFavourite,
          ),
      ],
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        PrimaryButton(widget.pick ? l.mealsUseAmount : editing ? l.foodSaveChanges : l.foodLogButton, key: const Key('food-save'), onPressed: _save, busy: _busy),
        TextButton(key: const Key('food-cancel'), onPressed: () => Navigator.pop(context), child: Text(editing ? l.foodCancelKeep : l.actionCancel)),
      ]),
      children: [
        if (item == null) ...[nameField, const SizedBox(height: 14), if (!widget.pick) ...mealAndDate],
        if (item != null) ...[
          pair(
            TextField(
              key: const Key('food-quantity'), controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.done,
              style: context.numStyle(18),
              onChanged: (v) => setState(() {
                _exact = parseNonNegative(v);
                _rescale();
              }),
              decoration: InputDecoration(labelText: l.foodAmountLabel),
            ),
            KeyedSubtree(
              key: const Key('food-unit'),
              child: DropdownButtonFormField<String>(
                key: ValueKey(_portions), initialValue: _unitId, isExpanded: true, decoration: InputDecoration(labelText: l.foodPortionLabel), dropdownColor: context.c.surface,
                // The closed field shows the unit's name; the open list adds what one of them weighs.
                selectedItemBuilder: (_) => [
                  for (final u in FoodScaling.units(item)) Text(named(u) != u.label ? named(u) : u.noun == null ? u.label : '${u.noun}${u.tail}', overflow: TextOverflow.ellipsis),
                ],
                items: [
                  for (final u in FoodScaling.units(item))
                    DropdownMenuItem(key: Key('food-unit-${u.id}'), value: u.id, child: Text(named(u) != u.label ? [named(u), ?u.size].join(' · ') : u.menuLabel)),
                ],
                onChanged: (u) => setState(() => _changeUnit(u)),
              ),
            ),
          ),
          if (definition != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(definition, key: const Key('food-unit-definition'), style: context.caption)),
          // The amount in full, with its weight when the food states one, so the number and unit are read together,
          // and what it brings as the fields below say now.
          if (amountLine != null) Padding(padding: const EdgeInsets.only(top: 14), child: _Logging(amountLine, calories: _macros['calories']!.text, protein: _macros['protein']!.text)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('food-add-portion'), onPressed: _busy ? null : _definePortion, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              iconAlignment: IconAlignment.end, icon: const Icon(Icons.chevron_right, size: 20), label: Text(l.foodAddPortion),
            ),
          ),
          CoachSpot(
            id: 'food.portion', introduce: FoodScaling.units(item).length > 1, padding: const EdgeInsets.only(top: 4, bottom: 10),
            say: CoachSay(l.foodPortionCoach),
          ),
          const SizedBox(height: 8),
          if (!widget.pick) ...[...mealAndDate, const Rule()],
        ] else ...[
          TextField(key: const Key('food-amount'), controller: _amount, textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l.foodHowMuch, helperText: l.foodHowMuchHelper)),
        ],
        const SizedBox(height: 18),
        // The amount is spelled out with its unit: "1 g" and "1 cup" look the same in the number field alone.
        Semantics(header: true, child: Text(amountLine == null ? l.foodNutritionHeading : l.foodNutritionFor(amountLine), key: const Key('food-amount-echo'), style: context.titleStyle(20))),
        const SizedBox(height: 4),
        Text(item == null ? l.foodNutritionOptional : l.foodNutritionFromSource, style: context.caption),
        const SizedBox(height: 12),
        GroupCard(children: [
          macro('calories', l.eatCalories, l.eatUnitKcal), macro('protein', l.eatProtein, l.eatUnitGram), macro('carbs', l.eatCarbs, l.eatUnitGram), macro('fat', l.eatFat, l.eatUnitGram),
        ]),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: StatusLine(Icons.help_outline, l.foodSourceMissing(missing.length, missing.join(l.eatListSeparator))),
          ),
        if (item != null && _corrected.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('food-reset-values'),
              onPressed: () => setState(() {
                _corrected.clear();
                _rescale();
              }),
              child: Text(l.foodUseSourceValues),
            ),
          ),
        if (item != null) ...[const SizedBox(height: 18), nameField],
        const SizedBox(height: 10),
        if (!editing)
          Align(
            alignment: AlignmentDirectional.centerStart,
            // Plain text, so a long label wraps at large text sizes instead of running off a narrow phone.
            child: TextButton(key: const Key('food-save-reusable'), onPressed: _busy ? null : _saveReusable, child: Text(l.foodSaveToMine)),
          ),
        if (editing)
          Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(key: const Key('food-remove'), onPressed: _remove, icon: const Icon(Icons.delete_outline, size: 18), label: Text(l.foodRemoveAction))),
      ],
    );
  }
}

/// The page around the form: back and the app bar's actions, the [header], then one scroll view whose fields all
/// stay built while the keyboard shrinks the page, and the pinned [bottom] action riding above the keyboard (as
/// [AppPage] does for a form, with a header that is not only a title).
class _FormPage extends StatelessWidget {
  const _FormPage({required this.header, required this.actions, required this.bottom, required this.children});
  final Widget header, bottom;
  final List<Widget> actions, children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(actions: actions),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 28), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: 18), ...children]),
              ),
            ),
            Padding(padding: EdgeInsets.fromLTRB(context.inset, 8, context.inset, 12), child: bottom),
          ]),
        ),
      );
}

/// The food being logged, as a compact panel in the approved look with no photograph (there is no licensed picture
/// of each food): its name in the serif, what tells it apart, the provider's own title when the page is headed by the
/// everyday name, and who the values come from. A tap opens Food details, the source in full.
class _FoodHeader extends StatelessWidget {
  const _FoodHeader(this.item, {required this.name, required this.onTap, this.overline, this.qualifier});
  final FoodItem item;
  final String name;
  final String? overline, qualifier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PanelTheme(
      child: Builder(
        builder: (context) => PanelSurface(
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              button: true, hint: l.foodShowsDetailsHint,
              child: InkWell(
                key: const Key('food-source'), onTap: onTap,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 12, 16),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        if (overline != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Overline(overline!)),
                        Semantics(header: true, child: Text(name, style: context.pageTitleStyle(32))),
                        if (qualifier != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(qualifier!, style: context.sansStyle(15.5, color: context.c.secondary, weight: FontWeight.w500))),
                        // The provider's own title, when the page is headed by the everyday name.
                        if (item.name != name) Padding(padding: const EdgeInsets.only(top: 2), child: Text(item.name, style: context.caption)),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(_credits(l, item).join(' · '), style: context.caption),
                        ),
                      ]),
                    ),
                    Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Icon(Icons.chevron_right, size: 24, color: context.c.secondary)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Source: USDA FoodData Central", "Barcode 0123…": the provider's name and the code stay as they are.
List<String> _credits(AppLocalizations l, FoodItem item) {
  final credit = sourceCredit(item);
  return [credit != null ? l.foodSource(credit) : l.foodYourOwn, if (item.barcode != null) l.foodBarcode(ltr(item.barcode!))];
}

/// "You're logging 2 eggs (100 g)", with the energy and protein the fields below hold now. A blank field is
/// unknown and shows a dash, never a zero.
class _Logging extends StatelessWidget {
  const _Logging(this.amount, {required this.calories, required this.protein});
  final String amount, calories, protein;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kcal = parseNonNegative(calories.trim()), grams = parseNonNegative(protein.trim());
    final g = grams == null ? null : formatNumber((grams * 10).round() / 10);
    Widget cell(String value, String label, String said) => MergeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(value, semanticsLabel: said, style: context.titleStyle(20)),
            Text(label, style: context.caption),
          ]),
        );
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.foodYoureLogging, style: context.sansStyle(14.5, color: context.c.secondary, weight: FontWeight.w500)),
        Text(amount, key: const Key('food-amount-line'), style: context.pageTitleStyle(26)),
        const SizedBox(height: 10),
        Wrap(spacing: 28, runSpacing: 8, children: [
          cell(kcal == null ? '—' : l.eatKcalValue(formatKcal(kcal)), l.foodEnergy, kcal == null ? l.foodUnknownSaid : l.foodKcalSaid(formatKcal(kcal))),
          cell(g == null ? '—' : l.eatGramsValue(g), l.eatProtein, g == null ? l.foodUnknownSaid : l.foodGramsSaid(g)),
        ]),
      ]),
    );
  }
}

/// Asks for one portion of a food in the user's own terms. It returns the name and the amount, and changes nothing
/// by itself. No amount is suggested: a weight is never guessed from what the food or the portion is called.
class _PortionDialog extends StatefulWidget {
  const _PortionDialog(this.item);
  final FoodItem item;
  @override
  State<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends State<_PortionDialog> {
  final _name = TextEditingController(), _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _add() {
    final l = context.l10n;
    final name = _name.text.trim(), amount = parseNonNegative(_amount.text);
    // Letters of any of the app's languages ("tranche", "شريحة"), a word or two.
    if (!RegExp(r'^\p{L}[\p{L}\p{M} \-]{0,23}$', unicode: true).hasMatch(name)) return setState(() => _error = l.foodPortionNameInvalid);
    if (FoodScaling.units(widget.item).any((u) => u.label.toLowerCase() == '1 ${name.toLowerCase()}')) return setState(() => _error = l.foodPortionExists(name));
    if (!((amount ?? 0) > 0) || amount! > 100000) return setState(() => _error = l.foodPortionAmountInvalid(name));
    Navigator.pop(context, (name, amount));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final measure = FoodScaling.portionMeasure(widget.item);
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
      title: Text(l.foodAddPortion),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.foodPortionFor(widget.item.name), style: context.caption),
          const SizedBox(height: 14),
          TextField(key: const Key('portion-name'), controller: _name, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: l.foodPortionCalled, hintText: l.foodPortionHint)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('portion-amount'), controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), onSubmitted: (_) => _add(),
            decoration: InputDecoration(labelText: l.foodPortionHowMuch, suffixText: measure),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(key: const Key('portion-add'), onPressed: _add, child: Text(l.foodAddPortionButton)),
      ],
    );
  }
}

/// What the food is and where its values come from: the provider's full title, brand, values on their stated
/// basis, credit and barcode. Shown in the Food details sheet of the form.
class FoodSourceCard extends StatelessWidget {
  const FoodSourceCard(this.item, {super.key});
  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final about = [if (item.brand != null) item.brand!, if (item.description != null) item.description!].join(' · ');
    String? value(String k) => item.nutrient(k) == null ? null : formatNumber2(item.nutrient(k)!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (item.imageUrl != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.tile),
                // The photo is decoration; the name beside it says the same thing, and a failed load shows nothing.
                child: Image.network(item.imageUrl!, width: 56, height: 56, fit: BoxFit.cover, excludeFromSemantics: true, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: context.titleStyle(18)),
              if (about.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(about, style: context.caption)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(l.foodNutritionBasis(FoodScaling.basisText(item, l)), style: context.label),
        const SizedBox(height: 4),
        Semantics(
          label: [
            for (final k in FoodItem.nutrientKeys)
              value(k) == null ? l.eatNutrientUnknownSaid(nutrientLabel(l, k)) : k == 'calories' ? l.eatSaidKcal(nutrientLabel(l, k), value(k)!) : l.eatSaidGrams(nutrientLabel(l, k), value(k)!),
          ].join(l.eatListSeparator),
          child: ExcludeSemantics(
            child: Wrap(spacing: 14, runSpacing: 4, children: [
              for (final k in FoodItem.nutrientKeys)
                Text(l.eatNutrientSaid(nutrientLabel(l, k), value(k) == null ? '—' : k == 'calories' ? l.eatKcalValue(value(k)!) : l.eatGramsValue(value(k)!)), style: context.sansStyle(15)),
            ]),
          ),
        ),
        // A restaurant item: what its source says the standard item includes, and the values it states beyond the four.
        if (RestaurantOrigin.of(item) case final r?) ...[
          if ([('sodiumMg', 'mg', l.eatOutSodiumLabel), ('fibreG', 'g', l.eatOutFibreLabel), ('satFatG', 'g', l.eatOutSatFatLabel)].where((e) => r.extra(e.$1) != null).toList() case final extra when extra.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(extra.map((e) => '${e.$3} ${formatNumber2(r.extra(e.$1)!)} ${e.$2}').join(' · '), style: context.sansStyle(15)),
            ),
          if (r.build != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.eatOutBuildNote(ltr(r.build!)), style: context.caption)),
        ],
        const SizedBox(height: 10),
        Text([..._credits(l, item), if (item.imageUrl != null && item.imageAttribution != null) item.imageAttribution!].join(' · '), style: context.caption),
      ]);
  }
}
