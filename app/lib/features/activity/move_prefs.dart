import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show ownerProvider;
import '../../data/session.dart';
import 'intervals.dart';

/// Spoken updates during a recording: by distance, by active time, or none (phase prompts are separate).
enum UpdateMode { off, distance, time }

/// Run / Walk choices kept on this phone (docs/RUN_WALK.md › Voice and alerts, › Intervals, › Steps): never part of
/// the account. Voice is off until the person turns it on. Steps are turned on per account, as is the daily goal.
@immutable
class MovePrefs {
  const MovePrefs({
    this.voice = false, this.updates = UpdateMode.distance, this.everyDistance = 1, this.everyMinutes = 5, this.vibrate = true, this.countdown = true,
    this.voiceName, this.voiceLocale, this.plan, this.intervals = false, this.steps = const {}, this.stepGoals = const {}, this.stepsHidden = const {},
  });

  /// Spoken announcements (phase changes, updates, personal bests) in the phone's own voice. Off by default.
  final bool voice;
  final UpdateMode updates;

  /// Every this many km or miles (the unit chosen in Me), or every this many minutes of active time.
  final double everyDistance;
  final int everyMinutes;

  /// A vibration as an interval phase changes, and a short countdown before it.
  final bool vibrate, countdown;

  /// The installed voice chosen for the coach, or null for the phone's default voice.
  final String? voiceName, voiceLocale;

  /// The saved interval setup, reused without retyping, and whether Ready starts with it.
  final IntervalPlan? plan;
  final bool intervals;

  /// Accounts that turned steps on, and their optional daily goals.
  final Set<String> steps;
  final Map<String, int> stepGoals;

  /// Accounts that chose not to show the Steps tile on Today. A display choice only: counting and permission stay as
  /// they are.
  final Set<String> stepsHidden;

  static const distanceChoices = [0.5, 1.0, 2.0], minuteChoices = [5, 10, 15];

  MovePrefs copy({bool? voice, UpdateMode? updates, double? everyDistance, int? everyMinutes, bool? vibrate, bool? countdown,
          (String?, String?)? voiceChoice, IntervalPlan? plan, bool? intervals, Set<String>? steps, Map<String, int>? stepGoals, Set<String>? stepsHidden}) =>
      MovePrefs(
        voice: voice ?? this.voice, updates: updates ?? this.updates, everyDistance: everyDistance ?? this.everyDistance, everyMinutes: everyMinutes ?? this.everyMinutes,
        vibrate: vibrate ?? this.vibrate, countdown: countdown ?? this.countdown, voiceName: voiceChoice == null ? voiceName : voiceChoice.$1,
        voiceLocale: voiceChoice == null ? voiceLocale : voiceChoice.$2, plan: plan ?? this.plan, intervals: intervals ?? this.intervals,
        steps: steps ?? this.steps, stepGoals: stepGoals ?? this.stepGoals, stepsHidden: stepsHidden ?? this.stepsHidden,
      );

  Map<String, dynamic> toJson() => {
        'voice': voice, 'updates': updates.name, 'everyDistance': everyDistance, 'everyMinutes': everyMinutes, 'vibrate': vibrate, 'countdown': countdown,
        'voiceName': voiceName, 'voiceLocale': voiceLocale, 'plan': plan?.toJson(), 'intervals': intervals, 'steps': [...steps], 'stepGoals': stepGoals, 'stepsHidden': [...stepsHidden],
      };

  static MovePrefs fromJson(Map<String, dynamic> j) {
    final d = (j['everyDistance'] as num?)?.toDouble();
    final m = (j['everyMinutes'] as num?)?.toInt();
    return MovePrefs(
      voice: j['voice'] == true, updates: UpdateMode.values.asNameMap()[j['updates']] ?? UpdateMode.distance,
      everyDistance: distanceChoices.contains(d) ? d! : 1, everyMinutes: minuteChoices.contains(m) ? m! : 5,
      vibrate: j['vibrate'] != false, countdown: j['countdown'] != false, voiceName: j['voiceName'] as String?, voiceLocale: j['voiceLocale'] as String?,
      plan: IntervalPlan.fromJson(j['plan']), intervals: j['intervals'] == true && IntervalPlan.fromJson(j['plan']) != null,
      steps: {...(j['steps'] as List? ?? const []).whereType<String>()},
      stepGoals: {for (final e in ((j['stepGoals'] as Map?) ?? const {}).entries) if (e.value is int && (e.value as int) > 0) e.key.toString(): e.value as int},
      stepsHidden: {...(j['stepsHidden'] as List? ?? const []).whereType<String>()},
    );
  }

  @override
  bool operator ==(Object other) => other is MovePrefs && jsonEncode(other.toJson()) == jsonEncode(toJson());
  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

class MovePrefsStore {
  MovePrefsStore(this._store);
  static const _key = 'gohard.rebuild.move';
  final SecretStore _store;
  MovePrefs value = const MovePrefs();

  Future<void> restore() async {
    try {
      final raw = await _store.read(_key);
      if (raw != null) value = MovePrefs.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } on Object {
      // An unreadable preference is not worth failing startup for; the defaults apply.
    }
  }

  Future<void> save() => _store.write(_key, jsonEncode(value.toJson()));
}

/// Overridden at startup with the restored store. Left alone (tests), it is an empty in-memory one.
final movePrefsStoreProvider = Provider<MovePrefsStore>((_) => MovePrefsStore(MemorySecretStore()));

class MovePrefsController extends Notifier<MovePrefs> {
  @override
  MovePrefs build() => ref.watch(movePrefsStoreProvider).value;

  void set(MovePrefs next) {
    ref.read(movePrefsStoreProvider).value = next;
    state = next;
    ref.read(movePrefsStoreProvider).save().ignore(); // already applied; a failed write only means it is chosen again
  }

  void update(MovePrefs Function(MovePrefs) f) => set(f(state));

  void setSteps(String owner, bool on) => update((p) => p.copy(steps: on ? {...p.steps, owner} : ({...p.steps}..remove(owner))));
  void setStepsOnToday(String owner, bool show) => update((p) => p.copy(stepsHidden: show ? ({...p.stepsHidden}..remove(owner)) : {...p.stepsHidden, owner}));
  void setStepGoal(String owner, int? goal) => update((p) => p.copy(stepGoals: goal == null || goal <= 0 ? ({...p.stepGoals}..remove(owner)) : {...p.stepGoals, owner: goal}));
}

final movePrefsProvider = NotifierProvider<MovePrefsController, MovePrefs>(MovePrefsController.new);

/// Whether the signed-in account turned steps on, on this phone.
final stepsEnabledProvider = Provider<bool>((ref) {
  final owner = ref.watch(ownerProvider);
  return owner != null && ref.watch(movePrefsProvider.select((p) => p.steps.contains(owner)));
});

/// Whether Today shows the Steps tile for the signed-in account: shown unless hidden, whether or not steps are on (off
/// is when Today offers to turn them on).
final stepsOnTodayProvider = Provider<bool>((ref) {
  final owner = ref.watch(ownerProvider);
  return owner != null && !ref.watch(movePrefsProvider.select((p) => p.stepsHidden.contains(owner)));
});

final stepGoalProvider = Provider<int?>((ref) {
  final owner = ref.watch(ownerProvider);
  return owner == null ? null : ref.watch(movePrefsProvider.select((p) => p.stepGoals[owner]));
});
