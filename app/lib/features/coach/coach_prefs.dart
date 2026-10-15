import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/session.dart';
import 'coach_avatar.dart';

/// The coach's look and coaching hints, for this phone only.
@immutable
class CoachPrefs {
  const CoachPrefs({this.guide = CoachGuide.leon, this.hintsEnabled = true, this.dismissed = const {}});
  final CoachGuide guide;
  final bool hintsEnabled;

  /// Hints already shown, closed or acted on. None of them shows again until "Show coaching hints again".
  final Set<String> dismissed;

  @override
  bool operator ==(Object other) => other is CoachPrefs && other.guide == guide && other.hintsEnabled == hintsEnabled && setEquals(other.dismissed, dismissed);
  @override
  int get hashCode => Object.hash(guide, hintsEnabled, Object.hashAllUnordered(dismissed));
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
      );
    } on Object {
      // An unreadable preference is not worth failing startup for; the defaults apply.
    }
  }

  Future<void> save() => _store.write(_key, jsonEncode({'guide': value.guide.name, 'hints': value.hintsEnabled, 'dismissed': [...value.dismissed]}));
}

/// Overridden at startup with the restored store. Left alone (tests), it is an empty in-memory one.
final coachPrefsStoreProvider = Provider<CoachPrefsStore>((_) => CoachPrefsStore(MemorySecretStore()));

class CoachPrefsController extends Notifier<CoachPrefs> {
  @override
  CoachPrefs build() => ref.watch(coachPrefsStoreProvider).value;

  void setGuide(CoachGuide guide) => _apply(CoachPrefs(guide: guide, hintsEnabled: state.hintsEnabled, dismissed: state.dismissed));
  void setHints(bool on) => _apply(CoachPrefs(guide: state.guide, hintsEnabled: on, dismissed: state.dismissed));

  /// Marks a hint seen: it does not show again in that flow.
  void dismiss(String hintId) {
    if (!state.dismissed.contains(hintId)) _apply(CoachPrefs(guide: state.guide, hintsEnabled: state.hintsEnabled, dismissed: {...state.dismissed, hintId}));
  }

  /// "Show coaching hints again": every hint may show once more. The guide and the on/off choice are kept.
  void resetHints() => _apply(CoachPrefs(guide: state.guide, hintsEnabled: state.hintsEnabled));

  void _apply(CoachPrefs next) {
    ref.read(coachPrefsStoreProvider).value = next;
    state = next;
    ref.read(coachPrefsStoreProvider).save().ignore(); // already applied; a failed write only means it is asked for again
  }
}

final coachPrefsProvider = NotifierProvider<CoachPrefsController, CoachPrefs>(CoachPrefsController.new);
