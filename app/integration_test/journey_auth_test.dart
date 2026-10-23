import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Account email (docs/AUTHENTICATION_EMAIL.md) on a device, against a local API that CAPTURES mail instead of sending
/// it (Email:Provider=Capture, Development only). Codes are read from the API's /dev/mail/latest. Not in the default
/// run: `scripts\test-android.ps1 -Only journey_auth_test -ApiBase http://10.0.2.2:PORT`, PORT being a capture API.
/// A disposable account: verify before setup (required), an open workout as local data, change the password in Me, the old password
/// refused, sign in with the new one (workout still there), forgot password by code, sign in again, delete the account.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('verify, change, reset: local data stays with the account', (tester) async {
    final j = Journey(tester, binding);
    final mail = Dio(BaseOptions(baseUrl: Journey.apiBase, validateStatus: (_) => true));
    final email = 'auth-journey-${DateTime.now().millisecondsSinceEpoch}@example.test';
    const changed = 'changed in me passphrase', reset = 'reset by emailed code';

    /// The newest captured code of one kind to this address (the API's worker sends within a few seconds).
    Future<String> code(String subjectWord, {String? not}) async {
      String? found;
      await j.waitUntil(() async {
        final r = await mail.get<Map>('/dev/mail/latest', queryParameters: {'to': email});
        final m = r.data;
        if (r.statusCode == 200 && m != null && '${m['subject']}'.contains(subjectWord) && '${m['code']}'.length == 8 && m['code'] != not) found = m['code'] as String;
        return found != null;
      }, what: 'a captured "$subjectWord" email', seconds: 40);
      debugPrint('GOHARD_AUTH captured $subjectWord code (${found!.length} digits)');
      return found!;
    }

    Future<void> signIn(String password) async {
      await j.type('auth-email', email);
      await j.type('auth-password', password);
      await j.tapKey('auth-submit');
    }

    ProviderContainer container() => ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

    // 1. Register: the verification step comes first (the first code was sent at registration), then setup.
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.tapKey('auth-toggle');
    await j.type('auth-name', 'Auth Journey');
    await j.type('auth-email', email);
    await j.type('auth-password', j.password);
    await j.tapKey('auth-submit');
    await j.waitFor(find.byKey(const Key('verify-gate')), what: 'the verification step');
    await j.shot('auth-01-verify-gate');
    await j.type('code-field', await code('Verify'));
    await j.shot('auth-02-verify-code');
    await j.tapKey('verify-confirm');
    await j.tapKey('setup-continue');
    await j.tapKey('setup-done');
    await j.tapKey('nav-me');
    await j.reveal(find.byKey(const Key('me-email')));
    await j.waitFor(find.descendant(of: find.byKey(const Key('me-email')), matching: find.text('Verified')), what: 'Me › Email verified');
    await j.shot('auth-03-me-verified');

    // 2. Local data: an open manual workout with one recorded set.
    await j.tapKey('nav-train');
    await j.tapKey('start-manual');
    await j.type('manual-title', 'Kept through passwords');
    await j.tapKey('manual-add-exercise');
    await j.type('exercise-search', 'Push-up');
    await j.tap(find.text('Push-up').last);
    await j.tapKey('manual-start');
    await j.waitFor(find.byKey(const Key('complete-set')), what: 'the recorder');
    await j.type('set-reps', '12');
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('set-row-0')), what: 'one recorded set');
    final owner = container().read(ownerProvider)!;
    final workoutId = container().read(workoutListProvider).singleWhere((w) => w.isOpen).id;
    Future<void> workoutStillThere(String when) async {
      final c = container();
      expect(c.read(ownerProvider), owner, reason: 'the same account');
      expect(c.read(workoutListProvider).where((w) => w.isOpen).map((w) => w.id), [workoutId], reason: '$when: the open workout is still on the phone');
      expect((await c.read(workoutRepositoryProvider).sets(workoutId)).where((s) => !s.isDeleted), hasLength(1), reason: '$when: its set too');
    }
    Navigator.of(tester.element(find.byKey(const Key('complete-set')))).pop();
    await j.settle(4);

    // 3. Change the password in Me: every device signed out, back to sign-in with the address filled in.
    await j.tapKey('nav-me');
    await j.tapKey('me-password');
    await j.type('current-password', j.password);
    await j.type('new-password', changed);
    await j.type('new-password-confirm', changed);
    await j.shot('auth-04-change-password');
    await j.tapKey('change-password-submit');
    await j.confirmWith('Change password');
    await j.waitFor(find.byKey(const Key('auth-forgot')), what: 'sign-in after the change');
    expect(tester.widget<TextField>(find.byKey(const Key('auth-email'))).controller!.text, email);
    await j.shot('auth-05-signed-out-after-change');

    // 4. The old password is refused; the new one signs in and the workout is there.
    await signIn(j.password);
    await j.waitFor(find.textContaining('do not match an account'), what: 'the old password refused');
    await signIn(changed);
    await j.waitFor(find.byKey(const Key('nav-me')), what: 'signed in with the changed password');
    await workoutStillThere('after the change');

    // 5. Signed out, forgot password: request, captured code, new password.
    await j.tapKey('nav-me');
    await j.tapKey('me-sign-out');
    await j.confirmWith('Sign out');
    await j.type('auth-email', email);
    await j.tapKey('auth-forgot');
    await j.tapKey('reset-send');
    await j.type('code-field', await code('reset'));
    await j.shot('auth-06-reset-code');
    await j.tapKey('reset-verify');
    await j.type('new-password', reset);
    await j.type('new-password-confirm', reset);
    await j.tapKey('reset-complete');
    await j.waitFor(find.textContaining('Your password was changed'), what: 'sign-in after the reset');
    await j.shot('auth-07-after-reset');

    await signIn(changed);
    await j.waitFor(find.textContaining('do not match an account'), what: 'the previous password refused after the reset');
    await signIn(reset);
    await j.waitFor(find.byKey(const Key('nav-me')), what: 'signed in with the reset password');
    await workoutStillThere('after the reset');
    await j.shot('auth-08-signed-in-after-reset');

    // The disposable account goes.
    final token = ((await j.api.post<Map>('/auth/login', data: {'email': email, 'password': reset})).data!)['accessToken'] as String;
    final gone = await j.api.delete<void>('/account', data: {'password': reset}, options: Options(headers: {'Authorization': 'Bearer $token'}));
    expect(gone.statusCode, 204);
    debugPrint('GOHARD_AUTH done; disposable account deleted');
  });
}
