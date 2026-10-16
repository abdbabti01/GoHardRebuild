import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/coach/coach_avatar.dart';
import 'package:gohard_rebuild/features/coach/coach_bubble.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/me/me_screen.dart';

import 'support.dart';
import 'ui_support.dart';

const _hint = 'Not sure how many days to train? Let\'s compare your options.';
const _id = 'split-intro';

/// A restart: a fresh store read back from the same phone storage.
Future<CoachPrefsStore> _restored(MemorySecretStore phone) async {
  final s = CoachPrefsStore(phone);
  await s.restore();
  return s;
}

/// Signed in as [owner]: introductions are kept per account.
Future<SessionManager> _signedIn(WidgetTester tester, [String owner = 'one']) async {
  final sessions = SessionManager(MemorySecretStore());
  await tester.runAsync(() => sessions.signIn(authFor(owner)));
  return sessions;
}

Future<ProviderContainer> _pump(WidgetTester tester, Widget home,
    {CoachPrefsStore? coach, AppearanceStore? appearance, DevicePrefsStore? device, SessionManager? sessions, Size size = const Size(390, 844), double textScale = 1, List<Override> more = const [], bool settle = true}) async {
  final s = sessions ?? await _signedIn(tester);
  return pumpApp(tester, [
    sessionsProvider.overrideWithValue(s),
    coachPrefsStoreProvider.overrideWithValue(coach ?? CoachPrefsStore(MemorySecretStore())),
    if (appearance != null) appearanceStoreProvider.overrideWithValue(appearance),
    if (device != null) devicePrefsStoreProvider.overrideWithValue(device),
    ...more,
  ], home: home, size: size, textScale: textScale, settle: settle);
}

/// A builder-like page: a draft field, the selected guide's avatar, the help entry and its spot, which may introduce
/// itself.
class _Page extends StatelessWidget {
  const _Page({this.introduce = true, this.onAsk});
  final bool introduce;
  final VoidCallback? onAsk;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Expanded(child: Text('Upper / Lower')),
              CoachHelpEntry(id: _id, label: 'Help with choosing a split'),
            ]),
            CoachSpot(id: _id, introduce: introduce, say: CoachSay(_hint, onAsk: onAsk ?? () {})),
            const CoachAvatar(key: Key('selected-avatar')),
            const TextField(key: Key('draft')),
            Builder(builder: (context) => TextButton(onPressed: () => push(context, const AppearanceScreen()), child: const Text('Appearance'))),
          ]),
        ),
      );
}

/// Records anything sent: a bubble must never reach the network.
class _RecordingTransport implements Transport {
  final calls = <String>[];
  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) {
    calls.add('$method $path');
    throw const TransportFailure('no network in this test');
  }
}

Finder get _bubble => find.byKey(const Key('coach-spot-$_id'));
Finder get _close => find.byKey(const Key('coach-say-close'));
Finder _avatar(CoachGuide g) => find.descendant(of: find.byKey(const Key('selected-avatar')), matching: find.byKey(Key('coach-avatar-${g.name}')));

Future<void> _openAppearance(WidgetTester tester) async {
  await tester.tap(find.text('Appearance'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(const Key('coach-hints-reset')), 200, scrollable: find.byType(Scrollable).last);
  await tester.pumpAndSettle();
}

void main() {
  test('setup is per account and survives a restart: resumes at its step, ends for good when finished or skipped', () async {
    final phone = MemorySecretStore();
    Future<ProviderContainer> launch() async => ProviderContainer(overrides: [coachPrefsStoreProvider.overrideWithValue(await _restored(phone))]);
    Future<void> saved() => Future<void>.delayed(Duration.zero);

    var app = await launch();
    app.read(coachPrefsProvider.notifier)
      ..startSetup('new')
      ..setGuide(CoachGuide.leona)
      ..setupFeatures('new');
    await saved();
    app = await launch(); // interrupted: the app is closed during the second step
    expect(app.read(coachPrefsProvider).setup, {'new': 'features'});
    expect(app.read(coachPrefsProvider).guide, CoachGuide.leona);
    expect(app.read(coachPrefsProvider).setup['existing'], isNull, reason: 'an account that only signs in has no setup');

    app.read(coachPrefsProvider.notifier).finishSetup('new');
    await saved();
    app = await launch();
    expect(app.read(coachPrefsProvider).setup, isEmpty, reason: 'finished: never shown again');
  });

  testWidgets('a fresh install is Leon whatever the profile; Leona applies at once, survives a restart and resets nothing else', (tester) async {
    final phone = MemorySecretStore();
    final appearance = AppearanceStore(MemorySecretStore())
      ..accent = Accent.pink
      ..mode = ThemeMode.dark;
    // A profile whose name or details might suggest anything: the guide is never inferred from it.
    final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-11', appearance: appearance, profile: {'displayName': 'Leona Sample'})))!;
    final container = await pumpApp(tester, [...overrides, coachPrefsStoreProvider.overrideWithValue(await _restored(phone))], home: const _Page(introduce: false));
    expect(container.read(coachPrefsProvider).guide, CoachGuide.leon);
    expect(_avatar(CoachGuide.leon), findsOneWidget);

    await tester.enterText(find.byKey(const Key('draft')), 'Week 1 draft');
    await _openAppearance(tester);
    await tester.ensureVisible(find.byKey(const Key('coach-leona')));
    await tester.pumpAndSettle();
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
    await _pump(tester, const _Page(introduce: false), coach: await _restored(phone));
    expect(_avatar(CoachGuide.leona), findsOneWidget);
  });

  testWidgets('an introduction appears once when in view: seen for this account on appearing, closed, and gone after a rebuild and a restart', (tester) async {
    final phone = MemorySecretStore();
    var asked = 0;
    final container = await _pump(tester, _Page(onAsk: () => asked++), coach: await _restored(phone));
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    expect(find.textContaining(_hint, findRichText: true), findsOneWidget);
    expect(container.read(coachPrefsProvider).dismissed, {'one|$_id'}, reason: 'appearing marks it seen, for this account');
    expect(asked, 0, reason: 'it never opens Ask GoHard by itself');
    expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<EditableText>()), reason: 'no focus moved');

    await tester.tap(_close);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const _Page(), coach: await _restored(phone));
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing, reason: 'remembered across a restart');
  });

  testWidgets('another account on the same phone gets its own introduction; seen state never leaks', (tester) async {
    final phone = MemorySecretStore();
    await _pump(tester, const _Page(), coach: await _restored(phone));
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const _Page(), coach: await _restored(phone), sessions: await _signedIn(tester, 'two'));
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget, reason: 'a different account has not seen it');
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const _Page(), coach: await _restored(phone));
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing, reason: 'the first account still has');
  });

  testWidgets('Ask me in the bubble asks; nothing is sent by the bubble itself', (tester) async {
    var asked = 0;
    final net = _RecordingTransport();
    await _pump(tester, _Page(onAsk: () => asked++), more: [transportProvider.overrideWithValue(net)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coach-say-ask')));
    await tester.pumpAndSettle();
    expect(asked, 1);
    await tester.tap(_close);
    await tester.pumpAndSettle();
    expect(net.calls, isEmpty);
  });

  testWidgets('with coaching hints off nothing appears by itself, but the help entry always opens the guide', (tester) async {
    final coach = CoachPrefsStore(MemorySecretStore())..value = const CoachPrefs(hintsEnabled: false);
    final container = await _pump(tester, const _Page(), coach: coach);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
    expect(container.read(coachPrefsProvider).dismissed, isEmpty, reason: 'not shown, so not seen');
    await tester.tap(find.byTooltip('Help with choosing a split'));
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget, reason: 'asked for: shown although hints are off');
    expect(find.byKey(const Key('coach-speaker')), findsOneWidget);
    await tester.tap(find.byTooltip('Help with choosing a split'));
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing, reason: 'the entry closes it again');
  });

  testWidgets('never two bubbles: opening one context closes the other', (tester) async {
    await _pump(tester, const Scaffold(body: Column(children: [
      Row(children: [CoachHelpEntry(id: 'a', label: 'Help A'), CoachHelpEntry(id: 'b', label: 'Help B')]),
      CoachSpot(id: 'a', say: CoachSay('About A.')),
      CoachSpot(id: 'b', say: CoachSay('About B.')),
    ])));
    await tester.tap(find.byTooltip('Help A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Help B'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach-speaker')), findsOneWidget);
    expect(find.text('About B.'), findsOneWidget);
    expect(find.text('About A.'), findsNothing);
  });

  testWidgets('an introduction built off screen is not seen until it is scrolled into view', (tester) async {
    final container = await _pump(tester, Scaffold(body: ListView(children: const [
      SizedBox(height: 1400),
      CoachSpot(id: _id, introduce: true, say: CoachSay(_hint)),
      SizedBox(height: 400),
    ])));
    await tester.pumpAndSettle();
    expect(container.read(coachPrefsProvider).dismissed, isEmpty, reason: 'built in the list but not seen');
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(container.read(coachPrefsProvider).dismissed, {'one|$_id'});
    expect(_bubble, findsOneWidget);
  });

  testWidgets('no introduction while the keyboard is up; it waits until the field is done', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    final container = await _pump(tester, const _Page());
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing, reason: 'the keyboard is up');
    expect(container.read(coachPrefsProvider).dismissed, isEmpty);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing, reason: 'not popping in as the keyboard closes; it waits for the next visit');
    expect(container.read(coachPrefsProvider).dismissed, isEmpty, reason: 'still unseen');
  });

  testWidgets('Show coaching hints again lets this account\'s introductions return; the switch turns them off', (tester) async {
    final coach = CoachPrefsStore(MemorySecretStore())..value = const CoachPrefs(dismissed: {'one|$_id', 'two|$_id'});
    final container = await _pump(tester, const _Page(), coach: coach);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
    await _openAppearance(tester);
    await tester.tap(find.byKey(const Key('coach-hints-reset')));
    await tester.pump();
    expect(container.read(coachPrefsProvider).dismissed, {'two|$_id'}, reason: 'only this account is reset');
    expect(container.read(coachPrefsProvider).guide, CoachGuide.leon, reason: 'the guide is kept');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget, reason: 'shown again once its page is current');

    await tester.tap(_close);
    await tester.pump();
    await _openAppearance(tester);
    await tester.tap(find.descendant(of: find.byKey(const Key('coach-hints')), matching: find.byType(Switch)));
    await tester.pump();
    expect(container.read(coachPrefsProvider).hintsEnabled, isFalse);
  });

  testWidgets('no introduction while its route is covered; it appears when the route is current again', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessions = await _signedIn(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionsProvider.overrideWithValue(sessions), coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore()))],
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

  testWidgets('the bubble arrives as the guide settles, and at once under Reduce Motion', (tester) async {
    double opacity() => tester.widget<Opacity>(find.descendant(of: _bubble, matching: find.byType(Opacity)).first).opacity;
    await _pump(tester, const _Page(), settle: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(opacity(), lessThan(0.5), reason: 'the words wait for the guide');
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const _Page(), device: DevicePrefsStore(MemorySecretStore())..motion = MotionPref.reduced, settle: false);
    await tester.pump();
    await tester.pump();
    expect(opacity(), 1, reason: 'a settled portrait and its bubble, directly');
  });

  testWidgets('labels: the previews are named and selected, the help entry by purpose, and the pictures are silent', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const _Page(introduce: false));
    expect(tester.getSemantics(find.byType(IconButton)), isSemantics(tooltip: 'Help with choosing a split', isButton: true, hasTapAction: true));
    expect(find.semantics.byFlag(SemanticsFlag.isImage), findsNothing, reason: 'the avatar is decorative');
    await _openAppearance(tester);
    expect(tester.getSemantics(find.byKey(const Key('coach-leon'))), isSemantics(label: 'Leon, lion', isButton: true, isSelected: true, hasSelectedState: true, isInMutuallyExclusiveGroup: true, hasTapAction: true, hasEnabledState: false, isFocusable: true, hasFocusAction: true));
    expect(tester.getSemantics(find.byKey(const Key('coach-leona'))), isSemantics(label: 'Leona, lioness', isButton: true, isSelected: false, hasSelectedState: true, isInMutuallyExclusiveGroup: true, hasTapAction: true, isFocusable: true, hasFocusAction: true));
    for (final g in CoachGuide.values) {
      expect(find.ancestor(of: find.byKey(Key('coach-avatar-${g.name}')), matching: find.byType(ExcludeSemantics)), findsWidgets, reason: 'the previews are named by their card, not the picture');
    }
    handle.dispose();
  });

  testWidgets('a closed introduction stays closed when its page is rebuilt, covered and uncovered, or left and come back to', (tester) async {
    final tab = ValueNotifier(0);
    addTearDown(tab.dispose);
    // Two "tabs": leaving the first disposes its page, so coming back builds a fresh state.
    await _pump(tester, ValueListenableBuilder<int>(valueListenable: tab, builder: (_, i, _) => i == 0 ? const _Page() : const Scaffold(body: Text('Other tab'))));
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    await tester.tap(_close);
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

  testWidgets('the Leon and Leona previews: large, labelled 48 px targets in six themes, at 390 px and at 320 px with twice the text', (tester) async {
    for (final (size, scale, preview) in [(const Size(390, 900), 1.0, 64.0), (const Size(320, 900), 2.0, 56.0)]) {
      for (final accent in Accent.values) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          final handle = tester.ensureSemantics();
          final appearance = AppearanceStore(MemorySecretStore())
            ..accent = accent
            ..mode = mode;
          await _pump(tester, const _Page(introduce: false), appearance: appearance, size: size, textScale: scale);
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

  testWidgets('six themes at 320 px and twice the text: Appearance and an open bubble fit', (tester) async {
    for (final accent in Accent.values) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final appearance = AppearanceStore(MemorySecretStore())
          ..accent = accent
          ..mode = mode;
        await _pump(tester, const _Page(), appearance: appearance, size: const Size(320, 900), textScale: 2);
        await tester.pumpAndSettle();
        expect(_bubble, findsOneWidget);
        expect(tester.getRect(_bubble).right, lessThanOrEqualTo(320));
        expect(tester.getRect(_bubble).left, greaterThanOrEqualTo(0));
        await tester.tap(_close);
        await tester.pump();
        await _openAppearance(tester);
        expect(tester.takeException(), isNull, reason: '${accent.name} ${mode.name}');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
