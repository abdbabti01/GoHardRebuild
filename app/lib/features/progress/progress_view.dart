import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../activity/move_widgets.dart' show PersonalBestsCard;
import '../plans/plan_progress.dart' show dateRange;
import '../shell/home_shell.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'goal_repository.dart';
import 'recap_screen.dart';
import 'trend_screens.dart';
import 'trends.dart';
import 'weekly.dart';

/// Train › Progress (docs/PROGRESS.md): this week's activity against the goals the person chose, strength trends,
/// plan adherence, last week's recap, then the quieter history. Everything is computed from local records.

final weeklyGoalListProvider = Provider<List<WeeklyGoal>>((ref) => [for (final r in ref.watch(weeklyGoalsProvider).value ?? const <Stored<WeeklyGoal>>[]) r.value]);
final _runListProvider = Provider<List<Run>>((ref) => [for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) r.value]);

/// One week's summary, recomputed from the records whenever they (or the day) change; never a stored snapshot.
final weekSummaryProvider = Provider.family<WeekSummary, String>((ref, monday) => summarizeWeek(
    monday: monday, today: ref.watch(todayKeyProvider), workouts: ref.watch(workoutListProvider), runs: ref.watch(_runListProvider), goals: ref.watch(weeklyGoalListProvider)));

/// This week, following the day as it rolls over.
final currentWeekProvider = Provider<WeekSummary>((ref) => ref.watch(weekSummaryProvider(mondayOf(ref.watch(todayKeyProvider)))));

/// Completed weeks that a recap can show, newest first (last week first).
final completedWeeksProvider = Provider<List<String>>((ref) => completedWeeks(today: ref.watch(todayKeyProvider), workouts: ref.watch(workoutListProvider), runs: ref.watch(_runListProvider)));

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : many ?? '${one}s'}';

/// What the coach on Train › Progress says: one fact from this week, or how to set a goal. Nothing is asked of the AI.
String progressCoachLine(WeekSummary week, {required bool? goalsSupported}) {
  final done = '${plural(week.workoutCount, 'workout')} and ${plural(week.activityCount, 'run or walk', 'runs or walks')}';
  if (week.workoutsTarget != null) return '${week.workoutCount} of ${week.workoutsTarget} workouts recorded this week.';
  if (week.runWalkTarget != null) return '${week.activityCount} of ${week.runWalkTarget} runs or walks recorded this week.';
  if (goalsSupported == false) return 'This week so far: $done recorded.';
  return week.isEmpty ? 'Nothing recorded yet this week. Set weekly goals below if you\'d like a target.' : 'This week so far: $done recorded. Set weekly goals below if you\'d like a target.';
}

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final primary = ref.watch(primaryPlanProvider);
    final index = ref.watch(trendIndexProvider);
    final weeks = ref.watch(completedWeeksProvider);
    final recent = ([for (final w in ref.watch(workoutListProvider)) if (!w.isDeleted && !w.isOpen) w]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc))).take(3).toList();
    final previews = [for (final t in index.recent) if (t.metric != TrendMetric.none) t].take(2).toList();
    final most = p.weeks.fold<int>(1, (m, w) => w.$2 > m ? w.$2 : m);
    const gap = SizedBox(height: 10), between = SizedBox(height: 28);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _WeekPanel(),
      between,
      SectionHeader('Strength trends',
          trailing: index.trends.isEmpty ? null : QuietLink('See all', key: const Key('trends-see-all'), said: 'See all exercise trends', onPressed: () => push(context, const ExerciseListScreen()))),
      gap,
      if (previews.isEmpty)
        // History is offered in every state, including an account with nothing recorded yet.
        p.hasEvidence
            ? Panel(child: Text('No exercise with a stable identity has recorded sets yet. Movements typed as free text have no trend.', style: context.caption))
            : EmptyState('No training recorded yet', 'Trends are built only from workouts you actually record. There is nothing to chart until then.',
                action: SecondaryButton('Start a manual workout', onPressed: () => startManualWorkout(context, ref)))
      else
        for (final (i, t) in previews.indexed) ...[if (i > 0) gap, TrendPreview(t)],
      between,
      const SectionHeader('Am I following my plan?'),
      gap,
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (primary == null)
            Text('You have no primary plan right now. Manual training still counts as training.', style: context.caption)
          else if (p.dueOccasions == 0)
            Text('No planned workout has come due yet.', style: context.caption)
          else ...[
            Text('${p.recorded} of ${p.dueOccasions} due workouts recorded', style: context.numStyle(17)),
            const SizedBox(height: 10),
            ProgressRail(p.recorded / p.dueOccasions, label: 'Due workouts recorded'),
            const SizedBox(height: 10),
            Text('${p.full} completed · ${p.partial} partial · ${p.skipped} skipped · ${p.missed} missed', style: context.numStyle(13.5, color: context.c.secondary, weight: FontWeight.w400)),
          ],
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: QuietLink(primary == null ? 'Plans' : 'View your plan', key: const Key('progress-view-plan'), said: 'Open Train, Plan',
                onPressed: () => ref.read(shellProvider.notifier).selectTrainView(TrainView.plan)),
          ),
          Text('Weekly goals are separate: they never schedule, move or complete a planned workout.', style: context.caption),
        ]),
      ),
      between,
      _RecapLink(monday: weeks.first, older: weeks.length - 1),
      between,
      const SectionHeader('Am I consistent?'),
      gap,
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Days with recorded training in each of the last 8 weeks. ${plural(p.sessions, 'session')} in total.', style: context.caption),
          const SizedBox(height: 14),
          Semantics(
            label: 'Training days per week, oldest first: ${p.weeks.map((w) => w.$2).join(', ')}',
            child: ExcludeSemantics(
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final w in p.weeks)
                  Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${w.$2}', style: context.numStyle(13)),
                      const SizedBox(height: 2),
                      Container(height: 6 + 58 * w.$2 / most, margin: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(color: w.$2 == 0 ? context.c.outline : context.c.accent, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      FittedBox(fit: BoxFit.scaleDown, child: Text(dayMonthNumeric(w.$1), style: context.numStyle(12.5, color: context.c.secondary, weight: FontWeight.w400))),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      ),
      if (recent.isNotEmpty) ...[
        between,
        const SectionHeader('Recent workouts'),
        gap,
        GroupCard(children: [for (final w in recent) WorkoutRow(w, grouped: true)]),
      ],
      between,
      GroupCard(children: [
        GroupRow(key: const Key('progress-history'), icon: Icons.history, title: 'Workout history', subtitle: 'Every workout you recorded', onTap: () => push(context, const WorkoutHistoryScreen())),
      ]),
      // Run / Walk personal bests, once something is saved: the same projection History shows.
      if (ref.watch(_runListProvider).any((r) => !r.isDeleted && !r.isOpen)) ...[between, const PersonalBestsCard()],
    ]);
  }
}

String dayMonthNumeric(String dayKey) {
  final p = dayKey.split('-');
  return '${int.parse(p[1])}/${int.parse(p[2])}';
}

/// This week in the approved pale panel: the date range, Set/Edit goals, then Workouts and Run / Walk, each with
/// its real count and, only where a target was chosen, "n of target" and a bar capped at full.
class _WeekPanel extends ConsumerWidget {
  const _WeekPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(currentWeekProvider);
    final supported = ref.watch(weeklyGoalsSupportedProvider);
    final stored = (ref.watch(weeklyGoalsProvider).value ?? const <Stored<WeeklyGoal>>[]).where((r) => r.value.weekStart == week.monday).firstOrNull;
    final range = dateRange(week.monday, week.sunday);
    final pictured = MediaQuery.textScalerOf(context).scale(10) <= 13;
    String said(String what, int? target, String counted) => target == null ? '$what: $counted recorded this week, no target.' : '$what: $counted of $target this week.';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PanelTheme(
        child: Builder(
          builder: (context) => PanelSurface(
            key: const Key('progress-week-panel'),
            photo: pictured ? const PanelPhoto('assets/images/workout-hero.webp', alignment: Alignment(1, 0.6)) : null,
            below: [
              _GoalRow(key: const Key('goal-row-workouts'), icon: Icons.fitness_center, label: 'Workouts', count: week.workoutCount, target: week.workoutsTarget,
                  said: said('Workouts', week.workoutsTarget, week.workoutsTarget == null ? plural(week.workoutCount, 'workout') : '${week.workoutCount}')),
              const SizedBox(height: 12),
              _GoalRow(key: const Key('goal-row-runwalk'), icon: Icons.directions_run, label: 'Run / Walk', count: week.activityCount, target: week.runWalkTarget,
                  said: said('Run / Walk', week.runWalkTarget, week.runWalkTarget == null ? plural(week.activityCount, 'run or walk', 'runs or walks') : '${week.activityCount}')),
            ],
            child: LayoutBuilder(
              builder: (context, box) => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: pictured ? box.maxWidth * PanelSurface.wordsShare : box.maxWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Overline('This week'),
                  const SizedBox(height: 4),
                  Heading('Your weekly rhythm', size: 30, serif: true),
                  const SizedBox(height: 4),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                    Text(range, key: const Key('progress-week-range'), style: context.numStyle(16, weight: FontWeight.w600)),
                    if (supported != false)
                      QuietLink(week.hasGoals ? 'Edit goals' : 'Set weekly goals', key: const Key('goals-edit'),
                          said: week.hasGoals ? 'Edit weekly goals' : 'Set weekly goals', onPressed: () => showGoalSheet(appContext(context), ref, week)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (supported == false)
        const Padding(
            padding: EdgeInsets.only(top: 10),
            child: StatusLine(Icons.cloud_off_outlined, 'Weekly goals are not available on your account\'s server yet, so none can be saved. Your counts are still shown.',
                key: Key('goals-unavailable'))),
      if (stored?.isPending ?? false)
        const Padding(padding: EdgeInsets.only(top: 10), child: StatusLine(Icons.phone_iphone, 'Goals saved on this phone · sync pending', key: Key('goals-pending'))),
      if (stored?.needsReview ?? false)
        const Padding(padding: EdgeInsets.only(top: 10), child: StatusLine(Icons.rule, 'This week\'s goals were also changed on another device. Review them from the notice at the bottom of the screen.', tone: Tone.warning)),
    ]);
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({super.key, required this.icon, required this.label, required this.count, required this.target, required this.said});
  final IconData icon;
  final String label, said;
  final int count;
  final int? target;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true, label: said,
        child: ExcludeSemantics(
          child: Row(children: [
            Icon(icon, size: 26, color: context.c.text),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, children: [
                  Text(label, style: context.sansStyle(16, weight: FontWeight.w500)),
                  Text(target == null ? '$count recorded' : '$count of $target', style: context.numStyle(16)),
                ]),
                if (target != null) ...[const SizedBox(height: 6), ProgressRail(count / target!, label: '$label goal', height: 10)],
              ]),
            ),
          ]),
        ),
      );
}

/// The weekly goals form: two optional whole numbers, effective from this week. Plans are untouched.
Future<void> showGoalSheet(BuildContext context, WidgetRef ref, WeekSummary week) => showGoSheet<void>(context, title: 'Weekly goals', builder: (_) => _GoalForm(week: week));

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({required this.week});
  final WeekSummary week;
  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final _workouts = TextEditingController(text: widget.week.workoutsTarget?.toString() ?? '');
  late final _runWalk = TextEditingController(text: widget.week.runWalkTarget?.toString() ?? '');
  String? _workoutsError, _runWalkError;
  bool _saving = false;

  @override
  void dispose() {
    _workouts.dispose();
    _runWalk.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final (w, we) = GoalRepository.parse(_workouts.text);
    final (r, re) = GoalRepository.parse(_runWalk.text);
    setState(() {
      _workoutsError = we;
      _runWalkError = re;
    });
    if (we != null || re != null) return;
    final week = widget.week;
    if (w == week.workoutsTarget && r == week.runWalkTarget) {
      Navigator.pop(context); // nothing changed: no record is written
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(goalRepositoryProvider).set(week.monday, workouts: w, runWalk: r);
    } on LocalSaveFailure {
      if (mounted) setState(() => _saving = false);
      if (mounted) toast(context, 'Your goals could not be saved on this phone. Nothing changed.');
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(w == null && r == null ? 'Weekly goals cleared from this week.' : 'Weekly goals saved.'), duration: const Duration(milliseconds: 2200)));
  }

  Widget _field(String key, String label, TextEditingController c, String? error) => TextField(
        key: Key(key), controller: c, enabled: !_saving,
        keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label, helperText: '1 to 21 a week, or blank for no target', errorText: error, helperMaxLines: 2, errorMaxLines: 3),
      );

  @override
  Widget build(BuildContext context) {
    final week = widget.week;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('These are weekly activity targets. Your training plan stays the same.', key: const Key('goals-helper'), style: context.body),
      const SizedBox(height: 6),
      Text('They apply from this week (${dateRange(week.monday, week.sunday)}) until you change them. Earlier weeks keep the goals they had. '
          'Leave a field blank for no target.', style: context.caption),
      const SizedBox(height: 18),
      _field('goal-workouts', 'Workouts per week', _workouts, _workoutsError),
      const SizedBox(height: 14),
      _field('goal-runwalk', 'Runs and walks per week', _runWalk, _runWalkError),
      const SizedBox(height: 20),
      PrimaryButton('Save goals', key: const Key('goals-save'), onPressed: _saving ? null : _save),
    ]);
  }
}

/// Last week's recap, with the older completed weeks reached from inside it.
class _RecapLink extends StatelessWidget {
  const _RecapLink({required this.monday, required this.older});
  final String monday;
  final int older;

  @override
  Widget build(BuildContext context) {
    final range = dateRange(monday, addDays(monday, 6));
    return Semantics(
      button: true, label: 'Last week\'s recap, $range${older > 0 ? '. Earlier weeks are inside.' : ''}',
      child: ExcludeSemantics(
        child: Pressable(
          key: const Key('progress-recap'),
          borderRadius: BorderRadius.circular(Radii.panel),
          onTap: () => push(context, WeeklyRecapScreen(monday: monday)),
          child: PanelTheme(
            child: Builder(
              builder: (context) => PanelSurface(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  Icon(Icons.event_available_outlined, size: 26, color: context.c.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Last week\'s recap', style: context.pageTitleStyle(21)),
                      Text(older > 0 ? '$range · earlier weeks inside' : range, style: context.sansStyle(15, color: context.c.secondary)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: context.c.text),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A strength trend in the overview: the exercise, its latest comparable result and a small chart. Opens the trend.
class TrendPreview extends ConsumerWidget {
  const TrendPreview(this.trend, {super.key});
  final ExerciseTrend trend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(loadUnitProvider);
    final today = ref.watch(todayKeyProvider);
    final reps = trend.defaultReps;
    final all = trend.points(reps: reps);
    final pts = inRange(all, TrendRange.weeks12, today);
    final shown = pts.isEmpty ? all : pts;
    final latest = all.last;
    final value = trendValue(trend, latest, unit);
    return Semantics(
      button: true, label: '${trend.name}. Latest recorded $value on ${dayMonth(latest.dayKey)}. ${metricLabel(trend, reps)}. ${plural(shown.length, 'session')} charted.',
      child: ExcludeSemantics(
        child: Pressable(
          key: Key('trend-preview-${trend.key}'),
          borderRadius: BorderRadius.circular(Radii.panel),
          onTap: () => push(context, ExerciseTrendScreen(exerciseKey: trend.key)),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trend.name, style: context.sansStyle(16, weight: FontWeight.w600)),
                    Text(value, style: context.pageTitleStyle(28)),
                    Text('Latest recorded · ${dayMonth(latest.dayKey)}', style: context.caption),
                  ]),
                ),
                Icon(Icons.chevron_right, color: context.c.secondary),
              ]),
              const SizedBox(height: 8),
              TrendChart(points: shown, axisLabel: (v) => axisValue(trend, v, unit), height: 84, compact: true),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "92.5 kg × 8", "12 reps", "1:30".
String trendValue(ExerciseTrend t, TrendPoint p, LoadUnit unit) => switch (t.metric) {
      TrendMetric.load => '${formatLoad(p.value, unit)} × ${p.set.reps}',
      TrendMetric.reps => '${p.value.round()} reps',
      TrendMetric.duration => secondsText(p.value.round()),
      TrendMetric.none => '',
    };

String axisValue(ExerciseTrend t, double v, LoadUnit unit) => switch (t.metric) {
      TrendMetric.load => formatLoadValue(v, unit),
      TrendMetric.duration => secondsText(v.round()),
      _ => formatNumber(v),
    };

String secondsText(int s) => s < 60 ? '$s s' : clockText(s);

String metricLabel(ExerciseTrend t, int? reps) => switch (t.metric) {
      TrendMetric.load => 'Top set load · $reps reps',
      TrendMetric.reps => 'Most reps in a set · no added load',
      TrendMetric.duration => 'Longest recorded time',
      TrendMetric.none => 'No comparable measure',
    };

/// The signed recorded change, shown neutrally: "+9 kg", "−2.5 kg", "No change".
String changeText(ExerciseTrend t, double delta, LoadUnit unit) {
  if (delta == 0) return 'No change';
  final sign = delta > 0 ? '+' : '−';
  return switch (t.metric) {
    TrendMetric.load => '$sign${formatLoad(delta.abs(), unit)}',
    TrendMetric.reps => '$sign${plural(delta.abs().round(), 'rep')}',
    _ => '$sign${secondsText(delta.abs().round())}',
  };
}
