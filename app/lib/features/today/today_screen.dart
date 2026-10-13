import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../activity/activity_screens.dart';
import '../activity/run_tracking.dart';
import '../nutrition/food_form.dart';
import '../nutrition/nutrition_surface.dart';
import '../plans/plan_actions.dart';
import '../plans/plan_progress.dart';
import '../plans/plan_screens.dart';
import '../shell/home_shell.dart';
import '../workout/result_rules.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import 'daily.dart';

/// The three photographs of Today. They are bundled decoration made for this app: not the user's workout, not a
/// route, not a meal anyone logged. Screen readers never hear about them, and a missing file leaves a plain panel.
abstract final class _Photos {
  static const workout = 'assets/images/workout-hero.webp', run = 'assets/images/run-cover.webp', nutrition = 'assets/images/nutrition-cover.webp';
}

/// Today: the date, the one training action that matters now, running and today's food at a glance, and what was
/// recorded. The week and its calendar live in Train › Plan; the full food breakdown lives in Eat.
/// Every value comes from the signed-in owner's records. Nothing here is a sample.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(todayKeyProvider);
    final snapshot = ref.watch(dailySnapshotProvider);
    final reachable = ref.watch(connectionProvider);
    final localError = [ref.watch(plansProvider), ref.watch(workoutsProvider), ref.watch(contextRowProvider)].any((a) => a.hasError);
    final foodError = ref.watch(foodProvider(day)).hasError;
    final pad = EdgeInsets.symmetric(horizontal: context.inset);
    final finishedRuns = [for (final r in snapshot?.runs ?? const <Run>[]) if (!r.isOpen) r];

    // Side by side while both are short: nothing logged yet, normal text, a phone wide enough for real labels.
    // Logged food brings values and goal rails that need the full width, so the two cards stack instead.
    final sideBySide = !foodError && snapshot != null && snapshot.food.isEmpty && MediaQuery.textScalerOf(context).scale(10) <= 11.5 && MediaQuery.sizeOf(context).width >= 350;
    final run = _RunCard(finishedToday: finishedRuns, fill: sideBySide);
    final nutrition = _NutritionCard(day: day, snapshot: snapshot, failed: foodError, fill: sideBySide);

    return RefreshIndicator(
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.inset, 14, context.inset, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(longDate(day), style: context.sansStyle(15.5, color: context.c.secondary, weight: FontWeight.w500)),
              const Heading('Today'),
            ]),
          ),
          if (reachable == false) Padding(padding: pad.copyWith(bottom: 8), child: const _ConnectionStatus()),

          // --- Training. A nutrition problem never hides this section, and the reverse.
          Padding(
            padding: pad,
            child: localError
                ? const Panel(child: StatusLine(Icons.error_outline, 'Your training could not be read from this phone. Pull down to try again.', tone: Tone.error))
                : snapshot == null
                    ? const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading your training…'))
                    : _TrainingSection(snapshot),
          ),
          const SizedBox(height: 12),

          // --- Running and nutrition: the same card, the same button, each with its own state.
          Padding(
            padding: pad,
            child: sideBySide
                ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: run), const SizedBox(width: 10), Expanded(child: nutrition)]))
                : Column(children: [run, const SizedBox(height: 12), nutrition]),
          ),

          // --- What was actually recorded today. Absent when there is nothing to show.
          if (snapshot != null && (snapshot.finishedToday.isNotEmpty || finishedRuns.length > 1)) Padding(padding: pad.copyWith(top: 24), child: _ActivitySection(snapshot, finishedRuns)),
        ],
      ),
    );
  }
}

/// The account could not be reached on the last attempt: one quiet line, with the explanation a tap away.
/// Changes that need a decision (conflicts, refusals) keep their own notice above the navigation bar.
class _ConnectionStatus extends ConsumerStatefulWidget {
  const _ConnectionStatus();
  @override
  ConsumerState<_ConnectionStatus> createState() => _ConnectionStatusState();
}

class _ConnectionStatusState extends ConsumerState<_ConnectionStatus> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        button: true, expanded: _open,
        child: InkWell(
          key: const Key('today-connection'),
          borderRadius: BorderRadius.circular(Radii.tile),
          onTap: () => setState(() => _open = !_open),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.minimum),
            child: Row(children: [
              Expanded(
                child: StatusLine(Icons.cloud_off, '$cantSyncLabel${pending == 0 ? '' : ' · ${waitingToSync(pending)}'}', tone: Tone.warning),
              ),
              Icon(_open ? Icons.expand_less : Icons.expand_more, size: 22, color: c.secondary),
            ]),
          ),
        ),
      ),
      if (_open) ...[
        Text(
            '$cantSyncDetail You are seeing what is saved on this phone. ${pending == 0 ? 'Nothing is waiting to sync.' : 'Your changes are kept here and sync by themselves once the account answers.'}',
            style: context.caption),
        Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('today-connection-retry'), onPressed: () => refreshFromAccount(ref), child: const Text('Try again'))),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------------- the shared card

/// A decorative photograph across the top of a card. Decoded once at the width of the phone, whichever card
/// it is in, so scrolling, a layout change or a new theme never decodes it again.
class _Photo extends StatelessWidget {
  const _Photo(this.asset, {required this.alignment});
  final String asset;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round().clamp(320, 1536);
    return ExcludeSemantics(
      child: Image.asset(asset, fit: BoxFit.cover, alignment: alignment, cacheWidth: width, errorBuilder: (context, _, _) => ColoredBox(color: context.c.sunken)),
    );
  }
}

/// The card all three sections of Today share: one radius, one border, an optional photograph, then the content
/// on the theme's own surface.
class _Card extends StatelessWidget {
  const _Card({this.header, required this.child, this.fill = false});
  final Widget? header;
  final Widget child;

  /// The card has been given a height (it sits beside another one): its content fills it, so buttons line up.
  final bool fill;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(Radii.panel), border: Border.all(color: context.c.divider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min, children: [
          ?header,
          if (fill) Expanded(child: Padding(padding: const EdgeInsets.all(14), child: child)) else Padding(padding: const EdgeInsets.all(14), child: child),
        ]),
      );
}

/// The heading of a companion card: an icon in the accent tint, the title, and one line of real state.
class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title, required this.state, this.stateIcon, this.active = false});
  final IconData icon;
  final String title, state;
  final IconData? stateIcon;

  /// Something is going on right now: the state is said in the accent, with its icon.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = active ? c.accent : c.secondary;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ExcludeSemantics(
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 21, color: c.accent),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(title, style: context.titleStyle(18))),
          const SizedBox(height: 1),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (stateIcon != null) Padding(padding: const EdgeInsets.only(right: 4, top: 2), child: Icon(stateIcon, size: 15, color: color)),
            Flexible(child: Text(state, style: context.sansStyle(13.5, color: color, weight: active ? FontWeight.w600 : FontWeight.w400))),
          ]),
        ]),
      ),
    ]);
  }
}

/// The one button of a companion card. Outlined, so the workout's filled button stays the main action of the
/// page; a little narrower inside than the app's default so "Continue run" stays on one line in a half-width card.
class _CardButton extends StatelessWidget {
  const _CardButton(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          child: Text(label, textAlign: TextAlign.center),
        ),
      );
}

// ---------------------------------------------------------------------------- training

/// "4 × 6–8", "3 × 30 s", "4 sets", "8 reps": what the plan prescribes for a movement. Null when it prescribes
/// nothing. This is a target, never something that was done.
String? _prescribed({int? sets, int? repsMin, int? repsMax, int? seconds}) {
  final each = seconds != null
      ? '$seconds s'
      : repsMin != null && repsMax != null && repsMin != repsMax
          ? '$repsMin–$repsMax'
          : (repsMin ?? repsMax)?.toString();
  if (sets == null) return each == null ? null : seconds != null ? each : '$each reps';
  return each == null ? '$sets ${sets == 1 ? 'set' : 'sets'}' : '$sets × $each';
}

/// One movement of the workout preview: its name, what is prescribed, and what has actually been recorded.
typedef _Movement = ({String name, String? target, String? recorded});

class _TrainingSection extends ConsumerWidget {
  const _TrainingSection(this.snapshot);
  final DailySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = snapshot.training;
    String nextText(Occasion? next) => next == null ? 'No further workout is scheduled in this block.' : 'Next: ${next.title} on ${longDate(next.scheduledDate)}.';
    void openPlan() => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan);
    List<_Movement> planned(List<Prescription> prescription) => [
          for (final e in prescription) (name: e.name, target: _prescribed(sets: e.targetSets, repsMin: e.targetRepsMin, repsMax: e.targetRepsMax, seconds: e.targetDurationSeconds), recorded: null),
        ];

    final (Widget card, bool offerManual) = switch (a) {
      ResumeWorkout(:final workout) => () {
          final trusted = ref.watch(trustedSetsProvider);
          final sets = SetProgress.of(workout, trusted);
          final n = workout.exercises.length;
          // A planned workout opens its plan entry; a manual one opens its own record of what was done so far.
          final plan = ref.watch(planListProvider).where((p) => p.id == workout.planId).firstOrNull;
          final occasion = plan?.occasions.where((o) => o.id == workout.occasionId).firstOrNull;
          return (
            _WorkoutCard(
              state: 'In progress', stateIcon: Icons.timelapse, title: workout.title,
              summary: n == 0 ? 'No exercise added yet' : '$n ${n == 1 ? 'exercise' : 'exercises'}${sets.planned == null ? '' : ' · ${sets.planned} sets'}',
              movements: [
                for (final e in workout.exercises)
                  () {
                    final done = trusted.where((s) => s.workoutId == workout.id && s.exerciseId == e.id).length;
                    final target = e.isPrescribed ? e.targetSets : null;
                    return (
                      name: e.name,
                      target: e.isPrescribed ? _prescribed(sets: e.targetSets, repsMin: e.targetRepsMin, repsMax: e.targetRepsMax, seconds: e.targetDurationSeconds) : null,
                      // Counts only. Nothing here calls a movement finished or current.
                      // With a single movement and no target the total under the list already says it.
                      recorded: done == 0 || (n == 1 && target == null) ? null : target == null ? '$done ${done == 1 ? 'set' : 'sets'} recorded' : '$done of $target sets recorded',
                    );
                  }(),
              ],
              progress: sets,
              onDetails: occasion != null ? () => showOccasionSheet(context, ref, plan!, occasion) : () => push(context, WorkoutDetailScreen(workoutId: workout.id)),
              action: PrimaryButton('Resume workout', key: const Key('today-resume'), icon: Icons.play_arrow_rounded, onPressed: () => resumeWorkout(context, ref, workout)),
            ),
            false
          );
        }(),
      WorkoutDue(:final plan, :final occasion) => (
          _WorkoutCard(
            state: 'Due today', stateIcon: Icons.today, title: occasion.title,
            // The minutes are the session length chosen when the plan was set up. They are not worked out from
            // the exercises, so they are labelled as planned time and never as an estimate.
            summary: 'Week ${occasion.weekNumber} · ${prescriptionSummary(occasion.prescription)}${plan.setup?['minutesPerSession'] == null ? '' : ' · ${plan.setup!['minutesPerSession']} min planned'}',
            movements: planned(occasion.prescription),
            onDetails: () => showOccasionSheet(context, ref, plan, occasion),
            action: PrimaryButton('Start workout', key: const Key('today-start'), icon: Icons.play_arrow_rounded, onPressed: () => startPlannedWorkout(context, ref, plan, occasion)),
          ),
          false
        ),
      DoneToday(:final plan, :final occasion, :final outcome, :final next) => (
          _WorkoutCard(
            state: 'Done for today', stateIcon: Icons.check_circle, title: occasion.title,
            body: '${outcome == WorkoutResultRules.full ? 'Finished: all planned sets recorded.' : 'Finished partially: some planned work was not recorded.'} ${nextText(next)}',
            onDetails: () => showOccasionSheet(context, ref, plan, occasion),
            action: SecondaryButton('View plan', onPressed: openPlan),
          ),
          false
        ),
      // No photograph from here on: a picture of training must not sit above "rest today" or "no plan yet".
      PlanPausedAction(:final plan) => (
          _PlainCard(state: 'Plan paused', stateIcon: Icons.pause_circle_outline, title: plan.title, body: 'No workouts are expected while the plan is paused, and nothing counts as missed.',
              action: PrimaryButton('Resume plan', onPressed: () => push(context, ResumeReviewScreen(planId: plan.id)))),
          true
        ),
      StartsLater(:final plan, :final first) => (
          _PlainCard(state: 'Starts ${shortDate(plan.startDate)}', stateIcon: Icons.event, title: first.title, body: 'Your first workout is on ${longDate(first.scheduledDate)}. Nothing is due before then.',
              action: SecondaryButton('View plan', onPressed: openPlan)),
          true
        ),
      BlockReviewDue(:final plan) => (
          _PlainCard(state: 'Block ready to review', stateIcon: Icons.flag_outlined, title: plan.title,
              body: 'This block has reached its end or has nothing left to do. Review what was actually recorded and choose what comes next.',
              action: PrimaryButton('Review this block', key: const Key('today-block-review'), onPressed: () => push(context, BlockReviewScreen(planId: plan.id)))),
          true
        ),
      RecoveryDay(:final next, :final missed) => (
          _PlainCard(state: 'Recovery day', stateIcon: Icons.spa_outlined, title: 'Rest today',
              body: '${nextText(next)}${missed.isEmpty ? '' : ' ${missed.length} earlier workout${missed.length == 1 ? ' is' : 's are'} unresolved; move or skip ${missed.length == 1 ? 'it' : 'them'} when you choose.'}',
              action: missed.isEmpty ? SecondaryButton('View plan', onPressed: openPlan) : SecondaryButton('Resolve missed training', key: const Key('today-missed'), onPressed: openPlan)),
          true
        ),
      ReviewDraft(:final draft) => (
          _PlainCard(state: 'Your plan is ready to review', stateIcon: Icons.fact_check_outlined, title: draft.title, body: 'This draft has not started. Nothing is scheduled until you start it.',
              action: PrimaryButton('Review your plan', key: const Key('today-review-draft'), onPressed: () => push(context, PlanReviewScreen(planId: draft.id)))),
          true
        ),
      CreatePlan() => (
          _PlainCard(state: 'Your training', stateIcon: Icons.fitness_center, title: 'No plan yet', body: 'Answer a few questions and review a plan before you commit, or just train manually today.',
              action: PrimaryButton('Create my plan', key: const Key('today-create-plan'), onPressed: () => push(context, const PlanSetupScreen()))),
          true
        ),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      card,
      if (offerManual) TextButton(key: const Key('today-manual'), onPressed: () => startManualWorkout(context, ref), child: const Text('Start a manual workout')),
      // Workouts saved for later stay recoverable without taking over the day.
      for (final w in snapshot.parked)
        ListRow(icon: Icons.bookmark_outline, title: w.title, subtitle: 'Saved for later · started ${shortDate(w.dayKey)}', divider: false, onTap: () => resumeWorkout(context, ref, w)),
    ]);
  }
}

/// A day with a workout: the photograph carries its name and state, the card below says what is in it and how
/// far it has got, and one button starts or resumes it.
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.state, required this.stateIcon, required this.title, this.summary, this.movements = const [], this.body, this.progress, this.onDetails, required this.action});
  final String state, title;
  final IconData stateIcon;
  final String? summary, body;
  final List<_Movement> movements;
  final SetProgress? progress;
  final VoidCallback? onDetails;
  final Widget action;

  /// How many movements the card lists itself; the rest are behind "See all".
  static const shown = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = progress;
    // With large text the name gets the whole width and the photograph is fully covered by the scrim.
    final wide = MediaQuery.textScalerOf(context).scale(10) > 13;
    final header = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 124),
      child: Stack(children: [
        // The dumbbells sit low and right in the picture; the words sit left.
        const Positioned.fill(child: _Photo(_Photos.workout, alignment: Alignment(0.6, 0.72))),
        // A dark floor under the words, at least 82% black wherever they can be; the photograph shows beside it.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: wide
                  ? const LinearGradient(colors: [Color(0xD9000000), Color(0xD9000000)])
                  : const LinearGradient(stops: [0, 0.62, 1], colors: [Color(0xE6000000), Color(0xD1000000), Color(0x14000000)]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: FractionallySizedBox(
            widthFactor: wide ? 1 : 0.62, alignment: Alignment.centerLeft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('WORKOUT', style: context.sansStyle(12.5, color: const Color(0xE6FFFFFF), weight: FontWeight.w600).copyWith(letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Semantics(header: true, child: Text(title, style: context.titleStyle(24, color: Colors.white))),
              const SizedBox(height: 8),
              // The state is a filled accent label: a word and an icon, readable on any photograph.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(stateIcon, size: 15, color: c.onAccent),
                  const SizedBox(width: 6),
                  Flexible(child: Text(state, style: context.sansStyle(13, color: c.onAccent, weight: FontWeight.w700))),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
    final more = movements.length - shown;
    return _Card(
      header: header,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (summary != null) Text(summary!, style: context.sansStyle(14.5, color: c.secondary)),
        if (body != null) Text(body!, style: context.sansStyle(15, color: c.secondary)),
        // Plain rows: there is no page for a single movement, so they do not pretend to be buttons.
        for (final (i, m) in movements.take(shown).indexed) ...[
          if (i == 0) const SizedBox(height: 6) else const Rule(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: MergeSemantics(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, style: context.sansStyle(16, weight: FontWeight.w500)),
                    if (wide && m.target != null) Text(m.target!, semanticsLabel: 'planned ${m.target}', style: context.sansStyle(15, color: c.secondary)),
                    if (m.recorded != null) Text(m.recorded!, style: context.caption),
                  ]),
                ),
                if (!wide && m.target != null) Padding(padding: const EdgeInsets.only(left: 12, top: 1), child: Text(m.target!, semanticsLabel: 'planned ${m.target}', style: context.sansStyle(15, color: c.secondary))),
              ]),
            ),
          ),
        ],
        if (onDetails != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('today-details'),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              onPressed: onDetails,
              child: Text(more > 0 ? 'See all ${movements.length} exercises' : 'Workout details'),
            ),
          ),
        if (p != null && (p.planned != null || p.recorded > 0)) ...[
          const SizedBox(height: 4),
          if (p.planned == null)
            Text('${p.recorded} ${p.recorded == 1 ? 'set' : 'sets'} recorded', style: context.sansStyle(15, weight: FontWeight.w600))
          else ...[
            Row(children: [
              Expanded(child: Text('${p.counted} of ${p.planned} sets recorded', style: context.sansStyle(15, weight: FontWeight.w600))),
              Text('${(p.fraction * 100).round()}%', style: context.sansStyle(14.5, color: c.secondary, weight: FontWeight.w600)),
            ]),
            const SizedBox(height: 7),
            ProgressRail(p.fraction, label: 'Planned sets recorded', height: 7),
          ],
        ],
        const SizedBox(height: 14),
        action,
      ]),
    );
  }
}

/// Rest days, paused plans, drafts and the empty start: the same card without a photograph.
class _PlainCard extends StatelessWidget {
  const _PlainCard({required this.state, required this.stateIcon, required this.title, required this.body, required this.action});
  final String state, title, body;
  final IconData stateIcon;
  final Widget action;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusPill(state, icon: stateIcon, tone: Tone.accent),
          const SizedBox(height: 10),
          Semantics(header: true, child: Text(title, style: context.titleStyle(24))),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(body, style: context.sansStyle(15, color: context.c.secondary))),
          const SizedBox(height: 14),
          action,
        ]),
      );
}

// ---------------------------------------------------------------------------- running

/// Today's one way into running, on every kind of day. An open run is read from the saved records, whatever day
/// it began, so it is continued (never started twice) also after the app was closed. The photograph is not a
/// map and says nothing about tracking: distance is measured only while the run's own screen is open.
class _RunCard extends ConsumerWidget {
  const _RunCard({required this.finishedToday, required this.fill});
  final List<Run> finishedToday;
  final bool fill;

  static String _km(double meters) => '${(meters / 1000).toStringAsFixed(2)} km';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = [for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) if (r.value.isOpen) r.value].firstOrNull;
    final String state;
    if (open != null) {
      // Only a distance that was really measured so far; the clock is on the run's own screen.
      final runtime = (ref.watch(runtimesProvider).value ?? const <Stored<Json>>[]).where((r) => r.rec.id == open.id).firstOrNull;
      final track = RunTrack(runtime?.value['track'] as Json? ?? const {});
      state = track.hasDistance ? 'In progress · ${_km(track.distanceMeters)} so far' : 'In progress';
    } else if (finishedToday.isNotEmpty) {
      final last = finishedToday.last;
      state = 'Today: ${durationText(last.activeDurationSeconds ?? 0)}${last.distanceMeters == null ? '' : ' · ${_km(last.distanceMeters!)}'}';
    } else {
      state = 'No run today';
    }
    final title = _CardTitle(icon: Icons.directions_run, title: 'Run', state: state, stateIcon: open == null ? null : Icons.timelapse, active: open != null);
    final label = open == null ? 'Start run' : 'Continue run';
    void go() => startRunFlow(context, ref);
    // On its own row the card is short: the title and the button share a line unless the text is large.
    final inline = !fill && MediaQuery.textScalerOf(context).scale(10) <= 13;
    return _Card(
      fill: fill,
      header: const SizedBox(height: 92, child: _Photo(_Photos.run, alignment: Alignment(0.55, 0.25))),
      child: inline
          ? Row(children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              OutlinedButton(key: const Key('today-run'), onPressed: go, child: Text(label)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                title,
                // The quiet way to what was run before; starting or continuing stays the card's one button.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)), onPressed: () => push(context, const RunHistoryScreen()), child: const Text('Run history')),
                ),
              ]),
              _CardButton(label, key: const Key('today-run'), onPressed: go),
            ]),
    );
  }
}

// ---------------------------------------------------------------------------- nutrition

/// Today's food at a glance, from the same entries and coverage Eat shows in full. The bowl in the photograph is
/// decoration: it is not an entry, and it is there on a day with nothing logged too.
class _NutritionCard extends ConsumerWidget {
  const _NutritionCard({required this.day, required this.snapshot, required this.failed, required this.fill});
  final String day;
  final DailySnapshot? snapshot;
  final bool failed, fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot;
    final profile = ref.watch(profileProvider).value;
    final foods = s?.food.length ?? 0;
    final goals = NutritionSummary.goalsText(profile?.calorieGoal, profile?.proteinGoal);
    void openEat() => ref.read(shellProvider.notifier).switchTab(2);
    return _Card(
      fill: fill,
      header: const SizedBox(height: 92, child: _Photo(_Photos.nutrition, alignment: Alignment(0.45, 0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
       Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _CardTitle(
          icon: Icons.restaurant, title: 'Nutrition',
          state: failed ? 'Could not be read' : s == null ? 'Loading…' : foods == 0 ? 'No food logged today' : '$foods ${foods == 1 ? 'food' : 'foods'} logged',
        ),
        if (failed)
          const Padding(padding: EdgeInsets.only(top: 10), child: StatusLine(Icons.error_outline, 'Today\'s food could not be read from this phone.', tone: Tone.error))
        else if (s != null && foods == 0 && goals != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Your daily goal: $goals', style: context.caption))
        else if (s != null && foods > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: NutritionSummary(coverage: s.coverage, calorieGoal: profile?.calorieGoal, proteinGoal: profile?.proteinGoal, onDetails: openEat),
          ),
        // A quiet way to the full journal; logging stays the card's one button.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(key: const Key('today-open-eat'), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)), onPressed: openEat, child: const Text('Food journal')),
        ),
       ]),
        _CardButton('Log food', key: const Key('log-food'), onPressed: () => openFoodForm(context, dayKey: day)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------- recorded today

/// What was recorded today, in its own words: a manual workout is "Recorded", never a completed plan day.
/// A single finished run is already said on the Run card, so runs are listed here only when there are several.
class _ActivitySection extends ConsumerWidget {
  const _ActivitySection(this.snapshot, this.finishedRuns);
  final DailySnapshot snapshot;
  final List<Run> finishedRuns;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Recorded today'),
        for (final w in snapshot.finishedToday)
          ListRow(
            title: w.title,
            subtitle: '${w.isManual ? 'Manual workout' : 'Planned workout'} · ${WorkoutResultRules.label(w.outcome)}${w.performedSets > 0 ? ' · ${w.performedSets} set${w.performedSets == 1 ? '' : 's'}' : ''}',
            onTap: () => push(context, WorkoutDetailScreen(workoutId: w.id)),
          ),
        if (finishedRuns.length > 1)
          for (final r in finishedRuns)
            ListRow(
              icon: Icons.directions_run, title: 'Run',
              subtitle: '${durationText(r.activeDurationSeconds ?? 0)}${r.distanceMeters == null ? '' : ' · ${(r.distanceMeters! / 1000).toStringAsFixed(2)} km'}',
            ),
      ]);
}
