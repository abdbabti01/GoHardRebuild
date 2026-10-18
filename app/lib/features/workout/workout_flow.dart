import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/device_prefs.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../coach/exercise_demo.dart' show DemoPoster;
import '../coach/exercise_media.dart' show ExerciseMedia, exerciseMediaProvider;
import '../coach/guide_sheets.dart' show showExerciseDetails;
import '../plans/plan_repository.dart';
import 'workout_repository.dart';
import 'workout_screen.dart';

/// Every way of starting or resuming a workout goes through here, so the one-foreground-workout rule and
/// its explicit choice are applied the same everywhere. Nothing in this file finishes a workout.

/// Returns true when the requested workout may come to the foreground.
Future<bool> _clearForeground(BuildContext context, WidgetRef ref, String? wantedId) async {
  final repo = ref.read(workoutRepositoryProvider);
  final decision = await repo.requestForeground(wantedId);
  if (decision is! ForegroundBusy || !context.mounted) return true;
  final current = decision.current;
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
      title: Text('${current.title} is still open'),
      content: const Text('Only one workout is in front at a time. Resume it, or save it for later. Saving for later keeps every recorded set and never finishes it.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, 'park'), child: const Text('Save it for later and continue')),
        FilledButton(onPressed: () => Navigator.pop(context, 'resume'), child: const Text('Resume it')),
      ],
    ),
  );
  if (!context.mounted) return false;
  if (choice == 'resume') {
    await push(context, WorkoutScreen(workoutId: current.id));
    return false;
  }
  if (choice == 'park') {
    await repo.park(current.id);
    return true;
  }
  return false;
}

Future<void> resumeWorkout(BuildContext context, WidgetRef ref, Workout workout) async {
  if (!await _clearForeground(context, ref, workout.id) || !context.mounted) return;
  await ref.read(workoutRepositoryProvider).bringToForeground(workout.id);
  if (context.mounted) await push(context, WorkoutScreen(workoutId: workout.id));
}

/// Start means started: the actual workout exists with its frozen prescription and running clock before
/// the screen opens. There is no second Start.
Future<void> startPlannedWorkout(BuildContext context, WidgetRef ref, Plan plan, Occasion occasion) async {
  if (!await _clearForeground(context, ref, null) || !context.mounted) return;
  try {
    final workout = await ref.read(workoutRepositoryProvider).startPlanned(plan, occasion, ref.read(todayKeyProvider));
    if (context.mounted) await push(context, WorkoutScreen(workoutId: workout.id));
  } on LocalSaveFailure {
    if (context.mounted) toast(context, 'The workout could not be started on this phone. Nothing was recorded. Try again.');
  }
}

/// Manual training: name it, pick movements, start. Needs no plan and works offline.
Future<void> startManualWorkout(BuildContext context, WidgetRef ref) async {
  final picked = await push<(String, List<CatalogExercise>)>(context, const ManualWorkoutSetup());
  if (picked == null || !context.mounted) return;
  if (!await _clearForeground(context, ref, null) || !context.mounted) return;
  try {
    final workout = await ref.read(workoutRepositoryProvider).startManual(picked.$1, picked.$2, ref.read(todayKeyProvider));
    if (context.mounted) await push(context, WorkoutScreen(workoutId: workout.id));
  } on LocalSaveFailure {
    if (context.mounted) toast(context, 'The workout could not be started on this phone. Nothing was recorded. Try again.');
  }
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
  const ExercisePicker({super.key, this.title = 'Choose a movement'});
  final String title;
  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  String _query = '';
  String? _muscle, _equipment;

  static bool _matches(CatalogExercise e, String query) {
    final q = _fold(query);
    if (q.isEmpty) return true;
    final hay = _fold('${e.name} ${e.category} ${e.equipment}');
    return q.split(' ').every(hay.contains) || hay.replaceAll(' ', '').contains(q.replaceAll(' ', ''));
  }

  Future<void> _create() async {
    final all = ref.read(exerciseChoicesProvider);
    final made = await showGoSheet<CustomExercise>(context, title: 'Your own exercise',
        builder: (_) => _CustomExerciseForm(name: _query.trim(), categories: {for (final e in all) e.category}, equipment: {for (final e in all) if (e.equipment.isNotEmpty) e.equipment}));
    if (made == null || !mounted) return;
    Navigator.pop(context, CatalogExercise({'key': made.key, 'name': made.name, 'category': made.category, 'equipment': made.equipment, 'isTimed': made.isTimed, 'isCustom': true}));
  }

  Widget _chips(String label, List<String> values, String? selected, String keyPrefix, ValueChanged<String?> pick) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(label),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final v in values)
              Padding(padding: const EdgeInsets.only(right: 6), child: PickChip(key: Key('$keyPrefix-$v'), label: v, selected: v == selected, onTap: () => pick(v == selected ? null : v))),
          ]),
        ),
      ]);

  /// Opens the exercise sheet over the picker to look, not to choose: the search, filters, scroll position and the
  /// list stay as they were, and closing it chooses nothing.
  Widget _preview(CatalogExercise e, bool video) {
    void open() => showExerciseDetails(context, exercise: (catalogKey: e.key, name: e.name, isTimed: e.isTimed));
    return video
        ? TextButton.icon(key: Key('exercise-demo-${e.key}'), onPressed: open, icon: const Icon(Icons.play_circle_outline_rounded, size: 20), label: const Text('Demo'))
        : IconButton(key: Key('exercise-about-${e.key}'), tooltip: 'About ${e.name}', icon: const Icon(Icons.info_outline, size: 20), onPressed: open);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(exerciseChoicesProvider);
    // Bundled and read once; nothing is fetched to show the list.
    final demos = ref.watch(exerciseMediaProvider).value;
    final catalogEmpty = !all.any((e) => !e.isCustom);
    final muscles = {for (final e in all) e.category}.toList()..sort();
    final equipment = {for (final e in all) if (e.equipment.isNotEmpty) e.equipment}.toList()..sort();
    final shown = [
      for (final e in all)
        if ((_muscle == null || e.category == _muscle) && (_equipment == null || e.equipment == _equipment) && _matches(e, _query)) e,
    ];
    final q = _query.trim();
    return AppPage(title: widget.title, children: [
      TextField(
          key: const Key('exercise-search'), textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: 'Search exercises', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _query = v)),
      const SizedBox(height: 10),
      if (catalogEmpty) ...[
        const StatusLine(Icons.cloud_off, 'The exercise list has not been downloaded to this phone yet. You can still create your own exercise.', tone: Tone.warning),
        const SizedBox(height: 10),
      ],
      if (muscles.length > 1) _chips('Muscle group', muscles, _muscle, 'filter-muscle', (v) => setState(() => _muscle = v)),
      if (equipment.length > 1) ...[const SizedBox(height: 6), _chips('Equipment', equipment, _equipment, 'filter-equipment', (v) => setState(() => _equipment = v))],
      const SizedBox(height: 6),
      if (shown.isEmpty && all.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('No exercise matches that. Try another name or filter, or create your own.', style: context.caption)),
      for (final e in shown)
        ListRow(
          key: Key('exercise-${e.key}'), title: e.name,
          subtitle: [e.category, if (e.equipment.isNotEmpty) e.equipment, if (e.isTimed) 'timed', if (e.isCustom) 'Your exercise'].join(' · '),
          leading: switch (demos?.forKey(e.key)) {
            final m? => _Thumb(m),
            null => null,
          },
          trailing: e.isCustom ? null : _preview(e, demos?.forKey(e.key)?.isVideo ?? false),
          onTap: () => Navigator.pop(context, e),
        ),
      ListRow(
        key: const Key('exercise-create-custom'), icon: Icons.add,
        title: q.isEmpty ? 'Create your own exercise' : 'Create “$q” as your own exercise',
        subtitle: 'Private to your account. It keeps its own history.', onTap: _create,
      ),
    ]);
  }
}

/// A small static picture of a reviewed demonstration (its bundled poster), decoded at its own size.
class _Thumb extends StatelessWidget {
  const _Thumb(this.media);
  final ExerciseMedia media;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: DemoPoster(media, width: 56, height: 40, fit: BoxFit.cover, cacheWidth: (56 * MediaQuery.devicePixelRatioOf(context)).ceil()),
        ),
      );
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
      if (mounted) setState(() { _busy = false; _error = 'It could not be saved on this phone. Try again.'; });
    }
  }

  Widget _choices(List<String> values, String selected, String keyPrefix, ValueChanged<String> pick) =>
      Wrap(spacing: 6, children: [for (final v in values) PickChip(key: Key('$keyPrefix-$v'), label: v, selected: v == selected, onTap: () => setState(() => pick(v)))]);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Only you can see your own exercises. Renaming one later never changes what you already recorded.', style: context.caption),
        const SizedBox(height: 12),
        TextField(
            key: const Key('custom-name'), controller: _name, maxLength: 80, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Name', errorText: _error), onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        const SectionLabel('Muscle group'),
        _choices(_categories, _category, 'custom-category', (v) => _category = v),
        const SizedBox(height: 8),
        const SectionLabel('Equipment'),
        _choices(_kits, _kit, 'custom-equipment', (v) => _kit = v),
        SwitchListTile(
            key: const Key('custom-timed'), contentPadding: EdgeInsets.zero, value: _timed, onChanged: (v) => setState(() => _timed = v),
            title: const Text('Timed'), subtitle: const Text('Held or done for a time, like a plank, instead of counted reps.')),
        const SizedBox(height: 8),
        PrimaryButton('Save exercise', key: const Key('custom-save'), busy: _busy, onPressed: _name.text.trim().isEmpty ? null : _save),
      ]);
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
  Widget build(BuildContext context) => AppPage(
        title: 'Manual workout',
        bottom: PrimaryButton('Start workout', key: const Key('manual-start'), onPressed: () => Navigator.pop(context, (_title.text, List.of(_chosen)))),
        children: [
          Text('Train without a plan. This is recorded as real training and never ticks off a planned workout.', style: context.caption),
          const SizedBox(height: 14),
          TextField(key: const Key('manual-title'), controller: _title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Name', hintText: 'Workout')),
          const SizedBox(height: 18),
          const SectionLabel('Movements'),
          if (_chosen.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('None yet. You can also add movements after starting.', style: context.caption)),
          if (_chosen.isNotEmpty) ...[
            const SizedBox(height: 8),
            GroupCard(children: [
              for (final (i, e) in _chosen.indexed)
                GroupRow(title: e.name, trailing: IconButton(tooltip: 'Remove ${e.name}', icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _chosen.removeAt(i)))),
            ]),
          ],
          const SizedBox(height: 10),
          SecondaryButton('Add a movement', key: const Key('manual-add-exercise'), icon: Icons.add, onPressed: () async {
            final e = await push<CatalogExercise>(context, const ExercisePicker());
            if (e != null) setState(() => _chosen.add(e));
          }),
        ],
      );
}
