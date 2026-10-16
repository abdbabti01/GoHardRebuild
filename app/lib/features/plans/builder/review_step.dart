import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/clock.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../core/units.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../plan_actions.dart' show pickDay;
import '../plan_draft.dart';
import '../plan_projection.dart';
import '../plan_rules.dart';
import 'workout_editor.dart';

/// The workouts the schedule uses that have no exercise yet: until they do, the plan is a draft.
List<String> emptyScheduled(PlanDraft d) {
  final used = PlanRules.scheduled(d.planBody['schedule'] as Json);
  return [for (final w in d.workouts) if (used.contains(w.id) && w.exercises.isEmpty) w.name];
}

/// Step 4: the real schedule from the same rules the account uses, each workout's contents, and what activating or
/// saving changes. The actions themselves are on the builder's pinned bar.
class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key, required this.draft, required this.change, this.editing});
  final PlanDraft draft;
  final DraftChange change;

  /// The saved plan being edited, or null for a new plan or a duplicate.
  final Plan? editing;

  Widget _day(BuildContext context, String key, String date, String? title) => Padding(
        key: Key(key),
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Wrap(spacing: 12, runSpacing: 2, children: [
          SizedBox(width: 104, child: Text(shortDate(date), style: context.numStyle(15, color: context.c.secondary, weight: FontWeight.w500))),
          Text(title ?? 'Rest', style: title == null ? context.sansStyle(15, color: context.c.secondary) : context.sansStyle(15.5, weight: FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = draft;
    final today = ref.watch(todayKeyProvider);
    final unit = ref.watch(loadUnitProvider);
    final primary = ref.watch(primaryPlanProvider);
    final workouts = ref.watch(workoutListProvider);
    final replaces = editing == null && primary != null && primary.id != d.planId ? primary : null;
    final missing = emptyScheduled(d);
    final names = {for (final w in d.workouts) w.id: w.name};
    final rotating = d.schedule.isRotating;
    final weeks = d.durationWeeks;
    final editingLive = editing != null && !editing!.isDraft;
    final effective = d.effectiveDate ?? today;
    final from = editingLive ? (effective.compareTo(d.startDate) < 0 ? d.startDate : effective) : d.startDate;

    final schedule = <Widget>[];
    if (!rotating) {
      final occ = d.occurrences();
      final byDate = {for (final o in occ) o['scheduledDate'] as String: o['title'] as String};
      final end = occ.isEmpty ? null : occ.last['scheduledDate'] as String;
      final span = weeks == null ? 14 : (daysBetween(from, addDays(d.startDate, weeks * 7)).clamp(0, 14));
      for (var i = 0; i < span; i++) {
        final date = addDays(from, i);
        if (i % 7 == 0) schedule.add(Padding(padding: const EdgeInsets.only(top: 10), child: SectionLabel(i == 0 ? (editingLive ? 'From ${shortDate(date)}' : 'First week') : 'Second week')));
        schedule.add(_day(context, 'review-day-$date', date, byDate[date]));
      }
      if (end != null) {
        schedule.add(Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${occ.length} workouts over ${weeks ?? 0} ${weeks == 1 ? 'week' : 'weeks'}, the last on ${longDate(end)}. The same week repeats until then.', style: context.caption)));
      }
    } else {
      final cycle = [for (final id in d.schedule.cycle) names[id] ?? '?'];
      final days = d.schedule.trainingDays;
      final plan = Plan({...d.toPlanJson(), if (editing != null) 'occasions': editing!.j['occasions'] ?? const []});
      final next = planOccasions(plan, today, editing == null ? const <Workout>[] : workouts, ahead: 8).where((o) => o.isVirtual).toList();
      schedule
        ..add(Text('Cycle: ${cycle.join(' → ')}, then it starts again.', style: context.body))
        ..add(Text(days.isEmpty ? 'Any day can be a training day.' : 'Training days: ${days.map(weekdayShort).join(', ')}.', style: context.caption))
        ..add(Padding(padding: const EdgeInsets.only(top: 10), child: const SectionLabel('Next workouts if you train on each training day')));
      for (final (i, o) in next.indexed) {
        schedule.add(_day(context, 'review-next-$i', o.scheduledDate, o.title));
      }
      schedule.add(Text('These dates are a projection. A missed day does not skip a workout: the same one waits for your next training day.', style: context.caption));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Heading(d.title.trim().isEmpty ? 'Untitled plan' : d.title.trim(), size: 30, serif: true),
      const SizedBox(height: 4),
      Text(
        [
          rotating ? 'Rotating sequence' : 'Fixed weekdays',
          weeks == null ? 'ongoing' : '$weeks ${weeks == 1 ? 'week' : 'weeks'}',
          'starts ${longDate(d.startDate)}',
          if (d.timeBudgetMinutes != null) 'planned time ${d.timeBudgetMinutes} min',
        ].join(' · '),
        style: context.caption,
      ),
      if (missing.isNotEmpty) ...[
        const SizedBox(height: 12),
        StatusLine(Icons.edit_note, 'Draft — add exercises to ${missing.join(', ')} before this plan can be activated.', tone: Tone.warning, key: const Key('review-draft')),
      ],
      if (replaces != null) ...[
        const SizedBox(height: 12),
        Panel(
          key: const Key('review-replaces'),
          child: StatusLine(Icons.swap_horiz, 'You are following "${replaces.title}". Activating this plan pauses it. Its history and recorded workouts are kept, and you can resume it later.'),
        ),
      ],
      if (editing != null) ...[
        const SizedBox(height: 12),
        if (editingLive) ...[
          GroupCard(children: [
            GroupRow(
              key: const Key('plan-effective-date'), title: 'Changes apply from', value: longDate(effective),
              onTap: () async {
                final day = await pickDay(context, initial: effective.compareTo(today) < 0 ? today : effective, first: today, help: 'Changes apply from');
                if (day != null) change((d) => d.effectiveDate = day);
              },
            ),
          ]),
          const SizedBox(height: 8),
          Text('Workouts you recorded or skipped, and one in progress, stay exactly as they are. Earlier workouts and any you edited on their own do not change.',
              style: context.caption),
        ] else
          Text('This plan has not started, so it is rebuilt with these changes.', style: context.caption),
      ],
      const SizedBox(height: 18),
      const SectionLabel('Schedule'),
      ...schedule,
      const SizedBox(height: 18),
      const SectionLabel('Workouts'),
      for (final w in d.workouts) ...[
        const SizedBox(height: 12),
        Text(w.name, style: context.sansStyle(16, weight: FontWeight.w600)),
        if (w.exercises.isEmpty) Text('No exercises yet', style: context.caption),
        for (final e in w.exercises)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 10, children: [
              Text(e.name, style: context.sansStyle(15)),
              Text([rxText(e), if (e.targetLoadKg != null) 'Target ${formatLoad(e.targetLoadKg, unit)}'].join(' · '), style: context.numStyle(14, color: context.c.secondary, weight: FontWeight.w500)),
            ]),
          ),
      ],
      const SizedBox(height: 12),
      Text('Targets are a starting point, not a prescription. What you record is what counts.', style: context.caption),
    ]);
  }
}
