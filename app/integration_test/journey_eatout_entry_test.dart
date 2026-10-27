import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/eating_out_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// The Eating out panel on a real install (docs/EATING_OUT.md › Finding it): on Eat, under the summary; on an earlier
/// day it opens Eating out for that day; back leaves Eat as it was. Nothing is logged or asked. Not in the default run:
/// `scripts\test-android.ps1 -Only journey_eatout_entry_test -ApiBase http://10.0.2.2:PORT`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('eating out entry', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Eatout Entry');
    final eat = find.byType(EatScreen);
    final panel = find.descendant(of: eat, matching: find.byKey(const Key('eat-eating-out')));

    await j.tapKey('nav-eat');
    await j.reveal(panel);
    await j.waitFor(find.descendant(of: panel, matching: find.textContaining('Pizza')), what: 'the chains on the panel');
    await j.shot('eod-01-panel');

    await j.tap(find.descendant(of: eat, matching: find.byTooltip('Previous day')));
    final t = DateTime.now().subtract(const Duration(days: 1));
    final yesterday = '${t.year}-${'${t.month}'.padLeft(2, '0')}-${'${t.day}'.padLeft(2, '0')}';
    await j.reveal(panel);
    await j.tap(panel);
    await j.waitFor(find.byKey(const Key('eatout-chain-subway-ca')), what: 'the chains');
    expect(tester.widget<EatingOutScreen>(find.byType(EatingOutScreen)).dayKey, yesterday, reason: 'the day picked on Eat');
    await j.shot('eod-02-chains');

    Navigator.of(tester.element(find.byType(EatingOutScreen))).pop();
    await j.settle(8);
    await j.reveal(panel);
    expect(panel, findsOneWidget);
    // Back to today sits in the header, out of the lazy list while the panel is in view.
    final back = find.descendant(of: eat, matching: find.byKey(const Key('eat-back-to-today')));
    await j.reveal(back);
    expect(back, findsOneWidget, reason: 'Eat still shows the earlier day');
  });
}
