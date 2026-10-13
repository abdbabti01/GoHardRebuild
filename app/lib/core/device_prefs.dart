import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session.dart';

/// Motion: follow the phone's Reduce Motion setting, or always reduce in this app.
enum MotionPref {
  device('Device'),
  reduced('Reduced');

  const MotionPref(this.label);
  final String label;
}

/// Haptics: whatever the phone allows, or none from this app.
enum HapticsPref {
  device('Device'),
  off('Off');

  const HapticsPref(this.label);
  final String label;
}

@immutable
class DevicePrefs {
  const DevicePrefs({this.motion = MotionPref.device, this.haptics = HapticsPref.device});
  final MotionPref motion;
  final HapticsPref haptics;

  @override
  bool operator ==(Object other) => other is DevicePrefs && other.motion == motion && other.haptics == haptics;
  @override
  int get hashCode => Object.hash(motion, haptics);
}

/// Motion and haptics kept on this device, in the same platform store as the session and the appearance. They are
/// read before the first frame. They are presentation choices for this phone, so they are never part of the account.
class DevicePrefsStore {
  DevicePrefsStore(this._store);
  static const _key = 'gohard.rebuild.device-prefs';
  final SecretStore _store;

  MotionPref motion = MotionPref.device;
  HapticsPref haptics = HapticsPref.device;

  Future<void> restore() async {
    try {
      final parts = (await _store.read(_key))?.split('|') ?? const <String>[];
      if (parts.isNotEmpty) motion = MotionPref.values.asNameMap()[parts[0]] ?? MotionPref.device;
      if (parts.length > 1) haptics = HapticsPref.values.asNameMap()[parts[1]] ?? HapticsPref.device;
    } on Object {
      // An unreadable preference is not worth failing startup for; the defaults apply.
    }
  }

  Future<void> save() => _store.write(_key, '${motion.name}|${haptics.name}');
}

/// Overridden at startup with the restored store. Left alone (tests), it is an empty in-memory one.
final devicePrefsStoreProvider = Provider<DevicePrefsStore>((_) => DevicePrefsStore(MemorySecretStore()));

class DevicePrefsController extends Notifier<DevicePrefs> {
  DevicePrefsStore get _saved => ref.read(devicePrefsStoreProvider);

  @override
  DevicePrefs build() {
    final s = ref.watch(devicePrefsStoreProvider);
    Haptics.enabled = s.haptics == HapticsPref.device;
    return DevicePrefs(motion: s.motion, haptics: s.haptics);
  }

  void setMotion(MotionPref motion) => _apply(motion, _saved.haptics);
  void setHaptics(HapticsPref haptics) => _apply(_saved.motion, haptics);

  void _apply(MotionPref motion, HapticsPref haptics) {
    _saved
      ..motion = motion
      ..haptics = haptics;
    Haptics.enabled = haptics == HapticsPref.device;
    state = DevicePrefs(motion: motion, haptics: haptics);
    _saved.save().ignore(); // already applied; a failed write only means it is asked for again
  }
}

final devicePrefsProvider = NotifierProvider<DevicePrefsController, DevicePrefs>(DevicePrefsController.new);

/// Applies the Motion preference to everything below it: "Reduced" is presented to the app exactly as the phone's
/// own Reduce Motion (`MediaQuery.disableAnimations`), so `context.motion`, `push`, sheets and rails all honour it
/// with no second code path. It sits in `MaterialApp.builder`, above the navigator, so changing it rebuilds nothing
/// but the widgets that read the setting: routes, forms, workouts and runs keep their state.
class DevicePrefsScope extends ConsumerWidget {
  const DevicePrefsScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduced = ref.watch(devicePrefsProvider.select((p) => p.motion == MotionPref.reduced));
    final media = MediaQuery.of(context);
    return MediaQuery(data: media.copyWith(disableAnimations: reduced || media.disableAnimations), child: child);
  }
}

/// The one way to give touch feedback. Every call does nothing while Haptics is Off in Me > Motion & haptics.
/// Use it for something the person just did (a selection, a confirmed action); never for background sync, a value
/// arriving from the account, or keystrokes.
///
///     Haptics.selection();   // a segment, tab, choice or toggle changed
///     Haptics.confirm();     // a deliberate action was accepted (a set recorded, a barcode read)
abstract final class Haptics {
  /// Kept equal to the saved preference by [DevicePrefsController]; the phone's own setting still applies on top.
  static bool enabled = true;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void confirm() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
