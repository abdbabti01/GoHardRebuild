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
import '../coach/coach_bubble.dart';
import '../coach/coach_contract.dart';
import '../coach/coach_prefs.dart';
import '../shell/home_shell.dart';
import '../today/daily.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import '../workout/workout_screen.dart';
import 'builder/plan_builder_screen.dart';
import 'plan_actions.dart';
import 'plan_draft.dart';
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
    final coachOn = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    final noPlan = ref.watch(primaryPlanProvider) == null;
    // Ask GoHard about the section in view: the primary plan on Plan, recorded training on Progress.
    final ask = switch (view) {
      TrainView.plan when noPlan => const CoachContext(label: 'Starting a plan'),
      TrainView.plan => CoachContext(label: ref.watch(primaryPlanProvider)?.title ?? 'Your plan'),
      TrainView.progress => const CoachContext(label: 'Your progress'),
      TrainView.workouts => const CoachContext(label: 'Your training'),
    };
    return ListView(
      // On the calm wash the shell lays behind Train; room for the floating bar at the end.
      padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topInset(context), context.inset, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        // The guide's face is Ask GoHard's way in on Train: the speaking bust (Show coach on Train and Eat), or, with
        // that off, its small avatar beside the title. Never both.
        TabHeader(title: 'Train', overline: longDate(ref.watch(todayKeyProvider)), trailing: coachOn ? null : CoachAskLauncher(ask: ask)),
        const SizedBox(height: 16),
        Segmented<TrainView>(
          values: TrainView.values, selected: view, keyPrefix: 'train',
          label: (v) => '${v.name[0].toUpperCase()}${v.name.substring(1)}',
          onChanged: (v) => ref.read(shellProvider.notifier).selectTrainView(v),
        ),
        // Under the sections, speaking about the one chosen: with large text its words can run long, and the sections
        // stay at the top where they are always reached.
        if (coachOn) ...[
          const SizedBox(height: 14),
          TabCoach(key: const Key('train-coach'), say: _coachSay(context, ref, view), onAvatarTap: () => openAskGoHard(context, ask)),
        ],
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

/// The builder's plan in progress on this phone, if any (what Create plan offers to continue).
final builderDraftProvider = FutureProvider.autoDispose<PlanDraft?>((ref) => ref.watch(planRepositoryProvider).builderDraft('new'));

/// How someone without a primary plan starts one, the same with or without the coach: continue the builder's plan in
/// progress (never discarded here), review a saved draft, or create one. Opens the existing builder or review page.
({String text, String title, String body, CoachGuideAction action}) _planStart(BuildContext context, WidgetRef ref) {
  Future<void> open(Widget page) async {
    await push<void>(context, page);
    ref.invalidate(builderDraftProvider); // finished, discarded or still in progress: read again
  }

  final inProgress = ref.watch(builderDraftProvider).value;
  final saved = ref.watch(planListProvider).where((p) => p.isDraft && !p.isArchived).firstOrNull;
  if (inProgress != null) {
    return (text: 'Your plan in progress is saved on this phone. Pick up where you left off.', title: 'Plan in progress', body: 'Saved on this phone. Nothing is scheduled until you start it.',
        action: (label: 'Continue my plan', key: const Key('plan-builder-continue'), onPressed: () => open(PlanBuilder(initial: inProgress))));
  }
  if (saved != null) {
    return (text: 'Your plan is saved as a draft. Review it, then start it when you\'re ready.', title: 'Your plan is ready to review', body: 'A saved draft does not schedule anything until you start it.',
        action: (label: 'Review my plan', key: const Key('plan-review-draft'), onPressed: () => open(PlanReviewScreen(planId: saved.id))));
  }
  return (text: 'Let\'s build your training plan. Choose a familiar split or make your own.', title: 'No plan yet', body: 'Choose a familiar split or make your own. Nothing is scheduled until you review it.',
      action: (label: 'Create my plan', key: const Key('create-plan'), onPressed: () => open(const CreatePlanScreen())));
}

/// What the coach says on Train, from the section in view and what is really there. Facts and next steps only: no
/// judgement of the training, no score, nothing about form.
CoachSay _coachSay(BuildContext context, WidgetRef ref, TrainView view) {
  final plan = ref.watch(primaryPlanProvider);
  final workouts = [for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted) w];
  switch (view) {
    case TrainView.plan when plan == null:
      final start = _planStart(context, ref);
      return CoachSay(start.text, primary: start.action);
    case TrainView.plan:
      return CoachSay(plan!.isPaused ? 'Your plan is paused, so nothing counts as missed. Resume it below when you\'re ready.' : 'Here\'s your plan week by week. Tap a workout for its details, or ask me about the schedule.',
          ask: CoachContext(label: plan.title));
    case TrainView.workouts:
      return CoachSay(
          workouts.any((w) => w.isOpen) ? 'A workout is still open. Resume it below when you\'re ready.'
              : plan != null ? 'Start your planned workout from Today, or record one of your own here.'
              : 'Record a workout of your own here. A plan can schedule them for you.',
          ask: const CoachContext(label: 'Your training'));
    case TrainView.progress:
      return CoachSay(workouts.any((w) => !w.isOpen) ? 'This is what you\'ve recorded so far. Ask me about any of it.' : 'What you record shows up here once you finish a workout.',
          ask: const CoachContext(label: 'Your progress'));
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
    final sets = ref.watch(trustedSetsProvider);
    return _section([
      if (open.isNotEmpty) ...[
        const SectionHeader('Open workouts'),
        _gap,
        // Each open workout is a panel with its own Resume (the deep button; quiet when saved for later) and Details.
        // The photograph goes to the first one only, so a second open workout does not repeat it.
        for (final (i, w) in open.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          _OpenPanel(w, parked: parked.contains(w.id), photo: i == 0, recorded: SetProgress.of(w, sets).recorded),
        ],
        const SizedBox(height: 20),
      ],
      GroupCard(children: [
        GroupRow(key: const Key('start-manual'), icon: Icons.add, title: 'Start a manual workout', subtitle: 'Train without a plan. It never ticks off a planned workout.',
            onTap: () => startManualWorkout(context, ref)),
        GroupRow(key: const Key('train-start-run'), icon: Icons.directions_run, title: 'Start a run', onTap: () => startRunFlow(context, ref)),
      ]),
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

/// An open workout on Train › Workouts, in the Today panel language: its state in an icon and a word, the name in
/// the serif, when it started and what is recorded, then Resume and Details. A workout saved for later keeps a quiet
/// Resume: it is still there, but it does not take over. Dialogs open from the app's context, not the panel's.
class _OpenPanel extends ConsumerWidget {
  const _OpenPanel(this.w, {required this.parked, required this.photo, required this.recorded});
  final Workout w;
  final bool parked, photo;
  final int recorded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = parked ? 'Saved for later' : 'In progress';
    void resume() => resumeWorkout(context, ref, w);
    return PhotoPanel(
      key: Key('train-open-${w.id}'),
      photo: photo ? 'assets/images/workout-hero.webp' : null,
      photoAlignment: const Alignment(1, 0.6),
      content: (context) => [
        StatusPill(status, icon: parked ? Icons.bookmark_outline : Icons.timelapse, tone: parked ? Tone.neutral : Tone.accent),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(w.title, style: context.pageTitleStyle(30))),
        Padding(padding: const EdgeInsets.only(top: 2), child: Text('$status · started ${shortDate(w.dayKey)}', style: context.sansStyle(15, color: context.c.secondary))),
        if (recorded > 0) Padding(padding: const EdgeInsets.only(top: 2), child: Text('$recorded ${recorded == 1 ? 'set' : 'sets'} recorded', style: context.numStyle(15))),
      ],
      actions: (_) => [
        parked
            ? TextButton(key: Key('train-resume-${w.id}'), onPressed: resume, child: const Text('Resume'))
            : PrimaryButton('Resume', key: Key('train-resume-${w.id}'), icon: Icons.play_arrow_rounded, expand: false, onPressed: resume),
        QuietLink('Details', said: 'Details of ${w.title}', onPressed: () => push(context, WorkoutDetailScreen(workoutId: w.id))),
      ],
    );
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

    return _section([
      if (ctxRow?.needsReview ?? false)
        const Padding(padding: EdgeInsets.only(bottom: 14), child: StatusLine(Icons.rule, 'A plan change saved on this phone differs from your account. Review it from the notice at the bottom of the screen.', tone: Tone.warning)),
      // No plan: with the coach on Train, its bubble holds the one way to start (above); without it, the same action
      // here. Manual training stays a quiet alternative either way.
      if (primary == null) ...[
        if (!ref.watch(coachPrefsProvider.select((p) => p.onTabs)))
          () {
            final start = _planStart(context, ref);
            return EmptyState(start.title, start.body, action: PrimaryButton(start.action.label, key: start.action.key, onPressed: start.action.onPressed));
          }(),
        Align(
          alignment: Alignment.centerLeft,
          child: QuietLink('Train without a plan', key: const Key('train-manual-instead'), said: 'Start a manual workout without a plan', onPressed: () => startManualWorkout(context, ref)),
        ),
      ],
      if (primary != null)
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
      const SizedBox(height: 14),
      if (week.occasions.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('No workouts are planned in this week.', style: context.caption)),
      _rows([for (final o in week.occasions) _OccasionRow(plan: plan, occasion: o, status: statusOf(o, plan, today, workouts), today: today)]),
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
      const SizedBox(height: 14),
      if (ahead.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('Nothing is left in this plan.', style: context.caption)),
      _rows([
        for (final o in ahead)
          _OccasionRow(plan: plan, occasion: o, status: statusOf(o, plan, today, workouts), today: today, rowKey: 'rotation-${o.sequenceIndex ?? o.ordinal - 1}', note: noteOf(o)),
      ]),
      if (recent.isNotEmpty) ...[
        _between,
        const SectionHeader('Recent sessions'),
        _gap,
        _rows([for (final o in recent) _OccasionRow(plan: plan, occasion: o, status: statusOf(o, plan, today, workouts), today: today, rowKey: 'rotation-${o.sequenceIndex ?? o.ordinal - 1}')]),
      ],
    ];
  }
}

/// The cycle in order (Push → Pull → Legs), the next workout's step in the pale panel tint with a border and the
/// word "Next".
class _CycleStrip extends StatelessWidget {
  const _CycleStrip({required this.cycle, required this.position});
  final List<WorkoutDefinition> cycle;
  final int? position;

  @override
  Widget build(BuildContext context) {
    Widget step(BuildContext context, int i, WorkoutDefinition w) {
      final c = context.c, next = i == position;
      return Container(
        key: Key('cycle-step-$i'),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: next ? c.tint : c.surface,
          borderRadius: BorderRadius.circular(Radii.field),
          border: Border.all(color: next ? c.accent : c.divider, width: next ? 1.5 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(w.name, style: context.sansStyle(15, weight: FontWeight.w600)),
          if (next) Text('Next', style: context.numStyle(12.5, color: c.accent)),
        ]),
      );
    }

    return Wrap(spacing: 6, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final (i, w) in cycle.indexed) ...[
        if (i > 0) ExcludeSemantics(child: Icon(Icons.arrow_forward, size: 16, color: context.c.secondary)),
        Semantics(
          label: 'Step ${i + 1} of ${cycle.length}, ${w.name}${i == position ? ', next' : ''}',
          // The next step takes the panel palette: dark ink and the deep accent on the pale tint, in Light and Dark.
          child: ExcludeSemantics(child: i == position ? PanelTheme(child: Builder(builder: (context) => step(context, i, w))) : step(context, i, w)),
        ),
      ],
    ]);
  }
}

/// The training pass, as a photo panel in the Today look: the plan's real name in the serif and where the calendar
/// is. A finite fixed plan adds workouts with a recorded result out of the ones still expected, with the rail; a
/// rotation has no meaningful total, so it shows this week's completed sessions and the position in the cycle
/// instead, and no percentage. The dumbbells photograph appears only while the plan is running.
class _TrainPass extends StatelessWidget {
  const _TrainPass({required this.title, required this.week, required this.completion, required this.photo, this.rotation, this.thisWeek = 0});
  final String title, week;
  final Completion? completion;
  final Rotation? rotation;
  final int thisWeek;
  final bool photo;

  @override
  Widget build(BuildContext context) {
    final done = completion ?? const Completion(0, 0);
    final measured = done.eligible > 0;
    final percent = '${(done.fraction * 100).round()}%';
    final r = rotation;
    final cycleLine = r == null
        ? null
        : r.next == null
            ? 'Cycle ${r.cyclesDone + 1} · nothing left'
            : 'Cycle ${r.cyclesDone + 1} · step ${r.position + 1} of ${r.cycle.length} · ${r.next!.title} next';
    return Semantics(
      container: true,
      label: r == null
          ? '$title. $week. ${done.completed} / ${done.eligible} workouts completed${measured ? ', $percent' : ''}.'
          : '$title. $week. $thisWeek ${thisWeek == 1 ? 'session' : 'sessions'} completed this week. $cycleLine.',
      child: ExcludeSemantics(
        child: PhotoPanel(
          key: const Key('train-pass'),
          photo: photo ? 'assets/images/workout-hero.webp' : null,
          // The dumbbells sit low and right in the picture.
          photoAlignment: const Alignment(1, 0.6),
          content: (context) {
            final c = context.c;
            return [
              Row(children: [
                Icon(Icons.event_note_outlined, size: 18, color: c.secondary),
                const SizedBox(width: 6),
                const Flexible(child: Overline('Training plan')),
              ]),
              const SizedBox(height: 4),
              Text(title, style: context.pageTitleStyle(30)),
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(week, style: context.numStyle(16, weight: FontWeight.w600))),
              const SizedBox(height: 10),
              if (r == null) ...[
                Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
                  Text.rich(TextSpan(text: '${done.completed}', children: [TextSpan(text: ' / ${done.eligible}', style: TextStyle(color: c.secondary))]), style: context.titleStyle(28)),
                  Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('Workouts completed', style: context.sansStyle(15, color: c.secondary))),
                ]),
                if (measured) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ProgressRail(done.fraction, label: 'Workouts completed')),
                    const SizedBox(width: 10),
                    Text(percent, style: context.numStyle(15)),
                  ]),
                ],
              ] else ...[
                Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
                  Text('$thisWeek', style: context.titleStyle(28)),
                  Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('${thisWeek == 1 ? 'Session' : 'Sessions'} completed this week', style: context.sansStyle(15, color: c.secondary))),
                ]),
                const SizedBox(height: 4),
                Text(cycleLine!, style: context.numStyle(15, color: c.secondary, weight: FontWeight.w500)),
              ],
            ];
          },
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

/// The rows of one week (or of the rotation ahead) in one quiet card, so the days read as a single schedule.
Widget _rows(List<Widget> rows) => rows.isEmpty ? const SizedBox.shrink() : GroupCard(children: rows);

/// One workout of the plan, a row of a [GroupCard]: its day, name, what is planned and its named state. Today's row
/// is outlined in the accent and says "Today" beside the date, so it never rests on colour alone. Fixed rows are
/// keyed `occasion-<week>-<ordinal>`; a rotation's rows `rotation-<sequenceIndex>` ([rowKey]).
class _OccasionRow extends ConsumerWidget {
  const _OccasionRow({required this.plan, required this.occasion, required this.status, required this.today, this.rowKey, this.note});
  final Plan plan;
  final Occasion occasion;
  final OccasionStatus status;
  final String today;
  final String? rowKey, note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = occasion, c = context.c;
    final pill = OccasionPill(status);
    final day = parseDayKey(o.scheduledDate);
    final isToday = o.scheduledDate == today;
    final summary = _plannedSummary(o.prescription);
    final moved = o.wasMoved ? 'Moved · originally ${shortDate(o.originalDate)}' : null;
    final extra = [?moved, ?note].join(' · ');
    // With large text the state sits under the title instead of squeezing it.
    final below = MediaQuery.textScalerOf(context).scale(10) > 13;
    final row = Pressable(
      key: Key(rowKey ?? 'occasion-${o.weekNumber}-${o.ordinal}'),
      borderRadius: BorderRadius.circular(Radii.field),
      semanticLabel: '${o.title}, ${longDate(o.scheduledDate)}${isToday ? ', today' : ''}, $summary${extra.isEmpty ? '' : ', $extra'}, ${status.label}',
      onTap: () => showOccasionSheet(context, ref, plan, o),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(weekdayShort(day.weekday), style: context.sansStyle(13, color: isToday ? c.text : c.secondary, weight: isToday ? FontWeight.w700 : FontWeight.w400)),
              Text('${day.day}', style: context.numStyle(18)),
              if (isToday) Text('Today', style: context.sansStyle(12.5, color: c.accent, weight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 12),
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
    );
    if (!isToday) return row;
    // Today: an accent outline inside the card's corners.
    return Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.field), border: Border.all(color: c.accent, width: 1.5)),
        child: row,
      ),
    );
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
    final thisWeek = p.weeks.last.$2;
    final recent = ([for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted && !w.isOpen) w]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc))).take(3).toList();
    return _section([
      // Only what was recorded: training days this week and the total, with their periods. Nothing is inferred.
      Semantics(
        container: true,
        label: 'Training progress. $thisWeek training ${thisWeek == 1 ? 'day' : 'days'} this week. ${p.sessions} ${p.sessions == 1 ? 'workout' : 'workouts'} recorded in total.',
        child: ExcludeSemantics(
          child: PhotoPanel(
            key: const Key('train-progress-panel'),
            photo: 'assets/images/workout-hero.webp',
            photoAlignment: const Alignment(1, 0.6),
            content: (context) => [
              Row(children: [
                Icon(Icons.bar_chart_rounded, size: 18, color: context.c.secondary),
                const SizedBox(width: 6),
                const Flexible(child: Overline('Training progress')),
              ]),
              const SizedBox(height: 6),
              Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
                Text('$thisWeek', style: context.pageTitleStyle(40)),
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('training ${thisWeek == 1 ? 'day' : 'days'} this week', style: context.sansStyle(15, color: context.c.secondary))),
              ]),
              Text('${p.sessions} ${p.sessions == 1 ? 'workout' : 'workouts'} recorded in total', style: context.numStyle(15, weight: FontWeight.w500)),
            ],
          ),
        ),
      ),
      _between,
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
      if (recent.isNotEmpty) ...[
        _between,
        const SectionHeader('Recent workouts'),
        _gap,
        GroupCard(children: [for (final w in recent) WorkoutRow(w, grouped: true)]),
      ],
      _between,
      const SectionHeader('Exercise history'),
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
