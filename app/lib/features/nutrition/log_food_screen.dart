import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
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

/// Where a food to log is found: search, a barcode, favourites, recent foods, the user's own foods, or typing it
/// in. Every one of them opens the same form; nothing on this screen records anything as eaten.
/// The day and meal it was opened for are carried into the form, and what was typed here is still here on return.
class LogFoodScreen extends ConsumerStatefulWidget {
  const LogFoodScreen({super.key, required this.dayKey, required this.meal});
  final String dayKey, meal;
  @override
  ConsumerState<LogFoodScreen> createState() => _LogFoodScreenState();
}

class _LogFoodScreenState extends ConsumerState<LogFoodScreen> {
  final _query = TextEditingController();

  /// The online search most recently asked for, and what came of it. A slower answer to an earlier search is dropped.
  String? _asked;
  List<FoodItem>? _results;
  LookupProblem? _searchProblem;
  bool _searching = false;

  /// A barcode being looked up, and why the last one produced no food.
  String? _lookingUp;
  String? _barcodeMessage;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Opens the shared form. When it logged something, this screen is done too and returns to where logging began.
  Future<void> _open(FoodDraft draft) async {
    final logged = await push<bool>(context, FoodFormScreen(draft: draft));
    if (logged == true && mounted) Navigator.pop(context, true);
  }

  /// A food found again (searched, scanned, or kept) with the portions the user defined on any copy of it they
  /// kept or logged, so "1 slice = 30 g" is defined once.
  FoodItem _withPortions(FoodItem item) => FoodScaling.withKnownPortions(item, [
        for (final r in ref.read(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]) if (!r.value.isDeleted) r.value.item,
        for (final r in ref.read(foodJournalProvider).value ?? const <Stored<FoodEntry>>[]) if (!r.value.isDeleted && r.value.source?['item'] is Map) FoodItem(r.value.source!['item'] as Json),
      ]);

  void _choose(Suggestion s) {
    final e = s.entry;
    // A food logged before starts from the same amount and values it was logged with, for the day and meal chosen now.
    _open(e == null
        ? FoodDraft.of(_withPortions(s.item), dayKey: widget.dayKey, meal: widget.meal)
        : FoodDraft(dayKey: widget.dayKey, meal: widget.meal, name: e.name, amount: e.amountDescription, calories: e.calories, protein: e.protein, carbs: e.carbs, fat: e.fat,
            item: e.source == null ? null : s.item, quantity: (e.source?['quantity'] as num?)?.toDouble(), unitId: e.source?['unit'] as String?));
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2 || _searching && _asked == q) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _asked = q;
      _searching = true;
      _results = null;
      _searchProblem = null;
    });
    try {
      final found = await ref.read(foodDiscoveryProvider).search(q);
      if (mounted && _asked == q) setState(() => _results = found);
    } on LookupFailure catch (e) {
      if (mounted && _asked == q) setState(() => _searchProblem = e.problem);
    } finally {
      if (mounted && _asked == q) setState(() => _searching = false);
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
      await _open(FoodDraft.of(_withPortions(item), dayKey: widget.dayKey, meal: widget.meal));
    } on LookupFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _lookingUp = null;
        _barcodeMessage = switch (e.problem) {
          LookupProblem.notFound => 'No product was found for barcode $code. You can search for it by name or enter it yourself.',
          LookupProblem.offline => 'You are offline and barcode $code has not been looked up on this phone before. You can enter the food yourself.',
          LookupProblem.rateLimited => 'The product database is busy right now. Try again in a few minutes, or enter the food yourself.',
          LookupProblem.invalid => 'That is not a product barcode.',
          _ => 'The product database could not be reached. Try again, or enter the food yourself.',
        };
      });
    }
  }

  static String _summary(FoodItem i) {
    final kcal = i.nutrient('calories');
    return [
      if (i.brand != null) i.brand!,
      if (i.description != null) i.description!,
      kcal == null ? 'Calories unknown' : '${formatNumber(kcal)} kcal ${FoodScaling.basisText(i)}',
    ].join(' · ');
  }

  Widget _row(Suggestion s, {String? tag, required String keyPrefix}) => ListRow(
        key: Key('$keyPrefix-${s.item.key}'),
        title: s.item.name,
        subtitle: s.entry != null && s.entry!.source == null ? '${s.entry!.amountDescription} · as you logged it' : [?tag, _summary(s.item)].join(' · '),
        onTap: () => _choose(s),
      );

  static const _tags = {Origin.favourite: 'Favourite', Origin.mine: 'My food', Origin.recent: 'Recent', Origin.seen: 'Seen before'};

  List<Widget> _online(String q, bool searchSupported) {
    if (!searchSupported) return [const StatusLine(Icons.cloud_off_outlined, 'Online food search is not set up on this server. You can still scan a barcode or enter the food yourself.')];
    if (_searching) return [const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: StatusLine(Icons.hourglass_empty, 'Searching…'))];
    if (_asked != q) {
      return [
        // Asked for on purpose: the database is shared and counted per request, so it is not queried as you type.
        SecondaryButton('Search online for "$q"', key: const Key('food-search-online'), icon: Icons.search, onPressed: q.length < 2 ? null : _search),
      ];
    }
    if (_searchProblem != null) {
      return [
        StatusLine(
            Icons.cloud_off_outlined,
            switch (_searchProblem!) {
              LookupProblem.offline => 'You are offline, so only foods already on this phone are shown. You can still enter the food yourself.',
              LookupProblem.rateLimited => 'The food database is busy right now. Try again in a few minutes, or enter the food yourself.',
              LookupProblem.notConfigured => 'Online food search is not set up on this server. You can still scan a barcode or enter the food yourself.',
              _ => 'The food database could not be reached. Try again, or enter the food yourself.',
            },
            tone: Tone.warning),
        if (_searchProblem != LookupProblem.notConfigured) Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('food-search-retry'), onPressed: () => setState(() => _asked = null), child: const Text('Try again'))),
      ];
    }
    final results = _results ?? const <FoodItem>[];
    if (results.isEmpty) return [Text('Nothing was found for "$q". Try other words, scan the barcode, or enter the food yourself.', key: const Key('food-search-empty'), style: context.body)];
    return [
      for (final item in results) _row(Suggestion(item, Origin.seen), keyPrefix: 'result'),
      const SizedBox(height: 10),
      Text('Results from USDA FoodData Central, in English, mostly foods sold or eaten in the United States. Values are as published and may differ from your packet.', style: context.caption),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim();
    final saved = [for (final r in ref.watch(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]) r.value.j];
    final journal = [for (final r in ref.watch(foodJournalProvider).value ?? const <Stored<FoodEntry>>[]) r.value];
    // A food the online search just returned is listed once, under Online, not again as "seen before".
    final online = {if (_asked == q) for (final i in _results ?? const <FoodItem>[]) i.key};
    final suggestions = [
      for (final s in localSuggestions(saved: saved, journal: journal, seen: q.isEmpty ? const [] : ref.watch(seenFoodsProvider).value ?? const [], query: q))
        if (s.origin != Origin.seen || !online.contains(s.item.key)) s,
    ];
    List<Suggestion> of(Origin o) => [for (final s in suggestions) if (s.origin == o) s].take(8).toList();
    final searchSupported = ref.watch(compatibilityProvider).supports('food.search');

    return AppPage(
      title: 'Log food',
      subtitle: '${widget.meal} · ${longDate(widget.dayKey)}',
      children: [
        TextField(
          key: const Key('food-search'), controller: _query, textInputAction: TextInputAction.search, textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}), onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: 'Search foods', prefixIcon: const Icon(Icons.search),
            suffixIcon: q.isEmpty ? null : IconButton(key: const Key('food-search-clear'), tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: () => setState(_query.clear)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SecondaryButton('Scan barcode', key: const Key('food-scan'), icon: Icons.qr_code_scanner, expand: false, onPressed: _lookingUp != null ? null : _scan),
          SecondaryButton('Enter it yourself', key: const Key('food-manual'), icon: Icons.edit_outlined, expand: false,
              onPressed: () => _open(FoodDraft(dayKey: widget.dayKey, meal: widget.meal, name: q))),
        ]),
        if (_lookingUp != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.hourglass_empty, 'Looking up barcode $_lookingUp…')),
        if (_barcodeMessage != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.info_outline, _barcodeMessage!, key: const Key('barcode-message'), tone: Tone.warning)),
        const SizedBox(height: 22),
        if (q.isEmpty) ...[
          if (suggestions.isEmpty) const EmptyState('Nothing saved yet', 'Foods you log, favourite or save will be listed here, ready to log again.'),
          for (final (origin, title) in const [(Origin.favourite, 'Favourites'), (Origin.recent, 'Recent'), (Origin.mine, 'My foods')])
            if (of(origin).isNotEmpty) ...[
              SectionHeader(title),
              for (final s in of(origin)) _row(s, keyPrefix: origin.name),
              const SizedBox(height: 18),
            ],
        ] else ...[
          if (suggestions.isNotEmpty) ...[
            const SectionHeader('On this phone'),
            for (final s in suggestions.take(12)) _row(s, tag: _tags[s.origin], keyPrefix: 'local'),
            const SizedBox(height: 18),
          ],
          const SectionHeader('Online'),
          const SizedBox(height: 8),
          ..._online(q, searchSupported),
        ],
        const SizedBox(height: 18),
        Text('Barcodes are looked up in Open Food Facts (Open Database License), a volunteer-built database that is strongest for European and North American products. Searching uses USDA FoodData Central.', style: context.caption),
      ],
    );
  }
}
