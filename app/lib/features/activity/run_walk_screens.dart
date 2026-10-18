import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/device_prefs.dart';
import '../../core/format.dart';
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
import 'location_source.dart';
import 'move_prefs.dart';
import 'move_widgets.dart';
import 'recorder.dart';
import 'route_map.dart';
import 'steps.dart';

/// Run / Walk (docs/RUN_WALK.md), the approved "Focus Dial": Ready → Recording (Stats / Map) → Save review → Saved.
/// The same screens serve both activities; only the words change.
Future<void> openRunWalk(BuildContext context, WidgetRef ref) => push(context, const RunWalkScreen());

String activityNoun(String type) => type == 'walk' ? 'walk' : 'run';
String activityTitle(String type) => type == 'walk' ? 'Walk' : 'Run';

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
        if (mounted) setState(() => _here = r);
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
        timerOnly = await confirm(context, title: 'Start without GPS?',
            body: 'The time is recorded, and you can type a distance when you finish. No route or GPS distance is recorded.', action: 'Start timer only');
        if (!timerOnly) return;
      }
      // The preview stream ends first, so the recording stream is the only one (and runs as a foreground service).
      await _preview?.cancel();
      _preview = null;
      final move = ref.read(movePrefsProvider);
      await ref.read(recorderProvider.notifier).start(type, timerOnly: timerOnly, plan: move.intervals ? move.plan : null);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = 'The ${activityNoun(type)} could not be started on this phone. Nothing was recorded.');
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
    return Scaffold(
      appBar: AppBar(actions: [
        TextButton.icon(key: const Key('runwalk-history'), onPressed: () => push(context, const ActivityHistoryScreen()), icon: const Icon(Icons.history), label: const Text('History')),
        const SizedBox(width: 8),
      ]),
      body: SafeArea(
        child: ListView(padding: EdgeInsets.fromLTRB(context.inset, 0, context.inset, 24), children: [
          Heading('Run / Walk', size: 36, serif: true),
          if (coachOn) ...[
            const SizedBox(height: 8),
            TabCoach(
              key: const Key('runwalk-coach'), id: 'runwalk', avatarLabel: 'Help with Run / Walk',
              say: intervals
                  ? const CoachSay('Intervals are set. Start when you\'re ready.')
                  // Words only, so Start stays in view; Intervals is the row under Start.
                  : const CoachSay('Want to alternate running and walking? Set up intervals below Start.'),
              onAvatarTap: () => _help(context),
            ),
          ],
          const SizedBox(height: 16),
          Segmented<String>(
            keyPrefix: 'activity-type', values: const ['run', 'walk'], selected: type, label: activityTitle,
            onChanged: (t) => ref.read(devicePrefsProvider.notifier).setActivity(t),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.4).clamp(220.0, 420.0),
            child: RouteMap(
              key: const Key('runwalk-ready-map'), segments: const [], controls: true,
              here: here == null ? null : (lat: here.lat, lon: here.lon, acc: here.acc), live: true,
              semanticLabel: here == null ? 'Map, no position yet' : 'Map showing your current position',
            ),
          ),
          const SizedBox(height: 12),
          _GpsCard(access: _access, here: here, onAction: _gpsAction),
          const SizedBox(height: 14),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
          PrimaryButton(intervals ? 'Start ${activityNoun(type)} intervals' : 'Start ${activityNoun(type)}', key: const Key('runwalk-start'), icon: Icons.play_arrow_rounded, busy: _starting, onPressed: () => _start(type)),
          const SizedBox(height: 10),
          Rule(),
          ListTile(
            key: const Key('runwalk-intervals'), contentPadding: EdgeInsets.zero, leading: const Icon(Icons.repeat_rounded),
            title: Text(intervals ? 'Intervals on' : 'Intervals off'),
            subtitle: Text(intervals ? '${planSummary(move.plan!)} · ${clockText(move.plan!.totalSeconds)}' : 'Alternate running and walking, in one activity.', style: context.caption),
            trailing: const Icon(Icons.chevron_right), onTap: () => showIntervalSetup(context),
          ),
          ListTile(
            key: const Key('runwalk-voice'), contentPadding: EdgeInsets.zero, leading: Icon(move.voice ? Icons.volume_up_outlined : Icons.volume_off_outlined),
            title: const Text('Voice and alerts'), subtitle: Text(voiceSummary(move, prefs.distance), style: context.caption),
            trailing: const Icon(Icons.chevron_right), onTap: () => showVoiceSheet(context),
          ),
          SwitchListTile(
            key: const Key('runwalk-autopause'), contentPadding: EdgeInsets.zero, value: prefs.autoPause && !intervals,
            secondary: const Icon(Icons.settings_outlined),
            title: Text('Auto-pause ${prefs.autoPause && !intervals ? 'On' : 'Off'}'),
            subtitle: Text(intervals ? 'Off for intervals: walking to recover is not a pause. Your choice for other runs and walks is kept.' : 'Pauses when you stop for a while and resumes when you move on.',
                style: context.caption),
            onChanged: intervals ? null : (on) => ref.read(devicePrefsProvider.notifier).setAutoPause(on),
          ),
          if (ref.watch(stepsEnabledProvider)) const _StepsNote(),
          if (_source.simulated) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.science_outlined, 'Simulated GPS (test build)', tone: Tone.warning)),
        ]),
      ),
    );
  }

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

void _help(BuildContext context) => showCoachHelpSheet(context, title: 'Run / Walk', say: const CoachSay(
    'Choose Run or Walk, then Start. GoHard records your route while the screen is locked or another app is open, '
    'and saves it on this phone first. Pause any time; Finish lets you review before saving. Intervals alternate running '
    'and walking in one activity; with Voice and alerts on, I say each change aloud.'));

/// On Ready, only when steps are on but cannot be counted: why, and the way to fix it.
class _StepsNote extends ConsumerStatefulWidget {
  const _StepsNote();
  @override
  ConsumerState<_StepsNote> createState() => _StepsNoteState();
}

class _StepsNoteState extends ConsumerState<_StepsNote> {
  late Future<StepAccess> _access = ref.read(stepSourceProvider).access();

  @override
  Widget build(BuildContext context) => FutureBuilder<StepAccess>(
        future: _access,
        builder: (context, snap) => switch (snap.data) {
          StepAccess.notAllowed => Pressable(
              onTap: () async {
                await ref.read(stepSourceProvider).request();
                setState(() => _access = ref.read(stepSourceProvider).access());
              },
              semanticLabel: 'Steps are not counted yet. Allow motion access.',
              child: const StatusLine(Icons.directions_walk, 'Steps are not counted yet. Tap to allow motion access.', tone: Tone.warning),
            ),
          StepAccess.blocked => Pressable(
              onTap: () => ref.read(stepSourceProvider).openSettings(),
              semanticLabel: 'Steps are not counted: motion access is off. Open Settings.',
              child: const StatusLine(Icons.directions_walk, 'Steps are not counted: motion access is off. Tap to open Settings.', tone: Tone.warning),
            ),
          StepAccess.unavailable => const StatusLine(Icons.directions_walk, 'This phone cannot count steps. Everything else is recorded.'),
          _ => ref.read(stepSourceProvider).simulated ? const StatusLine(Icons.science_outlined, 'Simulated steps (test build)', tone: Tone.warning) : const SizedBox.shrink(),
        },
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
    final (IconData icon, String title, String detail, String? action, Tone tone) = switch (access) {
      null => (Icons.location_searching, 'Checking GPS…', 'Reading this phone\'s location settings.', null, Tone.neutral),
      GpsAccess.servicesOff => (Icons.location_disabled, 'Location is off', 'Turn on location to record a route.', 'Open settings', Tone.warning),
      GpsAccess.notAllowed => (Icons.location_off_outlined, 'Location not allowed yet', 'Allow location while using GoHard to record your route.', 'Allow', Tone.warning),
      GpsAccess.deniedForever => (Icons.location_off_outlined, 'Location is blocked for GoHard', 'Allow it in Settings, or start with the timer only.', 'Open app settings', Tone.warning),
      GpsAccess.approximate => (Icons.location_searching, 'Precise location is off', 'Approximate location cannot measure a route.', 'Allow precise location', Tone.warning),
      GpsAccess.unavailable => (Icons.location_disabled, 'Location is not available', 'You can still start with the timer only.', null, Tone.warning),
      GpsAccess.allowed when acc == null => (Icons.location_searching, 'Waiting for GPS…', 'Outdoors, with a clear view of the sky, it takes a few seconds.', null, Tone.neutral),
      GpsAccess.allowed => (Icons.location_on, acc! <= 25 ? 'GPS ready' : 'GPS signal weak',
          '${acc <= 10 ? 'Good signal' : acc <= 25 ? 'Fair signal' : 'Weak signal'} · ±${acc.round()} m accuracy', null, acc <= 25 ? Tone.success : Tone.warning),
    };
    final card = Container(
      key: const Key('runwalk-gps'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(Radii.tile), border: Border.all(color: context.c.divider)),
      child: Row(children: [
        Icon(icon, color: tone == Tone.success ? context.c.accent : tone == Tone.warning ? context.c.warning : context.c.secondary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.sansStyle(16.5, weight: FontWeight.w600)),
            Text(detail, style: context.caption),
          ]),
        ),
        if (action != null) ...[const SizedBox(width: 8), Icon(Icons.chevron_right, color: context.c.secondary)],
      ]),
    );
    return action == null
        ? Semantics(container: true, child: card)
        : Pressable(onTap: onAction, semanticLabel: '$title. $detail. $action', child: card);
  }
}

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
    final noun = activityNoun(run.activityType);
    final steps = rec.stepsState == 'measured' || rec.stepsState == 'partial' ? rec.steps?.steps : null;
    final phases = rec.plan != null && !rec.free;
    final voice = ref.watch(movePrefsProvider.select((p) => p.voice));

    final status = switch (rec.state) {
      RecState.paused => const StatusPill('Paused', icon: Icons.pause_circle_outline, tone: Tone.accent),
      RecState.autoPaused => const StatusPill('Auto-paused', icon: Icons.pause_circle_outline, tone: Tone.accent),
      RecState.interrupted => const StatusPill('Interrupted', icon: Icons.warning_amber_rounded, tone: Tone.warning),
      _ => null,
    };
    final map = RouteMap(
      key: Key(_mapView ? 'runwalk-map-full' : 'runwalk-map-preview'), segments: a.segments, here: here, live: true, controls: true, zoomButtons: _mapView,
      onExpand: _mapView ? null : () => setState(() => _mapView = true),
      overlayPadding: EdgeInsets.only(bottom: _mapView ? 0 : 44),
      semanticLabel: 'Route so far${distance == null ? '' : ', ${unit.distance(distance)}'}',
    );
    final gps = _GpsChip(rec: rec);

    // Twice the text or a narrow phone: the two buttons one above the other, so their words never break.
    final stack = MediaQuery.textScalerOf(context).scale(10) > 15 || MediaQuery.sizeOf(context).width < 340;
    final controls = interrupted
        ? Row(children: [
            Expanded(child: SecondaryButton('Finish', key: const Key('runwalk-finish'), icon: Icons.stop_rounded, onPressed: _acting ? null : () => _act(ref.read(recorderProvider.notifier).finish))),
            const SizedBox(width: 12),
            Expanded(child: PrimaryButton('Resume', key: const Key('runwalk-resume'), icon: Icons.play_arrow_rounded, onPressed: _acting ? null : () => _act(ref.read(recorderProvider.notifier).resume))),
          ])
        : Flex(direction: stack ? Axis.vertical : Axis.horizontal, mainAxisSize: MainAxisSize.min, crossAxisAlignment: stack ? CrossAxisAlignment.stretch : CrossAxisAlignment.center, children: [
            _Slot(
              stack: stack,
              child: SecondaryButton(paused ? 'Resume' : 'Pause', key: Key(paused ? 'runwalk-resume' : 'runwalk-pause'), icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  onPressed: _acting ? null : () => _act(paused ? ref.read(recorderProvider.notifier).resume : ref.read(recorderProvider.notifier).pause)),
            ),
            const SizedBox(width: 12, height: 8),
            _Slot(stack: stack, child: PrimaryButton('Finish', key: const Key('runwalk-finish'), icon: Icons.stop_rounded, onPressed: _acting ? null : () => _act(ref.read(recorderProvider.notifier).finish))),
          ]);

    final notes = <Widget>[
      if (interrupted)
        StatusLine(Icons.warning_amber_rounded,
            a.hasLegacy && a.interruptions == 0
                ? 'This $noun was started before routes were kept. Its time and distance so far are kept; resume to record the rest with a route.'
                : 'Recording stopped when GoHard was closed. The time since then is left out. Resume to go on, or Finish to save it.',
            tone: Tone.warning),
      if (rec.problem != null) StatusLine(Icons.error_outline, rec.problem!, tone: Tone.error),
      if (rec.gpsError != null) StatusLine(Icons.gps_off, rec.gpsError!, tone: Tone.warning),
      if (rec.timerOnly) StatusLine(Icons.timer_outlined, 'Timer only: no GPS route or distance is recorded. You can type a distance when you finish.'),
      if (ref.read(locationSourceProvider).simulated) StatusLine(Icons.science_outlined, 'Simulated GPS (test build)', tone: Tone.warning),
    ];

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          key: const Key('runwalk-voice-toggle'), tooltip: voice ? 'Voice updates on. Turn off' : 'Voice updates off. Turn on',
          icon: Icon(voice ? Icons.volume_up_outlined : Icons.volume_off_outlined),
          onPressed: () {
            if (voice) ref.read(announcerProvider.notifier).cancel();
            ref.read(movePrefsProvider.notifier).update((p) => p.copy(voice: !voice));
          },
        ),
        CoachHelpButton(key: const Key('coach-help-run'), semanticLabel: 'Help with recording a $noun', onPressed: () => _help(context)),
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
            child: Segmented<bool>(keyPrefix: 'runwalk-view', values: const [true, false], selected: _mapView, label: (m) => m ? 'Map' : 'Stats', onChanged: (m) => setState(() => _mapView = m)),
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
                            : StatFigure(steps == null ? '—' : formatSteps(steps), null, rec.stepsState == 'partial' ? 'Steps (partly)' : steps == null ? 'Steps not counted' : 'Steps',
                                key: const Key('runwalk-steps'), size: 26),
                      ),
                      const SizedBox(height: 14),
                      for (final n in notes) Padding(padding: const EdgeInsets.only(bottom: 8), child: n),
                      SizedBox(
                        height: (box.maxHeight * 0.42).clamp(200.0, 360.0).toDouble(),
                        child: Stack(children: [Positioned.fill(child: map), Positioned(left: 10, bottom: 10, child: gps)]),
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
      label: 'Active time ${durationText(seconds)}${paused ? ', paused' : ''}',
      child: ExcludeSemantics(
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: panel.page, border: Border.all(color: panel.accentSoft, width: size * 0.035)),
          padding: EdgeInsets.all(size * 0.12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(clockText(seconds), style: context.pageTitleStyle(size * 0.27, color: panel.text))),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text('Active time', style: context.sansStyle(16, color: panel.secondary))),
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
        label: said ?? '$label ${value == '—' ? 'not known' : '$value ${unit ?? ''}'}',
        child: ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
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
    final d = StatFigure(distance == null ? '—' : unit.number(distance!), unit.label, 'Distance', key: const Key('runwalk-distance'));
    final p = StatFigure(unit.paceNumber(pace), _paceUnit(unit), 'Avg. moving pace', key: const Key('runwalk-pace'));
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
              StatFigure(clockText(active), null, 'Active time', size: 24, said: 'Active time ${durationText(active)}'),
              StatFigure(distance == null ? '—' : unit.number(distance!), unit.label, 'Distance', size: 24),
              StatFigure(unit.paceNumber(pace), _paceUnit(unit), 'Avg. moving pace', size: 24),
              if (steps != null) StatFigure(formatSteps(steps!), null, 'Steps', size: 24),
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
    final (Color dot, String text) = rec.timerOnly
        ? (context.c.secondary, 'Timer only')
        : !rec.gpsOn
            ? (context.c.secondary, 'GPS off')
            : rec.gpsError != null
                ? (context.c.warning, 'GPS lost')
                : acc == null
                    ? (context.c.warning, 'Waiting for GPS')
                    : (acc <= 25 ? const Color(0xFF3CC46B) : context.c.warning, 'GPS · ±${acc.round()} m');
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
  final h = startLocal.hour;
  final part = h >= 5 && h < 12 ? 'Morning' : h >= 12 && h < 17 ? 'Afternoon' : h >= 17 && h < 21 ? 'Evening' : 'Night';
  return '$part ${activityNoun(type)}';
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
    final typed = parseNonNegative(_distance.text);
    if (_distance.text.trim().isNotEmpty && (typed == null || typed > 1000)) return setState(() => _error = 'Enter the distance as a number, or leave it blank.');
    final title = _title.text.trim();
    if (title.isEmpty || title.length > 80) return setState(() => _error = 'Give it a title of 1 to 80 characters.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref.read(recorderProvider.notifier).save(title: title, notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(), typedMeters: typed == null ? null : typed * unit.meters);
      if (mounted) await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => ActivityDetailScreen(runId: id, justSaved: true)));
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = 'It could not be saved on this phone. Nothing was lost; try Save again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard(String noun) async {
    if (!await confirm(context, title: 'Discard this $noun?', body: 'The $noun and its route are deleted from this phone and your account. This cannot be undone.',
        action: 'Discard $noun', destructive: true)) {
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
    final noun = activityNoun(run.activityType);
    return AppPage(
      title: 'Save your $noun', subtitle: '${longDate(run.dayKey)} · ${activityTitle(run.activityType)}',
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        PrimaryButton('Save $noun', key: const Key('runwalk-save'), icon: Icons.check, busy: _saving, onPressed: _save),
      ]),
      children: [
        if (a.measured)
          SizedBox(height: 220, child: RouteMap(key: const Key('runwalk-review-map'), segments: a.segments, controls: true, semanticLabel: 'Recorded route'))
        else
          StatusLine(Icons.timer_outlined, rec.timerOnly || !a.hasLegacy ? 'No GPS route was recorded for this $noun.' : 'Route not recorded.'),
        const SizedBox(height: 16),
        Wrap(spacing: 22, runSpacing: 12, children: [
          StatFigure(gps == null ? '—' : unit.number(gps), unit.label, gps == null ? 'Distance not measured' : 'Distance'),
          StatFigure(clockText(s.metrics['movingSeconds'] as int), null, 'Moving time', said: 'Moving time ${durationText(s.metrics['movingSeconds'] as int)}'),
          StatFigure(clockText(s.activeSeconds), null, 'Active time', said: 'Active time ${durationText(s.activeSeconds)}'),
          StatFigure(unit.paceNumber(a.avgMovingPace(unit.meters)), _paceUnit(unit), 'Avg. moving pace'),
          if (rec.stepsState != 'off') StatFigure(rec.steps == null ? '—' : formatSteps(rec.steps!.steps), null, rec.stepsState == 'partial' ? 'Steps (part of the time)' : rec.steps == null ? 'Steps not counted' : 'Steps'),
        ]),
        const SizedBox(height: 18),
        TextField(key: const Key('runwalk-title'), controller: _title, maxLength: 80, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 8),
        TextField(key: const Key('runwalk-notes'), controller: _notes, maxLength: 1000, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Notes (optional)')),
        const SizedBox(height: 8),
        TextField(
          key: const Key('runwalk-distance-input'), controller: _distance, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: gps == null ? 'Distance (optional)' : 'Correct the distance (optional)', suffixText: unit.label,
            helperText: gps == null ? 'Typed, not measured by GPS.' : 'The GPS measurement is kept beside it; the route is not changed.',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        SecondaryButton('Resume recording', key: const Key('runwalk-review-resume'), icon: Icons.play_arrow_rounded, onPressed: _saving ? null : () => ref.read(recorderProvider.notifier).reopen()),
        const SizedBox(height: 4),
        Center(child: TextButton(key: const Key('runwalk-discard'), onPressed: _saving ? null : () => _discard(noun), child: Text('Discard $noun'))),
      ],
    );
  }
}
