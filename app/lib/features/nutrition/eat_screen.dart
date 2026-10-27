import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/go_icon.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../coach/coach_avatar.dart';
import '../coach/coach_bubble.dart';
import '../coach/coach_prefs.dart';
import '../shell/home_shell.dart' show shellProvider;
import 'food_form.dart';
import 'food_repository.dart' show SavedFood, mealLabel;
import 'log_food_screen.dart';
import 'nutrition_history.dart';
import 'nutrient_coverage.dart';
import 'nutrition_surface.dart';
import 'nutrition_tools.dart';
import 'eating_out.dart' show restaurantCatalogProvider;
import 'eating_out_screen.dart';
import 'restaurants.dart' show RestaurantChain;
import 'saved_meals_screens.dart';
import 'water.dart';

/// The dated food journal: the day's overview, one Log food action, then Breakfast, Lunch, Dinner and Snack,
/// built only from food the user logged as eaten. Each entry is its own row with the name, portion and values
/// that were saved with it; nothing is merged into a meal name or worked out again from a food database.
class EatScreen extends ConsumerStatefulWidget {
  const EatScreen({super.key});
  @override
  ConsumerState<EatScreen> createState() => _EatScreenState();
}

class _EatScreenState extends ConsumerState<EatScreen> {
  /// Null = follow the shared "today"; a picked day stays put when midnight passes.
  String? _picked;

  /// One family for the meals, the time of day they belong to: sunrise, sun, moon, and a snack. Outlined Material icons
  /// on the same tile, with the meal's name beside them.
  static const _icons = {'Breakfast': Icons.wb_twilight_outlined, 'Lunch': Icons.light_mode_outlined, 'Dinner': Icons.dark_mode_outlined, 'Snack': Icons.cookie_outlined};

  /// Built-in help with the journal. Ask GoHard answers training questions, so nothing here offers to ask it about food.
  /// It explains the saved foods and opens them, on request, at any time.
  static void _help(BuildContext context, String day) => showCoachHelpSheet(context, title: context.l10n.eatHelpTitle, say: CoachSay(context.l10n.eatHelpBody,
      guide: (label: context.l10n.eatOpenFavourites, key: const Key('eat-help-favourites'), onPressed: () => openSavedFoods(context, day: day, scope: FoodScope.favourites))));

  /// Whether anything was logged on a day before today (food on this phone).
  bool get _pastDays {
    final today = ref.read(todayKeyProvider);
    return (ref.read(foodJournalProvider).value ?? const []).any((r) => !r.value.isDeleted && r.value.dayKey.compareTo(today) < 0);
  }

  Future<void> _openHistory(String day, String today) async {
    final chosen = await push<String>(context, NutritionHistoryScreen(selected: day));
    if (chosen != null && mounted) setState(() => _picked = chosen == today ? null : chosen);
  }

  /// The meal a saved-food shortcut starts on, from the time of day; it can be changed in Add food before choosing.
  static String _mealNow(DateTime t) => t.hour < 11 ? 'Breakfast' : t.hour < 16 ? 'Lunch' : t.hour < 21 ? 'Dinner' : 'Snack';

  /// Eating out for [day] and the meal of the time of day: the panel and the coach's shortcut open the same thing.
  Future<void> _openEatingOut(String day) => openEatingOut(context, dayKey: day, meal: _mealNow(DateTime.now()));

  /// Add food opened on Favourites or My foods, for [day]. A shortcut, never a log: the amount is still reviewed and confirmed.
  static Future<void> openSavedFoods(BuildContext context, {required String day, required FoodScope scope}) =>
      push(context, LogFoodScreen(dayKey: day, meal: _mealNow(DateTime.now()), scope: scope));

  /// The one saved-foods hint the coach gives (docs/COACH.md › Train and Eat › Saved foods): to an account with none,
  /// how foods are kept for next time; to one with some, the way to them. Each is shown once (Coaching hints govern
  /// it, Show coaching hints again brings it back) and kept for this screen's life, so the words never change under
  /// the reader; afterwards the usual words, and the help keeps the shortcut.
  String? _hint;

  CoachSay? _hintSay(String day, List<SavedFood> saved, {required bool logged}) {
    final owner = ref.read(ownerProvider);
    if (owner == null || !ref.read(savedFoodsProvider).hasValue) return null;
    final has = saved.any((s) => s.isFavourite || s.isMine);
    // Tabs stay built off screen: a hint is chosen (and used up) only while Eat is the tab in view and its page current.
    // Nor while the keyboard is up (the view's own inset: the Scaffold takes it out of the page's MediaQuery).
    final inView = ref.watch(shellProvider.select((s) => s.tab == 2)) && (ModalRoute.isCurrentOf(context) ?? true) && View.of(context).viewInsets.bottom == 0;
    // A first visit is about logging a meal at all; saving one for next time is worth saying once food is logged.
    if (_hint == null && inView && (has || logged)) {
      final id = has ? 'eat.saved.shortcut' : 'eat.saved.new';
      _hint = ref.read(coachPrefsProvider).mayIntroduce(owner, id) ? id : '';
      if (_hint!.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(coachPrefsProvider.notifier).markSeen(owner, id));
    }
    // Once there are earlier days, History is introduced once (after the saved-foods hint has had its turn).
    if (_hint == '' && inView && _pastDays) {
      const id = 'eat.history';
      if (ref.read(coachPrefsProvider).mayIntroduce(owner, id)) {
        _hint = id;
        WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(coachPrefsProvider.notifier).markSeen(owner, id));
      }
    }
    // Saved meals & recipes, once, to someone who logs food (after the hints above have had their turn).
    if (_hint == '' && inView && logged) {
      const id = 'eat.meals';
      if (ref.read(coachPrefsProvider).mayIntroduce(owner, id)) {
        _hint = id;
        WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(coachPrefsProvider.notifier).markSeen(owner, id));
      }
    }
    // Eating out, once, after the hints above have had their turn (a first visit stays about logging a meal). The
    // panel under the summary is always there; this only points to it.
    if (_hint == '' && inView) {
      const id = 'eat.out';
      if (ref.read(coachPrefsProvider).mayIntroduce(owner, id)) {
        _hint = id;
        WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(coachPrefsProvider.notifier).markSeen(owner, id));
      }
    }
    final l = context.l10n;
    if (_hint == 'eat.out') return CoachSay(l.eatHintEatingOut, guide: (label: l.eatHintEatingOutAction, key: const Key('eat-coach-eating-out'), onPressed: () => _openEatingOut(day)));
    if (_hint == 'eat.history') return CoachSay(l.eatHintHistory);
    if (_hint == 'eat.meals') {
      return CoachSay(l.eatHintMeals,
          guide: (label: l.mealsLibraryTitle, key: const Key('eat-coach-meals'), onPressed: () => openMealsLibrary(context, dayKey: day, meal: _mealNow(DateTime.now()))));
    }
    if (_hint == 'eat.saved.new') return CoachSay(l.eatHintSavedNew);
    if (_hint != 'eat.saved.shortcut') return null;
    final fav = saved.any((s) => s.isFavourite);
    return CoachSay(fav ? l.eatHintFavourites : l.eatHintMine,
        guide: fav
            ? (label: l.eatOpenFavourites, key: const Key('eat-coach-favourites'), onPressed: () => openSavedFoods(context, day: day, scope: FoodScope.favourites))
            : (label: l.eatOpenMine, key: const Key('eat-coach-mine'), onPressed: () => openSavedFoods(context, day: day, scope: FoodScope.mine)));
  }

  /// What the coach says on Eat: fixed words chosen from the account's own settings, never from the AI. Water is
  /// mentioned only where it is shown (turned on, and the server keeps it). Words only: Log food and the goals link
  /// are right below it in the summary, so the bubble repeats neither.
  static CoachSay _say(AppLocalizations l, {required Profile? profile, required bool water}) {
    final hasGoal = profile != null && (profile.calorieGoal != null || profile.proteinGoal != null || profile.waterGoalMl != null);
    return CoachSay(hasGoal ? (water ? l.eatSayGoalWater : l.eatSayGoal) : (water ? l.eatSayNoGoalWater : l.eatSayNoGoal));
  }

  /// The portion as it was saved, then the macros that are known (a recipe portion's partial sums marked "known"), then
  /// how the record stands with the account.
  static String _detail(AppLocalizations l, Stored<FoodEntry> r) {
    final e = r.value;
    String? macro(double? v, String key, String Function(String) say) {
      final known = v ?? e.partial(key);
      return known == null ? null : v != null ? say(formatNumber(v)) : '${say(formatNumber(known))} (${l.eatKnown})';
    }
    final macros = [
      ?macro(e.protein, 'protein', l.eatMacroProtein),
      ?macro(e.carbs, 'carbs', l.eatMacroCarbs),
      ?macro(e.fat, 'fat', l.eatMacroFat),
    ];
    return [
      e.amountDescription,
      if (macros.isNotEmpty) macros.join(' · ') else if (e.calories == null && e.partial('calories') == null) l.eatNoNutritionEntered,
      if (r.needsReview) l.eatNeedsReview else if (r.isPending) l.eatSyncPendingShort,
    ].join(' · ');
  }

  /// A meal's calories from its own entries: a sum of what is known, labelled when some are unknown.
  static String _mealCalories(AppLocalizations l, List<FoodEntry> entries) {
    final t = NutrientCoverage.calculate(entries)[Nutrient.calories]!;
    return !t.hasAnyKnown ? l.eatCaloriesUnknown : t.isComplete ? l.eatKcalValue(formatKcal(t.knownTotal)) : l.eatKcalKnown(formatKcal(t.knownTotal));
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayKeyProvider);
    final day = _picked ?? today;
    final rows = ref.watch(foodProvider(day));
    final live = [for (final r in rows.value ?? const <Stored<FoodEntry>>[]) if (!r.value.isDeleted) r];
    final entries = [for (final r in live) r.value];
    final profile = ref.watch(profileProvider).value;
    final display = ref.watch(nutritionDisplayProvider);
    final c = context.c;
    final l = context.l10n;

    final coachOn = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    final guide = ref.watch(coachPrefsProvider.select((p) => p.guide));

    // With very large text the meal icon gives its room to the words.
    final roomy = MediaQuery.textScalerOf(context).scale(10) <= 15;
    final indent = roomy ? 16.0 : 12.0;

    return RefreshIndicator(
      edgeOffset: MediaQuery.paddingOf(context).top,
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        // On the calm wash the shell lays behind Eat, with room for the floating bar at the end.
        padding: EdgeInsets.only(bottom: 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topInset(context), context.inset, 18),
            child: TabHeader(
              title: l.navEat, overline: longDate(day),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                // Help with the journal from the same guide: its small avatar here only while the speaking coach is off.
                if (!coachOn) CoachHelpButton(key: const Key('coach-help-eat'), semanticLabel: l.eatHelpLabel, onPressed: () => _help(context, day)),
                // In Arabic the row runs right to left and the chevrons mirror: the earlier day stays on the reading-back side.
                IconButton(tooltip: l.eatPreviousDay, icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _picked = addDays(day, -1))),
                IconButton(tooltip: l.eatNextDay, icon: const Icon(Icons.chevron_right), onPressed: day.compareTo(today) >= 0 ? null : () => setState(() => _picked = addDays(day, 1) == today ? null : addDays(day, 1))),
              ]),
              below: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      // Under the date, on an earlier day: Back to today (the arrows stay for a day either side).
                      if (day != today)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(key: const Key('eat-back-to-today'), onPressed: () => setState(() => _picked = null), icon: const Icon(Icons.today, size: 18), label: Text(l.eatBackToToday)),
                        ),
                      if (coachOn)
                        TabCoach(key: const Key('eat-coach'), id: 'eat',
                            say: _hintSay(day, [for (final r in ref.watch(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]) if (!r.value.isDeleted) r.value], logged: entries.isNotEmpty) ??
                                _say(l, profile: profile, water: display.water),
                            avatarLabel: l.eatHelpFrom(guide.displayName(l)), onAvatarTap: () => _help(context, day)),
                    ]),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.inset),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (rows.hasError)
                Panel(child: StatusLine(Icons.error_outline, l.eatJournalReadError, tone: Tone.error))
              else if (!rows.hasValue)
                Panel(child: StatusLine(Icons.hourglass_empty, l.eatJournalLoading))
              else ...[
                // The day's summary as a photo panel, with the one general Log food in it.
                NutritionSurface(
                  entries: entries, coverage: NutrientCoverage.calculate(entries), calorieGoal: day == today ? profile?.calorieGoal : null, proteinGoal: day == today ? profile?.proteinGoal : null, pending: live.any((r) => r.isPending),
                  showCarbs: display.carbs, showFat: display.fat,
                  footer: [if (display.water) WaterRow(key: const Key('eat-water'), day: day), const NutritionTools(keyPrefix: 'eat')],
                  // Log food, and beside it the way to several foods at once: the same day, the meal of the time of day.
                  action: Wrap(spacing: 4, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    PrimaryButton(l.foodLogButton, key: const Key('log-food'), icon: Icons.restaurant, expand: false, onPressed: () => openFoodForm(context, dayKey: day)),
                    TextButton.icon(key: const Key('eat-saved-meals'), icon: const Icon(Icons.menu_book_outlined, size: 20), label: Text(l.mealsLibraryTitle),
                        onPressed: () => openMealsLibrary(context, dayKey: day, meal: _mealNow(DateTime.now()))),
                  ]),
                ),
                const SizedBox(height: 16),
                // Eating out, always here (coach or not): a restaurant order from verified menus, for the same day and the
                // meal of the time of day. The chains named are the catalog's own, so the line never claims more.
                () {
                  final names = [for (final ch in ref.watch(restaurantCatalogProvider).value?.chains ?? const <RestaurantChain>[]) ch.name];
                  return PanelLink(
                    key: const Key('eat-eating-out'), icon: const Icon(Icons.storefront_outlined), title: l.eatOutTitle, subtitle: l.eatOutPanelBody,
                    // Each name stays whole on one line; the list wraps between names.
                    detail: names.isEmpty ? null : names.map((n) => n.replaceAll(' ', String.fromCharCode(0xa0))).join(' · '),
                    action: l.eatOutPanelAction,
                    semanticLabel: [l.eatOutTitle, l.eatOutPanelBody, if (names.isNotEmpty) names.join(', '), l.eatOutPanelAction].join('. '),
                    onTap: () => _openEatingOut(day),
                  );
                }(),
                const SizedBox(height: 16),
                // The one way to History & trends (charts by week and month, the calendar, the days with entries): under
                // the day's summary, secondary to Log food. It opens the history on the day shown and changes nothing.
                PanelLink(
                  key: const Key('eat-history'), icon: const GoIcon(GoGlyph.history), title: l.eatHistoryTrends, subtitle: l.eatHistoryTrendsSubtitle,
                  semanticLabel: l.eatHistoryTrendsSaid, onTap: () => _openHistory(day, today),
                ),
                const SizedBox(height: 28),
                Heading(day == today ? l.eatTodaysMeals : l.eatMeals, size: 20),
                const SizedBox(height: 12),
                // One quiet group per meal: the meal as its heading (outlined icon, name, what its foods add up to as a
                // quieter second line), each logged food as its own row, then a small "+ Add food" footer for this meal
                // and day. The footer is subordinate: no tile, regular weight, the accent colour. No photographs here.
                for (final meal in meals) ...[
                  () {
                    final mine = [for (final r in live) if (r.value.meal == meal) r];
                    final label = meal.toLowerCase();
                    return GroupCard(children: [
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(indent, 14, 16, mine.isEmpty ? 2 : 10),
                        child: Row(children: [
                          if (roomy) ...[IconTile(_icons[meal] ?? Icons.restaurant, size: _tile), const SizedBox(width: 12)],
                          Expanded(
                            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
                              Semantics(header: true, child: Text(mealLabel(l, meal), style: context.sansStyle(18, weight: FontWeight.w700))),
                              if (mine.isNotEmpty) Text(_mealCalories(l, [for (final r in mine) r.value]), style: context.numStyle(14.5, color: c.secondary, weight: FontWeight.w500)),
                            ]),
                          ),
                        ]),
                      ),
                      for (final r in mine) _EntryRow(r, indent: indent, detail: _detail(l, r), onTap: () => openFoodForm(context, dayKey: day, entry: r.value)),
                      Row(children: [
                        Expanded(child: _AddFood(key: Key('eat-add-$label'), meal: meal, indent: indent, onTap: () => openFoodForm(context, dayKey: day, meal: meal))),
                        // Quiet, beside Add food: this meal's foods copied into a new saved meal. Nothing is logged again.
                        if (mine.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: TextButton(
                              key: Key('eat-save-meal-$label'),
                              onPressed: () => saveAsMeal(context, dayKey: day, meal: meal, entries: [for (final r in mine) r.value]),
                              child: Text(l.mealsSaveAsMeal, semanticsLabel: l.mealsSaveAsMealSaid(mealLabel(l, meal))),
                            ),
                          ),
                      ]),
                    ]);
                  }(),
                  const SizedBox(height: 12),
                ],
                Text(l.eatOnlyLoggedNote, style: context.caption),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  static const _tile = 40.0;
}

/// A meal's footer: "+ Add food", small and in the accent, below its foods. A full-width 48 px target; read out with
/// its meal ("Add food to lunch"). It opens Log food for this meal and the day shown; nothing is logged until saved.
class _AddFood extends StatelessWidget {
  const _AddFood({super.key, required this.meal, required this.indent, required this.onTap});
  final String meal;
  final double indent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.c.accent;
    return Semantics(
      button: true, label: context.l10n.eatAddFoodToMeal(meal), excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.minimum),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(indent - 2, 4, 12, 6),
            child: Row(children: [
              Icon(Icons.add, size: 18, color: accent),
              const SizedBox(width: 6),
              Flexible(child: Text(context.l10n.eatAddFood, style: context.sansStyle(15, weight: FontWeight.w500, color: accent))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One logged food under its meal: the saved name, then the saved portion and known values; its calories at the
/// trailing edge (a dash when unknown, never a zero). Opens the entry for editing. With large text the calories
/// move under the name instead of squeezing it.
class _EntryRow extends StatelessWidget {
  const _EntryRow(this.r, {required this.indent, required this.detail, required this.onTap});
  final Stored<FoodEntry> r;
  final double indent;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = r.value;
    final name = Text(e.name, style: context.sansStyle(15.5, weight: FontWeight.w500));
    final part = e.partial('calories');
    final kcal = Text(e.calories == null && part != null ? context.l10n.eatKcalKnown(formatKcal(part)) : context.l10n.eatKcalValue(e.calories == null ? '—' : formatKcal(e.calories!)), style: context.numStyle(14.5, color: context.c.secondary, weight: FontWeight.w500));
    return Semantics(
      button: true,
      child: InkWell(
        key: Key('food-row-${e.id}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.minimum + 8),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(indent, 8, 12, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  if (MediaQuery.textScalerOf(context).scale(10) <= 13)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: name), const SizedBox(width: 12), kcal])
                  else
                    Wrap(spacing: 12, runSpacing: 2, children: [name, kcal]),
                  Padding(padding: const EdgeInsets.only(top: 1), child: Text(detail, style: context.caption)),
                ]),
              ),
              Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.chevron_right, size: 20, color: context.c.secondary)),
            ]),
          ),
        ),
      ),
    );
  }
}
