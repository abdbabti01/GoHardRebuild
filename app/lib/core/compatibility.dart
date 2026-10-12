import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart' show transportProvider;
import '../data/models.dart';
import '../data/session.dart';
import 'config.dart';

/// What is known about this build and the account's server.
@immutable
class Compatibility {
  const Compatibility({this.requiredContract, this.capabilities});

  /// The oldest contract the server still accepts, when a check has confirmed it is newer than this build's.
  final int? requiredContract;

  /// What the server says it supports. Null until a check has answered: unknown is not "unsupported".
  final Set<String>? capabilities;

  /// Only a confirmed answer blocks. An unreachable server never does.
  bool get blocked => (requiredContract ?? 0) > AppConfig.contractVersion;
  bool supports(String capability) => capabilities?.contains(capability) ?? true;
}

/// Remembers a confirmed "this build is too old", in the same platform store as the session, so the block is
/// still there after a restart with no connection. It is cleared only by a later check that passes.
class CompatibilityStore {
  CompatibilityStore(this._store);
  static const _key = 'gohard.rebuild.required-contract';
  final SecretStore _store;
  int? requiredContract;

  Future<void> restore() async {
    try {
      requiredContract = int.tryParse(await _store.read(_key) ?? '');
    } on Object {
      // Unreadable means unknown, and unknown does not block.
    }
  }

  Future<void> save(int? required) async {
    requiredContract = required;
    try {
      required == null ? await _store.delete(_key) : await _store.write(_key, '$required');
    } on Object {
      // The block still holds for this run; it is simply asked for again next time.
    }
  }
}

final compatibilityStoreProvider = Provider<CompatibilityStore>((_) => CompatibilityStore(MemorySecretStore()));

class CompatibilityController extends Notifier<Compatibility> {
  static const timeout = Duration(seconds: 6);
  Future<void>? _checking;

  @override
  Compatibility build() => Compatibility(requiredContract: ref.watch(compatibilityStoreProvider).requiredContract);

  /// Asks the server once, without an account (the answer is the same for everyone), with a bounded wait. No answer, or one that cannot be read, changes nothing: the app
  /// carries on exactly as it was, including staying blocked if that was confirmed earlier.
  Future<void> check() => _checking ??= _check().whenComplete(() => _checking = null);

  Future<void> _check() async {
    final ApiResponse r;
    try {
      r = await ref.read(transportProvider).send('GET', '/capabilities').timeout(timeout);
    } on Object {
      return;
    }
    final data = r.data;
    if (!r.ok || data is! Map || data['minimumClientContract'] is! int) return;
    final minimum = data['minimumClientContract'] as int;
    final required = minimum > AppConfig.contractVersion ? minimum : null;
    final store = ref.read(compatibilityStoreProvider);
    if (store.requiredContract != required) await store.save(required);
    state = Compatibility(requiredContract: required, capabilities: {for (final c in (data as Json)['capabilities'] as List? ?? const []) '$c'});
  }
}

final compatibilityProvider = NotifierProvider<CompatibilityController, Compatibility>(CompatibilityController.new);
