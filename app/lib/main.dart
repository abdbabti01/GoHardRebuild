import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/appearance.dart';
import 'core/compatibility.dart';
import 'data/db.dart';
import 'data/session.dart';

class SecureSecretStore implements SecretStore {
  const SecureSecretStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDb(driftDatabase(name: 'gohard_rebuild'));
  final sessions = SessionManager(const SecureSecretStore());
  // Both are read before the first frame: the app opens signed in, and in the look that was chosen.
  final appearance = AppearanceStore(const SecureSecretStore());
  await sessions.restore();
  await appearance.restore(signedIn: sessions.current != null);
  // A confirmed "this build is too old" survives a restart, including one with no connection.
  final compatibility = CompatibilityStore(const SecureSecretStore());
  await compatibility.restore();
  runApp(ProviderScope(
    retry: (_, _) => null,
    overrides: [dbProvider.overrideWithValue(db), sessionsProvider.overrideWithValue(sessions), appearanceStoreProvider.overrideWithValue(appearance),
      compatibilityStoreProvider.overrideWithValue(compatibility)],
    child: const GoHardApp(),
  ));
}
