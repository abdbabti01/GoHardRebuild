import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/body/body_metrics.dart';
import 'package:gohard_rebuild/features/me/me_screen.dart';
import 'package:gohard_rebuild/features/me/reminders.dart';

import 'ui_support.dart';

const _day = '2026-10-11';

/// Records every replacement the app asks for.
class _Scheduler implements ReminderScheduler {
  final calls = <List<int>>[];
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool?> notificationsAllowed() async => true;
  @override
  Future<void> replaceAll(List<Notice> notices) async => calls.add([for (final n in notices) n.id]);
}

void main() {
  testWidgets('Me › Language opens the picker; العربية turns the page RTL at once, on the same tab', (tester) async {
    final container = await pumpApp(tester, [...(await tester.runAsync(() => overridesFor(day: _day)))!, reminderSchedulerProvider.overrideWithValue(_Scheduler())],
        size: const Size(390, 1600));
    await tester.tap(find.byKey(const Key('nav-me')));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('me-language'));
    await tester.ensureVisible(row);
    expect(find.descendant(of: row, matching: find.text('Language')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('System · English')), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-ar')));
    await tester.pumpAndSettle();

    expect(container.read(devicePrefsProvider).language, AppLanguage.ar);
    expect(find.byType(MeScreen), findsOneWidget, reason: 'still on Me');
    expect(Directionality.of(tester.element(find.byType(MeScreen))), TextDirection.rtl);
    expect(find.text('حسابي'), findsWidgets, reason: 'Me is now named in Arabic');
    expect(tester.takeException(), isNull);
  });

  test('the choice survives a restart through the device store', () async {
    final store = MemorySecretStore();
    final first = ProviderContainer(overrides: [devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(store))]);
    first.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.ar);
    await Future<void>.delayed(Duration.zero);
    first.dispose();

    final restored = DevicePrefsStore(store);
    await restored.restore();
    final again = ProviderContainer(overrides: [devicePrefsStoreProvider.overrideWithValue(restored)]);
    addTearDown(again.dispose);
    expect(again.read(devicePrefsProvider).language, AppLanguage.ar);
    expect(again.read(appLocaleProvider), const Locale('ar'));
  });

  test('System resolves the phone list; an explicit choice wins', () {
    expect(resolveLocale(AppLanguage.system, const [Locale('fr', 'FR')]), const Locale('fr', 'CA'));
    expect(resolveLocale(AppLanguage.system, const [Locale('ar', 'EG')]), const Locale('ar'));
    expect(resolveLocale(AppLanguage.system, const [Locale('de')]), const Locale('en'));
    expect(resolveLocale(AppLanguage.en, const [Locale('ar', 'EG')]), const Locale('en'));
  });

  test('body fields read French and Arabic decimals as the same canonical value', () {
    const units = BodyUnits(LoadUnit.kg, LengthUnit.cm);
    for (final typed in ['82.5', '82,5', '٨٢٫٥', '۸۲٫۵']) {
      expect(readField(BodyField.weight, typed, null, units).value, 82.5, reason: typed);
    }
    expect(readField(BodyField.weight, '1 082', null, units).error, BodyFieldError.notANumber, reason: 'no grouping in a body field');
  });

  test('a language change re-schedules the same reminders with the same IDs', () async {
    final scheduler = _Scheduler();
    final plan = blockPlan(start: '2026-10-05');
    final container = ProviderContainer(overrides: [
      ...await overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1', profile: {'remindersEnabled': true}),
      reminderSchedulerProvider.overrideWithValue(scheduler),
    ]);
    addTearDown(container.dispose);
    container.listen(reminderSyncProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final before = scheduler.calls.last;
    expect(before, isNotEmpty);

    container.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.frCA);
    await Future<void>.delayed(Duration.zero);
    container.read(reminderSyncProvider);
    final count = scheduler.calls.length;
    expect(count, greaterThan(1), reason: 'reworded reminders were scheduled again');
    expect(scheduler.calls.last, before, reason: 'same IDs, days and order: replaced, never duplicated');
  });
}
