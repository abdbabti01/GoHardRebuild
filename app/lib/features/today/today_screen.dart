import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../activity/activity_screens.dart';
import '../nutrition/food_form.dart';
import '../nutrition/nutrition_surface.dart';
import '../plans/plan_actions.dart';
import '../plans/plan_progress.dart';
import '../plans/plan_screens.dart';
import '../plans/week_widgets.dart';
import '../shell/home_shell.dart';
import '../workout/result_rules.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'daily.dart';

/// Today: the date, the one training action that matters now, this week, today's food and other activity.
/// Every value comes from the signed-in owner's records. Nothing here is a sample.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(todayKeyProvider);
    final snapshot = ref.watch(dailySnapshotProvider);
    final reachable = ref.watch(connectionProvider);
    final localError = [ref.watch(plansProvider), ref.watch(workoutsProvider), ref.watch(contextRowProvider)].any((a) => a.hasError);
    final foodError = ref.watch(foodProvider(day)).hasError;
    final pad = EdgeInsets.symmetric(horizontal: context.inset);
    final due = snapshot?.training;

    return RefreshIndicator(
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.inset, 14, context.inset, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(longDate(day), style: context.sansStyle(15.5, color: context.c.secondary, weight: FontWeight.w500)),
              const Heading('Today'),
            ]),
          ),
          if (reachable == false)
            Padding(padding: pad.copyWith(bottom: 14), child: const StatusLine(Icons.cloud_off, 'Offline. Showing what is saved on this phone; your changes will sync when you are back online.', tone: Tone.warning)),

          // --- Training. A nutrition problem never hides this section, and the reverse.
          Padding(
            padding: pad,
            child: localError
                ? const Panel(child: StatusLine(Icons.error_outline, 'Your training could not be read from this phone. Pull down to try again.', tone: Tone.error))
                : snapshot == null
                    ? const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading your training…'))
                    : _TrainingSection(snapshot),
          ),
          if (snapshot != null && !localError) _WeekSection(day),
          const SizedBox(height: 28),

          // --- Nutrition: the same entries and coverage Eat shows.
          Padding(
            padding: pad,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionHeader('Nutrition',
                  trailing: TextButton(key: const Key('today-open-eat'), onPressed: () => ref.read(shellProvider.notifier).switchTab(2), child: const Text('Food journal'))),
              const SizedBox(height: 6),
              if (foodError)
                Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const StatusLine(Icons.error_outline, 'Today\'s food could not be read from this phone.', tone: Tone.error),
                  const SizedBox(height: 12),
                  SecondaryButton('Log food', icon: Icons.add, onPressed: () => openFoodForm(context, dayKey: day)),
                ]))
              else if (snapshot == null)
                const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading today\'s food…'))
              else
                NutritionSurface(
                  entries: snapshot.food,
                  coverage: snapshot.coverage,
                  calorieGoal: ref.watch(profileProvider).value?.calorieGoal,
                  proteinGoal: ref.watch(profileProvider).value?.proteinGoal,
                  onLogFood: () => openFoodForm(context, dayKey: day),
                  footer: snapshot.food.isEmpty ? null : Text('Latest: ${snapshot.food.last.name} · ${snapshot.food.last.amountDescription}', style: context.caption),
                ),
            ]),
          ),

          // --- What the due workout holds, before starting it.
          if (due is WorkoutDue) ...[
            const SizedBox(height: 28),
            Padding(
              padding: pad,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionHeader('Workout preview'),
                for (final e in due.occasion.prescription)
                  ListRow(
                    title: e.name,
                    subtitle: targetText(sets: e.targetSets, repsMin: e.targetRepsMin, repsMax: e.targetRepsMax, seconds: e.targetDurationSeconds),
                    onTap: () => showOccasionSheet(context, ref, due.plan, due.occasion),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 28),

          // --- Other activity recorded today.
          if (snapshot != null) Padding(padding: pad, child: _ActivitySection(snapshot)),
        ],
      ),
    );
  }
}

class _TrainingSection extends ConsumerWidget {
  const _TrainingSection(this.snapshot);
  final DailySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = snapshot.training;
    String nextText(Occasion? next) => next == null ? 'No further workout is scheduled in this block.' : 'Next: ${next.title} on ${longDate(next.scheduledDate)}.';
    Widget manual() => Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('today-manual'), onPressed: () => startManualWorkout(context, ref), child: const Text('Start a manual workout')));
    void openPlan() => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan);

    final (Widget feature, bool offerManual) = switch (a) {
      ResumeWorkout(:final workout) => () {
          final sets = SetProgress.of(workout, ref.watch(trustedSetsProvider));
          final n = workout.exercises.length;
          return (
            _Feature(
              photo: true, state: 'In progress', stateIcon: Icons.timelapse, title: workout.title,
              meta: '$n ${n == 1 ? 'exercise' : 'exercises'}${sets.planned == null ? '' : ' · ${sets.planned} sets'}',
              progress: sets,
              action: PrimaryButton('Resume workout', key: const Key('today-resume'), icon: Icons.play_arrow_rounded, onPressed: () => resumeWorkout(context, ref, workout)),
            ),
            false
          );
        }(),
      WorkoutDue(:final plan, :final occasion) => (
          _Feature(
            photo: true, state: 'Due today', stateIcon: Icons.today, title: occasion.title,
            // The session length is the plan's own setting, shown as an estimate only when the plan has one.
            meta: 'Week ${occasion.weekNumber} · ${prescriptionSummary(occasion.prescription)}${plan.setup?['minutesPerSession'] == null ? '' : ' · about ${plan.setup!['minutesPerSession']} min'}',
            action: PrimaryButton('Start workout', key: const Key('today-start'), icon: Icons.play_arrow_rounded, onPressed: () => startPlannedWorkout(context, ref, plan, occasion)),
            more: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white), onPressed: () => showOccasionSheet(context, ref, plan, occasion), child: const Text('View workout')),
          ),
          false
        ),
      DoneToday(:final occasion, :final outcome, :final next) => (
          _Feature(
            photo: true, state: 'Done for today', stateIcon: Icons.check_circle, title: occasion.title,
            body: '${outcome == WorkoutResultRules.full ? 'Finished: all planned sets recorded.' : 'Finished partially: some planned work was not recorded.'} ${nextText(next)}',
            action: PrimaryButton('View plan', onPressed: openPlan),
          ),
          false
        ),
      PlanPausedAction(:final plan) => (
          _Feature(state: 'Plan paused', stateIcon: Icons.pause_circle_outline, title: plan.title, body: 'No workouts are expected while the plan is paused, and nothing counts as missed.',
              action: PrimaryButton('Resume plan', onPressed: () => push(context, ResumeReviewScreen(planId: plan.id)))),
          true
        ),
      StartsLater(:final plan, :final first) => (
          _Feature(state: 'Starts ${shortDate(plan.startDate)}', stateIcon: Icons.event, title: first.title, body: 'Your first workout is on ${longDate(first.scheduledDate)}. Nothing is due before then.',
              action: SecondaryButton('View plan', onPressed: openPlan)),
          true
        ),
      BlockReviewDue(:final plan) => (
          _Feature(state: 'Block ready to review', stateIcon: Icons.flag_outlined, title: plan.title,
              body: 'This block has reached its end or has nothing left to do. Review what was actually recorded and choose what comes next.',
              action: PrimaryButton('Review this block', key: const Key('today-block-review'), onPressed: () => push(context, BlockReviewScreen(planId: plan.id)))),
          true
        ),
      RecoveryDay(:final next, :final missed) => (
          _Feature(state: 'Recovery day', stateIcon: Icons.spa_outlined, title: 'Rest today',
              body: '${nextText(next)}${missed.isEmpty ? '' : ' ${missed.length} earlier workout${missed.length == 1 ? ' is' : 's are'} unresolved; move or skip ${missed.length == 1 ? 'it' : 'them'} when you choose.'}',
              action: missed.isEmpty ? SecondaryButton('View plan', onPressed: openPlan) : SecondaryButton('Resolve missed training', key: const Key('today-missed'), onPressed: openPlan)),
          true
        ),
      ReviewDraft(:final draft) => (
          _Feature(state: 'Your plan is ready to review', stateIcon: Icons.fact_check_outlined, title: draft.title, body: 'This draft has not started. Nothing is scheduled until you start it.',
              action: PrimaryButton('Review your plan', key: const Key('today-review-draft'), onPressed: () => push(context, PlanReviewScreen(planId: draft.id)))),
          true
        ),
      CreatePlan() => (
          _Feature(state: 'Your training', stateIcon: Icons.fitness_center, title: 'No plan yet', body: 'Answer a few questions and review a plan before you commit, or just train manually today.',
              action: PrimaryButton('Create my plan', key: const Key('today-create-plan'), onPressed: () => push(context, const PlanSetupScreen()))),
          true
        ),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      feature,
      if (offerManual) manual(),
      // Workouts saved for later stay recoverable without taking over the day.
      for (final w in snapshot.parked)
        Padding(padding: const EdgeInsets.only(top: 6), child: ListRow(icon: Icons.bookmark_outline, title: w.title, subtitle: 'Saved for later · started ${shortDate(w.dayKey)}', divider: false, onTap: () => resumeWorkout(context, ref, w))),
    ]);
  }
}

/// The day's training feature. A workout gets the photograph; rest days, paused plans and empty states get a
/// calm card, so a picture of training never sits above "rest today".
class _Feature extends StatelessWidget {
  const _Feature({required this.state, required this.stateIcon, required this.title, this.meta, this.body, this.progress, required this.action, this.more, this.photo = false});
  final String state, title;
  final IconData stateIcon;
  final String? meta, body;
  final SetProgress? progress;
  final Widget action;
  final Widget? more;
  final bool photo;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = photo ? Colors.white : c.text, soft = photo ? const Color(0xE6FFFFFF) : c.secondary;
    final p = progress;
    final content = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // The state is a filled accent label on the photograph, a quiet pill on a plain card.
        if (photo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(stateIcon, size: 16, color: c.onAccent),
              const SizedBox(width: 6),
              Flexible(child: Text(state, style: context.sansStyle(13.5, color: c.onAccent, weight: FontWeight.w700))),
            ]),
          )
        else
          StatusPill(state, icon: stateIcon, tone: Tone.accent),
        SizedBox(height: photo ? 84 : 14),
        Semantics(header: true, child: Text(title, style: context.titleStyle(28, color: fg))),
        if (meta != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(meta!, style: context.sansStyle(15.5, color: soft))),
        if (body != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(body!, style: context.sansStyle(15.5, color: soft))),
        if (p != null) ...[
          const SizedBox(height: 14),
          if (p.planned == null)
            Text('${p.recorded} ${p.recorded == 1 ? 'set' : 'sets'} recorded', style: context.sansStyle(15.5, color: fg, weight: FontWeight.w600))
          else ...[
            Row(children: [
              Expanded(child: Text('${p.counted} of ${p.planned} sets recorded', style: context.sansStyle(15.5, color: fg, weight: FontWeight.w600))),
              Text('${(p.fraction * 100).round()}%', style: context.sansStyle(15.5, color: fg, weight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            ProgressRail(p.fraction, label: 'Planned sets recorded', color: photo ? c.passFill : null, track: photo ? const Color(0x47FFFFFF) : null),
          ],
        ],
        const SizedBox(height: 18),
        action,
        if (more != null) Center(child: more),
      ]),
    );
    if (!photo) return Panel(padding: EdgeInsets.zero, child: content);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.hero),
      child: Stack(children: [
        // Decorative: hidden from assistive technology. Decoded at display size, not at the file's full size.
        Positioned.fill(
          child: ExcludeSemantics(
            child: Image.asset('assets/images/evening-gym-hero.jpg', fit: BoxFit.cover, alignment: const Alignment(-0.5, -1), cacheWidth: 1200,
                errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1C1F24))),
          ),
        ),
        // A solid dark floor under the text: white text keeps its contrast wherever the photograph is bright.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.2, 0.42, 1], colors: [Color(0x73000000), Color(0x4D000000), Color(0xD1000000), Color(0xF2000000)])),
          ),
        ),
        content,
      ]),
    );
  }
}

/// This week of the plan: real completion, and what each day holds.
class _WeekSection extends ConsumerWidget {
  const _WeekSection(this.today);
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(primaryPlanProvider);
    final workouts = ref.watch(workoutListProvider);
    final week = plan == null ? null : planWeeks(plan, today, workouts).where((w) => w.isCurrent).firstOrNull;
    if (plan == null || week == null) return const SizedBox.shrink();
    final done = week.completion;
    return Padding(
      padding: EdgeInsets.fromLTRB(context.inset, 28, context.inset, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader('Your week', detail: week.range),
        const SizedBox(height: 10),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (done.eligible == 0)
              Text('No workouts planned this week', style: context.sansStyle(16, weight: FontWeight.w600))
            else ...[
              Row(children: [
                Expanded(child: Text('${done.completed} of ${done.eligible} workouts complete', style: context.sansStyle(16, weight: FontWeight.w600))),
                Text('${(done.fraction * 100).round()}%', style: context.sansStyle(15, color: context.c.secondary, weight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              ProgressRail(done.fraction, label: 'Workouts complete this week'),
            ],
            const SizedBox(height: 16),
            WeekDayStrip(week: week, plan: plan, today: today, workouts: workouts),
          ]),
        ),
      ]),
    );
  }
}

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection(this.snapshot);
  final DailySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Today\'s activity'),
        const SizedBox(height: 4),
        if (snapshot.finishedToday.isEmpty && snapshot.runs.isEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('No other activity recorded today.', style: context.caption)),
        for (final w in snapshot.finishedToday)
          ListRow(
            title: w.title,
            subtitle: '${w.isManual ? 'Manual workout' : 'Planned workout'} · ${WorkoutResultRules.label(w.outcome)}${w.performedSets > 0 ? ' · ${w.performedSets} set${w.performedSets == 1 ? '' : 's'}' : ''}',
            onTap: () => push(context, WorkoutDetailScreen(workoutId: w.id)),
          ),
        for (final r in snapshot.runs)
          ListRow(
            icon: Icons.directions_run, title: r.isOpen ? 'Run in progress' : 'Run',
            subtitle: r.isOpen ? 'Tap to continue' : '${durationText(r.activeDurationSeconds ?? 0)}${r.distanceMeters == null ? '' : ' · ${(r.distanceMeters! / 1000).toStringAsFixed(2)} km'}',
            onTap: r.isOpen ? () => push(context, RunScreen(runId: r.id)) : null,
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 4, children: [
          TextButton.icon(key: const Key('today-run'), onPressed: () => startRunFlow(context, ref), icon: const Icon(Icons.directions_run, size: 20), label: const Text('Start a run')),
          TextButton.icon(onPressed: () => push(context, const BodyMetricsScreen()), icon: const Icon(Icons.monitor_weight_outlined, size: 20), label: const Text('Body measurements')),
        ]),
      ]);
}
