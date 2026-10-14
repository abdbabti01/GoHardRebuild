import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Evidence run, not part of the regular suite: Today in Weather mode for three real cities, with the local API
/// started WITHOUT -FoodFixtures so their current conditions are live (Open-Meteo, or MET Norway when it refuses).
/// Prints GOHARD_REC:start / GOHARD_REC:stop around the part worth recording, and captures each city's Today and
/// the "what the scene is based on" panel.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live weather on Today: three cities, their scenes and what each is based on', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Weather Live');

    Future<void> city(String query, String pick, String tag) async {
      await j.tapKey('nav-me');
      await j.tapKey('me-appearance');
      await j.tapKey('appearance-today-background');
      await j.tapKey('today-background-weather');
      if (find.byKey(const Key('weather-change-city')).evaluate().isNotEmpty) {
        await j.tapKey('weather-change-city');
      } else {
        await j.tapKey('weather-location-city');
      }
      await j.type('city-search-field', query);
      await j.tapKey('city-search-go');
      await j.waitFor(find.textContaining(pick), what: '$pick in the results', seconds: 30);
      await j.tap(find.textContaining(pick).first);
      await j.settle(4);
      await j.waitFor(find.byKey(const Key('weather-condition')), what: 'live conditions for $query', seconds: 30);
      await j.shot('live-$tag-basis');
      await tester.pageBack();
      await j.settle(2);
      await tester.pageBack();
      await j.settle(2);
      await j.tapKey('nav-today');
      await j.settle(8);
      await j.shot('live-$tag-today');
      debugPrint('GOHARD_REC:city $query');
      for (var i = 0; i < 28; i++) {
        await tester.pump(const Duration(milliseconds: 250)); // let the sky move for the recording
      }
    }

    debugPrint('GOHARD_REC:start');
    await city('Halifax', 'Nova Scotia', 'halifax');
    await city('Quebec', 'Quebec, Canada', 'quebec');
    await city('Sydney', 'New South Wales', 'sydney');
    debugPrint('GOHARD_REC:stop');
  });
}
