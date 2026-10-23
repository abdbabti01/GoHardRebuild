import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_history.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/workout_detail_screen.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Required verification and the Eat / Train navigation (docs/AUTHENTICATION_EMAIL.md) on a real install, against a
/// local API that CAPTURES mail (Email:Provider=Capture, loopback). Not in the default run:
/// `scripts\test-android.ps1 -Only journey_verify_nav_test -ApiBase http://10.0.2.2:PORT`.
///
/// One process: the Pixel_7 emulator has no room for the reinstall a second (restarted) phase needs, so persistence
/// across a restart is covered by test/verification_gate_test.dart, and on an iPhone by the checklist.
///
/// A new account lands on the verification step, never on the app; the API refuses its data with its own token. The
/// captured code is confirmed; setup once; then Eat's History & trends panel opens the history, and Train › Workouts'
/// history action opens the workout history; Progress no longer repeats it. The API now gives the data. The
/// disposable account is deleted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('verification and navigation', (tester) async {
    final j = Journey(tester, binding);
    Future<int?> snapshotStatus() async {
      final login = await j.api.post<Map>('/auth/login', data: {'email': j.email, 'password': j.password});
      expect(login.statusCode, 200, reason: 'the right password signs in, verified or not');
      final token = login.data!['accessToken'] as String;
      return (await j.api.get<dynamic>('/sync/snapshot', options: Options(headers: {'Authorization': 'Bearer $token'}))).statusCode;
    }

    bool inApp() => find.byType(HomeShell).evaluate().isNotEmpty || find.byKey(const Key('nav-today')).evaluate().isNotEmpty;

    j.email = 'verify-nav-${DateTime.now().millisecondsSinceEpoch}@example.test';
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.tapKey('auth-toggle');
    await j.type('auth-name', 'Verify Journey');
    await j.type('auth-email', j.email);
    await j.type('auth-password', j.password);
    await j.tapKey('auth-submit');
    // Watch every frame until the step shows: the app is never in between.
    for (var i = 0; i < 120 && find.byKey(const Key('verify-gate')).evaluate().isEmpty; i++) {
      expect(inApp(), isFalse, reason: 'no Today before verification');
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byKey(const Key('verify-gate')), findsOneWidget);
    expect(find.byKey(const Key('code-field')), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.byKey(const Key('setup-skip')), findsNothing);
    expect(inApp(), isFalse);
    expect(await snapshotStatus(), 403, reason: 'the API refuses the waiting account its data, by direct request');
    await j.shot('vn-01-gate-after-registration');

    await j.verifyWithCapturedCode();
    await j.waitFor(find.byKey(const Key('setup-continue')), what: 'setup, once verified');
    await j.shot('vn-02-setup-after-verify');
    await j.tapKey('setup-skip');
    await j.waitFor(find.byKey(const Key('nav-today')), what: 'Today');
    expect(find.byKey(const Key('verify-gate')), findsNothing);
    expect(find.byKey(const Key('setup-continue')), findsNothing, reason: 'setup once');
    expect(await snapshotStatus(), 200, reason: 'verified: the data opens');

    // Eat: the one History & trends panel opens the existing history.
    final inEat = find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-history')));
    await j.tapKey('nav-eat');
    await j.reveal(inEat);
    await j.shot('vn-03-eat-panel');
    await j.tap(inEat);
    await j.waitFor(find.byType(NutritionHistoryScreen), what: 'History & trends');
    expect(find.byKey(const Key('trends-period-label')), findsOneWidget);
    await j.shot('vn-04-eat-history');
    await tester.pageBack();
    await j.settle(4);

    // Train › Workouts: Recent workouts with its history action, the empty state for a new account.
    await j.tapKey('nav-train');
    await j.tapKey('train-workouts');
    await j.reveal(find.byKey(const Key('train-recent-empty')));
    expect(find.byKey(const Key('train-recent-empty')), findsOneWidget);
    await j.shot('vn-05-train-workouts');
    await j.tapKey('train-history');
    await j.waitFor(find.byType(WorkoutHistoryScreen), what: 'Workout history');
    await j.shot('vn-06-workout-history');
    await tester.pageBack();
    await j.settle(4);
    await j.tapKey('train-progress');
    await j.settle(4);
    expect(find.byKey(const Key('progress-history')), findsNothing, reason: 'Progress no longer repeats the history');
    expect(find.text('Recent workouts'), findsNothing);

    // The disposable account goes.
    final token = ((await j.api.post<Map>('/auth/login', data: {'email': j.email, 'password': j.password})).data!)['accessToken'] as String;
    expect((await j.api.delete<void>('/account', data: {'password': j.password}, options: Options(headers: {'Authorization': 'Bearer $token'}))).statusCode, 204);
    debugPrint('GOHARD_VN done; disposable account deleted');
  });
}
