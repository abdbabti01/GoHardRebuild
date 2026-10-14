import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../today/daily.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'builder/plan_builder_screen.dart';
import 'plan_progress.dart';
import 'plan_projection.dart';
import 'plan_repository.dart';
import 'schedule_rules.dart';
import 'week_widgets.dart';

/// Native date picker returning a calendar day key.
Future<String?> pickDay(BuildContext context, {required String initial, String? first, String? help}) async {
  final start = parseDayKey(first ?? addDays(initial, -366));
  final init = parseDayKey(initial);
  final picked = await showDatePicker(context: context, initialDate: init.isBefore(start) ? start : init, firstDate: start, lastDate: init.add(const Duration(days: 730)), helpText: help);
  return picked == null ? null : dayKeyOf(picked);
}

/// Runs a reviewed local plan decision and reports honestly: saved on the phone, refused by the rules, or not saved.
Future<bool> runPlanDecision(BuildContext context, Future<Receipt> Function() decision, {required String saved}) async {
  try {
    await decision();
    if (context.mounted && saved.isNotEmpty) toast(context, saved);
    return true;
  } on ScheduleRefused catch (e) {
    if (context.mounted) toast(context, e.codes.first == 'PRIMARY_EXISTS' ? 'Another plan is already your primary plan. Review the replacement first.' : e.message);
  } on LocalSaveFailure {
    if (context.mounted) toast(context, 'That could not be saved on this phone. Nothing changed.');
  }
  return false;
}

Future<void> pausePlanFlow(BuildContext context, WidgetRef ref, Plan plan) async {
  final open = ref.read(workoutListProvider).where((w) => w.isOpen && w.planId == plan.id).firstOrNull;
  if (!await confirm(context,
      title: 'Pause ${plan.title}?',
      body: 'Future workouts stop being expected from today, and nothing will count as missed while it is paused. Your history and remaining workouts are kept.'
          '${open == null ? '' : '\n\nYour open workout "${open.title}" is not affected: its clock keeps running and you can still finish it.'}',
      action: 'Pause this plan') ||
      !context.mounted) {
    return;
  }
  await runPlanDecision(context, () => ref.read(planRepositoryProvider).pause(plan, today: ref.read(todayKeyProvider)), saved: 'Plan paused.');
}

/// One planned occurrence, read from the same projection as Train and Today (a rotation's projected next workout
/// included): its prescription and the actions that are honestly available for its state. Nothing here completes
/// a workout. Starting, resuming and opening a record close the sheet and then continue from [host], the page
/// underneath, which is still there once the sheet has gone (at once, under Reduce Motion).
Future<void> showOccasionSheet(BuildContext host, WidgetRef hostRef, Plan plan, Occasion occasion) => showGoSheet<void>(
      host,
      builder: (sheet) => Consumer(builder: (context, ref, _) {
        // Re-read so the sheet reflects changes made from it (a skipped projection becomes a real occurrence).
        final current = ref.watch(planListProvider).where((p) => p.id == plan.id).firstOrNull ?? plan;
        final today = ref.watch(todayKeyProvider);
        final workouts = ref.watch(workoutListProvider);
        final unit = ref.watch(loadUnitProvider);
        final occasions = planOccasions(current, today, workouts);
        final o = occasions.where((x) => x.id == occasion.id).firstOrNull ?? occasion;
        final status = statusOf(o, current, today, workouts);
        final schedule = scheduleOf(current, workouts);
        final eligible = o.isVirtual || (schedule.where((s) => s.id == o.id).firstOrNull?.isEligible ?? false);
        final open = openWorkoutFor(o, workouts);
        final recorded = workouts.where((w) => !w.isDeleted && w.occasionId == o.id && !w.isOpen && w.qualifiedOccasion).firstOrNull;
        final rotation = rotationOf(current, occasions, workouts);
        final cycleLength = current.schedule?.cycle.length ?? 0;
        // Only the next workout of a rotation can be started or skipped: the sequence runs in order.
        final isNext = rotation == null || rotation.next?.id == o.id;
        // Read when an action needs it: showing a workout must not depend on the store being ready.
        PlanRepository repo() => ref.read(planRepositoryProvider);

        Future<void> move() async {
          final to = await pickDay(context, initial: o.scheduledDate.compareTo(today) < 0 ? today : o.scheduledDate, first: today, help: 'Move ${o.title} to');
          if (to == null || to == o.scheduledDate || !context.mounted) return;
          final v = ScheduleRules.validate(schedule, [ScheduleChange(o.id, o.scheduledDate, to)], current.minRecoveryDays);
          if (!v.isValid) return toast(context, ScheduleRules.describe(v.errors.first));
          final ok = await confirm(context,
              title: 'Move this workout?',
              body: 'Workout: ${o.title} (week ${o.weekNumber})\nCurrent date: ${longDate(o.scheduledDate)}\nProposed date: ${longDate(to)}\nOriginally planned: ${longDate(o.originalDate)}\n'
                  'Block ends: ${longDate(v.blockEnd!)}\n\nIt stays the same workout in the same training week. No other workout changes, and the repeating schedule stays as it is.',
              action: 'Move workout', cancel: 'Keep current dates');
          if (ok && context.mounted) await runPlanDecision(context, () => repo().move(current, schedule, o.id, to), saved: 'Moved to ${shortDate(to)}.');
        }

        Future<void> skip() async {
          final ok = await confirm(context,
              title: 'Skip ${o.title}?',
              body: current.isRotating
                  ? '${o.title} will be marked Skipped today and the rotation moves on to the workout after it. No workout, sets or completion credit are created.'
                  : 'The workout planned for ${longDate(o.scheduledDate)} will be marked Skipped. No workout, sets or completion credit are created, and it will not count as training.',
              action: 'Skip this workout', cancel: 'Keep it');
          if (ok && context.mounted) await runPlanDecision(context, () => repo().skipOccurrence(current, workouts, o, today: today), saved: 'Marked as skipped.');
        }

        void start() {
          Navigator.pop(sheet);
          startPlannedWorkout(host, hostRef, current, o);
        }

        final k = o.sequenceIndex;
        final where = k != null && cycleLength > 0
            ? 'Session ${k + 1}${rotation != null && o.id == rotation.next?.id ? ' · step ${rotation.position + 1} of $cycleLength, cycle ${rotation.cyclesDone + 1}' : ''}'
            : 'Week ${o.weekNumber}';
        final when = o.isVirtual
            ? 'Planned for ${longDate(o.scheduledDate)}. A rotation has no fixed dates: this is when it comes up if you keep to your training days.'
            : '${longDate(o.scheduledDate)}${o.wasMoved ? ' · originally ${shortDate(o.originalDate)}' : ''}';

        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [Overline(where), OccasionPill(status)]),
              const SizedBox(height: 8),
              Heading(o.title, size: 26),
              const SizedBox(height: 2),
              Text(when, style: context.caption),
              const SizedBox(height: 14),
              const Rule(),
              for (final (i, e) in o.prescription.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 26, child: Text('${i + 1}', style: context.numStyle(15, color: context.c.secondary, weight: FontWeight.w400))),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        // The target shares the name's line while both fit, and drops under it when they do not.
                        Wrap(alignment: WrapAlignment.spaceBetween, spacing: 10, children: [
                          Text(e.name, style: context.sansStyle(16)),
                          Text(prescriptionOf(e), style: context.numStyle(15, color: context.c.secondary, weight: FontWeight.w500)),
                        ]),
                        // The user's own target, not a record and not the last performance.
                        if (e.targetLoadKg != null) Text('Target ${formatLoad(e.targetLoadKg, unit)}', style: context.numStyle(14, color: context.c.secondary, weight: FontWeight.w400)),
                        if ((e.notes ?? '').trim().isNotEmpty) Text(e.notes!.trim(), style: context.caption),
                      ]),
                    ),
                  ]),
                ),
              const Rule(),
              const SizedBox(height: 16),
              if (open != null)
                PrimaryButton('Resume workout', key: const Key('occasion-resume'), onPressed: () {
                  Navigator.pop(sheet);
                  resumeWorkout(host, hostRef, open);
                })
              else if (recorded != null || o.resultWorkoutId != null)
                SecondaryButton('View what was recorded', onPressed: () {
                  Navigator.pop(sheet);
                  push(host, WorkoutDetailScreen(workoutId: recorded?.id ?? o.resultWorkoutId!));
                })
              else if (o.isSkipped)
                SecondaryButton('Undo skip', key: const Key('occasion-unskip'), onPressed: () => runPlanDecision(context, () => repo().unskip(current, o.id), saved: 'No longer skipped.'))
              else if (current.isPaused)
                const StatusLine(Icons.pause_circle_outline, 'The plan is paused. Resume the plan to start or reschedule its workouts.')
              else if (eligible && current.isActive && current.isRotating) ...[
                if (isNext) ...[
                  PrimaryButton(status == OccasionStatus.upcoming ? 'Start this workout now' : 'Start workout', key: const Key('occasion-start'), onPressed: start),
                  const SizedBox(height: 4),
                  Align(alignment: AlignmentDirectional.centerStart, child: TextButton(key: const Key('occasion-skip'), onPressed: skip, child: const Text('Skip this workout'))),
                  Text('A rotation has no dates to move: this workout waits for you until you do it or skip it.', style: context.caption),
                ] else
                  StatusLine(Icons.low_priority, 'Comes after ${rotation.next?.title ?? 'the workouts before it'}. A rotation runs in order: do or skip the next one first.'),
              ] else if (eligible && current.isActive) ...[
                if (status == OccasionStatus.missed)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, 'Missed on ${longDate(o.scheduledDate)}. Move it, skip it or do it now. It is never marked done by itself.', tone: Tone.warning)),
                PrimaryButton(switch (status) { OccasionStatus.missed => 'Start now', OccasionStatus.upcoming => 'Start this workout early', _ => 'Start workout' }, key: const Key('occasion-start'), onPressed: start),
                const SizedBox(height: 4),
                Wrap(children: [
                  TextButton(key: const Key('occasion-move'), onPressed: move, child: const Text('Move to another date')),
                  TextButton(key: const Key('occasion-skip'), onPressed: skip, child: const Text('Skip this workout')),
                  if (current.isBuilt)
                    TextButton(key: const Key('occasion-edit-one'), onPressed: () {
                      Navigator.pop(sheet);
                      openOccurrenceEditor(host, hostRef, current, o);
                    }, child: const Text('Edit this workout only')),
                ]),
              ],
            ]);
      }),
    );
