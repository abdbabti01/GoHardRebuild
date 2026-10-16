import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show ownerProvider;
import '../../data/session.dart';
import 'coach_avatar.dart';

/// The coach's look and coaching hints, for this phone only.
@immutable
class CoachPrefs {
  const CoachPrefs({this.guide = CoachGuide.leon, this.hintsEnabled = true, this.dismissed = const {}, this.onToday = true, this.greeted});
  final CoachGuide guide;
  final bool hintsEnabled;

  /// Me › Appearance › Show coach on Today: the companion beside Today's greeting. The only way to remove it; off,
  /// Ask GoHard is still the guide, on Train.
  final bool onToday;

  /// `owner|day` (the phone's local day) of the last greeting played. One is enough: a greeting belongs to one account
  /// on one day on this phone, and another account or day is a new key. (Builds before 16 Oct 2026 also kept a "hidden
  /// for today"; it is no longer read or written: Today's companion stays until Show coach on Today is turned off.)
  final String? greeted;

  static String dayKey(String owner, String day) => '$owner|$day';

  /// Whether Today may play the companion's greeting for [owner] on [day]: once a day. Show coach on Today governs
  /// it; Coaching hints govern the introductions elsewhere (docs/COACH.md › Companion › When the coach appears).
  bool mayGreet(String owner, String day) => greeted != dayKey(owner, day);

  /// Whether [owner] has already had the one introduction of [context] (a stable id such as `builder.structure`).
  bool seen(String owner, String context) => dismissed.contains('$owner|$context');

  /// Whether an automatic introduction of [context] may appear for [owner] now that it is in view.
  bool mayIntroduce(String owner, String context) => hintsEnabled && !seen(owner, context);

  CoachPrefs copy({CoachGuide? guide, bool? hintsEnabled, Set<String>? dismissed, bool? onToday, String? greeted}) => CoachPrefs(
      guide: guide ?? this.guide, hintsEnabled: hintsEnabled ?? this.hintsEnabled, dismissed: dismissed ?? this.dismissed, onToday: onToday ?? this.onToday,
      greeted: greeted ?? this.greeted);

  /// Introductions already shown, as `owner|context`, so one account's never hide or reveal another's. None shows
  /// again until "Show coaching hints again". (Entries without an owner come from an older build and are ignored.)
  final Set<String> dismissed;

  @override
  bool operator ==(Object other) => other is CoachPrefs && other.guide == guide && other.hintsEnabled == hintsEnabled && setEquals(other.dismissed, dismissed) &&
      other.onToday == onToday && other.greeted == greeted;
  @override
  int get hashCode => Object.hash(guide, hintsEnabled, Object.hashAllUnordered(dismissed), onToday, greeted);
}

/// Kept in the same platform store as the appearance and read before the first frame. A presentation choice for this
/// phone: never part of the account, never sent anywhere, and never inferred from a name, photo or profile.
class CoachPrefsStore {
  CoachPrefsStore(this._store);
  static const _key = 'gohard.rebuild.coach';
  final SecretStore _store;

  CoachPrefs value = const CoachPrefs();

  Future<void> restore() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      value = CoachPrefs(
        guide: CoachGuide.values.asNameMap()[j['guide']] ?? CoachGuide.leon,
        hintsEnabled: j['hints'] != false,
        dismissed: {...(j['dismissed'] as List? ?? const []).whereType<String>()},
        onToday: j['today'] != false, greeted: j['greeted'] as String?,
      );
    } on Object {
      // An unreadable preference is not worth failing startup for; the defaults apply.
    }
  }

  Future<void> save() => _store.write(_key, jsonEncode({'guide': value.guide.name, 'hints': value.hintsEnabled, 'dismissed': [...value.dismissed], 'today': value.onToday, 'greeted': value.greeted}));
}

/// Overridden at startup with the restored store. Left alone (tests), it is an empty in-memory one.
final coachPrefsStoreProvider = Provider<CoachPrefsStore>((_) => CoachPrefsStore(MemorySecretStore()));

class CoachPrefsController extends Notifier<CoachPrefs> {
  @override
  CoachPrefs build() => ref.watch(coachPrefsStoreProvider).value;

  void setGuide(CoachGuide guide) => _apply(state.copy(guide: guide));
  void setHints(bool on) => _apply(state.copy(hintsEnabled: on));
  void setOnToday(bool on) => _apply(state.copy(onToday: on));

  /// The greeting for [owner] on [day] has played: not again that day on this phone.
  void markGreeted(String owner, String day) {
    if (state.greeted != CoachPrefs.dayKey(owner, day)) _apply(state.copy(greeted: CoachPrefs.dayKey(owner, day)));
  }


  /// [owner] has seen the introduction of [context]: it does not appear by itself again.
  void markSeen(String owner, String context) {
    if (!state.seen(owner, context)) _apply(state.copy(dismissed: {...state.dismissed, '$owner|$context'}));
  }

  /// "Show coaching hints again": every introduction may appear once more for [owner]. Other accounts, the guide and
  /// the on/off choices are kept.
  void resetHints(String owner) => _apply(state.copy(dismissed: {for (final k in state.dismissed) if (k.contains('|') && !k.startsWith('$owner|')) k}));

  void _apply(CoachPrefs next) {
    ref.read(coachPrefsStoreProvider).value = next;
    state = next;
    ref.read(coachPrefsStoreProvider).save().ignore(); // already applied; a failed write only means it is asked for again
  }
}

final coachPrefsProvider = NotifierProvider<CoachPrefsController, CoachPrefs>(CoachPrefsController.new);

/// A workout just finished with training in it, from the finish's own success path (never from a sync, a rebuild
/// or a restart: it lives in memory only). Today acknowledges it once, then marks it [played].
typedef WorkoutSaved = ({String workoutId, String day, bool played});

class WorkoutSavedCue extends Notifier<WorkoutSaved?> {
  @override
  WorkoutSaved? build() {
    ref.watch(ownerProvider); // another sign-in starts with nothing to celebrate
    return null;
  }

  void saved(String workoutId, String day) => state = (workoutId: workoutId, day: day, played: false);
  void played() {
    if (state case final s? when !s.played) state = (workoutId: s.workoutId, day: s.day, played: true);
  }
}

final workoutSavedProvider = NotifierProvider<WorkoutSavedCue, WorkoutSaved?>(WorkoutSavedCue.new);
