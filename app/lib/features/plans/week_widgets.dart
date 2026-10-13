import 'package:flutter/material.dart';

import '../../core/clock.dart';
import '../../core/device_prefs.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../today/daily.dart';
import 'plan_progress.dart';

/// How a state is drawn everywhere: a word, an icon and a tone. Never colour by itself.
(IconData, Tone) statusLook(OccasionStatus s) => switch (s) {
      OccasionStatus.inProgress => (Icons.timelapse, Tone.accent),
      OccasionStatus.finished => (Icons.check_circle, Tone.success),
      OccasionStatus.partial => (Icons.check_circle_outline, Tone.success),
      OccasionStatus.skipped => (Icons.remove_circle_outline, Tone.neutral),
      OccasionStatus.missed => (Icons.error_outline, Tone.warning),
      OccasionStatus.due => (Icons.radio_button_unchecked, Tone.accent),
      OccasionStatus.upcoming => (Icons.schedule, Tone.neutral),
      OccasionStatus.paused => (Icons.pause_circle_outline, Tone.neutral),
    };

class OccasionPill extends StatelessWidget {
  const OccasionPill(this.status, {super.key});
  final OccasionStatus status;
  @override
  Widget build(BuildContext context) {
    final (icon, tone) = statusLook(status);
    return StatusPill(status.label, icon: icon, tone: tone);
  }
}

/// What a week tile says. It is read from the week's workouts, never from the calendar alone: a week whose dates
/// have passed is Done only when every expected workout has a recorded result.
enum WeekState { done, current, partial, missed, paused, skipped, upcoming, empty }

WeekState weekStateOf(PlanWeek week, Plan plan, String today, Iterable<Workout> workouts) {
  final done = week.completion;
  if (week.occasions.isEmpty) return WeekState.empty;
  if (done.eligible == 0) return WeekState.skipped;
  if (done.isDone) return WeekState.done;
  if (week.isCurrent) return WeekState.current;
  final open = {for (final o in week.occasions) statusOf(o, plan, today, workouts)};
  if (open.contains(OccasionStatus.inProgress) || done.completed > 0) return WeekState.partial;
  if (open.contains(OccasionStatus.missed)) return WeekState.missed;
  if (open.contains(OccasionStatus.paused)) return WeekState.paused;
  return WeekState.upcoming;
}

/// The words, icon and tone of a week's state. A partly recorded week says how much ("2 of 3").
(String, IconData, Tone) weekLook(WeekState state, Completion done) => switch (state) {
      WeekState.done => ('Done', Icons.check_circle, Tone.success),
      WeekState.current => ('Current', Icons.circle, Tone.accent),
      WeekState.partial => ('${done.completed} of ${done.eligible}', Icons.incomplete_circle, Tone.neutral),
      WeekState.missed => ('Missed', Icons.error_outline, Tone.warning),
      WeekState.paused => ('Paused', Icons.pause_circle_outline, Tone.neutral),
      WeekState.skipped => ('Skipped', Icons.remove_circle_outline, Tone.neutral),
      WeekState.upcoming => ('Upcoming', Icons.radio_button_unchecked, Tone.neutral),
      WeekState.empty => ('No workouts', Icons.remove, Tone.neutral),
    };

/// The seven days of one plan week with what each day holds. A day without a workout is a rest day.
class WeekDayStrip extends StatelessWidget {
  const WeekDayStrip({super.key, required this.week, required this.plan, required this.today, required this.workouts});
  final PlanWeek week;
  final Plan plan;
  final String today;
  final List<Workout> workouts;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Large text gets two rows of days instead of seven squeezed columns.
    final perRow = MediaQuery.textScalerOf(context).scale(10) > 13 ? 4 : 7;
    return LayoutBuilder(
      builder: (context, box) => Wrap(runSpacing: 10, children: [
        for (var i = 0; i < 7; i++)
          SizedBox(
            width: box.maxWidth / perRow,
            child: Builder(builder: (context) {
              final day = addDays(week.start, i);
              final occasion = week.occasions.where((o) => o.scheduledDate == day).firstOrNull;
              final status = occasion == null ? null : statusOf(occasion, plan, today, workouts);
              final isToday = day == today;
              final done = status == OccasionStatus.finished || status == OccasionStatus.partial;
              final Widget mark = switch (status) {
                null => Container(width: 12, height: 3, decoration: BoxDecoration(color: c.outline, borderRadius: BorderRadius.circular(2))),
                _ when done => Icon(Icons.check_circle, size: 24, color: c.success),
                OccasionStatus.inProgress => Icon(Icons.timelapse, size: 24, color: c.accent),
                OccasionStatus.missed => Icon(Icons.error_outline, size: 24, color: c.warning),
                OccasionStatus.skipped => Icon(Icons.remove_circle_outline, size: 24, color: c.outline),
                OccasionStatus.paused => Icon(Icons.pause_circle_outline, size: 24, color: c.outline),
                _ => Icon(Icons.radio_button_unchecked, size: 24, color: c.accent),
              };
              return Semantics(
                label: '${longDate(day)}${isToday ? ', today' : ''}, ${occasion == null ? 'rest day' : '${occasion.title}, ${status!.label}'}',
                child: ExcludeSemantics(
                  child: Column(children: [
                    SizedBox(height: 26, child: Center(child: mark)),
                    const SizedBox(height: 4),
                    Text(weekdayShort(parseDayKey(day).weekday), style: context.sansStyle(13, weight: isToday ? FontWeight.w700 : FontWeight.w500, color: isToday ? c.accent : c.text)),
                    Text('${parseDayKey(day).day}', style: context.numStyle(13, weight: isToday ? FontWeight.w700 : FontWeight.w400, color: isToday ? c.accent : c.secondary)),
                    // Today is also marked by a bar, so it does not depend on the accent colour.
                    Container(margin: const EdgeInsets.only(top: 3), width: 18, height: 3, decoration: BoxDecoration(color: isToday ? c.accent : Colors.transparent, borderRadius: BorderRadius.circular(2))),
                  ]),
                ),
              );
            }),
          ),
      ]),
    );
  }
}

/// Every week of the block as a tile: number, date range and state, whatever the block's length. Three across
/// on a phone, two when it is narrow, and one full-width row per week with large text, so no label is cut.
class WeekGrid extends StatelessWidget {
  const WeekGrid({super.key, required this.weeks, required this.selected, required this.onSelect, required this.stateOf});
  final List<PlanWeek> weeks;
  final int selected;
  final ValueChanged<int> onSelect;
  final WeekState Function(PlanWeek) stateOf;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return LayoutBuilder(builder: (context, box) {
      final columns = (box.maxWidth / (104 * scale)).floor().clamp(1, 3);
      const gap = 8.0;
      return Column(children: [
        for (var i = 0; i < weeks.length; i += columns)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
            // Tiles in a row share the height of the tallest, so a wrapped date range never leaves a ragged row.
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var j = i; j < i + columns; j++) ...[
                  if (j > i) const SizedBox(width: gap),
                  Expanded(
                      child: j >= weeks.length
                          ? const SizedBox()
                          : _WeekTile(week: weeks[j], state: stateOf(weeks[j]), selected: weeks[j].number == selected, wide: columns == 1, onTap: () => onSelect(weeks[j].number))),
                ],
              ]),
            ),
          ),
      ]);
    });
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({required this.week, required this.state, required this.selected, required this.wide, required this.onTap});
  final PlanWeek week;
  final WeekState state;
  final bool selected, wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = week.completion;
    final (label, icon, tone) = weekLook(state, done);
    final color = switch (tone) { Tone.success => c.success, Tone.accent => c.accent, Tone.warning => c.warning, _ => c.secondary };
    return Semantics(
      button: true, selected: selected,
      // "this week" is the calendar; "selected" is the choice; the value is the state. Three separate facts.
      label: 'Week ${week.number}, ${week.range}${week.isCurrent ? ', this week' : ''}, '
          '${done.eligible == 0 ? 'no workouts' : '${done.completed} of ${done.eligible} workouts completed'}',
      value: label,
      child: Material(
        // Selection is the border and the tint. The current week is said in words, so the two never look alike.
        color: selected ? c.accentSoft : c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile), side: BorderSide(color: selected ? c.accent : c.divider, width: selected ? 2 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('week-${week.number}'),
          onTap: () {
            if (!selected) Haptics.selection();
            onTap();
          },
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 84),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 14 : 8, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Week ${week.number}', style: context.numStyle(15, weight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(week.range, style: context.numStyle(12.5, color: c.secondary, weight: FontWeight.w400)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Padding(padding: const EdgeInsets.only(right: 5), child: Icon(icon, size: 16, color: color)),
                    Flexible(child: Text(label, style: context.numStyle(13, color: tone == Tone.neutral ? c.secondary : color))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
