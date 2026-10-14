import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';
import '../today/daily.dart';
import '../workout/workout_flow.dart';
import 'builder/plan_builder_screen.dart';
import 'plan_actions.dart';
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
    final apply = await showGoSheet<bool>(
      context,
      title: 'Change the schedule',
      builder: (sheet) => StatefulBuilder(builder: (context, set) {
        final check = ScheduleRules.generate(start, days, sessions, weeks, plan.minRecoveryDays);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              GroupCard(children: [
                GroupRow(key: const Key('draft-start'), icon: Icons.event, title: 'Start date', subtitle: longDate(start), onTap: () async {
                  final d = await pickDay(context, initial: start, first: ref.read(todayKeyProvider), help: 'Start date');
                  if (d != null) set(() => start = d);
                }),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                  initialValue: weeks, decoration: const InputDecoration(labelText: 'Block length'), dropdownColor: context.c.surface,
                  items: [for (final w in const [4, 8, 12]) DropdownMenuItem(value: w, child: Text('$w weeks'))], onChanged: (v) => set(() => weeks = v ?? weeks)),
              const SizedBox(height: 8),
              Text('Training days (choose $sessions)', style: context.caption),
              _WeekdayChecks(selected: days, onChanged: (v) => set(() => days = v)),
              if (check.errors.isNotEmpty) StatusLine(Icons.error_outline, ScheduleRules.describe(check.errors.first), tone: Tone.error),
              const SizedBox(height: 12),
              PrimaryButton('Update the draft', key: const Key('draft-update'), onPressed: check.errors.isEmpty ? () => Navigator.pop(sheet, true) : null),
              Center(child: TextButton(onPressed: () => Navigator.pop(sheet, false), child: const Text('Cancel and keep the reviewed schedule'))),
            ]);
      }),
    );
    if (apply != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final answer = await ref.read(planRepositoryProvider).updateDraft(plan, startDate: start, weekdays: days, blockWeeks: weeks);
      if (!mounted) return;
      setState(() => _error = answer.accepted ? null : answer.unreachable ? 'Your account cannot be reached. The draft is unchanged.' : ScheduleRules.describe(answer.code ?? ''));
    } on ScheduleRefused catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(Plan plan, Plan? current) async {
    final today = ref.read(todayKeyProvider);
    if (current != null) {
      final open = ref.read(workoutListProvider).where((w) => w.isOpen && w.planId == current.id).firstOrNull;
      final ok = await confirm(context,
          title: widget.closePrimary ? 'Finish ${current.title} and start this plan?' : 'Pause ${current.title} and start this plan?',
          body: '${widget.closePrimary ? '"${current.title}" will be closed as finished for now.' : '"${current.title}" will be paused, not deleted. You can resume it later.'} '
              '"${plan.title}" becomes your primary plan from ${longDate(plan.startDate)}. All recorded workouts are kept.'
              '${open == null ? '' : '\n\nYour open workout "${open.title}" stays open with its recorded sets; you can still finish it.'}',
          action: widget.closePrimary ? 'Finish and start' : 'Pause and start');
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final message = plan.startDate.compareTo(today) > 0 ? 'Plan saved. It starts ${shortDate(plan.startDate)}.' : 'Your plan has started.';
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
    return AppPage(
      title: plan.title,
      bottom: !plan.isDraft
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
              if (!usable) const Padding(padding: EdgeInsets.only(bottom: 10), child: StatusLine(Icons.info_outline, 'Draft — add exercises to use it. Every scheduled workout needs at least one exercise before the plan can start.')),
              PrimaryButton(current == null ? 'Start this plan' : widget.closePrimary ? 'Finish current block and start' : 'Replace my current plan', key: const Key('plan-start'), busy: _busy,
                  onPressed: usable ? () => _start(plan, current) : null),
              TextButton(key: const Key('plan-save-later'), onPressed: () => Navigator.pop(context), child: const Text('Save for later')),
            ]),
      children: [
        SectionLabel(plan.isDraft ? 'Draft · nothing is scheduled yet' : plan.lifecycle),
        const SizedBox(height: 10),
        Text(plan.isBuilt ? '${splitOf(ref, plan)} · ${scheduleMode(plan)}' : planSplit(plan, (_) => null), style: context.body),
        if (plan.isBuilt && minutes != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Planned time $minutes min', style: context.caption)),
        const SizedBox(height: 6),
        Text(
            rotating
                ? '${plan.isOngoing ? 'Ongoing' : '${plan.blockWeeks} weeks'} · starts ${longDate(plan.startDate)}${plan.endDate == null ? '' : ' · ends ${longDate(plan.endDate!)}'}'
                : '${plan.blockWeeks} weeks · ${plan.occasions.length} workouts · ${longDate(plan.startDate)} to ${plan.endDate == null ? '—' : longDate(plan.endDate!)}',
            style: context.caption),
        if (rotating && schedule != null) ...[
          const SizedBox(height: 6),
          Text('Cycle: ${schedule.cycle.map((id) => names[id] ?? 'Workout').join(' → ')}', style: context.caption),
          Text(schedule.trainingDays.isEmpty ? 'Any day: the next workout is there whenever you train.' : 'Training days: ${(schedule.trainingDays.toList()..sort()).map(weekdayShort).join(', ')}', style: context.caption),
        ],
        const SizedBox(height: 6),
        Text('First workout: ${rows.isEmpty ? '—' : '${rows.first.title}, ${longDate(rows.first.scheduledDate)}'}', style: context.caption),
        if (plan.isDraft && !plan.isBuilt)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('plan-edit-schedule'), onPressed: _busy ? null : () => _editSchedule(plan), icon: const Icon(Icons.edit_calendar_outlined, size: 18), label: const Text('Change dates, days or length'))),
        if (plan.isDraft && plan.isBuilt)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('plan-edit'), onPressed: _busy ? null : () => openPlanEditor(context, ref, plan), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit plan'))),
        if (current != null) ...[
          const SizedBox(height: 8),
          Panel(child: StatusLine(Icons.swap_horiz, 'You are following "${current.title}". Starting this plan will ${widget.closePrimary ? 'finish' : 'pause'} it. That needs your explicit confirmation; nothing is deleted.')),
        ],
        const SizedBox(height: 20),
        SectionLabel(rotating ? 'Next sessions' : 'First week'),
        if (rotating) Padding(padding: const EdgeInsets.only(top: 6), child: Text('A rotation has no fixed dates. These are the days the sequence would fall on from today; it waits for you if you miss one.', style: context.caption)),
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
                    Text(e.name, style: context.sansStyle(15)),
                    Text(prescriptionOf(e), style: context.numStyle(14, color: context.c.secondary, weight: FontWeight.w500)),
                  ]),
                ),
              ]),
            ),
          if (o.prescription.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('No exercises yet.', style: context.caption)),
          const SizedBox(height: 12),
          const Rule(),
        ],
        const SizedBox(height: 12),
        Text(
            !plan.isBuilt
                ? 'The same workouts repeat each week with a recovery day between them. Targets are guidance; what you record is what counts.'
                : rotating
                    ? 'The sequence continues in order across weeks; it never restarts on Monday. It moves on only when you finish or skip a workout. Targets are guidance; what you record is what counts.'
                    : 'These workouts repeat on the same weekdays each week. Targets are guidance; what you record is what counts.',
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
    return AppPage(
      title: 'Resume ${plan.title}',
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!v.isValid) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, ScheduleRules.describe(v.errors.first), tone: Tone.error)),
        PrimaryButton('Resume with these dates', key: const Key('resume-accept'), onPressed: !v.isValid ? null : () async {
          if (await runPlanDecision(context, () => ref.read(planRepositoryProvider).resume(plan, schedule, changes, today: today), saved: 'Plan resumed.') && context.mounted) Navigator.pop(context);
        }),
        TextButton(key: const Key('resume-keep-paused'), onPressed: () => Navigator.pop(context), child: const Text('Keep paused')),
      ]),
      children: [
        GroupCard(children: [
          GroupRow(key: const Key('resume-date'), icon: Icons.event, title: 'Next workout on', subtitle: longDate(resumeDate), onTap: () async {
            final d = await pickDay(context, initial: resumeDate, first: today, help: 'Resume date');
            if (d != null) setState(() => _resumeDate = d);
          }),
        ]),
        if (displaces != null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.swap_horiz, 'This makes it your primary plan and pauses "${displaces.title}".', tone: Tone.warning)),
        const SizedBox(height: 14),
        Text(changes.isEmpty
            ? 'No dates need to change. Remaining workouts keep their current dates.'
            : 'Every remaining workout moves by the same number of days, keeping its spacing. Recorded, skipped and in-progress workouts keep their dates.', style: context.caption),
        for (final c in changes) ListRow(title: titles[c.occasionId] ?? 'Workout', subtitle: '${shortDate(c.from)}  →  ${shortDate(c.to)}'),
        if (v.blockEnd != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text('The block would end ${longDate(v.blockEnd!)}.', style: context.body)),
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

    Future<void> close(String intent, String title, String body, String action) async {
      if (!await confirm(context, title: title, body: '$body${open == null ? '' : '\n\nYour open workout "${open.title}" can still be finished afterwards; its result stays with this block.'}', action: action) || !context.mounted) return;
      if (await runPlanDecision(context, () => repo.close(plan, intent: intent, today: today), saved: 'Block closed. Your history is kept.') && context.mounted) Navigator.pop(context);
    }

    return AppPage(title: 'Review this block', children: [
      Text(plan.title, style: context.sansStyle(16, weight: FontWeight.w600)),
      Text('${longDate(plan.startDate)} to ${plan.endDate == null ? '—' : longDate(plan.endDate!)}', style: context.caption),
      const SizedBox(height: 16),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(children: [
          for (final (i, (label, n)) in [
            ('Finished', c[OccasionStatus.finished]!), ('Partial', c[OccasionStatus.partial]!), ('Skipped', c[OccasionStatus.skipped]!),
            ('Missed', c[OccasionStatus.missed]!), ('Still ahead or in progress', remaining),
          ].indexed) ...[
            if (i > 0) const Rule(),
            Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [Expanded(child: Text(label, style: context.body)), Text('$n', style: context.titleStyle(21))])),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Text('Counts come from what was actually recorded for each planned workout. Reaching the end date does not by itself mean the training happened.', style: context.caption),
      if (plan.isClosed)
        Padding(padding: const EdgeInsets.only(top: 16), child: StatusLine(Icons.flag_outlined, plan.closureIntent == 'stopped_early' ? 'This block was stopped early.' : 'This block was finished for now.'))
      else ...[
        const SizedBox(height: 22),
        PrimaryButton('Continue this goal', key: const Key('block-continue'), onPressed: () async {
          final start = await pickDay(context, initial: today, first: today, help: 'Next block starts');
          if (start == null || !context.mounted) return;
          final answer = await repo.continueGoal(plan, start);
          if (!context.mounted) return;
          if (!answer.accepted) return toast(context, answer.unreachable ? 'Your account cannot be reached. Nothing was created.' : ScheduleRules.describe(answer.code ?? ''));
          await push(context, PlanReviewScreen(planId: answer.data!['planId'] as String, closePrimary: true));
        }),
        const SizedBox(height: 4),
        Text('Creates a new draft with the same setup. It does not start until you review and start it.', style: context.caption),
        const SizedBox(height: 14),
        SecondaryButton('Finish for now', key: const Key('block-finish'), onPressed: () => close('finish_for_now', 'Close this block?', 'The block is closed as finished for now and your primary plan slot is freed. This does not say the goal was achieved.', 'Close this block')),
        if (remaining > 0) ...[
          const SizedBox(height: 8),
          SecondaryButton('Stop early', key: const Key('block-stop'), onPressed: () => close('stopped_early', 'Stop this block early?', '$remaining planned workout${remaining == 1 ? '' : 's'} will no longer be expected. The block is recorded as stopped early, not as finished.', 'Stop this block')),
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
    return AppPage(title: plan.title, children: [
      SectionLabel(plan.isClosed ? (plan.closureIntent == 'stopped_early' ? 'Stopped early' : 'Finished for now') : plan.lifecycle),
      const SizedBox(height: 8),
      Text(plan.isBuilt ? '${splitOf(ref, plan)} · ${scheduleMode(plan)}' : planSplit(plan, (_) => null), style: context.body),
      Text('${longDate(plan.startDate)} to ${plan.endDate == null ? (plan.isOngoing ? 'ongoing' : '—') : longDate(plan.endDate!)}', style: context.caption),
      const SizedBox(height: 14),
      if (plan.isPaused && !isPrimary) PrimaryButton('Resume as my primary plan', key: const Key('plan-resume'), onPressed: () => push(context, ResumeReviewScreen(planId: plan.id))),
      if (plan.isClosed) SecondaryButton('Review this block', onPressed: () => push(context, BlockReviewScreen(planId: plan.id))),
      if (plan.isBuilt && !plan.isClosed)
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('plan-edit'), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit plan'), onPressed: () => openPlanEditor(context, ref, plan))),
      if (plan.isBuilt)
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('plan-duplicate'), icon: const Icon(Icons.copy_outlined, size: 18), label: const Text('Duplicate as a new plan'), onPressed: () => openPlanEditor(context, ref, plan, duplicate: true))),
      if (!isPrimary)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('plan-archive'),
            icon: Icon(plan.isArchived ? Icons.unarchive_outlined : Icons.inventory_2_outlined, size: 18),
            label: Text(plan.isArchived ? 'Move out of the archive' : 'Archive (hide from this list)'),
            onPressed: () async {
              if (await runPlanDecision(context, () => ref.read(planRepositoryProvider).archive(plan, !plan.isArchived), saved: plan.isArchived ? 'Restored to your plans.' : 'Archived. Its outcome and history are unchanged.') && context.mounted) Navigator.pop(context);
            },
          ),
        ),
      const SizedBox(height: 10),
      // A closed rotation has nothing ahead; an open one shows its projected next sessions too.
      for (final o in plan.isClosed ? plan.occasions : planOccasions(plan, today, workouts, ahead: 3))
        ListRow(
            title: o.title,
            subtitle: '${shortDate(o.scheduledDate)} · ${o.sequenceIndex == null ? 'week ${o.weekNumber}' : 'session ${o.sequenceIndex! + 1}'}'
                '${o.isVirtual ? ' · projected' : ''} · ${plan.isClosed && statusOf(o, plan, today, workouts) == OccasionStatus.upcoming ? 'Not done' : statusOf(o, plan, today, workouts).label}'),
    ]);
  }
}

/// The plan's split in words, with the starter's real name once the templates are read.
String splitOf(WidgetRef ref, Plan plan) {
  final t = ref.watch(planTemplatesProvider).value;
  return planSplit(plan, (id) => t?.templates.where((x) => x.id == id).firstOrNull?.name ?? 'Starter split');
}

class ArchivedPlansScreen extends ConsumerWidget {
  const ArchivedPlansScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(title: 'Archived plans', children: [
        Text('Archiving only hides a plan. Its outcome and recorded workouts are unchanged.', style: context.caption),
        for (final p in ref.watch(planListProvider).where((p) => p.isArchived)) ListRow(title: p.title, subtitle: p.lifecycle, onTap: () => push(context, PlanDetailScreen(planId: p.id))),
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
    return AppPage(
      title: 'Replace a movement',
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        PrimaryButton('Show me the change', key: const Key('substitution-submit'), busy: _busy, onPressed: _from == null || _to?.key == null ? null : () async {
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
                ? 'Your account cannot be reached. Nothing was changed.'
                : answer.code == 'PROPOSAL_DECLINED_UNCHANGED' ? 'You already chose to keep the current plan for exactly this change.' : 'There is nothing to change for that choice.');
          }
        }),
      ]),
      children: [
        Text('Only remaining workouts that have not been started are affected. You will review the exact change before it applies.', style: context.caption),
        const SizedBox(height: 14),
        const SectionLabel('Replace'),
        const SizedBox(height: 8),
        if (movements.isEmpty) Text('No remaining workout has a movement to replace.', style: context.caption),
        for (final e in movements.entries) ChoiceTile<String?>(key: Key('substitute-from-${e.key}'), value: e.key, groupValue: _from, title: e.value, onChanged: (v) => setState(() => _from = v)),
        const SizedBox(height: 10),
        GroupCard(children: [
          GroupRow(key: const Key('substitute-to'), icon: Icons.swap_horiz, title: 'With', subtitle: _to?.name ?? 'Choose a movement', onTap: () async {
            final e = await push<CatalogExercise>(context, const ExercisePicker(title: 'Replace with'));
            if (e != null) setState(() => _to = e);
          }),
        ]),
        const SizedBox(height: 8),
        if (_to != null && _to!.key == null) const StatusLine(Icons.info_outline, 'Choose a movement from the list. Custom movements can be used inside a workout, not in a plan change.', tone: Tone.warning),
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
    final answer = await ref.read(planRepositoryProvider).decide(p, accept: accept);
    if (!mounted) return;
    setState(() => _busy = false);
    if (answer.accepted) {
      toast(context, accept ? 'Change applied to the reviewed workouts.' : 'Kept your current plan.');
      Navigator.pop(context);
    } else {
      setState(() => _error = answer.unreachable
          ? 'Your account cannot be reached. Nothing was changed.'
          : 'This suggestion no longer matches your plan or records, so it was not applied. Nothing changed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = (ref.watch(proposalsProvider).value ?? const <Stored<Proposal>>[]).where((r) => r.value.id == widget.proposalId).firstOrNull?.value;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final plan = ref.watch(planListProvider).where((x) => x.id == p.planId).firstOrNull;
    final occasions = {for (final o in plan?.occasions ?? const <Occasion>[]) o.id: o};
    final stale = p.state == 'needs_review', open = p.state == 'open';
    return AppPage(
      title: 'Suggested change',
      bottom: !(open || stale)
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
              if (open) PrimaryButton('Accept this change', key: const Key('proposal-accept'), busy: _busy, onPressed: () => _decide(p, true)),
              TextButton(key: const Key('proposal-decline'), onPressed: _busy ? null : () => _decide(p, false), child: Text(open ? 'Keep current plan' : 'Dismiss this suggestion')),
            ]),
      children: [
        Text(p.explanation, style: context.body),
        const SizedBox(height: 12),
        if (stale) const StatusLine(Icons.rule, 'Your plan or recorded workouts changed after this was suggested, so it can no longer be applied as reviewed. Request it again if you still want it.', tone: Tone.warning),
        if (p.state == 'accepted') const StatusLine(Icons.check_circle_outline, 'You accepted this change.'),
        if (p.state == 'declined') const StatusLine(Icons.info_outline, 'You kept your current plan.'),
        const SizedBox(height: 16),
        SectionLabel('Affects ${p.affectedOccasionIds.length} unstarted workout${p.affectedOccasionIds.length == 1 ? '' : 's'}'),
        if (p.kind == 'schedule')
          for (final m in p.moves) ListRow(title: occasions[m['occasionId']]?.title ?? 'Workout', subtitle: 'Now ${shortDate(m['from'] as String)}  →  proposed ${shortDate(m['to'] as String)}')
        else ...[
          const SizedBox(height: 8),
          Text('Now: ${p.change['fromCatalogKey']}\nProposed: ${p.change['toName']}', style: context.body),
          for (final id in p.affectedOccasionIds)
            if (occasions[id] != null) ListRow(title: occasions[id]!.title, subtitle: '${shortDate(occasions[id]!.scheduledDate)} · week ${occasions[id]!.weekNumber}'),
        ],
        const SizedBox(height: 10),
        Text('Recorded and in-progress workouts are never changed by a suggestion.', style: context.caption),
      ],
    );
  }
}
