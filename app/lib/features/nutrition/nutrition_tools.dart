import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart' show LocalSaveFailure, SyncEngine;
import '../me/account_repository.dart';
import 'nutrition_surface.dart' show formatKcal;
import 'water.dart';

// ---------------------------------------------------------------------------- daily goals

/// The one goals form, used by Me › Nutrition goals and by the sheet Eat opens. All of them read and write the
/// profile's goals through [ProfileRepository.setGoals], with the same validation; fields start from the saved goals
/// or empty. No calorie or protein goal is ever suggested. For water, while no water goal is saved, a general starting
/// point (2,000 mL) is offered: "Use it" only fills the field, nothing is saved until Save goals, and leaving the
/// field blank keeps no goal. The water goal is shown (and sent) only while water tracking is on, so a form without it
/// never clears it.
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

  /// "Use it" fills the field with the suggestion; until the field is typed in or saved, nothing is decided.
  void _useSuggestion() =>
      setState(() => _water.text = _unit == VolumeUnit.ml ? '${VolumeUnit.suggestedGoalMl}' : _unit.number(VolumeUnit.suggestedGoalMl.toDouble()));

  void _aboutSuggestion() => showDialog<void>(context: context, builder: (dialog) => AlertDialog(
        key: const Key('water-suggestion-about'),
        title: Text(dialog.l10n.waterSuggestionAboutTitle),
        content: Text(dialog.l10n.waterSuggestionAboutBody(_unit.format(VolumeUnit.suggestedGoalMl.toDouble()))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: Text(dialog.l10n.actionOk))],
      ));

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    _water.dispose();
    super.dispose();
  }

  /// Blank is "no goal". Anything else has to be a whole number ("2,200", "2 200" and "٢٢٠٠" are 2200).
  static int? _whole(String raw, String error) {
    if (raw.trim().isEmpty) return null;
    final v = parsePositiveInt(raw, grouping: true);
    if (v == null) throw AuthFailure(error);
    return v;
  }

  int? _waterMl() {
    if (_water.text.trim().isEmpty) return null;
    final v = _unit.parseAmount(_water.text);
    if (v == null || v <= 0) throw AuthFailure(context.l10n.eatGoalWaterInvalid);
    return _unit.toMl(v).round();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final withWater = ref.read(nutritionDisplayProvider).water;
      // The newest profile on this phone, so a goal change never carries an older name or unit with it.
      final current = ref.read(profileProvider).value ?? widget.profile;
      await ref.read(profileRepositoryProvider).setGoals(current,
          calorieGoal: _whole(_calories.text, context.l10n.eatGoalCaloriesWhole), proteinGoal: _whole(_protein.text, context.l10n.eatGoalProteinWhole),
          withWater: withWater, waterGoalMl: withWater ? _waterMl() : null);
      if (mounted) widget.onSaved();
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } on LocalSaveFailure {
      setState(() => _error = context.l10n.eatGoalsSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final water = ref.watch(nutritionDisplayProvider).water;
    final l = context.l10n;
    final suggested = _unit.format(VolumeUnit.suggestedGoalMl.toDouble());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      TextField(key: const Key('goal-calories'), controller: _calories, keyboardType: TextInputType.number, textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l.eatGoalCaloriesLabel, suffixText: l.eatUnitKcal, hintText: l.eatGoalNone, helperText: l.eatGoalCaloriesHelper)),
      const SizedBox(height: 14),
      TextField(key: const Key('goal-protein'), controller: _protein, keyboardType: TextInputType.number, textInputAction: water ? TextInputAction.next : TextInputAction.done,
          decoration: InputDecoration(labelText: l.eatGoalProteinLabel, suffixText: l.eatUnitGram, hintText: l.eatGoalNone, helperText: l.eatGoalProteinHelper)),
      if (water) ...[
        const SizedBox(height: 14),
        TextField(key: const Key('goal-water'), controller: _water, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.eatGoalWaterLabel, suffixText: _unit.short, hintText: l.eatGoalNone,
                helperText: _unit == VolumeUnit.ml ? l.eatGoalWaterHelperMl : l.eatGoalWaterHelperFlOz)),
        // Offered only while the account has no water goal; an existing goal is never replaced by it.
        if (widget.profile.waterGoalMl == null)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _water,
            builder: (context, value, _) => value.text.trim().isNotEmpty
                ? const SizedBox.shrink()
                : Padding(
                    key: const Key('water-suggestion'),
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(l.waterSuggestedGoal(suggested), style: context.sansStyle(15, weight: FontWeight.w600)),
                          ),
                          Text(l.waterSuggestedGoalNote, style: context.caption),
                          // Pulled back to the text's leading edge (left in English, right in Arabic).
                          Transform.translate(
                            offset: Offset(context.isRtl ? 8 : -8, 0),
                            child: TextButton(key: const Key('water-suggestion-use'), onPressed: _useSuggestion, child: Text(l.waterSuggestionUse(suggested))),
                          ),
                        ]),
                      ),
                      IconButton(key: const Key('water-suggestion-info'), tooltip: l.waterSuggestionAboutTitle, icon: const Icon(Icons.info_outline), onPressed: _aboutSuggestion),
                    ]),
                  ),
          ),
      ],
      const SizedBox(height: 14),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      PrimaryButton(l.eatGoalsSave, key: const Key('goal-save'), busy: _busy, onPressed: _save),
      const SizedBox(height: 10),
      Text(l.eatGoalsNoSuggestion, style: context.caption),
    ]);
  }
}

/// Eat's way to the goals: a compact sheet over the page. They repeat every day. (Today shows progress only.)
Future<void> showGoalsSheet(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(profileProvider).value;
  if (profile == null) return;
  await showGoSheet<void>(appContext(context), title: context.l10n.eatGoalsSheetTitle, builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(sheet.l10n.eatGoalsSheetIntro, style: sheet.sansStyle(15, color: sheet.c.secondary)),
        const SizedBox(height: 16),
        GoalsEditor(profile: profile, onSaved: () => Navigator.pop(sheet)),
      ]));
}

// ---------------------------------------------------------------------------- water

/// The day's water under the nutrition figures, drawn like their goal bars: a droplet, "750 / 2,000 mL" and a bar with
/// the real share when a goal is saved (the bar full at the goal, the words and the share keep the real amount above
/// it); without a goal just the amount, with no bar or percentage. The row opens the day's water details
/// ([showWaterSheet]: its entries, corrections, removals). Under it, on today: one labelled tap for an ordinary drink
/// ([VolumeUnit.everyday], logged at once, with Undo) and Other amount; on an earlier day, Other amount for that day.
class WaterRow extends ConsumerWidget {
  const WaterRow({super.key, required this.day});
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(volumeUnitProvider);
    final today = ref.watch(todayKeyProvider) == day;
    final last = ref.watch(lastWaterProvider.select((w) => w != null && w.day == day ? w : null));
    final rows = ref.watch(waterProvider(day));
    // Until the day's entries are read nothing is claimed: an amount not yet known is not zero.
    final total = rows.hasValue ? waterTotal([for (final r in rows.value!) r.value]) : null;
    // Only today is set against the goal: earlier days' goals were not kept, so today's is not used to judge them.
    final goal = today ? ref.watch(profileProvider).value?.waterGoalMl : null;
    // An earlier day with nothing logged says so, rather than "0 mL" as if a zero had been recorded.
    final none = !today && total == 0;
    final c = context.c;
    final l = context.l10n;
    final said = total == null
        ? l.waterSaidLoading
        : none
            ? l.waterSaidNone
            : goal == null
                ? l.waterSaid(unit.format(total))
                : l.waterSaidWithGoal(unit.format(total), unit.format(goal.toDouble()), (total / goal * 100).round());
    final quick = unit.everyday;
    final actions = Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (today)
        FilledButton.tonalIcon(
          key: const Key('water-quick-add'), onPressed: () => addWater(context, ref, day, unit.toMl(quick)),
          style: FilledButton.styleFrom(minimumSize: const Size(0, Targets.minimum), padding: const EdgeInsets.symmetric(horizontal: 14)),
          icon: const Icon(Icons.water_drop_outlined, size: 18),
          label: Text(_plus(unit, quick), semanticsLabel: unit == VolumeUnit.ml ? l.waterAddSaidMl(unit.amount(quick)) : l.waterAddSaidFlOz(unit.amount(quick))),
        ),
      // For 5 s after a drink is added, Undo takes Other amount's place: the line keeps its height and nothing moves.
      if (last != null)
        TextButton.icon(key: const Key('water-undo'), onPressed: () => ref.read(lastWaterProvider.notifier).undo(),
            icon: const Icon(Icons.undo, size: 18), label: Text(l.waterUndo(unit.format(last.ml)), semanticsLabel: l.waterUndoSaid(unit.format(last.ml))))
      else
        TextButton(key: const Key('water-other'), onPressed: () => showOtherWaterSheet(context, ref, day), child: Text(l.waterOtherAmount)),
    ]);
    return Semantics(
      container: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        InkWell(
            key: const Key('water-row'),
            borderRadius: BorderRadius.circular(Radii.field),
            onTap: () => showWaterSheet(context, ref, day),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Targets.minimum),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Semantics(
                  button: true, label: said, hint: l.waterRowHint, excludeSemantics: true,
                  child: Row(children: [
                    Icon(Icons.water_drop_outlined, size: 22, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
                          Text(l.waterTitle, style: context.sansStyle(15, weight: FontWeight.w600)),
                          if (total != null) Text(none ? l.waterNoneLogged : goal == null ? unit.format(total) : unit.progress(total, goal.toDouble()), key: const Key('water-total'), style: context.numStyle(15)),
                        ]),
                        if (goal != null && total != null) Padding(padding: const EdgeInsets.only(top: 6), child: WaterGoalBar(total: total, goal: goal.toDouble())),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: c.secondary),
                  ]),
                ),
              ),
            ),
        ),
        Padding(padding: const EdgeInsetsDirectional.only(start: 28), child: actions),
      ]),
    );
  }
}

/// "+250 mL" on a quick-add button: the sign stays with the number in Arabic too.
String _plus(VolumeUnit unit, double amount) => withUnit(ltr('+${unit.amount(amount)}'), unit.short);

String _waterProblem(AppLocalizations l, InvalidWater e) => switch (e.problem) {
      WaterProblem.notAboveZero => l.waterProblemNotAboveZero,
      WaterProblem.overMax => l.waterProblemOverMax,
    };

/// Logs [ml] on [day] at once, as one entry, and offers Undo of exactly that entry for a few seconds (a bar that goes
/// away by itself, one at a time). Undo removes that entry through the outbox (it waits for the add when that has not
/// been sent yet), never subtracts from a total, and does nothing once another account is signed in.
Future<bool> addWater(BuildContext context, WidgetRef ref, String day, double ml) async {
  final repo = ref.read(waterRepositoryProvider);
  final owner = ref.read(ownerProvider);
  final unit = ref.read(volumeUnitProvider);
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(appContext(context));
  final view = View.maybeOf(context);
  final direction = Directionality.of(context);
  final id = SyncEngine.newId();
  final l = context.l10n;
  try {
    await repo.add(day, ml, id: id);
  } on InvalidWater catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_waterProblem(l, e)), duration: const Duration(seconds: 3)));
    return false;
  } on LocalSaveFailure {
    messenger.showSnackBar(SnackBar(content: Text(l.waterSaveFailed), duration: const Duration(seconds: 3)));
    return false;
  }
  // Undo is offered in the water line itself (not a bar over the page), for a few seconds.
  container.read(lastWaterProvider.notifier).set((id: id, day: day, owner: owner, ml: roundMl(ml), repo: repo));
  final today = container.read(todayKeyProvider) == day;
  if (view != null) {
    final amount = unit.format(roundMl(ml));
    SemanticsService.sendAnnouncement(view, today ? l.waterAddedAnnounce(amount) : l.waterAddedOnDayAnnounce(amount, longDate(day)), direction);
  }
  return true;
}

/// The drink just added, for the water line's Undo: exactly that entry, on its day, for its account, for 5 seconds.
typedef LastWater = ({String id, String day, String? owner, double ml, WaterRepository repo});

class LastWaterController extends Notifier<LastWater?> {
  Timer? _timer;
  static const showFor = Duration(seconds: 5);

  @override
  LastWater? build() {
    ref.watch(ownerProvider); // another account: nothing to undo
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void set(LastWater w) {
    _timer?.cancel();
    state = w;
    _timer = Timer(showFor, () {
      if (ref.mounted && state?.id == w.id) state = null;
    });
  }

  /// Removes exactly the entry just added (through the outbox: it waits for the add when that is not sent yet).
  void undo() {
    final w = state;
    if (w == null || ref.read(ownerProvider) != w.owner) return;
    _timer?.cancel();
    state = null;
    final entry = ref.read(waterProvider(w.day)).value?.where((r) => r.value.id == w.id).firstOrNull?.value
        ?? WaterEntry({'id': w.id, 'dayKey': w.day, 'volumeMl': w.ml, 'isDeleted': false});
    if (!entry.isDeleted) w.repo.remove(entry).ignore();
  }
}

final lastWaterProvider = NotifierProvider<LastWaterController, LastWater?>(LastWaterController.new);

/// Other amount: one field in the chosen unit and Add water, for [day].
Future<void> showOtherWaterSheet(BuildContext context, WidgetRef ref, String day) =>
    showGoSheet<void>(appContext(context), title: context.l10n.waterAddTitle, builder: (sheet) => _OtherWater(day: day));

class _OtherWater extends ConsumerStatefulWidget {
  const _OtherWater({required this.day});
  final String day;
  @override
  ConsumerState<_OtherWater> createState() => _OtherWaterState();
}

class _OtherWaterState extends ConsumerState<_OtherWater> {
  final _field = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final unit = ref.read(volumeUnitProvider);
    final v = unit.parseAmount(_field.text);
    if (v == null || v <= 0) return setState(() => _error = context.l10n.waterProblemNotAboveZero);
    try {
      WaterRepository.validate(unit.toMl(v));
    } on InvalidWater catch (e) {
      return setState(() => _error = _waterProblem(context.l10n, e));
    }
    final nav = Navigator.of(context);
    if (await addWater(context, ref, widget.day, unit.toMl(v))) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(volumeUnitProvider);
    final today = ref.watch(todayKeyProvider) == widget.day;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (!today) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(context.l10n.waterForDay(longDate(widget.day)), style: context.caption)),
      TextField(
        key: const Key('water-other-amount'), controller: _field, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done, onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: context.l10n.waterAmountLabel, suffixText: unit.short, errorText: _error),
      ),
      const SizedBox(height: 12),
      PrimaryButton(context.l10n.waterAddTitle, key: const Key('water-other-add'), onPressed: _submit),
    ]);
  }
}

/// The water goal's bar and its real share ("38%", also "120%"), as the calorie and protein goal bars draw theirs.
class WaterGoalBar extends StatelessWidget {
  const WaterGoalBar({super.key, required this.total, required this.goal});
  final double total, goal;

  @override
  Widget build(BuildContext context) => Row(key: const Key('water-goal-bar'), children: [
        Expanded(child: ProgressRail(total / goal, label: context.l10n.waterGoalLabel, height: 6)),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48),
          child: Text(formatPercent((total / goal * 100).round() / 100), textAlign: TextAlign.end, style: context.numStyle(13, color: context.c.secondary, weight: FontWeight.w500)),
        ),
      ]);
}

/// Logging water for [day] (pinned when the sheet opens): three quick amounts in the chosen unit, a custom amount,
/// and the day's entries, each of which can be corrected or removed. Adding offers Undo.
Future<void> showWaterSheet(BuildContext context, WidgetRef ref, String day) =>
    showGoSheet<void>(appContext(context), title: context.l10n.waterTitle, builder: (sheet) => _WaterSheet(day: day));

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
    try {
      WaterRepository.validate(ml);
    } on InvalidWater catch (e) {
      return setState(() => _error = _waterProblem(context.l10n, e));
    }
    if (await addWater(context, ref, widget.day, ml)) {
      setState(() => _error = null);
      _custom.clear();
    }
  }

  void _addCustom() {
    final unit = ref.read(volumeUnitProvider);
    final v = unit.parseAmount(_custom.text);
    if (v == null || v <= 0) return setState(() => _error = context.l10n.waterProblemNotAboveZero);
    _add(unit.toMl(v));
  }

  Future<void> _edit(WaterEntry e) async {
    final unit = ref.read(volumeUnitProvider);
    final ml = await showDialog<double>(context: context, builder: (dialog) => _AmountDialog(entry: e, unit: unit));
    if (ml == null) return;
    try {
      await ref.read(waterRepositoryProvider).update(e, ml);
      setState(() => _error = null);
    } on InvalidWater catch (x) {
      if (mounted) setState(() => _error = _waterProblem(context.l10n, x));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(volumeUnitProvider);
    final rows = ref.watch(waterProvider(widget.day));
    final entries = [for (final r in rows.value ?? const <Stored<WaterEntry>>[]) if (!r.value.isDeleted) r];
    final total = waterTotal([for (final r in entries) r.value]);
    final today = ref.watch(todayKeyProvider);
    // Earlier days' goals were not kept: only today is set against the goal.
    final goal = widget.day == today ? ref.watch(profileProvider).value?.waterGoalMl : null;
    final none = widget.day != today && rows.hasValue && entries.isEmpty;
    final c = context.c;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(widget.day == today ? l.eatTodayCaption : longDate(widget.day), style: context.caption),
      Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
        Text(none ? l.waterNoneLogged : unit.format(total), key: const Key('water-sheet-total'), style: context.pageTitleStyle(none ? 26 : 34)),
        if (goal != null)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('/ ${unit.format(goal.toDouble())}', style: context.sansStyle(15, color: c.secondary))),
      ]),
      if (goal != null) Padding(padding: const EdgeInsets.only(top: 8), child: WaterGoalBar(total: total, goal: goal.toDouble())),
      const SizedBox(height: 18),
      Text(l.waterAdd, style: context.label),
      const SizedBox(height: 8),
      Row(children: [
        for (final (i, q) in unit.quick.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: SecondaryButton(_plus(unit, q), key: Key('water-add-${q.round()}'), onPressed: () => _add(unit.toMl(q)))),
        ],
      ]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(key: const Key('water-custom'), controller: _custom, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done, onSubmitted: (_) => _addCustom(),
              decoration: InputDecoration(labelText: l.waterAnotherAmount, suffixText: unit.short)),
        ),
        const SizedBox(width: 10),
        PrimaryButton(l.waterAdd, key: const Key('water-add-custom'), expand: false, onPressed: _addCustom),
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      const SizedBox(height: 18),
      Text(entries.isEmpty ? l.waterNothingThisDay : l.waterLoggedThisDay, style: context.label),
      if (entries.isNotEmpty) ...[
        const SizedBox(height: 8),
        GroupCard(children: [
          for (final r in entries.reversed)
            GroupRow(
              key: Key('water-entry-${r.value.id}'), icon: Icons.water_drop_outlined, title: unit.format(r.value.volumeMl),
              subtitle: r.isPending ? l.waterEntryPending : l.waterEntryTap,
              onTap: () => _edit(r.value),
              trailing: IconButton(key: Key('water-delete-${r.value.id}'), tooltip: l.waterRemoveTooltip(unit.format(r.value.volumeMl)), icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(waterRepositoryProvider).remove(r.value).ignore()),
            ),
        ]),
      ],
      // Logging, correcting and removing only: the water goal is set with the other goals, in Eat.
      const SizedBox(height: 10),
      Text(l.waterOnlyLoggedNote, style: context.caption),
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
        title: Text(context.l10n.waterCorrectTitle),
        content: TextField(key: const Key('water-edit-field'), controller: _field, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: widget.unit.short)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.actionCancel)),
          TextButton(key: const Key('water-edit-save'), onPressed: () {
            final v = widget.unit.parseAmount(_field.text);
            if (v != null && v > 0) Navigator.pop(context, widget.unit.toMl(v));
          }, child: Text(context.l10n.actionSave)),
        ],
      );
}

// ---------------------------------------------------------------------------- customize

/// What this account sees in its nutrition. Calories and protein always stay; hiding the others changes only what is
/// shown: entries, goals and logged values are kept and come back when shown again.
Future<void> showTrackingSheet(BuildContext context) => showGoSheet<void>(appContext(context), title: context.l10n.eatCustomizeTracking, builder: (sheet) => const _TrackingSheet());

class _TrackingSheet extends ConsumerWidget {
  const _TrackingSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Built from the choice itself, not from what an older server lets be shown, so changing carbs never writes
    // "water off" for the account.
    final raw = ref.watch(rawNutritionDisplayProvider);
    final d = ref.watch(nutritionDisplayProvider);
    void set(NutritionDisplay next) => setNutritionDisplay(ref.read, next).ignore();

    Widget toggle(String key, String title, String subtitle, bool value, NutritionDisplay Function(bool) next) => SwitchListTile(
        key: Key(key), contentPadding: EdgeInsets.zero, title: Text(title, style: context.sansStyle(16, weight: FontWeight.w600)),
        subtitle: Text(subtitle, style: context.caption), value: value, onChanged: (v) => set(next(v)));

    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(l.eatTrackingIntro, style: context.sansStyle(15, color: context.c.secondary)),
      const SizedBox(height: 8),
      if (ref.watch(waterSupportedProvider))
        toggle('track-water', l.waterTitle, l.eatTrackWaterSubtitle, d.water, (v) => raw.copy(water: v))
      else
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: StatusLine(Icons.info_outline, l.eatTrackWaterUnsupported)),
      toggle('track-carbs', l.eatCarbs, l.eatTrackCarbsSubtitle, d.carbs, (v) => raw.copy(carbs: v)),
      toggle('track-fat', l.eatFat, l.eatTrackFatSubtitle, d.fat, (v) => raw.copy(fat: v)),
      if (ref.watch(displaySyncProvider)) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.eatTrackSynced, style: context.caption)),
    ]);
  }
}

/// The quiet ways from a nutrition summary to its settings: the daily goals ("Set daily goals" while none is set,
/// "Edit goals" once one is; Eat only, [goals]) and Customize tracking.
class NutritionTools extends ConsumerWidget {
  const NutritionTools({super.key, this.keyPrefix = 'nutrition', this.goals = true});

  /// Whether the goals link is offered here. Goals are set and edited in Eat; Today shows progress only.
  final bool goals;

  /// Distinguishes Today's from Eat's when both are built (the tabs stay alive).
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).value;
    final hasGoal = p != null && (p.calorieGoal != null || p.proteinGoal != null || p.waterGoalMl != null);
    // The goals link, then Customize tracking with its name (not an unexplained icon); they wrap by words.
    return Wrap(spacing: 4, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (goals)
        QuietLink(hasGoal ? context.l10n.eatEditGoals : context.l10n.eatSetGoals, key: Key('$keyPrefix-goals'), said: hasGoal ? context.l10n.eatEditGoalsSaid : context.l10n.eatSetGoals,
            onPressed: p == null ? null : () => showGoalsSheet(context, ref)),
      TextButton.icon(key: Key('$keyPrefix-customize'), onPressed: () => showTrackingSheet(context), icon: const Icon(Icons.tune, size: 20), label: Text(context.l10n.eatCustomizeTracking)),
    ]);
  }
}

/// "2,200 kcal · 140 g protein · 2 L water" for the goals that were set; null when none was.
String? goalsSummary(Profile? p, VolumeUnit unit, {required bool water}) {
  if (p == null) return null;
  final l = currentL10n;
  final parts = [
    if (p.calorieGoal != null) l.eatKcalValue(formatKcal(p.calorieGoal!)),
    if (p.proteinGoal != null) l.eatProteinGramsValue(formatGrouped(p.proteinGoal!)),
    if (water && p.waterGoalMl != null) l.eatWaterValue(unit.format(p.waterGoalMl!.toDouble())),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
