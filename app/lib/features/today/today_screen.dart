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
import '../shell/home_shell.dart';
import '../workout/result_rules.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'daily.dart';

/// Today: the date, the one training action that matters now, today's food at a glance and what was recorded.
/// The week and its calendar live in Train › Plan; the full food breakdown lives in Eat.
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
    final foods = snapshot?.food.length ?? 0;
    void openEat() => ref.read(shellProvider.notifier).switchTab(2);

    return RefreshIndicator(
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.inset, 14, context.inset, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(longDate(day), style: context.sansStyle(15.5, color: context.c.secondary, weight: FontWeight.w500)),
              const Heading('Today'),
            ]),
          ),
          if (reachable == false) Padding(padding: pad.copyWith(bottom: 8), child: const _ConnectionStatus()),

          // --- Training. A nutrition problem never hides this section, and the reverse.
          Padding(
            padding: pad,
            child: localError
                ? const Panel(child: StatusLine(Icons.error_outline, 'Your training could not be read from this phone. Pull down to try again.', tone: Tone.error))
                : snapshot == null
                    ? const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading your training…'))
                    : _TrainingSection(snapshot),
          ),
          const SizedBox(height: 4),

          // --- Nutrition at a glance: the same entries and coverage Eat shows in full.
          Padding(
            padding: pad,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionHeader('Nutrition',
                  detail: foods == 0 ? null : '$foods ${foods == 1 ? 'food' : 'foods'} logged',
                  trailing: TextButton(key: const Key('today-open-eat'), onPressed: openEat, child: const Text('Food journal'))),
              if (foodError)
                Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const StatusLine(Icons.error_outline, 'Today\'s food could not be read from this phone.', tone: Tone.error),
                  const SizedBox(height: 12),
                  SecondaryButton('Log food', icon: Icons.add, onPressed: () => openFoodForm(context, dayKey: day)),
                ]))
              else if (snapshot == null)
                const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading today\'s food…'))
              else
                NutritionSummary(
                  entries: snapshot.food,
                  coverage: snapshot.coverage,
                  calorieGoal: ref.watch(profileProvider).value?.calorieGoal,
                  proteinGoal: ref.watch(profileProvider).value?.proteinGoal,
                  onLogFood: () => openFoodForm(context, dayKey: day),
                  onDetails: openEat,
                ),
            ]),
          ),

          // --- What was actually recorded today. Absent when there is nothing to show.
          if (snapshot != null && (snapshot.finishedToday.isNotEmpty || snapshot.runs.any((r) => !r.isOpen))) Padding(padding: pad.copyWith(top: 24), child: _ActivitySection(snapshot)),
        ],
      ),
    );
  }
}

/// The account could not be reached on the last attempt: one quiet line, with the explanation a tap away.
/// Changes that need a decision (conflicts, refusals) keep their own notice above the navigation bar.
class _ConnectionStatus extends ConsumerStatefulWidget {
  const _ConnectionStatus();
  @override
  ConsumerState<_ConnectionStatus> createState() => _ConnectionStatusState();
}

class _ConnectionStatusState extends ConsumerState<_ConnectionStatus> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        button: true, expanded: _open,
        child: InkWell(
          key: const Key('today-connection'),
          borderRadius: BorderRadius.circular(Radii.tile),
          onTap: () => setState(() => _open = !_open),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.minimum),
            child: Row(children: [
              Expanded(
                child: StatusLine(Icons.cloud_off, '$cantSyncLabel${pending == 0 ? '' : ' · ${waitingToSync(pending)}'}', tone: Tone.warning),
              ),
              Icon(_open ? Icons.expand_less : Icons.expand_more, size: 22, color: c.secondary),
            ]),
          ),
        ),
      ),
      if (_open) ...[
        Text(
            '$cantSyncDetail You are seeing what is saved on this phone. ${pending == 0 ? 'Nothing is waiting to sync.' : 'Your changes are kept here and sync by themselves once the account answers.'}',
            style: context.caption),
        Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('today-connection-retry'), onPressed: () => refreshFromAccount(ref), child: const Text('Try again'))),
      ],
    ]);
  }
}

/// "Bench press · Row · Squat +2 more": enough to recognise the session; the sheet behind the title has the rest.
String? _movements(Iterable<String> names) {
  final all = names.toList();
  if (all.isEmpty) return null;
  return all.length <= 3 ? all.join(' · ') : '${all.take(3).join(' · ')} +${all.length - 3} more';
}

class _TrainingSection extends ConsumerWidget {
  const _TrainingSection(this.snapshot);
  final DailySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = snapshot.training;
    String nextText(Occasion? next) => next == null ? 'No further workout is scheduled in this block.' : 'Next: ${next.title} on ${longDate(next.scheduledDate)}.';
    void openPlan() => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan);

    final (Widget feature, bool offerManual) = switch (a) {
      ResumeWorkout(:final workout) => () {
          final sets = SetProgress.of(workout, ref.watch(trustedSetsProvider));
          final n = workout.exercises.length;
          // A planned workout opens its plan entry; a manual one has nothing more to show than the workout itself.
          final plan = ref.watch(planListProvider).where((p) => p.id == workout.planId).firstOrNull;
          final occasion = plan?.occasions.where((o) => o.id == workout.occasionId).firstOrNull;
          return (
            _Feature(
              photo: true, state: 'In progress', stateIcon: Icons.timelapse, title: workout.title,
              meta: '$n ${n == 1 ? 'exercise' : 'exercises'}${sets.planned == null ? '' : ' · ${sets.planned} sets'}',
              summary: _movements(workout.exercises.map((e) => e.name)),
              progress: sets,
              onDetails: occasion == null ? null : () => showOccasionSheet(context, ref, plan!, occasion),
              action: PrimaryButton('Resume workout', key: const Key('today-resume'), icon: Icons.play_arrow_rounded, onPressed: () => resumeWorkout(context, ref, workout)),
            ),
            false
          );
        }(),
      WorkoutDue(:final plan, :final occasion) => (
          _Feature(
            photo: true, state: 'Due today', stateIcon: Icons.today, title: occasion.title,
            // The minutes are the session length chosen when the plan was set up. They are not worked out from
            // the exercises, so they are labelled as planned time and never as an estimate.
            meta: 'Week ${occasion.weekNumber} · ${prescriptionSummary(occasion.prescription)}${plan.setup?['minutesPerSession'] == null ? '' : ' · ${plan.setup!['minutesPerSession']} min planned'}',
            summary: _movements(occasion.prescription.map((e) => e.name)),
            onDetails: () => showOccasionSheet(context, ref, plan, occasion),
            action: PrimaryButton('Start workout', key: const Key('today-start'), icon: Icons.play_arrow_rounded, onPressed: () => startPlannedWorkout(context, ref, plan, occasion)),
          ),
          false
        ),
      DoneToday(:final plan, :final occasion, :final outcome, :final next) => (
          _Feature(
            photo: true, state: 'Done for today', stateIcon: Icons.check_circle, title: occasion.title,
            body: '${outcome == WorkoutResultRules.full ? 'Finished: all planned sets recorded.' : 'Finished partially: some planned work was not recorded.'} ${nextText(next)}',
            onDetails: () => showOccasionSheet(context, ref, plan, occasion),
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
    // Any open run, whatever day it began: it is read from the saved records, so it is still here after a restart.
    final runOpen = (ref.watch(runsProvider).value ?? const <Stored<Run>>[]).any((r) => r.value.isOpen);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      feature,
      const SizedBox(height: 10),
      // Today's one way into running, on every kind of day. An open run is continued, never started twice.
      Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SecondaryButton(runOpen ? 'Continue your run' : 'Start run', key: const Key('today-run'), icon: Icons.directions_run, expand: false, onPressed: () => startRunFlow(context, ref)),
        if (offerManual) TextButton(key: const Key('today-manual'), onPressed: () => startManualWorkout(context, ref), child: const Text('Start a manual workout')),
      ]),
      // Workouts saved for later stay recoverable without taking over the day.
      for (final w in snapshot.parked)
        ListRow(icon: Icons.bookmark_outline, title: w.title, subtitle: 'Saved for later · started ${shortDate(w.dayKey)}', divider: false, onTap: () => resumeWorkout(context, ref, w)),
    ]);
  }
}

/// The day's training feature, kept short enough that food sits under it on the first screen. A workout gets
/// the photograph; rest days, paused plans and empty states get a calm card, so a picture of training never
/// sits above "rest today". The title opens the details when there are any; the button is the one main action.
class _Feature extends StatelessWidget {
  const _Feature({required this.state, required this.stateIcon, required this.title, this.meta, this.summary, this.body, this.progress, required this.action, this.onDetails, this.photo = false});
  final String state, title;
  final IconData stateIcon;
  final String? meta, summary, body;
  final SetProgress? progress;
  final Widget action;
  final VoidCallback? onDetails;
  final bool photo;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = photo ? Colors.white : c.text, soft = photo ? const Color(0xE6FFFFFF) : c.secondary;
    final p = progress;
    final heading = Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(title, style: context.titleStyle(24, color: fg))),
          if (meta != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(meta!, style: context.sansStyle(15, color: soft))),
          if (summary != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(summary!, style: context.sansStyle(14, color: soft))),
        ]),
      ),
      if (onDetails != null) Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.chevron_right, size: 26, color: soft)),
    ]);
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // The state is a filled accent label on the photograph, a quiet pill on a plain card.
        if (photo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(stateIcon, size: 16, color: c.onAccent),
              const SizedBox(width: 6),
              Flexible(child: Text(state, style: context.sansStyle(13.5, color: c.onAccent, weight: FontWeight.w700))),
            ]),
          )
        else
          StatusPill(state, icon: stateIcon, tone: Tone.accent),
        SizedBox(height: photo ? 22 : 10),
        if (onDetails == null)
          heading
        else
          Semantics(
            button: true, hint: 'Shows the workout details',
            child: InkWell(
              key: const Key('today-details'),
              onTap: onDetails,
              child: ConstrainedBox(constraints: const BoxConstraints(minHeight: Targets.minimum), child: heading),
            ),
          ),
        if (body != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(body!, style: context.sansStyle(15, color: soft))),
        if (p != null) ...[
          const SizedBox(height: 10),
          if (p.planned == null)
            Text('${p.recorded} ${p.recorded == 1 ? 'set' : 'sets'} recorded', style: context.sansStyle(15, color: fg, weight: FontWeight.w600))
          else ...[
            Row(children: [
              Expanded(child: Text('${p.counted} of ${p.planned} sets recorded', style: context.sansStyle(15, color: fg, weight: FontWeight.w600))),
              Text('${(p.fraction * 100).round()}%', style: context.sansStyle(15, color: fg, weight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            ProgressRail(p.fraction, label: 'Planned sets recorded', color: photo ? c.passFill : null, track: photo ? const Color(0x47FFFFFF) : null, height: 6),
          ],
        ],
        const SizedBox(height: 14),
        action,
      ]),
    );
    if (!photo) return Panel(padding: EdgeInsets.zero, child: content);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.hero),
      child: Stack(children: [
        // Decorative: hidden from assistive technology. Decoded at display size, not at the file's full size.
        Positioned.fill(
          child: ExcludeSemantics(
            child: Image.asset('assets/images/evening-gym-hero.jpg', fit: BoxFit.cover, alignment: const Alignment(-0.5, -0.6), cacheWidth: 1200,
                errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1C1F24))),
          ),
        ),
        // A solid dark floor under the text: white text keeps its contrast wherever the photograph is bright.
        // The photograph shows through the band beside the state label; the text starts below it.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.2, 1], colors: [Color(0x73000000), Color(0xD1000000), Color(0xF2000000)])),
          ),
        ),
        Material(type: MaterialType.transparency, child: content),
      ]),
    );
  }
}

/// What was recorded today, in its own words: a manual workout is "Recorded", never a completed plan day.
class _ActivitySection extends ConsumerWidget {
  const _ActivitySection(this.snapshot);
  final DailySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Recorded today'),
        for (final w in snapshot.finishedToday)
          ListRow(
            title: w.title,
            subtitle: '${w.isManual ? 'Manual workout' : 'Planned workout'} · ${WorkoutResultRules.label(w.outcome)}${w.performedSets > 0 ? ' · ${w.performedSets} set${w.performedSets == 1 ? '' : 's'}' : ''}',
            onTap: () => push(context, WorkoutDetailScreen(workoutId: w.id)),
          ),
        // Finished runs only. A run still going is not recorded yet, and the button above is its one way back in.
        for (final r in snapshot.runs)
          if (!r.isOpen)
            ListRow(
              icon: Icons.directions_run, title: 'Run',
              subtitle: '${durationText(r.activeDurationSeconds ?? 0)}${r.distanceMeters == null ? '' : ' · ${(r.distanceMeters! / 1000).toStringAsFixed(2)} km'}',
            ),
      ]);
}
