import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Daily goals from Today, optional water and Customize tracking on the device, in two runs of this file by
/// scripts\test-android.ps1 (a real process end between). Not part of the default run.
///
/// Phase 1: goals set from Today's Nutrition panel and read back on Eat and Me; water turned on; 250 mL and 330 mL
/// logged, the 330 corrected to 300 and then removed; a water goal set from the water sheet; then OFFLINE (the script
/// switches the emulator's network off on GOHARD_NET:off) 500 mL more, saved on the phone. The process then ends.
///
/// Phase 2, a new process, back online: the offline entry is still there, the queue reaches the account, a fresh pull
/// from the account shows exactly the two entries (no duplicate), hiding and showing water keeps them, the keyboard over
/// the water sheet. A recording (GOHARD_REC markers) shows goals, water logging and Customize tracking.
const _phase = String.fromEnvironment('GOHARD_PHASE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('goals, water and customize phase $_phase', (tester) async {
    final j = Journey(tester, binding);
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    // Closed by popping the sheet's own route: with the keyboard up a tall sheet covers the barrier a tap would hit.
    Future<void> closeSheet() async {
      FocusManager.instance.primaryFocus?.unfocus();
      if (find.byType(BottomSheet).evaluate().isNotEmpty) Navigator.of(tester.element(find.byType(BottomSheet).last)).pop();
      for (var i = 0; i < 24 && find.byType(BottomSheet).evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await j.settle(3);
    }

    Future<void> top() async {
      for (final e in find.byType(Scrollable).hitTestable().evaluate()) {
        final position = (e as StatefulElement).state as ScrollableState;
        if (position.position.axis == Axis.vertical && position.position.pixels > 0) position.position.jumpTo(0);
      }
      await j.settle(4);
    }

    // Customize tracking is in Eat (with the goals); the water line shows on Today and Eat.
    Future<void> setWater(bool on) async {
      await j.tapKey('nav-eat');
      // A tap while the keyboard is still leaving can land before the page settles: tap until the sheet is up.
      for (var i = 0; i < 4 && find.byKey(const Key('track-water')).evaluate().isEmpty; i++) {
        await j.tapKey('eat-customize');
        await j.settle(6);
      }
      await j.waitFor(find.byKey(const Key('track-water')));
      if (tester.widget<SwitchListTile>(find.byKey(const Key('track-water'))).value != on) await j.tapKey('track-water');
      await j.settle(2);
      await closeSheet();
      await j.tapKey('nav-today');
    }

    String waterTotal() => tester.widget<Text>(find.byKey(const Key('water-total')).first).data!;

    if (_phase == '1') {
      await j.start('Water Goals');
      await j.settle(8);
      await j.shot('water-01-today-no-goals');

      // --- Goals in Eat (Today shows progress only): the shared form, empty.
      expect(find.byKey(const Key('today-goals')), findsNothing);
      await j.tapKey('nav-eat');
      // Right after sign-up the link waits (disabled) until the account's profile, which holds the goals, has arrived.
      await j.waitUntil(() async => tester.widget<TextButton>(find.descendant(of: find.byKey(const Key('eat-goals')), matching: find.byType(TextButton))).onPressed != null,
          what: 'the profile to arrive so goals can be set');
      await j.tapKey('eat-goals');
      await j.waitFor(find.byKey(const Key('goal-calories')), what: 'the goals sheet');
      expect(tester.widget<TextField>(find.byKey(const Key('goal-calories'))).controller!.text, isEmpty);
      await j.type('goal-calories', '2200');
      await j.type('goal-protein', '140');
      await j.shot('water-02-goals-sheet-keyboard');
      await j.tapKey('goal-save');
      await j.waitFor(find.text('Edit goals'), what: 'Eat offering Edit goals');
      await j.tapKey('nav-today');
      await j.waitFor(find.text('Your daily goal: 2,200 kcal · 140 g protein'), what: 'Today reading the same goals');
      await j.tapKey('nav-me');
      await j.waitFor(find.text('2,200 kcal · 140 g protein'), what: 'Me reading the same goals');
      await j.tapKey('nav-today');
      await top();

      // --- Water: off until turned on; then logged, corrected and removed.
      expect(find.byKey(const Key('today-water')), findsNothing, reason: 'water starts off');
      await setWater(true);
      await j.waitFor(find.byKey(const Key('today-water')), what: 'the water row');
      await j.tapKey('water-quick-add');
      await j.waitFor(find.byKey(const Key('water-add-250')), what: 'the water sheet');
      await j.tapKey('water-add-250');
      await j.type('water-custom', '330');
      await j.tapKey('water-add-custom');
      await j.waitUntil(() async => tester.widget<Text>(find.byKey(const Key('water-sheet-total'))).data == '580 mL', what: '580 mL logged');
      await j.shot('water-03-sheet-logged');
      // The newest entry is listed first: correct it, then remove it.
      final newest = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('water-entry-')).first;
      await j.tap(newest);
      await j.waitFor(find.byKey(const Key('water-edit-field')));
      await tester.enterText(find.byKey(const Key('water-edit-field')), '300');
      await j.tapKey('water-edit-save');
      await j.waitUntil(() async => tester.widget<Text>(find.byKey(const Key('water-sheet-total'))).data == '550 mL', what: 'the correction');
      await j.tap(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('water-delete-')).first);
      await j.waitUntil(() async => tester.widget<Text>(find.byKey(const Key('water-sheet-total'))).data == '250 mL', what: 'the removal');

      // --- A water goal in Eat: the same goals form, now with water and the suggested starting goal.
      expect(find.byKey(const Key('water-goal')), findsNothing, reason: 'no goal shortcut in the water sheet');
      await closeSheet();
      await j.tapKey('nav-eat');
      await top();
      await j.tapKey('eat-goals');
      await j.waitFor(find.byKey(const Key('water-suggestion')), what: 'the suggested starting goal');
      await j.tapKey('water-suggestion-use');
      await j.tapKey('goal-save');
      await j.tapKey('nav-today');
      await j.waitFor(find.text('250 / 2,000 mL'), what: 'the water goal on Today');
      await top();
      await j.shot('water-04-today-water-goal');

      // --- Offline: 500 mL saved on the phone only.
      // ignore: avoid_print
      print('GOHARD_NET:off');
      await j.waitUntil(() async => !await j.apiReachable(), what: 'the phone to be offline');
      await j.tapKey('water-quick-add');
      await j.tapKey('water-add-500');
      await j.waitUntil(() async => tester.widget<Text>(find.byKey(const Key('water-sheet-total'))).data == '750 mL', what: '750 mL offline');
      await j.shot('water-05-offline-saved');
      await closeSheet();
      expect(waterTotal(), '750 mL');
      return;
    }

    // ---------------------------------------------------------------- phase 2: a new process, back online
    // ignore: avoid_print
    print('GOHARD_NET:on');
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.waitFor(find.byKey(const Key('today-water')), what: 'Today with water after the process ended', seconds: 40);
    // The day's entries are read from the phone's store as the app starts; then the offline entry is there.
    await j.waitUntil(() async => find.byKey(const Key('water-total')).evaluate().isNotEmpty && waterTotal() == '750 mL', what: 'the entry saved offline, after the process end', seconds: 30);
    await j.waitUntil(() async => await j.apiReachable(), what: 'the network to be back');

    // The queue reaches the account; then a fresh pull from it shows each entry once.
    await j.tapKey('nav-me');
    await j.waitFor(find.text('Everything is saved to your account'), what: 'the queue to drain', seconds: 60);
    await j.tapKey('nav-today');
    await top();
    await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 400)); // pull to refresh
    await j.settle(12);
    expect(waterTotal(), '750 mL', reason: 'the account holds 250 + 500, nothing twice');
    await j.tapKey('water-quick-add');
    await j.waitFor(find.byKey(const Key('water-sheet-total')));
    final entries = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('water-entry-'));
    expect(entries, findsNWidgets(2), reason: 'two entries after the sync and a fresh pull: no duplicate, the removed one gone');
    // The keyboard over the sheet: the field and its Add stay in view.
    await j.type('water-custom', '120');
    await j.shot('water-06-sheet-keyboard');
    await tester.enterText(find.byKey(const Key('water-custom')), '');
    FocusManager.instance.primaryFocus?.unfocus();
    await closeSheet();

    // Hiding water changes only what is shown.
    await setWater(false);
    expect(find.byKey(const Key('today-water')), findsNothing);
    await setWater(true);
    await j.waitFor(find.byKey(const Key('today-water')));
    expect(waterTotal(), '750 mL', reason: 'hiding removed nothing');
    await top();
    await j.shot('water-07-today-restored');
    await j.tapKey('nav-eat');
    await top();
    await j.shot('water-08-eat');

    // --- Recording: goals, water logging with Undo, Customize tracking.
    await j.tapKey('nav-today');
    await top();
    await const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('revertFlutterImage');
    debugPrint('GOHARD_REC:start:goals-water');
    await watch(2000);
    await watch(1500);
    await j.tap(find.byKey(const Key('water-quick-add')));
    await watch(1500);
    await j.tap(find.byKey(const Key('water-add-250')));
    await watch(1800);
    if (find.text('Undo').hitTestable().evaluate().isNotEmpty) await tester.tap(find.text('Undo'));
    await watch(1800);
    await closeSheet();
    await watch(1500);
    await j.tap(find.byKey(const Key('nav-eat')));
    await watch(1500);
    await j.tap(find.byKey(const Key('eat-customize')));
    await watch(1500);
    await j.tap(find.byKey(const Key('track-carbs')));
    await watch(1200);
    await j.tap(find.byKey(const Key('track-carbs')));
    await watch(1200);
    await closeSheet();
    await watch(1200);
    await j.tap(find.byKey(const Key('nav-eat')));
    await watch(3000);
    debugPrint('GOHARD_REC:stop');
    await watch(1500);
  });
}
