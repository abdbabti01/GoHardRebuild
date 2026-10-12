import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session.dart';
import 'theme.dart';

/// The two independent appearance choices: accent and mode.
@immutable
class Appearance {
  const Appearance(this.accent, this.mode);
  final Accent accent;
  final ThemeMode mode;

  @override
  bool operator ==(Object other) => other is Appearance && other.accent == accent && other.mode == mode;
  @override
  int get hashCode => Object.hash(accent, mode);
}

/// Appearance kept on this device, in the same platform store as the session. It is read before the first
/// frame, so the app never opens in one look and then switches to another.
class AppearanceStore {
  AppearanceStore(this._store);
  static const _key = 'gohard.rebuild.appearance';
  final SecretStore _store;

  Accent accent = Accent.blue;

  /// Null until a mode has been chosen on this device: a fresh install follows the phone.
  ThemeMode? mode;

  Future<void> restore() async {
    try {
      final parts = (await _store.read(_key))?.split('|') ?? const <String>[];
      if (parts.isNotEmpty) accent = Accent.parse(parts[0]);
      if (parts.length > 1) mode = ThemeMode.values.asNameMap()[parts[1]];
    } on Object {
      // An unreadable preference is not worth failing startup for; the defaults apply.
    }
  }

  Future<void> save() => _store.write(_key, '${accent.name}|${mode?.name ?? ''}');
}

/// Overridden at startup with the restored store. Left alone (tests), it is an empty in-memory one.
final appearanceStoreProvider = Provider<AppearanceStore>((_) => AppearanceStore(MemorySecretStore()));

class AppearanceController extends Notifier<Appearance> {
  AppearanceStore get _saved => ref.read(appearanceStoreProvider);

  @override
  Appearance build() {
    final s = ref.watch(appearanceStoreProvider);
    return Appearance(s.accent, s.mode ?? ThemeMode.system);
  }

  void setAccent(Accent accent) => _apply(accent, _saved.mode ?? ThemeMode.system);
  void setMode(ThemeMode mode) => _apply(_saved.accent, mode);

  /// An account that chose Light before this device had its own setting keeps Light. The account's "dark" was
  /// the old default rather than a choice, so it does not override following the phone.
  void adoptAccountAppearance(String? appearance) {
    if (_saved.mode == null && appearance == 'light') setMode(ThemeMode.light);
  }

  void _apply(Accent accent, ThemeMode mode) {
    _saved
      ..accent = accent
      ..mode = mode;
    state = Appearance(accent, mode);
    _saved.save().ignore(); // the look has already changed; a failed write only means it is asked for again
  }
}

final appearanceProvider = NotifierProvider<AppearanceController, Appearance>(AppearanceController.new);
