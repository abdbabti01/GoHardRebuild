import 'dart:convert';

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
import '../coach/coach_bubble.dart';
import 'food_form.dart';
import 'food_repository.dart';
import 'food_search.dart';
import 'log_food_screen.dart';
import 'nutrient_coverage.dart';
import 'nutrition_surface.dart' show formatKcal;
import 'saved_meals.dart';
import 'water.dart' show nutritionDisplayProvider;

/// Saved meals & recipes, opened for [dayKey] and [meal] (the meal a log starts on; the review can change it). Pops
/// `true` when something was logged from it. Opening, browsing and editing log nothing.
Future<bool?> openMealsLibrary(BuildContext context, {required String dayKey, required String meal}) =>
    push<bool>(context, MealsLibraryScreen(dayKey: dayKey, meal: meal));

/// A saved meal's editor, started from foods already logged together ("Save as meal"). Their snapshots and amounts
/// are copied; nothing is logged again, and the logged foods are not tied to the new meal.
Future<void> saveAsMeal(BuildContext context, {required String dayKey, required String meal, required List<FoodEntry> entries}) =>
    push(context, MealEditorScreen(dayKey: dayKey, start: MealBody({'kind': MealBody.meal, 'name': mealLabel(context.l10n, meal), 'components': [for (final e in entries) MealComponent.fromEntry(e).j]})));

String mealProblemText(AppLocalizations l, MealProblem p) => switch (p) {
      MealProblem.noName => l.mealsProblemNoName,
      MealProblem.nameTooLong => l.mealsProblemNameTooLong,
      MealProblem.noComponents => l.mealsProblemNoFoods,
      MealProblem.tooManyComponents => l.mealsProblemTooMany,
      MealProblem.badQuantity => l.mealsProblemBadQuantity,
      MealProblem.badServings => l.mealsProblemBadServings,
      MealProblem.badWeight => l.mealsProblemBadWeight,
      MealProblem.tooLarge => l.mealsProblemTooLarge,
      MealProblem.badMultiplier => l.mealsProblemBadMultiplier,
      MealProblem.badPortion => l.mealsProblemBadPortion,
    };

/// Calories as the truth allows: a total, a sum of what is known, or unknown. Never a partial sum shown as a total.
String kcalText(AppLocalizations l, NutrientTotal t) =>
    !t.hasAnyKnown ? l.eatCaloriesUnknown : t.isComplete ? l.eatKcalValue(formatKcal(t.knownTotal)) : l.eatKcalKnown(formatKcal(t.knownTotal));

/// "540 kcal", "1 serving (300 g)": what a picked food is called in the app's language.
String _describe(WidgetRef ref, AppLocalizations l, MealComponent c, double quantity) =>
    describeAmount(c.item, quantity, c.unit, ref.read(commonFoodsProvider).value?.of(c.item), foodLang(l));

/// Runs one save or log, turning what can go wrong into words on the page. Whatever fails, the input stays.
Future<bool> _attempt(BuildContext context, void Function(String?) error, Future<void> Function() run) async {
  error(null);
  try {
    await run();
    return true;
  } on InvalidMeal catch (e) {
    if (context.mounted) error(mealProblemText(context.l10n, e.problem));
  } on InvalidFood catch (e) {
    if (context.mounted) error(foodProblemText(context.l10n, e));
  } on LocalSaveFailure {
    if (context.mounted) error(context.l10n.foodSaveFailedLocal);
  }
  return false;
}

// ---------------------------------------------------------------------------- library

class MealsLibraryScreen extends ConsumerStatefulWidget {
  const MealsLibraryScreen({super.key, required this.dayKey, required this.meal});
  final String dayKey, meal;
  @override
  ConsumerState<MealsLibraryScreen> createState() => _MealsLibraryScreenState();
}

class _MealsLibraryScreenState extends ConsumerState<MealsLibraryScreen> {
  final _query = TextEditingController();
  String _kind = MealBody.meal;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _review(Stored<SavedMeal> m) async {
    // The review works on a copy taken now: an edit arriving from another phone never changes what is being reviewed.
    final logged = await push<bool>(context, MealReviewScreen(body: MealBody(copyJson(m.value.body.j)), saved: m.value, dayKey: widget.dayKey, meal: widget.meal));
    if (logged == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _delete(SavedMeal m) async {
    final l = context.l10n;
    if (!await confirm(context, title: l.mealsDeleteTitle(m.body.name), body: l.mealsDeleteBody, action: l.actionDelete, destructive: true)) return;
    await ref.read(savedMealRepositoryProvider).remove(m);
    if (mounted) toast(context, context.l10n.mealsDeleted);
  }

  void _edit({SavedMeal? saved, MealBody? start, String? draftKey, String? kind}) =>
      push(context, MealEditorScreen(dayKey: widget.dayKey, saved: saved, start: start, draftKey: draftKey, kind: kind ?? _kind));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final recipes = _kind == MealBody.recipe;
    final all = [for (final r in ref.watch(savedMealsProvider).value ?? const <Stored<SavedMeal>>[]) if (!r.value.isDeleted && r.value.body.kind == _kind) r]
      ..sort((a, b) => a.value.body.name.toLowerCase().compareTo(b.value.body.name.toLowerCase()));
    final q = normalizeSearch(_query.text);
    final shown = q.isEmpty ? all : [for (final r in all) if (normalizeSearch(r.value.body.name).contains(q)) r];
    final drafts = ref.watch(mealDraftsProvider).value ?? const <String, MealBody>{};
    final unsavedNew = [for (final e in drafts.entries) if (e.key.startsWith('new:') && e.value.kind == _kind) e];
    final supported = ref.watch(savedMealsSupportedProvider);
    final helpId = recipes ? 'meals.recipes' : 'meals.library';

    return AppPage(
      title: l.mealsLibraryTitle,
      subtitle: l.mealsForContext(mealLabel(l, widget.meal), longDate(widget.dayKey)),
      actions: [CoachHelpEntry(id: helpId, label: l.mealsHelpLabel)],
      children: [
        CoachSpot(key: ValueKey(helpId), id: helpId, introduce: true, padding: const EdgeInsets.only(bottom: 12), say: CoachSay(recipes ? l.mealsCoachRecipe : l.mealsCoachLibrary)),
        if (!supported) Padding(padding: const EdgeInsets.only(bottom: 12), child: StatusLine(Icons.cloud_off_outlined, l.mealsServerUnavailable, key: const Key('meals-unsupported'), tone: Tone.warning)),
        Segmented<String>(
          keyPrefix: 'meals-tab', values: const [MealBody.meal, MealBody.recipe], selected: _kind,
          label: (k) => k == MealBody.recipe ? l.mealsTabRecipes : l.mealsTabMeals, onChanged: (k) => setState(() => _kind = k),
        ),
        const SizedBox(height: 14),
        SecondaryButton(recipes ? l.mealsNewRecipe : l.mealsNewMeal, key: const Key('meals-new'), icon: Icons.add, onPressed: () => _edit()),
        if (all.length > 3) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('meals-search'), controller: _query, onChanged: (_) => setState(() {}), textInputAction: TextInputAction.search,
            decoration: InputDecoration(hintText: l.mealsSearchHint, prefixIcon: const Icon(Icons.search)),
          ),
        ],
        const SizedBox(height: 14),
        if (unsavedNew.isNotEmpty) ...[
          GroupCard(children: [
            for (final d in unsavedNew)
              GroupRow(
                key: Key('meals-draft-${d.key}'), icon: Icons.edit_note, title: d.value.name.trim().isEmpty ? l.mealsUntitled : d.value.name, subtitle: l.mealsUnsavedDraft,
                onTap: () => _edit(draftKey: d.key, kind: d.value.kind),
              ),
          ]),
          const SizedBox(height: 12),
        ],
        if (all.isEmpty && unsavedNew.isEmpty)
          EmptyState(recipes ? l.mealsEmptyRecipesTitle : l.mealsEmptyMealsTitle, recipes ? l.mealsEmptyRecipesBody : l.mealsEmptyMealsBody, key: const Key('meals-empty'))
        else if (shown.isEmpty && all.isNotEmpty)
          StatusLine(Icons.search_off, l.mealsNoMatch(_query.text.trim()))
        else if (shown.isNotEmpty)
          GroupCard(children: [
            for (final r in shown)
              _SavedRow(r, draft: drafts.containsKey(r.value.id), onTap: () => _review(r), onEdit: () => _edit(saved: r.value),
                  onDuplicate: () => _edit(start: r.value.body.copyWith(name: l.mealsCopyName(r.value.body.name))), onDelete: () => _delete(r.value)),
          ]),
      ],
    );
  }
}

/// One saved meal or recipe: its name, how many foods, and a truthful energy line ("540 kcal", "400 kcal known").
/// The row opens the log review (nothing is logged there until Log); the menu holds Edit, Duplicate and Delete.
class _SavedRow extends StatelessWidget {
  const _SavedRow(this.r, {required this.draft, required this.onTap, required this.onEdit, required this.onDuplicate, required this.onDelete});
  final Stored<SavedMeal> r;
  final bool draft;
  final VoidCallback onTap, onEdit, onDuplicate, onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = r.value.body;
    final n = b.components.length;
    final kcal = b.totals[Nutrient.calories]!;
    final facts = b.isRecipe
        ? [l.mealsIngredientsCount(n), if (b.servings != null) l.mealsMakesServings(b.servings!, MealMath.count(b.servings!)), if (b.servings != null) l.mealsPerServing(kcalText(l, kcal.times(1 / b.servings!)))]
        : [l.mealsFoodsCount(n), kcalText(l, kcal)];
    final status = [if (draft) l.mealsUnsavedDraft, if (r.needsReview) l.eatNeedsReview else if (r.isPending) l.eatSyncPendingShort];
    return GroupRow(
      key: Key('meals-row-${r.value.id}'), icon: b.isRecipe ? Icons.soup_kitchen_outlined : Icons.restaurant_menu, title: b.name,
      subtitle: [...facts, ...status].join(' · '), onTap: onTap,
      trailing: PopupMenuButton<int>(
        key: Key('meals-menu-${r.value.id}'), tooltip: l.mealsMenuLabel(b.name), color: context.c.surface,
        onSelected: (i) => [onEdit, onDuplicate, onDelete][i](),
        itemBuilder: (_) => [
          PopupMenuItem(key: const Key('meals-menu-edit'), value: 0, child: Text(l.actionEdit)),
          PopupMenuItem(key: const Key('meals-menu-duplicate'), value: 1, child: Text(l.mealsDuplicate)),
          PopupMenuItem(key: const Key('meals-menu-delete'), value: 2, child: Text(l.actionDelete, style: TextStyle(color: context.c.error))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------- shared pieces

/// One food of a meal or recipe: its name, its amount and its energy; tapping it changes the amount in the shared
/// amount form, the remove button takes it out. Neither logs anything.
class _ComponentRow extends StatelessWidget {
  const _ComponentRow(this.c, {required this.index, required this.onTap, required this.onRemove});
  final MealComponent c;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kcal = c.values['calories'];
    return GroupRow(
      key: Key('meal-part-$index'), title: c.name, subtitle: c.amount, value: kcal == null ? l.eatKcalValue('—') : l.eatKcalValue(formatKcal(kcal)), onTap: onTap,
      trailing: onRemove == null ? null : IconButton(key: Key('meal-part-remove-$index'), tooltip: l.mealsRemoveFood(c.name), icon: const Icon(Icons.close), onPressed: onRemove),
    );
  }
}

/// Calories, protein, carbs and fat for a whole meal, a batch or a portion: a total, a sum labelled "known", or a dash.
/// A note says so when some food has no value: a partial sum is never shown as a total.
class _Nutrition extends ConsumerWidget {
  const _Nutrition(this.title, this.totals, {super.key, this.note = true});

  /// Whether the missing-values note is said here (once per page).
  final bool note;
  final String title;
  final Map<Nutrient, NutrientTotal> totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final display = ref.watch(nutritionDisplayProvider);
    String grams(NutrientTotal t) => !t.hasAnyKnown ? '—' : t.isComplete ? l.eatGramsValue(formatNumber(_r1(t.knownTotal))) : '${l.eatGramsValue(formatNumber(_r1(t.knownTotal)))} · ${l.eatKnown}';
    final lines = [
      (l.eatCalories, totals[Nutrient.calories]!, true),
      (l.eatProtein, totals[Nutrient.protein]!, false),
      if (display.carbs) (l.eatCarbs, totals[Nutrient.carbs]!, false),
      if (display.fat) (l.eatFat, totals[Nutrient.fat]!, false),
    ];
    final missing = note && totals.values.any((t) => t.unknownEntries > 0);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, child: Text(title, style: context.titleStyle(18))),
        const SizedBox(height: 8),
        Wrap(spacing: 24, runSpacing: 8, children: [
          for (final (label, t, kcal) in lines)
            MergeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: context.caption),
                Text(kcal ? (t.hasAnyKnown ? kcalText(l, t) : '—') : grams(t), semanticsLabel: t.hasAnyKnown ? null : l.eatNutrientUnknownSaid(label), style: context.sansStyle(16, weight: FontWeight.w600)),
              ]),
            ),
        ]),
        if (missing) Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.info_outline, l.mealsSomeMissing)),
      ]),
    );
  }

  static double _r1(double v) => (v * 10).roundToDouble() / 10;
}

/// Picks one food for a meal or recipe through Add food in its selection mode, then the shared amount form. Logs nothing.
Future<MealComponent?> _pick(BuildContext context, {required String dayKey}) async {
  final d = await push<FoodDraft>(context, LogFoodScreen(dayKey: dayKey, meal: meals.first, pick: true));
  return d == null ? null : MealComponent.ofDraft(d);
}

/// Changes one food's amount (and unit) in the shared amount form, in its selection mode. Logs nothing.
Future<MealComponent?> _change(BuildContext context, MealComponent c, {required String dayKey}) async {
  final d = await push<FoodDraft>(context, FoodFormScreen(draft: c.draft(dayKey: dayKey, meal: meals.first), pick: true));
  return d == null ? null : MealComponent.ofDraft(d);
}

/// A positive number in any of the app's languages ("1,5", "١٫٥"); null when it is not one.
double? _positive(String raw) {
  final v = parseNonNegative(raw.trim());
  return v == null || !v.isFinite || v <= 0 ? null : v;
}

// ---------------------------------------------------------------------------- editor

/// The definition of a saved meal or a recipe: its name, its foods and amounts, and for a recipe the servings the whole
/// batch makes and (optionally) the finished batch's weight. Save is the one main action; nothing here logs food.
/// Every change is kept as this account's draft on the phone at once, so leaving, a language change or a restart
/// loses nothing; only Discard changes throws it away.
class MealEditorScreen extends ConsumerStatefulWidget {
  const MealEditorScreen({super.key, required this.dayKey, this.saved, this.start, this.draftKey, this.kind = MealBody.meal});

  /// Editing this definition; null for a new one.
  final SavedMeal? saved;

  /// A new one prefilled (Save as meal, Duplicate).
  final MealBody? start;

  /// An unsaved new one to carry on with.
  final String? draftKey;
  final String kind, dayKey;
  @override
  ConsumerState<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends ConsumerState<MealEditorScreen> {
  late final String _key = widget.draftKey ?? widget.saved?.id ?? 'new:${SyncEngine.newId()}';
  late final SavedMealRepository _repo = ref.read(savedMealRepositoryProvider);
  final _name = TextEditingController(), _servings = TextEditingController(), _weight = TextEditingController();
  late String _kind = widget.saved?.body.kind ?? widget.start?.kind ?? widget.kind;
  List<MealComponent> _parts = [];
  /// The definition as it was when this editing began: what "changed on another device" is measured against.
  MealBody? _base;
  bool _loaded = false, _dirty = false, _resumed = false, _busy = false;
  String? _error;

  bool get _recipe => _kind == MealBody.recipe;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final kept = await _repo.draft(_key);
    if (!mounted) return;
    final b = kept?.body ?? widget.start ?? widget.saved?.body ?? MealBody({'kind': _kind, 'name': '', 'components': const []});
    setState(() {
      _kind = b.kind;
      _name.text = b.name;
      _servings.text = b.j['servingsText'] as String? ?? (b.servings == null ? '' : formatNumber2(b.servings!));
      _weight.text = b.j['weightText'] as String? ?? (b.preparedWeightG == null ? '' : formatNumber2(b.preparedWeightG!));
      _parts = b.components;
      _base = kept?.base ?? widget.saved?.body;
      _resumed = kept != null;
      _dirty = kept != null || widget.start != null;
      _loaded = true;
    });
    if (widget.start != null && kept == null) _keep();
  }

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    _weight.dispose();
    super.dispose();
  }

  MealBody _body() => MealBody({
        'kind': _kind, 'name': _name.text, 'components': [for (final c in _parts) c.j],
        if (_recipe) ...{'servings': _positive(_servings.text) ?? (_servings.text.trim().isEmpty ? null : -1), 'preparedWeightG': _weight.text.trim().isEmpty ? null : _positive(_weight.text) ?? -1},
      });

  /// Every change is kept on the phone right away (with the field texts as typed); nothing is sent until Save.
  void _keep() {
    _dirty = true;
    final b = MealBody({..._body().j, 'servingsText': _servings.text, 'weightText': _weight.text});
    _repo.keepDraft(_key, b, base: _base).ignore(); // a failed draft write loses nothing on screen
  }

  void _changed(VoidCallback f) => setState(() {
        f();
        _keep();
      });

  Future<void> _add() async {
    final c = await _pick(context, dayKey: widget.dayKey);
    if (c != null && mounted) _changed(() => _parts = [..._parts, c]);
  }

  Future<void> _edit(int i) async {
    final c = await _change(context, _parts[i], dayKey: widget.dayKey);
    if (c != null && mounted) _changed(() => _parts = [..._parts]..[i] = c);
  }

  Future<void> _save({required bool asNew}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.l10n;
    final saved = widget.saved;
    final ok = await _attempt(context, (e) => setState(() => _error = e), () async {
      final body = _body();
      SavedMealRepository.validate(body);
      if (saved != null && !asNew) {
        final rec = await ref.read(syncProvider).get(ref.read(ownerProvider)!, Kinds.savedMeal, saved.id);
        final now = rec == null ? null : SavedMeal(jsonDecode(rec.body) as Json);
        // Changed or deleted on another phone since this editing began: say so, and let the person choose.
        if (now != null && now.isDeleted) throw const _Stop(true);
        if (now != null && _base != null && !sameMeal(now.body, _base!) && mounted &&
            !await confirm(context, title: l.mealsChangedElsewhereTitle, body: l.mealsChangedElsewhereBody, action: l.mealsSaveMine)) {
          throw const _Stop(false);
        }
      }
      await _repo.put(body, id: asNew ? null : saved?.id);
      await _repo.dropDraft(_key);
    }).catchError((Object e) {
      if (e is _Stop && e.deleted) setState(() => _error = l.mealsDeletedElsewhere);
      return false;
    });
    if (mounted) setState(() => _busy = false);
    if (!ok || !mounted) return;
    toast(context, _recipe ? l.mealsSavedRecipe : l.mealsSaved);
    Navigator.pop(context, true);
  }

  Future<void> _discard() async {
    final l = context.l10n;
    if (!await confirm(context, title: l.mealsDiscardTitle, body: widget.saved == null ? l.mealsDiscardBodyNew : l.mealsDiscardBody, action: l.mealsDiscard)) return;
    await _repo.dropDraft(_key);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final supported = ref.watch(savedMealsSupportedProvider);
    final editing = widget.saved != null;
    final title = _recipe ? (editing ? l.mealsEditRecipe : l.mealsNewRecipe) : (editing ? l.mealsEditMeal : l.mealsNewMeal);
    final body = _body();
    final servings = _positive(_servings.text);
    return AppPage(
      title: title,
      actions: [if (_recipe) CoachHelpEntry(id: 'meals.recipes', label: l.mealsHelpLabel)],
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, key: const Key('meal-error'), tone: Tone.error)),
        PrimaryButton(l.actionSave, key: const Key('meal-save'), busy: _busy, onPressed: !_loaded || !supported ? null : () => _save(asNew: false)),
        Wrap(alignment: WrapAlignment.center, children: [
          if (editing) TextButton(key: const Key('meal-save-new'), onPressed: !_loaded || !supported || _busy ? null : () => _save(asNew: true), child: Text(l.mealsSaveAsNew)),
          if (_dirty) TextButton(key: const Key('meal-discard'), onPressed: _busy ? null : _discard, child: Text(l.mealsDiscard)),
        ]),
      ]),
      children: !_loaded
          ? [const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()))]
          : [
              if (_resumed) Padding(padding: const EdgeInsets.only(bottom: 12), child: StatusLine(Icons.history, l.mealsResumed, key: const Key('meal-resumed'))),
              if (!supported) Padding(padding: const EdgeInsets.only(bottom: 12), child: StatusLine(Icons.cloud_off_outlined, l.mealsServerUnavailable, tone: Tone.warning)),
              if (_recipe) CoachSpot(id: 'meals.recipes', padding: const EdgeInsets.only(bottom: 12), say: CoachSay(l.mealsCoachRecipe)),
              TextField(key: const Key('meal-name'), controller: _name, textCapitalization: TextCapitalization.sentences, onChanged: (_) => _changed(() {}),
                  decoration: InputDecoration(labelText: l.mealsNameLabel)),
              if (_recipe) ...[
                const SizedBox(height: 14),
                TextField(key: const Key('recipe-servings'), controller: _servings, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _changed(() {}),
                    decoration: InputDecoration(labelText: l.mealsServingsLabel, helperText: l.mealsServingsHelper, helperMaxLines: 3)),
                const SizedBox(height: 14),
                TextField(key: const Key('recipe-weight'), controller: _weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _changed(() {}),
                    decoration: InputDecoration(labelText: l.mealsWeightLabel, suffixText: l.eatUnitGram, helperText: l.mealsWeightHelper, helperMaxLines: 3)),
              ],
              const SizedBox(height: 22),
              Semantics(header: true, child: Text(_recipe ? l.mealsIngredientsHeading : l.mealsFoodsHeading, style: context.titleStyle(20))),
              const SizedBox(height: 8),
              if (_parts.isNotEmpty)
                GroupCard(children: [
                  for (final (i, c) in _parts.indexed) _ComponentRow(c, index: i, onTap: () => _edit(i), onRemove: () => _changed(() => _parts = [..._parts]..removeAt(i))),
                ]),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(key: const Key('meal-add-food'), onPressed: _parts.length >= SavedMealRepository.maxComponents ? null : _add, icon: const Icon(Icons.add),
                    label: Text(_recipe ? l.mealsAddIngredient : l.mealsAddFood)),
              ),
              if (_parts.isNotEmpty) ...[
                const SizedBox(height: 10),
                _Nutrition(_recipe ? l.mealsBatchHeading : l.mealsTotalHeading, body.totals, key: const Key('meal-totals')),
                if (_recipe && servings != null) ...[
                  const SizedBox(height: 10),
                  _Nutrition(l.mealsPerServingHeading, {for (final e in body.totals.entries) e.key: e.value.times(1 / servings)}, key: const Key('recipe-per-serving'), note: false),
                ],
              ],
            ],
    );
  }
}

class _Stop implements Exception {
  const _Stop(this.deleted);
  final bool deleted;
}

// ---------------------------------------------------------------------------- log review

/// Reviewing a saved meal or a recipe portion before it is logged, or changing a logged recipe portion ([entry]).
///
/// It works on a copy of the definition taken when it opened, so an edit from another phone never changes what is on
/// screen. A meal can be multiplied (½×, 1×, 1½×, 2×, or any multiplier) and each food changed, removed or added, for
/// this time only. A recipe is logged by servings, or by grams of the finished batch when it was weighed.
/// Log is the main action and the only one that records food; Update saved meal and Save as new change templates only.
class MealReviewScreen extends ConsumerStatefulWidget {
  const MealReviewScreen({super.key, required this.body, required this.dayKey, required this.meal, this.saved, this.initialFactor, this.initialAmount, this.initialMeasure})
      : entry = null;
  MealReviewScreen.entry(FoodEntry this.entry, {super.key})
      : body = MealMath.ofEntry(entry)!.recipe, dayKey = entry.dayKey, meal = entry.meal, saved = null, initialFactor = null, initialAmount = null, initialMeasure = null;
  final MealBody body;
  final SavedMeal? saved;
  final String dayKey, meal;
  final FoodEntry? entry;

  /// Where a suggested portion opens (docs/COACH.md › Help with today): a meal at this multiplier, a recipe at this amount
  /// of [initialMeasure]. Still only a starting point: every amount stays editable and only Log records anything.
  final double? initialFactor, initialAmount;
  final PortionMeasure? initialMeasure;
  @override
  ConsumerState<MealReviewScreen> createState() => _MealReviewScreenState();
}

class _MealReviewScreenState extends ConsumerState<MealReviewScreen> {
  /// One operation per review: a second tap, or a retry after the first was written, logs nothing more.
  final _op = SyncEngine.newId();
  late String _day = widget.dayKey, _meal = meals.contains(widget.meal) ? widget.meal : meals.first;
  late List<MealComponent> _parts = widget.body.components;
  double? _factor = 1;
  late MealBody _batch = widget.body;
  late final _from = widget.entry == null ? null : MealMath.ofEntry(widget.entry!);
  late PortionMeasure _measure = _from?.measure ?? (widget.initialMeasure == PortionMeasure.gram && widget.body.preparedWeightG != null ? PortionMeasure.gram : PortionMeasure.serving);
  late final _amount = TextEditingController(text: formatNumber2(_from?.amount ?? widget.initialAmount ?? 1));
  bool _busy = false, _batchChanged = false, _started = false;
  String? _error;

  bool get _recipe => widget.body.isRecipe;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A suggested multiplier, applied once with the amounts said in this language (the same path as tapping it).
    if (_started) return;
    _started = true;
    final f = widget.initialFactor;
    if (!_recipe && f != null && f != 1 && f > 0 && f <= MealMath.maxMultiplier) {
      _factor = f;
      _parts = MealMath.scaled(widget.body.components, f, (c, q) => _describe(ref, context.l10n, c, q));
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _multiply(double f) => setState(() {
        _factor = f;
        _parts = MealMath.scaled(widget.body.components, f, (c, q) => _describe(ref, context.l10n, c, q));
      });

  Future<void> _custom() async {
    final f = await showDialog<double>(context: context, builder: (_) => const _MultiplierDialog());
    if (f != null && mounted) _multiply(f);
  }

  Future<void> _editPart(int i) async {
    final c = await _change(context, _parts[i], dayKey: _day);
    if (c == null || !mounted) return;
    setState(() {
      if (_recipe) {
        _batch = _batch.copyWith(components: [..._batch.components]..[i] = c);
        _batchChanged = true;
      } else {
        _parts = [..._parts]..[i] = c;
        _factor = null;
      }
    });
  }

  void _removePart(int i) => setState(() {
        if (_recipe) {
          _batch = _batch.copyWith(components: [..._batch.components]..removeAt(i));
          _batchChanged = true;
        } else {
          _parts = [..._parts]..removeAt(i);
          _factor = null;
        }
      });

  Future<void> _addPart() async {
    final c = await _pick(context, dayKey: _day);
    if (c == null || !mounted) return;
    setState(() {
      if (_recipe) {
        _batch = _batch.copyWith(components: [..._batch.components, c]);
        _batchChanged = true;
      } else {
        _parts = [..._parts, c];
        _factor = null;
      }
    });
  }

  /// The same portion in the other measure, through the recipe's own servings and weighed batch.
  void _changeMeasure(PortionMeasure to) {
    final now = _positive(_amount.text);
    final converted = now == null ? null : MealMath.convert(_batch, now, _measure, to);
    setState(() {
      if (converted != null) _amount.text = formatNumber2(converted);
      _measure = to;
    });
  }

  String _portionText(AppLocalizations l, double amount) =>
      _measure == PortionMeasure.gram ? l.eatGramsValue(formatNumber2(amount)) : l.mealsServingsAmount(amount, MealMath.count(amount));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: parseDayKey(_day), firstDate: DateTime.utc(2020), lastDate: parseDayKey(ref.read(todayKeyProvider)).add(const Duration(days: 1)));
    if (picked != null) setState(() => _day = dayKeyOf(picked)); // changing the day records nothing
  }

  Future<void> _log() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.l10n;
    final food = ref.read(foodRepositoryProvider);
    final ok = await _attempt(context, (e) => setState(() => _error = e), () async {
      if (_recipe) {
        final amount = _positive(_amount.text);
        if (amount == null) throw const InvalidMeal(MealProblem.badPortion);
        SavedMealRepository.validate(_batch);
        final e = widget.entry;
        await food.save(
            MealMath.portion(_batch, amount: amount, measure: _measure, dayKey: _day, meal: _meal, amountText: _portionText(l, amount),
                recipeId: widget.saved?.id ?? _from?.recipeId, recipeRevision: widget.saved?.revision ?? _from?.revision, entryId: e?.id, name: e?.name),
            operationId: _op);
      } else {
        if (_parts.isEmpty) throw const InvalidMeal(MealProblem.noComponents);
        await food.logMeal(MealMath.mealEntries(_parts, dayKey: _day, meal: _meal), operationId: _op);
      }
    });
    if (mounted) setState(() => _busy = false);
    if (!ok || !mounted) return;
    toast(context, widget.entry != null ? l.mealsPortionChanged : l.mealsLogged(mealLabel(l, _meal)));
    Navigator.pop(context, true);
  }

  /// Update saved meal: the amounts shown become the saved meal's, as one meal. Nothing is logged.
  Future<void> _update(SavedMeal live) async {
    final l = context.l10n, saved = widget.saved!;
    // Changed on another phone since this review opened: that is said first, and only an explicit choice replaces it.
    if (!sameMeal(live.body, saved.body) && !await confirm(context, title: l.mealsChangedElsewhereTitle, body: l.mealsChangedElsewhereBody, action: l.mealsSaveMine)) return;
    if (!mounted || !await confirm(context, title: l.mealsUpdateTitle, body: l.mealsUpdateBody(live.body.name), action: l.mealsUpdateSaved)) return;
    if (!mounted) return;
    if (await _attempt(context, (e) => setState(() => _error = e), () => ref.read(savedMealRepositoryProvider).put(live.body.copyWith(components: _parts), id: saved.id)) && mounted) {
      toast(context, l.mealsUpdated);
    }
  }

  /// Save as new: the amounts shown become one new saved meal; the original stays as it is. Nothing is logged.
  Future<void> _saveNew() async {
    final l = context.l10n;
    final name = await showDialog<String>(context: context, builder: (_) => _NameDialog(initial: l.mealsCopyName(widget.body.name), body: l.mealsSaveAsNewBody(widget.body.name)));
    if (name == null || !mounted) return;
    if (await _attempt(context, (e) => setState(() => _error = e), () => ref.read(savedMealRepositoryProvider).put(widget.body.copyWith(name: name, components: _parts))) && mounted) {
      toast(context, l.mealsSavedNew);
    }
  }

  Future<void> _remove() async {
    final e = widget.entry!;
    final l = context.l10n;
    if (!await confirm(context, title: l.foodRemoveTitle(e.name), body: l.foodRemoveBody(e.name, e.amountDescription, mealLabel(l, e.meal), longDate(e.dayKey)), action: l.foodRemoveAction)) return;
    await ref.read(foodRepositoryProvider).remove(e);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final supported = ref.watch(savedMealsSupportedProvider);
    final entry = widget.entry;
    final saved = widget.saved;
    final live = saved == null ? null : (ref.watch(savedMealsProvider).value ?? const <Stored<SavedMeal>>[]).where((r) => r.value.id == saved.id).firstOrNull?.value;
    final amount = _positive(_amount.text);
    final share = !_recipe || amount == null ? null : MealMath.share(_batch, amount, _measure);
    final totals = _recipe
        ? {for (final e in _batch.totals.entries) e.key: e.value.times(share ?? 0)}
        : NutrientCoverage.ofParts(_parts.map((c) => c.values));
    final parts = _recipe ? _batch.components : _parts;
    const factors = [0.5, 1.0, 1.5, 2.0];
    final weighed = _batch.preparedWeightG != null;

    return AppPage(
      title: entry?.name ?? widget.body.name,
      subtitle: entry != null ? l.foodEditTitle : l.mealsReviewNote,
      actions: [if (_recipe) CoachHelpEntry(id: 'meals.recipes', label: l.mealsHelpLabel)],
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, key: const Key('meal-error'), tone: Tone.error)),
        PrimaryButton(entry != null ? l.foodSaveChanges : _recipe ? l.mealsLogPortion : l.mealsLogMeal, key: const Key('meal-log'), busy: _busy, onPressed: supported ? _log : null),
        // The template actions are quieter than Log, and say what they change.
        if (!_recipe && saved != null && live != null && !live.isDeleted)
          Wrap(alignment: WrapAlignment.center, children: [
            TextButton(key: const Key('meal-update-saved'), onPressed: supported && !_busy ? () => _update(live) : null, child: Text(l.mealsUpdateSaved)),
            TextButton(key: const Key('meal-review-save-new'), onPressed: supported && !_busy ? _saveNew : null, child: Text(l.mealsSaveAsNew)),
          ]),
        if (_recipe && saved != null && live != null && !live.isDeleted)
          TextButton(key: const Key('recipe-edit'), onPressed: () => push(context, MealEditorScreen(dayKey: _day, saved: live)), child: Text(l.mealsEditRecipe)),
        if (entry != null) TextButton.icon(key: const Key('food-remove'), onPressed: _remove, icon: const Icon(Icons.delete_outline, size: 18), label: Text(l.foodRemoveAction)),
      ]),
      children: [
        if (!supported) Padding(padding: const EdgeInsets.only(bottom: 12), child: StatusLine(Icons.cloud_off_outlined, l.mealsServerUnavailable, tone: Tone.warning)),
        DropdownButtonFormField<String>(
          key: const Key('meal-review-meal'), initialValue: _meal, isExpanded: true, dropdownColor: context.c.surface,
          decoration: InputDecoration(labelText: l.foodMealLabel, prefixIcon: const Padding(padding: EdgeInsets.all(7), child: IconTile(Icons.restaurant, circle: true, size: 34))),
          items: [for (final m in meals) DropdownMenuItem(value: m, child: Text(mealLabel(l, m)))],
          onChanged: (m) => setState(() => _meal = m ?? _meal), // changing the meal records nothing
        ),
        InkWell(
          key: const Key('meal-review-date'), onTap: _pickDate,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: StatusLine(Icons.event, l.foodForDateTapToChange(longDate(_day)))),
        ),
        const SizedBox(height: 8),
        if (_recipe) ...[
          Semantics(header: true, child: Text(l.mealsPortionHeading, style: context.titleStyle(20))),
          const SizedBox(height: 8),
          if (weighed)
            Segmented<PortionMeasure>(
              keyPrefix: 'recipe-measure', values: PortionMeasure.values, selected: _measure,
              label: (m) => m == PortionMeasure.gram ? l.mealsMeasureGrams : l.mealsMeasureServings, onChanged: _changeMeasure,
            ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('recipe-amount'), controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}),
            style: context.numStyle(18),
            decoration: InputDecoration(
              labelText: l.mealsPortionAmount, suffixText: _measure == PortionMeasure.gram ? l.eatUnitGram : null,
              helperText: _batch.servings == null ? null : l.mealsMakesServings(_batch.servings!, MealMath.count(_batch.servings!)), helperMaxLines: 2,
            ),
          ),
          if (!weighed) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.mealsNoWeight, style: context.caption)),
          const SizedBox(height: 14),
          _Nutrition(amount == null ? l.mealsPortionHeading : l.mealsThisPortion(_portionText(l, amount)), totals, key: const Key('meal-review-totals')),
          const SizedBox(height: 22),
          Semantics(header: true, child: Text(l.mealsThisTimeIngredients, style: context.titleStyle(18))),
          Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(_batchChanged ? l.mealsThisTimeChanged : l.mealsThisTimeNote, style: context.caption)),
        ] else ...[
          Semantics(header: true, child: Text(l.mealsAmountsHeading, style: context.titleStyle(20))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final f in factors)
              ChoiceChip(
                key: Key('meal-factor-$f'), label: Text('${f == 0.5 ? '½' : f == 1.5 ? '1½' : formatNumber(f)}×'), selected: _factor == f,
                tooltip: l.mealsMultiplierSaid(formatNumber2(f)), onSelected: (_) => _multiply(f),
              ),
            ChoiceChip(
              key: const Key('meal-factor-custom'), selected: _factor != null && !factors.contains(_factor),
              label: Text(_factor != null && !factors.contains(_factor) ? '${formatNumber2(_factor!)}×' : l.mealsMultiplierCustom), onSelected: (_) => _custom(),
            ),
          ]),
          const SizedBox(height: 10),
        ],
        if (parts.isNotEmpty)
          GroupCard(children: [
            for (final (i, c) in parts.indexed)
              _ComponentRow(c, index: i, onTap: () => _editPart(i), onRemove: parts.length > 1 ? () => _removePart(i) : null),
          ]),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(key: const Key('meal-add-food'), onPressed: parts.length >= SavedMealRepository.maxComponents ? null : _addPart, icon: const Icon(Icons.add),
              label: Text(_recipe ? l.mealsAddIngredient : l.mealsAddFood)),
        ),
        if (!_recipe) ...[const SizedBox(height: 10), _Nutrition(l.mealsThisTimeTotal, totals, key: const Key('meal-review-totals'))],
      ],
    );
  }
}

/// Asks for a multiplier for every amount (above 0, at most 20), in any of the app's number formats.
class _MultiplierDialog extends StatefulWidget {
  const _MultiplierDialog();
  @override
  State<_MultiplierDialog> createState() => _MultiplierDialogState();
}

class _MultiplierDialogState extends State<_MultiplierDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() {
    final v = _positive(_text.text);
    if (v == null || v > MealMath.maxMultiplier) return setState(() => _error = context.l10n.mealsProblemBadMultiplier);
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
      title: Text(l.mealsMultiplierTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(key: const Key('meal-factor-field'), controller: _text, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), onSubmitted: (_) => _done(),
              decoration: InputDecoration(labelText: l.mealsMultiplierLabel, suffixText: '×')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(key: const Key('meal-factor-apply'), onPressed: _done, child: Text(l.actionOk)),
      ],
    );
  }
}

/// The name for a new saved meal made from the amounts on screen; says that those amounts become one saved meal.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial, required this.body});
  final String initial, body;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() {
    final name = _text.text.trim();
    if (name.isEmpty || name.length > 120) return setState(() => _error = context.l10n.mealsProblemNoName);
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
      title: Text(l.mealsSaveAsNewTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.body, style: context.caption),
          const SizedBox(height: 12),
          TextField(key: const Key('meal-new-name'), controller: _text, textCapitalization: TextCapitalization.sentences, onSubmitted: (_) => _done(),
              decoration: InputDecoration(labelText: l.mealsNameLabel)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(key: const Key('meal-new-save'), onPressed: _done, child: Text(l.actionSave)),
      ],
    );
  }
}
