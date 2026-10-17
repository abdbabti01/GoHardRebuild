import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart' show LocalSaveFailure, SyncEngine;
import '../me/account_repository.dart';
import 'nutrition_surface.dart' show formatKcal;
import 'water.dart';

// ---------------------------------------------------------------------------- daily goals

/// The one goals form, used by Me › Nutrition goals and by the sheet Today and Eat open. All of them read and write
/// the profile's goals through [ProfileRepository.setGoals], with the same validation; fields start from the saved
/// goals or empty, and the app never suggests or pre-fills a number. The water goal is shown (and sent) only while
/// water tracking is on, so a form without it never clears it.
class GoalsEditor extends ConsumerStatefulWidget {
  const GoalsEditor({super.key, required this.profile, required this.onSaved});
  final Profile profile;
  final VoidCallback onSaved;
  @override
  ConsumerState<GoalsEditor> createState() => _GoalsEditorState();
}

class _GoalsEditorState extends ConsumerState<GoalsEditor> {
  late final _calories = TextEditingController(text: widget.profile.calorieGoal?.toString() ?? '');
  late final _protein = TextEditingController(text: widget.profile.proteinGoal?.toString() ?? '');
  late final VolumeUnit _unit = ref.read(volumeUnitProvider);
  late final _water = TextEditingController(text: switch (widget.profile.waterGoalMl) { final ml? => _unit.amount(_unit == VolumeUnit.ml ? ml.toDouble() : ml / VolumeUnit.mlPerFlOz), null => '' });
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    _water.dispose();
    super.dispose();
  }

  /// Blank is "no goal". Anything else has to be a whole number.
  static int? _whole(String raw, String what) {
    if (raw.trim().isEmpty) return null;
    final v = parsePositiveInt(raw.replaceAll(',', ''));
    if (v == null) throw AuthFailure('$what is a whole number, or left blank for no goal.');
    return v;
  }

  int? _waterMl() {
    if (_water.text.trim().isEmpty) return null;
    final v = parseNonNegative(_water.text.replaceAll(RegExp(r'[,\s]'), ''));
    if (v == null || v <= 0) throw const AuthFailure('A water goal is an amount above zero, or left blank for no goal.');
    return _unit.toMl(v).round();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final withWater = ref.read(nutritionDisplayProvider).water;
      // The newest profile on this phone, so a goal change never carries an older name or unit with it.
      final current = ref.read(profileProvider).value ?? widget.profile;
      await ref.read(profileRepositoryProvider).setGoals(current,
          calorieGoal: _whole(_calories.text, 'A calorie goal'), proteinGoal: _whole(_protein.text, 'A protein goal'),
          withWater: withWater, waterGoalMl: withWater ? _waterMl() : null);
      if (mounted) widget.onSaved();
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } on LocalSaveFailure {
      setState(() => _error = 'Your goals could not be saved on this phone. What you typed is still here.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final water = ref.watch(nutritionDisplayProvider).water;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      TextField(key: const Key('goal-calories'), controller: _calories, keyboardType: TextInputType.number, textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Daily calories', suffixText: 'kcal', hintText: 'No goal', helperText: '500 to 10,000. Leave blank for no calorie goal.')),
      const SizedBox(height: 14),
      TextField(key: const Key('goal-protein'), controller: _protein, keyboardType: TextInputType.number, textInputAction: water ? TextInputAction.next : TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Daily protein', suffixText: 'g', hintText: 'No goal', helperText: '10 to 500. Leave blank for no protein goal.')),
      if (water) ...[
        const SizedBox(height: 14),
        TextField(key: const Key('goal-water'), controller: _water, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Daily water', suffixText: _unit.short, hintText: 'No goal',
                helperText: _unit == VolumeUnit.ml ? '100 to 10,000. Leave blank for no water goal.' : '3.4 to 338 (US fluid ounces). Leave blank for no water goal.')),
      ],
      const SizedBox(height: 14),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      PrimaryButton('Save goals', key: const Key('goal-save'), busy: _busy, onPressed: _save),
      const SizedBox(height: 10),
      Text('GoHard does not suggest a goal. If you are unsure what suits you, a dietitian or doctor can help.', style: context.caption),
    ]);
  }
}

/// Today's and Eat's way to the same goals: a compact sheet over the page. They repeat every day.
Future<void> showGoalsSheet(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(profileProvider).value;
  if (profile == null) return;
  await showGoSheet<void>(appContext(context), title: 'Daily goals', builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('These repeat every day until you change them. Leave any of them blank for no goal.', style: sheet.sansStyle(15, color: sheet.c.secondary)),
        const SizedBox(height: 16),
        GoalsEditor(profile: profile, onSaved: () => Navigator.pop(sheet)),
      ]));
}

// ---------------------------------------------------------------------------- water

/// The day's water in one quiet line under the nutrition figures: a droplet, what was logged, the goal's bar only when
/// a goal is set (full at the goal, the words keep the real amount), and an add button. Opens [showWaterSheet].
class WaterRow extends ConsumerWidget {
  const WaterRow({super.key, required this.day});
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(volumeUnitProvider);
    final rows = ref.watch(waterProvider(day));
    // Until the day's entries are read nothing is claimed: an amount not yet known is not zero.
    final total = rows.hasValue ? waterTotal([for (final r in rows.value!) r.value]) : null;
    final goal = ref.watch(profileProvider).value?.waterGoalMl;
    final c = context.c;
    final said = total == null ? 'Water, loading' : 'Water ${unit.format(total)}${goal == null ? '' : ' of ${unit.format(goal.toDouble())}'}';
    return Semantics(
      container: true,
      child: Row(children: [
        Expanded(
          child: InkWell(
            key: const Key('water-row'),
            borderRadius: BorderRadius.circular(Radii.field),
            onTap: () => showWaterSheet(context, ref, day),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Targets.minimum),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Semantics(
                  button: true, label: said, hint: 'Opens water for this day', excludeSemantics: true,
                  child: Row(children: [
                    Icon(Icons.water_drop_outlined, size: 22, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
                          Text('Water', style: context.sansStyle(15, weight: FontWeight.w600)),
                          if (total != null) Text(unit.format(total), key: const Key('water-total'), style: context.numStyle(15)),
                          if (goal != null) Text('of ${unit.format(goal.toDouble())}', style: context.sansStyle(14, color: c.secondary)),
                        ]),
                        if (goal != null && total != null) Padding(padding: const EdgeInsets.only(top: 5), child: ProgressRail(total / goal, label: 'Water goal', height: 5)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        IconButton(key: const Key('water-quick-add'), tooltip: 'Add water', icon: const Icon(Icons.add_circle_outline), color: c.accent, onPressed: () => showWaterSheet(context, ref, day)),
      ]),
    );
  }
}

/// Logging water for [day] (pinned when the sheet opens): three quick amounts in the chosen unit, a custom amount,
/// and the day's entries, each of which can be corrected or removed. Adding offers Undo.
Future<void> showWaterSheet(BuildContext context, WidgetRef ref, String day) =>
    showGoSheet<void>(appContext(context), title: 'Water', builder: (sheet) => _WaterSheet(day: day));

class _WaterSheet extends ConsumerStatefulWidget {
  const _WaterSheet({required this.day});
  final String day;
  @override
  ConsumerState<_WaterSheet> createState() => _WaterSheetState();
}

class _WaterSheetState extends ConsumerState<_WaterSheet> {
  final _custom = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _add(double ml) async {
    final repo = ref.read(waterRepositoryProvider);
    final unit = ref.read(volumeUnitProvider);
    final messenger = ScaffoldMessenger.of(context);
    final id = SyncEngine.newId();
    try {
      await repo.add(widget.day, ml, id: id);
      setState(() => _error = null);
      _custom.clear();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Added ${unit.format(roundMl(ml))} of water.'),
          action: SnackBarAction(label: 'Undo', onPressed: () {
            final entry = ref.read(waterProvider(widget.day)).value?.where((r) => r.value.id == id).firstOrNull;
            if (entry != null) repo.remove(entry.value).ignore();
          }),
        ));
    } on InvalidWater catch (e) {
      setState(() => _error = e.message);
    } on LocalSaveFailure {
      setState(() => _error = 'That could not be saved on this phone. Nothing was added.');
    }
  }

  void _addCustom() {
    final v = parseNonNegative(_custom.text.replaceAll(RegExp(r'[,\s]'), ''));
    if (v == null || v <= 0) return setState(() => _error = 'Enter an amount above zero.');
    _add(ref.read(volumeUnitProvider).toMl(v));
  }

  Future<void> _edit(WaterEntry e) async {
    final unit = ref.read(volumeUnitProvider);
    final ml = await showDialog<double>(context: context, builder: (dialog) => _AmountDialog(entry: e, unit: unit));
    if (ml == null) return;
    try {
      await ref.read(waterRepositoryProvider).update(e, ml);
      setState(() => _error = null);
    } on InvalidWater catch (x) {
      setState(() => _error = x.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(volumeUnitProvider);
    final entries = [for (final r in ref.watch(waterProvider(widget.day)).value ?? const <Stored<WaterEntry>>[]) if (!r.value.isDeleted) r];
    final total = waterTotal([for (final r in entries) r.value]);
    final goal = ref.watch(profileProvider).value?.waterGoalMl;
    final today = ref.watch(todayKeyProvider);
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(widget.day == today ? 'Today' : longDate(widget.day), style: context.caption),
      Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
        Text(unit.format(total), key: const Key('water-sheet-total'), style: context.pageTitleStyle(34)),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(goal == null ? 'No daily goal' : 'of ${unit.format(goal.toDouble())}', style: context.sansStyle(15, color: c.secondary)),
        ),
      ]),
      if (goal != null) Padding(padding: const EdgeInsets.only(top: 8), child: ProgressRail(total / goal, label: 'Water goal', height: 6)),
      const SizedBox(height: 18),
      Text('Add', style: context.label),
      const SizedBox(height: 8),
      Row(children: [
        for (final (i, q) in unit.quick.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: SecondaryButton('+${unit.amount(q)} ${unit.short}', key: Key('water-add-${q.round()}'), onPressed: () => _add(unit.toMl(q)))),
        ],
      ]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(key: const Key('water-custom'), controller: _custom, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done, onSubmitted: (_) => _addCustom(),
              decoration: InputDecoration(labelText: 'Another amount', suffixText: unit.short)),
        ),
        const SizedBox(width: 10),
        PrimaryButton('Add', key: const Key('water-add-custom'), expand: false, onPressed: _addCustom),
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      const SizedBox(height: 18),
      Text(entries.isEmpty ? 'Nothing logged on this day' : 'Logged on this day', style: context.label),
      if (entries.isNotEmpty) ...[
        const SizedBox(height: 8),
        GroupCard(children: [
          for (final r in entries.reversed)
            GroupRow(
              key: Key('water-entry-${r.value.id}'), icon: Icons.water_drop_outlined, title: unit.format(r.value.volumeMl),
              subtitle: r.isPending ? 'Saved on this phone · tap to correct' : 'Tap to correct',
              onTap: () => _edit(r.value),
              trailing: IconButton(key: Key('water-delete-${r.value.id}'), tooltip: 'Remove ${unit.format(r.value.volumeMl)}', icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(waterRepositoryProvider).remove(r.value).ignore()),
            ),
        ]),
      ],
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: QuietLink(goal == null ? 'Set a water goal' : 'Edit water goal', key: const Key('water-goal'), onPressed: () {
          Navigator.pop(context);
          showGoalsSheet(context, ref);
        }),
      ),
      Text('Only water you log here is counted, not drinks or food.', style: context.caption),
    ]);
  }
}

/// "Correct this amount": the entry's amount in the chosen unit, editable. Returns the new millilitres, or null.
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.entry, required this.unit});
  final WaterEntry entry;
  final VolumeUnit unit;
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _field = TextEditingController(
      text: widget.unit.amount(widget.unit == VolumeUnit.ml ? widget.entry.volumeMl : widget.entry.volumeMl / VolumeUnit.mlPerFlOz));

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Correct this amount'),
        content: TextField(key: const Key('water-edit-field'), controller: _field, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: widget.unit.short)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(key: const Key('water-edit-save'), onPressed: () {
            final v = parseNonNegative(_field.text.replaceAll(RegExp(r'[,\s]'), ''));
            if (v != null && v > 0) Navigator.pop(context, widget.unit.toMl(v));
          }, child: const Text('Save')),
        ],
      );
}

// ---------------------------------------------------------------------------- customize

/// What this account sees in its nutrition. Calories and protein always stay; hiding the others changes only what is
/// shown: entries, goals and logged values are kept and come back when shown again.
Future<void> showTrackingSheet(BuildContext context) => showGoSheet<void>(appContext(context), title: 'Customize tracking', builder: (sheet) => const _TrackingSheet());

class _TrackingSheet extends ConsumerWidget {
  const _TrackingSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(ownerProvider);
    final d = ref.watch(nutritionDisplayProvider);
    void set(NutritionDisplay next) {
      if (owner != null) ref.read(trackingPrefsProvider.notifier).setDisplay(owner, next);
    }

    Widget toggle(String key, String title, String subtitle, bool value, NutritionDisplay Function(bool) next) => SwitchListTile(
        key: Key(key), contentPadding: EdgeInsets.zero, title: Text(title, style: context.sansStyle(16, weight: FontWeight.w600)),
        subtitle: Text(subtitle, style: context.caption), value: value, onChanged: (v) => set(next(v)));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Calories and protein are always shown. Hiding something changes only what you see: nothing you logged or set is removed.',
          style: context.sansStyle(15, color: context.c.secondary)),
      const SizedBox(height: 8),
      if (ref.watch(waterSupportedProvider))
        toggle('track-water', 'Water', 'A water line on Today and Eat, with an optional goal', d.water, (v) => d.copy(water: v))
      else
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: StatusLine(Icons.info_outline, "Water tracking needs a newer version of your account's server. Nothing else changes.")),
      toggle('track-carbs', 'Carbs', 'The carbohydrate total in Eat', d.carbs, (v) => d.copy(carbs: v)),
      toggle('track-fat', 'Fat', 'The fat total in Eat', d.fat, (v) => d.copy(fat: v)),
    ]);
  }
}

/// The two quiet ways from a nutrition summary to its settings: the daily goals ("Set daily goals" while none is set,
/// "Edit goals" once one is) and Customize tracking.
class NutritionTools extends ConsumerWidget {
  const NutritionTools({super.key, this.keyPrefix = 'nutrition'});

  /// Distinguishes Today's from Eat's when both are built (the tabs stay alive).
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).value;
    final hasGoal = p != null && (p.calorieGoal != null || p.proteinGoal != null || p.waterGoalMl != null);
    // One line: the goals link, and Customize tracking as a quiet labelled icon at the end.
    return Row(children: [
      // The link takes all the room the icon does not, so large text wraps by words, never by letters.
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: QuietLink(hasGoal ? 'Edit goals' : 'Set daily goals', key: Key('$keyPrefix-goals'), said: hasGoal ? 'Edit daily goals' : 'Set daily goals',
              onPressed: p == null ? null : () => showGoalsSheet(context, ref)),
        ),
      ),
      IconButton(key: Key('$keyPrefix-customize'), tooltip: 'Customize tracking', icon: const Icon(Icons.tune), onPressed: () => showTrackingSheet(context)),
    ]);
  }
}

/// "2,200 kcal · 140 g protein · 2 L water" for the goals that were set; null when none was.
String? goalsSummary(Profile? p, VolumeUnit unit, {required bool water}) {
  if (p == null) return null;
  final parts = [
    if (p.calorieGoal != null) '${formatKcal(p.calorieGoal!)} kcal',
    if (p.proteinGoal != null) '${p.proteinGoal} g protein',
    if (water && p.waterGoalMl != null) '${unit.format(p.waterGoalMl!.toDouble())} water',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
