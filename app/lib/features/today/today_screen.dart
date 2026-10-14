import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/appearance.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../activity/activity_screens.dart';
import '../activity/run_tracking.dart';
import '../nutrition/food_form.dart';
import '../nutrition/nutrition_surface.dart';
import '../plans/builder/plan_builder_screen.dart';
import '../plans/plan_actions.dart';
import '../plans/plan_progress.dart';
import '../plans/plan_projection.dart' show rotationOf;
import '../plans/plan_screens.dart';
import '../shell/home_shell.dart';
import '../weather/weather.dart';
import '../workout/result_rules.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import '../workout/workout_runtime.dart';
import 'daily.dart';

/// The three photographs of Today. They are bundled decoration made for this app: not the user's workout, not a
/// route, not a meal anyone logged. Screen readers never hear about them, and a missing file leaves a plain panel.
abstract final class _Photos {
  static const workout = 'assets/images/workout-hero.webp', run = 'assets/images/run-cover.webp', nutrition = 'assets/images/nutrition-cover.webp';
}

/// Today: the date and a greeting, then three modules of one family (workout, run, nutrition), each with its real
/// state and one action. The week and its calendar live in Train › Plan; the exercise list lives in the workout's
/// sheet; the full food breakdown lives in Eat. Every value comes from the signed-in owner's records.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(todayKeyProvider);
    final snapshot = ref.watch(dailySnapshotProvider);
    final reachable = ref.watch(connectionProvider);
    final localError = [ref.watch(plansProvider), ref.watch(workoutsProvider), ref.watch(contextRowProvider)].any((a) => a.hasError);
    final foodError = ref.watch(foodProvider(day)).hasError;
    final finishedRuns = [for (final r in snapshot?.runs ?? const <Run>[]) if (!r.isOpen) r];

    // The scene fills the whole tab, behind the status bar and the floating bar, and stays put while the page
    // scrolls over it. It is const here, so nothing Today watches rebuilds it; only its own sky layer repaints.
    return Stack(children: [
      const Positioned.fill(child: RepaintBoundary(child: TodayBackdrop())),
      RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () => refreshFromAccount(ref),
        child: ListView(
          padding: EdgeInsets.only(bottom: 28 + MediaQuery.paddingOf(context).bottom),
          children: [
            _Header(day: day),
            Padding(
              // Edge to edge with the floating bar below it.
              padding: const EdgeInsets.symmetric(horizontal: GoNavigationBar.margin),
              child: _Surface(children: [
                if (reachable == false) const Padding(padding: EdgeInsets.only(top: 12), child: _ConnectionStatus()),
                // The day's rhythm: workout, run and food, one thread, on the surface and never over the photograph.
                RhythmTimeline(sections: [
                  // A nutrition problem never hides training, and the reverse.
                  (
                    Icons.fitness_center,
                    localError
                        ? const StatusLine(Icons.error_outline, 'Your training could not be read from this phone. Pull down to try again.', tone: Tone.error)
                        : snapshot == null
                            ? const StatusLine(Icons.hourglass_empty, 'Loading your training…')
                            : _TrainingSection(snapshot),
                  ),
                  (Icons.directions_run, _RunCard(today: day, finishedToday: finishedRuns)),
                  (Icons.restaurant, _NutritionCard(day: day, snapshot: snapshot, failed: foodError)),
                ]),

                // --- What was actually recorded today. Absent when there is nothing to show.
                if (snapshot != null && (snapshot.recordedToday.isNotEmpty || finishedRuns.length > 1)) ...[
                  Divider(color: context.c.divider, height: 1),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: _ActivitySection(snapshot, finishedRuns)),
                ],
              ]),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// The one surface Today's sections sit on over the scene: [GoColors.surface] at [GoColors.panelOpacity] (soft white
/// in Light, charcoal in Dark, whatever the sky) over a soft blur of the scene, with a thin edge. The scene stays
/// visible around it and faintly through it; every line on it reads as on a card. One blur for the whole column,
/// clipped to the surface.
class _Surface extends StatelessWidget {
  const _Surface({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = BorderRadius.circular(Radii.panel);
    return ClipRRect(
      key: const Key('today-surface'),
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(color: c.surface.withValues(alpha: GoColors.panelOpacity), borderRadius: radius, border: Border.all(color: c.divider.withValues(alpha: 0.7))),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width < 350 ? 8 : 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ),
    );
  }
}

/// The top of Today: the date, the title and the greeting over the scene (the weather, the dusk scene or the plain
/// page, as chosen in Appearance) that fills the tab behind it. Only the scene reads the weather; it repaints alone,
/// so a new scene never rebuilds, moves or resets anything here. The header's own scrim keeps its lines readable over
/// every scene.
class _Header extends ConsumerWidget {
  const _Header({required this.day});
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(todaySceneProvider);
    final appearance = ref.watch(appearanceProvider);
    // The header's text and scrim follow the sky, not the app's mode: light lines over a night, rain or storm sky
    // and dark lines over a daylight one, as in Apple Weather. Same accent; increased contrast respected.
    // Scenic and Plain are not weather: they keep the app's own mode.
    final sky = !scene.isWeather ? Theme.of(context).brightness : scene.dark ? Brightness.dark : Brightness.light;
    return Theme(
      key: const Key('today-header'),
      data: goTheme(appearance.accent, sky, highContrast: MediaQuery.highContrastOf(context)),
      child: Builder(
        builder: (context) => Padding(
          // The scene runs to the top edge, behind the status bar; the lines start below it.
          padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topInset(context), context.inset, 8),
          child: TabHeader(
            title: 'Today', overline: longDate(day), onBackdrop: true,
            below: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Greeting(), _SkyLine()]),
          ),
        ),
      ),
    );
  }
}

/// One quiet line under the greeting saying what the scene is: the weather it shows ("Partly cloudy"), or, when
/// Weather is chosen but there is no usable answer, that this is the scenic view and why. Nothing for Scenic or
/// Plain. A tap opens the Today background setting, where the details are.
class _SkyLine extends ConsumerWidget {
  const _SkyLine();

  static String _issue(WeatherIssue i) => switch (i) {
        WeatherIssue.needsPermission => 'Location not allowed yet',
        WeatherIssue.denied || WeatherIssue.deniedForever => 'Location not allowed',
        WeatherIssue.servicesOff => 'Location is off',
        WeatherIssue.timeout => 'No location in time',
        WeatherIssue.offline => 'Weather could not be reached',
        WeatherIssue.unavailable => 'Weather unavailable',
        WeatherIssue.noCity => 'Choose a city',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(todaySceneProvider);
    final issue = ref.watch(weatherProvider.select((w) => w.issue));
    final String text;
    final IconData icon;
    if (scene.isWeather) {
      text = scene.label!;
      icon = Icons.cloud_outlined;
    } else if (scene.fallback != null) {
      text = 'Scenic view · ${issue == null ? scene.fallback!.words : _issue(issue)}';
      icon = Icons.landscape_outlined;
    } else {
      return const SizedBox.shrink();
    }
    return Semantics(
      button: true, hint: 'Opens the Today background setting',
      child: InkWell(
        key: const Key('today-sky-line'),
        borderRadius: BorderRadius.circular(Radii.field),
        onTap: () => push(context, const TodayBackgroundScreen()),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.minimum),
          child: Row(children: [
            const SizedBox(width: 10),
            ExcludeSemantics(child: Icon(icon, size: 18, color: context.c.text)),
            const SizedBox(width: 24),
            Flexible(child: Text(text, style: context.sansStyle(15, color: context.c.text, weight: FontWeight.w500))),
          ]),
        ),
      ),
    );
  }
}

/// "Good evening, Alex": the phone's local time and the first word of the name on the profile. Without a name it
/// is just the greeting. It is worked out when Today is built, which is often enough for a part of the day.
class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = ref.watch(clockProvider).utcNow().toLocal().hour;
    final (words, icon) = hour >= 5 && hour < 12
        ? ('Good morning', Icons.wb_sunny_outlined)
        : hour >= 12 && hour < 18
            ? ('Good afternoon', Icons.wb_sunny_outlined)
            : ('Good evening', Icons.nightlight_outlined);
    final name = (ref.watch(profileProvider).value?.j['displayName'] as String? ?? '').trim().split(RegExp(r'\s+')).first;
    return Row(children: [
      IconTile(icon, size: 40, circle: true),
      const SizedBox(width: 14),
      Expanded(child: Text(name.isEmpty ? words : '$words, $name', key: const Key('today-greeting'), style: context.sansStyle(18, weight: FontWeight.w500))),
    ]);
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

// ---------------------------------------------------------------------------- the shared module

/// A small decorative crop at the trailing side of a module. It is decoded for the size it is drawn at, not for
/// the screen: the bundled photographs are 3:2, so covering the crop needs its width or 1.5 × its height,
/// whichever is larger, in device pixels (rounded up to a step of 64 so a few pixels of height change nothing).
class _Photo extends StatelessWidget {
  const _Photo(this.asset, {super.key, required this.alignment});
  final String asset;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: LayoutBuilder(builder: (context, box) {
          final pixels = math.max(box.maxWidth, box.maxHeight * 1.5) * MediaQuery.devicePixelRatioOf(context);
          return Image.asset(asset, width: box.maxWidth, height: box.maxHeight, fit: BoxFit.cover, alignment: alignment,
              cacheWidth: ((pixels / 64).ceil() * 64).clamp(64, 1536), errorBuilder: (context, _, _) => ColoredBox(color: context.c.sunken));
        }),
      );
}

/// A state in an icon and a word ("In progress", "Due today"), beside the module's label. The tone only adds to
/// the word: accent for what is live or due, the success colour for what is finished, quiet otherwise.
typedef _Status = (String label, IconData icon, Tone tone);

/// One section of Today's rhythm. All three are built from this: the label and its state, the content, a small
/// photograph at the trailing side when one fits and does not mislead, and one row of actions (the main button
/// and a quiet link). The round icon node and the separators belong to the [RhythmTimeline] around it. Heights
/// follow the content: the photograph stands beside the label too (unless [labelBeside] is false, for a label and
/// state too wide to share the line), so a short module is no taller than its picture. With large text the
/// photograph gives its room to the words, and the two actions stack.
class _Module extends StatelessWidget {
  const _Module({super.key, required this.label, this.status, this.labelBeside = true, this.head = const [], this.body = const [], this.footer, this.photo, this.photoAlignment = Alignment.center, required this.action, this.quiet});
  final String label;
  final _Status? status;
  final bool labelBeside;

  /// Under the label at the full width; [body] follows, left of the photograph.
  final List<Widget> head, body;

  /// A line under all of that, at the full width of the module (the note that some food values are missing).
  final Widget? footer;
  final String? photo;
  final Alignment photoAlignment;
  final Widget action;
  final Widget? quiet;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final large = scale > 1.3, narrow = MediaQuery.sizeOf(context).width < 350;
    final photoWidth = photo == null || large ? 0.0 : narrow ? 72.0 : 84.0;
    final s = status;
    // The label and its state, a word with an icon (never a colour alone).
    final labelRow = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Semantics(header: true, child: Overline(label)),
          if (s != null) StatusPill(s.$1, icon: s.$2, tone: s.$3),
        ]),
      ),
    );
    final beside = labelBeside && head.isEmpty;
    final top = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [if (beside) labelRow, ...body]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (!beside) labelRow,
      ...head,
      if (photoWidth == 0)
        top
      else
        Stack(children: [
          Padding(padding: EdgeInsets.only(right: photoWidth + 14), child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 64), child: top)),
          Positioned(
            top: beside ? 2 : 4, bottom: 0, right: 0, width: photoWidth,
            child: ClipRRect(borderRadius: BorderRadius.circular(Radii.tile), child: _Photo(photo!, key: Key('today-photo-$label'.toLowerCase()), alignment: photoAlignment)),
          ),
        ]),
      ?footer,
      const SizedBox(height: 10),
      if (quiet == null)
        action
      else if (large || narrow)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [action, Align(alignment: Alignment.centerLeft, child: quiet)])
      else
        Row(children: [Expanded(child: action), const SizedBox(width: 8), quiet!]),
    ]);
  }
}

// ---------------------------------------------------------------------------- training

class _TrainingSection extends ConsumerWidget {
  const _TrainingSection(this.snapshot);
  final DailySnapshot snapshot;

  static String _count(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = snapshot.training;
    final c = context.c;
    final today = snapshot.dayKey;
    // "Next: Pull · Wednesday" within the coming week, with the full date further out.
    String nextText(Occasion? next) => next == null
        ? 'No further workout is scheduled in this block.'
        : 'Next: ${next.title} · ${daysBetween(today, next.scheduledDate) < 7 ? weekdayName(weekdayOf(next.scheduledDate)) : longDate(next.scheduledDate)}.';
    void openPlan() => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan);
    Widget title(String text) => Padding(padding: const EdgeInsets.only(top: 2), child: Text(text, style: context.titleStyle(23)));
    Widget line(String text, {double top = 4}) => Padding(padding: EdgeInsets.only(top: top), child: Text(text, style: context.sansStyle(14.5, color: c.secondary)));
    Widget details(VoidCallback onPressed) => TextButton(key: const Key('today-details'), onPressed: onPressed, child: const Text('Details', semanticsLabel: 'Workout details'));

    /// A day with a workout to do: the only variant with the training photograph. The label and its state need
    /// the full line. [titleBeside] puts the name beside the photograph too, with [footer] at the full width below.
    Widget workout({required _Status status, required String name, bool titleBeside = false, List<Widget> head = const [], required List<Widget> body, Widget? footer, required Widget action, required VoidCallback onDetails}) => _Module(
        key: const Key('today-module-workout'), label: 'Workout', status: status, labelBeside: false,
        head: [if (!titleBeside) title(name), ...head], body: [if (titleBeside) title(name), ...body], footer: footer,
        // The dumbbells sit low and right in the picture.
        photo: _Photos.workout, photoAlignment: const Alignment(0.75, 0.8), action: action, quiet: details(onDetails));

    /// Rest, paused, finished, not started, nothing planned: the same module in words only. A picture of training
    /// must not sit beside "Rest today" or "No plan yet".
    Widget plain({_Status? status, required String name, required String text, required Widget action, VoidCallback? onDetails}) => _Module(
        key: const Key('today-module-workout'), label: 'Workout', status: status, head: [title(name)], body: [line(text, top: 6)],
        action: action, quiet: onDetails == null ? null : details(onDetails));

    final (Widget card, bool offerManual) = switch (a) {
      ResumeWorkout(workout: final w) => () {
          final sets = SetProgress.of(w, ref.watch(trustedSetsProvider));
          final n = w.exercises.length;
          // A planned workout opens its plan entry; a manual one opens its own record of what was done so far.
          final plan = ref.watch(planListProvider).where((p) => p.id == w.planId).firstOrNull;
          // Through the projection, so a rotation's step started on this phone still opens its plan entry.
          final occasion = plan == null ? null : planOccasions(plan, today, ref.watch(workoutListProvider)).where((o) => o.id == w.occasionId).firstOrNull;
          return (
            workout(
              status: ('In progress', Icons.timelapse, Tone.accent), name: w.title,
              // With a planned total the summary takes the full width and the ring sits beside the photograph.
              head: [if (sets.planned != null) line('${_count(n, 'exercise')} · ${sets.planned} planned sets')],
              body: [
                if (sets.planned == null) line(n == 0 ? 'No exercise added yet' : _count(n, 'exercise')),
                // Recorded is a count of sets, never a claim that a movement or the workout is complete.
                if (sets.planned != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      ProgressRing(
                        value: sets.fraction, size: MediaQuery.textScalerOf(context).scale(10) > 13 ? 104 : 76, stroke: 7, label: '${sets.counted} of ${sets.planned} planned sets recorded',
                        center: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${sets.counted}', style: context.titleStyle(22)),
                          Text('of ${sets.planned} sets', style: context.sansStyle(12.5, color: c.secondary)),
                        ]),
                      ),
                      const SizedBox(width: 14),
                      // Said by the ring already; drawn for the eye.
                      Flexible(
                        child: ExcludeSemantics(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${(sets.fraction * 100).round()}%', style: context.numStyle(21, color: c.accent, weight: FontWeight.w700)),
                            Text('recorded', style: context.sansStyle(14, color: c.secondary)),
                          ]),
                        ),
                      ),
                    ]),
                  )
                else if (sets.recorded > 0)
                  // No planned total exists for a manual workout, so there is a count and no percentage.
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('${_count(sets.recorded, 'set')} recorded', style: context.numStyle(16))),
              ],
              onDetails: occasion != null ? () => showOccasionSheet(context, ref, plan!, occasion) : () => push(context, WorkoutDetailScreen(workoutId: w.id)),
              action: PrimaryButton('Resume workout', key: const Key('today-resume'), icon: Icons.play_arrow_rounded, onPressed: () => resumeWorkout(context, ref, w)),
            ),
            false
          );
        }(),
      WorkoutDue(:final plan, :final occasion) => () {
          final sets = occasion.prescription.fold(0, (n, e) => n + (e.targetSets ?? 0));
          // The minutes are the session length chosen when the plan was set up. They are not worked out from
          // the exercises, so they are labelled as planned time and never as an estimate.
          final minutes = plannedMinutes(plan);
          // A rotation's next workout says where it is in the cycle; a fixed day says its plan week.
          final rotation = plan.isRotating ? rotationOf(plan, planOccasions(plan, today, ref.watch(workoutListProvider)), ref.watch(workoutListProvider)) : null;
          final where = rotation != null && rotation.next?.id == occasion.id
              ? 'Step ${rotation.position + 1} of ${rotation.cycle.length}'
              : occasion.sequenceIndex != null ? 'Session ${occasion.sequenceIndex! + 1}' : 'Week ${occasion.weekNumber}';
          return (
            workout(
              // The name and the week beside the photograph; the exercise and set counts on one full-width line.
              status: ('Due today', Icons.today, Tone.accent), name: occasion.title, titleBeside: true,
              body: [line('$where${minutes == null ? '' : ' · $minutes min planned'}')],
              footer: line('${_count(occasion.prescription.length, 'exercise')}${sets == 0 ? '' : ' · $sets planned sets'}', top: 6),
              onDetails: () => showOccasionSheet(context, ref, plan, occasion),
              action: PrimaryButton('Start workout', key: const Key('today-start'), icon: Icons.play_arrow_rounded, onPressed: () => startPlannedWorkout(context, ref, plan, occasion)),
            ),
            false
          );
        }(),
      DoneToday(:final plan, :final occasion, :final outcome, :final next) => (
          plain(
            status: ('Done for today', Icons.check_circle, Tone.success), name: occasion.title,
            text: '${outcome == WorkoutResultRules.full ? 'Finished: all planned sets recorded.' : 'Finished partially: some planned work was not recorded.'} ${nextText(next)}',
            onDetails: () => showOccasionSheet(context, ref, plan, occasion),
            action: SecondaryButton('View plan', onPressed: openPlan),
          ),
          false
        ),
      PlanPausedAction(:final plan) => (
          plain(status: ('Plan paused', Icons.pause_circle_outline, Tone.neutral), name: plan.title, text: 'No workouts are expected while the plan is paused, and nothing counts as missed.',
              action: PrimaryButton('Resume plan', onPressed: () => push(context, ResumeReviewScreen(planId: plan.id)))),
          true
        ),
      StartsLater(:final plan, :final first) => (
          plain(status: ('Starts ${shortDate(plan.startDate)}', Icons.event, Tone.neutral), name: first.title, text: 'Your first workout is on ${longDate(first.scheduledDate)}. Nothing is due before then.',
              action: SecondaryButton('View plan', onPressed: openPlan)),
          true
        ),
      BlockReviewDue(:final plan) => (
          plain(status: ('Block ready to review', Icons.flag_outlined, Tone.accent), name: plan.title,
              text: 'This block has reached its end or has nothing left to do. Review what was actually recorded and choose what comes next.',
              action: PrimaryButton('Review this block', key: const Key('today-block-review'), onPressed: () => push(context, BlockReviewScreen(planId: plan.id)))),
          true
        ),
      RecoveryDay(:final next, :final missed) => (
          plain(status: ('Recovery day', Icons.spa_outlined, Tone.neutral), name: 'Rest today',
              text: '${nextText(next)}${missed.isEmpty ? '' : ' ${missed.length} earlier workout${missed.length == 1 ? ' is' : 's are'} unresolved; move or skip ${missed.length == 1 ? 'it' : 'them'} when you choose.'}',
              action: missed.isEmpty ? SecondaryButton('View plan', onPressed: openPlan) : SecondaryButton('Resolve missed training', key: const Key('today-missed'), onPressed: openPlan)),
          true
        ),
      ReviewDraft(:final draft) => (
          plain(status: ('Your plan is ready to review', Icons.fact_check_outlined, Tone.accent), name: draft.title, text: 'This draft has not started. Nothing is scheduled until you start it.',
              action: PrimaryButton('Review your plan', key: const Key('today-review-draft'), onPressed: () => push(context, PlanReviewScreen(planId: draft.id)))),
          true
        ),
      CreatePlan() => (
          plain(name: 'No plan yet', text: 'Start from a familiar split or build your own and review it before you commit, or just train manually today.',
              action: PrimaryButton('Create my plan', key: const Key('today-create-plan'), onPressed: () => push(context, const CreatePlanScreen()))),
          true
        ),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      card,
      if (offerManual) TextButton(key: const Key('today-manual'), onPressed: () => startManualWorkout(context, ref), child: const Text('Start a manual workout')),
      // Workouts saved for later stay recoverable without taking over the day.
      if (snapshot.parked.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(top: offerManual ? 0 : 12),
          child: GroupCard(children: [
            for (final w in snapshot.parked)
              GroupRow(icon: Icons.bookmark_outline, tone: Tone.neutral, title: w.title, subtitle: 'Saved for later · started ${shortDate(w.dayKey)}', onTap: () => resumeWorkout(context, ref, w)),
          ]),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------- running

/// "5.20 km"
String _km(double meters) => '${(meters / 1000).toStringAsFixed(2)} km';

/// Labelled values of a run ("Distance", "Time"). Only ever built from values that were saved.
class _Cells extends StatelessWidget {
  const _Cells(this.cells);
  final List<(String label, String value)> cells;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        // Side by side with a thin rule between them; they wrap rather than squeeze.
        child: Wrap(runSpacing: 6, children: [
          for (final (i, (label, value)) in cells.indexed)
            Container(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 12, right: i == cells.length - 1 ? 0 : 12),
              decoration: i == 0 ? null : BoxDecoration(border: Border(left: BorderSide(color: context.c.divider))),
              child: MergeSemantics(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: context.caption),
                  Text(value, style: context.titleStyle(22)),
                ]),
              ),
            ),
        ]),
      );
}

/// Today's one way into running, on every kind of day. An open run is read from the saved records, whatever day
/// it began, so it is continued (never started twice) also after the app was closed. Distance and time appear
/// only when they were saved: there is no target, no percentage and no route. The photograph is not a map and
/// says nothing about tracking; distance is measured only while the run's own screen is open.
class _RunCard extends ConsumerStatefulWidget {
  const _RunCard({required this.today, required this.finishedToday});
  final String today;
  final List<Run> finishedToday;
  @override
  ConsumerState<_RunCard> createState() => _RunCardState();
}

class _RunCardState extends ConsumerState<_RunCard> {
  /// Runs only while an open run's clock is running, so its minutes stay true without anything animating.
  Timer? _minute;

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = [for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) if (r.value.isOpen) r.value].firstOrNull;
    final row = open == null ? null : (ref.watch(runtimesProvider).value ?? const <Stored<Json>>[]).where((r) => r.rec.id == open.id).firstOrNull;
    final runtime = row == null ? null : WorkoutRuntime(row.value);
    final ticking = runtime != null && !runtime.isPaused;
    if (ticking) {
      _minute ??= Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
    } else {
      _minute?.cancel();
      _minute = null;
    }

    String time(int seconds) => seconds < 60 ? 'Under 1 min' : durationText(seconds);
    final _Status? status;
    final String? note;
    var cells = const <(String, String)>[];
    if (open != null) {
      // The saved clock and the distance measured so far. Without them the card says only that a run is open.
      final track = RunTrack(runtime?.j['track'] as Json? ?? const {});
      cells = [if (track.hasDistance) ('Distance', _km(track.distanceMeters)), if (runtime != null) ('Time', time(runtime.elapsedSeconds(ref.read(clockProvider).utcNow())))];
      status = runtime?.isPaused ?? false ? ('Paused', Icons.pause_circle_outline, Tone.accent) : ('In progress', Icons.timelapse, Tone.accent);
      note = open.dayKey == widget.today ? (cells.isEmpty ? 'Started today' : null) : 'Started ${shortDate(open.dayKey)}';
    } else if (widget.finishedToday.isNotEmpty) {
      final last = widget.finishedToday.last;
      cells = [if (last.distanceMeters != null) ('Distance', _km(last.distanceMeters!)), if (last.activeDurationSeconds != null) ('Time', time(last.activeDurationSeconds!))];
      status = ('Finished today', Icons.check, Tone.neutral);
      note = null;
    } else {
      status = null;
      note = 'No run today';
    }
    return _Module(
      key: const Key('today-module-run'), label: 'Run', status: status,
      body: [
        if (note != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note, style: context.sansStyle(14, color: context.c.secondary))),
        if (cells.isNotEmpty) _Cells(cells),
      ],
      photo: _Photos.run, photoAlignment: const Alignment(0.7, 0.5),
      action: SecondaryButton(open == null ? 'Start run' : 'Continue run', key: const Key('today-run'), onPressed: () => startRunFlow(context, ref)),
      quiet: TextButton(key: const Key('today-run-history'), onPressed: () => push(context, const RunHistoryScreen()), child: const Text('History', semanticsLabel: 'Run history')),
    );
  }
}

// ---------------------------------------------------------------------------- nutrition

/// Today's food at a glance, from the same entries and coverage Eat shows in full. The bowl in the photograph is
/// decoration: it is not an entry, and it is there on a day with nothing logged too.
class _NutritionCard extends ConsumerWidget {
  const _NutritionCard({required this.day, required this.snapshot, required this.failed});
  final String day;
  final DailySnapshot? snapshot;
  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot;
    final profile = ref.watch(profileProvider).value;
    final goals = NutritionSummary.goalsText(profile?.calorieGoal, profile?.proteinGoal);
    final logged = !failed && s != null && s.food.isNotEmpty;
    void openEat() => ref.read(shellProvider.notifier).switchTab(2);
    Widget line(String text) => Padding(padding: const EdgeInsets.only(top: 2), child: Text(text, style: context.sansStyle(14, color: context.c.secondary)));
    return _Module(
      key: const Key('today-module-nutrition'), label: 'Nutrition',
      body: [
        if (failed)
          const Padding(padding: EdgeInsets.only(top: 4), child: StatusLine(Icons.error_outline, 'Today\'s food could not be read from this phone.', tone: Tone.error))
        else if (s == null)
          line('Loading…')
        else if (s.food.isEmpty) ...[
          line('No food logged today'),
          if (goals != null) line('Your daily goal: $goals'),
        ] else
          Padding(padding: const EdgeInsets.only(top: 2), child: NutritionSummary(coverage: s.coverage, calorieGoal: profile?.calorieGoal, proteinGoal: profile?.proteinGoal)),
      ],
      // Any food without a value: said here in a line, explained in Eat.
      footer: logged ? NutritionMissingNote(coverage: s.coverage, onDetails: openEat) : null,
      photo: _Photos.nutrition, photoAlignment: const Alignment(0.3, 0),
      action: SecondaryButton('Log food', key: const Key('log-food'), onPressed: () => openFoodForm(context, dayKey: day)),
      quiet: TextButton(key: const Key('today-open-eat'), onPressed: openEat, child: const Text('Journal', semanticsLabel: 'Food journal')),
    );
  }
}

// ---------------------------------------------------------------------------- recorded today

/// What was recorded today, in its own words: a manual workout is "Recorded", never a completed plan day.
/// A single finished run is already said on the Run module, so runs are listed here only when there are several;
/// an open run is never listed.
class _ActivitySection extends ConsumerWidget {
  const _ActivitySection(this.snapshot, this.finishedRuns);
  final DailySnapshot snapshot;
  final List<Run> finishedRuns;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Semantics(header: true, child: const Overline('Recorded today'))),
        GroupCard(children: [
          for (final w in snapshot.recordedToday)
            GroupRow(
              icon: Icons.fitness_center, tone: Tone.neutral, title: w.title,
              subtitle: '${w.isManual ? 'Manual workout' : 'Planned workout'} · ${WorkoutResultRules.label(w.outcome)}${w.performedSets > 0 ? ' · ${w.performedSets} set${w.performedSets == 1 ? '' : 's'}' : ''}',
              onTap: () => push(context, WorkoutDetailScreen(workoutId: w.id)),
            ),
          if (finishedRuns.length > 1)
            for (final r in finishedRuns)
              GroupRow(
                icon: Icons.directions_run, tone: Tone.neutral, title: 'Run',
                subtitle: '${durationText(r.activeDurationSeconds ?? 0)}${r.distanceMeters == null ? '' : ' · ${_km(r.distanceMeters!)}'}',
                onTap: () => push(context, RunScreen(runId: r.id)),
              ),
        ]),
      ]);
}
