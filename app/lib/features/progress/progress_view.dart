import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../activity/move_widgets.dart' show PersonalBestsCard;
import '../body/body_screens.dart' show BodyProgressScreen;
import '../plans/plan_progress.dart' show dateRange;
import '../shell/home_shell.dart';
import '../workout/workout_flow.dart';
import 'goal_repository.dart';
import 'recap_screen.dart';
import 'trend_screens.dart';
import 'trends.dart';
import 'weekly.dart';

/// Train › Progress (docs/PROGRESS.md): this week's activity against the goals the person chose, strength trends,
/// plan adherence, last week's recap, consistency and personal bests. Recorded sessions themselves live in Train ›
/// Workouts (Recent workouts and the full history); a chart point or a recap opens the workout it came from.
/// Everything is computed from local records.

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
String progressCoachLine(WeekSummary week, {required bool? goalsSupported, AppLocalizations? l}) {
  l ??= currentL10n;
  if (week.workoutsTarget != null) return l.progressCoachWorkoutsOfTarget(week.workoutCount, week.workoutsTarget!);
  if (week.runWalkTarget != null) return l.progressCoachRunWalkOfTarget(week.activityCount, week.runWalkTarget!);
  if (goalsSupported == false) return l.progressCoachSoFar(week.workoutCount, week.activityCount);
  return week.isEmpty ? l.progressCoachNothingYet : l.progressCoachSoFarSetGoals(week.workoutCount, week.activityCount);
}

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final primary = ref.watch(primaryPlanProvider);
    final index = ref.watch(trendIndexProvider);
    final weeks = ref.watch(completedWeeksProvider);
    final previews = [for (final t in index.recent) if (t.metric != TrendMetric.none) t].take(2).toList();
    final most = p.weeks.fold<int>(1, (m, w) => w.$2 > m ? w.$2 : m);
    const gap = SizedBox(height: 10), between = SizedBox(height: 28);
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _WeekPanel(),
      between,
      SectionHeader(l.progressStrengthTrends,
          trailing: index.trends.isEmpty ? null : QuietLink(l.progressSeeAll, key: const Key('trends-see-all'), said: l.progressSeeAllTrendsSemantic, onPressed: () => push(context, const ExerciseListScreen()))),
      gap,
      if (previews.isEmpty)
        // History is offered in every state, including an account with nothing recorded yet.
        p.hasEvidence
            ? Panel(child: Text(l.progressNoStableTrend, style: context.caption))
            : EmptyState(l.progressNoTrainingTitle, l.progressNoTrainingBody,
                action: SecondaryButton(l.progressStartManual, onPressed: () => startManualWorkout(context, ref)))
      else
        for (final (i, t) in previews.indexed) ...[if (i > 0) gap, TrendPreview(t)],
      // Body progress belongs to Me; this is only a quiet way there.
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: QuietLink(l.progressBodyLink, key: const Key('progress-body'), said: l.progressBodyLinkSemantic, onPressed: () => push(context, const BodyProgressScreen())),
      ),
      between,
      SectionHeader(l.progressPlanHeader),
      gap,
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (primary == null)
            Text(l.progressNoPrimary, style: context.caption)
          else if (p.dueOccasions == 0)
            Text(l.progressNothingDue, style: context.caption)
          else ...[
            Text(l.progressDueRecorded(p.recorded, p.dueOccasions), style: context.numStyle(17)),
            const SizedBox(height: 10),
            ProgressRail(p.recorded / p.dueOccasions, label: l.progressDueRail),
            const SizedBox(height: 10),
            Text(l.progressAdherenceBreakdown(p.full, p.partial, p.skipped, p.missed), style: context.numStyle(13.5, color: context.c.secondary, weight: FontWeight.w400)),
          ],
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: QuietLink(primary == null ? l.progressPlansLink : l.progressViewPlan, key: const Key('progress-view-plan'), said: l.progressOpenPlanSemantic,
                onPressed: () => ref.read(shellProvider.notifier).selectTrainView(TrainView.plan)),
          ),
          Text(l.progressGoalsSeparate, style: context.caption),
        ]),
      ),
      between,
      _RecapLink(monday: weeks.first, older: weeks.length - 1),
      between,
      SectionHeader(l.progressConsistencyHeader),
      gap,
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.progressConsistencyCaption(p.sessions), style: context.caption),
          const SizedBox(height: 14),
          Semantics(
            label: l.progressConsistencySemantic(p.weeks.map((w) => w.$2).join(l.workoutListSeparator)),
            // Oldest week on the left in every language: time runs left to right.
            child: ExcludeSemantics(
              child: Directionality(textDirection: TextDirection.ltr, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
              ])),
            ),
          ),
        ]),
      ),
      // Run / Walk personal bests, once something is saved: the same projection History shows.
      if (ref.watch(_runListProvider).any((r) => !r.isDeleted && !r.isOpen)) ...[between, const PersonalBestsCard()],
    ]);
  }
}

/// "10/12" in English (month first); day first in French and Arabic ("12/10").
String dayMonthNumeric(String dayKey) {
  final p = dayKey.split('-');
  final m = int.parse(p[1]), d = int.parse(p[2]);
  return currentLocale.languageCode == 'en' ? '$m/$d' : '$d/$m';
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
    final l = context.l10n;
    String said(String what, int? target, int count, String counted) => target == null ? l.progressGoalSaidNoTarget(what, counted) : l.progressGoalSaidTarget(what, count, target);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PanelTheme(
        child: Builder(
          builder: (context) => PanelSurface(
            key: const Key('progress-week-panel'),
            photo: pictured ? const PanelPhoto('assets/images/workout-hero.webp', alignment: Alignment(1, 0.6)) : null,
            below: [
              _GoalRow(key: const Key('goal-row-workouts'), icon: Icons.fitness_center, label: l.progressWorkoutsLabel, count: week.workoutCount, target: week.workoutsTarget,
                  said: said(l.progressWorkoutsLabel, week.workoutsTarget, week.workoutCount, l.progressWorkoutCount(week.workoutCount))),
              const SizedBox(height: 12),
              _GoalRow(key: const Key('goal-row-runwalk'), icon: Icons.directions_run, label: l.progressRunWalkLabel, count: week.activityCount, target: week.runWalkTarget,
                  said: said(l.progressRunWalkLabel, week.runWalkTarget, week.activityCount, l.progressRunWalkCount(week.activityCount))),
            ],
            child: LayoutBuilder(
              builder: (context, box) => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: pictured ? box.maxWidth * PanelSurface.wordsShare : box.maxWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Overline(l.progressThisWeek),
                  const SizedBox(height: 4),
                  Heading(l.progressWeeklyRhythm, size: 30, serif: true),
                  const SizedBox(height: 4),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                    Text(range, key: const Key('progress-week-range'), style: context.numStyle(16, weight: FontWeight.w600)),
                    if (supported != false)
                      QuietLink(week.hasGoals ? l.progressEditGoals : l.progressSetGoals, key: const Key('goals-edit'),
                          said: week.hasGoals ? l.progressEditGoalsSemantic : l.progressSetGoals, onPressed: () => showGoalSheet(appContext(context), ref, week)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (supported == false)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: StatusLine(Icons.cloud_off_outlined, l.progressGoalsUnavailable,
                key: const Key('goals-unavailable'))),
      if (stored?.isPending ?? false)
        Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.phone_iphone, l.progressGoalsPending, key: const Key('goals-pending'))),
      if (stored?.needsReview ?? false)
        Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.rule, l.progressGoalsReview, tone: Tone.warning)),
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
                  Text(target == null ? context.l10n.progressCountRecorded(count) : context.l10n.progressCountOfTarget(count, target!), style: context.numStyle(16)),
                ]),
                if (target != null) ...[const SizedBox(height: 6), ProgressRail(count / target!, label: context.l10n.progressGoalRail(label), height: 10)],
              ]),
            ),
          ]),
        ),
      );
}

/// The weekly goals form: two optional whole numbers, effective from this week. Plans are untouched.
Future<void> showGoalSheet(BuildContext context, WidgetRef ref, WeekSummary week) => showGoSheet<void>(context, title: context.l10n.progressGoalsTitle, builder: (_) => _GoalForm(week: week));

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
    String? say(GoalInputError? e) => e == null ? null : context.l10n.progressGoalRangeError(goalRange.$1, goalRange.$2);
    setState(() {
      _workoutsError = say(we);
      _runWalkError = say(re);
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
      if (mounted) toast(context, context.l10n.progressGoalsSaveFailed);
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context), l = context.l10n;
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(w == null && r == null ? l.progressGoalsCleared : l.progressGoalsSaved), duration: const Duration(milliseconds: 2200)));
  }

  Widget _field(String key, String label, TextEditingController c, String? error) => TextField(
        key: Key(key), controller: c, enabled: !_saving,
        keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9\u0660-\u0669\u06F0-\u06F9]')), LengthLimitingTextInputFormatter(2)],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label, helperText: context.l10n.progressGoalFieldHelper(goalRange.$1, goalRange.$2), errorText: error, helperMaxLines: 2, errorMaxLines: 3),
      );

  @override
  Widget build(BuildContext context) {
    final week = widget.week, l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.progressGoalsHelper, key: const Key('goals-helper'), style: context.body),
      const SizedBox(height: 6),
      Text(l.progressGoalsApply(dateRange(week.monday, week.sunday)), style: context.caption),
      const SizedBox(height: 18),
      _field('goal-workouts', l.progressGoalWorkoutsField, _workouts, _workoutsError),
      const SizedBox(height: 14),
      _field('goal-runwalk', l.progressGoalRunWalkField, _runWalk, _runWalkError),
      const SizedBox(height: 20),
      PrimaryButton(l.progressGoalsSave, key: const Key('goals-save'), onPressed: _saving ? null : _save),
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
    final l = context.l10n;
    return PanelLink(
      key: const Key('progress-recap'), icon: const Icon(Icons.event_available_outlined), title: l.progressRecapLinkTitle,
      subtitle: older > 0 ? l.progressRecapLinkOlder(range) : range,
      semanticLabel: older > 0 ? l.progressRecapLinkSemanticOlder(range) : l.progressRecapLinkSemantic(range),
      onTap: () => push(context, WeeklyRecapScreen(monday: monday)),
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
    final l = context.l10n, name = ref.watch(exerciseNamesProvider).name(trend.key, trend.name, Localizations.localeOf(context));
    return Semantics(
      button: true, label: l.progressTrendPreviewSemantic(name, value, dayMonth(latest.dayKey), metricLabel(trend, reps), shown.length),
      child: ExcludeSemantics(
        child: Pressable(
          key: Key('trend-preview-${trend.key}'),
          borderRadius: BorderRadius.circular(Radii.panel),
          onTap: () => push(context, ExerciseTrendScreen(exerciseKey: trend.key)),
          child: Panel(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 12).resolve(Directionality.of(context)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: context.sansStyle(16, weight: FontWeight.w600)),
                    Text(value, style: context.pageTitleStyle(28)),
                    Text(l.progressLatestRecordedOn(dayMonth(latest.dayKey)), style: context.caption),
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
      TrendMetric.load => currentL10n.workoutSetLoadReps(formatLoad(p.value, unit), p.set.reps ?? 0),
      TrendMetric.reps => currentL10n.progressRepsValue(p.value.round()),
      TrendMetric.duration => secondsText(p.value.round()),
      TrendMetric.none => '',
    };

String axisValue(ExerciseTrend t, double v, LoadUnit unit) => switch (t.metric) {
      TrendMetric.load => formatLoadValue(v, unit),
      TrendMetric.duration => secondsText(v.round()),
      _ => formatNumber(v),
    };

String secondsText(int s) => s < 60 ? currentL10n.durationSeconds(s) : clockText(s);

String metricLabel(ExerciseTrend t, int? reps) => switch (t.metric) {
      TrendMetric.load => currentL10n.progressMetricLoad(reps ?? 0),
      TrendMetric.reps => currentL10n.progressMetricReps,
      TrendMetric.duration => currentL10n.progressMetricDuration,
      TrendMetric.none => currentL10n.progressMetricNone,
    };

/// The signed recorded change, shown neutrally: "+9 kg", "−2.5 kg", "No change". The signed number keeps its order
/// in Arabic.
String changeText(ExerciseTrend t, double delta, LoadUnit unit) {
  final l = currentL10n;
  if (delta == 0) return l.progressNoChange;
  final sign = delta > 0 ? '+' : '−';
  return switch (t.metric) {
    TrendMetric.load => ltr('$sign${formatLoad(delta.abs(), unit)}'),
    TrendMetric.reps => l.progressChangeReps(ltr('$sign${delta.abs().round()}'), delta.abs().round()),
    _ => ltr('$sign${secondsText(delta.abs().round())}'),
  };
}
