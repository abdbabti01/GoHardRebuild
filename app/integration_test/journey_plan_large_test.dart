import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Captures only: the plan builder, Plan and Today at whatever text size and width the device has. Run it after
/// `adb shell settings put system font_scale 1.5` and `adb shell wm size 720x1520; adb shell wm density 320`
/// (a 360-dp-wide phone with large text); the shot names carry the measured scale and width. Not in the default run.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plan builder captures at the device text size and width', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Large Text');
    final view = tester.view;
    final width = (view.physicalSize.width / view.devicePixelRatio).round();
    final scale = tester.binding.platformDispatcher.textScaleFactor;
    final tag = 'x${scale.toStringAsFixed(1)}-w$width';
    // ignore: avoid_print
    print('GOHARD_CAPTURE text scale $scale, width $width dp');

    await j.tapKey('today-create-plan');
    await j.tapKey('plan-path-template');
    await j.chooseDays(Journey.daysIncludingToday());
    await j.shot('L1-availability-$tag');
    await j.tapKey('builder-next');
    await j.waitFor(find.byKey(const Key('template-full-body')));
    await j.shot('L2-templates-$tag');
    await j.tapKey('builder-next');
    await j.tapKey('exercise-0-0');
    await j.waitFor(find.byKey(const Key('rx-save')));
    await j.shot('L3-prescription-sheet-$tag');
    await j.tapKey('rx-save');
    await j.shot('L4-workout-editor-$tag');
    await j.tapKey('builder-next');
    await j.waitFor(find.byKey(const Key('plan-activate')));
    await j.shot('L5-review-$tag');
    await j.tapKey('plan-activate');
    await j.waitFor(find.textContaining('Week 1 of'));
    await j.shot('L6-train-plan-$tag');
    await j.tapKey('nav-today');
    await j.waitFor(find.byKey(const Key('today-start')));
    await j.shot('L7-today-$tag');
  });
}
