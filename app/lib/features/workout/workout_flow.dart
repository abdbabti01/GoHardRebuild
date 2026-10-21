import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/catalog_names.dart';
import '../../core/device_prefs.dart';
import '../../core/language.dart';
import '../../core/search_fold.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../plans/plan_l10n.dart' show exerciseMatches;
import '../plans/plan_projection.dart';
import '../plans/plan_repository.dart';
import '../shell/home_shell.dart';
import 'workout_repository.dart';
import 'workout_screen.dart' show shownName;

/// Every way of starting or resuming a workout goes through here, so the one-foreground-workout rule and
/// its explicit choice are applied the same everywhere, and each ends in the same panel in Train › Workouts.
/// Nothing in this file finishes a workout.

/// Returns true when the requested workout may come to the foreground. Choosing "Resume it" shows that workout
/// in the panel instead and returns false.
Future<bool> ensureForeground(BuildContext context, WidgetRef ref, String? wantedId) async {
  final repo = ref.read(workoutRepositoryProvider);
  final decision = await repo.requestForeground(wantedId);
  if (decision is! ForegroundBusy || !context.mounted) return true;
  final current = decision.current;
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
      title: Text(context.l10n.workoutStillOpenTitle(current.title)),
      content: Text(context.l10n.workoutStillOpenBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.actionCancel)),
        TextButton(onPressed: () => Navigator.pop(context, 'park'), child: Text(context.l10n.workoutStillOpenPark)),
        FilledButton(onPressed: () => Navigator.pop(context, 'resume'), child: Text(context.l10n.workoutStillOpenResume)),
      ],
    ),
  );
  if (!context.mounted) return false;
  if (choice == 'resume') {
    openWorkoutPanel(context, ref, current.id);
    return false;
  }
  if (choice == 'park') {
    await repo.park(current.id);
    return true;
  }
  return false;
}

/// Shows an actual workout in Train › Workouts' panel, closing any page or sheet above the tabs. Only showing: the
/// workout's state is whatever its own rules made it.
void openWorkoutPanel(BuildContext context, WidgetRef ref, String workoutId) {
  final shell = ref.read(shellProvider.notifier);
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  shell.openWorkout(WorkoutFocus.session(workoutId));
}

// One start or resume at a time: a second tap while the first is still deciding or saving does nothing, so a rapid
// double tap can never create two workouts.
bool _busy = false;
Future<void> _once(BuildContext context, WidgetRef ref, Future<String?> Function() run) async {
  if (_busy) return;
  _busy = true;
  final owner = ref.read(ownerProvider);
  try {
    final id = await run();
    // A late answer for an account that has since signed out shows nothing.
    if (id != null && context.mounted && ref.read(ownerProvider) == owner) openWorkoutPanel(context, ref, id);
  } on LocalSaveFailure {
    if (context.mounted) toast(context, context.l10n.workoutStartFailed);
  } finally {
    _busy = false;
  }
}

/// Explicit Resume: the foreground rules, then the same workout ID in the panel.
Future<void> resumeWorkout(BuildContext context, WidgetRef ref, Workout workout) => _once(context, ref, () async {
      if (!await ensureForeground(context, ref, workout.id) || !context.mounted) return null;
      await ref.read(workoutRepositoryProvider).bringToForeground(workout.id);
      return workout.id;
    });

/// Start means started: the actual workout exists with its frozen prescription and running clock before the panel
/// shows it. There is no second Start: an occurrence that already has an open workout resumes that one instead.
Future<void> startPlannedWorkout(BuildContext context, WidgetRef ref, Plan plan, Occasion occasion) async {
  if (openWorkoutFor(occasion, ref.read(workoutListProvider)) case final open?) return resumeWorkout(context, ref, open);
  return _once(context, ref, () async {
    if (!await ensureForeground(context, ref, null) || !context.mounted) return null;
    return (await ref.read(workoutRepositoryProvider).startPlanned(plan, occasion, ref.read(todayKeyProvider))).id;
  });
}

/// Manual training: name it, pick movements, start. Needs no plan and works offline.
Future<void> startManualWorkout(BuildContext context, WidgetRef ref) async {
  final picked = await push<(String, List<CatalogExercise>)>(context, const ManualWorkoutSetup());
  if (picked == null || !context.mounted) return;
  return _once(context, ref, () async {
    if (!await ensureForeground(context, ref, null) || !context.mounted) return null;
    return (await ref.read(workoutRepositoryProvider).startManual(picked.$1, picked.$2, ref.read(todayKeyProvider))).id;
  });
}

/// Lowercase, with hyphens, slashes and repeated spaces folded, so "Push-up", "push up" and "PUSH  UP" match.
String _fold(String s) => s.toLowerCase().replaceAll(RegExp(r'[-_/.,()]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// A choice among several shown as a pill: a 48 px target around it, the accent border, a check and a heavier label
/// when chosen (never colour alone), and selected semantics. Lay several out in a Wrap or a sideways-scrolling Row.
class PickChip extends StatelessWidget {
  const PickChip({super.key, required this.label, required this.selected, required this.onTap, this.semanticLabel});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected, button: true, label: semanticLabel, excludeSemantics: semanticLabel != null,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            if (!selected) Haptics.selection();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.minimum, minWidth: Targets.minimum),
            child: Center(
              widthFactor: 1, heightFactor: 1,
              child: AnimatedContainer(
                duration: context.motion(Motion.quick), curve: Motion.curve,
                constraints: const BoxConstraints(minHeight: 38), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    color: selected ? context.c.accentSoft : context.c.surface, borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: selected ? context.c.accent : context.c.outline, width: selected ? 2 : 1)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (selected) ...[Icon(Icons.check_rounded, size: 16, color: context.c.accent), const SizedBox(width: 4)],
                  Flexible(child: Text(label, textAlign: TextAlign.center, style: context.sansStyle(14.5, weight: selected ? FontWeight.w700 : FontWeight.w500))),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Choose an exercise: search familiar names, narrow by muscle group and equipment, or create your own (private to
/// the account, synced like everything else). Pops a [CatalogExercise]; one of your own has key `custom:<id>`.
class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key, this.title});

  /// "Choose a movement" when null.
  final String? title;
  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  String _query = '';
  String? _muscle, _equipment;

  /// Matched in every language: the stored name, the category and equipment in English and as shown, and the
  /// catalog's French, Arabic and English names and aliases (folded for accents and Arabic variants).
  /// The shared rule ([exerciseMatches]) first; then word by word, ignoring hyphens and spacing ("push up").
  static bool _matches(CatalogExercise e, String query, ExerciseNames names, Locale locale) {
    if (exerciseMatches(names, query, name: e.name, catalogKey: e.key, extra: '${e.category} ${e.equipment}')) return true;
    final q = _fold(foldForSearch(query));
    final hay = _fold(foldForSearch([e.name, e.category, e.equipment, names.category(e.category, locale), names.equipment(e.equipment, locale), if (e.key != null) ...names.searchTerms(e.key!)].join(' ')));
    return q.split(' ').every(hay.contains) || hay.replaceAll(' ', '').contains(q.replaceAll(' ', ''));
  }

  Future<void> _create() async {
    final all = ref.read(exerciseChoicesProvider);
    final made = await showGoSheet<CustomExercise>(context, title: context.l10n.workoutCustomTitle,
        builder: (_) => _CustomExerciseForm(name: _query.trim(), categories: {for (final e in all) e.category}, equipment: {for (final e in all) if (e.equipment.isNotEmpty) e.equipment}));
    if (made == null || !mounted) return;
    Navigator.pop(context, CatalogExercise({'key': made.key, 'name': made.name, 'category': made.category, 'equipment': made.equipment, 'isTimed': made.isTimed, 'isCustom': true}));
  }

  Widget _chips(String label, List<String> values, String Function(String) shown, String? selected, String keyPrefix, ValueChanged<String?> pick) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(label),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final v in values)
              Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: PickChip(key: Key('$keyPrefix-$v'), label: shown(v), selected: v == selected, onTap: () => pick(v == selected ? null : v))),
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(exerciseChoicesProvider);
    final names = ref.watch(exerciseNamesProvider), locale = Localizations.localeOf(context), l = context.l10n;
    String category(String v) => names.category(v, locale);
    String kit(String v) => names.equipment(v, locale);
    final catalogEmpty = !all.any((e) => !e.isCustom);
    final muscles = {for (final e in all) e.category}.toList()..sort();
    final equipment = {for (final e in all) if (e.equipment.isNotEmpty) e.equipment}.toList()..sort();
    final shown = [
      for (final e in all)
        if ((_muscle == null || e.category == _muscle) && (_equipment == null || e.equipment == _equipment) && _matches(e, _query, names, locale)) e,
    ];
    final q = _query.trim();
    return AppPage(title: widget.title ?? l.workoutPickerTitle, children: [
      TextField(
          key: const Key('exercise-search'), textInputAction: TextInputAction.search,
          decoration: InputDecoration(labelText: l.workoutPickerSearch, prefixIcon: const Icon(Icons.search)), onChanged: (v) => setState(() => _query = v)),
      const SizedBox(height: 10),
      if (catalogEmpty) ...[
        StatusLine(Icons.cloud_off, l.workoutPickerCatalogEmpty, tone: Tone.warning),
        const SizedBox(height: 10),
      ],
      if (muscles.length > 1) _chips(l.workoutPickerMuscle, muscles, category, _muscle, 'filter-muscle', (v) => setState(() => _muscle = v)),
      if (equipment.length > 1) ...[const SizedBox(height: 6), _chips(l.workoutPickerEquipment, equipment, kit, _equipment, 'filter-equipment', (v) => setState(() => _equipment = v))],
      const SizedBox(height: 6),
      if (shown.isEmpty && all.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(l.workoutPickerNoMatch, style: context.caption)),
      for (final e in shown)
        ListRow(
          key: Key('exercise-${e.key}'), title: names.name(e.key, e.name, locale),
          subtitle: [category(e.category), if (e.equipment.isNotEmpty) kit(e.equipment), if (e.isTimed) l.workoutPickerTimedTag, if (e.isCustom) l.workoutPickerYourExercise].join(' · '),
          onTap: () => Navigator.pop(context, e),
        ),
      ListRow(
        key: const Key('exercise-create-custom'), icon: Icons.add,
        title: q.isEmpty ? l.workoutPickerCreate : l.workoutPickerCreateNamed(q),
        subtitle: l.workoutPickerCreateSubtitle, onTap: _create,
      ),
    ]);
  }
}

class _CustomExerciseForm extends ConsumerStatefulWidget {
  const _CustomExerciseForm({required this.name, required this.categories, required this.equipment});
  final String name;
  final Set<String> categories, equipment;
  @override
  ConsumerState<_CustomExerciseForm> createState() => _CustomExerciseFormState();
}

class _CustomExerciseFormState extends ConsumerState<_CustomExerciseForm> {
  late final _name = TextEditingController(text: widget.name);
  late final _categories = {...widget.categories, 'Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core', 'Other'}.toList()..sort();
  late final _kits = {...widget.equipment, 'Barbell', 'Dumbbell', 'Machine', 'Cable', 'Bodyweight', 'Other'}.toList()..sort();
  String _category = 'Other', _kit = 'Other';
  bool _timed = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _busy = true; _error = null; });
    try {
      final made = await ref.read(planRepositoryProvider).saveCustomExercise(name: _name.text, category: _category, equipment: _kit, isTimed: _timed);
      if (mounted) Navigator.pop(context, made);
    } on ScheduleRefused catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message; });
    } on LocalSaveFailure {
      if (mounted) setState(() { _busy = false; _error = context.l10n.workoutSaveFailedRetry; });
    }
  }

  Widget _choices(List<String> values, String Function(String) shown, String selected, String keyPrefix, ValueChanged<String> pick) =>
      Wrap(spacing: 6, children: [for (final v in values) PickChip(key: Key('$keyPrefix-$v'), label: shown(v), selected: v == selected, onTap: () => setState(() => pick(v)))]);

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(exerciseNamesProvider), locale = Localizations.localeOf(context), l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(l.workoutCustomCaption, style: context.caption),
        const SizedBox(height: 12),
        TextField(
            key: const Key('custom-name'), controller: _name, maxLength: 80, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.workoutCustomName, errorText: _error), onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        SectionLabel(l.workoutPickerMuscle),
        _choices(_categories, (v) => names.category(v, locale), _category, 'custom-category', (v) => _category = v),
        const SizedBox(height: 8),
        SectionLabel(l.workoutPickerEquipment),
        _choices(_kits, (v) => names.equipment(v, locale), _kit, 'custom-equipment', (v) => _kit = v),
        SwitchListTile(
            key: const Key('custom-timed'), contentPadding: EdgeInsets.zero, value: _timed, onChanged: (v) => setState(() => _timed = v),
            title: Text(l.workoutCustomTimed), subtitle: Text(l.workoutCustomTimedHelp)),
        const SizedBox(height: 8),
        PrimaryButton(l.workoutCustomSave, key: const Key('custom-save'), busy: _busy, onPressed: _name.text.trim().isEmpty ? null : _save),
      ]);
  }
}

class ManualWorkoutSetup extends ConsumerStatefulWidget {
  const ManualWorkoutSetup({super.key});
  @override
  ConsumerState<ManualWorkoutSetup> createState() => _ManualWorkoutSetupState();
}

class _ManualWorkoutSetupState extends ConsumerState<ManualWorkoutSetup> {
  final _title = TextEditingController();
  final _chosen = <CatalogExercise>[];

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String nameOf(CatalogExercise e) => shownName(ref, context, e.key, e.name);
    return AppPage(
        title: l.workoutManualTitle,
        // Left blank, the workout is named in the app's language ("Workout" in English, as before).
        bottom: PrimaryButton(l.workoutStart, key: const Key('manual-start'), onPressed: () => Navigator.pop(context, (_title.text.trim().isEmpty ? l.workoutManualDefaultName : _title.text, List.of(_chosen)))),
        children: [
          Text(l.workoutManualCaption, style: context.caption),
          const SizedBox(height: 14),
          TextField(key: const Key('manual-title'), controller: _title, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: l.workoutCustomName, hintText: l.workoutManualDefaultName)),
          const SizedBox(height: 18),
          SectionLabel(l.workoutManualMovements),
          if (_chosen.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.workoutManualNone, style: context.caption)),
          if (_chosen.isNotEmpty) ...[
            const SizedBox(height: 8),
            GroupCard(children: [
              for (final (i, e) in _chosen.indexed)
                GroupRow(title: nameOf(e), trailing: IconButton(tooltip: l.workoutManualRemove(nameOf(e)), icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _chosen.removeAt(i)))),
            ]),
          ],
          const SizedBox(height: 10),
          SecondaryButton(l.workoutAddMovement, key: const Key('manual-add-exercise'), icon: Icons.add, onPressed: () async {
            final e = await push<CatalogExercise>(context, const ExercisePicker());
            if (e != null) setState(() => _chosen.add(e));
          }),
        ],
      );
  }
}
