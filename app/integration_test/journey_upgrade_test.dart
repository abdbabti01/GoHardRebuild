import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Upgrade from the version where appearance was an account field. The state that version left on a phone is
/// reproduced for real: a signed-in session in the platform's secure store, the account's appearance saved the way
/// the old Me screen saved it, and no device appearance record. The app is then started again, as after an update.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  const key = 'gohard.rebuild.appearance';

  testWidgets('upgrade_keeps_the_chosen_light_or_dark', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Upgrade Tester');
    ProviderContainer scope() => ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    Brightness shown() => Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    expect(await storage.read(key: key), 'blue|', reason: 'a fresh install records its default at first launch');
    expect(scope().read(appearanceProvider), const Appearance(Accent.blue, ThemeMode.system));

    for (final (old, mode) in [('dark', ThemeMode.dark), ('light', ThemeMode.light)]) {
      // What the old version did when Dark or Light was chosen in Me.
      await j.waitUntil(() async => scope().read(profileProvider).value != null, what: 'the profile on this phone');
      final profile = scope().read(profileProvider).value!;
      await scope().read(profileRepositoryProvider).update(profile, appearance: old);
      await j.waitUntil(() async => scope().read(profileProvider).value?.appearance == old, what: 'the account appearance saved as $old');
      await storage.delete(key: key); // the old version had no device record

      await tester.pumpWidget(const SizedBox()); // the old process ends: nothing in memory carries over
      await app.main(); // the updated app starts over the same signed-in install
      await j.waitFor(find.byKey(const Key('nav-me')), what: 'the signed-in app after the update');
      await j.waitUntil(() async => scope().read(appearanceProvider).mode == mode, what: 'the old $old choice carried over', seconds: 20);
      await j.settle(6);
      expect(shown(), mode == ThemeMode.dark ? Brightness.dark : Brightness.light);
      expect(await storage.read(key: key), 'blue|${mode.name}', reason: 'carried over once and saved on the device');
      await j.tapKey('nav-me');
      await j.reveal(find.byKey(const Key('me-appearance')));
      expect(find.text('Blue · ${old == 'dark' ? 'Dark' : 'Light'}'), findsOneWidget);
      await j.shot('80-upgrade-kept-$old');
    }

    // A choice made on this device then stands, whatever the account still says (it says light).
    await j.tapKey('me-appearance');
    await j.tapKey('appearance-dark');
    await j.tapKey('accent-green');
    await tester.pumpWidget(const SizedBox());
    await app.main();
    await j.waitFor(find.byKey(const Key('nav-me')));
    await j.settle(8);
    expect(scope().read(appearanceProvider), const Appearance(Accent.green, ThemeMode.dark));
    expect(shown(), Brightness.dark);
    await j.shot('81-restart-keeps-device-choice');
  });
}
