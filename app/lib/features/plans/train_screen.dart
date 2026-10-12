import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../activity/activity_screens.dart';
import '../shell/home_shell.dart';
import '../today/daily.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import '../workout/workout_screen.dart';
import 'plan_actions.dart';
import 'plan_progress.dart';
import 'plan_screens.dart';
import 'week_widgets.dart';

/// Train: Workouts / Plan / Progress. The chosen section is kept while you visit other tabs.
class TrainScreen extends ConsumerWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(shellProvider.select((s) => s.trainView));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.fromLTRB(context.inset, 14, context.inset, 12), child: const Heading('Train')),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: context.inset),
        child: Segmented<TrainView>(
          values: TrainView.values, selected: view, keyPrefix: 'train',
          label: (v) => '${v.name[0].toUpperCase()}${v.name.substring(1)}',
          onChanged: (v) => ref.read(shellProvider.notifier).selectTrainView(v),
        ),
      ),
      Expanded(child: switch (view) { TrainView.workouts => const _WorkoutsView(), TrainView.plan => const _PlanView(), TrainView.progress => const _ProgressView() }),
    ]);
  }
}

ListView _list(BuildContext context, List<Widget> children) => ListView(padding: EdgeInsets.fromLTRB(context.inset, 18, context.inset, 28), children: children);

class _WorkoutsView extends ConsumerWidget {
  const _WorkoutsView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted) w]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    final open = all.where((w) => w.isOpen).toList(), done = all.where((w) => !w.isOpen).toList();
    final parked = ref.watch(parkedIdsProvider);
    return _list(context, [
      if (open.isNotEmpty) ...[
        const SectionHeader('Open workouts'),
        for (final w in open)
          ListRow(
            title: w.title,
            subtitle: '${parked.contains(w.id) ? 'Saved for later' : 'In progress'} · started ${shortDate(w.dayKey)}',
            trailing: TextButton(onPressed: () => resumeWorkout(context, ref, w), child: const Text('Resume')),
            onTap: () => resumeWorkout(context, ref, w),
          ),
        const SizedBox(height: 18),
      ],
      PrimaryButton('Start a manual workout', key: const Key('start-manual'), icon: Icons.add, onPressed: () => startManualWorkout(context, ref)),
      const SizedBox(height: 10),
      SecondaryButton('Start a run', icon: Icons.directions_run, onPressed: () => startRunFlow(context, ref)),
      const SizedBox(height: 28),
      const SectionHeader('Recent'),
      if (done.isEmpty) const EmptyState('No workouts recorded yet', 'When you finish a workout, what you actually did shows up here.'),
      for (final w in done.take(5)) WorkoutRow(w),
      if (done.length > 5) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => push(context, const WorkoutHistoryScreen()), child: const Text('All workout history'))),
      const SizedBox(height: 18),
      ListRow(icon: Icons.directions_run, title: 'Run history', onTap: () => push(context, const RunHistoryScreen())),
    ]);
  }
}

class _PlanView extends ConsumerStatefulWidget {
  const _PlanView();
  @override
  ConsumerState<_PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends ConsumerState<_PlanView> {
  /// Null = follow the current week; a picked week stays put while you look around.
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayKeyProvider);
    final plans = ref.watch(planListProvider);
    final primary = ref.watch(primaryPlanProvider);
    final workouts = ref.watch(workoutListProvider);
    final ctxRow = ref.watch(contextRowProvider).value;
    final others = plans.where((p) => p.id != primary?.id).toList();
    final proposals = [for (final r in ref.watch(proposalsProvider).value ?? const <Stored<Proposal>>[]) if (r.value.planId == primary?.id && (r.value.state == 'open' || r.value.state == 'needs_review')) r.value];

    return _list(context, [
      if (ctxRow?.needsReview ?? false)
        const Padding(padding: EdgeInsets.only(bottom: 14), child: StatusLine(Icons.rule, 'A plan change saved on this phone differs from your account. Review it from the notice at the bottom of the screen.', tone: Tone.warning)),
      if (primary == null) ...[
        EmptyState(
          others.any((p) => p.isDraft && !p.isArchived) ? 'Your plan is ready to review' : 'No plan yet',
          others.any((p) => p.isDraft && !p.isArchived) ? 'A saved draft does not schedule anything until you start it.' : 'Answer a few questions and review a plan before you commit to it. Manual training is always available.',
          action: PrimaryButton('Create my plan', key: const Key('create-plan'), onPressed: () => push(context, const PlanSetupScreen())),
        ),
      ] else
        ..._primary(context, primary, today, workouts, proposals),
      if (others.isNotEmpty) ...[
        const SizedBox(height: 28),
        const SectionHeader('Saved and past plans'),
        for (final p in others.where((p) => !p.isArchived))
          ListRow(
            title: p.title,
            subtitle: switch (p.lifecycle) {
              'draft' => 'Draft · not started · would start ${shortDate(p.startDate)}',
              'paused' => 'Paused · not your primary plan',
              'closed' => p.closureIntent == 'stopped_early' ? 'Stopped early' : 'Finished for now',
              _ => p.lifecycle,
            },
            onTap: () => push(context, p.isDraft ? PlanReviewScreen(planId: p.id) : PlanDetailScreen(planId: p.id)),
          ),
        if (others.any((p) => p.isArchived))
          ListRow(icon: Icons.inventory_2_outlined, title: 'Archived plans (${others.where((p) => p.isArchived).length})', onTap: () => push(context, const ArchivedPlansScreen())),
      ],
    ]);
  }

  List<Widget> _primary(BuildContext context, Plan plan, String today, List<Workout> workouts, List<Proposal> proposals) {
    final weeks = planWeeks(plan, today, workouts);
    final block = Completion.of(plan.occasions, workouts);
    final week = weeks.where((w) => w.number == _picked).firstOrNull ?? focusWeek(weeks);
    final position = planWeek(plan, today);
    return [
      PassCard(
        title: plan.title,
        // Calendar position and completion are two different facts, shown separately.
        week: position == 0 ? 'Starts ${dayMonth(plan.startDate)}' : 'Week $position of ${plan.blockWeeks}',
        count: '${block.completed} / ${block.eligible}', caption: 'Workouts completed', progress: block.fraction,
      ),
      const SizedBox(height: 10),
      Text(
        [if (position == 0) 'Not started', if (plan.isPaused) 'Paused', if (plan.endDate != null) 'Ends ${shortDate(plan.endDate!)}'].join(' · '),
        style: context.caption,
      ),
      if (plan.isPaused) ...[
        const SizedBox(height: 14),
        const StatusLine(Icons.pause_circle_outline, 'Plan paused. No new workouts are expected, and nothing counts as missed while it is paused.'),
        const SizedBox(height: 12),
        PrimaryButton('Resume plan', key: const Key('plan-resume'), onPressed: () => push(context, ResumeReviewScreen(planId: plan.id))),
      ],
      for (final p in proposals)
        ListRow(icon: Icons.tips_and_updates_outlined, title: 'Suggested change to review', subtitle: p.explanation, onTap: () => push(context, ProposalReviewScreen(proposalId: p.id))),
      if (week != null) ...[
        const SizedBox(height: 26),
        const SectionHeader('Your weeks'),
        const SizedBox(height: 10),
        WeekGrid(weeks: weeks, selected: week.number, onSelect: (n) => setState(() => _picked = n)),
        const SizedBox(height: 26),
        SectionHeader(week.isCurrent ? 'This week' : 'Week ${week.number}', detail: week.range,
            trailing: week.completion.eligible == 0 ? null : Text('${week.completion.completed} of ${week.completion.eligible} completed', style: context.sansStyle(14.5, weight: FontWeight.w600))),
        const SizedBox(height: 14),
        WeekDayStrip(week: week, plan: plan, today: today, workouts: workouts),
        const SizedBox(height: 8),
        if (week.occasions.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('No workouts are planned in this week.', style: context.caption)),
        for (final o in week.occasions) _OccasionRow(plan: plan, occasion: o, status: statusOf(o, plan, today, workouts)),
        Builder(builder: (context) {
          final busy = {for (final o in week.occasions) o.scheduledDate};
          final rest = [for (var i = 0; i < 7; i++) if (!busy.contains(addDays(week.start, i))) weekdayShort(weekdayOf(addDays(week.start, i)))];
          return rest.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 10), child: Text('Rest: ${rest.join(', ')}', style: context.caption));
        }),
      ],
      const SizedBox(height: 28),
      const SectionHeader('Manage this plan'),
      if (plan.isActive) ListRow(icon: Icons.pause, title: 'Pause plan', onTap: () => pausePlanFlow(context, ref, plan)),
      ListRow(icon: Icons.swap_horiz, title: 'Replace a movement in remaining workouts', onTap: () => push(context, SubstitutionRequestScreen(planId: plan.id))),
      ListRow(icon: Icons.flag_outlined, title: 'Review or finish this block', onTap: () => push(context, BlockReviewScreen(planId: plan.id))),
      ListRow(icon: Icons.add, title: 'Create a different plan', subtitle: 'Starting it will ask before replacing this one.', onTap: () => push(context, const PlanSetupScreen())),
    ];
  }
}

/// One dated workout of the selected week with its named state.
class _OccasionRow extends ConsumerWidget {
  const _OccasionRow({required this.plan, required this.occasion, required this.status});
  final Plan plan;
  final Occasion occasion;
  final OccasionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = occasion;
    final pill = OccasionPill(status);
    // With large text the state sits under the title instead of squeezing it.
    final below = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Column(children: [
      InkWell(
        key: Key('occasion-${o.weekNumber}-${o.ordinal}'),
        onTap: () => showOccasionSheet(context, ref, plan, o),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.navigation),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.title, style: context.sansStyle(16, weight: FontWeight.w600)),
                  Text('${shortDate(o.scheduledDate)}${o.wasMoved ? ' · originally ${shortDate(o.originalDate)}' : ''}', style: context.sansStyle(14.5, color: context.c.secondary)),
                  Text(prescriptionSummary(o.prescription), style: context.caption),
                  if (below) Padding(padding: const EdgeInsets.only(top: 6), child: pill),
                ]),
              ),
              if (!below) Padding(padding: const EdgeInsets.only(left: 10), child: pill),
              Icon(Icons.chevron_right, size: 22, color: context.c.secondary),
            ]),
          ),
        ),
      ),
      const Rule(),
    ]);
  }
}

class _ProgressView extends ConsumerWidget {
  const _ProgressView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final unit = ref.watch(loadUnitProvider);
    final primary = ref.watch(primaryPlanProvider);
    if (!p.hasEvidence && p.dueOccasions == 0) {
      return _list(context, [
        EmptyState('No training recorded yet', 'Progress is built only from workouts you actually record. There is nothing to chart until then.',
            action: SecondaryButton('Start a manual workout', onPressed: () => startManualWorkout(context, ref))),
      ]);
    }
    final most = p.weeks.fold<int>(1, (m, w) => w.$2 > m ? w.$2 : m);
    return _list(context, [
      const SectionHeader('Am I following my plan?'),
      const SizedBox(height: 8),
      if (primary == null)
        Text('You have no primary plan right now. Manual training still counts as training below.', style: context.caption)
      else if (p.dueOccasions == 0)
        Text('No planned workout has come due yet.', style: context.caption)
      else ...[
        Text('${p.recorded} of ${p.dueOccasions} due workouts recorded', style: context.sansStyle(17, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        ProgressRail(p.recorded / p.dueOccasions, label: 'Due workouts recorded'),
        const SizedBox(height: 8),
        Text('${p.full} completed · ${p.partial} partial · ${p.skipped} skipped · ${p.missed} missed', style: context.caption),
      ],
      const SizedBox(height: 28),
      const SectionHeader('Am I consistent?'),
      const SizedBox(height: 6),
      Text('Days with recorded training in each of the last 8 weeks. ${p.sessions} session${p.sessions == 1 ? '' : 's'} in total.', style: context.caption),
      const SizedBox(height: 12),
      Semantics(
        label: 'Training days per week, oldest first: ${p.weeks.map((w) => w.$2).join(', ')}',
        child: ExcludeSemantics(
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final w in p.weeks)
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${w.$2}', style: context.sansStyle(13, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Container(height: 6 + 58 * w.$2 / most, margin: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(color: w.$2 == 0 ? context.c.outline : context.c.accent, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 6),
                  FittedBox(fit: BoxFit.scaleDown, child: Text('${parseDayKey(w.$1).month}/${parseDayKey(w.$1).day}', style: context.sansStyle(12.5, color: context.c.secondary))),
                ]),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 28),
      const SectionHeader('Am I getting stronger?'),
      const SizedBox(height: 6),
      if (p.insights.isEmpty)
        Text('Not enough comparable records yet. This needs the same movement recorded in at least two sessions.', style: context.caption)
      else
        for (final i in p.insights)
          ListRow(
            title: i.name,
            subtitle: '${shortDate(i.firstDay)}: ${setText(i.first, unit)}  →  ${shortDate(i.latestDay)}: ${setText(i.latest, unit)} · ${i.sessions} sessions',
          ),
      const SizedBox(height: 10),
      Text('Best recorded set of the first and the latest session. Loads are stored in kilograms and shown in ${unit == LoadUnit.kg ? 'kilograms' : 'pounds'}.', style: context.caption),
      const SizedBox(height: 18),
      ListRow(icon: Icons.history, title: 'Workout history', onTap: () => push(context, const WorkoutHistoryScreen())),
    ]);
  }
}
