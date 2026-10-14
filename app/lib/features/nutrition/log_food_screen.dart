import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../core/device_prefs.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'barcode_scan_screen.dart';
import 'food_discovery.dart';
import 'food_form.dart';
import 'food_item.dart';
import 'food_repository.dart';
import 'food_search.dart';

/// The lists a food can be picked from. Search covers everyday foods and the owner's own; the others are theirs.
enum FoodScope { search, recent, favourites, mine }

/// Add food: where a food to log is found. Typing searches the everyday foods bundled with the app and the
/// owner's own at once; the wider database is asked on a tap, or by itself when the phone has nothing for what
/// was typed. Every row opens the same form: nothing on this screen records anything as eaten.
/// The day is carried into the form, and so is the meal, which can be changed here first. What was typed, the
/// list and category chosen and the scroll position are still here on return.
class LogFoodScreen extends ConsumerStatefulWidget {
  const LogFoodScreen({super.key, required this.dayKey, required this.meal});

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
  FoodScope _scope = FoodScope.search;

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
        ? FoodDraft.of(_withPortions(s.item), dayKey: widget.dayKey, meal: _meal, name: common?.name, unitId: common?.unitId)
        : FoodDraft(dayKey: widget.dayKey, meal: _meal, name: e.name, amount: e.amountDescription, calories: e.calories, protein: e.protein, carbs: e.carbs, fat: e.fat,
            item: e.source == null ? null : s.item, quantity: (e.source?['quantity'] as num?)?.toDouble(), unitId: e.source?['unit'] as String?));
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
      setState(() {
        _lookingUp = null;
        _barcodeMessage = switch (e.problem) {
          LookupProblem.notFound => 'No product was found for barcode $code. You can search for it by name or create your own food.',
          // The app knows the lookup did not get through, not why.
          LookupProblem.offline => 'Barcode $code could not be looked up just now, and it has not been looked up on this phone before. That can be this phone\'s connection or the server. You can create your own food.',
          LookupProblem.timeout => 'The product database took too long to answer for barcode $code. Try again, or create your own food.',
          LookupProblem.rateLimited => 'The product database has had too many requests for now. Try again in a few minutes, or create your own food.',
          LookupProblem.invalid => 'That is not a product barcode.',
          _ => 'The product database is not answering right now. Try again, or create your own food.',
        };
      });
    }
  }

  /// Why the wider search produced nothing, said as what the app actually knows.
  static String _problemText(LookupProblem problem, {required bool hasLocal}) {
    final still = hasLocal ? ' The foods above are from this phone and still work.' : ' You can still scan a barcode or create your own food.';
    return switch (problem) {
      LookupProblem.offline => 'The wider food database could not be reached just now. That can be this phone\'s connection or the server.$still',
      LookupProblem.timeout => 'The wider food database took too long to answer.$still',
      LookupProblem.rateLimited => 'The wider food database has had too many requests for now. Try again in a few minutes.$still',
      LookupProblem.notConfigured => 'Wider food search is not set up on this server. Common foods, your own foods and barcodes still work.',
      LookupProblem.invalid || LookupProblem.notFound => 'That search could not be used. Try other words.',
      LookupProblem.unavailable => 'The wider food database is not answering right now. Try again in a moment.$still',
    };
  }

  Widget _row(Suggestion s, String keyPrefix, {String? id}) => _FoodRow(key: Key('$keyPrefix-${id ?? s.item.key}'), facts: rowFacts(s), onTap: () => _choose(s));

  Widget _status(IconData icon, String text, {Key? key, Tone tone = Tone.neutral}) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: StatusLine(icon, text, key: key, tone: tone));

  Widget _note(String text, Key key) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(text, key: key, style: context.caption));

  /// The Search list for what is typed: the owner's matches and the catalog's, then the wider database.
  List<Widget> _searchRows(CommonFoodCatalog catalog, List<Json> saved, List<FoodEntry> journal, List<FoodItem> seen, bool supported) {
    final q = _query.text.trim(), category = _category;
    if (q.isEmpty && category == null) {
      final recent = localSuggestions(saved: const [], journal: journal, seen: const []).take(5);
      return [
        if (recent.isNotEmpty) const _GroupLabel('Recent'),
        for (final s in recent) _row(Suggestion(s.item, s.origin, entry: s.entry, common: catalog.of(s.item)), 'recent'),
        _note('Type a food, such as "egg" or "rice", or pick a category. Everyday foods and your own are found without a connection.', const Key('food-search-guide')),
      ];
    }

    // What the wider search just returned is also kept on the phone as "seen"; it stays listed under More foods,
    // where it came from, instead of moving into Your foods the moment it arrives.
    final fresh = _asked == _question ? {for (final i in _results ?? const <FoodItem>[]) i.key} : const <String>{};
    final local = searchLocal(q, catalog: catalog, saved: saved, journal: journal, seen: [for (final i in seen) if (!fresh.contains(i.key)) i], category: category);
    final hasLocal = local.own.isNotEmpty || local.common.isNotEmpty;
    int best(List<Suggestion> l) => l.isEmpty ? 9 : matchScore(q, _fields(l.first)) ?? 9;
    final own = [if (local.own.isNotEmpty) const _GroupLabel('Your foods'), for (final s in local.own.take(12)) _row(s, 'local')];
    final common = [
      if (local.common.isNotEmpty) _GroupLabel(category ?? 'Common foods'),
      for (final s in category == null ? local.common.take(12) : local.common) _row(s, 'common', id: s.common!.id),
    ];
    final shown = {for (final s in local.own) s.item.key, for (final s in local.common) s.item.key};
    final found = _asked == _question && _results != null ? rankFound(q, _results!, catalog: catalog, shown: shown) : const <Suggestion>[];

    return [
      // Whichever group holds the better match comes first; your own foods win a tie.
      ...(best(local.common) < best(local.own) ? [...common, ...own] : [...own, ...common]),
      if (category != null) ...[
        if (!hasLocal) _status(Icons.search_off, q.isEmpty ? 'No common foods are filed under $category.' : 'No common food in $category matches "$q".', key: const Key('food-search-empty')),
        // A category is a property of the catalog. Foods without one are left out, and that is said.
        _note('Only common foods have a category. Choose All to include your own foods and the wider database.', const Key('food-category-note')),
      ] else if (!supported)
        _status(Icons.cloud_off_outlined, _problemText(LookupProblem.notConfigured, hasLocal: hasLocal), key: const Key('food-search-problem'))
      else if (_searching)
        _status(Icons.hourglass_empty, 'Searching more foods…', key: const Key('food-search-busy'))
      else if (_asked != _question) ...[
        if (!hasLocal) _status(Icons.search, 'Nothing on this phone matches "$q".', key: const Key('food-search-local-empty')),
        if (_question.length >= 2)
          ListRow(key: const Key('food-search-online'), icon: Icons.travel_explore, title: 'Search more foods', subtitle: 'Look up "$q" in USDA FoodData Central', onTap: _searchMore),
      ] else if (_problem != null) ...[
        _status(Icons.cloud_off_outlined, _problemText(_problem!, hasLocal: hasLocal), key: const Key('food-search-problem'), tone: Tone.warning),
        if (_problem != LookupProblem.notConfigured) ListRow(key: const Key('food-search-retry'), icon: Icons.refresh, title: 'Try again', onTap: _searchMore),
      ] else if (found.isEmpty)
        // Said only when the database answered and had nothing (more): a failed search never reads as "no foods".
        _status(Icons.search_off, hasLocal ? 'The wider database has no other foods for "$q".' : 'No foods were found for "$q". Try other words, scan the barcode, or create your own food.',
            key: const Key('food-search-empty'))
      else ...[
        const _GroupLabel('More foods'),
        for (final s in found) _row(s, 'result'),
        _note('From USDA FoodData Central, in English, mostly foods sold or eaten in the United States. Values are as published and may differ from your packet.', const Key('food-search-credit')),
      ],
    ];
  }

  /// One of the owner's own lists, narrowed by what is typed.
  List<Widget> _ownRows(CommonFoodCatalog catalog, List<Json> saved, List<FoodEntry> journal) {
    final q = _query.text.trim();
    final (origin, prefix, title, body) = switch (_scope) {
      FoodScope.recent => (Origin.recent, 'recent', 'Nothing logged yet', 'Foods you log are listed here, ready to log again.'),
      FoodScope.favourites => (Origin.favourite, 'favourite', 'No favourites yet', 'Mark a food with the star on its amount page to keep it here.'),
      _ => (Origin.mine, 'mine', 'No foods of your own yet', 'Create your own food below, or use "Save to My foods" on any food\'s amount page.'),
    };
    // Each list is built on its own, so a favourite that was also logged is in both.
    bool belongs(Json j) => origin == Origin.favourite ? j['isFavourite'] == true : FoodItem(j['item'] as Json? ?? const {}).source == 'user';
    final all = [
      for (final s in localSuggestions(saved: origin == Origin.recent ? const [] : saved.where(belongs).toList(), journal: origin == Origin.recent ? journal : const [], seen: const []))
        if (s.origin == origin) Suggestion(s.item, s.origin, saved: s.saved, entry: s.entry, common: catalog.of(s.item)),
    ];
    final matching = rankByRelevance(q, all, _fields);
    return [
      if (all.isEmpty) EmptyState(title, body) else if (matching.isEmpty) _status(Icons.search_off, 'Nothing in this list matches "$q".', key: const Key('food-search-empty')),
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

    final top = Padding(
      padding: EdgeInsets.fromLTRB(inset, 4, inset, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(
            key: const Key('food-back'), tooltip: 'Back', padding: EdgeInsets.zero, alignment: Alignment.centerLeft,
            constraints: const BoxConstraints(minWidth: Targets.minimum, minHeight: Targets.minimum),
            icon: const Icon(Icons.arrow_back_ios_new, size: 22), onPressed: () => Navigator.maybePop(context),
          ),
          const Expanded(child: Heading('Add food', size: 28)),
          TextButton.icon(key: const Key('food-scan'), onPressed: _lookingUp != null ? null : _scan, icon: const Icon(Icons.qr_code_scanner, size: 22), label: const Text('Scan')),
        ]),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
          _MealSelector(meal: _meal, onChanged: (m) => setState(() => _meal = m)),
          Text('· ${longDate(widget.dayKey)}', style: context.caption),
        ]),
        const SizedBox(height: 4),
        TextField(
          key: const Key('food-search'), controller: _query, textInputAction: TextInputAction.search, autocorrect: false,
          onChanged: (_) => _changed(),
          onSubmitted: (_) {
            FocusScope.of(context).unfocus();
            if (supported) _searchMore();
          },
          decoration: InputDecoration(
            hintText: 'Search foods', prefixIcon: const Icon(Icons.search),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    key: const Key('food-search-clear'), tooltip: 'Clear search', icon: const Icon(Icons.close),
                    onPressed: () {
                      _query.clear();
                      _changed();
                    }),
          ),
        ),
        const SizedBox(height: 6),
        _Tabs<FoodScope>(
          values: FoodScope.values, selected: _scope, keyPrefix: 'food-scope',
          label: (s) => const {FoodScope.search: 'Search', FoodScope.recent: 'Recent', FoodScope.favourites: 'Favourites', FoodScope.mine: 'My foods'}[s]!,
          onChanged: (s) {
            _scope = s;
            _changed();
          },
        ),
      ]),
    );

    final rows = <Widget>[
      if (_scope == FoodScope.search && catalog.categories.isNotEmpty)
        _Chips(
          values: [null, ...catalog.categories], selected: _category,
          onChanged: (c) {
            _category = c;
            _changed();
          },
        ),
      if (_lookingUp != null) _status(Icons.hourglass_empty, 'Looking up barcode $_lookingUp…'),
      if (_barcodeMessage != null) _status(Icons.info_outline, _barcodeMessage!, key: const Key('barcode-message'), tone: Tone.warning),
      ...(_scope == FoodScope.search ? _searchRows(catalog, saved, journal, seen, supported) : _ownRows(catalog, saved, journal)),
      ListRow(
        key: const Key('food-manual'), icon: Icons.edit_outlined, title: 'Can\'t find it? Create your own food',
        onTap: () => _open(FoodDraft(dayKey: widget.dayKey, meal: _meal, name: q)),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text('Choose a food to check the amount before logging.', key: const Key('food-footer'), style: context.caption),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('Common foods and wider search: USDA FoodData Central. Barcodes: Open Food Facts (Open Database License).', style: context.caption),
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
        key: const Key('food-meal-select'), tooltip: 'Change meal', initialValue: meal, onSelected: onChanged, color: context.c.surface,
        itemBuilder: (_) => [for (final m in meals) PopupMenuItem(key: Key('food-meal-option-$m'), value: m, child: Text(m))],
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.minimum, minWidth: Targets.minimum),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(meal, style: context.sansStyle(16, weight: FontWeight.w600))),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 22, color: context.c.secondary),
          ]),
        ),
      );
}

/// Quiet text tabs with an underline on the chosen one. They scroll sideways instead of shrinking or cutting a label.
class _Tabs<T extends Enum> extends StatelessWidget {
  const _Tabs({required this.values, required this.selected, required this.label, required this.onChanged, required this.keyPrefix});
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.c.divider))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final v in values)
              Semantics(
                selected: v == selected, button: true, inMutuallyExclusiveGroup: true,
                child: InkWell(
                  key: Key('$keyPrefix-${v.name}'),
                  onTap: () {
                    if (v != selected) Haptics.selection();
                    onChanged(v);
                  },
                  child: AnimatedContainer(
                    duration: context.motion(Motion.quick), curve: Curves.easeOut,
                    constraints: const BoxConstraints(minHeight: Targets.minimum, minWidth: Targets.minimum), padding: const EdgeInsets.symmetric(horizontal: 12),
                    // The underline, the weight and the colour all mark the choice, so it also reads in grayscale.
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: v == selected ? context.c.accent : Colors.transparent, width: 2.5))),
                    // Shrink-wrapped: an Align with no factor would take all the height a sideways scroller offers.
                    child: Center(widthFactor: 1, heightFactor: 1, child: Text(label(v), style: context.sansStyle(15.5, weight: v == selected ? FontWeight.w700 : FontWeight.w500, color: v == selected ? context.c.text : context.c.secondary))),
                  ),
                ),
              ),
          ]),
        ),
      );
}

/// All, then the catalog's categories, in one row that scrolls sideways.
class _Chips extends StatelessWidget {
  const _Chips({required this.values, required this.selected, required this.onChanged});
  final List<String?> values;
  final String? selected;
  final ValueChanged<String?> onChanged;

  static const _short = {'Carbohydrates': 'Carbs'};

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
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
                        child: Text(v == null ? 'All' : _short[v] ?? v, style: context.sansStyle(14.5, weight: v == selected ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// One food: its name, what tells it apart, the amount its values are for, calories and protein, and a plus that
/// chooses it. The row and the plus do the same thing: open the amount form. Neither logs.
class _FoodRow extends StatelessWidget {
  const _FoodRow({super.key, required this.facts, required this.onTap});
  final RowFacts facts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // With large text or on a narrow phone, protein joins the line under the name instead of crowding it.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 350;
    final kcal = '${facts.calories == null ? '—' : formatNumber(facts.calories!.roundToDouble())} kcal';
    final protein = facts.protein == null ? '— protein' : '${formatNumber((facts.protein! * 10).roundToDouble() / 10)} g protein';
    final values = stacked ? '${facts.basis} · $kcal · $protein' : '${facts.basis} · $kcal';
    String spoken(String text) => text.replaceAll('—', 'unknown');
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.navigation),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(facts.title, style: context.sansStyle(16, weight: FontWeight.w600)),
                  if (facts.detail != null) Text(facts.detail!, style: context.caption),
                  Text(values, semanticsLabel: spoken(values), style: context.caption),
                ]),
              ),
              if (!stacked) Padding(padding: const EdgeInsets.only(left: 10), child: Text(protein, semanticsLabel: spoken(protein), style: context.sansStyle(14.5, weight: FontWeight.w500))),
              IconButton(
                tooltip: 'Choose ${facts.title}', onPressed: onTap,
                icon: Container(
                  width: 34, height: 34, alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.c.accentSoft, shape: BoxShape.circle),
                  child: Icon(Icons.add, size: 22, color: context.c.accent),
                ),
              ),
            ]),
          ),
        ),
      ),
      const Rule(),
    ]);
  }
}
