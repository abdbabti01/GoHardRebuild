/// Run / Walk intervals (docs/RUN_WALK.md › Intervals). A plan is a list of timed phases; where a session is in it is
/// a pure function of the plan, the skips the person made and the recorder's active time, so a rebuild, a tab change,
/// a pause or a restart can never move it. Walk/recovery phases are recording time like any other: they are not pauses.
library;

import 'dart:math';

import '../../core/language.dart';

enum PhaseKind { warmup, run, walk, cooldown }

class IntervalPhase {
  const IntervalPhase(this.kind, this.seconds, {this.round});
  final PhaseKind kind;
  final int seconds;

  /// 1-based round for run and walk phases.
  final int? round;

  String get label => phaseName(currentL10n, kind);
}

class IntervalPlan {
  const IntervalPlan({this.warmup = 0, required this.run, required this.walk, required this.reps, this.cooldown = 0});
  final int warmup, run, walk, reps, cooldown;

  /// Editable starting point, after week 1 of the NHS Couch to 5K plan: a 5-minute brisk walk, then 60 seconds of
  /// running and 90 seconds of walking, 8 times (20 minutes), then a 5-minute walk to cool down.
  static const preset = IntervalPlan(warmup: 300, run: 60, walk: 90, reps: 8, cooldown: 300);

  static const maxPhase = 3600, maxWarm = 1800, maxReps = 30, minPhase = 10;

  List<IntervalPhase> get phases => [
        if (warmup > 0) IntervalPhase(PhaseKind.warmup, warmup),
        for (var r = 1; r <= reps; r++) ...[IntervalPhase(PhaseKind.run, run, round: r), IntervalPhase(PhaseKind.walk, walk, round: r)],
        if (cooldown > 0) IntervalPhase(PhaseKind.cooldown, cooldown),
      ];

  /// The programmed active time, in seconds.
  int get totalSeconds => warmup + reps * (run + walk) + cooldown;

  IntervalPlan copy({int? warmup, int? run, int? walk, int? reps, int? cooldown}) => IntervalPlan(
      warmup: warmup ?? this.warmup, run: run ?? this.run, walk: walk ?? this.walk, reps: reps ?? this.reps, cooldown: cooldown ?? this.cooldown);

  Map<String, dynamic> toJson() => {'warmup': warmup, 'run': run, 'walk': walk, 'reps': reps, 'cooldown': cooldown};

  /// Null for anything out of range, so a damaged record never produces a strange session.
  static IntervalPlan? fromJson(Object? j) {
    if (j is! Map) return null;
    int? v(String k) => (j[k] as num?)?.toInt();
    final p = IntervalPlan(warmup: v('warmup') ?? 0, run: v('run') ?? 0, walk: v('walk') ?? 0, reps: v('reps') ?? 0, cooldown: v('cooldown') ?? 0);
    bool phase(int s) => s >= minPhase && s <= maxPhase;
    bool edge(int s) => s == 0 || (s >= minPhase && s <= maxWarm);
    return phase(p.run) && phase(p.walk) && p.reps >= 1 && p.reps <= maxReps && edge(p.warmup) && edge(p.cooldown) ? p : null;
  }

  @override
  bool operator ==(Object other) => other is IntervalPlan && other.warmup == warmup && other.run == run && other.walk == walk && other.reps == reps && other.cooldown == cooldown;
  @override
  int get hashCode => Object.hash(warmup, run, walk, reps, cooldown);
}

/// Where a session is: the current phase, its time left, and whether the programmed phases are all done.
class IntervalPosition {
  const IntervalPosition({required this.index, required this.phase, required this.remainingMs, required this.done, required this.isLastRound});
  final int index;
  final IntervalPhase? phase;
  final int remainingMs;
  final bool done, isLastRound;
}

abstract final class IntervalClock {
  /// The position at [activeMs] of recording time. [skips] are the active times (ms) at which Skip phase was pressed:
  /// each ends the phase it falls in.
  static IntervalPosition at(IntervalPlan plan, List<int> skips, int activeMs) {
    final phases = plan.phases;
    final sorted = [...skips]..sort();
    var start = 0, k = 0;
    for (var i = 0; i < phases.length; i++) {
      var end = start + phases[i].seconds * 1000;
      while (k < sorted.length && sorted[k] < start) {
        k++;
      }
      if (k < sorted.length && sorted[k] < end) end = max(start, sorted[k++]);
      if (activeMs < end) {
        return IntervalPosition(index: i, phase: phases[i], remainingMs: end - activeMs, done: false, isLastRound: phases[i].round == plan.reps);
      }
      start = end;
    }
    return IntervalPosition(index: phases.length, phase: null, remainingMs: 0, done: true, isLastRound: true);
  }

  /// Each phase as it was recorded: its active seconds and whether it was skipped (ended early by the person).
  static List<({IntervalPhase phase, int seconds, bool skipped})> timeline(IntervalPlan plan, List<int> skips, int activeMs) {
    final phases = plan.phases;
    final sorted = [...skips]..sort();
    final out = <({IntervalPhase phase, int seconds, bool skipped})>[];
    var start = 0, k = 0;
    for (final p in phases) {
      if (activeMs <= start) break;
      var end = start + p.seconds * 1000;
      var skipped = false;
      while (k < sorted.length && sorted[k] < start) {
        k++;
      }
      if (k < sorted.length && sorted[k] < end) {
        end = max(start, sorted[k++]);
        skipped = true;
      }
      final stop = min(end, activeMs);
      out.add((phase: p, seconds: ((stop - start) / 1000).round(), skipped: skipped || stop < end));
      start = end;
    }
    return out;
  }
}

/// "Warm-up", "Échauffement", "إحماء".
String phaseName(AppLocalizations l, PhaseKind k) => switch (k) {
      PhaseKind.warmup => l.runPhaseWarmup,
      PhaseKind.run => l.runPhaseRun,
      PhaseKind.walk => l.runPhaseWalk,
      PhaseKind.cooldown => l.runPhaseCooldown,
    };

/// "1:30", "5:00", "45 s" for setup and the phase bar.
String phaseClock(int seconds) => seconds < 60 ? currentL10n.durationSeconds(seconds) : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// "2 minutes", "1 minute 30 seconds", "45 seconds" for speech and screen readers, in [l] (the resolved language).
String spokenDuration(int seconds, [AppLocalizations? l]) {
  l ??= currentL10n;
  final m = seconds ~/ 60, s = seconds % 60;
  if (m == 0) return l.runSpokenSeconds(s);
  return s == 0 ? l.runSpokenMinutes(m) : l.runSpokenMinutesSeconds(l.runSpokenMinutes(m), l.runSpokenSeconds(s));
}

/// What the coach says as a phase begins (docs/RUN_WALK.md › Intervals › Prompts).
String phaseCue(IntervalPosition p, [AppLocalizations? l]) {
  l ??= currentL10n;
  final ph = p.phase;
  if (ph == null) return l.runCueIntervalsFinished;
  final d = spokenDuration(ph.seconds, l);
  return switch (ph.kind) {
    PhaseKind.warmup => l.runCueWarmup(d),
    PhaseKind.run => p.isLastRound ? l.runCueFinalRun(d) : l.runCueRun(d),
    PhaseKind.walk => l.runCueWalk(d),
    PhaseKind.cooldown => l.runCueCooldown(d),
  };
}
