import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/compatibility.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/auth/account_security.dart';
import 'package:gohard_rebuild/features/auth/auth_screen.dart';
import 'package:gohard_rebuild/features/me/account_repository.dart';
import 'package:gohard_rebuild/features/me/me_screen.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';

import 'support.dart';
import 'ui_support.dart';

/// docs/AUTHENTICATION_EMAIL.md: the reset, change and verification forms against a scripted account server.

/// Answers the account-email routes like the real API; everything else is "not found".
class _Accounts implements Transport {
  final code = '01234567';
  final calls = <({String path, Object? data})>[];
  bool offline = false, loseComplete = false;
  List<String> capabilities = ['account.security', 'account.email'];
  String? password = 'the old long passphrase';

  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async {
    calls.add((path: path, data: data));
    if (path == '/capabilities') return ApiResponse(200, {'contractVersion': 1, 'minimumClientContract': 1, 'capabilities': capabilities});
    if (offline) throw const TransportFailure('offline');
    final d = data is Map ? data : const {};
    switch (path) {
      case '/auth/password-reset/request':
        return const ApiResponse(202, {'cooldownSeconds': 60});
      case '/auth/password-reset/verify':
        return d['code'] == code ? const ApiResponse(200, {'resetToken': 'grant-1', 'expiresAtUtc': '2026-10-21T00:10:00Z'}) : const ApiResponse(400, {'code': 'INVALID_CODE'});
      case '/auth/password-reset/complete':
        if (loseComplete) {
          password = d['newPassword'] as String;
          throw const TransportFailure('response lost after commit');
        }
        password = d['newPassword'] as String;
        return const ApiResponse(204, null);
      case '/account/password':
        if (d['currentPassword'] != password) return const ApiResponse(400, {'code': 'WRONG_PASSWORD'});
        password = d['newPassword'] as String;
        return const ApiResponse(204, null);
      case '/account/email-verification/request':
        return const ApiResponse(202, {'cooldownSeconds': 60});
      case '/account/email-verification/confirm':
        return d['code'] == code ? const ApiResponse(200, {}) : const ApiResponse(400, {'code': 'INVALID_CODE'});
    }
    return const ApiResponse(404, null);
  }
}

/// The screens never touch the outbox; pull and flush simply succeed.
class _NoSync implements SyncEngine {
  @override
  dynamic noSuchMethod(Invocation i) => Future.value(true);
}

Future<(ProviderContainer, _Accounts)> _open(WidgetTester tester, {Widget home = const AuthScreen(), bool signedIn = false, Json profile = const {},
    _Accounts? server, Size size = const Size(390, 900), double textScale = 1, String language = 'en'}) async {
  final accounts = server ?? _Accounts();
  final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-21', profile: profile)))!;
  final container = await pumpApp(tester, [
    ...overrides,
    transportProvider.overrideWithValue(accounts),
    authRepositoryProvider.overrideWith((ref) => AuthRepository(ref.watch(apiProvider), ref.watch(sessionsProvider), _NoSync())),
  ], home: home, size: size, textScale: textScale, settle: false);
  if (!signedIn) await container.read(sessionsProvider).signOut();
  if (language != 'en') container.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(language));
  await container.read(compatibilityProvider.notifier).check();
  await tester.pumpAndSettle();
  return (container, accounts);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  // Lazily built lists (sign-in, Me) only hold what is near the screen: scroll the target into existence first.
  if (find.byKey(Key(key)).evaluate().isEmpty) await tester.scrollUntilVisible(find.byKey(Key(key)), 120, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// The real data layer's authority, plus the password route.
class _WithPassword implements Transport {
  _WithPassword(this.inner);
  final FakeServer inner;
  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async =>
      path == '/account/password' ? const ApiResponse(204, null) : inner.send(method, path, data: data, bearer: bearer);
}

void main() {
  test('a password change queues no credential and the same account finds its pending work after signing in again', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final owner = await h.signIn('one');
    h.server.offline = true;
    await FoodRepository(h.sync, owner).save(FoodDraft(dayKey: '2026-10-21', meal: 'Breakfast', name: 'Oats', amount: '60 g', calories: 230));
    h.server.offline = false;
    const current = 'the old long passphrase', next = 'a brand new passphrase';

    await AuthRepository(Api(_WithPassword(h.server), h.sessions), h.sessions, h.sync).changePassword(current, next);
    expect(h.sessions.current, isNull);
    expect(h.sessions.notice, SignOutReason.passwordChanged);
    final queued = await h.sync.commands(owner, states: const ['pending', 'accepted', 'conflict', 'rejected', 'superseded']);
    expect(queued.map((c) => c.kind), ['food.create'], reason: 'the change itself never enters the outbox');
    for (final c in queued) {
      expect('${c.payload}${c.outbound}', isNot(anyOf(contains(current), contains(next))));
    }

    await h.signIn('one'); // the same account, with the new password
    expect((await h.bodies(owner, Kinds.food)).single['name'], 'Oats');
    expect((await h.sync.commands(owner)).single.state, 'pending', reason: 'still waiting to sync, not discarded');
  });

  test('a code keeps its leading zeros and any script\'s digits become ASCII', () {
    expect(normalizeCode('01234567'), '01234567');
    expect(normalizeCode('٠١٢٣٤٥٦٧'), '01234567', reason: 'Arabic-Indic');
    expect(normalizeCode('۰۱۲۳۴۵۶۷'), '01234567', reason: 'Eastern Arabic (Persian)');
    expect(normalizeCode('Your GoHard code: 0123 4567.'), '01234567', reason: 'pasted with words and a space');
    expect(normalizeCode('\u20660123-4567\u2069'), '01234567', reason: 'isolates and a dash from the Arabic email');
    expect(checkNewPassword('short', 'short'), AuthError.weakPassword);
    expect(checkNewPassword('a long enough phrase', 'a long enough phrase!'), AuthError.passwordMismatch);
    expect(checkNewPassword('é' * 15, 'é' * 15), isNull, reason: 'characters, not bytes');
    expect(checkNewPassword('x' * 257, 'x' * 257), AuthError.passwordTooLong);
  });

  testWidgets('forgot password: email kept, pasted Arabic code, wrong code, new password, back to sign-in', (tester) async {
    final (container, server) = await _open(tester);
    await _type(tester, 'auth-email', 'someone@example.test');
    await _tap(tester, 'auth-forgot');
    expect(tester.widget<TextField>(find.byKey(const Key('reset-email'))).controller!.text, 'someone@example.test', reason: 'prefilled from sign-in');

    await _tap(tester, 'reset-send');
    expect(find.textContaining('If an account uses'), findsOneWidget, reason: 'acknowledges a request, not an account or delivery');
    expect(find.text('Resend in 60 s'), findsOneWidget);

    // A wrong code is an error the field can be corrected from; a network problem is not "wrong".
    await _type(tester, 'code-field', '99999999');
    await _tap(tester, 'reset-verify');
    expect(find.textContaining("That code isn't right"), findsOneWidget);
    server.offline = true;
    await _tap(tester, 'reset-verify');
    expect(find.textContaining('cannot be reached'), findsOneWidget);
    expect(find.textContaining("That code isn't right"), findsNothing);
    server.offline = false;

    await _type(tester, 'code-field', 'Code: ٠١٢٣٤٥٦٧');
    final field = tester.widget<TextField>(find.byKey(const Key('code-field')));
    expect(field.controller!.text, '01234567');
    expect(field.textDirection, TextDirection.ltr);
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
    await _tap(tester, 'reset-verify');

    await _type(tester, 'new-password', 'too short');
    await _type(tester, 'new-password-confirm', 'too short');
    await _tap(tester, 'reset-complete');
    expect(find.textContaining('at least 15 characters'), findsWidgets);
    await _type(tester, 'new-password', 'a brand new passphrase');
    await _type(tester, 'new-password-confirm', 'a brand new passphrase');
    await _tap(tester, 'reset-complete');

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.textContaining('Your password was changed'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('auth-email'))).controller!.text, 'someone@example.test');
    expect(server.password, 'a brand new passphrase');
    expect(container.read(sessionsProvider).current, isNull, reason: 'a reset never signs in by itself');
    expect(server.calls.map((c) => c.path), isNot(contains('/auth/login')));
  });

  testWidgets('a lost reply to the new password says to try signing in, and is not sent again', (tester) async {
    final (_, server) = await _open(tester, server: _Accounts()..loseComplete = true);
    await _tap(tester, 'auth-forgot');
    await _type(tester, 'reset-email', 'someone@example.test');
    await _tap(tester, 'reset-send');
    await _type(tester, 'code-field', '01234567');
    await _tap(tester, 'reset-verify');
    await _type(tester, 'new-password', 'a brand new passphrase');
    await _type(tester, 'new-password-confirm', 'a brand new passphrase');
    await _tap(tester, 'reset-complete');
    expect(find.textContaining("couldn't confirm the change"), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byKey(const Key('reset-complete'))).onPressed, isNull, reason: 'no blind resubmission');
    final completes = server.calls.where((c) => c.path == '/auth/password-reset/complete').length;
    await tester.pump(const Duration(seconds: 30));
    expect(server.calls.where((c) => c.path == '/auth/password-reset/complete').length, completes, reason: 'never resent by itself');
    await _tap(tester, 'reset-go-sign-in');
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('without a sender, recovery says so before promising an email', (tester) async {
    await _open(tester, server: _Accounts()..capabilities = ['account.security']);
    await _tap(tester, 'auth-forgot');
    expect(find.text("Email recovery isn't available yet. Your account and data are safe; try again later."), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('code-field')), findsNothing);
  });

  testWidgets('an older server: no Password row in Me, and verification state is not invented', (tester) async {
    await _open(tester, home: const Scaffold(body: MeScreen()), signedIn: true, size: const Size(390, 1800), server: _Accounts()..capabilities = []);
    expect(find.byKey(const Key('me-password')), findsNothing);
    expect(find.byKey(const Key('me-email')), findsNothing, reason: 'the profile says nothing about verification');
  });

  testWidgets('Me shows the server\'s verification state and changes the password, signing out without losing the address', (tester) async {
    final (container, server) = await _open(tester, home: const Scaffold(body: MeScreen()), signedIn: true, size: const Size(390, 1800), profile: {'emailVerified': false});
    expect(find.descendant(of: find.byKey(const Key('me-email')), matching: find.text('Not verified')), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsNothing, reason: 'no badge until the server confirms');

    await _tap(tester, 'me-password');
    await _type(tester, 'current-password', 'not my password');
    await _type(tester, 'new-password', 'a brand new passphrase');
    await _type(tester, 'new-password-confirm', 'a brand new passphrase');
    await _tap(tester, 'change-password-submit');
    await tester.tap(find.widgetWithText(FilledButton, 'Change password').last); // the confirmation
    await tester.pumpAndSettle();
    expect(find.textContaining('That password is not correct'), findsOneWidget);
    expect(container.read(sessionsProvider).current, isNotNull, reason: 'a wrong current password changes nothing');

    await _type(tester, 'current-password', 'the old long passphrase');
    await _tap(tester, 'change-password-submit');
    await tester.tap(find.widgetWithText(FilledButton, 'Change password').last);
    await tester.pumpAndSettle();
    final sessions = container.read(sessionsProvider);
    expect(sessions.current, isNull);
    expect(sessions.notice, SignOutReason.passwordChanged);
    expect(sessions.retainedEmail, 'one@example.test');
    expect(server.password, 'a brand new passphrase');
  });

  testWidgets('change password is disabled offline with a reason', (tester) async {
    final (container, _) = await _open(tester, home: const ChangePasswordScreen(), signedIn: true);
    container.read(connectionProvider.notifier).report(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('needs a connection'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byKey(const Key('change-password-submit'))).onPressed, isNull);
  });

  testWidgets('verify email: send, enter, done', (tester) async {
    final (_, server) = await _open(tester, home: const VerifyEmailScreen(), signedIn: true, profile: {'emailVerified': false});
    await _tap(tester, 'verify-send');
    await _type(tester, 'code-field', '01234567');
    await _tap(tester, 'verify-confirm');
    expect(server.calls.map((c) => c.path), containsAllInOrder(['/account/email-verification/request', '/account/email-verification/confirm']));
  });

  for (final language in ['fr', 'ar']) {
    testWidgets('$language at 320 px with 2× text: every step lays out, the code stays left to right', (tester) async {
      await _open(tester, language: language == 'fr' ? 'fr-CA' : 'ar', size: const Size(320, 640), textScale: 2);
      await _tap(tester, 'auth-forgot');
      await _type(tester, 'reset-email', 'someone@example.test');
      await _tap(tester, 'reset-send');
      await _type(tester, 'code-field', '٠١٢٣٤٥٦٧');
      expect(tester.widget<TextField>(find.byKey(const Key('code-field'))).textDirection, TextDirection.ltr);
      expect(Directionality.of(tester.element(find.byKey(const Key('code-field')))), language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      await _tap(tester, 'reset-verify');
      expect(find.byKey(const Key('new-password')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

