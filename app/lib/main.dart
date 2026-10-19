import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/appearance.dart';
import 'core/compatibility.dart';
import 'core/device_prefs.dart';
import 'data/db.dart';
import 'data/session.dart';
import 'features/activity/move_prefs.dart';
import 'features/coach/coach_prefs.dart';
import 'features/nutrition/water.dart';
import 'features/weather/weather.dart';

class SecureSecretStore implements SecretStore {
  const SecureSecretStore();
  // After the first unlock since the phone started, not only while it is unlocked: GoHard keeps syncing during a run with
  // the screen locked, and a refresh token rotated then must be saved, or the next start finds only the revoked one.
  // Still this phone's encrypted keychain; reads fall back to items saved under the previous setting.
  static const _storage = FlutterSecureStorage(iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock));
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
  final devicePrefs = DevicePrefsStore(const SecureSecretStore());
  await devicePrefs.restore();
  // Leon or Leona and the coaching hints, so the first frame already shows the chosen guide.
  final coachPrefs = CoachPrefsStore(const SecureSecretStore());
  await coachPrefs.restore();
  final trackingPrefs = TrackingPrefsStore(const SecureSecretStore());
  await trackingPrefs.restore();
  // Run / Walk voice, intervals and steps choices.
  final movePrefs = MovePrefsStore(const SecureSecretStore());
  await movePrefs.restore();
  // A confirmed "this build is too old" survives a restart, including one with no connection.
  final compatibility = CompatibilityStore(const SecureSecretStore());
  await compatibility.restore();
  // The Today background choice and the last weather answer, so Today opens with the scene it had.
  final weatherPrefs = await restoreWeatherPrefs(const SecureSecretStore());
  runApp(ProviderScope(
    retry: (_, _) => null,
    overrides: [dbProvider.overrideWithValue(db), sessionsProvider.overrideWithValue(sessions), appearanceStoreProvider.overrideWithValue(appearance),
      devicePrefsStoreProvider.overrideWithValue(devicePrefs), coachPrefsStoreProvider.overrideWithValue(coachPrefs), trackingPrefsStoreProvider.overrideWithValue(trackingPrefs),
      movePrefsStoreProvider.overrideWithValue(movePrefs),
      compatibilityStoreProvider.overrideWithValue(compatibility), weatherPrefs],
    child: const GoHardApp(),
  ));
}
