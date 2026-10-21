import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/catalog_names.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../today/daily.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'builder/plan_builder_screen.dart';
import 'plan_l10n.dart';
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
    if (context.mounted) toast(context, planErrorText(context.l10n, e.codes.first));
  } on LocalSaveFailure {
    if (context.mounted) toast(context, context.l10n.planLocalSaveFailed);
  }
  return false;
}

Future<void> pausePlanFlow(BuildContext context, WidgetRef ref, Plan plan) async {
  final open = ref.read(workoutListProvider).where((w) => w.isOpen && w.planId == plan.id).firstOrNull;
  final l = context.l10n;
  if (!await confirm(context,
      title: l.planPauseTitle(plan.title),
      body: [l.planPauseBody, if (open != null) l.planPauseOpenWorkout(open.title)].join('\n\n'),
      action: l.planPauseAction) ||
      !context.mounted) {
    return;
  }
  await runPlanDecision(context, () => ref.read(planRepositoryProvider).pause(plan, today: ref.read(todayKeyProvider)), saved: l.planPausedToast);
}

/// Whether [o] can be started now, by the same rules as the occurrence sheet's Start: an active plan, the occurrence
/// still eligible (not skipped, recorded or open), and for a rotation only its next workout.
bool canStartOccasion(Plan plan, Occasion o, String today, List<Workout> workouts) {
  if (!plan.isActive || o.isSkipped || openWorkoutFor(o, workouts) != null || o.resultWorkoutId != null) return false;
  if (workouts.any((w) => !w.isDeleted && w.occasionId == o.id && !w.isOpen && w.qualifiedOccasion)) return false;
  if (!o.isVirtual && !(scheduleOf(plan, workouts).where((s) => s.id == o.id).firstOrNull?.isEligible ?? false)) return false;
  if (!plan.isRotating) return true;
  return rotationOf(plan, planOccasions(plan, today, workouts), workouts)?.next?.id == o.id;
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
        final l = context.l10n;
        final names = ref.watch(exerciseNamesProvider), locale = Localizations.localeOf(context);

        Future<void> move() async {
          final to = await pickDay(context, initial: o.scheduledDate.compareTo(today) < 0 ? today : o.scheduledDate, first: today, help: l.planMoveHelp(o.title));
          if (to == null || to == o.scheduledDate || !context.mounted) return;
          final v = ScheduleRules.validate(schedule, [ScheduleChange(o.id, o.scheduledDate, to)], current.minRecoveryDays);
          if (!v.isValid) return toast(context, planErrorText(l, v.errors.first));
          final ok = await confirm(context,
              title: l.planMoveTitle,
              body: l.planMoveBody(o.title, o.weekNumber, longDate(o.scheduledDate), longDate(to), longDate(o.originalDate), longDate(v.blockEnd!)),
              action: l.planMoveAction, cancel: l.planMoveCancel);
          if (ok && context.mounted) await runPlanDecision(context, () => repo().move(current, schedule, o.id, to), saved: l.planMovedToast(shortDate(to)));
        }

        Future<void> skip() async {
          final ok = await confirm(context,
              title: l.planSkipTitle(o.title),
              body: current.isRotating ? l.planSkipBodyRotation(o.title) : l.planSkipBodyFixed(longDate(o.scheduledDate)),
              action: l.planSkipAction, cancel: l.planSkipCancel);
          if (ok && context.mounted) await runPlanDecision(context, () => repo().skipOccurrence(current, workouts, o, today: today), saved: l.planSkippedToast);
        }

        void start() {
          Navigator.pop(sheet);
          startPlannedWorkout(host, hostRef, current, o);
        }

        final k = o.sequenceIndex;
        final where = k != null && cycleLength > 0
            ? rotation != null && o.id == rotation.next?.id
                ? l.planSessionStep(k + 1, rotation.position + 1, cycleLength, rotation.cyclesDone + 1)
                : l.planSessionN(k + 1)
            : l.planWeekN(o.weekNumber);
        final when = o.isVirtual
            ? l.planVirtualWhen(longDate(o.scheduledDate))
            : o.wasMoved ? l.planDateOriginally(longDate(o.scheduledDate), shortDate(o.originalDate)) : longDate(o.scheduledDate);

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
                          Text(names.name(e.catalogKey, e.name, locale), style: context.sansStyle(16)),
                          Text(prescriptionOf(e), style: context.numStyle(15, color: context.c.secondary, weight: FontWeight.w500)),
                        ]),
                        // The user's own target, not a record and not the last performance.
                        if (e.targetLoadKg != null) Text(l.planTargetLoad(formatLoad(e.targetLoadKg, unit)), style: context.numStyle(14, color: context.c.secondary, weight: FontWeight.w400)),
                        if ((e.notes ?? '').trim().isNotEmpty) Text(e.notes!.trim(), style: context.caption),
                      ]),
                    ),
                  ]),
                ),
              const Rule(),
              const SizedBox(height: 16),
              if (open != null)
                PrimaryButton(l.planResumeWorkout, key: const Key('occasion-resume'), onPressed: () {
                  Navigator.pop(sheet);
                  resumeWorkout(host, hostRef, open);
                })
              else if (recorded != null || o.resultWorkoutId != null)
                SecondaryButton(l.planViewRecorded, onPressed: () {
                  Navigator.pop(sheet);
                  push(host, WorkoutDetailScreen(workoutId: recorded?.id ?? o.resultWorkoutId!));
                })
              else if (o.isSkipped)
                (PlanRepository.canUnskip(current, o.id, workouts)
                    ? SecondaryButton(l.planUndoSkip, key: const Key('occasion-unskip'), onPressed: () => runPlanDecision(context, () => repo().unskip(current, o.id, workouts: workouts), saved: l.planUnskippedToast))
                    : StatusLine(Icons.info_outline, l.planSkippedStays))
              else if (current.isPaused)
                StatusLine(Icons.pause_circle_outline, l.planPausedNoStart)
              else if (eligible && current.isActive && current.isRotating) ...[
                if (isNext) ...[
                  PrimaryButton(status == OccasionStatus.upcoming ? l.planStartNowRotation : l.planStartWorkout, key: const Key('occasion-start'), onPressed: start),
                  const SizedBox(height: 4),
                  Wrap(children: [
                    TextButton(key: const Key('occasion-skip'), onPressed: skip, child: Text(l.planSkipAction)),
                    // A rest day the person chooses: nothing is skipped, credited or moved on; the workout waits.
                    if (o.isVirtual && o.scheduledDate == today && status == OccasionStatus.due)
                      TextButton(key: const Key('occasion-rest'), onPressed: () async {
                        await repo().setRestDay(current, today, rest: true);
                        if (sheet.mounted) Navigator.pop(sheet);
                        if (host.mounted) toast(host, l.planRestToast(o.title));
                      }, child: Text(l.planRestInstead)),
                  ]),
                  Text(l.planRotationNoMove, style: context.caption),
                ] else
                  StatusLine(Icons.low_priority, rotation.next == null ? l.planComesAfterEarlier : l.planComesAfter(rotation.next!.title)),
              ] else if (eligible && current.isActive) ...[
                if (status == OccasionStatus.missed)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, l.planMissedOn(longDate(o.scheduledDate)), tone: Tone.warning)),
                PrimaryButton(switch (status) { OccasionStatus.missed => l.planStartNowMissed, OccasionStatus.upcoming => l.planStartEarly, _ => l.planStartWorkout }, key: const Key('occasion-start'), onPressed: start),
                const SizedBox(height: 4),
                Wrap(children: [
                  TextButton(key: const Key('occasion-move'), onPressed: move, child: Text(l.planMoveDate)),
                  TextButton(key: const Key('occasion-skip'), onPressed: skip, child: Text(l.planSkipAction)),
                  if (current.isBuilt)
                    TextButton(key: const Key('occasion-edit-one'), onPressed: () {
                      Navigator.pop(sheet);
                      openOccurrenceEditor(host, hostRef, current, o);
                    }, child: Text(l.planEditOnlyThis)),
                ]),
              ],
            ]);
      }),
    );
