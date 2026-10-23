import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/appearance.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../core/device_prefs.dart';
import '../activity/activity_detail.dart';
import '../auth/account_security.dart' show VerifyEmailScreen;
import '../../core/go_icon.dart';
import '../activity/move_prefs.dart' show stepGoalProvider, stepsEnabledProvider, stepsOnTodayProvider;
import '../activity/steps.dart';
import '../activity/steps_ui.dart';
import '../activity/recorder.dart';
import '../activity/run_walk_screens.dart';
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
import 'daily.dart';
import 'today_greeting.dart';

/// The three photographs of Today. They are bundled decoration made for this app: not the user's workout, not a
/// route, not a meal anyone logged. Screen readers never hear about them, and a missing file leaves a plain panel.
abstract final class _Photos {
  static const workout = 'assets/images/workout-hero.webp', run = 'assets/images/run-cover.webp', nutrition = 'assets/images/nutrition-cover.webp';

  /// GoHard_Today_History_Water_Corrections/assets/steps-footprints.png (a generated photograph supplied with the
  /// handoff; ASSETS.md there), resized to 960 px.
  static const steps = 'assets/images/steps-footprints.jpg';
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
    final l = context.l10n;
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
                    if (ref.watch(accountAccessProvider).value case final a? when !a.verified && a.dueAt != null) ...[PanelSurface(child: _VerifyNotice(a)), gap],
                    // A nutrition problem never hides training, and the reverse.
                    if (localError)
                      PanelSurface(child: StatusLine(Icons.error_outline, l.todayTrainingError, tone: Tone.error))
                    else if (snapshot == null)
                      PanelSurface(child: StatusLine(Icons.hourglass_empty, l.todayTrainingLoading))
                    else
                      _TrainingSection(snapshot),
                    gap,
                    _NutritionCard(day: day, snapshot: snapshot, failed: foodError),
                  ]),
                ),
                gap,
                // Run / Walk and, beside it, Steps (shown before it is turned on: that is how it is found); History under them.
                _RunCard(today: day, finishedToday: finishedRuns, steps: ref.watch(stepsOnTodayProvider)),
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

/// An account from before required verification (docs/AUTHENTICATION_EMAIL.md): the server's real deadline and one way
/// to the shared form. Past it, uploads wait and it says so; what is saved on this phone stays. Shown here only, never
/// as a popup.
class _VerifyNotice extends StatelessWidget {
  const _VerifyNotice(this.access);
  final AccountAccess access;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(key: const Key('today-verify-notice'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      StatusLine(Icons.mark_email_unread_outlined, access.required ? l.todayVerifyPaused : l.todayVerifyBy(longDate(dayKeyOf(access.dueAt!))),
          tone: access.required ? Tone.warning : Tone.neutral),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: QuietLink(l.todayVerifyAction, key: const Key('today-verify'), onPressed: () => push(context, const VerifyEmailScreen())),
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

  /// Whether the guide introduces Steps instead of today's line: once (Coaching hints govern it), while steps are off and
  /// their tile is shown, decided the first time Today is really in view and kept for this header's life.
  bool? _stepsIntro;

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
    final inView = ref.watch(shellProvider.select((s) => s.tab == 0)) && (ModalRoute.isCurrentOf(context) ?? true);
    if (_stepsIntro == null && slot != null && inView && owner.isNotEmpty && !busy && !justSaved) {
      // Not on the account's first day (that greeting is about the plan): from a day after an earlier greeting.
      final returning = coach.greeted != null && coach.greeted!.startsWith('$owner|') && coach.greeted != CoachPrefs.dayKey(owner, day);
      _stepsIntro = returning && !ref.read(stepsEnabledProvider) && ref.read(stepsOnTodayProvider) && coach.mayIntroduce(owner, 'today.steps');
      if (_stepsIntro!) WidgetsBinding.instance.addPostFrameCallback((_) => prefs.markSeen(owner, 'today.steps'));
    }
    final intro = _stepsIntro == true && !ref.watch(stepsEnabledProvider);
    final l = context.l10n;
    return Theme(
      key: const Key('today-header'),
      // The header's text and scrim follow the sky (see [_skyTheme]).
      data: _skyTheme(context, ref),
      child: Builder(
        builder: (context) => Padding(
          // The scene runs to the top edge, behind the status bar; the lines start below it.
          padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topInset(context), context.inset, 8),
          child: TabHeader(
            title: l.navToday, overline: longDate(day), onBackdrop: true,
            below: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (slot == null)
                _Greeting(greeting)
              else
                CoachSpeech(
                  key: const Key('today-coach'),
                  say: intro
                      ? CoachSay(l.todayCoachStepsIntro, title: greeting.title,
                          guide: (label: l.todayCoachEnableSteps, key: const Key('today-coach-steps'), onPressed: () => showStepsSheet(context)))
                      : CoachSay(greeting.line ?? l.todayCoachNeedHand, title: greeting.title, ask: ask),
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

  static String _issue(AppLocalizations l, WeatherIssue i) => switch (i) {
        WeatherIssue.needsPermission => l.todaySkyNeedsPermission,
        WeatherIssue.denied || WeatherIssue.deniedForever => l.todaySkyDenied,
        WeatherIssue.servicesOff => l.todaySkyServicesOff,
        WeatherIssue.timeout => l.todaySkyTimeout,
        WeatherIssue.offline => l.todaySkyOffline,
        WeatherIssue.unavailable => l.todaySkyUnavailable,
        WeatherIssue.noCity => l.todaySkyNoCity,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(todaySceneProvider);
    final issue = ref.watch(weatherProvider.select((w) => w.issue));
    final l = context.l10n;
    final String text;
    final IconData icon;
    if (scene.isWeather) {
      // Worked out from the cached answer's code: a new language asks the provider for nothing.
      final t = scene.temperatureC, condition = sceneLabel(l, scene);
      text = t == null ? condition : l.todaySkyWeather(formatTemperature(t, fahrenheit: ref.watch(weatherPrefsProvider.select((p) => p.fahrenheit))), condition);
      icon = Icons.cloud_outlined;
    } else if (scene.fallback != null) {
      text = l.todaySkyScenic(issue == null ? weatherFallbackText(l, scene.fallback!) : _issue(l, issue));
      icon = Icons.landscape_outlined;
    } else {
      return const SizedBox.shrink();
    }
    return Semantics(
      button: true, hint: l.todaySkyHint,
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
  final l = context.l10n;
  final name = firstName(ref.watch(profileProvider).value?.j['displayName'] as String?);
  final snapshot = ref.watch(dailySnapshotProvider);
  final line = snapshot == null || MediaQuery.textScalerOf(context).scale(10) > 13 ? null : todayLine(l, snapshot, ref.watch(workoutListProvider), justSaved: justSaved);
  return (title: greetingTitle(l, hour, name), line: line, day: hour >= 5 && hour < 18);
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
                child: StatusLine(Icons.cloud_off, pending == 0 ? context.l10n.shellCantSyncLabel : context.l10n.shellCantSyncWaiting(pending), tone: Tone.warning),
              ),
              Icon(_open ? Icons.expand_less : Icons.expand_more, size: 22, color: c.secondary),
            ]),
          ),
        ),
      ),
      if (_open) ...[
        Text(pending == 0 ? context.l10n.todayCantSyncDetailNothingWaiting : context.l10n.todayCantSyncDetailWaiting, style: context.caption),
        Align(alignment: AlignmentDirectional.centerStart, child: TextButton(key: const Key('today-connection-retry'), onPressed: () => refreshFromAccount(ref), child: Text(context.l10n.actionTryAgain))),
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
  const _Module({super.key, required this.label, required this.photoId, this.showLabel = true, this.status, this.head = const [], this.body = const [], this.footer, this.photo, this.photoAlignment = Alignment.center,
      required this.action, this.quiet, this.below = const []});

  /// The overline, and always the panel's heading for a screen reader. The workout panel does not show it: its badge
  /// and its name say what it is, as in the approved design.
  final String label;

  /// Names the photograph's key (`today-photo-<photoId>`), never the displayed label.
  final String photoId;
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
    // A fraction of the width, not a LayoutBuilder, so two tiles can be measured and made the same height.
    return PanelSurface(
      photo: pictured ? PanelPhoto(photo!, key: Key('today-photo-$photoId'), alignment: photoAlignment) : null,
      below: below,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        FractionallySizedBox(widthFactor: pictured ? PanelSurface.wordsShare : 1, alignment: AlignmentDirectional.centerStart, child: words),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [action, ?quiet]),
      ]),
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

  /// Today's state of a planned occurrence, in words with an icon (never colour alone).
  static _Status _todayStatus(AppLocalizations l, OccasionStatus s) => switch (s) {
        OccasionStatus.inProgress => (l.todayStatusInProgress, Icons.timelapse, Tone.accent),
        OccasionStatus.finished => (l.todayStatusCompleted, Icons.check_circle, Tone.success),
        OccasionStatus.partial => (l.todayStatusPartly, Icons.check_circle_outline, Tone.neutral),
        OccasionStatus.skipped => (l.todayStatusSkipped, Icons.skip_next_outlined, Tone.neutral),
        OccasionStatus.missed => (l.todayStatusMissed, Icons.error_outline, Tone.warning),
        OccasionStatus.paused => (l.todayStatusPaused, Icons.pause_circle_outline, Tone.neutral),
        OccasionStatus.due || OccasionStatus.upcoming => (l.todayStatusDue, Icons.today, Tone.accent),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = snapshot.training;
    final c = context.c;
    final l = context.l10n;
    final app = appContext(context);
    final today = snapshot.dayKey;
    final all = ref.watch(workoutListProvider);
    // Within the coming week the weekday, further out the full date.
    String when(Occasion o) => daysBetween(today, o.scheduledDate) < 7 ? weekdayName(weekdayOf(o.scheduledDate)) : longDate(o.scheduledDate);
    // "Next: Pull · Wednesday" on its real date. A rotation names its next workout; it has a day only when the plan
    // has training days to put it on.
    String nextText(Plan plan, Occasion? next) => next == null
        ? l.todayNextNone
        : plan.isRotating
            ? (plan.schedule?.trainingDays ?? const []).isEmpty ? l.todayNextRotation(next.title) : l.todayNextRotationDay(next.title, when(next))
            : l.todayNext(next.title, when(next));
    void openPlan() => ref.read(shellProvider.notifier).switchTab(1, trainView: TrainView.plan);
    // Details is the workout itself in Train › Workouts: its preview before Start (nothing is created), the open workout
    // as it is (paused or saved for later stays so), or what was recorded.
    void preview(Plan plan, Occasion o) => ref.read(shellProvider.notifier).openWorkout(WorkoutFocus.preview(plan.id, o.id));
    // The workout's name in the serif, as the approved design has it; a long name wraps.
    Widget title(String text) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: context.pageTitleStyle(36)));
    Widget line(String text, {double top = 4}) => Padding(padding: EdgeInsetsDirectional.only(top: top), child: Text(text, style: context.sansStyle(15, color: c.secondary)));
    Widget details(VoidCallback onPressed) => QuietLink(l.todayDetailsLink, key: const Key('today-details'), said: l.todayDetailsSaid, onPressed: onPressed);
    // Under the lead workout in the same panel: other workouts today, missed ones, a manual workout, saved for later.
    // Set before the lead is built (below).
    var extras = const <Widget>[];

    /// A day with a workout to do: the only variant with the training photograph.
    Widget workout({required _Status status, required String name, List<Widget> head = const [], required List<Widget> body, Widget? footer, required Widget action, required VoidCallback onDetails}) => _Module(
        key: const Key('today-module-workout'), label: l.todayWorkoutLabel, photoId: 'workout', showLabel: false, status: status,
        head: [title(name), ...head], body: body, footer: footer,
        // The dumbbells sit low and right in the picture.
        photo: _Photos.workout, photoAlignment: const Alignment(1, 0.6), action: action, quiet: details(onDetails), below: extras);

    /// Rest, skipped, completed, paused, not started, nothing planned: the same panel in words only. A picture of
    /// training must not sit beside "Rest day" or "No plan yet".
    Widget plain({_Status? status, required String name, required String text, required Widget action, VoidCallback? onDetails, Widget? quiet}) => _Module(
        key: const Key('today-module-workout'), label: l.todayWorkoutLabel, photoId: 'workout', showLabel: false, status: status, head: [title(name)], body: [line(text, top: 6)],
        action: action, quiet: quiet ?? (onDetails == null ? null : details(onDetails)), below: extras);

    /// One of today's planned occurrences with its workout open: the sets recorded against its plan. Saved for later,
    /// it says so and its Resume is quiet: it is still today's workout, but it does not take over the day.
    Widget inProgress(Plan plan, Occasion occasion, Workout w) {
      final sets = SetProgress.of(w, ref.watch(trustedSetsProvider));
      final n = w.exercises.length;
      final parked = ref.watch(parkedIdsProvider).contains(w.id);
      void resume() => resumeWorkout(app, ref, w);
      return workout(
        status: parked ? (l.todayStatusSavedForLater, Icons.bookmark_outline, Tone.neutral) : _todayStatus(l, OccasionStatus.inProgress), name: w.title,
        // With a planned total the summary takes the full width and the ring sits beside the photograph.
        head: [if (sets.planned != null) line('${l.todayExerciseCount(n)} · ${l.todayPlannedSets(sets.planned!)}')],
        body: [
          if (sets.planned == null) line(n == 0 ? l.todayNoExercise : l.todayExerciseCount(n)),
          // Recorded is a count of sets, never a claim that a movement or the workout is complete.
          if (sets.planned != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                ProgressRing(
                  value: sets.fraction, size: MediaQuery.textScalerOf(context).scale(10) > 13 ? 104 : 76, stroke: 7, label: l.todaySetsRingLabel(sets.counted, sets.planned!),
                  center: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${sets.counted}', style: context.titleStyle(22)),
                    Text(l.todayOfSets(sets.planned!), style: context.sansStyle(12.5, color: c.secondary)),
                  ]),
                ),
                const SizedBox(width: 14),
                // Said by the ring already; drawn for the eye.
                Flexible(
                  child: ExcludeSemantics(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(formatPercent((sets.fraction * 100).round() / 100), style: context.numStyle(21, color: c.accent, weight: FontWeight.w700)),
                      FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(l.todayRecordedCaption, style: context.sansStyle(14, color: c.secondary))),
                    ]),
                  ),
                ),
              ]),
            )
          else if (sets.recorded > 0)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.todaySetsRecorded(sets.recorded), style: context.numStyle(16))),
        ],
        onDetails: () => ref.read(shellProvider.notifier).openWorkout(WorkoutFocus.session(w.id)),
        action: parked
            ? SecondaryButton(l.todayResumeWorkout, key: const Key('today-resume'), icon: Icons.play_arrow_rounded, expand: false, onPressed: resume)
            : PrimaryButton(l.todayResumeWorkout, key: const Key('today-resume'), icon: Icons.play_arrow_rounded, expand: false, onPressed: resume),
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
          ? l.todayRotationStep(rotation.position + 1, rotation.cycle.length)
          : occasion.sequenceIndex != null ? l.todaySessionNumber(occasion.sequenceIndex! + 1) : l.todayWeekNumber(occasion.weekNumber);
      void start() => startPlannedWorkout(app, ref, plan, occasion);
      return workout(
        // The exercise and set counts under the name, then where it is in the plan.
        status: _todayStatus(l, OccasionStatus.due), name: occasion.title,
        body: [
          line([l.todayExerciseCount(occasion.prescription.length), if (sets != 0) l.todayPlannedSets(sets)].join(' · ')),
          line([where, if (minutes != null) l.todayMinutesPlanned(minutes)].join(' · '), top: 2),
        ],
        onDetails: () => preview(plan, occasion),
        action: quietStart
            ? SecondaryButton(l.todayStartWorkout, key: const Key('today-start'), icon: Icons.play_arrow_rounded, expand: false, onPressed: start)
            : PrimaryButton(l.todayStartWorkout, key: const Key('today-start'), icon: Icons.play_arrow_rounded, expand: false, onPressed: start),
      );
    }

    /// One of today's planned occurrences already resolved: skipped, completed or partly completed. It stays
    /// today's, under its own name; the next workout is named beside it, never in its place.
    Widget resolved(Plan plan, Occasion o, OccasionStatus s, Occasion? next, bool blockDone) {
      final what = switch (s) {
        OccasionStatus.skipped => l.todayResolvedSkipped,
        OccasionStatus.finished => l.todayResolvedFinished,
        _ => l.todayResolvedPartial,
      };
      final undo = s == OccasionStatus.skipped && !o.isVirtual && PlanRepository.canUnskip(plan, o.id, all);
      return plain(
        status: _todayStatus(l, s), name: o.title,
        text: '$what ${blockDone ? l.todayBlockLast : nextText(plan, next)}',
        onDetails: () => preview(plan, o),
        quiet: undo
            ? TextButton(
                key: const Key('today-undo-skip'),
                onPressed: () => runPlanDecision(app, () => ref.read(planRepositoryProvider).unskip(plan, o.id, workouts: all), saved: l.todayUnskipSaved),
                child: Text(l.todayUndoSkip))
            : null,
        action: blockDone
            ? PrimaryButton(l.todayReviewBlock, key: const Key('today-block-review'), expand: false, onPressed: () => push(context, BlockReviewScreen(planId: plan.id)))
            // A rotation's next workout can be done now, as an explicit choice; skipping alone never puts it on today.
            : plan.isRotating && next != null && plan.isActive
                ? SecondaryButton(l.todayTrainNow, key: const Key('today-train-now'), icon: Icons.play_arrow_rounded, expand: false, onPressed: () => startPlannedWorkout(app, ref, plan, next))
                : SecondaryButton(l.todayViewPlan, expand: false, onPressed: openPlan),
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
                        subtitle: l.todayAlsoToday(_todayStatus(l, status[o.id]!).$1), onTap: () => preview(plan, o)),
                ]),
              if (missed.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(key: const Key('today-missed'), onPressed: openPlan,
                      child: Text(l.todayMissedUnresolved(missed.length))),
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
                status: (l.todayStatusRestDay, Icons.spa_outlined, Tone.neutral), name: l.todayRestDayTitle,
                text: [if (chosen) l.todayRestChosen, nextText(plan, next), if (missed.isNotEmpty) l.todayRestMissed(missed.length)].join(' '),
                action: missed.isEmpty
                    ? SecondaryButton(l.todayViewPlan, expand: false, onPressed: openPlan)
                    : SecondaryButton(l.todayResolveMissed, key: const Key('today-missed'), expand: false, onPressed: openPlan),
                quiet: chosen
                    ? TextButton(key: const Key('today-undo-rest'), onPressed: () => ref.read(planRepositoryProvider).setRestDay(plan, today, rest: false), child: Text(l.todayTrainToday))
                    : null,
              ),
        ),
      PlanPausedAction(:final plan) => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(status: (l.todayStatusPlanPaused, Icons.pause_circle_outline, Tone.neutral), name: plan.title, text: l.todayPausedText,
              action: PrimaryButton(l.todayResumePlan, expand: false, onPressed: () => push(context, ResumeReviewScreen(planId: plan.id)))),
        ),
      StartsLater(:final plan, :final first) => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(status: (l.todayStatusStarts(shortDate(plan.startDate)), Icons.event, Tone.neutral), name: first.title, text: l.todayStartsLaterText(longDate(first.scheduledDate)),
              action: SecondaryButton(l.todayViewPlan, expand: false, onPressed: openPlan)),
        ),
      BlockReviewDue(:final plan) => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(status: (l.todayStatusBlockReview, Icons.flag_outlined, Tone.accent), name: plan.title,
              text: l.todayBlockReviewText,
              action: PrimaryButton(l.todayReviewBlock, key: const Key('today-block-review'), expand: false, onPressed: () => push(context, BlockReviewScreen(planId: plan.id)))),
        ),
      ReviewDraft(:final draft) => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(status: (l.todayStatusDraftReview, Icons.fact_check_outlined, Tone.accent), name: draft.title, text: l.todayDraftText,
              action: PrimaryButton(l.todayReviewPlan, key: const Key('today-review-draft'), expand: false, onPressed: () => push(context, PlanReviewScreen(planId: draft.id)))),
        ),
      CreatePlan() => (
          snapshot.inProgress.isEmpty,
          const <Widget>[],
          () => plain(name: l.todayNoPlanTitle, text: l.todayNoPlanText,
              action: PrimaryButton(l.todayCreatePlan, key: const Key('today-create-plan'), expand: false, onPressed: () => push(context, const CreatePlanScreen()))),
        ),
    };
    extras = [
      ...own,
      if (offerManual) Align(alignment: AlignmentDirectional.centerStart, child: TextButton(key: const Key('today-manual'), onPressed: () => startManualWorkout(app, ref), child: Text(l.todayStartManual))),
      // Workouts saved for later stay recoverable without taking over the day.
      if (snapshot.parked.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: GroupCard(children: [
            for (final w in snapshot.parked)
              GroupRow(icon: Icons.bookmark_outline, tone: Tone.neutral, title: w.title, subtitle: l.todayParkedSubtitle(shortDate(w.dayKey)), onTap: () => resumeWorkout(app, ref, w)),
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
    final l = context.l10n;
    final what = w.isManual ? l.todayManualWorkout : l.todayPlannedWorkoutFrom(shortDate(w.dayKey));
    final app = appContext(context);
    return PanelSurface(
      key: Key('today-open-${w.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Semantics(header: true, child: Overline(what)),
            StatusPill(l.todayStatusInProgress, icon: Icons.timelapse, tone: Tone.accent),
          ]),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(w.title, style: context.pageTitleStyle(30))),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(n == 0 ? l.todayNoExercise : l.todayExerciseCount(n), style: context.sansStyle(15, color: context.c.secondary)),
          ),
          // No planned total exists for a manual workout, so there is a count and no percentage.
          if (sets.recorded > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.todaySetsRecorded(sets.recorded), style: context.numStyle(16))),
          const SizedBox(height: 14),
          PrimaryButton(l.todayResumeWorkout, key: const Key('today-resume'), icon: Icons.play_arrow_rounded, expand: false, onPressed: () => resumeWorkout(app, ref, w)),
        ]),
    );
  }
}

// ---------------------------------------------------------------------------- running

/// "5.20 km"


/// Today's one way into Run / Walk (docs/RUN_WALK.md), on every kind of day. An open activity is read from the
/// saved records, whatever day it began, and taken over by the one recorder, so it is resumed (never started twice)
/// also after the app was closed. Distance and time are the recorder's or the saved ones: there is no target and no
/// percentage. The photograph is decoration, not a map.
class _RunCard extends ConsumerStatefulWidget {
  const _RunCard({required this.today, required this.finishedToday, this.steps = false});
  final String today;
  final List<Run> finishedToday;

  /// The Steps tile sits beside this one; History then goes under the two.
  final bool steps;
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
    final rec = ref.watch(recorderProvider);
    // An open activity found at startup (after a restart, or from the build before routes) is taken over by the one
    // recorder, so it is resumed and never started twice.
    if (open != null && !rec.open) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? adoptOpenActivity(ref) : null);
    final owned = rec.run?.id == open?.id ? rec : null;
    final ticking = owned != null && owned.state == RecState.recording;
    if (ticking) {
      _minute ??= Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
    } else {
      _minute?.cancel();
      _minute = null;
    }

    final l = context.l10n;
    String time(int seconds) => seconds < 60 ? l.todayUnderOneMinute : durationText(seconds);
    final unit = ref.watch(devicePrefsProvider.select((p) => p.distance));
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 350;
    final pair = widget.steps && !stacked;
    // What the tile shows, from the real state: an open activity (the recorder's numbers), the last one finished today
    // (its saved numbers, as before), or nothing yet. Distance is the main figure when measured; time supports it.
    final List<Widget> body;
    final String action;
    // Styled inside the tile (under its PanelTheme), not by the page: a Builder takes the tile's colours.
    Widget figure(String text) => Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(text, key: const Key('today-run-figure'), style: context.pageTitleStyle(34))),
          ),
        );
    Widget support(String text) => Builder(builder: (context) => Text(text, style: context.sansStyle(16, color: context.c.secondary)));
    if (open != null) {
      final a = owned?.analysis;
      final now = ref.read(clockProvider).utcNow().millisecondsSinceEpoch;
      final kind = open.activityType == 'walk' ? 'walk' : 'run';
      final (String words, IconData icon, Tone tone) = switch (owned?.state) {
        RecState.paused || RecState.autoPaused => (l.todayActivityPaused(kind), Icons.pause_rounded, Tone.neutral),
        RecState.interrupted => (l.todayActivityInterrupted(kind), Icons.warning_amber_rounded, Tone.warning),
        RecState.review => (l.todayActivityNotSaved(kind), Icons.edit_note, Tone.neutral),
        _ => (l.todayActivityInProgress(kind), Icons.timelapse, Tone.neutral),
      };
      body = [
        _TileState(icon, words, tone: tone, sub: open.dayKey == widget.today ? null : l.todayStartedOn(shortDate(open.dayKey))),
        if (a != null && (a.measured || a.hasLegacy)) figure(unit.distance(a.distance + a.legacyDistance)),
        if (a != null) support(time(a.activeMs(now) ~/ 1000)) else if (open.dayKey == widget.today) Padding(padding: const EdgeInsets.only(top: 6), child: support(l.todayStartedToday)),
      ];
      action = l.todayRunResume;
    } else if (widget.finishedToday.isNotEmpty) {
      final last = widget.finishedToday.last;
      final t = last.movingSeconds ?? last.activeDurationSeconds;
      body = [
        _TileState(Icons.check_rounded, l.todayActivityCompleted(last.activityType == 'walk' ? 'walk' : 'run'), sub: l.todayCompletedWhen),
        if (last.distanceMeters != null) figure(unit.distance(last.distanceMeters)),
        if (t != null) Padding(padding: EdgeInsets.only(top: last.distanceMeters == null ? 8 : 0), child: support(time(t))),
      ];
      action = l.todayRunStartNew;
    } else {
      body = [support(l.todayNoRunWalk)];
      action = l.todayRunStart;
    }
    // Its one action: Start, Resume (the same activity) or Start new; the full history is in Train.
    final app = context;
    final tile = PanelTheme(
      child: Builder(
        builder: (context) => _HeaderTile(
          key: const Key('today-module-run'), label: l.todayRunWalkLabel, photoId: 'run', fill: pair,
          // The near shoe on the path, at the strip's trailing side.
          photo: _Photos.run, photoAlignment: const Alignment(1, 0.35),
          body: body,
          // Full tile width, as in the approved mockup, so "Start new" stays on one line.
          action: PrimaryButton(action, key: const Key('today-run'), leading: const GoIcon(GoGlyph.play, size: 18), onPressed: () => openRunWalk(app, ref)),
        ),
      ),
    );
    if (!widget.steps) return tile;
    // Side by side at ordinary sizes, the same width and height (the taller one's content sets it); one above the other
    // with large text or on a narrow phone, never clipped or shrunk to match.
    if (stacked) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile, const SizedBox(height: 10), const _StepsCard()]);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: tile), const SizedBox(width: 10), const Expanded(child: _StepsCard(fill: true))]),
    );
  }
}

/// Run / Walk and Steps on Today (the selected "option 2", docs/DESIGN.md › Today option 2): a short photographic header
/// strip with the section's label on its pale side, then the tile's figures on the calm panel tint, then one action at
/// the bottom. Two tiles side by side are made the same height ([fill]); the header has a fixed height and the content
/// grows, so large text is never clipped. Built under [PanelTheme], like the other Today panels.
class _HeaderTile extends StatelessWidget {
  const _HeaderTile({super.key, required this.label, required this.photoId, required this.photo, required this.photoAlignment, required this.body, this.action, this.fill = false});
  final String label, photo;

  /// Names the photograph's key (`today-photo-<photoId>`), never the displayed label.
  final String photoId;
  final Alignment photoAlignment;
  final List<Widget> body;
  final Widget? action;
  final bool fill;

  static const header = 78.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = BorderRadius.circular(Radii.panel);
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Container(
      decoration: BoxDecoration(color: c.page, borderRadius: radius, boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))]),
      foregroundDecoration: BoxDecoration(borderRadius: radius, border: Border.all(color: c.text.withValues(alpha: 0.08))),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min, children: [
          SizedBox(
            height: large ? header + 10 : header,
            child: Stack(fit: StackFit.expand, children: [
              // The photograph takes the strip's trailing side; the label's side is the panel tint, blending into it.
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerEnd, widthFactor: 0.72,
                child: PanelPhoto(photo, key: Key('today-photo-$photoId'), alignment: photoAlignment),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd, colors: [c.page, c.page, c.page.withValues(alpha: 0.55), c.page.withValues(alpha: 0)], stops: const [0, 0.28, 0.45, 0.7]),
                ),
              ),
              PositionedDirectional(start: 16, top: 14, end: 12, child: Semantics(header: true, child: Overline(label))),
            ]),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: body),
          ),
          if (fill) const Spacer(),
          if (action != null) Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: Align(alignment: AlignmentDirectional.centerStart, child: action)) else const SizedBox(height: 14),
        ]),
      ),
    );
  }
}

/// A compact state line in a tile: a small icon in a soft circle, the words, and an optional quieter second line.
class _TileState extends StatelessWidget {
  const _TileState(this.icon, this.text, {this.sub, this.tone = Tone.neutral});
  final IconData icon;
  final String text;
  final String? sub;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ink = tone == Tone.warning ? c.warning : c.text;
    return MergeSemantics(
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 26, height: 26, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.accentSoft),
          child: Icon(icon, size: 16, color: ink),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(text, style: context.sansStyle(14, weight: FontWeight.w600, color: ink)),
            if (sub != null) Text(sub!, style: context.sansStyle(14, color: c.secondary)),
          ]),
        ),
      ]),
    );
  }
}

/// Steps beside Run / Walk (docs/RUN_WALK.md › Steps › Where it is). Before steps are on it offers them ("Track your
/// steps", Enable); after, the day's real count, its source and when it was read, a goal bar only when a goal is set,
/// and a distinct line for loading, not allowed, unavailable, failed and no data. Tapping it opens the Steps sheet.
/// Opening Today asks the phone for nothing.
class _StepsCard extends ConsumerStatefulWidget {
  const _StepsCard({this.fill = false});
  final bool fill;
  @override
  ConsumerState<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends ConsumerState<_StepsCard> with WidgetsBindingObserver {
  /// Fresh while shown and on; nothing is read while it is not.
  Timer? _fresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _fresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && ref.read(stepsEnabledProvider)) ref.read(dailyStepsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(stepsEnabledProvider);
    if (on) {
      _fresh ??= Timer.periodic(const Duration(minutes: 5), (_) => ref.read(dailyStepsProvider.notifier).refresh());
    } else {
      _fresh?.cancel();
      _fresh = null;
    }
    final d = on ? ref.watch(dailyStepsProvider) : const DailyOff();
    final goal = ref.watch(stepGoalProvider);
    final src = ref.read(stepSourceProvider);
    final app = appContext(context);
    final l = context.l10n;
    // The read time in the phone's own clock format ("12:19 PM", "12:19"), kept on one line with its word.
    String at(DateTime t) => MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context)).replaceAll(' ', '\u00a0').replaceAll('\u202f', '\u00a0');
    Widget button(String label, Key key, VoidCallback onPressed) => PrimaryButton(label, key: key, expand: false, onPressed: onPressed);
    // The goal is set and changed in the Steps sheet; never set here, never a default.
    Widget goalLink() => QuietLink(goal == null ? l.todayStepsSetGoal : l.todayStepsEditGoal, key: const Key('today-steps-goal-link'),
        said: goal == null ? l.todayStepsSetGoalSaid : l.todayStepsEditGoalSaid, onPressed: () => showStepsSheet(app));
    // (headline, lines under it, action): the headline is a real count only when there is one.
    final (String head, List<String> lines, Widget? action) = switch (d) {
      DailyOff() => (l.todayStepsTrack, [l.todayStepsCountWithPhone], button(l.todayStepsEnable, const Key('today-steps-enable'), () => enableSteps(ref))),
      DailyLoading() => ('…', [l.todayStepsReading], null),
      DailyValue(:final steps, :final source, at: final t, :final recorded) => recorded
          ? (formatSteps(steps), [source, l.todayStepsUpdated(at(t))], goalLink())
          : ('—', [l.todayStepsNone, source], goalLink()),
      DailyNotAllowed(:final blocked) => ('—', [blocked ? l.todayStepsBlocked : l.todayStepsAllowHint],
          blocked ? button(l.todayStepsSettings, const Key('today-steps-settings'), () => src.openSettings()) : button(l.todayStepsAllow, const Key('today-steps-allow'), () => enableSteps(ref))),
      DailyUnavailable(:final why) => ('—', [why], null),
      DailyFailed() => ('—', [l.todayStepsFailed], button(l.actionTryAgain, const Key('today-steps-retry'), () => ref.read(dailyStepsProvider.notifier).refresh())),
    };
    final count = d is DailyValue && d.recorded;
    final progress = count && goal != null ? (d.steps / goal).clamp(0.0, 1.0) : null;
    final said = d is DailyOff ? l.todayStepsOffSaid : l.todayStepsSaid(head == '—' || head == '…' ? l.todayStepsNotKnown : head, lines.join('. '));
    final tile = PanelTheme(
      child: Builder(
        builder: (context) => _HeaderTile(
          key: const Key('today-steps'), label: l.todayStepsLabel, photoId: 'steps', fill: widget.fill,
          // The strip shows the nearest tread impressions (the right half of the photograph).
          photo: _Photos.steps, photoAlignment: const Alignment(0.8, 0.55),
          body: [
            GoIcon(GoGlyph.steps, size: 26, color: context.c.accent),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart,
                  child: Text(head, key: const Key('today-steps-value'), style: context.pageTitleStyle(d is DailyOff ? 24 : 34))),
            ),
            // The goal and its bar only when a goal is set; then where and when it was read, each on its own line.
            if (progress != null) ...[
              Text(l.todayStepsOfGoal(formatSteps(goal!)), key: const Key('today-steps-goal'), style: context.sansStyle(15, color: context.c.secondary)),
              Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: ProgressRail(progress, label: l.todayStepsGoalLabel)),
            ],
            for (final line in lines) Text(line, style: context.sansStyle(15, color: context.c.secondary)),
            if (src.simulated && on) Text(l.todayStepsSimulated, style: context.caption),
          ],
          action: action,
        ),
      ),
    );
    return Pressable(onTap: () => showStepsSheet(app), semanticLabel: l.todayStepsOpens(said), child: tile);
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
    final l = context.l10n;
    Widget line(String text) => Padding(padding: const EdgeInsets.only(top: 2), child: Text(text, style: context.sansStyle(15, color: context.c.secondary)));
    return _Module(
      key: const Key('today-module-nutrition'), label: l.todayNutritionLabel, photoId: 'nutrition',
      body: [
        if (failed)
          Padding(padding: const EdgeInsets.only(top: 6), child: StatusLine(Icons.error_outline, l.todayFoodError, tone: Tone.error))
        else if (s == null)
          line(l.todayLoading)
        else if (s.food.isEmpty) ...[
          // Nothing logged is not zero eaten: words, never "0 kcal".
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.todayNoFood, style: context.pageTitleStyle(28))),
          if (goals != null) line(l.todayDailyGoal(goals)),
        ] else
          Padding(padding: const EdgeInsets.only(top: 4), child: NutritionSummary(coverage: s.coverage, calorieGoal: profile?.calorieGoal, proteinGoal: profile?.proteinGoal)),
      ],
      // Any food without a value: said here in a line, explained in Eat.
      footer: logged ? NutritionMissingNote(coverage: s.coverage, onDetails: openEat) : null,
      // The bowl at the trailing side.
      photo: _Photos.nutrition, photoAlignment: const Alignment(0.7, 0),
      action: PrimaryButton(l.todayLogFood, key: const Key('log-food'), icon: Icons.restaurant, expand: false, onPressed: () => openFoodForm(appContext(context), dayKey: day)),
      quiet: QuietLink(l.todayJournal, key: const Key('today-open-eat'), said: l.todayJournalSaid, onPressed: openEat),
      // Under the figures, quieter than them: the day's water when it is tracked, then Customize tracking. Goals are
      // shown here as progress only; they are set and edited in Eat. Sheets open in the app's own look.
      // Today's water when it is tracked. Goals and Customize tracking belong to Eat.
      below: [if (display.water) WaterRow(key: const Key('today-water'), day: day)],
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
        Padding(padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8), child: Semantics(header: true, child: Overline(context.l10n.todayRecordedTodayOverline))),
        GroupCard(children: [
          for (final w in snapshot.recordedToday)
            GroupRow(
              icon: Icons.fitness_center, tone: Tone.neutral, title: w.title,
              subtitle: [w.isManual ? context.l10n.todayManualWorkout : context.l10n.todayPlannedWorkout, outcomeLabel(context.l10n, w.outcome),
                if (w.performedSets > 0) context.l10n.todaySetCount(w.performedSets)].join(' · '),
              onTap: () => push(context, WorkoutDetailScreen(workoutId: w.id)),
            ),
          if (finishedRuns.length > 1)
            for (final r in finishedRuns)
              GroupRow(
                icon: r.isWalk ? Icons.directions_walk : Icons.directions_run, tone: Tone.neutral, title: r.title ?? activityTitle(r.activityType),
                subtitle: '${durationText(r.movingSeconds ?? r.activeDurationSeconds ?? 0)}${r.distanceMeters == null ? '' : ' · ${ref.watch(devicePrefsProvider).distance.distance(r.distanceMeters)}'}',
                onTap: () => push(context, ActivityDetailScreen(runId: r.id)),
              ),
        ]),
      ]);
}
