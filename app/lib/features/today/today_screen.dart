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
import '../plans/plan_screens.dart';
import '../shell/home_shell.dart';
import '../workout/result_rules.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'daily.dart';

/// Today: the one training action that matters now, today's food, and today's other activity.
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

    return RefreshIndicator(
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.inset, 14, context.inset - 8, 0),
            child: Row(children: [
              const GhMark(),
              const Spacer(),
              IconButton(key: const Key('today-profile'), tooltip: 'Me', icon: const Icon(Icons.person_outline), onPressed: () => ref.read(shellProvider.notifier).switchTab(3)),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(context.inset, 10, context.inset, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(longDate(day), style: context.sansStyle(14, color: context.ec.secondary)),
              const Serif('Today', size: 47),
            ]),
          ),
          // Decorative brand photograph: not recorded activity, and hidden from assistive technology.
          ExcludeSemantics(child: AspectRatio(aspectRatio: 390 / 182, child: Image.asset('assets/images/evening-gym-hero.jpg', fit: BoxFit.cover))),
          const SizedBox(height: 22),
          if (reachable == false)
            Padding(padding: pad.copyWith(bottom: 14), child: const StatusLine(Icons.cloud_off, 'Offline. Showing what is saved on this phone; your changes will sync when you are back online.', tone: Tone.warning)),

          // --- Training. A nutrition problem never hides this section, and the reverse.
          Padding(
            padding: pad,
            child: localError
                ? const StatusLine(Icons.error_outline, 'Your training could not be read from this phone. Pull down to try again.', tone: Tone.error)
                : snapshot == null
                    ? const StatusLine(Icons.hourglass_empty, 'Loading your training…')
                    : _TrainingSection(snapshot),
          ),
          const SizedBox(height: 26),

          // --- Nutrition: the same entries and coverage Eat shows.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.inset - 6),
            child: foodError
                ? Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const StatusLine(Icons.error_outline, 'Today\'s food could not be read from this phone.', tone: Tone.error),
                    const SizedBox(height: 10),
                    SecondaryButton('Log food', onPressed: () => openFoodForm(context, dayKey: day)),
                  ]))
                : snapshot == null
                    ? const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading today\'s food…'))
                    : NutritionSurface(
                        entries: snapshot.food,
                        coverage: snapshot.coverage,
                        onLogFood: () => openFoodForm(context, dayKey: day),
                        footer: snapshot.food.isEmpty
                            ? null
                            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Latest: ${snapshot.food.last.name} · ${snapshot.food.last.amountDescription}', style: context.sansStyle(13, color: context.ec.nutritionSecondary)),
                                TextButton(
                                  style: TextButton.styleFrom(foregroundColor: context.ec.nutritionText, padding: EdgeInsets.zero),
                                  onPressed: () => ref.read(shellProvider.notifier).switchTab(2),
                                  child: const Text('Open food journal'),
                                ),
                              ]),
                      ),
          ),
          const SizedBox(height: 26),

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
    final sets = ref.watch(trustedSetsProvider);
    Widget block(String label, String title, String body, {Widget? action, List<Widget> more = const []}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionLabel(label),
          const SizedBox(height: 8),
          Serif(title, size: 39),
          const SizedBox(height: 8),
          Text(body, style: context.sansStyle(15, color: context.ec.secondary)),
          if (action != null) ...[const SizedBox(height: 16), action],
          ...more,
        ]);
    String nextText(Occasion? next) => next == null ? 'No further workout is scheduled in this block.' : 'Next: ${next.title} on ${longDate(next.scheduledDate)}.';
    Widget manual() => Padding(padding: const EdgeInsets.only(top: 4), child: TextButton(key: const Key('today-manual'), onPressed: () => startManualWorkout(context, ref), child: const Text('Start a manual workout')));
    void openPlan() => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan);

    final main = switch (a) {
      ResumeWorkout(:final workout) => block(
          'Your training', workout.title,
          switch (sets.where((s) => s.workoutId == workout.id).length) { 0 => 'This workout is open. Nothing has been recorded in it yet.', 1 => 'Your 1 recorded set is waiting for you.', final n => 'Your $n recorded sets are waiting for you.' },
          action: PrimaryButton('Resume workout', key: const Key('today-resume'), onPressed: () => resumeWorkout(context, ref, workout))),
      PlanPausedAction(:final plan) => block('Plan paused', plan.title, 'No workouts are expected while the plan is paused, and nothing counts as missed.',
          action: PrimaryButton('Resume plan', onPressed: () => push(context, ResumeReviewScreen(planId: plan.id))), more: [manual()]),
      StartsLater(:final plan, :final first) => block('Starts ${shortDate(plan.startDate)}', first.title, 'Your first workout is on ${longDate(first.scheduledDate)}. Nothing is due before then.',
          action: SecondaryButton('View plan', onPressed: openPlan), more: [manual()]),
      BlockReviewDue(:final plan) => block('Block ready to review', plan.title, 'This block has reached its end or has nothing left to do. Review what was actually recorded and choose what comes next.',
          action: PrimaryButton('Review this block', key: const Key('today-block-review'), onPressed: () => push(context, BlockReviewScreen(planId: plan.id))), more: [manual()]),
      WorkoutDue(:final plan, :final occasion) => block(
          'Your training · week ${occasion.weekNumber}', occasion.title,
          '${occasion.prescription.take(3).map((e) => e.name).join(', ')}${occasion.prescription.length > 3 ? ' and ${occasion.prescription.length - 3} more' : ''}.',
          action: PrimaryButton('Start workout', key: const Key('today-start'), onPressed: () => startPlannedWorkout(context, ref, plan, occasion)),
          more: [Padding(padding: const EdgeInsets.only(top: 4), child: TextButton(onPressed: () => showOccasionSheet(context, ref, plan, occasion), child: const Text('View workout')))]),
      DoneToday(:final occasion, :final outcome, :final next) => block('Done for today', occasion.title,
          '${outcome == WorkoutResultRules.full ? 'Finished: all planned sets recorded.' : 'Finished partially: some planned work was not recorded.'} ${nextText(next)}',
          action: SecondaryButton('View plan', onPressed: openPlan)),
      RecoveryDay(:final next, :final missed) => block('Recovery day', 'Rest today', '${nextText(next)}${missed.isEmpty ? '' : ' ${missed.length} earlier workout${missed.length == 1 ? ' is' : 's are'} unresolved; move or skip ${missed.length == 1 ? 'it' : 'them'} when you choose.'}',
          action: missed.isEmpty ? null : SecondaryButton('Resolve missed training', key: const Key('today-missed'), onPressed: openPlan), more: [manual()]),
      ReviewDraft(:final draft) => block('Your plan is ready to review', draft.title, 'This draft has not started. Nothing is scheduled until you start it.',
          action: PrimaryButton('Review your plan', key: const Key('today-review-draft'), onPressed: () => push(context, PlanReviewScreen(planId: draft.id))), more: [manual()]),
      CreatePlan() => block('Your training', 'No plan yet', 'Answer a few questions and review a plan before you commit, or just train manually today.',
          action: PrimaryButton('Create my plan', key: const Key('today-create-plan'), onPressed: () => push(context, const PlanSetupScreen())), more: [manual()]),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      main,
      // Workouts saved for later stay recoverable without taking over the day.
      for (final w in snapshot.parked)
        Padding(padding: const EdgeInsets.only(top: 10), child: ListRow(icon: Icons.bookmark_outline, title: w.title, subtitle: 'Saved for later · started ${shortDate(w.dayKey)}', divider: false, onTap: () => resumeWorkout(context, ref, w))),
    ]);
  }
}

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection(this.snapshot);
  final DailySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Serif('Today\'s activity', size: 27),
        const SizedBox(height: 6),
        if (snapshot.finishedToday.isEmpty && snapshot.runs.isEmpty) Text('No other activity recorded today.', style: context.caption),
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
          TextButton.icon(key: const Key('today-run'), onPressed: () => startRunFlow(context, ref), icon: const Icon(Icons.directions_run, size: 18), label: const Text('Start a run')),
          TextButton.icon(onPressed: () => push(context, const BodyMetricsScreen()), icon: const Icon(Icons.monitor_weight_outlined, size: 18), label: const Text('Body measurements')),
        ]),
      ]);
}
