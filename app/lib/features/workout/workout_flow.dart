import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
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

/// Choose a movement from the catalog or type a custom one. Pops a [CatalogExercise].
class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key, this.title = 'Choose a movement'});
  final String title;
  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).value ?? const <CatalogExercise>[];
    final q = _query.trim().toLowerCase();
    final shown = [for (final e in catalog) if (q.isEmpty || e.name.toLowerCase().contains(q) || e.category.toLowerCase().contains(q)) e];
    return AppPage(title: widget.title, children: [
      TextField(key: const Key('exercise-search'), decoration: const InputDecoration(labelText: 'Search or type your own', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _query = v)),
      const SizedBox(height: 8),
      if (catalog.isEmpty) const StatusLine(Icons.cloud_off, 'The movement list has not been downloaded yet. You can still type your own movement.', tone: Tone.warning),
      if (_query.trim().isNotEmpty && !shown.any((e) => e.name.toLowerCase() == q))
        ListRow(
          key: const Key('exercise-custom'),
          icon: Icons.add, title: 'Use "${_query.trim()}"', subtitle: 'Custom movement. It keeps its own history.',
          onTap: () => Navigator.pop(context, CatalogExercise({'key': null, 'name': _query.trim(), 'category': 'Custom', 'equipment': '', 'isTimed': false})),
        ),
      for (final e in shown)
        ListRow(key: Key('exercise-${e.key}'), title: e.name, subtitle: '${e.category} · ${e.equipment}${e.isTimed ? ' · timed' : ''}', onTap: () => Navigator.pop(context, e)),
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
