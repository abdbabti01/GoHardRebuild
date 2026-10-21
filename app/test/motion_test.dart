import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/me/me_screen.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';

import 'ui_support.dart';

const _day = '2026-10-11';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Counts the haptic requests the app sends to the platform.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') calls.add('${call.arguments}');
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  addTearDown(() => Haptics.enabled = true);
  return calls;
}

double _railValue(WidgetTester tester) => tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value!;
double _scale(WidgetTester tester, Finder of) => tester.widget<AnimatedScale>(find.descendant(of: of, matching: find.byType(AnimatedScale)).first).scale;

void main() {
  group('motion and haptics preference', () {
    test('a fresh install follows the device, and both choices survive a restart', () async {
      final disk = MemorySecretStore();
      final first = DevicePrefsStore(disk);
      await first.restore();
      expect((first.motion, first.haptics), (MotionPref.device, HapticsPref.device));

      first
        ..motion = MotionPref.reduced
        ..haptics = HapticsPref.off;
      await first.save();
      expect(disk.values['gohard.rebuild.device-prefs'], 'reduced|off|km|run|off|system'); // + Run / Walk: distance unit, last activity, auto-pause; + language
      final relaunched = DevicePrefsStore(disk);
      await relaunched.restore();
      expect((relaunched.motion, relaunched.haptics), (MotionPref.reduced, HapticsPref.off));
    });

    test('an unreadable saved value falls back to the device defaults', () async {
      final store = DevicePrefsStore(MemorySecretStore()..values['gohard.rebuild.device-prefs'] = 'sideways|loud|x');
      await store.restore();
      expect((store.motion, store.haptics), (MotionPref.device, HapticsPref.device));
    });

    testWidgets('the timings are the tuned ones, and Reduced makes every one of them zero', (tester) async {
      expect(Motion.press.inMilliseconds, inInclusiveRange(80, 120));
      expect(Motion.quick.inMilliseconds, inInclusiveRange(180, 240));
      expect(Motion.sheet.inMilliseconds, inInclusiveRange(250, 320));
      expect(Motion.progress.inMilliseconds, inInclusiveRange(300, 450));
      expect(Motion.pressScale, 0.98);

      late BuildContext seen;
      final container = await pumpApp(tester, [devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(MemorySecretStore()))],
          home: Builder(builder: (context) {
            seen = context;
            return const Scaffold(body: TextField(key: Key('draft')));
          }));
      expect(seen.motion(Motion.sheet), Motion.sheet);
      expect(seen.reduceMotion, isFalse);
      await tester.enterText(find.byKey(const Key('draft')), 'half typed');

      container.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
      await tester.pump();
      for (final d in [Motion.press, Motion.quick, Motion.sheet, Motion.progress]) {
        expect(seen.motion(d), Duration.zero);
      }
      expect(seen.reduceMotion, isTrue, reason: 'exactly what the phone\'s own Reduce Motion reports');
      expect(find.text('half typed'), findsOneWidget, reason: 'the open form was not rebuilt');

      container.read(devicePrefsProvider.notifier).setMotion(MotionPref.device);
      await tester.pump();
      expect(seen.motion(Motion.quick), Motion.quick);
    });

    testWidgets('the phone\'s Reduce Motion still applies while the preference is Device', (tester) async {
      late BuildContext seen;
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpApp(tester, const [], home: Builder(builder: (context) {
        seen = context;
        return const SizedBox();
      }));
      expect(seen.motion(Motion.quick), Duration.zero);
    });

    testWidgets('Haptics Off sends nothing to the phone; Device sends a selection tick', (tester) async {
      final calls = _recordHaptics(tester);
      final disk = MemorySecretStore();
      final container = await pumpApp(tester, [devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(disk))], home: const MotionHapticsScreen());

      await _tap(tester, 'motion-reduced');
      expect(calls, ['HapticFeedbackType.selectionClick']);
      Haptics.confirm();
      expect(calls.last, 'HapticFeedbackType.mediumImpact');
      calls.clear();

      await _tap(tester, 'haptics-off');
      calls.clear(); // the tap that turned them off was itself a selection
      await _tap(tester, 'motion-device');
      await _tap(tester, 'motion-reduced');
      Haptics.selection();
      Haptics.confirm();
      expect(calls, isEmpty);
      expect(container.read(devicePrefsProvider), const DevicePrefs(motion: MotionPref.reduced, haptics: HapticsPref.off));
      expect(disk.values['gohard.rebuild.device-prefs'], 'reduced|off|km|run|off|system'); // + Run / Walk: distance unit, last activity, auto-pause; + language
      expect(find.text('GoHard does not vibrate this phone.'), findsOneWidget);

      await _tap(tester, 'haptics-device');
      Haptics.selection();
      expect(calls, isNotEmpty);
    });

    testWidgets('a restored Off is in force from the first frame', (tester) async {
      final calls = _recordHaptics(tester);
      final store = DevicePrefsStore(MemorySecretStore())..haptics = HapticsPref.off;
      await pumpApp(tester, [devicePrefsStoreProvider.overrideWithValue(store)], home: const MotionHapticsScreen());
      await _tap(tester, 'motion-reduced');
      expect(calls, isEmpty);
    });

    testWidgets('changing motion, haptics or the look keeps the tab, the Train section and the page that is open', (tester) async {
      final disk = MemorySecretStore();
      final plan = blockPlan(start: '2026-09-21', recorded: 8);
      final container = await pumpApp(tester, [
        ...(await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1')))!,
        devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(disk)),
      ]);
      await _tap(tester, 'nav-train');
      await _tap(tester, 'train-plan');
      await _tap(tester, 'nav-me');
      expect(find.descendant(of: find.byKey(const Key('me-motion')), matching: find.text('Device')), findsOneWidget);
      await Scrollable.ensureVisible(tester.element(find.byKey(const Key('me-motion'))), alignment: 0.5); // clear of the floating bar
      await tester.pumpAndSettle();
      await _tap(tester, 'me-motion');

      await _tap(tester, 'motion-reduced');
      await _tap(tester, 'haptics-off');
      expect(find.byType(MotionHapticsScreen), findsOneWidget, reason: 'still on the page where the choice was made');
      expect(tester.getSemantics(find.byKey(const Key('motion-reduced'))), isSemantics(isSelected: true, isButton: true, hasSelectedState: true, isInMutuallyExclusiveGroup: true, hasTapAction: true, hasFocusAction: true, isFocusable: true, label: 'Reduced'));
      expect(container.read(shellProvider).tab, 3);
      expect(container.read(shellProvider).trainView, TrainView.plan);
      expect(disk.values['gohard.rebuild.device-prefs'], 'reduced|off|km|run|off|system'); // + Run / Walk: distance unit, last activity, auto-pause; + language

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MotionHapticsScreen), findsNothing);
      expect(find.text('Reduced · Haptics off'), findsOneWidget, reason: 'Me says what is really set');
      await _tap(tester, 'nav-train');
      expect(find.byKey(const Key('week-3')), findsOneWidget, reason: 'Train is still on Plan');
    });
  });

  group('shell', () {
    testWidgets('a tab change fades the new tab in without rebuilding or resetting any tab', (tester) async {
      final container = await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day)))!);
      Element page(Type type) => find.byType(type, skipOffstage: false).evaluate().single;
      final me = page(MeScreen);
      final meState = tester.state(find.descendant(of: find.byType(MeScreen, skipOffstage: false), matching: find.byType(Scrollable, skipOffstage: false)).first);

      await tester.tap(find.byKey(const Key('nav-me')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final fade = tester.widget<FadeTransition>(find.ancestor(of: find.byType(MeScreen), matching: find.byType(FadeTransition)).first);
      expect(fade.opacity.value, inExclusiveRange(0, 1), reason: 'part way through a short fade');
      await tester.pump(Motion.quick);
      expect(fade.opacity.value, 1);
      expect(tester.hasRunningAnimations, isFalse, reason: 'nothing keeps moving');

      await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      final scrolled = tester.state<ScrollableState>(find.byType(Scrollable).last).position.pixels;
      expect(scrolled, greaterThan(0));
      await _tap(tester, 'nav-today');
      await _tap(tester, 'nav-me');
      expect(identical(page(MeScreen), me), isTrue, reason: 'the same Me, not a new one');
      expect(identical(tester.state(find.byType(Scrollable).last), meState), isTrue);
      expect(tester.state<ScrollableState>(find.byType(Scrollable).last).position.pixels, scrolled, reason: 'where it was left');
      expect(container.read(shellProvider).tab, 3);
    });

    testWidgets('with Reduced motion the new tab is simply there', (tester) async {
      final store = DevicePrefsStore(MemorySecretStore())..motion = MotionPref.reduced;
      await pumpApp(tester, [...(await tester.runAsync(() => overridesFor(day: _day)))!, devicePrefsStoreProvider.overrideWithValue(store)]);
      await tester.tap(find.byKey(const Key('nav-me')));
      await tester.pump();
      await tester.pump();
      final fade = tester.widget<FadeTransition>(find.ancestor(of: find.byType(MeScreen), matching: find.byType(FadeTransition)).first);
      expect(fade.opacity.value, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Daily Rhythm components', () {
    double ring(WidgetTester tester, [Finder? of]) =>
        (tester.widget<CustomPaint>(find.descendant(of: of ?? find.byType(ProgressRing), matching: find.byType(CustomPaint)).first).painter! as dynamic).value as double;

    testWidgets('a progress ring is announced once with its percentage, clamps, and never replays on a rebuild', (tester) async {
      final handle = tester.ensureSemantics();
      final value = ValueNotifier(6 / 18), rebuild = ValueNotifier(0);
      final container = await pumpApp(tester, [devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(MemorySecretStore()))],
          settle: false,
          home: Scaffold(
              body: ListenableBuilder(
                  listenable: Listenable.merge([value, rebuild]),
                  builder: (_, _) => Column(children: [
                        ProgressRing(key: const Key('r'), value: value.value, label: 'Planned sets recorded', center: const Text('6 of 18')),
                        const ProgressRing(key: Key('over'), value: 1.7, label: 'Calories'),
                        const ProgressRing(key: Key('nan'), value: double.nan, label: 'Unknown'),
                      ]))));
      expect(ring(tester, find.byKey(const Key('r'))), moreOrLessEquals(1 / 3), reason: 'first frame: no run-up from zero');
      expect(tester.getSemantics(find.byKey(const Key('r'))), isSemantics(label: 'Planned sets recorded', value: '33 percent'));
      expect(find.bySemanticsLabel('6 of 18'), findsNothing, reason: 'the centre is not read a second time');
      expect(ring(tester, find.byKey(const Key('over'))), 1, reason: 'over goal is a full ring');
      expect(tester.getSemantics(find.byKey(const Key('over'))), isSemantics(label: 'Calories', value: '100 percent'));
      expect(ring(tester, find.byKey(const Key('nan'))), 0);

      rebuild.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(ring(tester, find.byKey(const Key('r'))), moreOrLessEquals(1 / 3), reason: 'a rebuild with the same value moves nothing');
      expect(tester.hasRunningAnimations, isFalse);

      value.value = 0.5;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(ring(tester, find.byKey(const Key('r'))), inExclusiveRange(1 / 3, 0.5), reason: 'a real change eases from the old value');
      await tester.pump(Motion.progress);
      expect(ring(tester, find.byKey(const Key('r'))), 0.5);
      expect(tester.hasRunningAnimations, isFalse, reason: 'nothing keeps moving');

      container.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
      await tester.pump();
      value.value = 0.9;
      await tester.pump();
      await tester.pump();
      expect(ring(tester, find.byKey(const Key('r'))), 0.9, reason: 'Reduced: the new value is shown at once');
      handle.dispose();
    });

    testWidgets('the floating bar: four keyed 48 px destinations, the chosen one announced and in the accent', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day)))!);
      final accent = GoColors.of(Accent.blue, Brightness.light).accent;
      for (final (i, tab) in ['today', 'train', 'eat', 'me'].indexed) {
        await _tap(tester, 'nav-$tab');
        for (final (j, other) in ['today', 'train', 'eat', 'me'].indexed) {
          final label = '${other[0].toUpperCase()}${other.substring(1)}';
          expect(tester.getSemantics(find.byKey(Key('nav-$other'))), isSemantics(label: label, isButton: true, isSelected: i == j, hasSelectedState: true, hasTapAction: true, isFocusable: true, hasFocusAction: true),
              reason: '$other while $tab is shown');
          expect(tester.getSize(find.byKey(Key('nav-$other'))).height, greaterThanOrEqualTo(48));
        }
        final icon = tester.widget<Icon>(find.descendant(of: find.byKey(Key('nav-$tab')), matching: find.byType(Icon)));
        expect(icon.color, accent);
      }
      // Inset and rounded: the bar does not touch the screen's sides.
      expect(tester.getTopLeft(find.byKey(const Key('nav-today'))).dx, greaterThanOrEqualTo(GoNavigationBar.margin));
      expect(tester.getTopRight(find.byKey(const Key('nav-me'))).dx, lessThanOrEqualTo(390 - GoNavigationBar.margin));
      // A secondary page has back navigation and no second copy of the bar.
      // Mid-screen, clear of the floating bar (Me grew an Activity & tracking group above it).
      await Scrollable.ensureVisible(tester.element(find.byKey(const Key('me-motion'))), alignment: 0.5);
      await tester.pumpAndSettle();
      await _tap(tester, 'me-motion');
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(GoNavigationBar).hitTestable(), findsNothing);
      handle.dispose();
    });

    testWidgets('the bar sits above the home indicator', (tester) async {
      await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day)))!, insets: const EdgeInsets.only(bottom: 34));
      expect(tester.getBottomLeft(find.byKey(const Key('nav-today'))).dy, lessThanOrEqualTo(844 - 34));
    });

    testWidgets('choice cards: radio-like semantics, a check badge on the chosen one, a tick only for a change', (tester) async {
      final handle = tester.ensureSemantics();
      final haptics = _recordHaptics(tester);
      var chosen = 'Dark';
      await pumpApp(tester, const [], home: Scaffold(
          body: StatefulBuilder(
              builder: (context, setState) => Row(children: [
                    for (final m in ['Light', 'Dark'])
                      Expanded(child: ChoiceCard(key: Key('c-$m'), label: m, leading: const Icon(Icons.circle), selected: chosen == m, onTap: () => setState(() => chosen = m))),
                  ]))));
      expect(tester.getSemantics(find.byKey(const Key('c-Dark'))), isSemantics(label: 'Dark', isButton: true, isSelected: true, hasSelectedState: true, isInMutuallyExclusiveGroup: true, hasTapAction: true, isFocusable: true, hasFocusAction: true));
      expect(find.descendant(of: find.byKey(const Key('c-Dark')), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('c-Light')), matching: find.byIcon(Icons.check_rounded)), findsNothing);
      await _tap(tester, 'c-Dark');
      expect(haptics, isEmpty, reason: 'already chosen');
      await _tap(tester, 'c-Light');
      expect(chosen, 'Light');
      expect(haptics, hasLength(1));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a header on a backdrop fits 320 px at twice the text size', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await pumpApp(tester, const [], size: const Size(320, 1400), textScale: scale, home: Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const TabHeader(title: 'Today', overline: 'Tuesday, October 13, 2026', below: Text('Good evening, Alexandria'), onBackdrop: true),
                ]))));
        expect(tester.takeException(), isNull, reason: 'text scale $scale');
      }
    });
  });

  group('shared components', () {
    testWidgets('a progress rail appears at its value, moves only for a new value, and never replays on a rebuild', (tester) async {
      final value = ValueNotifier(0.5), rebuild = ValueNotifier(0);
      final container = await pumpApp(tester, [devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(MemorySecretStore()))],
          settle: false,
          home: Scaffold(body: ListenableBuilder(listenable: Listenable.merge([value, rebuild]), builder: (_, _) => ProgressRail(value.value, label: 'Sets'))));
      expect(_railValue(tester), 0.5, reason: 'first frame: no run-up from zero');

      rebuild.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_railValue(tester), 0.5, reason: 'a rebuild with the same value moves nothing');
      expect(tester.hasRunningAnimations, isFalse);

      value.value = 0.8;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_railValue(tester), inExclusiveRange(0.5, 0.8), reason: 'a real change eases from the old value');
      await tester.pump(Motion.progress);
      expect(_railValue(tester), 0.8);

      container.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
      await tester.pump();
      value.value = 0.2;
      await tester.pump();
      await tester.pump();
      expect(_railValue(tester), 0.2, reason: 'Reduced: the new value is shown at once');
    });

    testWidgets('Pressable is a labelled 48 px button that scales lightly while pressed, and not at all when reduced or disabled', (tester) async {
      final handle = tester.ensureSemantics();
      final calls = _recordHaptics(tester);
      var taps = 0;
      final container = await pumpApp(tester, [devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(MemorySecretStore()))],
          home: Scaffold(
              body: Column(children: [
            Pressable(key: const Key('p'), onTap: () => taps++, semanticLabel: 'Open run', haptic: true, child: const Icon(Icons.directions_run, size: 20)),
            const Pressable(key: Key('off'), onTap: null, child: Text('Unavailable')),
          ])));
      expect(tester.getSize(find.byKey(const Key('p'))).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.byKey(const Key('p'))).width, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(find.byKey(const Key('p'))), isSemantics(label: 'Open run', isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true));
      expect(tester.getSemantics(find.byKey(const Key('off'))), isSemantics(label: 'Unavailable', isButton: true, hasEnabledState: true, isEnabled: false));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      final press = await tester.startGesture(tester.getCenter(find.byKey(const Key('p'))));
      await tester.pump(const Duration(milliseconds: 200)); // past the delay that tells a press from a scroll
      expect(_scale(tester, find.byKey(const Key('p'))), Motion.pressScale);
      await press.up();
      await tester.pumpAndSettle();
      expect(_scale(tester, find.byKey(const Key('p'))), 1);
      expect(taps, 1);
      expect(calls, ['HapticFeedbackType.selectionClick']);

      container.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
      await tester.pump();
      final still = await tester.startGesture(tester.getCenter(find.byKey(const Key('p'))));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_scale(tester, find.byKey(const Key('p'))), 1, reason: 'Reduced: the tint shows, nothing scales');
      await still.up();
      await tester.pumpAndSettle();
      expect(taps, 2);

      await tester.tap(find.byKey(const Key('off')));
      expect(taps, 2, reason: 'a disabled Pressable does nothing');
      handle.dispose();
    });

    testWidgets('buttons scale while pressed, a busy button ignores taps, and a destructive one is filled with the error colour', (tester) async {
      var taps = 0;
      // Not settled: the busy button's spinner turns for as long as it is busy.
      await pumpApp(tester, const [], settle: false, home: Scaffold(
          body: Column(children: [
        PrimaryButton('Save', key: const Key('save'), onPressed: () => taps++),
        PrimaryButton('Saving', key: const Key('busy'), busy: true, onPressed: () => taps++),
        PrimaryButton('Delete', key: const Key('delete'), destructive: true, onPressed: () {}),
        const SecondaryButton('Later', key: Key('later'), onPressed: null),
      ])));
      final press = await tester.startGesture(tester.getCenter(find.byKey(const Key('save'))));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_scale(tester, find.byKey(const Key('save'))), Motion.pressScale);
      await press.up();
      await tester.pump();
      await tester.pump(Motion.press);
      expect(_scale(tester, find.byKey(const Key('save'))), 1);
      expect(taps, 1);

      await tester.tap(find.byKey(const Key('busy')));
      expect(taps, 1);
      expect(find.bySemanticsLabel('Working'), findsOneWidget);
      final c = Theme.of(tester.element(find.byType(Scaffold))).extension<GoColors>()!;
      final delete = tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('delete')), matching: find.byType(FilledButton)));
      expect(delete.style!.backgroundColor!.resolve({}), c.error);
      expect(tester.widget<OutlinedButton>(find.descendant(of: find.byKey(const Key('later')), matching: find.byType(OutlinedButton))).enabled, isFalse);
      for (final key in ['save', 'busy', 'delete', 'later']) {
        expect(tester.getSize(find.byKey(Key(key))).height, greaterThanOrEqualTo(Targets.primary));
      }
    });

    testWidgets('showGoSheet opens above the keyboard, returns a result, and appears at once when motion is reduced', (tester) async {
      final store = DevicePrefsStore(MemorySecretStore());
      String? result;
      final container = await pumpApp(tester, [devicePrefsStoreProvider.overrideWithValue(store)],
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () async => result = await showGoSheet<String>(context, title: 'Units',
                          builder: (sheet) => Column(children: [
                                const TextField(key: Key('sheet-field')),
                                TextButton(onPressed: () => Navigator.pop(sheet, 'kg'), child: const Text('Kilograms')),
                              ])),
                      child: const Text('Open')))));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.hasRunningAnimations, isTrue, reason: 'the sheet travels in');
      await tester.pumpAndSettle();
      expect(find.text('Units'), findsOneWidget);

      // The keyboard takes 300 px: the field stays above it.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.byKey(const Key('sheet-field'))).dy, lessThanOrEqualTo(844 - 300));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kilograms'));
      await tester.pumpAndSettle();
      expect(result, 'kg');

      container.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse, reason: 'Reduced: no travel');
      expect(find.text('Kilograms').hitTestable(), findsOneWidget);
    });

    testWidgets('the tab header, group rows and icon tiles fit a 320 px phone at twice the text size', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const [], size: const Size(320, 900), textScale: 2, home: Scaffold(
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const TabHeader(title: 'Today', overline: 'Tuesday, October 13, 2026', below: Text('Good evening')),
                const Overline('Preferences'),
                GroupCard(children: [
                  GroupRow(icon: Icons.palette_outlined, title: 'Appearance', value: 'Blue · System', onTap: () {}),
                  GroupRow(icon: Icons.restaurant_outlined, title: 'Nutrition goals', subtitle: 'Daily calorie and protein targets', value: '2200 kcal · 140 g protein', onTap: () {}),
                  const GroupRow(icon: Icons.rule, tone: Tone.warning, title: 'A row that opens nothing'),
                ]),
              ]))));
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('GoHard'), findsOneWidget, reason: 'the mark is labelled');
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.bySemanticsLabel('Preferences'), findsOneWidget, reason: 'announced in its normal case');
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2), reason: 'a chevron only where a row opens something');
      // At this size the value has moved under its title instead of being cut.
      expect(tester.getTopLeft(find.text('Blue · System')).dy, greaterThan(tester.getBottomLeft(find.text('Appearance')).dy - 1));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();

      // (The test font is far wider than Inter, so short words stand in for "Appearance" and "Blue · System".)
      await pumpApp(tester, const [], home: Scaffold(body: GroupCard(children: [GroupRow(icon: Icons.straighten, title: 'Units', value: 'Metric', onTap: () {})])));
      expect(tester.getTopLeft(find.text('Metric')).dx, greaterThan(tester.getTopRight(find.text('Units')).dx), reason: 'when it fits, the value sits at the trailing edge');
      expect(tester.getCenter(find.text('Metric')).dy, moreOrLessEquals(tester.getCenter(find.text('Units')).dy, epsilon: 2));
    });
  });
}
