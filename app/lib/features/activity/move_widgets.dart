import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/device_prefs.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../coach/coach_bubble.dart' show CoachSay, CoachSpeech;
import '../coach/coach_rig.dart' show RigFrame;
import '../coach/coach_prefs.dart';
import 'activity_detail.dart';
import 'announcer.dart';
import 'intervals.dart';
import 'move_prefs.dart';
import 'recorder.dart';
import 'records.dart';

/// Run / Walk pieces shared by Ready, Recording, History, Today and Customize tracking: interval setup, voice and
/// alerts, the phase bar, the coach's line during a recording, personal bests and steps.

// ---------------------------------------------------------------------------- interval setup

/// "5:00 warm-up · 8 × run 1:00, walk 1:30 · 5:00 cool-down"
String planSummary(AppLocalizations l, IntervalPlan p) => [
      if (p.warmup > 0) l.runPlanWarmup(phaseClock(p.warmup)),
      l.runPlanRepeats(p.reps, phaseClock(p.run), phaseClock(p.walk)),
      if (p.cooldown > 0) l.runPlanCooldown(phaseClock(p.cooldown)),
    ].join(' · ');

Future<void> showIntervalSetup(BuildContext context) => showGoSheet<void>(context, title: context.l10n.runSetupIntervals, builder: (_) => const _IntervalSetup());

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
    final l = context.l10n;
    final shown = text ?? (v) => v == 0 ? l.runIntervalNone : phaseClock(v);
    final spoken = said ?? (v) => v == 0 ? l.runIntervalNoneSaid : spokenDuration(v, l);
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
        IconButton(key: Key('interval-$key-less'), tooltip: l.runIntervalLess(label), onPressed: value <= min ? null : () => set(key == 'warmup' || key == 'cooldown' ? (value <= 60 ? 0 : next(false)) : next(false)), icon: const Icon(Icons.remove_circle_outline)),
        SizedBox(width: 64, child: ExcludeSemantics(child: Text(shown(value), key: Key('interval-$key'), textAlign: TextAlign.center, style: context.titleStyle(19)))),
        IconButton(key: Key('interval-$key-more'), tooltip: l.runIntervalMore(label), onPressed: value >= max ? null : () => set(key == 'warmup' || key == 'cooldown' ? (value == 0 ? 60 : next(true)) : next(true)), icon: const Icon(Icons.add_circle_outline)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(movePrefsProvider);
    final p = _p;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(l.runIntervalsIntro, style: context.sansStyle(15, color: context.c.secondary)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text(l.runIntervalsPresetNote, style: context.caption)),
        if (p != IntervalPlan.preset) TextButton(key: const Key('interval-preset'), onPressed: () => setState(() => _p = IntervalPlan.preset), child: Text(l.runIntervalsUsePreset)),
      ]),
      const SizedBox(height: 6),
      _row('warmup', l.runIntervalWarmup, p.warmup, min: 0, max: IntervalPlan.maxWarm, step: 60),
      _row('run', l.runIntervalRun, p.run, min: IntervalPlan.minPhase + 5, max: IntervalPlan.maxPhase),
      _row('walk', l.runIntervalWalk, p.walk, min: IntervalPlan.minPhase + 5, max: IntervalPlan.maxPhase),
      _row('reps', l.runIntervalRepeats, p.reps, min: 1, max: IntervalPlan.maxReps, step: 1, text: l.runIntervalRepsValue, said: l.runIntervalRepsSaid),
      _row('cooldown', l.runIntervalCooldown, p.cooldown, min: 0, max: IntervalPlan.maxWarm, step: 60),
      const SizedBox(height: 10),
      PhaseStrip(plan: p),
      const SizedBox(height: 8),
      Text(planSummary(l, p), key: const Key('interval-summary'), style: context.sansStyle(15)),
      Text(l.runIntervalTotal(ltr(clockText(p.totalSeconds))), key: const Key('interval-total'), style: context.sansStyle(15, weight: FontWeight.w600)),
      const SizedBox(height: 14),
      PrimaryButton(l.runIntervalsUse, key: const Key('interval-use'), onPressed: () {
        ref.read(movePrefsProvider.notifier).update((m) => m.copy(plan: p, intervals: true));
        Navigator.pop(context);
      }),
      if (prefs.intervals)
        Center(
          child: TextButton(key: const Key('interval-off'), onPressed: () {
            ref.read(movePrefsProvider.notifier).update((m) => m.copy(intervals: false));
            Navigator.pop(context);
          }, child: Text(l.runIntervalsOff)),
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
                  margin: EdgeInsetsDirectional.only(end: i == phases.length - 1 ? 0 : 1.5),
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

/// "1 km", "0.5 mi", "0,5 mi": the distance between voice updates.
String everyDistanceText(double d, DistanceUnit unit) => withUnit(d == d.roundToDouble() ? '${d.round()}' : localDecimal('$d'), unit.label);

Future<void> showVoiceSheet(BuildContext context) => showGoSheet<void>(context, title: context.l10n.runSetupVoice, builder: (_) => const _VoiceSheet());

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
    // The app language, never the phone's: only its offline voices are offered and spoken (announcer.voicesFor).
    final lang = Localizations.localeOf(context).languageCode;
    final l = context.l10n;
    Widget toggle(String key, String title, String subtitle, bool value, void Function(bool) on) => SwitchListTile(
        key: Key(key), contentPadding: EdgeInsets.zero, title: Text(title, style: context.sansStyle(16, weight: FontWeight.w600)),
        subtitle: Text(subtitle, style: context.caption), value: value, onChanged: on);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      toggle('voice-on', l.runVoiceUpdates, l.runVoiceUpdatesSubtitle(guide.name, guide.displayName(l)), p.voice, (v) => ctl.update((m) => m.copy(voice: v))),
      if (p.voice) ...[
        const SizedBox(height: 6),
        Text(l.runVoiceUpdatesLabel, style: context.label),
        const SizedBox(height: 6),
        Segmented<UpdateMode>(
          keyPrefix: 'voice-updates', values: UpdateMode.values, selected: p.updates,
          label: (m) => switch (m) { UpdateMode.off => l.runVoiceUpdatesNone, UpdateMode.distance => l.runVoiceUpdatesDistance, UpdateMode.time => l.runVoiceUpdatesTime },
          onChanged: (m) => ctl.update((x) => x.copy(updates: m)),
        ),
        const SizedBox(height: 8),
        if (p.updates == UpdateMode.distance)
          Segmented<double>(keyPrefix: 'voice-every-d', values: MovePrefs.distanceChoices, selected: p.everyDistance,
              label: (d) => everyDistanceText(d, unit), onChanged: (d) => ctl.update((x) => x.copy(everyDistance: d))),
        if (p.updates == UpdateMode.time)
          Segmented<int>(keyPrefix: 'voice-every-t', values: MovePrefs.minuteChoices, selected: p.everyMinutes, label: l.durationMinutes, onChanged: (m) => ctl.update((x) => x.copy(everyMinutes: m))),
        if (p.updates != UpdateMode.off)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.runVoiceUpdatesExplain, style: context.caption),
          ),
        const SizedBox(height: 12),
        FutureBuilder<List<VoiceOption>>(
          future: _voices,
          builder: (context, snap) {
            final all = voicesFor(snap.data ?? const <VoiceOption>[], lang);
            final chosen = all.where((v) => v.name == p.voiceName && v.locale == p.voiceLocale).firstOrNull;
            final missing = p.voiceName != null && snap.hasData && chosen == null;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<VoiceOption?>(
                key: const Key('voice-choice'), isExpanded: true, initialValue: chosen,
                decoration: InputDecoration(labelText: l.runVoiceField, helperText: snap.hasData && all.isEmpty
                        ? l.runVoiceNoneForLanguage
                        : missing
                            ? l.runVoiceMissing
                            : l.runVoiceOfflineOnly,
                    helperMaxLines: 4),
                items: [
                  DropdownMenuItem<VoiceOption?>(value: null, child: Text(l.runVoicePhoneDefault)),
                  for (final v in all.take(40)) DropdownMenuItem<VoiceOption?>(value: v, child: Text(ltr('${v.name} (${v.locale})'), overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => ctl.update((x) => x.copy(voiceChoice: (v?.name, v?.locale))),
              ),
              const SizedBox(height: 8),
              SecondaryButton(l.runVoicePreview, key: const Key('voice-preview'), icon: Icons.volume_up_outlined,
                  onPressed: snap.hasData && all.isEmpty ? null : () => ref.read(announcerProvider.notifier).preview(guide, chosen).ignore()),
            ]);
          },
        ),
      ],
      const SizedBox(height: 6),
      toggle('voice-vibrate', l.runVoiceVibrate, l.runVoiceVibrateSubtitle, p.vibrate, (v) => ctl.update((m) => m.copy(vibrate: v))),
      toggle('voice-countdown', l.runVoiceCountdown, l.runVoiceCountdownSubtitle, p.countdown, (v) => ctl.update((m) => m.copy(countdown: v))),
      Text(l.runVoiceFooter, style: context.caption),
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
    final l = context.l10n;
    final label = phaseName(l, ph.kind);
    final round = ph.round == null ? null : l.runRoundOf(ph.round!, plan.reps);
    final counting = left <= 3;
    // Large text or a narrow phone: Skip phase goes under the phase, so the phase's words keep the width.
    final narrow = MediaQuery.textScalerOf(context).scale(10) > 15 || MediaQuery.sizeOf(context).width < 340;
    final skip = TextButton.icon(key: const Key('runwalk-skip-phase'), onPressed: rec.state == RecState.interrupted ? null : () => ref.read(recorderProvider.notifier).skipPhase(),
        icon: const Icon(Icons.skip_next_rounded), label: Text(l.runSkipPhase));
    final said = [label, ?round, l.runTimeLeft(spokenDuration(left, l))].join(', ');
    return Semantics(
      container: true,
      label: next == null ? said : '$said. ${l.runNextPhaseSaid(phaseName(l, next.kind).toLowerCase())}',
      child: Container(
        key: const Key('runwalk-interval'),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
        decoration: BoxDecoration(color: panel.page, borderRadius: BorderRadius.circular(Radii.tile)),
        child: PanelTheme(
          child: Builder(
            builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.end, children: [
                      Text(label, key: const Key('runwalk-phase'), style: context.pageTitleStyle(compact ? 24 : 28)),
                      Text(counting ? '$left' : l.runTimeLeft(ltr(phaseClock(left))), key: const Key('runwalk-phase-left'),
                          style: context.sansStyle(counting ? 24 : 17, weight: FontWeight.w700, color: counting ? context.c.accent : null)),
                      if (round != null) Text(round, style: context.sansStyle(15, color: context.c.secondary)),
                    ]),
                  ),
                ),
                if (!narrow) skip,
              ]),
              if (narrow) Align(alignment: AlignmentDirectional.centerStart, child: skip),
              if (!compact) ...[
                const SizedBox(height: 6),
                PhaseStrip(plan: plan, current: pos.index),
                if (next != null) Padding(padding: const EdgeInsets.only(top: 4), child: ExcludeSemantics(child: Text(l.runNextPhase(phaseName(l, next.kind), ltr(phaseClock(next.seconds))), style: context.caption))),
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
              Text(context.l10n.runIntervalsFinished, style: context.pageTitleStyle(24)),
              Text(context.l10n.runIntervalsStillRecording, style: context.sansStyle(15, color: context.c.secondary)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 8, children: [
                SecondaryButton(context.l10n.runContinueFreely, key: const Key('runwalk-continue-free'), expand: false, onPressed: () => ref.read(recorderProvider.notifier).continueFreely()),
                PrimaryButton(context.l10n.runFinishAndReview, key: const Key('runwalk-finish-review'), expand: false, onPressed: () => ref.read(recorderProvider.notifier).finish()),
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
    if (cue != null && face) {
      // The real guide speaking: Leon or Leona's bust (the same rig as Today) with the bubble from the mouth, compact,
      // in the page. One widget for the whole recording, so a new message changes the words and the guide nods; it
      // never re-enters. Reduce Motion is the rig's own. Read once by screen readers as each message arrives.
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          liveRegion: true, container: true, label: cue.text,
          child: ExcludeSemantics(
            child: CoachSpeech(
              key: const Key('runwalk-coach-line'), say: CoachSay(cue.text), portrait: const Size(58, 72), frame: RigFrame.edge, bleed: context.inset,
              ack: cue.key.hashCode,
            ),
          ),
        ),
      );
    }
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
    final l = context.l10n;
    return Column(key: const Key('personal-bests'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.runPersonalBests, style: context.sansStyle(18, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      GroupCard(children: [
        for (final bm in benchmarks)
          if (types.contains(bm.type))
            () {
              final best = b.by[bm.id];
              return GroupRow(
                key: Key('best-${bm.id}'), icon: bm.longest ? Icons.straighten : Icons.timer_outlined, title: benchmarkLabel(l, bm),
                subtitle: best == null ? l.runBestNotSet : '${activityName(best.run)} · ${shortDate(best.run.dayKey)}',
                value: best == null ? '—' : bm.longest ? unit.distance(best.value) : ltr(clockOf(best.value)),
                onTap: best == null ? null : () => push(context, ActivityDetailScreen(runId: best.run.id)),
              );
            }(),
      ]),
      const SizedBox(height: 6),
      Text(unchecked > 0 ? '${l.runBestsFootnote} ${l.runBestsUnchecked(unchecked)}' : l.runBestsFootnote, style: context.caption),
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
    final l = context.l10n;
    final shown = [
      for (final bm in benchmarks)
        if (types.contains(bm.type) && b.by[bm.id] != null) '${benchmarkLabel(l, bm)} ${bm.longest ? unit.distance(b.by[bm.id]!.value) : ltr(clockOf(b.by[bm.id]!.value))}',
    ];
    return GroupCard(children: [
      GroupRow(
        key: const Key('history-bests'), icon: Icons.emoji_events_outlined, title: l.runPersonalBests,
        subtitle: shown.isEmpty ? l.runBestsNoneYet : shown.take(2).join(' · '),
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
  Widget build(BuildContext context) => AppPage(title: context.l10n.runPersonalBests, children: [PersonalBestsCard(types: types)]);
}
