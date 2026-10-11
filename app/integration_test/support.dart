import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

/// Shared driver for the native journeys: patient finders for lazily built lists, and a direct line to the
/// local API so a test can act as "another device" or inspect what the account really holds.
class Journey {
  Journey(this.tester, this.binding);
  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  static const apiBase = String.fromEnvironment('GOHARD_API_BASE');
  final api = Dio(BaseOptions(baseUrl: '$apiBase/api/v1', validateStatus: (_) => true, connectTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 5)));
  late String email;
  final password = 'journey password 1';

  Future<void> settle([int frames = 4]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  String get onScreen => tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((s) => s.isNotEmpty).take(34).join(' | ');

  Future<void> waitFor(Finder finder, {String? what, int seconds = 25}) async {
    for (var i = 0; i < seconds * 4; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 250));
    }
    fail('Timed out waiting for ${what ?? finder}. On screen: $onScreen');
  }

  Future<void> waitUntil(Future<bool> Function() condition, {required String what, int seconds = 60}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (await condition()) return;
      await tester.pump(const Duration(milliseconds: 500));
    }
    fail('Timed out waiting for $what. On screen: $onScreen');
  }

  /// Lists build lazily: scroll the list that is actually on screen until the target exists.
  Future<void> reveal(Finder finder) async {
    await settle(2);
    if (finder.evaluate().isNotEmpty || find.byType(ListView).hitTestable().evaluate().isEmpty) return;
    final list = find.descendant(of: find.byType(ListView).hitTestable().last, matching: find.byType(Scrollable)).first;
    for (final delta in const [300.0, -300.0]) {
      try {
        await tester.scrollUntilVisible(finder, delta, scrollable: list, maxScrolls: 25);
        return;
      } on StateError {
        // Not in that direction; try the other, then let waitFor report it properly.
      }
    }
  }

  Future<void> tap(Finder finder) async {
    // A short message can cover the bottom of a list; wait for it rather than tap through it.
    for (var i = 0; i < 20 && find.byType(SnackBar).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    for (var attempt = 0;; attempt++) {
      try {
        await reveal(finder);
        await waitFor(finder);
        await tester.ensureVisible(finder.first);
        await settle(2);
        // A row can still sit just under the navigation bar; nudge the list until the target can really be tapped.
        for (var i = 0; i < 6 && finder.hitTestable().evaluate().isEmpty && find.byType(ListView).hitTestable().evaluate().isNotEmpty; i++) {
          await tester.drag(find.byType(ListView).hitTestable().last, const Offset(0, -160));
          await settle(2);
        }
        await tester.tap(finder.first, warnIfMissed: false);
        break;
      } on StateError {
        if (attempt == 3) rethrow; // the list rebuilt between finding and tapping
      }
    }
    await settle();
  }

  /// Closes an open bottom sheet and waits until it has really gone, so the next tap cannot land on its barrier.
  Future<void> closeSheet() async {
    await tester.tapAt(const Offset(20, 60));
    for (var i = 0; i < 24 && find.byType(BottomSheet).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await settle(4);
  }

  Future<void> tapKey(String key) => tap(find.byKey(Key(key)));
  Future<void> tapText(String text) => tap(find.text(text));
  Future<void> confirmWith(String label) => tap(find.widgetWithText(FilledButton, label));

  Future<void> type(String key, String text) async {
    await reveal(find.byKey(Key(key)));
    await waitFor(find.byKey(Key(key)));
    await tester.ensureVisible(find.byKey(Key(key)));
    // On a real device the first enterText after a focus change can be dropped; focus first, then verify and retry.
    final field = find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText));
    for (var attempt = 0; attempt < 4; attempt++) {
      await tester.tap(find.byKey(Key(key)), warnIfMissed: false);
      await settle(2);
      await tester.enterText(find.byKey(Key(key)), text);
      await settle(2);
      if (tester.widget<EditableText>(field).controller.text == text) return;
    }
    fail('Could not type "$text" into $key');
  }

  Future<void> shot(String name) async {
    await settle(3);
    await binding.takeScreenshot(name);
  }

  Future<void> start(String name) async {
    email = '${name.toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}@example.test';
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await tapKey('auth-toggle');
    await type('auth-name', name);
    await type('auth-email', email);
    await type('auth-password', password);
    await tapKey('auth-submit');
    await waitFor(find.text('No plan yet'), what: 'Today for a new account');
  }

  /// Fills the setup so a workout is due on whatever day this runs, with a recovery day between sessions.
  Future<void> chooseTrainingDaysIncludingToday() async {
    await waitFor(find.byKey(const Key('setup-submit')));
    final weekday = DateTime.now().weekday;
    final days = {weekday, (weekday + 1) % 7 + 1, (weekday + 3) % 7 + 1};
    for (var d = 1; d <= 7; d++) {
      await reveal(find.byKey(Key('weekday-$d')));
      final checked = tester.widget<CheckboxListTile>(find.byKey(Key('weekday-$d'))).value ?? false;
      if (checked != days.contains(d)) await tapKey('weekday-$d');
    }
  }

  /// Signs in to the API directly, as a second device would, and returns the bearer token.
  Future<String> apiToken() async => ((await api.post<Map>('/auth/login', data: {'email': email, 'password': password})).data!)['accessToken'] as String;

  Future<Map<String, dynamic>> snapshot(String token) async =>
      ((await api.get<Map>('/sync/snapshot', options: Options(headers: {'Authorization': 'Bearer $token'}))).data!).cast<String, dynamic>();

  Future<bool> apiReachable() async {
    try {
      return (await api.get<dynamic>('/capabilities')).statusCode == 200;
    } on DioException {
      return false;
    }
  }
}
