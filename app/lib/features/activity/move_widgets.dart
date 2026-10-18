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
import '../coach/coach_avatar.dart';
import '../coach/coach_prefs.dart';
import 'activity_detail.dart';
import 'announcer.dart';
import 'intervals.dart';
import 'move_prefs.dart';
import 'recorder.dart';
import 'records.dart';
import 'steps.dart';

/// Run / Walk pieces shared by Ready, Recording, History, Today and Customize tracking: interval setup, voice and
/// alerts, the phase bar, the coach's line during a recording, personal bests and steps.

// ---------------------------------------------------------------------------- interval setup

/// "5:00 warm-up · 8 × run 1:00, walk 1:30 · 5:00 cool-down"
String planSummary(IntervalPlan p) => [
      if (p.warmup > 0) '${phaseClock(p.warmup)} warm-up',
      '${p.reps} × run ${phaseClock(p.run)}, walk ${phaseClock(p.walk)}',
      if (p.cooldown > 0) '${phaseClock(p.cooldown)} cool-down',
    ].join(' · ');

Future<void> showIntervalSetup(BuildContext context) => showGoSheet<void>(context, title: 'Intervals', builder: (_) => const _IntervalSetup());

class _IntervalSetup extends ConsumerStatefulWidget {
  const _IntervalSetup();
  @override
  ConsumerState<_IntervalSetup> createState() => _IntervalSetupState();
}

class _IntervalSetupState extends ConsumerState<_IntervalSetup> {
  late IntervalPlan _p = ref.read(movePrefsProvider).plan ?? IntervalPlan.preset;

  static int _stepFor(int s, bool up) {
    final at = up ? s : s - 1;
    return at < 120 ? 15 : at < 600 ? 30 : 60;
  }

  Widget _row(String key, String label, int value, {required int min, required int max, int? step, String Function(int)? text, String Function(int)? said}) {
    final shown = text ?? (v) => v == 0 ? 'None' : phaseClock(v);
    final spoken = said ?? (v) => v == 0 ? 'none' : spokenDuration(v);
    int next(bool up) => (value + (up ? 1 : -1) * (step ?? _stepFor(value, up))).clamp(min, max);
    void set(int v) => setState(() => _p = switch (key) {
          'warmup' => _p.copy(warmup: v),
          'run' => _p.copy(run: v),
          'walk' => _p.copy(walk: v),
          'reps' => _p.copy(reps: v),
          _ => _p.copy(cooldown: v),
        });
    return Semantics(
      container: true,
      label: '$label, ${spoken(value)}',
      child: Row(children: [
        Expanded(child: Text(label, style: context.sansStyle(16, weight: FontWeight.w600))),
        IconButton(key: Key('interval-$key-less'), tooltip: 'Less $label', onPressed: value <= min ? null : () => set(key == 'warmup' || key == 'cooldown' ? (value <= 60 ? 0 : next(false)) : next(false)), icon: const Icon(Icons.remove_circle_outline)),
        SizedBox(width: 64, child: ExcludeSemantics(child: Text(shown(value), key: Key('interval-$key'), textAlign: TextAlign.center, style: context.titleStyle(19)))),
        IconButton(key: Key('interval-$key-more'), tooltip: 'More $label', onPressed: value >= max ? null : () => set(key == 'warmup' || key == 'cooldown' ? (value == 0 ? 60 : next(true)) : next(true)), icon: const Icon(Icons.add_circle_outline)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(movePrefsProvider);
    final p = _p;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Alternate running and walking. Walking to recover is part of the session, not a pause: it is one activity.', style: context.sansStyle(15, color: context.c.secondary)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('Starting point: ${IntervalPlan.presetName}, as in week 1 of the NHS Couch to 5K plan. Change anything.', style: context.caption)),
        if (p != IntervalPlan.preset) TextButton(key: const Key('interval-preset'), onPressed: () => setState(() => _p = IntervalPlan.preset), child: const Text('Use it')),
      ]),
      const SizedBox(height: 6),
      _row('warmup', 'Warm-up walk', p.warmup, min: 0, max: IntervalPlan.maxWarm, step: 60),
      _row('run', 'Run', p.run, min: IntervalPlan.minPhase + 5, max: IntervalPlan.maxPhase),
      _row('walk', 'Walk / recover', p.walk, min: IntervalPlan.minPhase + 5, max: IntervalPlan.maxPhase),
      _row('reps', 'Repeats', p.reps, min: 1, max: IntervalPlan.maxReps, step: 1, text: (v) => '$v ×', said: (v) => '$v times'),
      _row('cooldown', 'Cool-down walk', p.cooldown, min: 0, max: IntervalPlan.maxWarm, step: 60),
      const SizedBox(height: 10),
      PhaseStrip(plan: p),
      const SizedBox(height: 8),
      Text(planSummary(p), key: const Key('interval-summary'), style: context.sansStyle(15)),
      Text('Programmed active time ${clockText(p.totalSeconds)}', key: const Key('interval-total'), style: context.sansStyle(15, weight: FontWeight.w600)),
      const SizedBox(height: 14),
      PrimaryButton('Use these intervals', key: const Key('interval-use'), onPressed: () {
        ref.read(movePrefsProvider.notifier).update((m) => m.copy(plan: p, intervals: true));
        Navigator.pop(context);
      }),
      if (prefs.intervals)
        Center(
          child: TextButton(key: const Key('interval-off'), onPressed: () {
            ref.read(movePrefsProvider.notifier).update((m) => m.copy(intervals: false));
            Navigator.pop(context);
          }, child: const Text('Turn intervals off')),
        ),
    ]);
  }
}

/// The phases drawn to scale: run in the accent, walking phases soft.
class PhaseStrip extends StatelessWidget {
  const PhaseStrip({super.key, required this.plan, this.current});
  final IntervalPlan plan;
  final int? current;

  @override
  Widget build(BuildContext context) {
    final panel = GoColors.panelOf(context.c);
    final phases = plan.phases;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 12,
          child: Row(children: [
            for (final (i, ph) in phases.indexed)
              Expanded(
                flex: ph.seconds,
                child: Container(
                  margin: EdgeInsets.only(right: i == phases.length - 1 ? 0 : 1.5),
                  decoration: BoxDecoration(
                    color: ph.kind == PhaseKind.run ? context.c.accent : ph.kind == PhaseKind.walk ? panel.accentSoft : context.c.divider,
                    border: i == current ? Border.all(color: context.c.text, width: 2) : null,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------- voice and alerts

String voiceSummary(MovePrefs p, DistanceUnit unit) {
  final updates = switch (p.updates) {
    UpdateMode.off => 'no updates',
    UpdateMode.distance => 'every ${p.everyDistance == p.everyDistance.roundToDouble() ? p.everyDistance.round() : p.everyDistance} ${unit.label}',
    UpdateMode.time => 'every ${p.everyMinutes} min',
  };
  return p.voice ? 'Voice on, $updates' : 'Voice off';
}

Future<void> showVoiceSheet(BuildContext context) => showGoSheet<void>(context, title: 'Voice and alerts', builder: (_) => const _VoiceSheet());

class _VoiceSheet extends ConsumerStatefulWidget {
  const _VoiceSheet();
  @override
  ConsumerState<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<_VoiceSheet> {
  late final Future<List<VoiceOption>> _voices = ref.read(voiceOutProvider).voices().catchError((Object _) => const <VoiceOption>[]);

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(movePrefsProvider);
    final unit = ref.watch(devicePrefsProvider.select((p) => p.distance));
    final guide = ref.watch(coachPrefsProvider.select((c) => c.guide));
    final ctl = ref.read(movePrefsProvider.notifier);
    final lang = Localizations.localeOf(context).languageCode;
    Widget toggle(String key, String title, String subtitle, bool value, void Function(bool) on) => SwitchListTile(
        key: Key(key), contentPadding: EdgeInsets.zero, title: Text(title, style: context.sansStyle(16, weight: FontWeight.w600)),
        subtitle: Text(subtitle, style: context.caption), value: value, onChanged: on);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      toggle('voice-on', 'Voice updates', '${guide.label} says interval changes, updates and personal bests aloud, in a voice installed on this phone. Nothing is sent anywhere.',
          p.voice, (v) => ctl.update((m) => m.copy(voice: v))),
      if (p.voice) ...[
        const SizedBox(height: 6),
        Text('Updates', style: context.label),
        const SizedBox(height: 6),
        Segmented<UpdateMode>(
          keyPrefix: 'voice-updates', values: UpdateMode.values, selected: p.updates,
          label: (m) => switch (m) { UpdateMode.off => 'None', UpdateMode.distance => 'Distance', UpdateMode.time => 'Time' },
          onChanged: (m) => ctl.update((x) => x.copy(updates: m)),
        ),
        const SizedBox(height: 8),
        if (p.updates == UpdateMode.distance)
          Segmented<double>(keyPrefix: 'voice-every-d', values: MovePrefs.distanceChoices, selected: p.everyDistance,
              label: (d) => '${d == d.roundToDouble() ? d.round() : d} ${unit.label}', onChanged: (d) => ctl.update((x) => x.copy(everyDistance: d))),
        if (p.updates == UpdateMode.time)
          Segmented<int>(keyPrefix: 'voice-every-t', values: MovePrefs.minuteChoices, selected: p.everyMinutes, label: (m) => '$m min', onChanged: (m) => ctl.update((x) => x.copy(everyMinutes: m))),
        if (p.updates != UpdateMode.off)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Each update says the distance, the active time and the average moving pace (moving time ÷ distance), only once GPS has measured enough.', style: context.caption),
          ),
        const SizedBox(height: 12),
        FutureBuilder<List<VoiceOption>>(
          future: _voices,
          builder: (context, snap) {
            final all = [for (final v in snap.data ?? const <VoiceOption>[]) if (v.locale.toLowerCase().startsWith(lang)) v]..sort((a, b) => a.name.compareTo(b.name));
            final chosen = all.where((v) => v.name == p.voiceName && v.locale == p.voiceLocale).firstOrNull;
            final missing = p.voiceName != null && snap.hasData && chosen == null;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<VoiceOption?>(
                key: const Key('voice-choice'), isExpanded: true, initialValue: chosen,
                decoration: InputDecoration(labelText: 'Voice', helperText: missing ? 'The voice chosen before is not installed now: the phone\'s own voice is used.' : null, helperMaxLines: 2),
                items: [
                  const DropdownMenuItem<VoiceOption?>(value: null, child: Text("The phone's own voice")),
                  for (final v in all.take(40)) DropdownMenuItem<VoiceOption?>(value: v, child: Text('${v.name} (${v.locale})', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => ctl.update((x) => x.copy(voiceChoice: (v?.name, v?.locale))),
              ),
              const SizedBox(height: 8),
              SecondaryButton('Preview voice', key: const Key('voice-preview'), icon: Icons.volume_up_outlined,
                  onPressed: () => ref.read(announcerProvider.notifier).preview(guide, chosen).ignore()),
            ]);
          },
        ),
      ],
      const SizedBox(height: 6),
      toggle('voice-vibrate', 'Vibrate at interval changes', 'Also with the screen locked on Android. On iPhone, while GoHard is open.', p.vibrate, (v) => ctl.update((m) => m.copy(vibrate: v))),
      toggle('voice-countdown', 'Countdown', 'A tick each second for the last three seconds of a phase.', p.countdown, (v) => ctl.update((m) => m.copy(countdown: v))),
      Text('Interval changes are always shown on screen. These choices are kept on this phone.', style: context.caption),
    ]);
  }
}

// ---------------------------------------------------------------------------- recording: phases and the coach

/// The current phase, its time left and the round, under the dial. From the recorder's active clock: a rebuild only
/// redraws it.
class IntervalBar extends ConsumerWidget {
  const IntervalBar({super.key, required this.rec, required this.nowMs, this.compact = false});
  final RecorderView rec;
  final int nowMs;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = rec.plan!, pos = rec.intervalAt(nowMs)!;
    final panel = GoColors.panelOf(context.c);
    if (pos.done) return const _IntervalsDone();
    final ph = pos.phase!;
    final left = (pos.remainingMs / 1000).ceil();
    final next = pos.index + 1 < plan.phases.length ? plan.phases[pos.index + 1] : null;
    final round = ph.round == null ? null : 'Round ${ph.round} of ${plan.reps}';
    final counting = left <= 3;
    // Large text or a narrow phone: Skip phase goes under the phase, so the phase's words keep the width.
    final narrow = MediaQuery.textScalerOf(context).scale(10) > 15 || MediaQuery.sizeOf(context).width < 340;
    final skip = TextButton.icon(key: const Key('runwalk-skip-phase'), onPressed: rec.state == RecState.interrupted ? null : () => ref.read(recorderProvider.notifier).skipPhase(),
        icon: const Icon(Icons.skip_next_rounded), label: const Text('Skip phase'));
    return Semantics(
      container: true,
      label: '${ph.label}${round == null ? '' : ', $round'}, ${spokenDuration(left)} left${next == null ? '' : '. Next: ${next.label.toLowerCase()}'}',
      child: Container(
        key: const Key('runwalk-interval'),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(color: panel.page, borderRadius: BorderRadius.circular(Radii.tile)),
        child: PanelTheme(
          child: Builder(
            builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.end, children: [
                      Text(ph.label, key: const Key('runwalk-phase'), style: context.pageTitleStyle(compact ? 24 : 28)),
                      Text(counting ? '$left' : '${phaseClock(left)} left', key: const Key('runwalk-phase-left'),
                          style: context.sansStyle(counting ? 24 : 17, weight: FontWeight.w700, color: counting ? context.c.accent : null)),
                      if (round != null) Text(round, style: context.sansStyle(15, color: context.c.secondary)),
                    ]),
                  ),
                ),
                if (!narrow) skip,
              ]),
              if (narrow) Align(alignment: Alignment.centerLeft, child: skip),
              if (!compact) ...[
                const SizedBox(height: 6),
                PhaseStrip(plan: plan, current: pos.index),
                if (next != null) Padding(padding: const EdgeInsets.only(top: 4), child: ExcludeSemantics(child: Text('Next: ${next.label} ${phaseClock(next.seconds)}', style: context.caption))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _IntervalsDone extends ConsumerWidget {
  const _IntervalsDone();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        key: const Key('runwalk-intervals-done'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GoColors.panelOf(context.c).page, borderRadius: BorderRadius.circular(Radii.tile)),
        child: PanelTheme(
          child: Builder(
            builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text('Intervals finished', style: context.pageTitleStyle(24)),
              Text('Still recording. Keep going freely, or finish and review.', style: context.sansStyle(15, color: context.c.secondary)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 8, children: [
                SecondaryButton('Continue freely', key: const Key('runwalk-continue-free'), expand: false, onPressed: () => ref.read(recorderProvider.notifier).continueFreely()),
                PrimaryButton('Finish and review', key: const Key('runwalk-finish-review'), expand: false, onPressed: () => ref.read(recorderProvider.notifier).finish()),
              ]),
            ]),
          ),
        ),
      );
}

/// The coach during a recording: the last thing said, beside the guide's small portrait (or alone, when the coach is
/// hidden), in the page rather than over the map or the controls. Read out by screen readers as it changes.
class CoachLine extends ConsumerWidget {
  const CoachLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cue = ref.watch(announcerProvider);
    final face = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    final child = cue == null
        ? const SizedBox(key: ValueKey('none'), width: double.infinity)
        : Padding(
            key: ValueKey(cue.key),
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              container: true,
              label: cue.text,
              child: ExcludeSemantics(
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  if (face) ...[const CoachAvatar(size: 38), const SizedBox(width: 8)],
                  Expanded(
                    child: Container(
                      key: const Key('runwalk-coach-line'),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(color: context.c.raised, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.c.divider)),
                      child: Text(cue.text, style: context.sansStyle(15.5, weight: FontWeight.w500)),
                    ),
                  ),
                ]),
              ),
            ),
          );
    if (context.reduceMotion) return child;
    return AnimatedSwitcher(duration: Motion.quick, child: child);
  }
}

// ---------------------------------------------------------------------------- personal bests

/// Personal bests for Run and Walk, from every saved activity on this phone (History and Progress).
class PersonalBestsCard extends ConsumerWidget {
  const PersonalBestsCard({super.key, this.types = const ['run', 'walk']});
  final List<String> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = [for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) r.value];
    final unit = ref.watch(devicePrefsProvider.select((p) => p.distance));
    final b = personalBests(runs);
    final unchecked = types.fold<int>(0, (n, t) => n + (b.unchecked[t] ?? 0));
    return Column(key: const Key('personal-bests'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Personal bests', style: context.sansStyle(18, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      GroupCard(children: [
        for (final bm in benchmarks)
          if (types.contains(bm.type))
            () {
              final best = b.by[bm.id];
              final label = '${bm.label}${bm.longest ? '' : ' ${bm.type}'}';
              return GroupRow(
                key: Key('best-${bm.id}'), icon: bm.longest ? Icons.straighten : Icons.timer_outlined, title: label,
                subtitle: best == null ? 'Not set yet' : '${activityName(best.run)} · ${shortDate(best.run.dayKey)}',
                value: best == null ? '—' : bm.longest ? unit.distance(best.value) : clockOf(best.value),
                onTap: best == null ? null : () => push(context, ActivityDetailScreen(runId: best.run.id)),
              );
            }(),
      ]),
      const SizedBox(height: 6),
      Text(
        'From saved activities whose distance GPS measured. A fastest time is the quickest continuous stretch of that distance, '
        'timed from its start to its end; a pause or a GPS gap breaks a stretch. Typed or corrected distances do not count.'
        '${unchecked > 0 ? ' $unchecked earlier ${unchecked == 1 ? 'activity was' : 'activities were'} saved before fastest times were kept and ${unchecked == 1 ? 'counts' : 'count'} only for distance, if measured.' : ''}',
        style: context.caption,
      ),
    ]);
  }
}

/// History's one row for personal bests: the two headline ones, opening the full list. Kept to a row so History's
/// own list stays first.
class PersonalBestsLink extends ConsumerWidget {
  const PersonalBestsLink({super.key, required this.types});
  final List<String> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = [for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) r.value];
    final unit = ref.watch(devicePrefsProvider.select((p) => p.distance));
    final b = personalBests(runs);
    final shown = [
      for (final bm in benchmarks)
        if (types.contains(bm.type) && b.by[bm.id] != null) '${bm.label}${bm.longest ? '' : ' ${bm.type}'} ${bm.longest ? unit.distance(b.by[bm.id]!.value) : clockOf(b.by[bm.id]!.value)}',
    ];
    return GroupCard(children: [
      GroupRow(
        key: const Key('history-bests'), icon: Icons.emoji_events_outlined, title: 'Personal bests',
        subtitle: shown.isEmpty ? 'None yet: they come from saved activities measured by GPS' : shown.take(2).join(' · '),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => push(context, PersonalBestsScreen(types: types)),
      ),
    ]);
  }
}

class PersonalBestsScreen extends StatelessWidget {
  const PersonalBestsScreen({super.key, required this.types});
  final List<String> types;
  @override
  Widget build(BuildContext context) => AppPage(title: 'Personal bests', children: [PersonalBestsCard(types: types)]);
}

// ---------------------------------------------------------------------------- steps

/// Turning steps on asks for motion access (and, on Android, Health Connect's step read for the daily total). Run /
/// Walk works whatever the answer; the screens say what was not allowed.
Future<void> enableSteps(WidgetRef ref) async {
  final owner = ref.read(ownerProvider);
  if (owner == null) return;
  final src = ref.read(stepSourceProvider);
  ref.read(movePrefsProvider.notifier).setSteps(owner, true);
  await src.request();
  await src.dailyRequest();
  await ref.read(dailyStepsProvider.notifier).refresh();
}

/// Steps in Customize tracking: the switch, the optional goal, and what stays where.
class StepsSettings extends ConsumerStatefulWidget {
  const StepsSettings({super.key});
  @override
  ConsumerState<StepsSettings> createState() => _StepsSettingsState();
}

class _StepsSettingsState extends ConsumerState<StepsSettings> {
  late final TextEditingController _goal;

  @override
  void initState() {
    super.initState();
    _goal = TextEditingController(text: ref.read(stepGoalProvider)?.toString() ?? '');
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(stepsEnabledProvider);
    final owner = ref.watch(ownerProvider);
    final src = ref.watch(stepSourceProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      SwitchListTile(
        key: const Key('track-steps'), contentPadding: EdgeInsets.zero, value: on,
        title: Text('Steps', style: context.sansStyle(16, weight: FontWeight.w600)),
        subtitle: Text('Counted by this phone during a run or walk, and today\'s total on Today. Walking without your phone is not counted.', style: context.caption),
        onChanged: owner == null ? null : (v) => v ? enableSteps(ref) : ref.read(movePrefsProvider.notifier).setSteps(owner, false),
      ),
      if (on) ...[
        TextField(
          key: const Key('steps-goal'), controller: _goal, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Daily steps goal (optional)', helperText: 'Your own number. Leave it blank for none.'),
          onChanged: (t) => ref.read(movePrefsProvider.notifier).setStepGoal(owner!, int.tryParse(t.trim().replaceAll(',', ''))),
        ),
        const SizedBox(height: 8),
        Text("Today's total is read from ${src.dailySource} and stays on this phone: it is never sent to your account. "
            'The steps of a run or walk are saved with it and sync with your account.', style: context.caption),
      ],
    ]);
  }
}

/// Today's steps, near Run / Walk, when turned on: one compact row with its source and when it was read. Loading,
/// not allowed, unavailable and a real zero each read differently.
class StepsTodayRow extends ConsumerStatefulWidget {
  const StepsTodayRow({super.key, required this.onOpenSettings});
  final VoidCallback onOpenSettings;
  @override
  ConsumerState<StepsTodayRow> createState() => _StepsTodayRowState();
}

class _StepsTodayRowState extends ConsumerState<StepsTodayRow> with WidgetsBindingObserver {
  /// Fresh while shown; nothing is read while it is not.
  late final Timer _fresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fresh = Timer.periodic(const Duration(minutes: 5), (_) => ref.read(dailyStepsProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _fresh.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) ref.read(dailyStepsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(dailyStepsProvider);
    final goal = ref.watch(stepGoalProvider);
    final src = ref.read(stepSourceProvider);
    String at(DateTime t) => '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
    final (String value, String detail, VoidCallback? tap) = switch (d) {
      DailyOff() => ('', '', null),
      DailyLoading() => ('…', 'Reading steps', null),
      DailyUnavailable(:final why) => ('—', why, widget.onOpenSettings),
      DailyNotAllowed(:final blocked) => ('—', blocked ? 'Motion access is off. Allow it in Settings.' : 'Allow motion access to see today\'s steps.',
          blocked ? () => src.openSettings() : () => enableSteps(ref)),
      DailyFailed() => ('—', 'Could not read steps just now', () => ref.read(dailyStepsProvider.notifier).refresh()),
      DailyValue(:final steps, :final source, at: final t, :final recorded) => recorded
          ? (formatSteps(steps), '${goal == null ? '' : 'of ${formatSteps(goal)} · '}$source · ${at(t)}', widget.onOpenSettings)
          : ('—', 'No steps recorded on this phone today ($source)', widget.onOpenSettings),
    };
    if (d is DailyOff) return const SizedBox.shrink();
    final panel = GoColors.panelOf(context.c);
    final progress = d is DailyValue && d.recorded && goal != null ? (d.steps / goal).clamp(0.0, 1.0) : null;
    final row = Container(
      key: const Key('today-steps'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: panel.page, borderRadius: BorderRadius.circular(Radii.tile)),
      child: PanelTheme(
        child: Builder(
          builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(Icons.directions_walk, color: context.c.accent),
              const SizedBox(width: 10),
              Text('Steps today', style: context.sansStyle(15.5, weight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(child: Text(value, key: const Key('today-steps-value'), textAlign: TextAlign.end, style: context.titleStyle(20))),
            ]),
            Text(detail, style: context.caption),
            if (progress != null) Padding(padding: const EdgeInsets.only(top: 6), child: ProgressRail(progress, label: 'Steps goal')),
            if (src.simulated) Text('Simulated steps (test build)', style: context.caption),
          ]),
        ),
      ),
    );
    final said = 'Steps today: ${value == '—' || value == '…' ? 'not known' : value}. $detail';
    return tap == null ? Semantics(container: true, label: said, child: ExcludeSemantics(child: row)) : Pressable(onTap: tap, semanticLabel: said, child: row);
  }
}
