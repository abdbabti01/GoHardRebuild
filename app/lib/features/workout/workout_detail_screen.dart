import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/catalog_names.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../plans/plan_progress.dart';
import 'next_target.dart';
import 'result_rules.dart';
import 'workout_flow.dart';
import 'workout_screen.dart';

/// One recorded workout: its honest outcome, actual sets per movement and what was planned but not recorded.
/// Also the short result shown right after Finish; there is no share, rating or questionnaire in the way.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId, this.justFinished = false});
  final String workoutId;
  final bool justFinished;

  static String outcomeExplanation(AppLocalizations l, Workout w) => switch (w.outcome) {
        WorkoutResultRules.full => l.workoutOutcomeFullExplain,
        WorkoutResultRules.partial => l.workoutOutcomePartialExplain,
        WorkoutResultRules.noData => w.isManual ? l.workoutOutcomeNoDataExplainManual : l.workoutOutcomeNoDataExplainPlanned,
        WorkoutResultRules.manualRecorded => l.workoutOutcomeManualExplain,
        _ => l.workoutOutcomeOpenExplain,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = (ref.watch(workoutsProvider).value ?? const <Stored<Workout>>[]).where((r) => r.value.id == workoutId).firstOrNull;
    if (row == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final w = row.value;
    final sets = _setsOf(ref, workoutId);
    final l = context.l10n;

    return AppPage(
      title: justFinished ? outcomeLabel(l, w.outcome) : w.title,
      bottom: justFinished ? PrimaryButton(l.actionDone, key: const Key('result-done'), onPressed: () => Navigator.pop(context)) : null,
      actions: [
        if (!justFinished)
          IconButton(
            tooltip: l.workoutRemoveAction,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirm(context, title: l.workoutRemoveTitle, body: l.workoutRemoveRecordedBody(w.title, longDate(w.dayKey), sets.length), action: l.workoutRemoveAction, cancel: l.actionCancel)) return;
              await ref.read(workoutRepositoryProvider).delete(w);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ],
      children: [
        if (justFinished) Text(w.title, style: context.sansStyle(16, weight: FontWeight.w600)),
        ..._facts(context, ref, row, sets),
      ],
    );
  }
}

List<WorkoutSet> _setsOf(WidgetRef ref, String workoutId) =>
    [for (final r in ref.watch(setsProvider(workoutId)).value ?? const <Stored<WorkoutSet>>[]) if (!r.value.isDeleted) r.value]..sort((a, b) => a.performedAtUtc.compareTo(b.performedAtUtc));

/// What a workout recorded: when, where it came from, its honest outcome and every set per movement.
List<Widget> _facts(BuildContext context, WidgetRef ref, Stored<Workout> row, List<WorkoutSet> sets) {
  final w = row.value;
  final unit = ref.watch(loadUnitProvider);
  final l = context.l10n;
  final names = ref.watch(exerciseNamesProvider), locale = Localizations.localeOf(context);
  return [
        Text(w.isManual ? l.workoutDateManual(longDate(w.dayKey)) : longDate(w.dayKey), style: context.caption),
        // Which plan and session this came from, read from the plan as it is now (it may since have been edited,
        // archived or closed); the recorded exercises below are this workout's own and never change with the plan.
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(provenanceOf(w, ref.watch(planListProvider), ref.watch(workoutListProvider)), key: const Key('workout-provenance'), style: context.caption),
        ),
        const SizedBox(height: 12),
        StatusLine(w.isOpen ? Icons.timelapse : w.outcome == WorkoutResultRules.noData ? Icons.remove_circle_outline : Icons.check_circle_outline,
            '${outcomeLabel(l, w.outcome)}. ${WorkoutDetailScreen.outcomeExplanation(l, w)}'),
        if (row.isPending) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.phone_iphone, l.workoutSyncPending)),
        if (row.needsReview) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.rule, l.workoutDetailNeedsReview, tone: Tone.warning)),
        const SizedBox(height: 16),
        // The recorded facts as the page's pale summary panel; they wrap onto their own lines with large text.
        PhotoPanel(
          key: const Key('workout-facts'),
          photo: 'assets/images/workout-hero.webp',
          photoAlignment: const Alignment(1, 0.6),
          content: (_) => [
            Wrap(spacing: 24, runSpacing: 10, children: [
              _Fact(l.workoutFactTime, w.activeDurationSeconds == null ? '—' : durationText(w.activeDurationSeconds!)),
              _Fact(l.workoutFactSets, '${sets.length}'),
              _Fact(l.workoutFactMovements, '${sets.map((s) => s.exerciseId).toSet().length}'),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        if (w.isOpen) PrimaryButton(l.workoutResumeWorkout, onPressed: () => resumeWorkout(context, ref, w)),
        for (final e in w.exercises) ...[
          const SizedBox(height: 14),
          Text(names.name(e.catalogKey, e.name, locale), style: context.sansStyle(16, weight: FontWeight.w600)),
          if (e.isPrescribed) Text(l.workoutPlannedTarget(targetText(sets: e.targetSets, repsMin: e.targetRepsMin, repsMax: e.targetRepsMax, seconds: e.targetDurationSeconds, l: l)), style: context.numStyle(13.5, color: context.c.secondary, weight: FontWeight.w400)),
          if (sets.where((s) => s.exerciseId == e.id).isEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.isPrescribed ? l.workoutExerciseNotRecorded : l.workoutExerciseNoSets, style: context.sansStyle(14, color: context.c.secondary)))
          else
            for (final (i, s) in sets.where((s) => s.exerciseId == e.id).indexed)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.workoutSetRowTitle(i + 1, setText(s, unit, l)), style: context.numStyle(15, weight: FontWeight.w400))),
          const SizedBox(height: 12),
          const Rule(),
        ],
        if (w.exercises.isEmpty) EmptyState(l.workoutDetailEmptyTitle, l.workoutDetailEmptyBody),
  ];
}

/// The finished state of Train › Workouts' panel: the saved result under its real outcome label, then Done (back to
/// the overview, like All workouts). It only shows; nothing here changes the workout.
class WorkoutResultView extends ConsumerWidget {
  const WorkoutResultView({super.key, required this.workoutId, required this.onDone});
  final String workoutId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = (ref.watch(workoutsProvider).value ?? const <Stored<Workout>>[]).where((r) => r.value.id == workoutId).firstOrNull;
    if (row == null) return const SizedBox.shrink();
    return Column(key: const Key('workout-result'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: AlignmentDirectional.centerStart, child: AllWorkoutsLink(onPressed: onDone)),
      Heading(outcomeLabel(context.l10n, row.value.outcome), size: 28, serif: true),
      Text(row.value.title, style: context.sansStyle(16, weight: FontWeight.w600)),
      ..._facts(context, ref, row, _setsOf(ref, workoutId)),
      // Optional next targets this saved workout supports. It is already saved; nothing here changes it.
      if (definitionOf(ref, row.value) case final def? when !row.value.isOpen) NextTimeSection(planId: row.value.planId!, workoutId: def, source: row.value.id),
      const SizedBox(height: 20),
      PrimaryButton(context.l10n.actionDone, key: const Key('result-done'), onPressed: onDone),
    ]);
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Overline(label),
        Text(value, style: context.pageTitleStyle(28)),
      ]);
}

/// All retained workouts, newest first. Unfinished ones read "In progress", never as completed.
class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = [for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted) w]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return AppPage(title: context.l10n.workoutHistoryTitle, children: [
      if (workouts.isEmpty) EmptyState(context.l10n.workoutHistoryEmptyTitle, context.l10n.workoutHistoryEmptyBody),
      for (final w in workouts) WorkoutRow(w),
    ]);
  }
}

/// One workout in a list. [grouped] is the row of a short [GroupCard]; a long history uses flat rows, which are
/// laid out lazily. A planned workout names its plan; a manual one says manual.
class WorkoutRow extends ConsumerWidget {
  const WorkoutRow(this.workout, {super.key, this.grouped = false});
  final Workout workout;
  final bool grouped;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = workout.planId == null ? null : ref.watch(planListProvider).where((p) => p.id == workout.planId).firstOrNull;
    final l = context.l10n;
    final subtitle = [
      shortDate(workout.dayKey), outcomeLabel(l, workout.outcome),
      if (!workout.isOpen) l.workoutSetCount(workout.performedSets),
      if (workout.isManual) l.workoutManualTag else if (plan != null) plan.title,
    ].join(' · ');
    void open() => push(context, WorkoutDetailScreen(workoutId: workout.id));
    return grouped
        ? GroupRow(icon: Icons.fitness_center, tone: Tone.neutral, title: workout.title, subtitle: subtitle, onTap: open)
        : ListRow(icon: Icons.fitness_center, title: workout.title, subtitle: subtitle, onTap: open);
  }
}
