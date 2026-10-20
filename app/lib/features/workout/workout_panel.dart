import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../coach/guide_sheets.dart' show showExerciseInfo, rxSentence;
import '../plans/plan_actions.dart';
import '../plans/plan_progress.dart';
import '../plans/week_widgets.dart' show OccasionPill;
import '../shell/home_shell.dart';
import '../today/daily.dart';
import 'next_target.dart';
import 'progress.dart';
import 'workout_flow.dart';
import 'workout_screen.dart';

/// Train › Workouts' one workout panel: the preview of a planned occurrence before Start, then the recorder for the
/// actual workout, then its saved result, all in this one place (docs/DESIGN.md › Workout panel). What it shows is
/// [ShellState.workout]; showing is never starting, and leaving never pauses, parks or finishes anything.
class WorkoutPanel extends ConsumerWidget {
  const WorkoutPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(shellProvider.select((s) => s.workout));
    void close() => ref.read(shellProvider.notifier).closeWorkout();
    final child = switch (focus) {
      null => const SizedBox.shrink(),
      WorkoutFocus(:final workoutId?) => WorkoutRecorder(key: ValueKey('session-$workoutId'), workoutId: workoutId, onLeave: close),
      WorkoutFocus(:final planId, :final occasionId) => WorkoutPreview(key: ValueKey('preview-$planId-$occasionId'), planId: planId!, occasionId: occasionId!, onLeave: close),
    };
    // A subtle fade from preview to recording; the state that matters lives in the stored workout, not in the widget.
    return AnimatedSwitcher(
      duration: context.motion(Motion.quick), reverseDuration: Duration.zero, switchInCurve: Motion.curve,
      layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
      child: child,
    );
  }
}

/// One planned occurrence before it is started, from the same projection as Today and Plan: its state and plan
/// context, every exercise with its prescription and last time, and Start only when the plan's rules allow it.
/// Nothing is created here until Start; an occurrence that already has an open workout shows that workout instead.
class WorkoutPreview extends ConsumerStatefulWidget {
  const WorkoutPreview({super.key, required this.planId, required this.occasionId, required this.onLeave});
  final String planId, occasionId;
  final VoidCallback onLeave;
  @override
  ConsumerState<WorkoutPreview> createState() => _WorkoutPreviewState();
}

class _WorkoutPreviewState extends ConsumerState<WorkoutPreview> {
  /// Collapsed rows shown before "See all".
  static const _shown = 4;
  int? _expanded = 0;
  bool _all = false, _starting = false;

  Future<void> _start(Plan plan, Occasion o) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await startPlannedWorkout(context, ref, plan, o);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planListProvider).where((p) => p.id == widget.planId).firstOrNull;
    final today = ref.watch(todayKeyProvider);
    final workouts = ref.watch(workoutListProvider);
    final o = plan == null ? null : planOccasions(plan, today, workouts).where((x) => x.id == widget.occasionId).firstOrNull;
    if (plan == null || o == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AllWorkoutsLink(onPressed: widget.onLeave),
        ref.watch(plansProvider).hasValue
            ? const EmptyState('This workout is no longer planned', 'The plan changed since it was opened. Nothing was started or recorded.')
            : const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      ]);
    }
    // Already started (here, on Today or on another device): that workout, never a second one.
    if (openWorkoutFor(o, workouts) case final open?) return WorkoutRecorder(key: ValueKey('session-${open.id}'), workoutId: open.id, onLeave: widget.onLeave);

    final c = context.c;
    final unit = ref.watch(loadUnitProvider);
    final status = statusOf(o, plan, today, workouts);
    final startable = canStartOccasion(plan, o, today, workouts);
    final recorded = o.resultWorkoutId ?? workouts.where((w) => !w.isDeleted && w.occasionId == o.id && !w.isOpen && w.qualifiedOccasion).firstOrNull?.id;
    final sets = o.prescription.fold(0, (n, e) => n + (e.targetSets ?? 0));
    final minutes = plannedMinutes(plan);
    final where = o.sequenceIndex != null ? 'Session ${o.sequenceIndex! + 1}' : 'Week ${o.weekNumber}';
    final keys = [for (final p in o.prescription) p.catalogKey];
    // Anchored at now: before Start there is no session, and nothing is made up to stand in for one.
    final now = ref.read(clockProvider).utcNow();
    final rows = o.prescription.indexed.toList();
    final visible = _all || rows.length <= _shown + 1 ? rows : rows.take(_shown).toList();

    return Column(key: const Key('workout-preview'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerLeft, child: AllWorkoutsLink(onPressed: widget.onLeave)),
      PhotoPanel(
        key: const Key('preview-panel'),
        photo: 'assets/images/workout-hero.webp',
        photoAlignment: const Alignment(1, 0.6),
        content: (context) => [
          Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [Overline(where), OccasionPill(status)]),
          const SizedBox(height: 6),
          Semantics(header: true, child: Text(o.title, style: context.pageTitleStyle(30))),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('${o.prescription.length} ${o.prescription.length == 1 ? 'exercise' : 'exercises'}${sets == 0 ? '' : ' · $sets planned ${sets == 1 ? 'set' : 'sets'}'}',
                style: context.numStyle(16, weight: FontWeight.w600)),
          ),
          Text('${o.scheduledDate == today ? 'Today' : longDate(o.scheduledDate)} · ${plan.title}${minutes == null ? '' : ' · $minutes min planned'}', style: context.sansStyle(14.5, color: context.c.secondary)),
        ],
        actions: (context) => [
          if (startable) PrimaryButton('Start workout', key: const Key('preview-start'), icon: Icons.play_arrow_rounded, expand: false, busy: _starting, onPressed: () => _start(plan, o)),
          if (recorded != null)
            QuietLink('View what was recorded', key: const Key('preview-recorded'), onPressed: () => ref.read(shellProvider.notifier).openWorkout(WorkoutFocus.session(recorded))),
          // Move, skip, edit this one and the rest stay where they were, in the occurrence sheet.
          QuietLink('More options', key: const Key('preview-options'), said: 'Move, skip or edit this workout', onPressed: () => showOccasionSheet(appContext(context), ref, plan, o)),
        ],
      ),
      // Suggestions stay reachable here after the result is gone. An occurrence edited on its own keeps its content.
      if (o.workoutId != null && !o.isCustomised) NextTimeSection(planId: plan.id, workoutId: o.workoutId!),
      const SizedBox(height: 22),
      const SectionHeader('Exercises'),
      const SizedBox(height: 10),
      if (rows.isEmpty) Text('No exercises are planned in this workout.', style: context.caption),
      if (rows.isNotEmpty)
        GroupCard(children: [
          for (final (i, e) in visible)
            _PreviewRow(
              index: i, exercise: e, expanded: _expanded == i, unit: unit, workoutName: o.title,
              slotKey: o.workoutId == null || o.isCustomised ? null : (planId: plan.id, workoutId: o.workoutId!, occurrenceKey: e.occurrenceKey),
              history: exerciseHistory(catalogKey: e.catalogKey, ordinal: occurrenceOf(keys, i), beforeUtc: now, workouts: workouts, sets: ref.watch(trustedSetsProvider)),
              status: historyStatus(ref, e.catalogKey),
              onTap: () => setState(() => _expanded = _expanded == i ? null : i),
            ),
        ]),
      if (visible.length < rows.length)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(key: const Key('preview-see-all'), onPressed: () => setState(() => _all = true), child: Text('See all ${rows.length} exercises')),
        ),
      if (!startable && recorded == null) ...[
        const SizedBox(height: 14),
        StatusLine(Icons.info_outline, switch (status) {
          _ when plan.isPaused => 'The plan is paused. Resume the plan to start its workouts.',
          OccasionStatus.skipped => 'Skipped. Nothing was recorded for it.',
          _ when plan.isRotating => 'A rotation runs in order: this one comes up after the workouts before it.',
          _ => 'This workout cannot be started now. More options shows what can be done with it.',
        }, tone: Tone.neutral),
      ],
      Padding(padding: const EdgeInsets.only(top: 14), child: Text('Last time is what you actually recorded before. Nothing here is recorded until you start.', style: context.caption.copyWith(color: c.secondary))),
    ]);
  }
}

/// One exercise of the preview: collapsed, its number, name and prescription; expanded, also the plan's words for it,
/// the user's target and notes, About, and last time.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.index, required this.exercise, required this.expanded, required this.unit, required this.workoutName, required this.history, required this.status, required this.onTap, this.slotKey});
  final int index;
  final Prescription exercise;
  final bool expanded;
  final LoadUnit unit;
  final String workoutName;
  final List<PreviousPerformance> history;
  final HistoryStatus status;
  final VoidCallback onTap;

  /// Where this exercise's target lives in the plan, when it can be reviewed from here.
  final TargetKey? slotKey;

  @override
  Widget build(BuildContext context) {
    final e = exercise, c = context.c;
    final rx = targetText(sets: e.targetSets, repsMin: e.targetRepsMin, repsMax: e.targetRepsMax, seconds: e.targetDurationSeconds);
    return Column(key: Key('preview-exercise-$index'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        expanded: expanded, button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.minimum),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${index + 1}', style: context.numStyle(15, color: c.secondary, weight: FontWeight.w400))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.name, style: context.sansStyle(16, weight: FontWeight.w600)),
                    if (rx.isNotEmpty) Text(rx, style: context.numStyle(13.5, color: c.secondary, weight: FontWeight.w400)),
                  ]),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 22, color: c.secondary),
              ]),
            ),
          ),
        ),
      ),
      if (expanded)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 8, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(rxSentence(e), style: context.caption),
            // The user's own target, not a record and not the last performance.
            if (e.targetLoadKg != null) Text('Target ${formatLoad(e.targetLoadKg, unit)}', style: context.numStyle(14, color: c.secondary, weight: FontWeight.w500)),
            if ((e.notes ?? '').trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: StatusLine(Icons.sticky_note_2_outlined, e.notes!.trim())),
            Wrap(children: [
              QuietLink('About', key: Key('preview-demo-$index'), said: 'About ${e.name}', onPressed: () => showExerciseInfo(appContext(context), exercise: e, workoutName: workoutName)),
              if (slotKey != null)
                QuietLink(e.targetLoadKg == null ? 'Set a target' : 'Review target', key: Key('preview-target-$index'), said: 'Target for ${e.name}',
                    onPressed: () => showTargetReview(appContext(context), slotKey!)),
            ]),
            LastTime(history: history, status: status, unit: unit, compare: false, onAll: () => showExerciseHistory(context, name: e.name, history: history, unit: unit)),
          ]),
        ),
    ]);
  }
}
