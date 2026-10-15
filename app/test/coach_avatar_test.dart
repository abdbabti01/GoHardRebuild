import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/coach/coach_avatar.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/me/me_screen.dart';

import 'ui_support.dart';

const _hint = 'Not sure how many days to train? Ask GoHard about this split.';

/// A restart: a fresh store read back from the same phone storage.
Future<CoachPrefsStore> _restored(MemorySecretStore phone) async {
  final s = CoachPrefsStore(phone);
  await s.restore();
  return s;
}

Future<ProviderContainer> _pump(WidgetTester tester, Widget home,
        {CoachPrefsStore? coach, AppearanceStore? appearance, DevicePrefsStore? device, Size size = const Size(390, 844), double textScale = 1}) =>
    pumpApp(tester, [
      coachPrefsStoreProvider.overrideWithValue(coach ?? CoachPrefsStore(MemorySecretStore())),
      if (appearance != null) appearanceStoreProvider.overrideWithValue(appearance),
      if (device != null) devicePrefsStoreProvider.overrideWithValue(device),
    ], home: home, size: size, textScale: textScale);

/// A builder-like page: a draft field, the selected guide's avatar and a help button that may carry a hint.
class _Page extends StatelessWidget {
  const _Page({this.hintId = 'split-intro', this.onAsk});
  final String? hintId;
  final VoidCallback? onAsk;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Upper / Lower')),
              CoachHelpButton(semanticLabel: 'Ask GoHard about this split', onPressed: onAsk ?? () {}),
            ]),
            if (hintId != null) CoachHint(hintId: hintId!, text: _hint, onAsk: onAsk ?? () {}),
            const CoachAvatar(key: Key('selected-avatar')),
            const TextField(key: Key('draft')),
            Builder(builder: (context) => TextButton(onPressed: () => push(context, const AppearanceScreen()), child: const Text('Appearance'))),
          ]),
        ),
      );
}

/// Records anything sent: a hint must never reach the network.
class _RecordingTransport implements Transport {
  final calls = <String>[];
  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) {
    calls.add('$method $path');
    throw const TransportFailure('no network in this test');
  }
}

Finder get _bubble => find.byKey(const Key('coach-hint'));
Finder _avatar(CoachGuide g) => find.descendant(of: find.byKey(const Key('selected-avatar')), matching: find.byKey(Key('coach-avatar-${g.name}')));

Future<void> _openAppearance(WidgetTester tester) async {
  await tester.tap(find.text('Appearance'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(const Key('coach-hints-reset')), 200, scrollable: find.byType(Scrollable).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a fresh install is Leon whatever the profile; Leona applies at once, survives a restart and resets nothing else', (tester) async {
    final phone = MemorySecretStore();
    final appearance = AppearanceStore(MemorySecretStore())
      ..accent = Accent.pink
      ..mode = ThemeMode.dark;
    // A profile whose name or details might suggest anything: the guide is never inferred from it.
    final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-11', appearance: appearance, profile: {'displayName': 'Leona Sample'})))!;
    final container = await pumpApp(tester, [...overrides, coachPrefsStoreProvider.overrideWithValue(await _restored(phone))], home: const _Page(hintId: null));
    expect(container.read(coachPrefsProvider).guide, CoachGuide.leon);
    expect(_avatar(CoachGuide.leon), findsOneWidget);

    await tester.enterText(find.byKey(const Key('draft')), 'Week 1 draft');
    await _openAppearance(tester);
    await tester.tap(find.byKey(const Key('coach-leona')));
    await tester.pump();
    expect(container.read(coachPrefsProvider).guide, CoachGuide.leona);
    expect(container.read(appearanceProvider), const Appearance(Accent.pink, ThemeMode.dark), reason: 'accent and mode are untouched');
    expect(find.byType(AppearanceScreen), findsOneWidget, reason: 'still on the same page');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Week 1 draft'), findsOneWidget, reason: 'the page underneath kept its state');
    expect(_avatar(CoachGuide.leona), findsOneWidget, reason: 'applied immediately');

    // Restart: same phone storage, new store.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const _Page(hintId: null), coach: await _restored(phone));
    expect(_avatar(CoachGuide.leona), findsOneWidget);
  });

  testWidgets('a hint shows once: seen on appearing, closed, and still gone after a rebuild and a restart', (tester) async {
    final phone = MemorySecretStore();
    var asked = 0;
    final container = await _pump(tester, _Page(onAsk: () => asked++), coach: await _restored(phone));
    expect(_bubble, findsOneWidget);
    expect(find.text(_hint), findsOneWidget);
    expect(container.read(coachPrefsProvider).dismissed, {'split-intro'}, reason: 'appearing marks it seen');
    expect(asked, 0, reason: 'the hint never opens Ask GoHard by itself');
    expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<EditableText>()), reason: 'no focus moved');

    await tester.tap(find.byTooltip('Close hint'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const _Page(), coach: await _restored(phone));
    expect(_bubble, findsNothing, reason: 'remembered across a restart');
  });

  testWidgets('Ask GoHard in the hint asks and closes it', (tester) async {
    var asked = 0;
    await _pump(tester, _Page(onAsk: () => asked++));
    await tester.tap(find.byKey(const Key('coach-hint-ask')));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(_bubble, findsNothing);
  });

  testWidgets('with coaching hints off there is no bubble, and the button still asks', (tester) async {
    final coach = CoachPrefsStore(MemorySecretStore())..value = const CoachPrefs(hintsEnabled: false);
    var asked = 0;
    final container = await _pump(tester, _Page(onAsk: () => asked++), coach: coach);
    expect(_bubble, findsNothing);
    expect(container.read(coachPrefsProvider).dismissed, isEmpty, reason: 'not shown, so not seen');
    await tester.tap(find.byTooltip('Ask GoHard about this split'));
    expect(asked, 1);
  });

  testWidgets('Show coaching hints again lets a seen hint return; the switch turns hints off', (tester) async {
    final coach = CoachPrefsStore(MemorySecretStore())..value = const CoachPrefs(dismissed: {'split-intro'});
    final container = await _pump(tester, const _Page(), coach: coach);
    expect(_bubble, findsNothing);
    await _openAppearance(tester);
    await tester.tap(find.byKey(const Key('coach-hints-reset')));
    await tester.pump();
    expect(container.read(coachPrefsProvider).dismissed, isEmpty);
    expect(container.read(coachPrefsProvider).guide, CoachGuide.leon, reason: 'the guide is kept');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget, reason: 'shown again once its page is current');

    await tester.tap(find.byTooltip('Close hint'));
    await tester.pump();
    await _openAppearance(tester);
    await tester.tap(find.descendant(of: find.byKey(const Key('coach-hints')), matching: find.byType(Switch)));
    await tester.pump();
    expect(container.read(coachPrefsProvider).hintsEnabled, isFalse);
  });

  testWidgets('no bubble while its route is covered; it appears when the route is current again', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore()))],
      child: MaterialApp(
        theme: goTheme(Accent.blue, Brightness.light),
        initialRoute: '/top',
        routes: {'/': (_) => const _Page(), '/top': (_) => const Scaffold(body: Text('On top'))},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(_hint, skipOffstage: false), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
  });

  testWidgets('the hint arrives with a short fade, and with none under Reduce Motion', (tester) async {
    Duration entrance() => tester.widget<TweenAnimationBuilder<double>>(find.byKey(const Key('coach-hint-entrance'))).duration;
    await _pump(tester, const _Page());
    expect(entrance(), Motion.quick);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const _Page(), device: DevicePrefsStore(MemorySecretStore())..motion = MotionPref.reduced);
    expect(entrance(), Duration.zero);
  });

  testWidgets('labels: the previews are named and selected, the help button by purpose, and the pictures are silent', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const _Page(hintId: null));
    expect(tester.getSemantics(find.byType(IconButton)), isSemantics(tooltip: 'Ask GoHard about this split', isButton: true, hasTapAction: true));
    expect(find.semantics.byFlag(SemanticsFlag.isImage), findsNothing, reason: 'the avatar is decorative');
    await _openAppearance(tester);
    expect(tester.getSemantics(find.byKey(const Key('coach-leon'))), isSemantics(label: 'Leon, lion', isButton: true, isSelected: true, hasSelectedState: true, isInMutuallyExclusiveGroup: true, hasTapAction: true, hasEnabledState: false, isFocusable: true, hasFocusAction: true));
    expect(tester.getSemantics(find.byKey(const Key('coach-leona'))), isSemantics(label: 'Leona, lioness', isButton: true, isSelected: false, hasSelectedState: true, isInMutuallyExclusiveGroup: true, hasTapAction: true, isFocusable: true, hasFocusAction: true));
    for (final g in CoachGuide.values) {
      expect(find.ancestor(of: find.byKey(Key('coach-avatar-${g.name}')), matching: find.byType(ExcludeSemantics)), findsWidgets, reason: 'the previews are named by their card, not the picture');
    }
    handle.dispose();
  });

  testWidgets('a closed hint stays closed when its page is rebuilt, covered and uncovered, or left and come back to', (tester) async {
    final tab = ValueNotifier(0);
    addTearDown(tab.dispose);
    // Two "tabs": leaving the first disposes its page, so coming back builds a fresh hint state.
    await _pump(tester, ValueListenableBuilder<int>(valueListenable: tab, builder: (_, i, _) => i == 0 ? const _Page() : const Scaffold(body: Text('Other tab'))));
    expect(_bubble, findsOneWidget);
    await tester.tap(find.byTooltip('Close hint'));
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);

    await _openAppearance(tester); // covers the page, then rebuilds it as current again
    await tester.tap(find.byKey(const Key('coach-leona'))); // a preference change rebuilds every listener
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing, reason: 'route current again and prefs changed');

    tab.value = 1;
    await tester.pumpAndSettle();
    tab.value = 0;
    await tester.pumpAndSettle();
    expect(find.text('Upper / Lower'), findsOneWidget);
    expect(_bubble, findsNothing, reason: 'switching away and back does not bring it back');
  });

  testWidgets('a hint, its help button and its close send nothing over the network', (tester) async {
    final net = _RecordingTransport();
    await pumpApp(tester, [coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore())), transportProvider.overrideWithValue(net)], home: const _Page());
    expect(_bubble, findsOneWidget);
    await tester.tap(find.byTooltip('Ask GoHard about this split'));
    await tester.tap(find.byTooltip('Close hint'));
    await tester.pumpAndSettle();
    expect(net.calls, isEmpty);
  });

  testWidgets('the Leon and Leona previews: large, labelled 48 px targets in six themes, at 390 px and at 320 px with twice the text', (tester) async {
    for (final (size, scale, preview) in [(const Size(390, 900), 1.0, 64.0), (const Size(320, 900), 2.0, 56.0)]) {
      for (final accent in Accent.values) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          final handle = tester.ensureSemantics();
          final appearance = AppearanceStore(MemorySecretStore())
            ..accent = accent
            ..mode = mode;
          await _pump(tester, const _Page(hintId: null), appearance: appearance, size: size, textScale: scale);
          await _openAppearance(tester);
          await tester.scrollUntilVisible(find.byKey(const Key('coach-leona')), 100, scrollable: find.byType(Scrollable).last);
          await tester.pumpAndSettle();
          final why = '${accent.name} ${mode.name} ${size.width} @$scale';
          for (final g in CoachGuide.values) {
            final card = tester.getRect(find.byKey(Key('coach-${g.name}')));
            expect(card.width, greaterThanOrEqualTo(Targets.minimum), reason: why);
            expect(card.height, greaterThanOrEqualTo(Targets.minimum), reason: why);
            expect(card.left, greaterThanOrEqualTo(0), reason: why);
            expect(card.right, lessThanOrEqualTo(size.width), reason: why);
            final art = find.descendant(of: find.byKey(Key('coach-${g.name}')), matching: find.byType(CoachAvatar));
            expect(tester.getSize(art), Size.square(preview), reason: why);
            expect(tester.getSemantics(find.byKey(Key('coach-${g.name}'))), isSemantics(label: '${g.label}, ${g.animal}', isButton: true, isSelected: g == CoachGuide.leon, hasSelectedState: true, isInMutuallyExclusiveGroup: true, hasTapAction: true, isFocusable: true, hasFocusAction: true, hasEnabledState: false), reason: why);
          }
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull, reason: why);
          handle.dispose();
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });

  testWidgets('six themes at 320 px and twice the text: Appearance and an open hint fit', (tester) async {
    for (final accent in Accent.values) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final appearance = AppearanceStore(MemorySecretStore())
          ..accent = accent
          ..mode = mode;
        await _pump(tester, const _Page(), appearance: appearance, size: const Size(320, 900), textScale: 2);
        expect(_bubble, findsOneWidget);
        expect(tester.getRect(_bubble).right, lessThanOrEqualTo(320));
        expect(tester.getRect(_bubble).left, greaterThanOrEqualTo(0));
        await tester.tap(find.byTooltip('Close hint'));
    await tester.pump();
        await _openAppearance(tester);
        expect(tester.takeException(), isNull, reason: '${accent.name} ${mode.name}');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
