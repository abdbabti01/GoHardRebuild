import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../coach/coach_bubble.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import 'food_item.dart';
import 'food_repository.dart';
import 'log_food_screen.dart';

/// Logging food from Today or Eat. A new entry starts at the place where a food is found (search, scan, saved,
/// recent or manual entry); an existing one opens straight in the form. Either way nothing is logged until the
/// form's own button is pressed, and the user comes back to where they started.
Future<void> openFoodForm(BuildContext context, {required String dayKey, FoodEntry? entry, String? meal}) => entry == null
    ? push(context, LogFoodScreen(dayKey: dayKey, meal: meal ?? 'Breakfast'))
    : push(context, FoodFormScreen(draft: FoodDraft.edit(entry), existing: entry));

/// The one form every way of finding a food leads to: review the food and its source, say how much, pick the
/// meal and date, then confirm. Pops `true` when an entry was logged or changed.
class FoodFormScreen extends ConsumerStatefulWidget {
  const FoodFormScreen({super.key, required this.draft, this.existing});

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
    if (v == null) throw InvalidFood('${key[0].toUpperCase()}${key.substring(1)} must be a number of zero or more, or left blank.');
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
    if (item != null && !((quantity ?? 0) > 0)) throw const InvalidFood('Enter how much you had, as a number above zero.');
    return FoodDraft(
        id: widget.draft.id, dayKey: _dayKey, meal: _meal, name: _name.text,
        amount: item == null ? _amount.text : FoodScaling.describe(item, quantity!, FoodScaling.unit(item, _unitId)),
        calories: _macro('calories'), protein: _macro('protein'), carbs: _macro('carbs'), fat: _macro('fat'), item: item, quantity: item == null ? null : quantity, unitId: _unitId);
  }

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
      if (mounted) setState(() => _error = e.message);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = 'This could not be saved on your phone. Your entry is still here. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<void> _save() async {
    if (_busy) return; // a second tap while the first is saving must not log the food twice
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
    if (ok && mounted) toast(context, 'Saved to My foods. Nothing was logged.');
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
    if (!await confirm(context, title: 'Remove ${e.name}?', body: 'This removes only "${e.name}" (${e.amountDescription}) from ${e.meal} on ${longDate(e.dayKey)}. Your other food stays.', action: 'Remove this food')) return;
    await ref.read(foodRepositoryProvider).remove(e);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: parseDayKey(_dayKey), firstDate: DateTime.utc(2020), lastDate: parseDayKey(ref.read(todayKeyProvider)).add(const Duration(days: 1)));
    if (picked != null) setState(() => _dayKey = dayKeyOf(picked));
  }

  /// The source in full (provider title, values per basis, brand, credit, barcode), on demand.
  void _details(FoodItem item) => showGoSheet<void>(context, title: 'Food details', builder: (_) => FoodSourceCard(item));

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final item = _item;
    final favourite = item != null && (ref.watch(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]).any((r) => !r.value.isDeleted && r.value.isFavourite && r.value.item.key == item.key);
    // "2 eggs (100 g)": what will be logged, in words. Null until there is a food and an amount above zero.
    String? amountLine;
    if (item != null && (_amountEaten ?? 0) > 0) {
      amountLine = FoodScaling.describe(item, _amountEaten!, FoodScaling.unit(item, _unitId));
    }
    final unit = item == null ? null : FoodScaling.unit(item, _unitId);
    // "1 egg = 50 g": what one of the chosen unit is, said only when its source (or the user) states it.
    final definition = unit == null || unit.size == null || unit.label.contains(unit.size!) ? null : '${unit.label} = ${unit.size}';
    final title = editing ? 'Edit food' : item == null ? 'New food' : (widget.draft.name.trim().isEmpty ? item.name : widget.draft.name);
    final qualifier = editing ? widget.draft.name : item == null ? null : ref.watch(commonFoodsProvider).value?.of(item)?.qualifier ?? item.brand;
    final missing = [if (item != null) for (final k in FoodItem.nutrientKeys) if (item.nutrient(k) == null) _nutrientLabels[k]!.toLowerCase()];
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
        if (item != null && _corrected.contains(key)) Text('Your value', style: context.sansStyle(13, color: context.c.accent, weight: FontWeight.w600)),
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
        decoration: InputDecoration(labelText: item == null ? 'What did you eat?' : 'Name in your journal'));

    return AppPage(
      title: title,
      subtitle: qualifier,
      actions: [
        if (item != null) const CoachHelpEntry(id: 'food.portion', label: 'Help with amounts and portions'),
        if (item != null && !editing)
          IconButton(
            key: const Key('food-favourite'), tooltip: favourite ? 'Remove from favourites' : 'Add to favourites',
            icon: Icon(favourite ? Icons.star : Icons.star_border, color: favourite ? context.c.accent : null), onPressed: _toggleFavourite,
          ),
      ],
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        PrimaryButton(editing ? 'Save changes' : 'Log food', key: const Key('food-save'), onPressed: _save, busy: _busy),
        TextButton(key: const Key('food-cancel'), onPressed: () => Navigator.pop(context), child: Text(editing ? 'Cancel and keep the recorded version' : 'Cancel')),
      ]),
      children: [
        if (item == null) ...[nameField, const SizedBox(height: 14)],
        DropdownButtonFormField<String>(
          key: const Key('food-meal'), initialValue: _meal, isExpanded: true, dropdownColor: context.c.surface,
          decoration: const InputDecoration(labelText: 'Meal', prefixIcon: Padding(padding: EdgeInsets.all(7), child: IconTile(Icons.restaurant, circle: true, size: 34))),
          items: [for (final m in meals) DropdownMenuItem(value: m, child: Text(m))],
          onChanged: (m) => setState(() => _meal = m ?? _meal),
        ),
        InkWell(
          onTap: _pickDate,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: StatusLine(Icons.event, 'For ${longDate(_dayKey)}. Tap to change the date.')),
        ),
        if (item != null) ...[
          const Rule(),
          _DetailsRow(item, showName: item.name != title, onTap: () => _details(item)),
          const Rule(),
          const SizedBox(height: 18),
          pair(
            TextField(
              key: const Key('food-quantity'), controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.done,
              style: context.numStyle(18),
              onChanged: (v) => setState(() {
                _exact = parseNonNegative(v);
                _rescale();
              }),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            KeyedSubtree(
              key: const Key('food-unit'),
              child: DropdownButtonFormField<String>(
                key: ValueKey(_portions), initialValue: _unitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Unit'), dropdownColor: context.c.surface,
                // The closed field shows the unit's name; the open list adds what one of them weighs.
                selectedItemBuilder: (_) => [for (final u in FoodScaling.units(item)) Text(u.noun == null ? u.label : '${u.noun}${u.tail}', overflow: TextOverflow.ellipsis)],
                items: [for (final u in FoodScaling.units(item)) DropdownMenuItem(key: Key('food-unit-${u.id}'), value: u.id, child: Text(u.menuLabel))],
                onChanged: (u) => setState(() => _changeUnit(u)),
              ),
            ),
          ),
          if (definition != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(definition, key: const Key('food-unit-definition'), style: context.caption)),
          // The amount in full, with its weight when the food states one, so the number and unit are read together.
          if (amountLine != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(amountLine, key: const Key('food-amount-line'), style: context.titleStyle(24))),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('food-add-portion'), onPressed: _busy ? null : _definePortion, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              iconAlignment: IconAlignment.end, icon: const Icon(Icons.chevron_right, size: 20), label: const Text('Add your own portion'),
            ),
          ),
          CoachSpot(
            id: 'food.portion', introduce: FoodScaling.units(item).length > 1, padding: const EdgeInsets.only(top: 4, bottom: 10),
            say: const CoachSay('You can count portions here. The weight is shown when a reliable conversion is available.'),
          ),
          const SizedBox(height: 4),
          const Rule(),
        ] else ...[
          TextField(key: const Key('food-amount'), controller: _amount, textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'How much?', helperText: 'In your own words, for example "200 g" or "2 slices"')),
        ],
        const SizedBox(height: 18),
        // The amount is spelled out with its unit: "1 g" and "1 cup" look the same in the number field alone.
        Semantics(header: true, child: Text(amountLine == null ? 'Nutrition' : 'Nutrition for $amountLine', key: const Key('food-amount-echo'), style: context.titleStyle(20))),
        const SizedBox(height: 4),
        Text(
            item == null
                ? 'Optional. Tap a value to enter it; a blank stays unknown and is never counted as zero.'
                : 'From the source, for this amount. Tap a value to correct it; a blank stays unknown and is never counted as zero.',
            style: context.caption),
        const SizedBox(height: 12),
        GroupCard(children: [macro('calories', 'Calories', 'kcal'), macro('protein', 'Protein', 'g'), macro('carbs', 'Carbs', 'g'), macro('fat', 'Fat', 'g')]),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: StatusLine(Icons.help_outline, 'This source gives no value for ${missing.join(', ')}. ${missing.length == 1 ? 'It stays' : 'They stay'} unknown unless you enter ${missing.length == 1 ? 'it' : 'them'}.'),
          ),
        if (item != null && _corrected.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('food-reset-values'),
              onPressed: () => setState(() {
                _corrected.clear();
                _rescale();
              }),
              child: const Text('Use the source\'s values again'),
            ),
          ),
        if (item != null) ...[const SizedBox(height: 18), nameField],
        const SizedBox(height: 10),
        if (!editing)
          Align(
            alignment: Alignment.centerLeft,
            // Plain text, so a long label wraps at large text sizes instead of running off a narrow phone.
            child: TextButton(key: const Key('food-save-reusable'), onPressed: _busy ? null : _saveReusable, child: const Text('Save to My foods without logging')),
          ),
        if (editing)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('food-remove'), onPressed: _remove, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Remove this food'))),
      ],
    );
  }
}

const _nutrientLabels = {'calories': 'Calories', 'protein': 'Protein', 'carbs': 'Carbs', 'fat': 'Fat'};

/// The way into the source card: who the values come from, in one line, and the rest on a tap.
class _DetailsRow extends StatelessWidget {
  const _DetailsRow(this.item, {required this.showName, required this.onTap});
  final FoodItem item;
  final bool showName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final credit = sourceCredit(item.source);
    return Semantics(
      button: true,
      child: InkWell(
        key: const Key('food-source'), onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              // At very large text the decorative tile gives its width to the words.
              if (MediaQuery.textScalerOf(context).scale(10) <= 15) ...[const IconTile(Icons.description_outlined, circle: true, size: 44), const SizedBox(width: 14)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('Food details', style: context.sansStyle(16, weight: FontWeight.w600)),
                  // The provider's own title, when the page is headed by the everyday name.
                  if (showName) Text(item.name, style: context.caption),
                  Text([if (credit != null) 'Source: $credit' else 'Your own food', if (item.barcode != null) 'Barcode ${item.barcode}'].join(' · '), style: context.caption),
                ]),
              ),
              Icon(Icons.chevron_right, size: 22, color: context.c.secondary),
            ]),
          ),
        ),
      ),
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
    final name = _name.text.trim(), amount = parseNonNegative(_amount.text);
    if (!RegExp(r'^[A-Za-z][A-Za-z \-]{0,23}$').hasMatch(name)) return setState(() => _error = 'Name one portion in a word or two, such as "slice" or "small bowl".');
    if (FoodScaling.units(widget.item).any((u) => u.label.toLowerCase() == '1 ${name.toLowerCase()}')) return setState(() => _error = 'This food already has a portion called "$name".');
    if (!((amount ?? 0) > 0) || amount! > 100000) return setState(() => _error = 'Enter how much one $name is, as a number above zero.');
    Navigator.pop(context, (name, amount));
  }

  @override
  Widget build(BuildContext context) {
    final measure = FoodScaling.portionMeasure(widget.item);
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
      title: const Text('Add your own portion'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('For ${widget.item.name} only. Its nutrition values do not change, and nothing is logged.', style: context.caption),
          const SizedBox(height: 14),
          TextField(key: const Key('portion-name'), controller: _name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'One portion is called', hintText: 'slice')),
          const SizedBox(height: 12),
          TextField(
            key: const Key('portion-amount'), controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), onSubmitted: (_) => _add(),
            decoration: InputDecoration(labelText: 'How much is one?', suffixText: measure),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('portion-add'), onPressed: _add, child: const Text('Add portion')),
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
    final credit = sourceCredit(item.source);
    final about = [if (item.brand != null) item.brand!, if (item.description != null) item.description!].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (item.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
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
        Text('Nutrition ${FoodScaling.basisText(item)}', style: context.label),
        const SizedBox(height: 4),
        Semantics(
          label: [for (final k in FoodItem.nutrientKeys) '${_nutrientLabels[k]} ${item.nutrient(k) == null ? 'unknown' : '${formatNumber2(item.nutrient(k)!)} ${k == 'calories' ? 'kilocalories' : 'grams'}'}'].join(', '),
          child: ExcludeSemantics(
            child: Wrap(spacing: 14, runSpacing: 4, children: [
              for (final k in FoodItem.nutrientKeys)
                Text('${_nutrientLabels[k]} ${item.nutrient(k) == null ? '—' : '${formatNumber2(item.nutrient(k)!)}${k == 'calories' ? ' kcal' : ' g'}'}', style: context.sansStyle(15)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Text(
            [
              if (credit != null) 'Source: $credit' else 'Your own food',
              if (item.barcode != null) 'Barcode ${item.barcode}',
              if (item.imageUrl != null && item.imageAttribution != null) item.imageAttribution!,
            ].join(' · '),
            style: context.caption),
      ]);
  }
}
