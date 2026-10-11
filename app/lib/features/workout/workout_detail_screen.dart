import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'result_rules.dart';
import 'workout_flow.dart';
import 'workout_screen.dart';

/// One recorded workout: its honest outcome, actual sets per movement and what was planned but not recorded.
/// Also the short result shown right after Finish; there is no share, rating or questionnaire in the way.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId, this.justFinished = false});
  final String workoutId;
  final bool justFinished;

  static String outcomeExplanation(Workout w) => switch (w.outcome) {
        WorkoutResultRules.full => 'Every planned movement has its target number of sets recorded.',
        WorkoutResultRules.partial => 'Actual training was recorded. Some planned work was not; that is shown below.',
        WorkoutResultRules.noData => 'No training was logged, so this gives no training credit${w.isManual ? '' : ' and the planned workout is still available'}.',
        WorkoutResultRules.manualRecorded => 'Recorded as manual training. It does not tick off a planned workout.',
        _ => 'This workout is still open. It is never finished automatically.',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = (ref.watch(workoutsProvider).value ?? const <Stored<Workout>>[]).where((r) => r.value.id == workoutId).firstOrNull;
    if (row == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final w = row.value;
    final unit = ref.watch(loadUnitProvider);
    final sets = [for (final r in ref.watch(setsProvider(workoutId)).value ?? const <Stored<WorkoutSet>>[]) if (!r.value.isDeleted) r.value]
      ..sort((a, b) => a.performedAtUtc.compareTo(b.performedAtUtc));

    return EveningPage(
      title: justFinished ? WorkoutResultRules.label(w.outcome) : w.title,
      bottom: justFinished ? PrimaryButton('Done', key: const Key('result-done'), onPressed: () => Navigator.pop(context)) : null,
      actions: [
        if (!justFinished)
          IconButton(
            tooltip: 'Remove workout',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirm(context, title: 'Remove this workout?', body: 'This removes "${w.title}" from ${longDate(w.dayKey)} and its ${sets.length} recorded set${sets.length == 1 ? '' : 's'} from your history.', action: 'Remove workout')) return;
              await ref.read(workoutRepositoryProvider).delete(w);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ],
      children: [
        if (justFinished) Text(w.title, style: context.sansStyle(16, weight: FontWeight.w600)),
        Text('${longDate(w.dayKey)}${w.isManual ? ' · manual' : ''}', style: context.caption),
        const SizedBox(height: 12),
        StatusLine(w.isOpen ? Icons.timelapse : w.outcome == WorkoutResultRules.noData ? Icons.remove_circle_outline : Icons.check_circle_outline,
            '${WorkoutResultRules.label(w.outcome)}. ${outcomeExplanation(w)}'),
        if (row.isPending) const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.phone_iphone, 'Saved on this phone · sync pending')),
        if (row.needsReview) const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.rule, 'Saved on this phone; needs your review before it can sync.', tone: Tone.warning)),
        const SizedBox(height: 16),
        Row(children: [
          _Fact('Time', w.activeDurationSeconds == null ? '—' : durationText(w.activeDurationSeconds!)),
          _Fact('Sets', '${sets.length}'),
          _Fact('Movements', '${sets.map((s) => s.exerciseId).toSet().length}'),
        ]),
        const SizedBox(height: 20),
        if (w.isOpen) PrimaryButton('Resume workout', onPressed: () => resumeWorkout(context, ref, w)),
        for (final e in w.exercises) ...[
          const SizedBox(height: 14),
          Text(e.name, style: context.sansStyle(16, weight: FontWeight.w600)),
          if (e.isPrescribed) Text('Planned · ${e.target}', style: context.caption),
          if (sets.where((s) => s.exerciseId == e.id).isEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.isPrescribed ? 'Not recorded.' : 'No sets recorded.', style: context.sansStyle(14, color: context.ec.secondary)))
          else
            for (final (i, s) in sets.where((s) => s.exerciseId == e.id).indexed)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('${i + 1}.  ${setText(s, unit)}', style: context.sansStyle(15).copyWith(fontFeatures: const [FontFeature.tabularFigures()]))),
          const SizedBox(height: 10),
          const Rule(),
        ],
        if (w.exercises.isEmpty) const EmptyState('Nothing recorded', 'This workout has no movements.'),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.sansStyle(12, color: context.ec.secondary)),
          Text(value, style: context.serifStyle(25)),
        ]),
      );
}

/// All retained workouts, newest first. Unfinished ones read "In progress", never as completed.
class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = [for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted) w]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return EveningPage(title: 'Workout history', children: [
      if (workouts.isEmpty) const EmptyState('No workouts yet', 'Workouts you record will appear here with what you actually did.'),
      for (final w in workouts) WorkoutRow(w),
    ]);
  }
}

class WorkoutRow extends StatelessWidget {
  const WorkoutRow(this.workout, {super.key});
  final Workout workout;
  @override
  Widget build(BuildContext context) => ListRow(
        title: workout.title,
        subtitle: '${shortDate(workout.dayKey)} · ${WorkoutResultRules.label(workout.outcome)}'
            '${workout.isOpen ? '' : ' · ${workout.performedSets} set${workout.performedSets == 1 ? '' : 's'}'}${workout.isManual ? ' · manual' : ''}',
        onTap: () => push(context, WorkoutDetailScreen(workoutId: workout.id)),
      );
}
