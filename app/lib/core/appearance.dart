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

  /// True on the first launch of this version over an install that was already signed in. Appearance used to be an
  /// account field (Dark, Light or Match this phone), so that one launch carries the account's value over.
  bool migratesAccountMode = false;

  /// [signedIn]: whether a session was restored at startup, which is what tells an upgrade from a fresh install.
  Future<void> restore({required bool signedIn}) async {
    try {
      final raw = await _store.read(_key);
      final parts = raw?.split('|') ?? const <String>[];
      if (parts.isNotEmpty) accent = Accent.parse(parts[0]);
      if (parts.length > 1) mode = ThemeMode.values.asNameMap()[parts[1]];
      if (raw == null) {
        migratesAccountMode = signedIn;
        // A fresh install records its default now, so signing in later never looks like an upgrade.
        if (!signedIn) await save();
      }
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

  /// Upgrade only: the look this install had before (Dark, Light or following the phone) is kept exactly, once.
  /// A choice already made on this device is never overwritten, and a fresh install stays on System.
  void adoptAccountAppearance(String? appearance) {
    final mode = switch (appearance) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, 'system' => ThemeMode.system, _ => null };
    if (_saved.migratesAccountMode && mode != null) _apply(_saved.accent, mode);
  }

  void _apply(Accent accent, ThemeMode mode) {
    _saved
      ..migratesAccountMode = false
      ..accent = accent
      ..mode = mode;
    state = Appearance(accent, mode);
    _saved.save().ignore(); // the look has already changed; a failed write only means it is asked for again
  }
}

final appearanceProvider = NotifierProvider<AppearanceController, Appearance>(AppearanceController.new);
