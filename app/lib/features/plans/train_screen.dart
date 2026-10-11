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
import 'plan_screens.dart';

/// Train: Workouts / Plan / Progress. The chosen section is kept while you visit other tabs.
class TrainScreen extends ConsumerWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(shellProvider.select((s) => s.trainView));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.fromLTRB(context.inset, 12, context.inset, 10), child: const Serif('Train')),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: context.inset),
        child: Row(children: [
          for (final v in TrainView.values)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: v == TrainView.values.last ? 0 : 8),
                child: Semantics(
                  selected: v == view, button: true,
                  child: OutlinedButton(
                    key: Key('train-${v.name}'),
                    style: OutlinedButton.styleFrom(
                        backgroundColor: v == view ? context.ec.selected : null, side: BorderSide(color: v == view ? context.ec.text : context.ec.divider),
                        padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, Targets.minimum),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.week))),
                    onPressed: () => ref.read(shellProvider.notifier).selectTrainView(v),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text('${v.name[0].toUpperCase()}${v.name.substring(1)}', style: TextStyle(fontWeight: v == view ? FontWeight.w700 : FontWeight.w400))),
                  ),
                ),
              ),
            ),
        ]),
      ),
      Expanded(child: switch (view) { TrainView.workouts => const _WorkoutsView(), TrainView.plan => const _PlanView(), TrainView.progress => const _ProgressView() }),
    ]);
  }
}

ListView _list(BuildContext context, WidgetRef ref, List<Widget> children) => ListView(padding: EdgeInsets.fromLTRB(context.inset, 18, context.inset, 28), children: children);

class _WorkoutsView extends ConsumerWidget {
  const _WorkoutsView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted) w]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    final open = all.where((w) => w.isOpen).toList(), done = all.where((w) => !w.isOpen).toList();
    final parked = ref.watch(parkedIdsProvider);
    return _list(context, ref, [
      if (open.isNotEmpty) ...[
        const SectionLabel('Open workouts'),
        for (final w in open)
          ListRow(
            title: w.title,
            subtitle: '${parked.contains(w.id) ? 'Saved for later' : 'In progress'} · started ${shortDate(w.dayKey)}',
            trailing: TextButton(onPressed: () => resumeWorkout(context, ref, w), child: const Text('Resume')),
            onTap: () => resumeWorkout(context, ref, w),
          ),
        const SizedBox(height: 18),
      ],
      PrimaryButton('Start a manual workout', key: const Key('start-manual'), onPressed: () => startManualWorkout(context, ref)),
      const SizedBox(height: 8),
      SecondaryButton('Start a run', icon: Icons.directions_run, onPressed: () => startRunFlow(context, ref)),
      const SizedBox(height: 26),
      const SectionLabel('Recent'),
      if (done.isEmpty) const EmptyState('No workouts recorded yet', 'When you finish a workout, what you actually did shows up here.'),
      for (final w in done.take(5)) WorkoutRow(w),
      if (done.length > 5) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => push(context, const WorkoutHistoryScreen()), child: const Text('All workout history'))),
      const SizedBox(height: 18),
      ListRow(icon: Icons.directions_run, title: 'Run history', onTap: () => push(context, const RunHistoryScreen())),
    ]);
  }
}

class _PlanView extends ConsumerWidget {
  const _PlanView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayKeyProvider);
    final plans = ref.watch(planListProvider);
    final primary = ref.watch(primaryPlanProvider);
    final workouts = ref.watch(workoutListProvider);
    final ctxRow = ref.watch(contextRowProvider).value;
    final others = plans.where((p) => p.id != primary?.id).toList();
    final proposals = [for (final r in ref.watch(proposalsProvider).value ?? const <Stored<Proposal>>[]) if (r.value.planId == primary?.id && (r.value.state == 'open' || r.value.state == 'needs_review')) r.value];

    return _list(context, ref, [
      if (ctxRow?.needsReview ?? false)
        const Padding(padding: EdgeInsets.only(bottom: 14), child: StatusLine(Icons.rule, 'A plan change saved on this phone differs from your account. Review it from the notice at the bottom of the screen.', tone: Tone.warning)),
      if (primary == null) ...[
        EmptyState(
          others.any((p) => p.isDraft && !p.isArchived) ? 'Your plan is ready to review' : 'No plan yet',
          others.any((p) => p.isDraft && !p.isArchived) ? 'A saved draft does not schedule anything until you start it.' : 'Answer a few questions and review a plan before you commit to it. Manual training is always available.',
          action: PrimaryButton('Create my plan', key: const Key('create-plan'), onPressed: () => push(context, const PlanSetupScreen())),
        ),
      ] else ...[
        SectionLabel('Primary plan${primary.isPaused ? ' · paused' : today.compareTo(primary.startDate) < 0 ? ' · starts ${shortDate(primary.startDate)}' : ''}'),
        const SizedBox(height: 6),
        Serif(primary.title, size: 30),
        const SizedBox(height: 4),
        Text(
          '${planWeek(primary, today) == 0 ? 'Not started' : 'Plan week ${planWeek(primary, today)} of ${primary.blockWeeks}'}'
          '${primary.endDate == null ? '' : ' · ends ${shortDate(primary.endDate!)}'}',
          style: context.caption,
        ),
        const SizedBox(height: 14),
        _WeekStrip(plan: primary, today: today),
        const SizedBox(height: 14),
        if (primary.isPaused) ...[
          const StatusLine(Icons.pause_circle_outline, 'Plan paused. No new workouts are expected, and nothing counts as missed while it is paused.'),
          const SizedBox(height: 10),
          PrimaryButton('Resume plan', key: const Key('plan-resume'), onPressed: () => push(context, ResumeReviewScreen(planId: primary.id))),
        ],
        for (final p in proposals)
          ListRow(icon: Icons.tips_and_updates_outlined, title: 'Suggested change to review', subtitle: p.explanation, onTap: () => push(context, ProposalReviewScreen(proposalId: p.id))),
        for (final week in {for (final o in primary.occasions) o.weekNumber}) ...[
          const SizedBox(height: 18),
          SectionLabel('Week $week'),
          for (final o in primary.occasions.where((o) => o.weekNumber == week))
            ListRow(
              key: Key('occasion-${o.weekNumber}-${o.ordinal}'),
              title: o.title,
              subtitle: '${shortDate(o.scheduledDate)}${o.wasMoved ? ' · originally ${shortDate(o.originalDate)}' : ''} · ${statusOf(o, primary, today, workouts).label}',
              onTap: () => showOccasionSheet(context, ref, primary, o),
            ),
        ],
        const SizedBox(height: 22),
        const SectionLabel('Manage this plan'),
        if (primary.isActive) ListRow(icon: Icons.pause, title: 'Pause plan', onTap: () => pausePlanFlow(context, ref, primary)),
        ListRow(icon: Icons.swap_horiz, title: 'Replace a movement in remaining workouts', onTap: () => push(context, SubstitutionRequestScreen(planId: primary.id))),
        ListRow(icon: Icons.flag_outlined, title: 'Review or finish this block', onTap: () => push(context, BlockReviewScreen(planId: primary.id))),
        ListRow(icon: Icons.add, title: 'Create a different plan', subtitle: 'Starting it will ask before replacing this one.', onTap: () => push(context, const PlanSetupScreen())),
      ],
      if (others.isNotEmpty) ...[
        const SizedBox(height: 26),
        const SectionLabel('Saved and past plans'),
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
}

/// The current local week, Monday to Sunday, with real dates. Today is marked with text semantics.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.plan, required this.today});
  final Plan plan;
  final String today;

  @override
  Widget build(BuildContext context) {
    final monday = addDays(today, 1 - weekdayOf(today));
    final training = {for (final o in plan.occasions) if (!o.isSkipped) o.scheduledDate};
    return Row(children: [
      for (var i = 0; i < 7; i++)
        Expanded(
          child: Builder(builder: (context) {
            final day = addDays(monday, i);
            final isToday = day == today, trains = training.contains(day);
            return Semantics(
              label: '${longDate(day)}${isToday ? ', today' : ''}${trains ? ', workout planned' : ''}',
              child: ExcludeSemantics(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: isToday ? context.ec.action : null, borderRadius: BorderRadius.circular(Radii.week), border: Border.all(color: isToday ? context.ec.action : context.ec.divider)),
                  child: Column(children: [
                    Text(weekdayShort(i + 1)[0], style: context.sansStyle(11, color: isToday ? context.ec.actionText : context.ec.secondary)),
                    Text('${parseDayKey(day).day}', style: context.sansStyle(14, weight: FontWeight.w600, color: isToday ? context.ec.actionText : context.ec.text)),
                    Icon(trains ? Icons.circle : Icons.circle_outlined, size: 6, color: trains ? (isToday ? context.ec.actionText : context.ec.chart) : Colors.transparent),
                  ]),
                ),
              ),
            );
          }),
        ),
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
      return _list(context, ref, [
        EmptyState('No training recorded yet', 'Progress is built only from workouts you actually record. There is nothing to chart until then.',
            action: SecondaryButton('Start a manual workout', onPressed: () => startManualWorkout(context, ref))),
      ]);
    }
    final most = p.weeks.fold<int>(1, (m, w) => w.$2 > m ? w.$2 : m);
    return _list(context, ref, [
      const Serif('Am I following my plan?', size: 23),
      const SizedBox(height: 6),
      if (primary == null)
        Text('You have no primary plan right now. Manual training still counts as training below.', style: context.caption)
      else if (p.dueOccasions == 0)
        Text('No planned workout has come due yet.', style: context.caption)
      else ...[
        Text('${p.recorded} of ${p.dueOccasions} due workouts recorded', style: context.sansStyle(17, weight: FontWeight.w600)),
        Text('${p.full} finished · ${p.partial} partial · ${p.skipped} skipped · ${p.missed} missed', style: context.caption),
      ],
      const SizedBox(height: 24),
      const Serif('Am I consistent?', size: 23),
      const SizedBox(height: 6),
      Text('Days with recorded training in each of the last 8 weeks. ${p.sessions} session${p.sessions == 1 ? '' : 's'} in total.', style: context.caption),
      const SizedBox(height: 10),
      Semantics(
        label: 'Training days per week, oldest first: ${p.weeks.map((w) => w.$2).join(', ')}',
        child: ExcludeSemantics(
          child: SizedBox(
            height: 96,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final w in p.weeks)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${w.$2}', style: context.sansStyle(12, color: context.ec.secondary)),
                    Container(height: 6 + 52 * w.$2 / most, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: w.$2 == 0 ? context.ec.divider : context.ec.chart, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(height: 4),
                    Text('${parseDayKey(w.$1).month}/${parseDayKey(w.$1).day}', style: context.sansStyle(10, color: context.ec.secondary)),
                  ]),
                ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Serif('Am I getting stronger?', size: 23),
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
