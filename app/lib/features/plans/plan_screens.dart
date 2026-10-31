import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/catalog_names.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../plus/entitlement.dart';
import '../plus/plus_screen.dart';
import '../shell/home_shell.dart';
import '../today/daily.dart';
import '../workout/workout_flow.dart';
import 'builder/plan_builder_screen.dart';
import 'plan_actions.dart';
import 'plan_l10n.dart';
import 'plan_progress.dart';
import 'plan_repository.dart';
import 'plan_rules.dart';
import 'schedule_rules.dart';

class _WeekdayChecks extends StatelessWidget {
  const _WeekdayChecks({required this.selected, required this.onChanged});
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(children: [
        for (var d = 1; d <= 7; d++)
          SizedBox(
            width: 104,
            child: CheckboxListTile(
              key: Key('weekday-$d'), dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
              title: Text(weekdayShort(d), style: context.sansStyle(15)), value: selected.contains(d),
              onChanged: (v) => onChanged(([...selected.where((x) => x != d), if (v ?? false) d]..sort())),
            ),
          ),
      ]);
}

/// The proposed plan itself: commitment, dates and real workout content. Start is the only commitment, and it
/// can only commit exactly what is shown here.
class PlanReviewScreen extends ConsumerStatefulWidget {
  const PlanReviewScreen({super.key, required this.planId, this.closePrimary = false});
  final String planId;

  /// True when this draft continues a block that is being finished as part of starting it.
  final bool closePrimary;
  @override
  ConsumerState<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends ConsumerState<PlanReviewScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _editSchedule(Plan plan) async {
    var start = plan.startDate, weeks = plan.blockWeeks;
    var days = ((plan.setup?['weekdays'] as List?) ?? const [1, 3, 5]).cast<int>();
    final sessions = (plan.setup?['sessionsPerWeek'] as int?) ?? days.length;
    final l = context.l10n;
    final apply = await showGoSheet<bool>(
      context,
      title: l.planChangeSchedule,
      builder: (sheet) => StatefulBuilder(builder: (context, set) {
        final check = ScheduleRules.generate(start, days, sessions, weeks, plan.minRecoveryDays);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              GroupCard(children: [
                GroupRow(key: const Key('draft-start'), icon: Icons.event, title: l.planStartDate, subtitle: longDate(start), onTap: () async {
                  final d = await pickDay(context, initial: start, first: ref.read(todayKeyProvider), help: l.planStartDate);
                  if (d != null) set(() => start = d);
                }),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                  initialValue: weeks, decoration: InputDecoration(labelText: l.planBlockLength), dropdownColor: context.c.surface,
                  items: [for (final w in const [4, 8, 12]) DropdownMenuItem(value: w, child: Text(l.planWeeksPlain(w)))], onChanged: (v) => set(() => weeks = v ?? weeks)),
              const SizedBox(height: 8),
              Text(l.planTrainingDaysChoose(sessions), style: context.caption),
              _WeekdayChecks(selected: days, onChanged: (v) => set(() => days = v)),
              if (check.errors.isNotEmpty) StatusLine(Icons.error_outline, planErrorText(l, check.errors.first), tone: Tone.error),
              const SizedBox(height: 12),
              PrimaryButton(l.planUpdateDraft, key: const Key('draft-update'), onPressed: check.errors.isEmpty ? () => Navigator.pop(sheet, true) : null),
              Center(child: TextButton(onPressed: () => Navigator.pop(sheet, false), child: Text(l.planCancelKeepSchedule))),
            ]);
      }),
    );
    if (apply != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final answer = await ref.read(planRepositoryProvider).updateDraft(plan, startDate: start, weekdays: days, blockWeeks: weeks);
      if (!mounted) return;
      setState(() => _error = answer.accepted ? null : answer.unreachable ? l.planUnreachableDraft : planErrorText(l, answer.code ?? ''));
    } on ScheduleRefused catch (e) {
      setState(() => _error = planErrorText(l, e.codes.first));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(Plan plan, Plan? current) async {
    final today = ref.read(todayKeyProvider);
    final l = context.l10n;
    if (current != null) {
      final open = ref.read(workoutListProvider).where((w) => w.isOpen && w.planId == current.id).firstOrNull;
      final ok = await confirm(context,
          title: widget.closePrimary ? l.planFinishAndStartTitle(current.title) : l.planPauseAndStartTitle(current.title),
          body: [
            widget.closePrimary ? l.planStartFinishBody(current.title, plan.title, longDate(plan.startDate)) : l.planStartPauseBody(current.title, plan.title, longDate(plan.startDate)),
            if (open != null) l.planOpenWorkoutStaysOpen(open.title),
          ].join('\n\n'),
          action: widget.closePrimary ? l.planFinishAndStart : l.planPauseAndStart);
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final message = plan.startDate.compareTo(today) > 0 ? l.planSavedStarts(shortDate(plan.startDate)) : l.planStarted;
    final done = await runPlanDecision(context,
        () => ref.read(planRepositoryProvider).activate(plan, today: today, replacePrimaryId: current?.id, closePrimary: widget.closePrimary && current != null),
        saved: '');
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) {
      ref.read(shellProvider.notifier).switchTab(0);
      Navigator.of(context).popUntil((r) => r.isFirst);
      // Shown once back on the shell, so it sits above the navigation bar instead of covering it.
      messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2200)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planListProvider).where((p) => p.id == widget.planId).firstOrNull;
    if (plan == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final primary = ref.watch(primaryPlanProvider);
    final current = primary?.id == plan.id ? null : primary;
    final today = ref.watch(todayKeyProvider);
    final workouts = ref.watch(workoutListProvider);
    final rotating = plan.isRotating;
    // Fixed plans: their real dated first week. A rotation: its next sessions as the shared projection lays them out.
    final rows = rotating ? planOccasions(plan, today, workouts).take(6).toList() : plan.occasions.where((o) => o.weekNumber == 1).toList();
    final usable = !plan.isBuilt || PlanRules.usable(plan.j);
    final minutes = plannedMinutes(plan);
    final schedule = plan.schedule;
    final names = {for (final w in plan.workouts) w.id: w.name};
    final l = context.l10n;
    final exNames = ref.watch(exerciseNamesProvider), locale = Localizations.localeOf(context);
    return AppPage(
      title: plan.title,
      bottom: !plan.isDraft
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
              if (!usable) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.info_outline, l.planDraftNeedsExercises)),
              PrimaryButton(current == null ? l.planStartThis : widget.closePrimary ? l.planFinishBlockStart : l.planReplaceCurrent, key: const Key('plan-start'), busy: _busy,
                  onPressed: usable ? () => _start(plan, current) : null),
              TextButton(key: const Key('plan-save-later'), onPressed: () => Navigator.pop(context), child: Text(l.planSaveForLater)),
            ]),
      children: [
        SectionLabel(plan.isDraft ? l.planDraftNothingScheduled : l.planLifecycle(plan.lifecycle)),
        const SizedBox(height: 10),
        Text(plan.isBuilt ? '${splitOf(ref, plan)} · ${scheduleMode(plan)}' : planSplit(plan, (_) => null), style: context.body),
        if (plan.isBuilt && minutes != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l.planPlannedTime(minutes), style: context.caption)),
        const SizedBox(height: 6),
        Text(
            rotating
                ? [plan.isOngoing ? l.planOngoing : l.planWeeksPlain(plan.blockWeeks), l.planStartsOn(longDate(plan.startDate)), if (plan.endDate != null) l.planEndsOn(longDate(plan.endDate!))].join(' · ')
                : [l.planWeeksPlain(plan.blockWeeks), l.planWorkoutsPlain(plan.occasions.length), l.planDateSpan(longDate(plan.startDate), plan.endDate == null ? l.valueUnknown : longDate(plan.endDate!))].join(' · '),
            style: context.caption),
        if (rotating && schedule != null) ...[
          const SizedBox(height: 6),
          Text(l.planCycleList(schedule.cycle.map((id) => names[id] ?? l.planWorkoutFallback).join(l.planSequenceArrow)), style: context.caption),
          Text(schedule.trainingDays.isEmpty ? l.planAnyDayNext : l.planTrainingDaysList((schedule.trainingDays.toList()..sort()).map(weekdayShort).join(l.planListComma)), style: context.caption),
        ],
        const SizedBox(height: 6),
        Text(l.planFirstWorkout(rows.isEmpty ? l.valueUnknown : l.planTitleDate(rows.first.title, longDate(rows.first.scheduledDate))), style: context.caption),
        if (plan.isDraft && !plan.isBuilt)
          Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(key: const Key('plan-edit-schedule'), onPressed: _busy ? null : () => _editSchedule(plan), icon: const Icon(Icons.edit_calendar_outlined, size: 18), label: Text(l.planChangeDates))),
        if (plan.isDraft && plan.isBuilt)
          Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(key: const Key('plan-edit'), onPressed: _busy ? null : () => openPlanEditor(context, ref, plan), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(l.planEdit))),
        if (current != null) ...[
          const SizedBox(height: 8),
          Panel(child: StatusLine(Icons.swap_horiz, widget.closePrimary ? l.planFollowingFinish(current.title) : l.planFollowingPause(current.title))),
        ],
        const SizedBox(height: 20),
        SectionLabel(rotating ? l.planNextSessions : l.planFirstWeek),
        if (rotating) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.planRotationReviewNote, style: context.caption)),
        for (final o in rows) ...[
          const SizedBox(height: 14),
          Text('${rotating ? shortDate(o.scheduledDate) : weekdayName(weekdayOf(o.scheduledDate))} · ${o.title}', style: context.sansStyle(16, weight: FontWeight.w600)),
          for (final (i, e) in o.prescription.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: context.numStyle(13.5, color: context.c.secondary, weight: FontWeight.w400))),
                Expanded(
                  child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 10, children: [
                    Text(exNames.name(e.catalogKey, e.name, locale), style: context.sansStyle(15)),
                    Text(prescriptionOf(e), style: context.numStyle(14, color: context.c.secondary, weight: FontWeight.w500)),
                  ]),
                ),
              ]),
            ),
          if (o.prescription.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.planNoExercisesYetDot, style: context.caption)),
          const SizedBox(height: 12),
          const Rule(),
        ],
        const SizedBox(height: 12),
        Text(
            !plan.isBuilt
                ? l.planRepeatOld
                : rotating
                    ? l.planRepeatRotation
                    : l.planRepeatFixed,
            style: context.caption),
      ],
    );
  }
}

/// Resuming shows every remaining date before anything changes. Keep paused leaves the schedule untouched.
class ResumeReviewScreen extends ConsumerStatefulWidget {
  const ResumeReviewScreen({super.key, required this.planId});
  final String planId;
  @override
  ConsumerState<ResumeReviewScreen> createState() => _ResumeReviewScreenState();
}

class _ResumeReviewScreenState extends ConsumerState<ResumeReviewScreen> {
  String? _resumeDate;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planListProvider).where((p) => p.id == widget.planId).firstOrNull;
    if (plan == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final today = ref.watch(todayKeyProvider);
    final resumeDate = _resumeDate ?? today;
    final schedule = scheduleOf(plan, ref.watch(workoutListProvider));
    final changes = PlanRepository.resumeChanges(plan, schedule, resumeDate);
    final v = ScheduleRules.validate(schedule, changes, plan.minRecoveryDays);
    final primary = ref.watch(primaryPlanProvider);
    final displaces = primary != null && primary.id != plan.id ? primary : null;
    final titles = {for (final o in plan.occasions) o.id: o.title};
    final l = context.l10n;
    return AppPage(
      title: l.planResumeTitle(plan.title),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!v.isValid) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, planErrorText(l, v.errors.first), tone: Tone.error)),
        PrimaryButton(l.planResumeAccept, key: const Key('resume-accept'), onPressed: !v.isValid ? null : () async {
          if (await runPlanDecision(context, () => ref.read(planRepositoryProvider).resume(plan, schedule, changes, today: today), saved: l.planResumedToast) && context.mounted) Navigator.pop(context);
        }),
        TextButton(key: const Key('resume-keep-paused'), onPressed: () => Navigator.pop(context), child: Text(l.planKeepPaused)),
      ]),
      children: [
        GroupCard(children: [
          GroupRow(key: const Key('resume-date'), icon: Icons.event, title: l.planNextWorkoutOn, subtitle: longDate(resumeDate), onTap: () async {
            final d = await pickDay(context, initial: resumeDate, first: today, help: l.planResumeDateHelp);
            if (d != null) setState(() => _resumeDate = d);
          }),
        ]),
        if (displaces != null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.swap_horiz, l.planResumeDisplaces(displaces.title), tone: Tone.warning)),
        const SizedBox(height: 14),
        Text(changes.isEmpty
            ? l.planResumeNoChanges
            : l.planResumeShifts, style: context.caption),
        for (final c in changes) ListRow(title: titles[c.occasionId] ?? l.planWorkoutFallback, subtitle: l.planDateMove(shortDate(c.from), shortDate(c.to))),
        if (v.blockEnd != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(l.planBlockWouldEnd(longDate(v.blockEnd!)), style: context.body)),
      ],
    );
  }
}

Map<OccasionStatus, int> blockCounts(Plan plan, String today, List<Workout> workouts) {
  final counts = {for (final s in OccasionStatus.values) s: 0};
  for (final o in plan.occasions) {
    final s = statusOf(o, plan, today, workouts);
    counts[s] = counts[s]! + 1;
  }
  return counts;
}

/// Block review: honest counts from recorded occasions. Finishing closes the block; it never claims the goal is achieved.
class BlockReviewScreen extends ConsumerWidget {
  const BlockReviewScreen({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planListProvider).where((p) => p.id == planId).firstOrNull;
    if (plan == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final today = ref.watch(todayKeyProvider);
    final workouts = ref.watch(workoutListProvider);
    final c = blockCounts(plan, today, workouts);
    final remaining = c[OccasionStatus.upcoming]! + c[OccasionStatus.due]! + c[OccasionStatus.paused]! + c[OccasionStatus.inProgress]!;
    final open = workouts.where((w) => w.isOpen && w.planId == plan.id).firstOrNull;
    final repo = ref.read(planRepositoryProvider);
    final l = context.l10n;

    Future<void> close(String intent, String title, String body, String action) async {
      if (!await confirm(context, title: title, body: [body, if (open != null) l.planCloseOpenWorkout(open.title)].join('\n\n'), action: action) || !context.mounted) return;
      if (await runPlanDecision(context, () => repo.close(plan, intent: intent, today: today), saved: l.planBlockClosedToast) && context.mounted) Navigator.pop(context);
    }

    return AppPage(title: l.planReviewBlock, children: [
      Text(plan.title, style: context.sansStyle(16, weight: FontWeight.w600)),
      Text(l.planDateSpan(longDate(plan.startDate), plan.endDate == null ? l.valueUnknown : longDate(plan.endDate!)), style: context.caption),
      const SizedBox(height: 16),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(children: [
          for (final (i, (label, n)) in [
            (l.planCountFinished, c[OccasionStatus.finished]!), (l.planCountPartial, c[OccasionStatus.partial]!), (l.planWeekSkipped, c[OccasionStatus.skipped]!),
            (l.planWeekMissed, c[OccasionStatus.missed]!), (l.planCountRemaining, remaining),
          ].indexed) ...[
            if (i > 0) const Rule(),
            Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [Expanded(child: Text(label, style: context.body)), Text('$n', style: context.titleStyle(21))])),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Text(l.planCountsNote, style: context.caption),
      if (plan.isClosed)
        Padding(padding: const EdgeInsets.only(top: 16), child: StatusLine(Icons.flag_outlined, plan.closureIntent == 'stopped_early' ? l.planBlockStoppedEarly : l.planBlockFinished))
      else ...[
        const SizedBox(height: 22),
        PrimaryButton(l.planContinueGoal, key: const Key('block-continue'), onPressed: () async {
          // Continuing makes a new saved plan (docs/PLUS_PREVIEW.md): the limit is explained before anything is asked.
          final plans = ref.read(planListProvider), existing = plans.where((p) => !p.isArchived).length;
          final gate = planGate(ref.read(plusProvider), plans);
          if (gate != CreateGate.ok) return showPlusLimit(context, PlusLimit.plans, gate: gate, existing: existing);
          final start = await pickDay(context, initial: today, first: today, help: l.planNextBlockStarts);
          if (start == null || !context.mounted) return;
          final answer = await repo.continueGoal(plan, start);
          if (!context.mounted) return;
          if (answer.code == 'PLAN_LIMIT') return showPlusLimit(context, PlusLimit.plans, gate: CreateGate.limit, existing: existing);
          if (!answer.accepted) return toast(context, answer.unreachable ? l.planUnreachableNothingCreated : planErrorText(l, answer.code ?? ''));
          await push(context, PlanReviewScreen(planId: answer.data!['planId'] as String, closePrimary: true));
        }),
        const SizedBox(height: 4),
        Text(l.planContinueNote, style: context.caption),
        const SizedBox(height: 14),
        SecondaryButton(l.planFinishForNow, key: const Key('block-finish'), onPressed: () => close('finish_for_now', l.planCloseBlockTitle, l.planCloseBlockBody, l.planCloseBlockAction)),
        if (remaining > 0) ...[
          const SizedBox(height: 8),
          SecondaryButton(l.planStopEarly, key: const Key('block-stop'), onPressed: () => close('stopped_early', l.planStopTitle, l.planStopBody(remaining), l.planStopAction)),
        ],
      ],
    ]);
  }
}

/// A saved, paused or closed plan that is not driving Today.
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});
  final String planId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planListProvider).where((p) => p.id == planId).firstOrNull;
    if (plan == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final today = ref.watch(todayKeyProvider);
    final workouts = ref.watch(workoutListProvider);
    final isPrimary = ref.watch(primaryPlanProvider)?.id == plan.id;
    final l = context.l10n;
    return AppPage(title: plan.title, children: [
      SectionLabel(plan.isClosed ? (plan.closureIntent == 'stopped_early' ? l.planStoppedEarly : l.planFinishedForNow) : l.planLifecycle(plan.lifecycle)),
      const SizedBox(height: 8),
      Text(plan.isBuilt ? '${splitOf(ref, plan)} · ${scheduleMode(plan)}' : planSplit(plan, (_) => null), style: context.body),
      Text(l.planDateSpan(longDate(plan.startDate), plan.endDate == null ? (plan.isOngoing ? l.planOngoingLower : l.valueUnknown) : longDate(plan.endDate!)), style: context.caption),
      const SizedBox(height: 14),
      if (plan.isPaused && !isPrimary) PrimaryButton(l.planResumeAsPrimary, key: const Key('plan-resume'), onPressed: () => push(context, ResumeReviewScreen(planId: plan.id))),
      if (plan.isClosed) SecondaryButton(l.planReviewBlock, onPressed: () => push(context, BlockReviewScreen(planId: plan.id))),
      if (plan.isBuilt && !plan.isClosed)
        Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(key: const Key('plan-edit'), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(l.planEdit), onPressed: () => openPlanEditor(context, ref, plan))),
      if (plan.isBuilt)
        Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(key: const Key('plan-duplicate'), icon: const Icon(Icons.copy_outlined, size: 18), label: Text(l.planDuplicateAsNew), onPressed: () => openPlanEditor(context, ref, plan, duplicate: true))),
      if (!isPrimary)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('plan-archive'),
            icon: Icon(plan.isArchived ? Icons.unarchive_outlined : Icons.inventory_2_outlined, size: 18),
            label: Text(plan.isArchived ? l.planUnarchive : l.planArchiveHide),
            onPressed: () async {
              if (await runPlanDecision(context, () => ref.read(planRepositoryProvider).archive(plan, !plan.isArchived), saved: plan.isArchived ? l.planRestoredToast : l.planArchivedToast) && context.mounted) Navigator.pop(context);
            },
          ),
        ),
      const SizedBox(height: 10),
      // A closed rotation has nothing ahead; an open one shows its projected next sessions too.
      for (final o in plan.isClosed ? plan.occasions : planOccasions(plan, today, workouts, ahead: 3))
        ListRow(
            title: o.title,
            subtitle: [
              shortDate(o.scheduledDate),
              o.sequenceIndex == null ? l.planWeekLower(o.weekNumber) : l.planSessionLower(o.sequenceIndex! + 1),
              if (o.isVirtual) l.planProjectedLower,
              plan.isClosed && statusOf(o, plan, today, workouts) == OccasionStatus.upcoming ? l.planNotDone : statusOf(o, plan, today, workouts).label,
            ].join(' · ')),
    ]);
  }
}

/// The plan's split in words, with the starter's real name once the templates are read.
String splitOf(WidgetRef ref, Plan plan) {
  final t = ref.watch(planTemplatesProvider).value;
  return planSplit(plan, (id) => t?.templates.where((x) => x.id == id).firstOrNull?.name ?? currentL10n.planStarterSplit);
}

class ArchivedPlansScreen extends ConsumerWidget {
  const ArchivedPlansScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(title: context.l10n.planArchivedTitle, children: [
        Text(context.l10n.planArchivedNote, style: context.caption),
        for (final p in ref.watch(planListProvider).where((p) => p.isArchived)) ListRow(title: p.title, subtitle: context.l10n.planLifecycle(p.lifecycle), onTap: () => push(context, PlanDetailScreen(planId: p.id))),
      ]);
}

/// Request an equipment change for the remaining unstarted workouts. It produces a proposal to review.
class SubstitutionRequestScreen extends ConsumerStatefulWidget {
  const SubstitutionRequestScreen({super.key, required this.planId});
  final String planId;
  @override
  ConsumerState<SubstitutionRequestScreen> createState() => _SubstitutionRequestScreenState();
}

class _SubstitutionRequestScreenState extends ConsumerState<SubstitutionRequestScreen> {
  String? _from, _error;
  CatalogExercise? _to;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planListProvider).where((p) => p.id == widget.planId).firstOrNull;
    if (plan == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final eligible = {for (final s in scheduleOf(plan, ref.watch(workoutListProvider))) if (s.isEligible) s.id};
    final movements = {for (final o in plan.occasions) if (eligible.contains(o.id)) for (final e in o.prescription) if (e.catalogKey != null) e.catalogKey!: e.name};
    final l = context.l10n;
    final names = ref.watch(exerciseNamesProvider), locale = Localizations.localeOf(context);
    return AppPage(
      title: l.planReplaceMovementTitle,
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        PrimaryButton(l.planShowChange, key: const Key('substitution-submit'), busy: _busy, onPressed: _from == null || _to?.key == null ? null : () async {
          setState(() {
            _busy = true;
            _error = null;
          });
          final answer = await ref.read(planRepositoryProvider).proposeSubstitution(plan, _from!, _to!.key!);
          if (!context.mounted) return;
          setState(() => _busy = false);
          if (answer.accepted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ProposalReviewScreen(proposalId: answer.data!['id'] as String)));
          } else {
            setState(() => _error = answer.unreachable
                ? l.planUnreachableNothingChanged
                : answer.code == 'PROPOSAL_DECLINED_UNCHANGED' ? l.planProposalDeclinedUnchanged : l.planNothingToChange);
          }
        }),
      ]),
      children: [
        Text(l.planSubstitutionNote, style: context.caption),
        const SizedBox(height: 14),
        SectionLabel(l.planReplaceLabel),
        const SizedBox(height: 8),
        if (movements.isEmpty) Text(l.planNoMovement, style: context.caption),
        for (final e in movements.entries) ChoiceTile<String?>(key: Key('substitute-from-${e.key}'), value: e.key, groupValue: _from, title: names.name(e.key, e.value, locale), onChanged: (v) => setState(() => _from = v)),
        const SizedBox(height: 10),
        GroupCard(children: [
          GroupRow(key: const Key('substitute-to'), icon: Icons.swap_horiz, title: l.planWith, subtitle: _to == null ? l.planChooseMovement : names.name(_to!.key, _to!.name, locale), onTap: () async {
            final e = await push<CatalogExercise>(context, ExercisePicker(title: l.planReplaceWith));
            if (e != null) setState(() => _to = e);
          }),
        ]),
        const SizedBox(height: 8),
        if (_to != null && _to!.key == null) StatusLine(Icons.info_outline, l.planCustomNotInPlanChange, tone: Tone.warning),
      ],
    );
  }
}

/// A proposed future change: reason, exact scope and before/after. Accept applies exactly this; Keep current declines it.
class ProposalReviewScreen extends ConsumerStatefulWidget {
  const ProposalReviewScreen({super.key, required this.proposalId});
  final String proposalId;
  @override
  ConsumerState<ProposalReviewScreen> createState() => _ProposalReviewScreenState();
}

class _ProposalReviewScreenState extends ConsumerState<ProposalReviewScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _decide(Proposal p, bool accept) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final l = context.l10n;
    final answer = await ref.read(planRepositoryProvider).decide(p, accept: accept);
    if (!mounted) return;
    setState(() => _busy = false);
    if (answer.accepted) {
      toast(context, accept ? l.planChangeApplied : l.planKeptCurrent);
      Navigator.pop(context);
    } else {
      setState(() => _error = answer.unreachable
          ? l.planUnreachableNothingChanged
          : l.planSuggestionStale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = (ref.watch(proposalsProvider).value ?? const <Stored<Proposal>>[]).where((r) => r.value.id == widget.proposalId).firstOrNull?.value;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final plan = ref.watch(planListProvider).where((x) => x.id == p.planId).firstOrNull;
    final occasions = {for (final o in plan?.occasions ?? const <Occasion>[]) o.id: o};
    final stale = p.state == 'needs_review', open = p.state == 'open';
    final l = context.l10n;
    return AppPage(
      title: l.planSuggestedChangeTitle,
      bottom: !(open || stale)
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
              if (open) PrimaryButton(l.planAcceptChange, key: const Key('proposal-accept'), busy: _busy, onPressed: () => _decide(p, true)),
              TextButton(key: const Key('proposal-decline'), onPressed: _busy ? null : () => _decide(p, false), child: Text(open ? l.planKeepCurrent : l.planDismissSuggestion)),
            ]),
      children: [
        Text(p.explanation, style: context.body),
        const SizedBox(height: 12),
        if (stale) StatusLine(Icons.rule, l.planProposalStaleLine, tone: Tone.warning),
        if (p.state == 'accepted') StatusLine(Icons.check_circle_outline, l.planAcceptedLine),
        if (p.state == 'declined') StatusLine(Icons.info_outline, l.planDeclinedLine),
        const SizedBox(height: 16),
        SectionLabel(l.planAffects(p.affectedOccasionIds.length)),
        if (p.kind == 'schedule')
          for (final m in p.moves) ListRow(title: occasions[m['occasionId']]?.title ?? l.planWorkoutFallback, subtitle: l.planProposalMove(shortDate(m['from'] as String), shortDate(m['to'] as String)))
        else ...[
          const SizedBox(height: 8),
          Text(l.planProposalNow('${p.change['fromCatalogKey']}', '${p.change['toName']}'), style: context.body),
          for (final id in p.affectedOccasionIds)
            if (occasions[id] != null) ListRow(title: occasions[id]!.title, subtitle: [shortDate(occasions[id]!.scheduledDate), l.planWeekLower(occasions[id]!.weekNumber)].join(' · ')),
        ],
        const SizedBox(height: 10),
        Text(l.planProposalNote, style: context.caption),
      ],
    );
  }
}
