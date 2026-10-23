import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../core/go_icon.dart';
import '../activity/activity_history.dart';
import '../activity/run_walk_screens.dart';
import '../coach/coach_bubble.dart';
import '../coach/coach_contract.dart';
import '../coach/coach_prefs.dart';
import '../progress/progress_view.dart';
import '../shell/home_shell.dart';
import '../today/daily.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import '../workout/workout_panel.dart';
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
    // A workout in Workouts' panel: a compact header (the sections only), and back closes the panel, not the app.
    final inPanel = view == TrainView.workouts && ref.watch(shellProvider.select((s) => s.workout)) != null;
    final onTrain = ref.watch(shellProvider.select((s) => s.tab)) == 1;
    final coachOn = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    final noPlan = ref.watch(primaryPlanProvider) == null;
    final l = context.l10n;
    // Ask GoHard about the section in view: the primary plan on Plan, recorded training on Progress.
    final ask = switch (view) {
      TrainView.plan when noPlan => CoachContext(label: l.trainAskStartingPlan),
      TrainView.plan => CoachContext(label: ref.watch(primaryPlanProvider)?.title ?? l.trainAskYourPlan),
      TrainView.progress => CoachContext(label: l.trainAskYourProgress),
      TrainView.workouts => CoachContext(label: l.trainAskYourTraining),
    };
    return PopScope(
      canPop: !(inPanel && onTrain),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(shellProvider.notifier).closeWorkout();
      },
      child: ListView(
      // On the calm wash the shell lays behind Train; room for the floating bar at the end.
      padding: EdgeInsets.fromLTRB(context.inset, inPanel ? MediaQuery.paddingOf(context).top + 12 : TabHeader.topInset(context), context.inset, 28 + MediaQuery.paddingOf(context).bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // The guide's face is Ask GoHard's way in on Train: the speaking bust (Show coach on Train and Eat), or, with
        // that off, its small avatar beside the title. Never both.
        if (!inPanel) ...[
          TabHeader(title: l.navTrain, overline: longDate(ref.watch(todayKeyProvider)), trailing: coachOn ? null : CoachAskLauncher(ask: ask)),
          const SizedBox(height: 16),
        ],
        Segmented<TrainView>(
          values: TrainView.values, selected: view, keyPrefix: 'train',
          label: (v) => switch (v) { TrainView.workouts => l.trainSectionWorkouts, TrainView.plan => l.trainSectionPlan, TrainView.progress => l.trainSectionProgress },
          onChanged: (v) => ref.read(shellProvider.notifier).selectTrainView(v),
        ),
        // Under the sections, speaking about the one chosen: with large text its words can run long, and the sections
        // stay at the top where they are always reached.
        // One coach treatment at a time: inside a workout, its own help instead.
        if (coachOn && !inPanel) ...[
          const SizedBox(height: 14),
          TabCoach(key: const Key('train-coach'), id: 'train', say: _coachSay(context, ref, view), onAvatarTap: () => openAskGoHard(context, ask)),
        ],
        SizedBox(height: inPanel ? 6 : 20),
        // The section that was chosen fades in; the one left is simply gone, so nothing is shown twice.
        AnimatedSwitcher(
          duration: context.motion(Motion.quick), reverseDuration: Duration.zero, switchInCurve: Motion.curve,
          layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
          child: switch (view) {
            TrainView.workouts => inPanel ? const WorkoutPanel() : const _WorkoutsView(),
            TrainView.plan => const _PlanView(),
            TrainView.progress => const ProgressView(),
          },
        ),
      ],
      ),
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
  final l = context.l10n;
  final saved = ref.watch(planListProvider).where((p) => p.isDraft && !p.isArchived).firstOrNull;
  if (inProgress != null) {
    return (text: l.planStartInProgressCoach, title: l.planStartInProgressTitle, body: l.planStartInProgressBody,
        action: (label: l.planStartContinue, key: const Key('plan-builder-continue'), onPressed: () => open(PlanBuilder(initial: inProgress))));
  }
  if (saved != null) {
    return (text: l.planStartDraftCoach, title: l.planStartDraftTitle, body: l.planStartDraftBody,
        action: (label: l.planStartReview, key: const Key('plan-review-draft'), onPressed: () => open(PlanReviewScreen(planId: saved.id))));
  }
  return (text: l.planStartNewCoach, title: l.planStartNewTitle, body: l.planStartNewBody,
      action: (label: l.planStartCreate, key: const Key('create-plan'), onPressed: () => open(const CreatePlanScreen())));
}

/// What the coach says on Train, from the section in view and what is really there. Facts and next steps only: no
/// judgement of the training, no score, nothing about form.
CoachSay _coachSay(BuildContext context, WidgetRef ref, TrainView view) {
  final plan = ref.watch(primaryPlanProvider);
  final workouts = [for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted) w];
  final l = context.l10n;
  switch (view) {
    case TrainView.plan when plan == null:
      final start = _planStart(context, ref);
      return CoachSay(start.text, primary: start.action);
    case TrainView.plan:
      return CoachSay(plan!.isPaused ? l.trainCoachPlanPaused : l.trainCoachPlanWeek,
          ask: CoachContext(label: plan.title));
    case TrainView.workouts:
      return CoachSay(
          workouts.any((w) => w.isOpen) ? l.trainCoachWorkoutOpen
              : plan != null ? l.trainCoachWorkoutsPlan
              : l.trainCoachWorkoutsNoPlan,
          ask: CoachContext(label: l.trainAskYourTraining));
    case TrainView.progress:
      // One fact from the shared weekly projection, or how to set a goal. Nothing is asked of the AI.
      return CoachSay(progressCoachLine(ref.watch(currentWeekProvider), goalsSupported: ref.watch(weeklyGoalsSupportedProvider)), ask: CoachContext(label: l.trainAskYourProgress));
  }
}

Column _section(List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);

const _gap = SizedBox(height: 10), _between = SizedBox(height: 28);

class _WorkoutsView extends ConsumerWidget {
  const _WorkoutsView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted) w]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    final open = all.where((w) => w.isOpen).toList(), done = all.where((w) => !w.isOpen).toList();
    final parked = ref.watch(parkedIdsProvider);
    final sets = ref.watch(trustedSetsProvider);
    // Today's planned workouts still to start, from Today's own projection; one already open is shown below instead.
    final snapshot = ref.watch(dailySnapshotProvider);
    final l = context.l10n;
    final scheduled = switch (snapshot?.training) {
      PlannedToday(:final plan, :final occasions) => [
          for (final o in occasions)
            if (openWorkoutFor(o, all) == null && statusOf(o, plan, snapshot!.dayKey, all) == OccasionStatus.due) (plan, o),
        ],
      _ => const <(Plan, Occasion)>[],
    };
    return _section([
      if (scheduled.isNotEmpty) ...[
        SectionHeader(l.trainScheduledToday),
        _gap,
        GroupCard(children: [
          for (final (plan, o) in scheduled)
            GroupRow(
              key: Key('train-scheduled-${o.id}'), icon: Icons.fitness_center, title: o.title, subtitle: l.trainDueToday(_plannedSummary(l, o.prescription)),
              onTap: () => ref.read(shellProvider.notifier).openWorkout(WorkoutFocus.preview(plan.id, o.id)),
            ),
        ]),
        const SizedBox(height: 20),
      ],
      if (open.isNotEmpty) ...[
        SectionHeader(l.trainOpenWorkouts),
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
        GroupRow(key: const Key('start-manual'), icon: Icons.add, title: l.trainStartManual, subtitle: l.trainStartManualSubtitle,
            onTap: () => startManualWorkout(context, ref)),
        GroupRow(key: const Key('train-start-run'), icon: Icons.directions_run, title: l.trainRunWalk, subtitle: l.trainRunWalkSubtitle, onTap: () => openRunWalk(context, ref)),
        // Run / Walk's history lives here, beside starting one (Today offers only Start / Resume).
        GroupRow(key: const Key('train-run-history'), leading: const GoIcon(GoGlyph.history), title: l.trainRunWalkHistory, subtitle: l.trainRunWalkHistorySubtitle,
            onTap: () => push(context, const ActivityHistoryScreen())),
      ]),
      _between,
      // The one home for recorded sessions: the latest three (a closed session keeps its own outcome label), and the
      // whole history from the header, there even before anything is recorded.
      SectionHeader(l.trainRecentWorkouts,
          trailing: QuietLink(l.trainViewAllHistory, key: const Key('train-history'), said: l.trainViewAllHistorySaid, onPressed: () => push(context, const WorkoutHistoryScreen()))),
      _gap,
      if (done.isEmpty)
        Panel(
          key: const Key('train-recent-empty'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.trainRecentEmptyTitle, style: context.sansStyle(16, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(l.trainRecentEmptyBody, style: context.caption),
          ]),
        )
      else
        GroupCard(key: const Key('train-recent'), children: [for (final w in done.take(3)) WorkoutRow(w, grouped: true)]),
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
    final l = context.l10n;
    final status = parked ? l.trainSavedForLater : l.trainInProgress;
    void resume() => resumeWorkout(context, ref, w);
    return PhotoPanel(
      key: Key('train-open-${w.id}'),
      photo: photo ? 'assets/images/workout-hero.webp' : null,
      photoAlignment: const Alignment(1, 0.6),
      content: (context) => [
        StatusPill(status, icon: parked ? Icons.bookmark_outline : Icons.timelapse, tone: parked ? Tone.neutral : Tone.accent),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(w.title, style: context.pageTitleStyle(30))),
        Padding(padding: const EdgeInsets.only(top: 2), child: Text(l.trainOpenStatusLine(status, shortDate(w.dayKey)), style: context.sansStyle(15, color: context.c.secondary))),
        if (recorded > 0) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l.trainSetsRecorded(recorded), style: context.numStyle(15))),
      ],
      actions: (_) => [
        parked
            ? TextButton(key: Key('train-resume-${w.id}'), onPressed: resume, child: Text(l.trainResume))
            : PrimaryButton(l.trainResume, key: Key('train-resume-${w.id}'), icon: Icons.play_arrow_rounded, expand: false, onPressed: resume),
        QuietLink(l.trainDetails, key: Key('train-details-${w.id}'), said: l.trainDetailsOf(w.title), onPressed: () => ref.read(shellProvider.notifier).openWorkout(WorkoutFocus.session(w.id))),
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
    final l = context.l10n;
    final proposals = [for (final r in ref.watch(proposalsProvider).value ?? const <Stored<Proposal>>[]) if (r.value.planId == primary?.id && (r.value.state == 'open' || r.value.state == 'needs_review')) r.value];

    return _section([
      if (ctxRow?.needsReview ?? false)
        Padding(padding: const EdgeInsets.only(bottom: 14), child: StatusLine(Icons.rule, l.planNeedsReview, tone: Tone.warning)),
      // No plan: with the coach on Train, its bubble holds the one way to start (above); without it, the same action
      // here. Manual training stays a quiet alternative either way.
      if (primary == null) ...[
        if (!ref.watch(coachPrefsProvider.select((p) => p.onTabs)))
          () {
            final start = _planStart(context, ref);
            return EmptyState(start.title, start.body, action: PrimaryButton(start.action.label, key: start.action.key, onPressed: start.action.onPressed));
          }(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: QuietLink(l.planTrainWithoutPlan, key: const Key('train-manual-instead'), said: l.planTrainWithoutPlanSaid, onPressed: () => startManualWorkout(context, ref)),
        ),
      ],
      if (primary != null)
        ..._primary(context, primary, today, workouts, proposals),
      if (others.isNotEmpty) ...[
        _between,
        SectionHeader(l.planSavedAndPast),
        _gap,
        GroupCard(children: [
          for (final p in others.where((p) => !p.isArchived))
            GroupRow(
              key: Key('saved-plan-${p.id}'),
              title: p.title,
              subtitle: switch (p.lifecycle) {
                'draft' when p.isBuilt => PlanRules.usable(p.j) ? l.planSavedDraftReady(scheduleMode(p), shortDate(p.startDate)) : l.planSavedDraftEmpty(scheduleMode(p)),
                'draft' => l.planSavedDraftOld(shortDate(p.startDate)),
                'paused' => l.planSavedPaused,
                'closed' => p.closureIntent == 'stopped_early' ? l.planStoppedEarly : l.planFinishedForNow,
                'active' => l.planSavedActive,
                _ => p.lifecycle,
              },
              onTap: () => push(context, p.isDraft ? PlanReviewScreen(planId: p.id) : PlanDetailScreen(planId: p.id)),
            ),
          if (others.any((p) => p.isArchived))
            GroupRow(icon: Icons.inventory_2_outlined, tone: Tone.neutral, title: l.planArchivedCount(others.where((p) => p.isArchived).length), onTap: () => push(context, const ArchivedPlansScreen())),
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
    final l = context.l10n;
    final note = [
      if (position == 0) l.planNotStarted,
      if (plan.isPaused) l.planPaused,
      if (plan.endDate != null) l.planEnds(shortDate(plan.endDate!)) else if (plan.isOngoing) l.planOngoingNoEnd,
    ].join(' · ');
    return [
      _TrainPass(
        title: plan.title,
        // Calendar position and completion are two different facts, shown separately.
        week: position == 0 ? l.planStarts(dayMonth(plan.startDate)) : plan.isOngoing ? l.planWeekN(position) : l.planWeekNOfM(position, plan.blockWeeks),
        completion: rotation == null ? Completion.of(plan.occasions, workouts) : null,
        rotation: rotation, thisWeek: rotation == null ? 0 : creditedThisWeek(occasions, workouts, today),
        photo: plan.isActive && position > 0,
      ),
      Padding(padding: const EdgeInsets.only(top: 8), child: Text('${splitOf(ref, plan)} · ${scheduleMode(plan)}', key: const Key('plan-split'), style: context.body)),
      if (minutes != null) Text(l.planPlannedTime(minutes), key: const Key('plan-time'), style: context.caption),
      if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note, style: context.caption)),
      if (plan.isPaused) ...[
        const SizedBox(height: 14),
        StatusLine(Icons.pause_circle_outline, l.planPausedLine),
        const SizedBox(height: 12),
        PrimaryButton(l.planResume, key: const Key('plan-resume'), onPressed: () => push(context, ResumeReviewScreen(planId: plan.id))),
      ],
      if (proposals.isNotEmpty) ...[
        const SizedBox(height: 14),
        GroupCard(children: [
          for (final p in proposals)
            GroupRow(icon: Icons.tips_and_updates_outlined, tone: Tone.warning, title: l.planSuggestedChange, subtitle: p.explanation, onTap: () => push(context, ProposalReviewScreen(proposalId: p.id))),
        ]),
      ],
      if (rotation != null) ..._rotation(context, plan, today, workouts, occasions, rotation) else ..._weeks(context, plan, today, workouts),
      _between,
      SectionHeader(l.planManage),
      _gap,
      GroupCard(children: [
        if (plan.isBuilt)
          GroupRow(key: const Key('plan-edit'), icon: Icons.edit_outlined, tone: Tone.neutral, title: l.planEdit,
              subtitle: l.planEditSubtitle, onTap: () => openPlanEditor(context, ref, plan)),
        if (plan.isActive) GroupRow(key: const Key('plan-pause'), icon: Icons.pause, tone: Tone.neutral, title: l.planPause, onTap: () => pausePlanFlow(context, ref, plan)),
        if (plan.isBuilt)
          GroupRow(key: const Key('plan-duplicate'), icon: Icons.copy_outlined, tone: Tone.neutral, title: l.planDuplicate,
              subtitle: l.planDuplicateSubtitle, onTap: () => openPlanEditor(context, ref, plan, duplicate: true)),
        // A reviewed swap in the remaining workouts (a built plan's own workouts follow it). A rotation has no
        // remaining dated workouts to swap in: edit it instead.
        if (!plan.isRotating)
          GroupRow(icon: Icons.swap_horiz, tone: Tone.neutral, title: l.planReplaceMovement, onTap: () => push(context, SubstitutionRequestScreen(planId: plan.id))),
        GroupRow(icon: Icons.flag_outlined, tone: Tone.neutral, title: l.planReviewBlockRow, onTap: () => push(context, BlockReviewScreen(planId: plan.id))),
        GroupRow(icon: Icons.add, tone: Tone.neutral, title: l.planCreateDifferent, subtitle: l.planCreateDifferentSubtitle, onTap: () => push(context, const CreatePlanScreen())),
      ]),
      _gap,
      Text(l.planArchiveNote, style: context.caption),
    ];
  }

  /// Fixed weekdays and older plans: the week grid, the chosen week's days and its dated workouts.
  List<Widget> _weeks(BuildContext context, Plan plan, String today, List<Workout> workouts) {
    final weeks = planWeeks(plan, today, workouts);
    final week = weeks.where((w) => w.number == _picked).firstOrNull ?? focusWeek(weeks);
    if (week == null) return const [];
    final l = context.l10n;
    return [
      _between,
      SectionHeader(l.planChooseWeek),
      _gap,
      WeekGrid(weeks: weeks, selected: week.number, stateOf: (w) => weekStateOf(w, plan, today, workouts), onSelect: (n) => setState(() => _picked = n)),
      _between,
      SectionHeader(week.isCurrent ? l.planThisWeek : l.planWeekN(week.number), detail: week.range,
          trailing: week.completion.eligible == 0 ? null : Text(l.planCompletedOf(week.completion.completed, week.completion.eligible), style: context.numStyle(14.5))),
      if (week.completion.eligible > 0) ...[
        _gap,
        Row(children: [
          Expanded(child: ProgressRail(week.completion.fraction, label: l.planWeekRailLabel)),
          const SizedBox(width: 12),
          ExcludeSemantics(child: Text(formatPercent(week.completion.fraction), style: context.numStyle(14.5, color: context.c.secondary))),
        ]),
      ],
      const SizedBox(height: 16),
      WeekDayStrip(week: week, plan: plan, today: today, workouts: workouts),
      const SizedBox(height: 14),
      if (week.occasions.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(l.planNoWorkoutsThisWeek, style: context.caption)),
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
    final l = context.l10n;
    String? noteOf(Occasion o) => o.id == rotation.next?.id ? l.planNextInCycle : o.isVirtual ? l.planProjected : null;
    return [
      _between,
      SectionHeader(l.planYourCycle, detail: l.planCycleN(rotation.cyclesDone + 1)),
      _gap,
      _CycleStrip(cycle: rotation.cycle, position: rotation.next == null ? null : rotation.position),
      _gap,
      Text(days.isEmpty ? l.planRotationNoteEveryDay : l.planRotationNoteDays(days.map(weekdayShort).join(l.planListComma)), style: context.caption),
      _between,
      SectionHeader(l.planComingUp, detail: dateRange(today, end)),
      _gap,
      WeekDayStrip(week: days7, plan: plan, today: today, workouts: workouts),
      const SizedBox(height: 14),
      if (ahead.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(l.planNothingLeft, style: context.caption)),
      _rows([
        for (final o in ahead)
          _OccasionRow(plan: plan, occasion: o, status: statusOf(o, plan, today, workouts), today: today, rowKey: 'rotation-${o.sequenceIndex ?? o.ordinal - 1}', note: noteOf(o)),
      ]),
      if (recent.isNotEmpty) ...[
        _between,
        SectionHeader(l.planRecentSessions),
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
          if (next) Text(context.l10n.planNext, style: context.numStyle(12.5, color: c.accent)),
        ]),
      );
    }

    return Wrap(spacing: 6, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final (i, w) in cycle.indexed) ...[
        if (i > 0) ExcludeSemantics(child: Icon(Icons.arrow_forward, size: 16, color: context.c.secondary)),
        Semantics(
          label: i == position ? context.l10n.planCycleStepNextSemantics(i + 1, cycle.length, w.name) : context.l10n.planCycleStepSemantics(i + 1, cycle.length, w.name),
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
    final percent = formatPercent(done.fraction);
    final l = context.l10n;
    final r = rotation;
    final cycleLine = r == null
        ? null
        : r.next == null
            ? l.planCycleNothingLeft(r.cyclesDone + 1)
            : l.planCycleLine(r.cyclesDone + 1, r.position + 1, r.cycle.length, r.next!.title);
    return Semantics(
      container: true,
      label: r == null
          ? measured ? l.planPassSemanticsPercent(title, week, done.completed, done.eligible, percent) : l.planPassSemantics(title, week, done.completed, done.eligible)
          : l.planPassRotationSemantics(title, week, thisWeek, cycleLine!),
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
                Flexible(child: Overline(l.planTrainingPlanOverline)),
              ]),
              const SizedBox(height: 4),
              Text(title, style: context.pageTitleStyle(30)),
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(week, style: context.numStyle(16, weight: FontWeight.w600))),
              const SizedBox(height: 10),
              if (r == null) ...[
                Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
                  Text.rich(TextSpan(text: '${done.completed}', children: [TextSpan(text: ' / ${done.eligible}', style: TextStyle(color: c.secondary))]), style: context.titleStyle(28)),
                  Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(l.planWorkoutsCompleted, style: context.sansStyle(15, color: c.secondary))),
                ]),
                if (measured) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ProgressRail(done.fraction, label: l.planWorkoutsCompleted)),
                    const SizedBox(width: 10),
                    Text(percent, style: context.numStyle(15)),
                  ]),
                ],
              ] else ...[
                Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
                  Text('$thisWeek', style: context.titleStyle(28)),
                  Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(l.planSessionsThisWeek(thisWeek), style: context.sansStyle(15, color: c.secondary))),
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
String _plannedSummary(AppLocalizations l, List<Prescription> prescription) {
  final sets = prescription.fold(0, (n, e) => n + (e.targetSets ?? 0));
  return [l.planExerciseCount(prescription.length), if (sets != 0) l.planPlannedSetCount(sets)].join(' · ');
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
    final l = context.l10n;
    final summary = _plannedSummary(l, o.prescription);
    final moved = o.wasMoved ? l.planMovedOriginally(shortDate(o.originalDate)) : null;
    final extra = [?moved, ?note].join(' · ');
    // With large text the state sits under the title instead of squeezing it.
    final below = MediaQuery.textScalerOf(context).scale(10) > 13;
    final row = Pressable(
      key: Key(rowKey ?? 'occasion-${o.weekNumber}-${o.ordinal}'),
      borderRadius: BorderRadius.circular(Radii.field),
      semanticLabel: [o.title, longDate(o.scheduledDate), if (isToday) l.planTodayLower, summary, if (extra.isNotEmpty) extra, status.label].join(l.planListComma),
      onTap: () => showOccasionSheet(context, ref, plan, o),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
        child: Row(children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(weekdayShort(day.weekday), style: context.sansStyle(13, color: isToday ? c.text : c.secondary, weight: isToday ? FontWeight.w700 : FontWeight.w400)),
              Text('${day.day}', style: context.numStyle(18)),
              if (isToday) Text(l.planTodayLabel, style: context.sansStyle(12.5, color: c.accent, weight: FontWeight.w700)),
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
          Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.chevron_right, size: 22, color: c.secondary)),
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
