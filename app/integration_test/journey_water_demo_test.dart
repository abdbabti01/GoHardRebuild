import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// A short recording for review, not part of the default run: daily goals set from Today, water turned on and logged
/// with Undo, Customize tracking, and Eat showing the same. Prints `GOHARD_REC:start:goals-water` / `GOHARD_REC:stop`
/// for the host recorder. The behaviour itself is checked by `journey_water_test`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('goals, water and customize, recorded', (tester) async {
    final j = Journey(tester, binding);
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    Future<void> closeSheet() async {
      FocusManager.instance.primaryFocus?.unfocus();
      if (find.byType(BottomSheet).evaluate().isNotEmpty) Navigator.of(tester.element(find.byType(BottomSheet).last)).pop();
      await watch(1200);
    }

    await j.start('Water Demo');
    await j.tapKey('nav-eat');
    await j.waitUntil(() async => tester.widget<TextButton>(find.descendant(of: find.byKey(const Key('eat-goals')), matching: find.byType(TextButton))).onPressed != null,
        what: 'the profile to arrive');
    await j.shot('water-demo-start'); // the script publishes a journey's captures; one before the recording
    await const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('revertFlutterImage');
    debugPrint('GOHARD_REC:start:goals-water');
    await watch(2000);

    // Goals from Eat, in the sheet; the panel then offers Edit goals.
    await j.tapKey('eat-goals');
    await watch(1200);
    await j.type('goal-calories', '2200');
    await j.type('goal-protein', '140');
    await watch(800);
    await j.tapKey('goal-save');
    await watch(1800);

    // Customize tracking: water on (still in Eat).
    await j.tapKey('eat-customize');
    await watch(1200);
    await j.tapKey('track-water');
    await watch(1200);
    await closeSheet();

    // Water: two quick additions, one undone, then a custom amount.
    await j.tapKey('water-quick-add');
    await watch(1200);
    await j.tapKey('water-add-250');
    await watch(1200);
    await j.tapKey('water-add-500');
    await watch(1000);
    if (find.text('Undo').hitTestable().evaluate().isNotEmpty) await tester.tap(find.text('Undo').hitTestable().first);
    await watch(1500);
    await j.type('water-custom', '330');
    await j.tapKey('water-add-custom');
    await watch(1800);
    await closeSheet();
    await watch(1500);

    // The same day's water and goals on Eat.
    await j.tapKey('nav-eat');
    await watch(2500);
    await j.tapKey('nav-today');
    await watch(2500);
    debugPrint('GOHARD_REC:stop');
    await watch(1500);
  });
}
