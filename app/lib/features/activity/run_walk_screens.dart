import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/device_prefs.dart';
import '../../core/format.dart';
import '../../core/go_icon.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart' show LocalSaveFailure;
import '../coach/coach_avatar.dart' show CoachHelpButton;
import '../coach/coach_bubble.dart';
import '../coach/coach_prefs.dart';
import 'activity_detail.dart';
import 'activity_history.dart';
import 'announcer.dart' show announcerProvider;
import 'intervals.dart';
import 'steps_ui.dart';
import 'location_source.dart';
import 'move_prefs.dart';
import 'move_widgets.dart';
import 'recorder.dart';
import 'route_map.dart';
import 'steps.dart';

/// Run / Walk (docs/RUN_WALK.md), the approved "Focus Dial": Ready → Recording (Stats / Map) → Save review → Saved.
/// The same screens serve both activities; only the words change.
Future<void> openRunWalk(BuildContext context, WidgetRef ref) => push(context, const RunWalkScreen());

/// The English noun ("run", "walk"); test fixtures only. Shown words use [activityTitle] or a message taking the type.
String activityNoun(String type) => type == 'walk' ? 'walk' : 'run';

/// "Run", "Course", "جري": in the resolved app language.
String activityTitle(String type) => currentL10n.runActivityTitle(type);

/// What the recording screen says about a [RecIssue].
String recIssueText(AppLocalizations l, RecIssue i) => switch (i) { RecIssue.notSaving => l.runNotSaving, RecIssue.gpsStopped => l.runGpsStopped };

/// Adopts an open activity found on this phone (after a restart, or from the build before routes) so it is resumed,
/// never duplicated. Safe to call often.
void adoptOpenActivity(WidgetRef ref) {
  final rec = ref.read(recorderProvider);
  if (rec.open) return;
  final open = [for (final r in ref.read(runsProvider).value ?? const <Stored<Run>>[]) if (r.value.isOpen) r.value].firstOrNull;
  if (open != null) ref.read(recorderProvider.notifier).adopt(open).ignore();
}

class RunWalkScreen extends ConsumerStatefulWidget {
  const RunWalkScreen({super.key});
  @override
  ConsumerState<RunWalkScreen> createState() => _RunWalkScreenState();
}

class _RunWalkScreenState extends ConsumerState<RunWalkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) adoptOpenActivity(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(runsProvider, (_, _) => adoptOpenActivity(ref));
    final rec = ref.watch(recorderProvider);
    return switch (rec.state) {
      RecState.idle => const _Ready(key: Key('runwalk-ready')),
      RecState.review => const _Review(key: Key('runwalk-review')),
      _ => const _Recording(key: Key('runwalk-recording')),
    };
  }
}

// ---------------------------------------------------------------------------- Ready

class _Ready extends ConsumerStatefulWidget {
  const _Ready({super.key});
  @override
  ConsumerState<_Ready> createState() => _ReadyState();
}

class _ReadyState extends ConsumerState<_Ready> with WidgetsBindingObserver {
  GpsAccess? _access;
  Reading? _here;

  /// The same position for the expanded map, so it follows while it is open (one preview stream, never a second).
  final _position = ValueNotifier<Reading?>(null);
  StreamSubscription<Reading>? _preview;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preview?.cancel();
    _position.dispose();
    super.dispose();
  }

  /// Coming back from the system settings: read the real state again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  LocationSource get _source => ref.read(locationSourceProvider);

  Future<void> _refresh({bool ask = false}) async {
    final access = ask ? await _source.request() : await _source.access();
    if (!mounted) return;
    setState(() => _access = access);
    if (access == GpsAccess.allowed) {
      // Foreground only, while Ready is on screen: the dot and its accuracy. It stops when Ready closes or Start is pressed.
      _preview ??= _source.watch(recording: false).listen((r) {
        if (!mounted) return;
        setState(() => _here = r);
        _position.value = r;
      }, onError: (Object _) {});
    } else {
      await _preview?.cancel();
      _preview = null;
      _here = null;
    }
  }

  Future<void> _start(String type) async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      var access = _access;
      if (access != GpsAccess.allowed) {
        access = await _source.request();
        if (mounted) setState(() => _access = access);
      }
      var timerOnly = false;
      if (access != GpsAccess.allowed) {
        if (!mounted) return;
        final l = context.l10n;
        timerOnly = await confirm(context, title: l.runStartNoGpsTitle, body: l.runStartNoGpsBody, action: l.runStartNoGpsAction);
        if (!timerOnly) return;
      }
      // The preview stream ends first, so the recording stream is the only one (and runs as a foreground service).
      await _preview?.cancel();
      _preview = null;
      final move = ref.read(movePrefsProvider);
      await ref.read(recorderProvider.notifier).start(type, timerOnly: timerOnly, plan: move.intervals ? move.plan : null);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = context.l10n.runStartFailed(type));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(devicePrefsProvider);
    final move = ref.watch(movePrefsProvider);
    final intervals = move.intervals && move.plan != null;
    final type = prefs.activity;
    final coachOn = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    final here = _here;
    final l = context.l10n;
    final voiceValue = !move.voice
        ? l.runStateOff
        : switch (move.updates) {
            UpdateMode.off => l.runStateOn,
            UpdateMode.distance => l.runVoiceValueEvery(everyDistanceText(move.everyDistance, prefs.distance)),
            UpdateMode.time => l.runVoiceValueEvery(l.durationMinutes(move.everyMinutes)),
          };
    final media = MediaQuery.of(context);
    // The map takes what is left of a phone's real height (status bar, home indicator, app bar and the Start bar taken
    // off) once everything else on Ready is in view; a short phone or large text scrolls instead of shrinking controls.
    // ponytail: the rest of Ready's height is a measured constant (move_ui_test checks the fit with real insets), not a
    // layout pass; re-measure it when Ready's rows change.
    final usable = media.size.height - media.padding.top - media.padding.bottom - 48 - 76 - (_source.simulated ? 32 : 0);
    final mapHeight = (usable - (coachOn ? 500 : 460) * media.textScaler.scale(1).clamp(1.0, 1.3)).clamp(110.0, 320.0);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: Navigator.of(context).canPop()
            ? IconButton(key: const Key('runwalk-back'), tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.of(context).maybePop(),
                icon: directionalGlyph(context, GoIcon(GoGlyph.back, color: context.c.text)))
            : null,
        actions: [
          TextButton.icon(key: const Key('runwalk-history'), onPressed: () => push(context, const ActivityHistoryScreen()), icon: const GoIcon(GoGlyph.history, size: 22), label: Text(l.runHistory)),
          const SizedBox(width: 8),
        ],
      ),
      // Start is always the last thing and always reachable; nothing is set below it.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.inset, 8, context.inset, 10),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
            PrimaryButton(intervals ? l.runStartIntervalsButton(type) : l.runStartButton(type), key: const Key('runwalk-start'),
                leading: const GoIcon(GoGlyph.play, size: 20), busy: _starting, onPressed: () => _start(type)),
          ]),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 12), children: [
          // The title with the guide beside it, its bubble under the title (words only, so the setup stays in view).
          if (coachOn)
            Stack(children: [
              Heading(l.runTitle, size: 36, serif: true),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: TabCoach(
                  key: const Key('runwalk-coach'), id: 'runwalk', avatarLabel: l.runHelpAvatar,
                  say: CoachSay(intervals ? l.runCoachReadyIntervals : l.runCoachReady),
                  onAvatarTap: () => _help(context),
                ),
              ),
            ])
          else
            Heading(l.runTitle, size: 36, serif: true),
          const SizedBox(height: 10),
          Segmented<String>(
            keyPrefix: 'activity-type', values: const ['run', 'walk'], selected: type, label: activityTitle,
            onChanged: (t) => ref.read(devicePrefsProvider.notifier).setActivity(t),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: mapHeight,
            child: RouteMap(
              key: const Key('runwalk-ready-map'), segments: const [], controls: true, zoomButtons: true,
              here: here == null ? null : (lat: here.lat, lon: here.lon, acc: here.acc), live: true,
              onExpand: () => push(context, _ReadyMap(position: _position)),
              semanticLabel: here == null ? l.runMapNoPosition : l.runMapHere,
            ),
          ),
          const SizedBox(height: 8),
          _GpsCard(access: _access, here: here, onAction: _gpsAction),
          if (_source.simulated) Padding(padding: const EdgeInsets.only(top: 6), child: StatusLine(Icons.science_outlined, l.runSimulatedGps, tone: Tone.warning)),
          const SizedBox(height: 10),
          SetupGroup(key: const Key('runwalk-setup'), title: l.runSetupTitle, children: [
            SetupRow(key: const Key('runwalk-intervals'), glyph: GoGlyph.intervals, label: l.runSetupIntervals, value: intervals ? planShort(move.plan!) : l.runStateOff, onTap: () => showIntervalSetup(context)),
            SetupRow(key: const Key('runwalk-voice'), glyph: GoGlyph.voice, label: l.runSetupVoice, value: voiceValue, divider: true, onTap: () => showVoiceSheet(context)),
            SetupRow(
              key: const Key('runwalk-autopause'), glyph: GoGlyph.autoPause, label: l.runSetupAutoPause, divider: true,
              value: intervals ? l.runAutoPauseNotWithIntervals : prefs.autoPause ? l.runStateOn : l.runStateOff, onTap: () => _autoPause(context),
            ),
          ]),
          const SizedBox(height: 10),
          const StepsSetupRow(),
        ]),
      ),
    );
  }

  /// Auto-pause's own sheet: the switch and what it does. While intervals are set it is not used, and the choice for
  /// free runs and walks is kept as it is.
  void _autoPause(BuildContext context) => showGoSheet<void>(context, title: context.l10n.runSetupAutoPause, builder: (_) => Consumer(
        builder: (context, ref, _) {
          final on = ref.watch(devicePrefsProvider.select((p) => p.autoPause));
          final intervals = ref.watch(movePrefsProvider.select((m) => m.intervals && m.plan != null));
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(
              key: const Key('autopause-switch'), contentPadding: EdgeInsets.zero, value: on,
              title: Text(context.l10n.runSetupAutoPause, style: context.sansStyle(16, weight: FontWeight.w600)),
              subtitle: Text(context.l10n.runAutoPauseSubtitle, style: context.caption),
              onChanged: (v) => ref.read(devicePrefsProvider.notifier).setAutoPause(v),
            ),
            if (intervals)
              StatusLine(Icons.info_outline, context.l10n.runAutoPauseIntervalsNote),
          ]);
        },
      ));

  Future<void> _gpsAction() async {
    switch (_access) {
      case GpsAccess.servicesOff:
        await _source.openSettings(app: false);
      case GpsAccess.deniedForever:
        await _source.openSettings(app: true);
      case GpsAccess.notAllowed || GpsAccess.approximate:
        await _refresh(ask: true);
        if (_access == GpsAccess.approximate) await _source.openSettings(app: true);
      default:
        await _refresh();
    }
  }
}

void _help(BuildContext context) => showCoachHelpSheet(context, title: context.l10n.runTitle, say: CoachSay(context.l10n.runHelpBody));

/// "Run 1 min · Walk 90 s · × 8": the setup row's summary.
String planShort(IntervalPlan p) {
  final l = currentL10n;
  String d(int s) => s % 60 == 0 ? l.durationMinutes(s ~/ 60) : s < 120 ? l.durationSeconds(s) : phaseClock(s);
  return l.runPlanShort(d(p.run), d(p.walk), p.reps);
}

/// Ready's map, larger, with the same position: Expand map. Opening it starts nothing.
class _ReadyMap extends StatelessWidget {
  const _ReadyMap({required this.position});
  final ValueListenable<Reading?> position;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.runMapTitle)),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 12),
            child: ValueListenableBuilder<Reading?>(
              valueListenable: position,
              builder: (context, here, _) => RouteMap(
                key: const Key('runwalk-ready-map-full'), segments: const [], controls: true, zoomButtons: true, live: true,
                here: here == null ? null : (lat: here.lat, lon: here.lon, acc: here.acc),
                semanticLabel: here == null ? context.l10n.runMapNoPosition : context.l10n.runMapHere,
              ),
            ),
          ),
        ),
      );
}

class _GpsCard extends StatelessWidget {
  const _GpsCard({required this.access, required this.here, required this.onAction});
  final GpsAccess? access;
  final Reading? here;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final acc = here?.acc;
    final l = context.l10n;
    final accText = acc == null ? '' : accuracyText(acc);
    final (IconData icon, String title, String detail, String? action, Tone tone) = switch (access) {
      null => (Icons.location_searching, l.runGpsChecking, l.runGpsCheckingDetail, null, Tone.neutral),
      GpsAccess.servicesOff => (Icons.location_disabled, l.runGpsOff, l.runGpsOffDetail, l.runGpsOpenSettings, Tone.warning),
      GpsAccess.notAllowed => (Icons.location_off_outlined, l.runGpsNotAllowed, l.runGpsNotAllowedDetail, l.runGpsAllow, Tone.warning),
      GpsAccess.deniedForever => (Icons.location_off_outlined, l.runGpsBlocked, l.runGpsBlockedDetail, l.runGpsOpenAppSettings, Tone.warning),
      GpsAccess.approximate => (Icons.location_searching, l.runGpsApproximate, l.runGpsApproximateDetail, l.runGpsAllowPrecise, Tone.warning),
      GpsAccess.unavailable => (Icons.location_disabled, l.runGpsUnavailable, l.runGpsUnavailableDetail, null, Tone.warning),
      GpsAccess.allowed when acc == null => (Icons.location_searching, l.runGpsWaiting, l.runGpsWaitingDetail, null, Tone.neutral),
      GpsAccess.allowed => (Icons.location_on, acc! <= 25 ? l.runGpsReady : l.runGpsWeak,
          l.runGpsAccuracyDetail(acc <= 10 ? l.runGpsSignalGood : acc <= 25 ? l.runGpsSignalFair : l.runGpsSignalWeak, accText), null, acc <= 25 ? Tone.success : Tone.warning),
    };
    // One compact line ("GPS ready · ±5 m"), the reason under it only when something is needed.
    final ready = access == GpsAccess.allowed && acc != null;
    final card = Container(
      key: const Key('runwalk-gps'),
      constraints: const BoxConstraints(minHeight: Targets.minimum),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(Radii.tile), border: Border.all(color: context.c.divider)),
      child: Row(children: [
        Icon(icon, color: tone == Tone.success ? context.c.accent : tone == Tone.warning ? context.c.warning : context.c.secondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(ready ? '$title · $accText' : title, style: context.sansStyle(16, weight: FontWeight.w600)),
            if (!ready) Text(detail, style: context.caption),
          ]),
        ),
        if (action != null) ...[const SizedBox(width: 8), directionalGlyph(context, GoIcon(GoGlyph.chevronRight, size: 20, color: context.c.secondary))],
      ]),
    );
    return action == null
        ? Semantics(container: true, child: card)
        : Pressable(onTap: onAction, semanticLabel: '$title. $detail. $action', child: card);
  }
}

/// "±5 m": a GPS reading's accuracy, kept in its Latin order inside Arabic.
String accuracyText(double acc) => withUnit(ltr('±${acc.round()}'), currentL10n.unitMetre);

// ---------------------------------------------------------------------------- Recording

class _Recording extends ConsumerStatefulWidget {
  const _Recording({super.key});
  @override
  ConsumerState<_Recording> createState() => _RecordingState();
}

class _RecordingState extends ConsumerState<_Recording> {
  Timer? _tick;
  bool _mapView = false, _acting = false;

  @override
  void initState() {
    super.initState();
    // Redraws the clock only; time itself comes from the stored events.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() f) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = ref.watch(recorderProvider);
    final run = rec.run, a = rec.analysis;
    if (run == null || a == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final unit = ref.watch(devicePrefsProvider.select((p) => p.distance));
    final now = ref.read(clockProvider).utcNow().millisecondsSinceEpoch;
    final active = a.activeMs(now) ~/ 1000;
    final distance = a.measured || a.hasLegacy ? a.distance + a.legacyDistance : null;
    final pace = a.avgMovingPace(unit.meters);
    final here = rec.last == null ? null : (lat: rec.last!.lat, lon: rec.last!.lon, acc: rec.last!.acc);
    final paused = rec.state == RecState.paused || rec.state == RecState.autoPaused;
    final interrupted = rec.state == RecState.interrupted;
    final type = run.activityType;
    final l = context.l10n;
    final steps = rec.stepsState == 'measured' || rec.stepsState == 'partial' ? rec.steps?.steps : null;
    final phases = rec.plan != null && !rec.free;
    final voice = ref.watch(movePrefsProvider.select((p) => p.voice));

    final status = switch (rec.state) {
      RecState.paused => StatusPill(l.runStatusPaused, icon: Icons.pause_circle_outline, tone: Tone.accent),
      RecState.autoPaused => StatusPill(l.runStatusAutoPaused, icon: Icons.pause_circle_outline, tone: Tone.accent),
      RecState.interrupted => StatusPill(l.runStatusInterrupted, icon: Icons.warning_amber_rounded, tone: Tone.warning),
      _ => null,
    };
    final map = RouteMap(
      key: Key(_mapView ? 'runwalk-map-full' : 'runwalk-map-preview'), segments: a.segments, here: here, live: true, controls: true, zoomButtons: _mapView,
      onExpand: _mapView ? null : () => setState(() => _mapView = true),
      semanticLabel: distance == null ? l.runMapRouteSoFar : l.runMapRouteSoFarDistance(unit.distance(distance)),
    );
    final gps = _GpsChip(rec: rec);

    // Twice the text or a narrow phone: the two buttons one above the other, so their words never break.
    final stack = MediaQuery.textScalerOf(context).scale(10) > 15 || MediaQuery.sizeOf(context).width < 340;
    final controls = interrupted
        ? Row(children: [
            Expanded(child: SecondaryButton(l.runFinish, key: const Key('runwalk-finish'), icon: Icons.stop_rounded, onPressed: _acting ? null : () => _act(ref.read(recorderProvider.notifier).finish))),
            const SizedBox(width: 12),
            Expanded(child: PrimaryButton(l.runResume, key: const Key('runwalk-resume'), icon: Icons.play_arrow_rounded, onPressed: _acting ? null : () => _act(ref.read(recorderProvider.notifier).resume))),
          ])
        : Flex(direction: stack ? Axis.vertical : Axis.horizontal, mainAxisSize: MainAxisSize.min, crossAxisAlignment: stack ? CrossAxisAlignment.stretch : CrossAxisAlignment.center, children: [
            _Slot(
              stack: stack,
              child: SecondaryButton(paused ? l.runResume : l.runPause, key: Key(paused ? 'runwalk-resume' : 'runwalk-pause'), icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  onPressed: _acting ? null : () => _act(paused ? ref.read(recorderProvider.notifier).resume : ref.read(recorderProvider.notifier).pause)),
            ),
            const SizedBox(width: 12, height: 8),
            _Slot(stack: stack, child: PrimaryButton(l.runFinish, key: const Key('runwalk-finish'), icon: Icons.stop_rounded, onPressed: _acting ? null : () => _act(ref.read(recorderProvider.notifier).finish))),
          ]);

    final notes = <Widget>[
      if (interrupted)
        StatusLine(Icons.warning_amber_rounded,
            a.hasLegacy && a.interruptions == 0 ? l.runInterruptedLegacy(type) : l.runInterrupted,
            tone: Tone.warning),
      if (rec.problem != null) StatusLine(Icons.error_outline, recIssueText(l, rec.problem!), tone: Tone.error),
      if (rec.gpsError != null) StatusLine(Icons.gps_off, recIssueText(l, rec.gpsError!), tone: Tone.warning),
      if (rec.timerOnly) StatusLine(Icons.timer_outlined, l.runTimerOnlyNote),
      if (ref.read(locationSourceProvider).simulated) StatusLine(Icons.science_outlined, l.runSimulatedGps, tone: Tone.warning),
    ];

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          key: const Key('runwalk-voice-toggle'), tooltip: voice ? l.runVoiceToggleOn : l.runVoiceToggleOff,
          icon: Icon(voice ? Icons.volume_up_outlined : Icons.volume_off_outlined),
          onPressed: () {
            if (voice) ref.read(announcerProvider.notifier).cancel();
            ref.read(movePrefsProvider.notifier).update((p) => p.copy(voice: !voice));
          },
        ),
        CoachHelpButton(key: const Key('coach-help-run'), semanticLabel: l.runHelpRecording(type), onPressed: () => _help(context)),
        const SizedBox(width: 8),
      ]),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.inset),
            child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Heading(activityTitle(run.activityType), size: 36, serif: true),
              ?status,
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.inset),
            child: Segmented<bool>(keyPrefix: 'runwalk-view', values: const [true, false], selected: _mapView, label: (m) => m ? l.runMapTitle : l.runViewStats, onChanged: (m) => setState(() => _mapView = m)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _mapView
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.inset),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _CompactStats(active: active, distance: distance, pace: pace, unit: unit, steps: steps),
                      if (phases) ...[const SizedBox(height: 8), IntervalBar(rec: rec, nowMs: now, compact: true)],
                      const CoachLine(),
                      const SizedBox(height: 10),
                      Expanded(child: Stack(children: [Positioned.fill(child: map), Positioned(left: 10, top: 10, child: gps)])),
                      for (final n in notes) Padding(padding: const EdgeInsets.only(top: 8), child: n),
                    ]),
                  )
                : LayoutBuilder(
                    builder: (context, box) => ListView(padding: EdgeInsets.symmetric(horizontal: context.inset), children: [
                      Center(child: _Dial(seconds: active, size: (box.maxWidth * (phases ? 0.52 : 0.62)).clamp(160.0, 300.0).toDouble(), paused: paused || interrupted)),
                      if (phases) ...[const SizedBox(height: 12), IntervalBar(rec: rec, nowMs: now)],
                      const CoachLine(),
                      const SizedBox(height: 16),
                      _Figures(
                        distance: distance, pace: pace, unit: unit,
                        steps: rec.stepsState == 'off'
                            ? null
                            : StatFigure(steps == null ? '—' : formatSteps(steps), null, rec.stepsState == 'partial' ? l.runStepsPartly : steps == null ? l.runStepsNotCounted : l.runSteps,
                                key: const Key('runwalk-steps'), size: 26),
                      ),
                      const SizedBox(height: 14),
                      for (final n in notes) Padding(padding: const EdgeInsets.only(bottom: 8), child: n),
                      SizedBox(
                        height: (box.maxHeight * 0.42).clamp(200.0, 360.0).toDouble(),
                        child: Stack(children: [Positioned.fill(child: map), Positioned(left: 10, top: 10, child: gps)]),
                      ),
                    ]),
                  ),
          ),
          Padding(padding: EdgeInsets.fromLTRB(context.inset, 12, context.inset, 12), child: controls),
        ]),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.stack, required this.child});
  final bool stack;
  final Widget child;
  @override
  Widget build(BuildContext context) => stack ? child : Expanded(child: child);
}

/// The approved pale dial: active time in the serif, clearly labelled. The rim is a frame, not progress.
class _Dial extends StatelessWidget {
  const _Dial({required this.seconds, required this.size, required this.paused});
  final int seconds;
  final double size;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final panel = GoColors.panelOf(context.c);
    return Semantics(
      key: const Key('runwalk-dial'),
      label: paused ? context.l10n.runActiveTimePausedSaid(durationText(seconds)) : context.l10n.runActiveTimeSaid(durationText(seconds)),
      child: ExcludeSemantics(
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: panel.page, border: Border.all(color: panel.accentSoft, width: size * 0.035)),
          padding: EdgeInsets.all(size * 0.12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(clockText(seconds), style: context.pageTitleStyle(size * 0.27, color: panel.text))),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(context.l10n.runActiveTime, style: context.sansStyle(16, color: panel.secondary))),
          ]),
        ),
      ),
    );
  }
}

/// A big figure in the serif with its unit and a label under it ("2.40 km / Distance").
class StatFigure extends StatelessWidget {
  const StatFigure(this.value, this.unit, this.label, {super.key, this.size = 34, this.said});
  final String value, label;
  final String? unit, said;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: said ?? (value == '—' ? context.l10n.runFigureSaidUnknown(label) : context.l10n.runFigureSaid(label, '$value ${unit ?? ''}')),
        child: ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: value, style: context.pageTitleStyle(size)),
                if (unit != null && value != '—') TextSpan(text: ' $unit', style: context.sansStyle(size * 0.5, weight: FontWeight.w600)),
              ])),
            ),
            Text(label, style: context.sansStyle(15, color: context.c.secondary)),
          ]),
        ),
      );
}

String _paceUnit(DistanceUnit u) => '/${u.label}';

class _Figures extends StatelessWidget {
  const _Figures({required this.distance, required this.pace, required this.unit, this.steps});
  final double? distance, pace;
  final DistanceUnit unit;

  /// Steps, in the same row when they are counted (smaller: distance and pace lead).
  final Widget? steps;

  @override
  Widget build(BuildContext context) {
    final d = StatFigure(distance == null ? '—' : unit.number(distance!), unit.label, context.l10n.runDistance, key: const Key('runwalk-distance'));
    final p = StatFigure(unit.paceNumber(pace), _paceUnit(unit), context.l10n.runAvgMovingPace, key: const Key('runwalk-pace'));
    if (MediaQuery.textScalerOf(context).scale(10) > 13 || MediaQuery.sizeOf(context).width < 340) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [d, const SizedBox(height: 10), p, if (steps != null) ...[const SizedBox(height: 10), steps!]]);
    }
    return IntrinsicHeight(
      child: Row(children: [
        Expanded(flex: 4, child: d),
        VerticalDivider(color: context.c.divider, width: 20),
        Expanded(flex: 4, child: p),
        if (steps != null) ...[VerticalDivider(color: context.c.divider, width: 20), Expanded(flex: 3, child: steps!)],
      ]),
    );
  }
}

class _CompactStats extends StatelessWidget {
  const _CompactStats({required this.active, required this.distance, required this.pace, required this.unit, this.steps});
  final int? steps;
  final int active;
  final double? distance, pace;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('runwalk-compact-stats'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: GoColors.panelOf(context.c).page, borderRadius: BorderRadius.circular(Radii.tile)),
        child: PanelTheme(
          child: Builder(
            builder: (context) => Wrap(spacing: 18, runSpacing: 6, children: [
              StatFigure(clockText(active), null, context.l10n.runActiveTime, size: 24, said: context.l10n.runActiveTimeSaid(durationText(active))),
              StatFigure(distance == null ? '—' : unit.number(distance!), unit.label, context.l10n.runDistance, size: 24),
              StatFigure(unit.paceNumber(pace), _paceUnit(unit), context.l10n.runAvgMovingPace, size: 24),
              if (steps != null) StatFigure(formatSteps(steps!), null, context.l10n.runSteps, size: 24),
            ]),
          ),
        ),
      );
}

class _GpsChip extends StatelessWidget {
  const _GpsChip({required this.rec});
  final RecorderView rec;

  @override
  Widget build(BuildContext context) {
    final acc = rec.last?.acc;
    final l = context.l10n;
    final (Color dot, String text) = rec.timerOnly
        ? (context.c.secondary, l.runChipTimerOnly)
        : !rec.gpsOn
            ? (context.c.secondary, l.runChipGpsOff)
            : rec.gpsError != null
                ? (context.c.warning, l.runChipGpsLost)
                : acc == null
                    ? (context.c.warning, l.runChipWaiting)
                    : (acc <= 25 ? const Color(0xFF3CC46B) : context.c.warning, l.runChipGps(accuracyText(acc)));
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: context.c.surface.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(text, style: context.sansStyle(13.5, weight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------- Save review

/// "Morning walk": from the local start time.
String defaultTitle(String type, DateTime startLocal) {
  final h = startLocal.hour, l = currentL10n;
  return h >= 5 && h < 12 ? l.runTitleMorning(type) : h >= 12 && h < 17 ? l.runTitleAfternoon(type) : h >= 17 && h < 21 ? l.runTitleEvening(type) : l.runTitleNight(type);
}

class _Review extends ConsumerStatefulWidget {
  const _Review({super.key});
  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  late final TextEditingController _title, _notes = TextEditingController(), _distance = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final run = ref.read(recorderProvider).run!;
    _title = TextEditingController(text: defaultTitle(run.activityType, DateTime.parse(run.startedAtUtc).toLocal()));
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _distance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final unit = ref.read(devicePrefsProvider).distance;
    final l = context.l10n;
    final typed = parseNonNegative(_distance.text);
    if (_distance.text.trim().isNotEmpty && (typed == null || typed > 1000)) return setState(() => _error = l.runDistanceInvalid);
    final title = _title.text.trim();
    if (title.isEmpty || title.length > 80) return setState(() => _error = l.runTitleInvalid);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref.read(recorderProvider.notifier).save(title: title, notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(), typedMeters: typed == null ? null : typed * unit.meters);
      if (mounted) await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => ActivityDetailScreen(runId: id, justSaved: true)));
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = context.l10n.runSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard(String type) async {
    final l = context.l10n;
    if (!await confirm(context, title: l.runDiscardTitle(type), body: l.runDiscardBody(type), action: l.runDiscardButton(type), destructive: true)) {
      return;
    }
    await ref.read(recorderProvider.notifier).discard();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final rec = ref.watch(recorderProvider);
    final run = rec.run, a = rec.analysis;
    if (run == null || a == null) return const Scaffold(body: SizedBox.shrink());
    final unit = ref.watch(devicePrefsProvider.select((p) => p.distance));
    final now = ref.read(clockProvider).utcNow().millisecondsSinceEpoch;
    final s = ActivitySummary.of(a, now);
    final gps = s.metrics['gpsDistanceMeters'] as double?;
    final type = run.activityType;
    final l = context.l10n;
    return AppPage(
      title: l.runSaveTitle(type), subtitle: '${longDate(run.dayKey)} · ${activityTitle(type)}',
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        PrimaryButton(l.runSaveButton(type), key: const Key('runwalk-save'), icon: Icons.check, busy: _saving, onPressed: _save),
      ]),
      children: [
        if (a.measured)
          SizedBox(height: 220, child: RouteMap(key: const Key('runwalk-review-map'), segments: a.segments, controls: true, semanticLabel: l.runRecordedRoute))
        else
          StatusLine(Icons.timer_outlined, rec.timerOnly || !a.hasLegacy ? l.runNoRouteFor(type) : l.runRouteNotRecordedLine),
        const SizedBox(height: 16),
        Wrap(spacing: 22, runSpacing: 12, children: [
          StatFigure(gps == null ? '—' : unit.number(gps), unit.label, gps == null ? l.runDistanceNotMeasured : l.runDistance),
          StatFigure(clockText(s.metrics['movingSeconds'] as int), null, l.runMovingTime, said: l.runMovingTimeSaid(durationText(s.metrics['movingSeconds'] as int))),
          StatFigure(clockText(s.activeSeconds), null, l.runActiveTime, said: l.runActiveTimeSaid(durationText(s.activeSeconds))),
          StatFigure(unit.paceNumber(a.avgMovingPace(unit.meters)), _paceUnit(unit), l.runAvgMovingPace),
          if (rec.stepsState != 'off') StatFigure(rec.steps == null ? '—' : formatSteps(rec.steps!.steps), null, rec.stepsState == 'partial' ? l.runStepsPartOfTime : rec.steps == null ? l.runStepsNotCounted : l.runSteps),
        ]),
        const SizedBox(height: 18),
        TextField(key: const Key('runwalk-title'), controller: _title, maxLength: 80, decoration: InputDecoration(labelText: l.runTitleField)),
        const SizedBox(height: 8),
        TextField(key: const Key('runwalk-notes'), controller: _notes, maxLength: 1000, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: l.runNotesOptional)),
        const SizedBox(height: 8),
        TextField(
          key: const Key('runwalk-distance-input'), controller: _distance, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: gps == null ? l.runDistanceOptional : l.runCorrectDistance, suffixText: unit.label,
            helperText: gps == null ? l.runDistanceTypedHelper : l.runDistanceGpsKeptHelper,
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        SecondaryButton(l.runResumeRecording, key: const Key('runwalk-review-resume'), icon: Icons.play_arrow_rounded, onPressed: _saving ? null : () => ref.read(recorderProvider.notifier).reopen()),
        const SizedBox(height: 4),
        Center(child: TextButton(key: const Key('runwalk-discard'), onPressed: _saving ? null : () => _discard(type), child: Text(l.runDiscardButton(type)))),
      ],
    );
  }
}
