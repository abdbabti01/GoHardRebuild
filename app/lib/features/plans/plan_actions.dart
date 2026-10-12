import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../today/daily.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'plan_repository.dart';
import 'schedule_rules.dart';

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

/// One planned occasion: its prescription and the actions that are honestly available for its state.
Future<void> showOccasionSheet(BuildContext context, WidgetRef ref, Plan plan, Occasion occasion) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Consumer(builder: (context, ref, _) {
        // Re-read so the sheet reflects changes made from it.
        final current = ref.watch(planListProvider).where((p) => p.id == plan.id).firstOrNull ?? plan;
        final o = current.occasions.where((x) => x.id == occasion.id).firstOrNull ?? occasion;
        final today = ref.watch(todayKeyProvider);
        final workouts = ref.watch(workoutListProvider);
        final status = statusOf(o, current, today, workouts);
        final schedule = scheduleOf(current, workouts);
        final eligible = schedule.firstWhere((s) => s.id == o.id).isEligible;
        final open = openWorkoutFor(o, workouts);
        final recorded = workouts.where((w) => !w.isDeleted && w.occasionId == o.id && !w.isOpen && w.qualifiedOccasion).firstOrNull;
        final repo = ref.read(planRepositoryProvider);

        Future<void> move() async {
          final to = await pickDay(context, initial: o.scheduledDate, first: today, help: 'Move ${o.title} to');
          if (to == null || to == o.scheduledDate || !context.mounted) return;
          final v = ScheduleRules.validate(schedule, [ScheduleChange(o.id, o.scheduledDate, to)], current.minRecoveryDays);
          if (!v.isValid) return toast(context, ScheduleRules.describe(v.errors.first));
          final ok = await confirm(context,
              title: 'Move this workout?',
              body: 'Workout: ${o.title} (week ${o.weekNumber})\nCurrent date: ${longDate(o.scheduledDate)}\nProposed date: ${longDate(to)}\nOriginally planned: ${longDate(o.originalDate)}\n'
                  'Block ends: ${longDate(v.blockEnd!)}\n\nIt stays the same workout in the same training week. No other workout changes.',
              action: 'Move workout', cancel: 'Keep current dates');
          if (ok && context.mounted) await runPlanDecision(context, () => repo.move(current, schedule, o.id, to), saved: 'Moved to ${shortDate(to)}.');
        }

        Future<void> skip() async {
          final ok = await confirm(context,
              title: 'Skip ${o.title}?',
              body: 'The workout planned for ${longDate(o.scheduledDate)} will be marked Skipped. No workout, sets or completion credit are created, and it will not count as training.',
              action: 'Skip this workout', cancel: 'Keep it');
          if (ok && context.mounted) await runPlanDecision(context, () => repo.skip(current, schedule, o.id), saved: 'Marked as skipped.');
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              SectionLabel('Week ${o.weekNumber} · ${status.label}'),
              const SizedBox(height: 6),
              Heading(o.title, size: 26),
              Text('${longDate(o.scheduledDate)}${o.wasMoved ? ' · originally ${shortDate(o.originalDate)}' : ''}', style: context.caption),
              const SizedBox(height: 14),
              for (final (i, e) in o.prescription.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    SizedBox(width: 24, child: Text('${i + 1}', style: context.caption)),
                    Expanded(child: Text(e.name, style: context.sansStyle(16))),
                    Text(targetText(sets: e.targetSets, repsMin: e.targetRepsMin, repsMax: e.targetRepsMax, seconds: e.targetDurationSeconds), style: context.caption),
                  ]),
                ),
              const SizedBox(height: 16),
              if (open != null)
                PrimaryButton('Resume workout', onPressed: () {
                  Navigator.pop(sheet);
                  resumeWorkout(context, ref, open);
                })
              else if (recorded != null || o.resultWorkoutId != null)
                SecondaryButton('View what was recorded', onPressed: () {
                  Navigator.pop(sheet);
                  push(context, WorkoutDetailScreen(workoutId: recorded?.id ?? o.resultWorkoutId!));
                })
              else if (o.isSkipped)
                SecondaryButton('Undo skip', onPressed: () => runPlanDecision(context, () => repo.unskip(current, o.id), saved: 'No longer skipped.'))
              else if (current.isPaused)
                const StatusLine(Icons.pause_circle_outline, 'The plan is paused. Resume the plan to start or reschedule its workouts.')
              else if (eligible && current.isActive) ...[
                PrimaryButton(status == OccasionStatus.upcoming ? 'Start this workout early' : 'Start workout', key: const Key('occasion-start'), onPressed: () {
                  Navigator.pop(sheet);
                  startPlannedWorkout(context, ref, current, o);
                }),
                const SizedBox(height: 4),
                Wrap(children: [
                  TextButton(key: const Key('occasion-move'), onPressed: move, child: const Text('Move to another date')),
                  TextButton(key: const Key('occasion-skip'), onPressed: skip, child: const Text('Skip this workout')),
                ]),
              ],
            ]),
          ),
        );
      }),
    );
