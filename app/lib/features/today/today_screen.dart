import 'dart:async';

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
import '../coach/coach_bubble.dart';
import '../coach/coach_rig.dart' show RigFrame;
import '../coach/coach_contract.dart';
import '../coach/coach_prefs.dart';
import '../nutrition/food_form.dart';
import '../nutrition/nutrition_surface.dart';
import '../nutrition/nutrition_tools.dart';
import '../nutrition/water.dart';
import '../plans/builder/plan_builder_screen.dart';
import '../plans/plan_actions.dart';
import '../plans/plan_progress.dart';
import '../plans/plan_projection.dart' show rotationOf;
import '../plans/plan_repository.dart';
import '../plans/plan_screens.dart';
import '../shell/home_shell.dart';
import '../weather/weather.dart';
import '../workout/result_rules.dart';
import '../workout/workout_detail_screen.dart';
import '../workout/workout_flow.dart';
import '../workout/workout_runtime.dart';
import 'daily.dart';
import 'today_greeting.dart';

/// The three photographs of Today. They are bundled decoration made for this app: not the user's workout, not a
/// route, not a meal anyone logged. Screen readers never hear about them, and a missing file leaves a plain panel.
abstract final class _Photos {
  static const workout = 'assets/images/workout-hero.webp', run = 'assets/images/run-cover.webp', nutrition = 'assets/images/nutrition-cover.webp';
}

/// Today: the date and a greeting, then three panels of one family, in this order: the workout and nutrition at the
/// full width, and a compact Run tile with History beside it, the scene showing around them (docs/DESIGN.md › Today
/// panels). Each has its real state and one action. The week and its calendar live in Train › Plan; the exercise list
/// lives in the workout's sheet; the full food breakdown lives in Eat. Every value comes from the signed-in owner's
/// records.
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
    const gap = SizedBox(height: 12);

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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PanelTheme(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (reachable == false) ...[const PanelSurface(child: _ConnectionStatus()), gap],
                    // A nutrition problem never hides training, and the reverse.
                    if (localError)
                      const PanelSurface(child: StatusLine(Icons.error_outline, 'Your training could not be read from this phone. Pull down to try again.', tone: Tone.error))
                    else if (snapshot == null)
                      const PanelSurface(child: StatusLine(Icons.hourglass_empty, 'Loading your training…'))
                    else
                      _TrainingSection(snapshot),
                    gap,
                    _NutritionCard(day: day, snapshot: snapshot, failed: foodError),
                  ]),
                ),
                gap,
                // The compact tile under the panel theme and History beside it on the scene.
                _RunCard(today: day, finishedToday: finishedRuns),
                // What was actually recorded today. Absent when there is nothing to show.
                if (snapshot != null && (snapshot.recordedToday.isNotEmpty || finishedRuns.length > 1)) ...[gap, PanelTheme(child: PanelSurface(child: _ActivitySection(snapshot, finishedRuns)))],
              ]),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// The header's look over the scene: its text follows the sky, not the app's mode (light lines over a night, rain or
/// storm sky and dark lines over a daylight one, as in Apple Weather). Same accent; increased contrast respected.
/// Scenic and Plain are not weather: they keep the app's own mode. Also used for History beside the Run tile.
ThemeData _skyTheme(BuildContext context, WidgetRef ref) {
  final scene = ref.watch(todaySceneProvider);
  final sky = !scene.isWeather ? Theme.of(context).brightness : scene.dark ? Brightness.dark : Brightness.light;
  return goTheme(ref.watch(appearanceProvider).accent, sky, highContrast: MediaQuery.highContrastOf(context));
}

/// The top of Today: the date, the title and the greeting over the scene (the weather, the dusk scene or the plain
/// page, as chosen in Appearance) that fills the tab behind it. Only the scene reads the weather; it repaints alone,
/// so a new scene never rebuilds, moves or resets anything here. The header's own scrim keeps its lines readable over
/// every scene.
///
/// Leon or Leona speaks from the right edge (docs/COACH.md › Companion): the head-and-shoulders portrait leaning in
/// past the header's inset, its bubble right beside it with the greeting, Today's line and Ask me, the tail at the
/// mouth. It is part of this header for as long as Me › Appearance › Show coach on Today is on: it scrolls away with it,
/// is never over the sections, a form or the navigation, and there is no close button. The portrait is Ask GoHard's
/// launcher, like Ask me. Narrow phones get a smaller guide; large text, a taller bubble.
class _Header extends ConsumerStatefulWidget {
  const _Header({required this.day});
  final String day;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  int _ack = 0;

  /// The guide's portrait at this width: smaller on narrow phones, never gone (it is Today's way into Ask GoHard).
  /// Large text makes the bubble taller, not the guide absent.
  static Size _slot(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 340 ? const Size(68, 84) : width < 380 ? const Size(80, 100) : const Size(92, 114);
  }

  /// Asking: the guide nods (seen as Today comes back, since it pauses while covered) and Ask GoHard opens.
  void _asked() => setState(() => _ack++);

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final coach = ref.watch(coachPrefsProvider);
    final prefs = ref.read(coachPrefsProvider.notifier);
    final owner = ref.watch(ownerProvider) ?? '';
    final saved = ref.watch(workoutSavedProvider);
    final justSaved = saved != null && saved.day == day;
    // Only Show coach on Today decides: an old "hidden for today" from an earlier build is not read at all.
    final slot = coach.onToday ? _slot(context) : null;
    if (slot != null && justSaved && !saved.played && (ModalRoute.isCurrentOf(context) ?? true) && TickerMode.valuesOf(context).enabled) {
      // The finish this session, acknowledged once, when Today is in view again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(workoutSavedProvider.notifier).played();
        setState(() => _ack++);
      });
    }
    // While a workout or a run is open the companion stays quiet: no entrance, just the settled guide.
    final busy = (ref.watch(dailySnapshotProvider)?.inProgress.isNotEmpty ?? false) || (ref.watch(runsProvider).value ?? const []).any((r) => r.value.isOpen);
    final greeting = _greeting(context, ref, justSaved: justSaved);
    const ask = CoachContext(label: 'Your training');
    return Theme(
      key: const Key('today-header'),
      // The header's text and scrim follow the sky (see [_skyTheme]).
      data: _skyTheme(context, ref),
      child: Builder(
        builder: (context) => Padding(
          // The scene runs to the top edge, behind the status bar; the lines start below it.
          padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topInset(context), context.inset, 8),
          child: TabHeader(
            title: 'Today', overline: longDate(day), onBackdrop: true,
            below: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (slot == null)
                _Greeting(greeting)
              else
                CoachSpeech(
                  key: const Key('today-coach'),
                  say: CoachSay(greeting.line ?? 'Need a hand with today?', title: greeting.title, ask: ask),
                  portrait: slot, frame: RigFrame.edge, bleed: context.inset,
                  greet: !busy && coach.mayGreet(owner, day), ack: _ack,
                  onGreeted: () => prefs.markGreeted(owner, day), // after the frame, so not through ref
                  onAsk: _asked,
                  onAvatarTap: () {
                    _asked();
                    openAskGoHard(context, ask);
                  },
                ),
              const _SkyLine(),
            ]),
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
      final t = scene.temperatureC;
      text = t == null ? scene.label! : '${formatTemperature(t, fahrenheit: ref.watch(weatherPrefsProvider.select((p) => p.fahrenheit)))} · ${scene.label}';
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

/// "Good afternoon, Babti!" and one factual line ("Upper body A is planned today."): the phone's local time, the
/// first word of the name on the profile and Today's own projection (today_greeting.dart), worked out on the phone;
/// opening Today never asks the AI. The line is left out at large text, where the workout module says it anyway.
typedef _TodayGreeting = ({String title, String? line, bool day});

_TodayGreeting _greeting(BuildContext context, WidgetRef ref, {required bool justSaved}) {
  final hour = ref.watch(clockProvider).utcNow().toLocal().hour;
  final words = partOfDay(hour);
  final name = firstName(ref.watch(profileProvider).value?.j['displayName'] as String?);
  final snapshot = ref.watch(dailySnapshotProvider);
  final line = snapshot == null || MediaQuery.textScalerOf(context).scale(10) > 13 ? null : todayLine(snapshot, ref.watch(workoutListProvider), justSaved: justSaved);
  return (title: name == null ? '$words!' : '$words, $name!', line: line, day: hour >= 5 && hour < 18);
}

/// The greeting without the guide (Show coach on Today off, hidden for the day, a narrow phone or large text): the
/// round time-of-day icon and the same words; Ask GoHard is then beside the title.
class _Greeting extends StatelessWidget {
  const _Greeting(this.g);
  final _TodayGreeting g;

  @override
  Widget build(BuildContext context) => Row(children: [
        IconTile(g.day ? Icons.wb_sunny_outlined : Icons.nightlight_outlined, size: 40, circle: true),
        const SizedBox(width: 14),
        Expanded(
          child: MergeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.title, key: const Key('today-greeting'), style: context.sansStyle(18, weight: FontWeight.w500)),
              if (g.line != null) Text(g.line!, key: const Key('today-greeting-line'), style: context.sansStyle(15, color: context.c.text)),
            ]),
          ),
        ),
      ]);
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

/// A state in an icon and a word ("In progress", "Due today"), the panel's badge. The tone only adds to the word:
/// accent for what is live or due, the success colour for what is finished, quiet otherwise.
typedef _Status = (String label, IconData icon, Tone tone);

/// The content of one of Today's panels, all three built from this: the label (Nutrition, Run) and the state badge,
/// the content, then the main button with a quiet link beside it. The words keep to the part of the panel the
/// photograph has faded out of; the button row may reach further, over the faint start of the fade. Heights follow
/// the content. With large text the photograph gives its room to the words, and the button and link wrap.
class _Module extends StatelessWidget {
  const _Module({super.key, required this.label, this.showLabel = true, this.status, this.head = const [], this.body = const [], this.footer, this.photo, this.photoAlignment = Alignment.center,
      required this.action, this.quiet, this.below = const []});

  /// The overline, and always the panel's heading for a screen reader. The workout panel does not show it: its badge
  /// and its name say what it is, as in the approved design.
  final String label;
  final bool showLabel;
  final _Status? status;
  final List<Widget> head, body;
  final Widget? footer;
  final String? photo;
  final Alignment photoAlignment;
  final Widget action;
  final Widget? quiet;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final pictured = photo != null && !large;
    final s = status;
    final labelRow = Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Semantics(header: true, label: showLabel ? null : label, child: showLabel ? Overline(label) : const SizedBox.shrink()),
      if (s != null) StatusPill(s.$1, icon: s.$2, tone: s.$3),
    ]);
    final words = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [labelRow, ...head, ...body, ?footer]);
    return PanelSurface(
      photo: pictured ? PanelPhoto(photo!, key: Key('today-photo-${label.toLowerCase()}'), alignment: photoAlignment) : null,
      below: below,
      child: LayoutBuilder(
        builder: (context, box) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(constraints: BoxConstraints(maxWidth: pictured ? box.maxWidth * PanelSurface.wordsShare : box.maxWidth), child: words),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [action, ?quiet]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------- training

/// Today's training, as three separate facts (docs/TRAINING_PLANS.md › Today): what the plan says about today, with
/// each of today's occurrences in its real state; the next workout, on its real date or as the next in a rotation;
/// and what is actually open, kept apart from the plan. A manual workout never hides or stands in for a planned one.
class _TrainingSection extends ConsumerWidget {
  const _TrainingSection(this.snapshot);
  final DailySnapshot snapshot;

  static String _count(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';

  /// Today's state of a planned occurrence, in words with an icon (never colour alone).
  static _Status _todayStatus(OccasionStatus s) => switch (s) {
        OccasionStatus.inProgress => ('In progress', Icons.timelapse, Tone.accent),
        OccasionStatus.finished => ('Completed', Icons.check_circle, Tone.success),
        OccasionStatus.partial => ('Partly completed', Icons.check_circle_outline, Tone.neutral),
        OccasionStatus.skipped => ('Skipped today', Icons.skip_next_outlined, Tone.neutral),
        OccasionStatus.missed => ('Missed', Icons.error_outline, Tone.warning),
        OccasionStatus.paused => ('Paused', Icons.pause_circle_outline, Tone.neutral),
        OccasionStatus.due || OccasionStatus.upcoming => ('Due today', Icons.today, Tone.accent),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = snapshot.training;
    final c = context.c;
    final app = appContext(context);
    final today = snapshot.dayKey;
    final all = ref.watch(workoutListProvider);
    // Within the coming week the weekday, further out the full date.
    String when(Occasion o) => daysBetween(today, o.scheduledDate) < 7 ? weekdayName(weekdayOf(o.scheduledDate)) : longDate(o.scheduledDate);
    // "Next: Pull · Wednesday" on its real date. A rotation names its next workout; it has a day only when the plan
    // has training days to put it on.
    String nextText(Plan plan, Occasion? next) => next == null
        ? 'No further workout is scheduled in this block.'
        : plan.isRotating
            ? 'Next in your rotation: ${next.title}${(plan.schedule?.trainingDays ?? const []).isEmpty ? '' : ' · ${when(next)}'}.'
            : 'Next: ${next.title} · ${when(next)}.';
    void openPlan() => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan);
    // The workout's name in the serif, as the approved design has it; a long name wraps.
    Widget title(String text) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: context.pageTitleStyle(36)));
    Widget line(String text, {double top = 4}) => Padding(padding: EdgeInsets.only(top: top), child: Text(text, style: context.sansStyle(15, color: c.secondary)));
    Widget details(VoidCallback onPressed) => QuietLink('Details', key: const Key('today-details'), said: 'Workout details', onPressed: onPressed);
    // Under the lead workout in the same panel: other workouts today, missed ones, a manual workout, saved for later.
    // Set before the lead is built (below).
    var extras = const <Widget>[];

    /// A day with a workout to do: the only variant with the training photograph.
    Widget workout({required _Status status, required String name, List<Widget> head = const [], required List<Widget> body, Widget? footer, required Widget action, required VoidCallback onDetails}) => _Module(
        key: const Key('today-module-workout'), label: 'Workout', showLabel: false, status: status,
        head: [title(name), ...head], body: body, footer: footer,
        // The dumbbells sit low and right in the picture.
        photo: _Photos.workout, photoAlignment: const Alignment(1, 0.6), action: action, quiet: details(onDetails), below: extras);

    /// Rest, skipped, completed, paused, not started, nothing planned: the same panel in words only. A picture of
    /// training must not sit beside "Rest day" or "No plan yet".
    Widget plain({_Status? status, required String name, required String text, required Widget action, VoidCallback? onDetails, Widget? quiet}) => _Module(
        key: const Key('today-module-workout'), label: 'Workout', showLabel: false, status: status, head: [title(name)], body: [line(text, top: 6)],
        action: action, quiet: quiet ?? (onDetails == null ? null : details(onDetails)), below: extras);

    /// One of today's planned occurrences with its workout open: the sets recorded against its plan. Saved for later,
    /// it says so and its Resume is quiet: it is still today's workout, but it does not take over the day.
    Widget inProgress(Plan plan, Occasion occasion, Workout w) {
      final sets = SetProgress.of(w, ref.watch(trustedSetsProvider));
      final n = w.exercises.length;
      final parked = ref.watch(parkedIdsProvider).contains(w.id);
      void resume() => resumeWorkout(app, ref, w);
      return workout(
        status: parked ? ('Saved for later', Icons.bookmark_outline, Tone.neutral) : _todayStatus(OccasionStatus.inProgress), name: w.title,
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
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('${_count(sets.recorded, 'set')} recorded', style: context.numStyle(16))),
        ],
        onDetails: () => showOccasionSheet(app, ref, plan, occasion),
        action: parked
            ? SecondaryButton('Resume workout', key: const Key('today-resume'), icon: Icons.play_arrow_rounded, expand: false, onPressed: resume)
            : PrimaryButton('Resume workout', key: const Key('today-resume'), icon: Icons.play_arrow_rounded, expand: false, onPressed: resume),
      );
    }

    /// One of today's planned occurrences still to do. [quietStart] when another workout is open in front.
    Widget due(Plan plan, Occasion occasion, {bool quietStart = false}) {
      final sets = occasion.prescription.fold(0, (n, e) => n + (e.targetSets ?? 0));
      // The minutes are the session length chosen when the plan was set up. They are not worked out from the
      // exercises, so they are labelled as planned time and never as an estimate.
      final minutes = plannedMinutes(plan);
      // A rotation's next workout says where it is in the cycle; a fixed day says its plan week.
      final rotation = plan.isRotating ? rotationOf(plan, planOccasions(plan, today, all), all) : null;
      final where = rotation != null && rotation.next?.id == occasion.id
          ? 'Step ${rotation.position + 1} of ${rotation.cycle.length}'
          : occasion.sequenceIndex != null ? 'Session ${occasion.sequenceIndex! + 1}' : 'Week ${occasion.weekNumber}';
      void start() => startPlannedWorkout(app, ref, plan, occasion);
      return workout(
        // The exercise and set counts under the name, then where it is in the plan.
        status: _todayStatus(OccasionStatus.due), name: occasion.title,
        body: [
          line('${_count(occasion.prescription.length, 'exercise')}${sets == 0 ? '' : ' · $sets planned sets'}'),
          line('$where${minutes == null ? '' : ' · $minutes min planned'}', top: 2),
        ],
        onDetails: () => showOccasionSheet(app, ref, plan, occasion),
        action: quietStart
            ? SecondaryButton('Start workout', key: const Key('today-start'), icon: Icons.play_arrow_rounded, expand: false, onPressed: start)
            : PrimaryButton('Start workout', key: const Key('today-start'), icon: Icons.play_arrow_rounded, expand: false, onPressed: start),
      );
    }

    /// One of today's planned occurrences already resolved: skipped, completed or partly completed. It stays
    /// today's, under its own name; the next workout is named beside it, never in its place.
    Widget resolved(Plan plan, Occasion o, OccasionStatus s, Occasion? next, bool blockDone) {
      final what = switch (s) {
        OccasionStatus.skipped => 'Skipped: nothing was recorded for it and it does not count as training.',
        OccasionStatus.finished => 'Finished: all planned sets recorded.',
        _ => 'Finished partially: some planned work was not recorded.',
      };
      final undo = s == OccasionStatus.skipped && !o.isVirtual && PlanRepository.canUnskip(plan, o.id, all);
      return plain(
        status: _todayStatus(s), name: o.title,
        text: '$what ${blockDone ? 'That was the last workout of this block.' : nextText(plan, next)}',
        onDetails: () => showOccasionSheet(app, ref, plan, o),
        quiet: undo
            ? TextButton(
                key: const Key('today-undo-skip'),
                onPressed: () => runPlanDecision(app, () => ref.read(planRepositoryProvider).unskip(plan, o.id, workouts: all), saved: 'No longer skipped.'),
                child: const Text('Undo skip'))
            : null,
        action: blockDone
            ? PrimaryButton('Review this block', key: const Key('today-block-review'), expand: false, onPressed: () => push(context, BlockReviewScreen(planId: plan.id)))
            // A rotation's next workout can be done now, as an explicit choice; skipping alone never puts it on today.
            : plan.isRotating && next != null && plan.isActive
                ? SecondaryButton('Train this now', key: const Key('today-train-now'), icon: Icons.play_arrow_rounded, expand: false, onPressed: () => startPlannedWorkout(app, ref, plan, next))
                : SecondaryButton('View plan', expand: false, onPressed: openPlan),
      );
    }

    // Each state: whether a manual workout is offered, what else belongs under the lead, and the lead panel itself.
    final (bool offerManual, List<Widget> own, Widget Function() card) = switch (a) {
      PlannedToday(:final plan, :final occasions, :final next, :final missed, :final blockDone) => () {
          final status = {for (final o in occasions) o.id: statusOf(o, plan, today, all)};
          // In front: the one in progress, else the first still due, else the first of the day.
          final lead = occasions.where((o) => status[o.id] == OccasionStatus.inProgress).firstOrNull ??
              occasions.where((o) => status[o.id] == OccasionStatus.due).firstOrNull ??
              occasions.first;
          final open = openWorkoutFor(lead, all);
          final s = status[lead.id]!;
          final others = [for (final o in occasions) if (o.id != lead.id) o];
          return (
            open == null && s != OccasionStatus.due && snapshot.inProgress.isEmpty,
            <Widget>[
              // Every other occurrence on today's date keeps its own row and state.
              if (others.isNotEmpty)
                GroupCard(children: [
                  for (final o in others)
                    GroupRow(
                        key: Key('today-also-${o.id}'), icon: Icons.fitness_center, tone: Tone.neutral, title: o.title,
                        subtitle: 'Also today · ${_todayStatus(status[o.id]!).$1}', onTap: () => showOccasionSheet(app, ref, plan, o)),
                ]),
              if (missed.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(key: const Key('today-missed'), onPressed: openPlan,
                      child: Text('${missed.length} earlier workout${missed.length == 1 ? ' is' : 's are'} unresolved')),
                ),
            ],
            () => open != null
                ? inProgress(plan, lead, open)
                : s == OccasionStatus.due
                    ? due(plan, lead, quietStart: snapshot.inProgress.isNotEmpty)
                    : resolved(plan, lead, s, next, blockDone),
          );
        }(),
      PlannedRest(:final plan, :final next, :final missed, :final chosen) => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(
                status: ('Planned rest day', Icons.spa_outlined, Tone.neutral), name: 'Rest day',
                text: '${chosen ? 'You chose to rest today. Nothing was skipped and your rotation waits for you. ' : ''}${nextText(plan, next)}'
                    '${missed.isEmpty ? '' : ' ${missed.length} earlier workout${missed.length == 1 ? ' is' : 's are'} unresolved; move or skip ${missed.length == 1 ? 'it' : 'them'} when you choose.'}',
                action: missed.isEmpty
                    ? SecondaryButton('View plan', expand: false, onPressed: openPlan)
                    : SecondaryButton('Resolve missed training', key: const Key('today-missed'), expand: false, onPressed: openPlan),
                quiet: chosen
                    ? TextButton(key: const Key('today-undo-rest'), onPressed: () => ref.read(planRepositoryProvider).setRestDay(plan, today, rest: false), child: const Text('Train today'))
                    : null,
              ),
        ),
      PlanPausedAction(:final plan) => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(status: ('Plan paused', Icons.pause_circle_outline, Tone.neutral), name: plan.title, text: 'No workouts are expected while the plan is paused, and nothing counts as missed.',
              action: PrimaryButton('Resume plan', expand: false, onPressed: () => push(context, ResumeReviewScreen(planId: plan.id)))),
        ),
      StartsLater(:final plan, :final first) => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(status: ('Starts ${shortDate(plan.startDate)}', Icons.event, Tone.neutral), name: first.title, text: 'Your plan begins on ${longDate(first.scheduledDate)}. Nothing is due before then.',
              action: SecondaryButton('View plan', expand: false, onPressed: openPlan)),
        ),
      BlockReviewDue(:final plan) => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(status: ('Block ready to review', Icons.flag_outlined, Tone.accent), name: plan.title,
              text: 'This block has reached its end or has nothing left to do. Review what was actually recorded and choose what comes next.',
              action: PrimaryButton('Review this block', key: const Key('today-block-review'), expand: false, onPressed: () => push(context, BlockReviewScreen(planId: plan.id)))),
        ),
      ReviewDraft(:final draft) => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(status: ('Your plan is ready to review', Icons.fact_check_outlined, Tone.accent), name: draft.title, text: 'This draft has not started. Nothing is scheduled until you start it.',
              action: PrimaryButton('Review your plan', key: const Key('today-review-draft'), expand: false, onPressed: () => push(context, PlanReviewScreen(planId: draft.id)))),
        ),
      CreatePlan() => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(name: 'No active plan', text: 'Start from a familiar split or build your own and review it before you commit, or just train manually today.',
              action: PrimaryButton('Create my plan', key: const Key('today-create-plan'), expand: false, onPressed: () => push(context, const CreatePlanScreen()))),
        ),
    };
    extras = [
      ...own,
      if (offerManual) Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('today-manual'), onPressed: () => startManualWorkout(app, ref), child: const Text('Start a manual workout'))),
      // Workouts saved for later stay recoverable without taking over the day.
      if (snapshot.parked.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: GroupCard(children: [
            for (final w in snapshot.parked)
              GroupRow(icon: Icons.bookmark_outline, tone: Tone.neutral, title: w.title, subtitle: 'Saved for later · started ${shortDate(w.dayKey)}', onTap: () => resumeWorkout(app, ref, w)),
          ]),
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // An open workout outside today's plan (a manual one, or a planned one from another day) has its own panel in
      // front, and the plan's own state stays below it, unchanged.
      for (final w in snapshot.inProgress) ...[_OpenWorkout(w), const SizedBox(height: 12)],
      card(),
    ]);
  }
}

/// A workout open in front that is not one of today's planned occurrences: a compact panel with its own Resume and
/// no photograph. It is what was actually started, in its own words; it never says it is the plan's workout.
class _OpenWorkout extends ConsumerWidget {
  const _OpenWorkout(this.w);
  final Workout w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = SetProgress.of(w, ref.watch(trustedSetsProvider));
    final n = w.exercises.length;
    final what = w.isManual ? 'Manual workout' : 'Planned workout from ${shortDate(w.dayKey)}';
    final app = appContext(context);
    return PanelSurface(
      key: Key('today-open-${w.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Semantics(header: true, child: Overline(what)),
            const StatusPill('In progress', icon: Icons.timelapse, tone: Tone.accent),
          ]),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(w.title, style: context.pageTitleStyle(30))),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(n == 0 ? 'No exercise added yet' : _TrainingSection._count(n, 'exercise'), style: context.sansStyle(15, color: context.c.secondary)),
          ),
          // No planned total exists for a manual workout, so there is a count and no percentage.
          if (sets.recorded > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_TrainingSection._count(sets.recorded, 'set')} recorded', style: context.numStyle(16))),
          const SizedBox(height: 14),
          PrimaryButton('Resume workout', key: const Key('today-resume'), icon: Icons.play_arrow_rounded, expand: false, onPressed: () => resumeWorkout(app, ref, w)),
        ]),
    );
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
    // The tile is built under the panel theme; History sits on the scene beside it, in the header's sky colours on a
    // scrim so it reads over any weather.
    final app = context;
    final tile = PanelTheme(
      child: Builder(
        builder: (context) => _Module(
          key: const Key('today-module-run'), label: 'Run', status: status,
          head: [Padding(padding: const EdgeInsets.only(top: 6), child: Text('Run', style: context.pageTitleStyle(30)))],
          body: [
            if (note != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note, style: context.sansStyle(14.5, color: context.c.secondary))),
            if (cells.isNotEmpty) _Cells(cells),
          ],
          // The near shoe and the far leg, at the tile's trailing side.
          photo: _Photos.run, photoAlignment: const Alignment(0.6, 0),
          action: PrimaryButton(open == null ? 'Start run' : 'Continue run', key: const Key('today-run'), icon: Icons.play_arrow_rounded, expand: false, onPressed: () => startRunFlow(app, ref)),
        ),
      ),
    );
    final history = Theme(
      data: _skyTheme(context, ref),
      child: Builder(
        builder: (context) => QuietLink('History', key: const Key('today-run-history'), said: 'Run history', onPressed: () => push(context, const RunHistoryScreen()),
            background: context.c.scrim),
      ),
    );
    // Large text or a narrow phone: the tile takes the width and History goes under it.
    if (MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 350) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile, const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: history)]);
    }
    return Row(children: [Expanded(flex: 64, child: tile), Expanded(flex: 36, child: Center(child: history))]);
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
    final display = ref.watch(nutritionDisplayProvider);
    final goals = NutritionSummary.goalsText(profile?.calorieGoal, profile?.proteinGoal);
    final logged = !failed && s != null && s.food.isNotEmpty;
    void openEat() => ref.read(shellProvider.notifier).switchTab(2);
    Widget line(String text) => Padding(padding: const EdgeInsets.only(top: 2), child: Text(text, style: context.sansStyle(15, color: context.c.secondary)));
    return _Module(
      key: const Key('today-module-nutrition'), label: 'Nutrition',
      body: [
        if (failed)
          const Padding(padding: EdgeInsets.only(top: 6), child: StatusLine(Icons.error_outline, 'Today\'s food could not be read from this phone.', tone: Tone.error))
        else if (s == null)
          line('Loading…')
        else if (s.food.isEmpty) ...[
          // Nothing logged is not zero eaten: words, never "0 kcal".
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('No food logged today', style: context.pageTitleStyle(28))),
          if (goals != null) line('Your daily goal: $goals'),
        ] else
          Padding(padding: const EdgeInsets.only(top: 4), child: NutritionSummary(coverage: s.coverage, calorieGoal: profile?.calorieGoal, proteinGoal: profile?.proteinGoal)),
      ],
      // Any food without a value: said here in a line, explained in Eat.
      footer: logged ? NutritionMissingNote(coverage: s.coverage, onDetails: openEat) : null,
      // The bowl at the trailing side.
      photo: _Photos.nutrition, photoAlignment: const Alignment(0.7, 0),
      action: PrimaryButton('Log food', key: const Key('log-food'), icon: Icons.restaurant, expand: false, onPressed: () => openFoodForm(appContext(context), dayKey: day)),
      quiet: QuietLink('Journal', key: const Key('today-open-eat'), said: 'Food journal', onPressed: openEat),
      // Under the figures, quieter than them: the day's water when it is tracked, then the goals (set or edit, also
      // with nothing logged) and Customize tracking. Sheets open in the app's own look.
      below: [if (display.water) WaterRow(key: const Key('today-water'), day: day), const NutritionTools(keyPrefix: 'today')],
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
