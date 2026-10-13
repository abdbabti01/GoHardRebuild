import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
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
  late final FoodItem? _item = widget.draft.item;
  late String? _unitId = _item == null ? null : FoodScaling.unit(_item, widget.draft.unitId).id;

  /// Nutrients whose value is the user's own rather than the source's for this amount. Changing the amount
  /// rescales every other value and leaves these alone.
  late final Set<String> _corrected = {
    if (_item != null && (widget.draft.quantity ?? 0) > 0)
      for (final e in FoodScaling.scale(_item, widget.draft.quantity!, FoodScaling.unit(_item, widget.draft.unitId)).entries)
        if (widget.draft.macros[e.key] != e.value) e.key,
  };
  String? _error;
  bool _busy = false;

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

  double? get _amountEaten => parseNonNegative(_quantity.text);

  /// The source's values for the amount now entered, written into every field the user has not corrected.
  void _rescale() {
    final item = _item, quantity = _amountEaten;
    if (item == null || quantity == null) return;
    final scaled = FoodScaling.scale(item, quantity, FoodScaling.unit(item, _unitId));
    for (final e in scaled.entries) {
      if (!_corrected.contains(e.key)) _macros[e.key]!.text = _text(e.value);
    }
  }

  FoodDraft _draft() {
    final item = _item;
    final quantity = _amountEaten;
    if (item != null && !((quantity ?? 0) > 0)) throw const InvalidFood('Enter how much you had, as a number above zero.');
    return FoodDraft(
        id: widget.draft.id, dayKey: _dayKey, meal: _meal, name: _name.text,
        amount: item == null ? _amount.text : FoodScaling.amountText(quantity!, FoodScaling.unit(item, _unitId)),
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

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final item = _item;
    final favourite = item != null && (ref.watch(savedFoodsProvider).value ?? const <Stored<SavedFood>>[]).any((r) => !r.value.isDeleted && r.value.isFavourite && r.value.item.key == item.key);
    // Side by side, or one under the other when the text is large or the phone narrow.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 350;
    Widget macro(String key, String label, String suffix) => TextField(
          key: Key('food-$key'), controller: _macros[key], keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() => _corrected.add(key)),
          decoration: InputDecoration(labelText: label, suffixText: suffix, hintText: 'Unknown', helperText: item != null && _corrected.contains(key) ? 'Your value' : null),
        );
    Widget pair(Widget a, Widget b) => stacked ? Column(children: [a, const SizedBox(height: 12), b]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

    return AppPage(
      title: editing ? 'Edit food' : 'Log food',
      actions: [
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
        InkWell(
          onTap: _pickDate,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: StatusLine(Icons.event, 'For ${longDate(_dayKey)}. Tap to change the date.')),
        ),
        const SizedBox(height: 8),
        if (item != null) ...[FoodSourceCard(item), const SizedBox(height: 16)],
        TextField(key: const Key('food-name'), controller: _name, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: item == null ? 'What did you eat?' : 'Name in your journal')),
        const SizedBox(height: 12),
        if (item == null)
          TextField(key: const Key('food-amount'), controller: _amount, textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'How much?', helperText: 'In your own words, for example "200 g" or "2 slices"'))
        else
          pair(
            TextField(
              key: const Key('food-quantity'), controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next,
              onChanged: (_) => setState(_rescale), decoration: const InputDecoration(labelText: 'How much?'),
            ),
            DropdownButtonFormField<String>(
              key: const Key('food-unit'), initialValue: _unitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Unit'), dropdownColor: context.c.surface,
              items: [for (final u in FoodScaling.units(item)) DropdownMenuItem(value: u.id, child: Text(u.label, overflow: TextOverflow.ellipsis))],
              onChanged: (u) => setState(() {
                _unitId = u ?? _unitId;
                _rescale();
              }),
            ),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('food-meal'), initialValue: _meal, isExpanded: true, decoration: const InputDecoration(labelText: 'Meal'),
          dropdownColor: context.c.surface,
          items: [for (final m in meals) DropdownMenuItem(value: m, child: Text(m))],
          onChanged: (m) => setState(() => _meal = m ?? _meal),
        ),
        const SizedBox(height: 22),
        // The amount is spelled out with its unit: "1 g" and "1 cup" look the same in the number field alone.
        SectionLabel(
            item != null && (_amountEaten ?? 0) > 0 ? 'Nutrition for ${FoodScaling.amountText(_amountEaten!, FoodScaling.unit(item, _unitId))} · optional' : 'Nutrition for this amount · optional',
            key: const Key('food-amount-echo')),
        const SizedBox(height: 6),
        Text(
            item == null
                ? 'Leave a field blank if you do not know it. Blank stays unknown; it is never counted as zero.'
                : 'Worked out from the food above for the amount you entered. Change a value to correct it; a blank stays unknown and is never counted as zero.',
            style: context.caption),
        const SizedBox(height: 12),
        pair(macro('calories', 'Calories', 'kcal'), macro('protein', 'Protein', 'g')),
        const SizedBox(height: 12),
        pair(macro('carbs', 'Carbs', 'g'), macro('fat', 'Fat', 'g')),
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
        const SizedBox(height: 14),
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

/// What the food is and where its values come from, shown before anything is logged.
class FoodSourceCard extends StatelessWidget {
  const FoodSourceCard(this.item, {super.key});
  final FoodItem item;

  static const _labels = {'calories': 'Calories', 'protein': 'Protein', 'carbs': 'Carbs', 'fat': 'Fat'};

  @override
  Widget build(BuildContext context) {
    final credit = sourceCredit(item.source);
    final missing = [for (final k in FoodItem.nutrientKeys) if (item.nutrient(k) == null) _labels[k]!.toLowerCase()];
    final about = [if (item.brand != null) item.brand!, if (item.description != null) item.description!].join(' · ');
    return Panel(
      key: const Key('food-source'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          label: [for (final k in FoodItem.nutrientKeys) '${_labels[k]} ${item.nutrient(k) == null ? 'unknown' : '${formatNumber2(item.nutrient(k)!)} ${k == 'calories' ? 'kilocalories' : 'grams'}'}'].join(', '),
          child: ExcludeSemantics(
            child: Wrap(spacing: 14, runSpacing: 4, children: [
              for (final k in FoodItem.nutrientKeys)
                Text('${_labels[k]} ${item.nutrient(k) == null ? '—' : '${formatNumber2(item.nutrient(k)!)}${k == 'calories' ? ' kcal' : ' g'}'}', style: context.sansStyle(15)),
            ]),
          ),
        ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          StatusLine(Icons.help_outline, 'This source gives no value for ${missing.join(', ')}. ${missing.length == 1 ? 'It stays' : 'They stay'} unknown unless you enter ${missing.length == 1 ? 'it' : 'them'}.'),
        ],
        const SizedBox(height: 10),
        Text(
            [
              if (credit != null) 'Source: $credit' else 'Your own food',
              if (item.barcode != null) 'Barcode ${item.barcode}',
              if (item.imageUrl != null && item.imageAttribution != null) item.imageAttribution!,
            ].join(' · '),
            style: context.caption),
      ]),
    );
  }
}
