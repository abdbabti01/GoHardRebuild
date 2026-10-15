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
import 'builder/plan_builder_screen.dart';
import 'plan_actions.dart';
import 'plan_progress.dart';
import 'plan_projection.dart';
import 'plan_rules.dart';
import 'plan_screens.dart';
import 'week_widgets.dart';

/// Train: Workouts / Plan / Progress. The chosen section lives in [shellProvider], so it is kept while you visit
/// other tabs, open a page or change the look.
class TrainScreen extends ConsumerWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(shellProvider.select((s) => s.trainView));
    return ListView(
      // On the calm wash the shell lays behind Train; room for the floating bar at the end.
      padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topInset(context), context.inset, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        TabHeader(title: 'Train', overline: longDate(ref.watch(todayKeyProvider))),
        const SizedBox(height: 16),
        Segmented<TrainView>(
          values: TrainView.values, selected: view, keyPrefix: 'train',
          label: (v) => '${v.name[0].toUpperCase()}${v.name.substring(1)}',
          onChanged: (v) => ref.read(shellProvider.notifier).selectTrainView(v),
        ),
        const SizedBox(height: 20),
        // The section that was chosen fades in; the one left is simply gone, so nothing is shown twice.
        AnimatedSwitcher(
          duration: context.motion(Motion.quick), reverseDuration: Duration.zero, switchInCurve: Motion.curve,
          layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
          child: switch (view) { TrainView.workouts => const _WorkoutsView(), TrainView.plan => const _PlanView(), TrainView.progress => const _ProgressView() },
        ),
      ],
    );
  }
}

Column _section(List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);

const _gap = SizedBox(height: 10), _between = SizedBox(height: 28);

/// The two histories. Workout history is always here, whatever has or has not been recorded.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({this.runs = false});
  final bool runs;
  @override
  Widget build(BuildContext context) => GroupCard(children: [
        GroupRow(key: Key(runs ? 'train-history' : 'progress-history'), icon: Icons.history, title: 'Workout history', subtitle: 'Every workout you recorded', onTap: () => push(context, const WorkoutHistoryScreen())),
        if (runs) GroupRow(key: const Key('train-run-history'), icon: Icons.directions_run, title: 'Run history', subtitle: 'Every run you recorded', onTap: () => push(context, const RunHistoryScreen())),
      ]);
}

class _WorkoutsView extends ConsumerWidget {
  const _WorkoutsView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted) w]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    final open = all.where((w) => w.isOpen).toList(), done = all.where((w) => !w.isOpen).toList();
    final parked = ref.watch(parkedIdsProvider);
    final roomy = MediaQuery.textScalerOf(context).scale(10) <= 13;
    return _section([
      if (open.isNotEmpty) ...[
        const SectionHeader('Open workouts'),
        _gap,
        GroupCard(children: [
          for (final w in open) ...[
            GroupRow(
              icon: parked.contains(w.id) ? Icons.bookmark_outline : Icons.timelapse,
              title: w.title,
              subtitle: '${parked.contains(w.id) ? 'Saved for later' : 'In progress'} · started ${shortDate(w.dayKey)}',
              trailing: roomy ? TextButton(onPressed: () => resumeWorkout(context, ref, w), child: const Text('Resume')) : null,
              onTap: () => resumeWorkout(context, ref, w),
            ),
            // With large text the button takes its own line instead of squeezing the workout's name.
            if (!roomy) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => resumeWorkout(context, ref, w), child: const Text('Resume'))),
          ],
        ]),
        const SizedBox(height: 20),
      ],
      PrimaryButton('Start a manual workout', key: const Key('start-manual'), icon: Icons.add, onPressed: () => startManualWorkout(context, ref)),
      _gap,
      SecondaryButton('Start a run', icon: Icons.directions_run, onPressed: () => startRunFlow(context, ref)),
      _between,
      const SectionHeader('Recent'),
      if (done.isEmpty)
        const EmptyState('No workouts recorded yet', 'When you finish a workout, what you actually did shows up here.')
      else ...[
        _gap,
        GroupCard(children: [for (final w in done.take(5)) WorkoutRow(w, grouped: true)]),
      ],
      _between,
      const SectionHeader('History'),
      _gap,
      const _HistoryCard(runs: true),
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
    final hasDraft = others.any((p) => p.isDraft && !p.isArchived);

    return _section([
      if (ctxRow?.needsReview ?? false)
        const Padding(padding: EdgeInsets.only(bottom: 14), child: StatusLine(Icons.rule, 'A plan change saved on this phone differs from your account. Review it from the notice at the bottom of the screen.', tone: Tone.warning)),
      if (primary == null)
        EmptyState(
          hasDraft ? 'Your plan is ready to review' : 'No plan yet',
          hasDraft
              ? 'A saved draft does not schedule anything until you start it.'
              : 'Start from a familiar split or build your own, and review it before anything is scheduled. Manual training is always available.',
          action: PrimaryButton('Create my plan', key: const Key('create-plan'), onPressed: () => push(context, const CreatePlanScreen())),
        )
      else
        ..._primary(context, primary, today, workouts, proposals),
      if (others.isNotEmpty) ...[
        _between,
        const SectionHeader('Saved and past plans'),
        _gap,
        GroupCard(children: [
          for (final p in others.where((p) => !p.isArchived))
            GroupRow(
              key: Key('saved-plan-${p.id}'),
              title: p.title,
              subtitle: switch (p.lifecycle) {
                'draft' when p.isBuilt => 'Draft · ${scheduleMode(p)} · ${PlanRules.usable(p.j) ? 'not started · would start ${shortDate(p.startDate)}' : 'add exercises to use it'}',
                'draft' => 'Draft · not started · would start ${shortDate(p.startDate)}',
                'paused' => 'Paused · not your primary plan',
                'closed' => p.closureIntent == 'stopped_early' ? 'Stopped early' : 'Finished for now',
                'active' => 'Active · not your primary plan',
                _ => p.lifecycle,
              },
              onTap: () => push(context, p.isDraft ? PlanReviewScreen(planId: p.id) : PlanDetailScreen(planId: p.id)),
            ),
          if (others.any((p) => p.isArchived))
            GroupRow(icon: Icons.inventory_2_outlined, tone: Tone.neutral, title: 'Archived plans (${others.where((p) => p.isArchived).length})', onTap: () => push(context, const ArchivedPlansScreen())),
        ]),
      ],
    ]);
  }

  List<Widget> _primary(BuildContext context, Plan plan, String today, List<Workout> workouts, List<Proposal> proposals) {
    // The one projection Today and the occurrence sheet read too.
    final occasions = planOccasions(plan, today, workouts);
    final rotation = rotationOf(plan, occasions, workouts);
    final position = planWeek(plan, today);
    final minutes = plan.isBuilt ? plannedMinutes(plan) : null;
    final note = [
      if (position == 0) 'Not started',
      if (plan.isPaused) 'Paused',
      if (plan.endDate != null) 'Ends ${shortDate(plan.endDate!)}' else if (plan.isOngoing) 'Ongoing, no end date',
    ].join(' · ');
    return [
      _TrainPass(
        title: plan.title,
        // Calendar position and completion are two different facts, shown separately.
        week: position == 0 ? 'Starts ${dayMonth(plan.startDate)}' : plan.isOngoing ? 'Week $position' : 'Week $position of ${plan.blockWeeks}',
        completion: rotation == null ? Completion.of(plan.occasions, workouts) : null,
        rotation: rotation, thisWeek: rotation == null ? 0 : creditedThisWeek(occasions, workouts, today),
        photo: plan.isActive && position > 0,
      ),
      Padding(padding: const EdgeInsets.only(top: 8), child: Text('${splitOf(ref, plan)} · ${scheduleMode(plan)}', key: const Key('plan-split'), style: context.body)),
      if (minutes != null) Text('Planned time $minutes min', key: const Key('plan-time'), style: context.caption),
      if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note, style: context.caption)),
      if (plan.isPaused) ...[
        const SizedBox(height: 14),
        const StatusLine(Icons.pause_circle_outline, 'Plan paused. No new workouts are expected, and nothing counts as missed while it is paused.'),
        const SizedBox(height: 12),
        PrimaryButton('Resume plan', key: const Key('plan-resume'), onPressed: () => push(context, ResumeReviewScreen(planId: plan.id))),
      ],
      if (proposals.isNotEmpty) ...[
        const SizedBox(height: 14),
        GroupCard(children: [
          for (final p in proposals)
            GroupRow(icon: Icons.tips_and_updates_outlined, tone: Tone.warning, title: 'Suggested change to review', subtitle: p.explanation, onTap: () => push(context, ProposalReviewScreen(proposalId: p.id))),
        ]),
      ],
      if (rotation != null) ..._rotation(context, plan, today, workouts, occasions, rotation) else ..._weeks(context, plan, today, workouts),
      _between,
      const SectionHeader('Manage this plan'),
      _gap,
      GroupCard(children: [
        if (plan.isBuilt)
          GroupRow(key: const Key('plan-edit'), icon: Icons.edit_outlined, tone: Tone.neutral, title: 'Edit plan',
              subtitle: 'Workouts, exercises and schedule from a date you choose. Recorded workouts never change.', onTap: () => openPlanEditor(context, ref, plan)),
        if (plan.isActive) GroupRow(key: const Key('plan-pause'), icon: Icons.pause, tone: Tone.neutral, title: 'Pause plan', onTap: () => pausePlanFlow(context, ref, plan)),
        if (plan.isBuilt)
          GroupRow(key: const Key('plan-duplicate'), icon: Icons.copy_outlined, tone: Tone.neutral, title: 'Duplicate plan',
              subtitle: 'A new draft with the same workouts and schedule. This plan stays as it is.', onTap: () => openPlanEditor(context, ref, plan, duplicate: true)),
        // A reviewed swap in the remaining workouts (a built plan's own workouts follow it). A rotation has no
        // remaining dated workouts to swap in: edit it instead.
        if (!plan.isRotating)
          GroupRow(icon: Icons.swap_horiz, tone: Tone.neutral, title: 'Replace a movement in remaining workouts', onTap: () => push(context, SubstitutionRequestScreen(planId: plan.id))),
        GroupRow(icon: Icons.flag_outlined, tone: Tone.neutral, title: 'Review or finish this block', onTap: () => push(context, BlockReviewScreen(planId: plan.id))),
        GroupRow(icon: Icons.add, tone: Tone.neutral, title: 'Create a different plan', subtitle: 'Starting it will ask before replacing this one.', onTap: () => push(context, const CreatePlanScreen())),
      ]),
      _gap,
      Text('Your primary plan is paused, finished or replaced before it can be archived. Saved and past plans can be archived from their page.', style: context.caption),
    ];
  }

  /// Fixed weekdays and older plans: the week grid, the chosen week's days and its dated workouts.
  List<Widget> _weeks(BuildContext context, Plan plan, String today, List<Workout> workouts) {
    final weeks = planWeeks(plan, today, workouts);
    final week = weeks.where((w) => w.number == _picked).firstOrNull ?? focusWeek(weeks);
    if (week == null) return const [];
    return [
      _between,
      const SectionHeader('Choose a week'),
      _gap,
      WeekGrid(weeks: weeks, selected: week.number, stateOf: (w) => weekStateOf(w, plan, today, workouts), onSelect: (n) => setState(() => _picked = n)),
      _between,
      SectionHeader(week.isCurrent ? 'This week' : 'Week ${week.number}', detail: week.range,
          trailing: week.completion.eligible == 0 ? null : Text('${week.completion.completed} of ${week.completion.eligible} completed', style: context.numStyle(14.5))),
      if (week.completion.eligible > 0) ...[
        _gap,
        Row(children: [
          Expanded(child: ProgressRail(week.completion.fraction, label: 'Workouts completed in this week')),
          const SizedBox(width: 12),
          ExcludeSemantics(child: Text('${(week.completion.fraction * 100).round()}%', style: context.numStyle(14.5, color: context.c.secondary))),
        ]),
      ],
      const SizedBox(height: 16),
      WeekDayStrip(week: week, plan: plan, today: today, workouts: workouts),
      const SizedBox(height: 10),
      const Rule(),
      if (week.occasions.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text('No workouts are planned in this week.', style: context.caption)),
      for (final o in week.occasions) _OccasionRow(plan: plan, occasion: o, status: statusOf(o, plan, today, workouts)),
    ];
  }

  /// A rotating sequence: the cycle and where you are in it, the next workout and the projected days ahead, and
  /// what was recently done or skipped.
  List<Widget> _rotation(BuildContext context, Plan plan, String today, List<Workout> workouts, List<Occasion> occasions, Rotation rotation) {
    final days = plan.schedule!.trainingDays.toList()..sort();
    bool resolved(Occasion o) => o.isSkipped || occasionOutcome(o, workouts) != null;
    final ahead = [for (final o in occasions) if (!resolved(o)) o];
    final recent = [for (final o in occasions) if (resolved(o)) o].reversed.take(5).toList();
    final end = addDays(today, 6);
    final days7 = PlanWeek(number: 0, start: today, end: end, occasions: [for (final o in ahead) if (o.scheduledDate.compareTo(end) <= 0) o],
        completion: const Completion(0, 0), isCurrent: true, isPast: false);
    String? noteOf(Occasion o) => o.id == rotation.next?.id ? 'Next in the cycle' : o.isVirtual ? 'Projected' : null;
    return [
      _between,
      SectionHeader('Your cycle', detail: 'Cycle ${rotation.cyclesDone + 1}'),
      _gap,
      _CycleStrip(cycle: rotation.cycle, position: rotation.next == null ? null : rotation.position),
      _gap,
      Text(
          'A rotation has no fixed dates. The next workout waits for you until you finish or skip it, and the cycle carries on across weeks. '
          '${days.isEmpty ? 'Upcoming days assume you train every day.' : 'Upcoming days follow your training days (${days.map(weekdayShort).join(', ')}); the others are rest days.'}',
          style: context.caption),
      _between,
      SectionHeader('Coming up', detail: dateRange(today, end)),
      _gap,
      WeekDayStrip(week: days7, plan: plan, today: today, workouts: workouts),
      const SizedBox(height: 10),
      const Rule(),
      if (ahead.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text('Nothing is left in this plan.', style: context.caption)),
      for (final o in ahead) _OccasionRow(plan: plan, occasion: o, status: statusOf(o, plan, today, workouts), rowKey: 'rotation-${o.sequenceIndex ?? o.ordinal - 1}', note: noteOf(o)),
      if (recent.isNotEmpty) ...[
        _between,
        const SectionHeader('Recent sessions'),
        _gap,
        const Rule(),
        for (final o in recent) _OccasionRow(plan: plan, occasion: o, status: statusOf(o, plan, today, workouts), rowKey: 'rotation-${o.sequenceIndex ?? o.ordinal - 1}'),
      ],
    ];
  }
}

/// The cycle in order (Push → Pull → Legs), the next workout's step marked by a border, a tint and the word "Next".
class _CycleStrip extends StatelessWidget {
  const _CycleStrip({required this.cycle, required this.position});
  final List<WorkoutDefinition> cycle;
  final int? position;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(spacing: 6, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final (i, w) in cycle.indexed) ...[
        if (i > 0) ExcludeSemantics(child: Icon(Icons.arrow_forward, size: 16, color: c.secondary)),
        Semantics(
          label: 'Step ${i + 1} of ${cycle.length}, ${w.name}${i == position ? ', next' : ''}',
          child: ExcludeSemantics(
            child: Container(
              key: Key('cycle-step-$i'),
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: i == position ? c.accentSoft : c.surface,
                borderRadius: BorderRadius.circular(Radii.field),
                border: Border.all(color: i == position ? c.accent : c.divider, width: i == position ? 2 : 1),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.name, style: context.sansStyle(15, weight: FontWeight.w600)),
                if (i == position) Text('Next', style: context.numStyle(12.5, color: c.accent)),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// The training pass: the plan's real name and where the calendar is. A finite fixed plan adds workouts with a
/// recorded result out of the ones still expected; a rotation has no meaningful total, so it shows this week's
/// completed sessions and the position in the cycle instead, and no percentage. A small category photograph sits at
/// the trailing edge while there is room for it. (Built here rather than with the shared PassCard, which has no
/// place for the photograph.)
class _TrainPass extends StatelessWidget {
  const _TrainPass({required this.title, required this.week, required this.completion, required this.photo, this.rotation, this.thisWeek = 0});
  final String title, week;
  final Completion? completion;
  final Rotation? rotation;
  final int thisWeek;
  final bool photo;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final media = MediaQuery.of(context);
    final showPhoto = photo && media.size.width >= 360 && media.textScaler.scale(10) <= 13;
    final done = completion ?? const Completion(0, 0);
    final measured = done.eligible > 0;
    final percent = '${(done.fraction * 100).round()}%';
    final r = rotation;
    final cycleLine = r == null
        ? null
        : r.next == null
            ? 'Cycle ${r.cyclesDone + 1} · nothing left'
            : 'Cycle ${r.cyclesDone + 1} · step ${r.position + 1} of ${r.cycle.length} · ${r.next!.title} next';
    // About a third of the card, inset with its own rounded corners, decoded at the size it is drawn.
    final photoWidth = ((media.size.width - 2 * context.inset) * 0.32).roundToDouble();
    return Semantics(
      container: true,
      label: r == null
          ? '$title. $week. ${done.completed} / ${done.eligible} workouts completed${measured ? ', $percent' : ''}.'
          : '$title. $week. $thisWeek ${thisWeek == 1 ? 'session' : 'sessions'} completed this week. $cycleLine.',
      child: ExcludeSemantics(
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.panel), side: BorderSide(color: c.divider)),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18 + (showPhoto ? photoWidth + 6 : 0), 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Overline('Training plan'),
                const SizedBox(height: 4),
                // The plan's name is the one serif line in the body, as in the reference pass.
                Text(title, style: context.pageTitleStyle(30)),
                Padding(padding: const EdgeInsets.only(top: 2), child: Text(week, style: context.numStyle(15, color: c.secondary, weight: FontWeight.w500))),
                const SizedBox(height: 14),
                if (r == null) ...[
                  Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 10, children: [
                    Text.rich(TextSpan(text: '${done.completed}', children: [TextSpan(text: ' / ${done.eligible}', style: TextStyle(color: c.secondary))]), style: context.titleStyle(34)),
                    Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Workouts completed', style: context.sansStyle(15, color: c.secondary))),
                  ]),
                  if (measured) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: ProgressRail(done.fraction, label: 'Workouts completed')),
                      const SizedBox(width: 12),
                      Text(percent, style: context.numStyle(15)),
                    ]),
                  ],
                ] else ...[
                  Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 10, children: [
                    Text('$thisWeek', style: context.titleStyle(34)),
                    Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${thisWeek == 1 ? 'Session' : 'Sessions'} completed this week', style: context.sansStyle(15, color: c.secondary))),
                  ]),
                  const SizedBox(height: 6),
                  Text(cycleLine!, style: context.numStyle(15, color: c.secondary, weight: FontWeight.w500)),
                ],
              ]),
            ),
            if (showPhoto)
              Positioned(
                top: 6, bottom: 6, right: 6, width: photoWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.panel - 6),
                  // Decoded at the crop's height (the source is landscape, so its width follows and still covers).
                  child: LayoutBuilder(
                    builder: (context, box) => Image.asset('assets/images/workout-hero.webp', fit: BoxFit.cover,
                        cacheHeight: (box.maxHeight * media.devicePixelRatio).round().clamp(64, 1536), errorBuilder: (context, _, _) => ColoredBox(color: c.sunken)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// "5 exercises · 18 planned sets"; the sets are left out when no movement has a target.
String _plannedSummary(List<Prescription> prescription) {
  final sets = prescription.fold(0, (n, e) => n + (e.targetSets ?? 0));
  return '${prescription.length} ${prescription.length == 1 ? 'exercise' : 'exercises'}${sets == 0 ? '' : ' · $sets planned ${sets == 1 ? 'set' : 'sets'}'}';
}

/// One workout of the plan: its day, name, what is planned and its named state. Fixed rows are keyed
/// `occasion-<week>-<ordinal>`; a rotation's rows `rotation-<sequenceIndex>` ([rowKey]).
class _OccasionRow extends ConsumerWidget {
  const _OccasionRow({required this.plan, required this.occasion, required this.status, this.rowKey, this.note});
  final Plan plan;
  final Occasion occasion;
  final OccasionStatus status;
  final String? rowKey, note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = occasion, c = context.c;
    final pill = OccasionPill(status);
    final day = parseDayKey(o.scheduledDate);
    final summary = _plannedSummary(o.prescription);
    final moved = o.wasMoved ? 'Moved · originally ${shortDate(o.originalDate)}' : null;
    final extra = [?moved, ?note].join(' · ');
    // With large text the state sits under the title instead of squeezing it.
    final below = MediaQuery.textScalerOf(context).scale(10) > 13;
    final active = status == OccasionStatus.inProgress || status == OccasionStatus.due;
    return Column(children: [
      Pressable(
        key: Key(rowKey ?? 'occasion-${o.weekNumber}-${o.ordinal}'),
        borderRadius: BorderRadius.circular(Radii.field),
        semanticLabel: '${o.title}, ${longDate(o.scheduledDate)}, $summary${extra.isEmpty ? '' : ', $extra'}, ${status.label}',
        onTap: () => showOccasionSheet(context, ref, plan, o),
        child: LayoutBuilder(
          builder: (context, box) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 36),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(weekdayShort(day.weekday), style: context.sansStyle(13, color: c.secondary)),
                  Text('${day.day}', style: context.numStyle(18)),
                ]),
              ),
              const SizedBox(width: 10),
              if (!below && box.maxWidth >= 330) ...[IconTile(Icons.fitness_center, circle: true, tone: active ? Tone.accent : Tone.neutral), const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // The state shares the name's line while both fit; otherwise it drops under it, never squeezing the name.
                  Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                    Text(o.title, style: context.sansStyle(16, weight: FontWeight.w600)),
                    if (!below) pill,
                  ]),
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(summary, style: context.numStyle(13.5, color: c.secondary, weight: FontWeight.w400))),
                  if (extra.isNotEmpty) Text(extra, style: context.caption),
                  if (below) Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: AlignmentDirectional.centerStart, child: pill)),
                ]),
              ),
              Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right, size: 22, color: c.secondary)),
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
    // History is offered in every state, including an account with nothing recorded yet.
    if (!p.hasEvidence && p.dueOccasions == 0) {
      return _section([
        EmptyState('No training recorded yet', 'Progress is built only from workouts you actually record. There is nothing to chart until then.',
            action: SecondaryButton('Start a manual workout', onPressed: () => startManualWorkout(context, ref))),
        _gap,
        const _HistoryCard(),
      ]);
    }
    final most = p.weeks.fold<int>(1, (m, w) => w.$2 > m ? w.$2 : m);
    return _section([
      const SectionHeader('Am I following my plan?'),
      _gap,
      Panel(
        child: primary == null
            ? Text('You have no primary plan right now. Manual training still counts as training below.', style: context.caption)
            : p.dueOccasions == 0
                ? Text('No planned workout has come due yet.', style: context.caption)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p.recorded} of ${p.dueOccasions} due workouts recorded', style: context.numStyle(17)),
                    const SizedBox(height: 10),
                    ProgressRail(p.recorded / p.dueOccasions, label: 'Due workouts recorded'),
                    const SizedBox(height: 10),
                    Text('${p.full} completed · ${p.partial} partial · ${p.skipped} skipped · ${p.missed} missed', style: context.numStyle(13.5, color: context.c.secondary, weight: FontWeight.w400)),
                  ]),
      ),
      _between,
      const SectionHeader('Am I consistent?'),
      _gap,
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Days with recorded training in each of the last 8 weeks. ${p.sessions} session${p.sessions == 1 ? '' : 's'} in total.', style: context.caption),
          const SizedBox(height: 14),
          Semantics(
            label: 'Training days per week, oldest first: ${p.weeks.map((w) => w.$2).join(', ')}',
            child: ExcludeSemantics(
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final w in p.weeks)
                  Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${w.$2}', style: context.numStyle(13)),
                      const SizedBox(height: 2),
                      Container(height: 6 + 58 * w.$2 / most, margin: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(color: w.$2 == 0 ? context.c.outline : context.c.accent, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      FittedBox(fit: BoxFit.scaleDown, child: Text('${parseDayKey(w.$1).month}/${parseDayKey(w.$1).day}', style: context.numStyle(12.5, color: context.c.secondary, weight: FontWeight.w400))),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      ),
      _between,
      const SectionHeader('Am I getting stronger?'),
      _gap,
      if (p.insights.isEmpty)
        Panel(child: Text('Not enough comparable records yet. This needs the same movement recorded in at least two sessions.', style: context.caption))
      else
        GroupCard(children: [
          for (final i in p.insights)
            GroupRow(
              title: i.name,
              subtitle: '${shortDate(i.firstDay)}: ${setText(i.first, unit)}  →  ${shortDate(i.latestDay)}: ${setText(i.latest, unit)} · ${i.sessions} sessions',
            ),
        ]),
      _gap,
      Text('Best recorded set of the first and the latest session. Loads are stored in kilograms and shown in ${unit == LoadUnit.kg ? 'kilograms' : 'pounds'}.', style: context.caption),
      _between,
      const _HistoryCard(),
    ]);
  }
}
