import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/device_prefs.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../activity/activity_detail.dart';
import '../activity/run_walk_screens.dart' show activityTitle;
import '../coach/coach_bubble.dart';
import '../coach/coach_contract.dart';
import '../coach/coach_prefs.dart';
import '../plans/plan_progress.dart' show dateRange;
import '../workout/result_rules.dart';
import '../workout/workout_detail_screen.dart';
import 'progress_view.dart';
import 'trend_screens.dart';
import 'weekly.dart';

/// The recap of one completed Monday–Sunday week (docs/PROGRESS.md › Weekly recap), recalculated from the records
/// every time it is shown: counts, Run / Walk totals, the goals that applied that week, at most one factual strength
/// highlight, and the week's sessions. Earlier completed weeks are a step back from here.
class WeeklyRecapScreen extends ConsumerStatefulWidget {
  const WeeklyRecapScreen({super.key, required this.monday});
  final String monday;
  @override
  ConsumerState<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends ConsumerState<WeeklyRecapScreen> {
  late String _monday = widget.monday;

  @override
  Widget build(BuildContext context) {
    final weeks = ref.watch(completedWeeksProvider);
    // A week that is no longer complete (the clock went back) or not offered falls back to the newest completed one.
    if (!weeks.contains(_monday)) _monday = weeks.first;
    final i = weeks.indexOf(_monday);
    final week = ref.watch(weekSummaryProvider(_monday));
    final unit = ref.watch(devicePrefsProvider.select((p) => p.distance));
    final load = ref.watch(loadUnitProvider);
    final highlight = strengthHighlight(week, ref.watch(trendIndexProvider));
    final coachOn = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    final range = dateRange(week.monday, week.sunday);
    final isLast = i == 0;
    final runs = week.runs.length, walks = week.walks.length;
    final activityLabel = runs == 0 ? (walks == 1 ? 'Walk' : 'Walks') : walks == 0 ? (runs == 1 ? 'Run' : 'Runs') : 'Runs and walks';
    final distance = week.distance, active = week.activeSeconds;
    final said = [
      if (week.workoutCount > 0) plural(week.workoutCount, 'workout'),
      if (runs > 0) plural(runs, 'run'),
      if (walks > 0) plural(walks, 'walk'),
    ];

    // Built with the panel's own context, so the figures take its dark ink.
    Widget stat(BuildContext context, String key, String value, String label) => Column(key: Key(key), crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: context.pageTitleStyle(32)),
          Text(label, style: context.sansStyle(15, color: context.c.secondary)),
        ]);

    return AppPage(title: 'Weekly recap', children: [
      // Previous and next among completed weeks; the current week is never shown as finished.
      Row(children: [
        IconButton(key: const Key('recap-previous'), tooltip: 'Previous week', onPressed: i + 1 < weeks.length ? () => setState(() => _monday = weeks[i + 1]) : null, icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text(isLast ? 'Last week · $range' : 'Week of $range', key: const Key('recap-range'), textAlign: TextAlign.center, style: context.sansStyle(16, weight: FontWeight.w600))),
        IconButton(key: const Key('recap-next'), tooltip: 'Next week', onPressed: i > 0 ? () => setState(() => _monday = weeks[i - 1]) : null, icon: const Icon(Icons.chevron_right)),
      ]),
      const SizedBox(height: 8),
      Semantics(
        container: true,
        label: '${isLast ? 'Last week' : 'Week of'} $range. ${week.isEmpty ? 'No activity was recorded.' : '${said.join(', ')} recorded.'}'
            '${week.activities.isEmpty ? '' : ' ${week.activityWord} distance ${distance.known ? unit.distance(distance.value) : 'not recorded'}${distance.incomplete ? ', some distances not recorded' : ''}. Active time ${active.known ? durationText(active.value.round()) : 'not recorded'}.'}',
        child: ExcludeSemantics(
          child: PhotoPanel(
            key: const Key('recap-panel'),
            photo: 'assets/images/workout-hero.webp',
            photoAlignment: const Alignment(1, 0.6),
            content: (context) => [
              Overline(isLast ? 'Last week · $range' : 'Week of $range'),
              const SizedBox(height: 4),
              Text('Your week, recorded', style: context.pageTitleStyle(28)),
              const SizedBox(height: 10),
              if (week.isEmpty)
                Text('No activity was recorded this week.', key: const Key('recap-empty'), style: context.sansStyle(16))
              else ...[
                Wrap(spacing: 28, runSpacing: 12, children: [
                  stat(context, 'recap-workouts', '${week.workoutCount}', week.workoutCount == 1 ? 'Workout' : 'Workouts'),
                  stat(context, 'recap-activities', '${week.activityCount}', activityLabel),
                ]),
                if (week.activities.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 28, runSpacing: 12, children: [
                    stat(context, 'recap-distance', distance.known ? unit.distance(distance.value) : '—', '${week.activityWord} distance'),
                    stat(context, 'recap-active', active.known ? durationText(active.value.round()) : '—', '${week.activityWord} time'),
                  ]),
                  if (distance.incomplete)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${plural(distance.missing, 'activity', 'activities')} had no distance recorded and ${distance.missing == 1 ? 'is' : 'are'} not in the total.',
                          key: const Key('recap-incomplete'), style: context.sansStyle(13.5, color: context.c.secondary)),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 26),
      const SectionHeader('Your weekly targets'),
      const SizedBox(height: 10),
      if (!week.hasGoals)
        Panel(child: Text('No goals were set for this week.', key: const Key('recap-no-goals'), style: context.sansStyle(15, color: context.c.secondary)))
      else
        GroupCard(children: [
          if (week.workoutsTarget != null) _TargetRow(key: const Key('recap-goal-workouts'), icon: Icons.fitness_center, label: 'Workouts', count: week.workoutCount, target: week.workoutsTarget!),
          if (week.runWalkTarget != null) _TargetRow(key: const Key('recap-goal-runwalk'), icon: Icons.directions_run, label: 'Run / Walk', count: week.activityCount, target: week.runWalkTarget!),
        ]),
      if (highlight != null) ...[
        const SizedBox(height: 26),
        const SectionHeader('Strength highlight'),
        const SizedBox(height: 10),
        GroupCard(children: [
          GroupRow(
            key: const Key('recap-highlight'), icon: Icons.show_chart, title: highlight.trend.name,
            value: '${trendValue(highlight.trend, highlight.first, load)} → ${trendValue(highlight.trend, highlight.last, load)}',
            subtitle: '${dayMonth(highlight.first.dayKey)} → ${dayMonth(highlight.last.dayKey)} · recorded at ${highlight.reps} reps',
            onTap: () => push(context, ExerciseTrendScreen(exerciseKey: highlight.trend.key)),
          ),
        ]),
      ],
      // The recap coach announces the recorded counts only; it asks nothing of the AI by itself.
      if (coachOn) ...[
        const SizedBox(height: 22),
        CoachSpeaker(
          key: const Key('recap-coach'),
          say: CoachSay(week.isEmpty ? 'No activity was recorded in the week of $range.' : 'You recorded ${said.length == 1 ? said.single : '${said.take(said.length - 1).join(', ')} and ${said.last}'} in the week of $range.',
              ask: const CoachContext(label: 'Your progress')),
        ),
      ],
      const SizedBox(height: 26),
      SectionHeader('This week\'s sessions', detail: week.isEmpty ? null : '${week.workoutCount + week.activityCount}'),
      const SizedBox(height: 10),
      if (week.isEmpty)
        Text('Nothing was recorded between ${longDate(week.monday)} and ${longDate(week.sunday)}.', style: context.caption)
      else
        GroupCard(key: const Key('recap-sessions'), children: [
          for (final (_, row) in [
            for (final w in week.workouts)
              (w.startedAtUtc, GroupRow(key: Key('recap-workout-${w.id}'), icon: Icons.fitness_center, tone: Tone.neutral, title: w.title,
                  subtitle: '${shortDate(w.dayKey)} · ${WorkoutResultRules.label(w.outcome)} · ${plural(w.performedSets, 'set')}',
                  onTap: () => push(context, WorkoutDetailScreen(workoutId: w.id)))),
            for (final r in week.activities)
              (r.startedAtUtc, GroupRow(key: Key('recap-run-${r.id}'), icon: r.isWalk ? Icons.directions_walk : Icons.directions_run, tone: Tone.neutral, title: r.title ?? activityTitle(r.activityType),
                  subtitle: [shortDate(r.dayKey), activityTitle(r.activityType), if (r.distanceMeters != null) unit.distance(r.distanceMeters), durationText(r.activeDurationSeconds!)].join(' · '),
                  onTap: () => push(context, ActivityDetailScreen(runId: r.id)))),
          ]..sort((a, b) => a.$1.compareTo(b.$1)))
            row,
        ]),
    ]);
  }
}

/// A goal of the week with its real count. Reached is said in words and a check, never by colour alone; the bar
/// stops at full while the count keeps the real number.
class _TargetRow extends StatelessWidget {
  const _TargetRow({super.key, required this.icon, required this.label, required this.count, required this.target});
  final IconData icon;
  final String label;
  final int count, target;

  @override
  Widget build(BuildContext context) {
    final reached = count >= target;
    return Semantics(
      container: true, label: '$label: $count of $target${reached ? ', reached' : ''}.',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(reached ? Icons.check_circle : Icons.radio_button_unchecked, size: 26, color: reached ? context.c.accent : context.c.outline),
            const SizedBox(width: 10),
            Icon(icon, size: 22, color: context.c.text),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 8, children: [
                  Text(label, style: context.sansStyle(16, weight: FontWeight.w600)),
                  Text('$count of $target${reached ? ' · reached' : ''}', style: context.numStyle(15.5, color: context.c.secondary)),
                ]),
                const SizedBox(height: 6),
                ProgressRail(count / target, label: '$label goal'),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

