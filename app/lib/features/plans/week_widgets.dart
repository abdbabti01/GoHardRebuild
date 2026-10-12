import 'package:flutter/material.dart';

import '../../core/clock.dart';
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
                _ when done => Icon(Icons.check_circle, size: 26, color: c.success),
                OccasionStatus.inProgress => Icon(Icons.timelapse, size: 26, color: c.accent),
                OccasionStatus.missed => Icon(Icons.error_outline, size: 26, color: c.warning),
                OccasionStatus.skipped => Icon(Icons.remove_circle_outline, size: 26, color: c.outline),
                OccasionStatus.paused => Icon(Icons.pause_circle_outline, size: 26, color: c.outline),
                _ => Icon(Icons.radio_button_unchecked, size: 26, color: c.accent),
              };
              return Semantics(
                label: '${longDate(day)}${isToday ? ', today' : ''}, ${occasion == null ? 'rest day' : '${occasion.title}, ${status!.label}'}',
                child: ExcludeSemantics(
                  child: Column(children: [
                    SizedBox(height: 28, child: Center(child: mark)),
                    const SizedBox(height: 4),
                    Text(weekdayShort(parseDayKey(day).weekday), style: context.sansStyle(13, weight: isToday ? FontWeight.w700 : FontWeight.w500, color: isToday ? c.accent : c.text)),
                    Text('${parseDayKey(day).day}', style: context.sansStyle(13, weight: isToday ? FontWeight.w700 : FontWeight.w400, color: isToday ? c.accent : c.secondary)),
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

/// The block's weeks as tiles: number, date range and state on every tile, including the selected one.
/// Three or four across, fewer with large text; a long block starts with the weeks around the chosen one.
class WeekGrid extends StatefulWidget {
  const WeekGrid({super.key, required this.weeks, required this.selected, required this.onSelect});
  final List<PlanWeek> weeks;
  final int selected;
  final ValueChanged<int> onSelect;

  /// More weeks than this start collapsed behind "All weeks".
  static const collapseAbove = 12, window = 8;

  @override
  State<WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<WeekGrid> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final weeks = widget.weeks;
    final collapsible = weeks.length > WeekGrid.collapseAbove;
    var shown = weeks;
    if (collapsible && !_all) {
      final from = ((widget.selected - 1) ~/ WeekGrid.window) * WeekGrid.window;
      shown = weeks.sublist(from, (from + WeekGrid.window).clamp(0, weeks.length));
    }
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, box) {
        // Wide enough for "Sep 28 – Oct 4" on one line at the current text size; tiles in a row share a height.
        final columns = (box.maxWidth / (106 * scale)).floor().clamp(1, 4);
        const gap = 8.0;
        return Column(children: [
          for (var i = 0; i < shown.length; i += columns)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var j = i; j < i + columns; j++) ...[
                    if (j > i) const SizedBox(width: gap),
                    Expanded(child: j >= shown.length ? const SizedBox() : _WeekTile(week: shown[j], selected: shown[j].number == widget.selected, onTap: () => widget.onSelect(shown[j].number))),
                  ],
                ]),
              ),
            ),
        ]);
      }),
      if (collapsible)
        TextButton(
          key: const Key('weeks-all'),
          onPressed: () => setState(() => _all = !_all),
          child: Text(_all ? 'Show fewer weeks' : 'All ${weeks.length} weeks'),
        ),
    ]);
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({required this.week, required this.selected, required this.onTap});
  final PlanWeek week;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = week.completion;
    final (String state, IconData? icon, Color color) = done.eligible == 0
        ? ('No workouts', null, c.secondary)
        : done.isDone
            ? ('Done', Icons.check_circle, c.success)
            : week.isCurrent || week.isPast || done.completed > 0
                ? ('${done.completed} of ${done.eligible}', week.isCurrent ? Icons.timelapse : null, week.isCurrent ? c.accent : c.text)
                : ('Planned', null, c.secondary);
    return Semantics(
      button: true, selected: selected,
      label: 'Week ${week.number}, ${week.range}${week.isCurrent ? ', this week' : ''}, '
          '${done.eligible == 0 ? 'no workouts' : '${done.completed} of ${done.eligible} workouts completed'}',
      child: Material(
        color: selected ? c.accentSoft : c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile), side: BorderSide(color: selected ? c.accent : c.divider, width: selected ? 2 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('week-${week.number}'),
          onTap: onTap,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 84),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Week ${week.number}', style: context.sansStyle(14.5, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(week.range, textAlign: TextAlign.center, style: context.sansStyle(13, color: c.secondary)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(icon, size: 16, color: color)),
                    Flexible(child: Text(state, textAlign: TextAlign.center, style: context.sansStyle(13, weight: FontWeight.w600, color: color))),
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
