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
import 'food_repository.dart';

/// Opens the food form for a new entry on `dayKey`, or to edit `entry`. Used by both Today and Eat, and
/// always returns to where it was opened from.
Future<void> openFoodForm(BuildContext context, {required String dayKey, FoodEntry? entry, String? meal}) =>
    push(context, FoodFormScreen(draft: entry == null ? FoodDraft(dayKey: dayKey, meal: meal ?? 'Breakfast') : FoodDraft.edit(entry), existing: entry));

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
  late final _macros = {
    'calories': TextEditingController(text: _text(widget.draft.calories)),
    'protein': TextEditingController(text: _text(widget.draft.protein)),
    'carbs': TextEditingController(text: _text(widget.draft.carbs)),
    'fat': TextEditingController(text: _text(widget.draft.fat)),
  };
  late String _meal = widget.draft.meal, _dayKey = widget.draft.dayKey;
  String? _error;
  bool _busy = false;

  static String _text(double? v) => v == null ? '' : formatNumber(v);

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
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

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = FoodDraft(id: widget.draft.id, dayKey: _dayKey, meal: _meal, name: _name.text, amount: _amount.text,
          calories: _macro('calories'), protein: _macro('protein'), carbs: _macro('carbs'), fat: _macro('fat'));
      await ref.read(foodRepositoryProvider).save(draft);
      if (mounted) Navigator.pop(context);
    } on InvalidFood catch (e) {
      setState(() => _error = e.message);
    } on LocalSaveFailure {
      // Everything typed stays in the fields; nothing claims to be saved.
      setState(() => _error = 'This could not be saved on your phone. Your entry is still here. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final e = widget.existing!;
    if (!await confirm(context, title: 'Remove ${e.name}?', body: 'This removes only "${e.name}" (${e.amountDescription}) from ${e.meal} on ${longDate(e.dayKey)}. Your other food stays.', action: 'Remove this food')) return;
    await ref.read(foodRepositoryProvider).remove(e);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: parseDayKey(_dayKey), firstDate: DateTime.utc(2020), lastDate: parseDayKey(ref.read(todayKeyProvider)).add(const Duration(days: 1)));
    if (picked != null) setState(() => _dayKey = dayKeyOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    Widget macro(String key, String label, String suffix) => Expanded(
          child: TextField(
            key: Key('food-$key'), controller: _macros[key], keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, suffixText: suffix, hintText: 'Unknown'),
          ),
        );
    return EveningPage(
      title: editing ? 'Edit food' : 'Log food',
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        PrimaryButton(editing ? 'Save changes' : 'Save food', key: const Key('food-save'), onPressed: _save, busy: _busy),
        TextButton(key: const Key('food-cancel'), onPressed: () => Navigator.pop(context), child: Text(editing ? 'Cancel and keep the recorded version' : 'Cancel')),
      ]),
      children: [
        InkWell(
          onTap: _pickDate,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: StatusLine(Icons.event, 'For ${longDate(_dayKey)}. Tap to change the date.')),
        ),
        const SizedBox(height: 8),
        TextField(key: const Key('food-name'), controller: _name, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'What did you eat?')),
        const SizedBox(height: 12),
        TextField(key: const Key('food-amount'), controller: _amount, textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'How much?', helperText: 'In your own words, for example "200 g" or "2 slices"')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('food-meal'), initialValue: _meal, decoration: const InputDecoration(labelText: 'Meal'),
          dropdownColor: context.ec.input,
          items: [for (final m in meals) DropdownMenuItem(value: m, child: Text(m))],
          onChanged: (m) => setState(() => _meal = m ?? _meal),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Nutrition for this amount · optional'),
        const SizedBox(height: 6),
        Text('Leave a field blank if you do not know it. Blank stays unknown; it is never counted as zero.', style: context.caption),
        const SizedBox(height: 12),
        Row(children: [macro('calories', 'Calories', 'kcal'), const SizedBox(width: 10), macro('protein', 'Protein', 'g')]),
        const SizedBox(height: 12),
        Row(children: [macro('carbs', 'Carbs', 'g'), const SizedBox(width: 10), macro('fat', 'Fat', 'g')]),
        if (editing) ...[
          const SizedBox(height: 22),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('food-remove'), onPressed: _remove, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Remove this food'))),
        ],
      ],
    );
  }
}
