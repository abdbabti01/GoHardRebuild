import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../core/device_prefs.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../coach/coach_bubble.dart';
import '../../data/models.dart';
import 'barcode_scan_screen.dart';
import 'food_discovery.dart';
import 'food_form.dart';
import 'food_item.dart';
import 'food_repository.dart';
import 'food_search.dart';
import 'eating_out_screen.dart' show openEatingOut;
import 'saved_meals_screens.dart' show openMealsLibrary;

/// The lists a food can be picked from. Search covers everyday foods and the owner's own; the others are theirs.
enum FoodScope { search, recent, favourites, mine }

/// Add food: where a food to log is found. Typing searches the everyday foods bundled with the app and the
/// owner's own at once; the wider database is asked on a tap, or by itself when the phone has nothing for what
/// was typed. Every row opens the same form: nothing on this screen records anything as eaten.
/// The day is carried into the form, and so is the meal, which can be changed here first. What was typed, the
/// list and category chosen and the scroll position are still here on return.
class LogFoodScreen extends ConsumerStatefulWidget {
  const LogFoodScreen({super.key, required this.dayKey, required this.meal, this.scope = FoodScope.search, this.pick = false});

  /// Selection only (a saved meal's or recipe's editor): the chosen food and its confirmed amount are returned as a
  /// [FoodDraft]. Nothing is logged, and no meal or date is asked for.
  final bool pick;

  /// The list it opens on (Eat's coach opens Favourites or My foods directly).
  final FoodScope scope;

  /// `meal` is where the meal selector starts; the user can change it before choosing a food.
  final String dayKey, meal;

  /// How long typing has to pause before the wider database is asked on its own.
  static const pause = Duration(milliseconds: 600);
  @override
  ConsumerState<LogFoodScreen> createState() => _LogFoodScreenState();
}

SearchFields _fields(Suggestion s) => s.common?.fields ?? SearchFields(s.item.name, brand: s.item.brand);

class _LogFoodScreenState extends ConsumerState<LogFoodScreen> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  late String _meal = meals.contains(widget.meal) ? widget.meal : meals.first;
  late FoodScope _scope = widget.scope;

  /// Null is "All". A category only ever filters foods the catalog classifies.
  String? _category;

  /// The wider search. [_asked] is the question its state belongs to; [_token] changes whenever the question on
  /// screen changes, so an answer to an earlier question (or to one since cleared) is dropped when it arrives.
  Timer? _debounce;
  int _token = 0;
  String? _asked;
  List<FoodItem>? _results;
  LookupProblem? _problem;
  bool _searching = false;

  /// Answers already given while this screen is open, by question: typing the same thing again asks nothing.
  var _answers = <String, List<FoodItem>>{};

  /// A barcode being looked up, and why the last one produced no food.
  String? _lookingUp;
  String? _barcodeMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Opens the shared form. When it logged something, this screen is done too and returns to where logging began.
  Future<void> _open(FoodDraft draft) async {
    if (widget.pick) {
      final chosen = await push<FoodDraft>(context, FoodFormScreen(draft: draft, pick: true));
      if (chosen != null && mounted) Navigator.pop(context, chosen);
      return;
    }
    final logged = await push<bool>(context, FoodFormScreen(draft: draft));
    if (logged == true && mounted) Navigator.pop(context, true);
  }

  List<Json> get _saved => [for (final r in ref.read(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]) r.value.j];
  List<FoodEntry> get _journal => [for (final r in ref.read(foodJournalProvider).value ?? const <Stored<FoodEntry>>[]) r.value];

  /// A food found again (searched, scanned, or kept) with the portions the user defined on any copy of it they
  /// kept or logged, so "1 slice = 30 g" is defined once.
  FoodItem _withPortions(FoodItem item) => FoodScaling.withKnownPortions(item, [
        for (final j in _saved) if (j['isDeleted'] != true) FoodItem(j['item'] as Json? ?? const {}),
        for (final e in _journal) if (!e.isDeleted && e.source?['item'] is Map) FoodItem(e.source!['item'] as Json),
      ]);

  void _choose(Suggestion s) {
    final e = s.entry, common = s.common;
    // A food logged before starts from the same amount and values it was logged with, for the day and meal chosen now.
    _open(e == null
        ? FoodDraft.of(_withPortions(s.item), dayKey: widget.dayKey, meal: _meal, name: common?.nameIn(foodLang(context.l10n)), unitId: common?.unitId)
        : FoodDraft(dayKey: widget.dayKey, meal: _meal, name: e.name, amount: e.amountDescription, calories: e.calories, protein: e.protein, carbs: e.carbs, fat: e.fat,
            item: e.source == null ? null : s.item, quantity: (e.source?['quantity'] as num?)?.toDouble(), unitId: e.source?['unit'] as String?));
  }

  /// Saved meals & recipes for this day and meal. When something was logged there, this screen is done too.
  Future<void> _openMeals() async {
    final logged = await openMealsLibrary(context, dayKey: widget.dayKey, meal: _meal);
    if (logged == true && mounted) Navigator.pop(context, true);
  }

  /// Eating out for this day and the meal chosen above. When an order was logged there, this screen is done too.
  Future<void> _openEatingOut() async {
    final logged = await openEatingOut(context, dayKey: widget.dayKey, meal: _meal);
    if (logged == true && mounted) Navigator.pop(context, true);
  }

  /// What the wider search would be asked now: the typed words, normalized. Empty while it does not apply: in
  /// the owner's own lists, and under a category, which the wider database cannot filter by.
  String get _question => _scope == FoodScope.search && _category == null ? normalizeSearch(_query.text) : '';

  void _forget() {
    _debounce?.cancel();
    _token++;
    _asked = null;
    _results = null;
    _problem = null;
    _searching = false;
  }

  /// The query, the list or the category changed. The same question keeps its answer; a new one drops whatever
  /// was shown or still on its way, and is asked after a pause only when the phone has nothing for it.
  void _changed() {
    final question = _question;
    if (question == _asked) return setState(() {});
    setState(() {
      _forget();
      final known = _answers[question];
      if (known != null) {
        _asked = question;
        _results = known;
      }
    });
    final catalog = ref.read(commonFoodsProvider).value;
    if (_results != null || question.length < 3 || catalog == null || !ref.read(compatibilityProvider).supports('food.search')) return;
    final local = searchLocal(question, catalog: catalog, saved: _saved, journal: _journal, seen: ref.read(seenFoodsProvider).value ?? const []);
    if (local.own.isEmpty && local.common.isEmpty) _debounce = Timer(LogFoodScreen.pause, _searchMore);
  }

  /// Asks the wider database for what is typed, once. A second tap while it is answering joins the first.
  Future<void> _searchMore() async {
    final text = _query.text.trim(), question = _question;
    if (question.length < 2 || _searching && _asked == question) return;
    _debounce?.cancel();
    final token = ++_token, answers = _answers;
    setState(() {
      _asked = question;
      _searching = true;
      _results = null;
      _problem = null;
    });
    try {
      final found = answers[question] ?? await ref.read(foodDiscoveryProvider).search(text);
      // A late answer is still the answer to its own question: kept for when that is asked again, shown only if
      // it is still the question on screen.
      answers[question] = found;
      if (!mounted || token != _token) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    } on LookupFailure catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _problem = e.problem;
        _searching = false;
      });
    }
  }

  Future<void> _scan() async {
    setState(() => _barcodeMessage = null);
    final code = await push<String>(context, const BarcodeScanScreen());
    if (code == null || !mounted || _lookingUp != null) return; // cancelled, or a lookup is already running
    setState(() => _lookingUp = code);
    try {
      final item = await ref.read(foodDiscoveryProvider).barcode(code);
      if (!mounted) return;
      setState(() => _lookingUp = null);
      await _open(FoodDraft.of(_withPortions(item), dayKey: widget.dayKey, meal: _meal));
    } on LookupFailure catch (e) {
      if (!mounted) return;
      final l = context.l10n, shown = ltr(code);
      setState(() {
        _lookingUp = null;
        _barcodeMessage = switch (e.problem) {
          LookupProblem.notFound => l.foodBarcodeNotFound(shown),
          // The app knows the lookup did not get through, not why.
          LookupProblem.offline => l.foodBarcodeOffline(shown),
          LookupProblem.timeout => l.foodBarcodeTimeout(shown),
          LookupProblem.rateLimited => l.foodBarcodeRateLimited,
          LookupProblem.invalid => l.foodBarcodeInvalid,
          _ => l.foodBarcodeUnavailable,
        };
      });
    }
  }

  /// Why the wider search produced nothing, said as what the app actually knows.
  static String _problemText(AppLocalizations l, LookupProblem problem, {required bool hasLocal}) {
    final still = hasLocal ? l.foodSearchStillLocal : l.foodSearchStillScan;
    return switch (problem) {
      LookupProblem.offline => '${l.foodSearchOffline} $still',
      LookupProblem.timeout => '${l.foodSearchTimeout} $still',
      LookupProblem.rateLimited => '${l.foodSearchRateLimited} $still',
      LookupProblem.notConfigured => l.foodSearchNotConfigured,
      LookupProblem.invalid || LookupProblem.notFound => l.foodSearchInvalid,
      LookupProblem.unavailable => '${l.foodSearchUnavailable} $still',
    };
  }

  /// Arabic letters typed, or an app language other than English: the wider database (USDA, in English) may not
  /// understand the words even though the food exists.
  bool _nonEnglish(String q) => RegExp('[؀-ۿ]').hasMatch(q) || foodLang(context.l10n) != 'en';

  Widget _row(Suggestion s, String keyPrefix, {String? id}) => _FoodRow(key: Key('$keyPrefix-${id ?? s.item.key}'), facts: rowFacts(s, context.l10n), onTap: () => _choose(s));

  Widget _status(IconData icon, String text, {Key? key, Tone tone = Tone.neutral}) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: StatusLine(icon, text, key: key, tone: tone));

  Widget _note(String text, Key key) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(text, key: key, style: context.caption));

  /// The Search list for what is typed: the owner's matches and the catalog's, then the wider database.
  List<Widget> _searchRows(CommonFoodCatalog catalog, List<Json> saved, List<FoodEntry> journal, List<FoodItem> seen, bool supported) {
    final l = context.l10n;
    final q = _query.text.trim(), category = _category;
    final categoryName = category == null ? null : foodCategoryLabel(l, category);
    if (q.isEmpty && category == null) {
      final recent = localSuggestions(saved: const [], journal: journal, seen: const []).take(5);
      return [
        if (recent.isNotEmpty) _GroupLabel(l.foodScopeRecent),
        for (final s in recent) _row(Suggestion(s.item, s.origin, entry: s.entry, common: catalog.of(s.item)), 'recent'),
        _note(l.foodSearchGuide, const Key('food-search-guide')),
      ];
    }

    // What the wider search just returned is also kept on the phone as "seen"; it stays listed under More foods,
    // where it came from, instead of moving into Your foods the moment it arrives.
    final fresh = _asked == _question ? {for (final i in _results ?? const <FoodItem>[]) i.key} : const <String>{};
    final local = searchLocal(q, catalog: catalog, saved: saved, journal: journal, seen: [for (final i in seen) if (!fresh.contains(i.key)) i], category: category);
    final hasLocal = local.own.isNotEmpty || local.common.isNotEmpty;
    int best(List<Suggestion> l) => l.isEmpty ? 9 : matchScore(q, _fields(l.first)) ?? 9;
    final own = [if (local.own.isNotEmpty) _GroupLabel(l.foodGroupYours), for (final s in local.own.take(12)) _row(s, 'local')];
    final common = [
      if (local.common.isNotEmpty) _GroupLabel(categoryName ?? l.foodGroupCommon),
      for (final s in category == null ? local.common.take(12) : local.common) _row(s, 'common', id: s.common!.id),
    ];
    final shown = {for (final s in local.own) s.item.key, for (final s in local.common) s.item.key};
    final found = _asked == _question && _results != null ? rankFound(q, _results!, catalog: catalog, shown: shown) : const <Suggestion>[];

    return [
      // Whichever group holds the better match comes first; your own foods win a tie.
      ...(best(local.common) < best(local.own) ? [...common, ...own] : [...own, ...common]),
      if (category != null) ...[
        if (!hasLocal) _status(Icons.search_off, q.isEmpty ? l.foodCategoryEmpty(categoryName!) : l.foodCategoryNoMatch(categoryName!, q), key: const Key('food-search-empty')),
        // A category is a property of the catalog. Foods without one are left out, and that is said.
        _note(l.foodCategoryNote, const Key('food-category-note')),
      ] else if (!supported)
        _status(Icons.cloud_off_outlined, _problemText(l, LookupProblem.notConfigured, hasLocal: hasLocal), key: const Key('food-search-problem'))
      else if (_searching)
        _status(Icons.hourglass_empty, l.foodSearchBusy, key: const Key('food-search-busy'))
      else if (_asked != _question) ...[
        if (!hasLocal) _status(Icons.search, l.foodSearchLocalEmpty(q), key: const Key('food-search-local-empty')),
        if (_question.length >= 2)
          _LinkRow(key: const Key('food-search-online'), title: l.foodSearchMore, subtitle: l.foodSearchMoreSubtitle(q), accent: true, onTap: _searchMore),
      ] else if (_problem != null) ...[
        _status(Icons.cloud_off_outlined, _problemText(l, _problem!, hasLocal: hasLocal), key: const Key('food-search-problem'), tone: Tone.warning),
        if (_problem != LookupProblem.notConfigured) ListRow(key: const Key('food-search-retry'), icon: Icons.refresh, title: l.actionTryAgain, onTap: _searchMore),
      ] else if (found.isEmpty)
        // Said only when the database answered and had nothing (more): a failed search never reads as "no foods".
        // In another language the provider may simply not know the words: the way on is said, never "no such food".
        _status(Icons.search_off, _nonEnglish(q) ? l.foodSearchNoneNonEnglish(q) : hasLocal ? l.foodSearchNoOthers(q) : l.foodSearchNoneFound(q),
            key: const Key('food-search-empty'))
      else ...[
        _GroupLabel(l.foodGroupMore),
        for (final s in found) _row(s, 'result'),
        _note(l.foodSearchCredit, const Key('food-search-credit')),
      ],
    ];
  }

  /// One of the owner's own lists, narrowed by what is typed.
  List<Widget> _ownRows(CommonFoodCatalog catalog, List<Json> saved, List<FoodEntry> journal) {
    final l = context.l10n;
    final q = _query.text.trim();
    final (origin, prefix, title, body) = switch (_scope) {
      FoodScope.recent => (Origin.recent, 'recent', l.foodRecentEmptyTitle, l.foodRecentEmptyBody),
      FoodScope.favourites => (Origin.favourite, 'favourite', l.foodFavouritesEmptyTitle, l.foodFavouritesEmptyBody),
      _ => (Origin.mine, 'mine', l.foodMineEmptyTitle, l.foodMineEmptyBody),
    };
    // Each list is built on its own, so a favourite that was also logged is in both.
    bool belongs(Json j) => origin == Origin.favourite ? j['isFavourite'] == true : FoodItem(j['item'] as Json? ?? const {}).source == 'user';
    final all = [
      for (final s in localSuggestions(saved: origin == Origin.recent ? const [] : saved.where(belongs).toList(), journal: origin == Origin.recent ? journal : const [], seen: const []))
        if (s.origin == origin) Suggestion(s.item, s.origin, saved: s.saved, entry: s.entry, common: catalog.of(s.item)),
    ];
    final matching = rankByRelevance(q, all, _fields);
    return [
      if (all.isEmpty) EmptyState(title, body) else if (matching.isEmpty) _status(Icons.search_off, l.foodListNoMatch(q), key: const Key('food-search-empty')),
      for (final s in matching.take(40)) _row(s, prefix),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Everything listed here belongs to one account. When the owner changes, what was found for the last one goes.
    ref.listen(ownerProvider, (_, _) => setState(() {
          _forget();
          _answers = {}; // a new map: an answer still on its way for the last owner lands in the old one
        }));
    final q = _query.text.trim();
    final catalog = ref.watch(commonFoodsProvider).value ?? CommonFoodCatalog.empty;
    final saved = [for (final r in ref.watch(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]) r.value.j];
    final journal = [for (final r in ref.watch(foodJournalProvider).value ?? const <Stored<FoodEntry>>[]) r.value];
    final seen = ref.watch(seenFoodsProvider).value ?? const <FoodItem>[];
    final supported = ref.watch(compatibilityProvider).supports('food.search');
    final inset = context.inset;
    final l = context.l10n;

    final top = Padding(
      padding: EdgeInsets.fromLTRB(inset, 4, inset, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(
            key: const Key('food-back'), tooltip: MaterialLocalizations.of(context).backButtonTooltip, padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart,
            constraints: const BoxConstraints(minWidth: Targets.minimum, minHeight: Targets.minimum),
            icon: const Icon(Icons.arrow_back_ios_new, size: 22), onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(child: Heading(l.foodAddTitle, size: 40, serif: true)),
          CoachHelpEntry(id: 'food.search', label: l.foodHelpSearch),
        ]),
        if (!widget.pick)
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
            _MealSelector(meal: _meal, onChanged: (m) => setState(() => _meal = m)),
            Text('· ${longDate(widget.dayKey)}', style: context.caption),
          ]),
        const SizedBox(height: 8),
        TextField(
          key: const Key('food-search'), controller: _query, textInputAction: TextInputAction.search, autocorrect: false,
          onChanged: (_) => _changed(),
          onSubmitted: (_) {
            FocusScope.of(context).unfocus();
            if (supported) _searchMore();
          },
          style: context.sansStyle(17),
          decoration: InputDecoration(
            hintText: l.foodSearchHint, prefixIcon: const Icon(Icons.search, size: 26), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.panel), borderSide: BorderSide(color: context.c.outline)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.panel), borderSide: BorderSide(color: context.c.accent, width: 2)),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    key: const Key('food-search-clear'), tooltip: l.foodSearchClear,
                    icon: Container(width: 30, height: 30, decoration: BoxDecoration(color: context.c.sunken, shape: BoxShape.circle), child: Icon(Icons.close, size: 18, color: context.c.text)),
                    onPressed: () {
                      _query.clear();
                      _changed();
                    }),
          ),
        ),
        const SizedBox(height: 10),
        // The second way in, as prominent as the field.
        SecondaryButton(l.foodScanBarcode, key: const Key('food-scan'), icon: Icons.qr_code_scanner, onPressed: _lookingUp != null ? null : _scan),
        const SizedBox(height: 10),
        _Tabs<FoodScope>(
          values: FoodScope.values, selected: _scope, keyPrefix: 'food-scope',
          label: (s) => switch (s) { FoodScope.search => l.foodScopeSearch, FoodScope.recent => l.foodScopeRecent, FoodScope.favourites => l.foodScopeFavourites, FoodScope.mine => l.foodScopeMine },
          onChanged: (s) {
            _scope = s;
            _changed();
          },
        ),
      ]),
    );

    final rows = <Widget>[
      // At the top of the results, so the search field never moves: once, the first time this page is in view with no
      // keyboard up; afterwards from the help entry beside Scan. Typing a search puts it away: the results come first.
      if (_query.text.trim().isEmpty) CoachSpot(
        id: 'food.search', introduce: true, padding: const EdgeInsets.only(top: 4, bottom: 8),
        say: CoachSay(l.foodSearchCoach),
      ),
      if (_scope == FoodScope.search && catalog.categories.isNotEmpty)
        _Chips(
          values: [null, ...catalog.categories], selected: _category,
          onChanged: (c) {
            _category = c;
            _changed();
          },
        ),
      if (_lookingUp != null) _status(Icons.hourglass_empty, l.foodBarcodeLookingUp(ltr(_lookingUp!))),
      if (_barcodeMessage != null) _status(Icons.info_outline, _barcodeMessage!, key: const Key('barcode-message'), tone: Tone.warning),
      ...(_scope == FoodScope.search ? _searchRows(catalog, saved, journal, seen, supported) : _ownRows(catalog, saved, journal)),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: GroupCard(children: [
          GroupRow(
            key: const Key('food-manual'), icon: Icons.edit_outlined, title: l.foodManualTitle, subtitle: l.foodManualSubtitle,
            onTap: () => _open(FoodDraft(dayKey: widget.dayKey, meal: _meal, name: q)),
          ),
          // Several foods at once, for this day and the meal chosen above. Not offered while picking one food for a meal.
          if (!widget.pick)
            GroupRow(
              key: const Key('food-saved-meals'), icon: Icons.menu_book_outlined, title: l.mealsLibraryTitle, subtitle: l.mealsFromAddFoodSubtitle,
              onTap: _openMeals,
            ),
          if (!widget.pick)
            GroupRow(
              key: const Key('food-eating-out'), icon: Icons.storefront_outlined, title: l.eatOutTitle, subtitle: l.eatOutEntrySubtitle,
              onTap: _openEatingOut,
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Text(l.foodFooter, key: const Key('food-footer'), style: context.caption),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(l.foodCredits, style: context.caption),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => Column(children: [
            // The search field stays put while results scroll. On a very short window (large text, keyboard up)
            // this block scrolls within its share instead of pushing the results off the screen.
            ConstrainedBox(constraints: BoxConstraints(maxHeight: box.maxHeight * 0.7), child: SingleChildScrollView(child: top)),
            Expanded(
              child: ListView(
                controller: _scroll, padding: EdgeInsets.fromLTRB(inset, 4, inset, 28), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: rows,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A quiet heading over a group of rows.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 2), child: Semantics(header: true, child: Text(text, style: context.titleStyle(18))));
}

/// The meal the food will be logged under. It starts as the meal the screen was opened for and can be changed.
class _MealSelector extends StatelessWidget {
  const _MealSelector({required this.meal, required this.onChanged});
  final String meal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        key: const Key('food-meal-select'), tooltip: context.l10n.foodChangeMeal, initialValue: meal, onSelected: onChanged, color: context.c.surface,
        itemBuilder: (_) => [for (final m in meals) PopupMenuItem(key: Key('food-meal-option-$m'), value: m, child: Text(mealLabel(context.l10n, m)))],
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.minimum, minWidth: Targets.minimum),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(mealLabel(context.l10n, meal), style: context.sansStyle(18, weight: FontWeight.w500, color: context.c.secondary))),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 22, color: context.c.secondary),
          ]),
        ),
      );
}

/// The lists as a segmented track, in the shared [Segmented] look (the chosen one filled with the pale tint and its
/// ink). Four labels do not fit every phone, so the track spreads them out when they fit and scrolls sideways when
/// they do not, instead of shrinking or cutting a label.
class _Tabs<T extends Enum> extends StatelessWidget {
  const _Tabs({required this.values, required this.selected, required this.label, required this.onChanged, required this.keyPrefix});
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final ink = GoColors.panelOf(context.c).text;
    final radius = BorderRadius.circular(Radii.field - 2);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(Radii.field + 1), border: Border.all(color: context.c.divider)),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              for (final v in values)
                Semantics(
                  selected: v == selected, button: true, inMutuallyExclusiveGroup: true,
                  child: InkWell(
                    key: Key('$keyPrefix-${v.name}'), borderRadius: radius,
                    onTap: () {
                      if (v != selected) Haptics.selection();
                      onChanged(v);
                    },
                    child: AnimatedContainer(
                      duration: context.motion(Motion.quick), curve: Motion.curve,
                      constraints: const BoxConstraints(minHeight: Targets.minimum, minWidth: Targets.minimum), padding: const EdgeInsets.symmetric(horizontal: 14),
                      // Fill, weight and a strong luminance step mark the choice, so it also reads in grayscale.
                      decoration: BoxDecoration(color: v == selected ? context.c.tint : Colors.transparent, borderRadius: radius),
                      // Shrink-wrapped: an Align with no factor would take all the height a sideways scroller offers.
                      child: Center(widthFactor: 1, heightFactor: 1, child: Text(label(v), style: context.sansStyle(15, weight: v == selected ? FontWeight.w700 : FontWeight.w500, color: v == selected ? ink : context.c.text))),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// All, then the catalog's categories, in one row that scrolls sideways.
class _Chips extends StatelessWidget {
  const _Chips({required this.values, required this.selected, required this.onChanged});
  final List<String?> values;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Semantics(
                selected: v == selected, button: true, inMutuallyExclusiveGroup: true,
                child: InkWell(
                  key: Key('food-category-${v ?? 'all'}'), customBorder: const StadiumBorder(),
                  onTap: () {
                    if (v != selected) Haptics.selection();
                    onChanged(v);
                  },
                  // A 48 px target around a 38 px pill.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Targets.minimum, minWidth: Targets.minimum),
                    child: Center(
                      widthFactor: 1, heightFactor: 1,
                      child: AnimatedContainer(
                        duration: context.motion(Motion.quick), curve: Curves.easeOut,
                        constraints: const BoxConstraints(minHeight: 38), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                            color: v == selected ? context.c.accentSoft : context.c.surface, borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: v == selected ? context.c.accent : context.c.divider, width: v == selected ? 1.5 : 1)),
                        child: Text(v == null ? context.l10n.foodCategoryAll : foodCategoryLabel(context.l10n, v, short: true), style: context.sansStyle(14.5, weight: v == selected ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// One food: its name, what tells it apart (its kind, brand or source), the amount its values are for, calories and
/// protein, and a chevron. The whole row opens the amount form; it never logs. No photograph: there is no licensed
/// picture of each food.
class _FoodRow extends StatelessWidget {
  const _FoodRow({super.key, required this.facts, required this.onTap});
  final RowFacts facts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // With large text or on a narrow phone, protein joins the line under the name instead of crowding it.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 350;
    final l = context.l10n;
    final kcal = l.eatKcalValue(facts.calories == null ? '—' : formatNumber(facts.calories!.roundToDouble()));
    final protein = facts.protein == null ? l.foodRowProteinUnknown : l.eatProteinGramsValue(formatNumber((facts.protein! * 10).roundToDouble() / 10));
    final values = stacked ? '${facts.basis} · $kcal · $protein' : '${facts.basis} · $kcal';
    String spoken(String text) => text.replaceAll('—', l.foodUnknownSaid);
    return Column(children: [
      Semantics(
        button: true, hint: l.foodChooseHint,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.navigation + 6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(facts.title, style: context.sansStyle(17, weight: FontWeight.w600)),
                    if (facts.detail != null) Padding(padding: const EdgeInsets.only(top: 1), child: Text(facts.detail!, style: context.sansStyle(14.5, color: context.c.secondary))),
                    Text(values, semanticsLabel: spoken(values), style: context.caption),
                  ]),
                ),
                if (!stacked) Padding(padding: const EdgeInsetsDirectional.only(start: 10), child: Text(protein, semanticsLabel: spoken(protein), style: context.sansStyle(14.5, weight: FontWeight.w500))),
                Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: Icon(Icons.chevron_right, size: 24, color: context.c.secondary)),
              ]),
            ),
          ),
        ),
      ),
      const Rule(),
    ]);
  }
}

/// A plain link row: an accented one for the next step ("Search more foods"), a quiet one for the way out.
class _LinkRow extends StatelessWidget {
  const _LinkRow({super.key, required this.title, this.subtitle, this.accent = false, required this.onTap});
  final String title;
  final String? subtitle;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(children: [
        Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Targets.navigation),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(title, style: context.sansStyle(16.5, weight: accent ? FontWeight.w600 : FontWeight.w500, color: accent ? context.c.accent : context.c.secondary)),
                      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: context.caption)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, size: 22, color: accent ? context.c.accent : context.c.secondary),
                ]),
              ),
            ),
          ),
        ),
        const Rule(),
      ]);
}
