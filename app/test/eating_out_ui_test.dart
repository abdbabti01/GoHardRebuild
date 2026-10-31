import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/coach/coach_client.dart' show AskFailure, AskProblem;
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/coach/coach_rig.dart' show rigImageProvider;
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/eating_out.dart';
import 'package:gohard_rebuild/features/nutrition/eating_out_screen.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart' show NutritionSurface;
import 'package:gohard_rebuild/features/nutrition/restaurants.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';
import 'package:gohard_rebuild/data/sync.dart' show Receipt;

import 'food_fakes.dart';
import 'ui_support.dart';
import 'package:gohard_rebuild/features/plus/entitlement.dart' show CreateGate;

/// Eating out on screen (docs/EATING_OUT.md). The AI is a STUB here (ScriptedEatingOut): these tests show what the app
/// does with an answer and when it asks — never how well a live model reads a request.
/// With `--dart-define=GOHARD_RENDER=true` (and GOHARD_RENDER_LANG=fr|ar) the renders group writes docs/evidence/eating-out.

const day = '2026-10-11';
const _render = bool.fromEnvironment('GOHARD_RENDER');
const _out = renderLanguage == '' ? '../docs/evidence/eating-out' : '../docs/evidence/localization/$renderLanguage/eating-out';
final catalog = RestaurantCatalog.parse(File('assets/data/restaurant-catalog.json').readAsStringSync())!;
const rings = 'subway-ca:potato-rings-4', chicken = 'subway-ca:rotisserie-chicken-6in';

class MemoryEatOut implements EatOutStore {
  MemoryEatOut([this.draft = const EatOutDraft()]);
  EatOutDraft draft;
  @override
  Future<EatOutDraft> load() async => draft;
  @override
  void keep(EatOutDraft d) => draft = d;
}

/// The server's interpretation, scripted. Every request is recorded; nothing is sent anywhere.
class ScriptedEatingOut implements EatingOutClient {
  @override
  void Function()? get onCharged => null;
  final requests = <Json>[];
  Future<Json> Function(Json request) reply = (r) async => answer(r, const {});
  @override
  Future<Json> interpret(Json request) {
    requests.add(request);
    return reply(request);
  }
}

/// Saved meals, recorded: Save as meal must reach only this, never the journal.
class RecordingMeals implements SavedMealRepository {
  @override
  (CreateGate, int) Function()? get mayCreate => null;
  final puts = <MealBody>[];
  @override
  Future<String> put(MealBody body, {String? id}) async {
    puts.add(body);
    return id ?? 'new-id';
  }

  @override
  Future<Receipt> remove(SavedMeal m) async => const Receipt('op', 'pending');
  @override
  Future<void> keepDraft(String key, MealBody body, {MealBody? base}) async {}
  @override
  Future<({MealBody body, MealBody? base})?> draft(String key) async => null;
  @override
  Future<void> dropDraft(String key) async {}
}

Json answer(Json r, Json intent) => {
      'requestId': r['requestId'], 'catalogVersion': catalog.version, 'chainId': r['chainId'], 'orderRevision': r['orderRevision'],
      'intent': {
        'kind': 'constraints', 'mode': 'choose', 'chainId': null, 'maxCalories': null, 'minCalories': null, 'minProtein': null, 'keep': const [], 'exclude': const [],
        'prefer': const [], 'avoid': const [], 'priority': null, 'clarification': null, 'unknownItems': const [], 'problem': null, 'dropped': const [], ...intent,
      },
    };

const lunch = {'maxCalories': 600, 'minProtein': 25, 'keep': [{'itemId': rings, 'quantity': 1}], 'priority': 'protein'};

Future<(List<Override>, FoodFakes, MemoryEatOut, ScriptedEatingOut)> _fixture(WidgetTester tester,
    {EatOutDraft draft = const EatOutDraft(), AppearanceStore? appearance, List<Json> food = const [], CoachPrefs? coach}) async {
  final fakes = FoodFakes(), store = MemoryEatOut(draft), ai = ScriptedEatingOut();
  return (
    [
      if (coach != null) coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore())..value = coach),
      ...(await tester.runAsync(() => overridesFor(day: day, appearance: appearance, food: food)))!,
      ...fakes.overrides,
      restaurantCatalogProvider.overrideWith((ref) async => catalog),
      eatOutStoreProvider.overrideWithValue(store),
      eatingOutClientProvider.overrideWithValue(ai),
      savedMealRepositoryProvider.overrideWithValue(RecordingMeals()),
      savedMealsProvider.overrideWith((ref) => Stream.value(const [])),
      mealDraftsProvider.overrideWith((ref) => Stream.value(const {})),
    ],
    fakes,
    store,
    ai,
  );
}

Future<void> _fonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await inter.load();
  await (FontLoader(serif)..addFont(File('assets/fonts/DMSerifDisplay-Regular.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
  await loadArabicFonts();
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Opens Eating out the way Eat does, and keeps what it returned.
class _Launcher extends StatelessWidget {
  const _Launcher(this.result);
  final List<bool?> result;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(child: TextButton(key: const Key('open'), onPressed: () async => result.add(await openEatingOut(context, dayKey: day, meal: 'Lunch')), child: const Text('open'))));
}

void main() {
  setUpAll(_fonts);

  testWidgets('Eat opens Eating out for the day shown; choosing, targets and building send nothing and log nothing', (tester) async {
    final (overrides, fakes, store, ai) = await _fixture(tester);
    await pumpApp(tester, overrides, size: const Size(390, 1600));
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    await _tap(tester, find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-eating-out'))));
    expect(find.text('Subway · Canada'), findsOneWidget);
    for (final name in ["McDonald's", 'Tim Hortons', 'Pizza Pizza']) {
      expect(find.text('$name · Canada'), findsOneWidget);
    }
    expect(find.text('Menu not added yet: no verified data'), findsNothing);
    final mcd = catalog.chain('mcdonalds-ca')!;
    expect(find.descendant(of: find.byKey(const Key('eatout-chain-mcdonalds-ca')), matching: find.textContaining('${mcd.items.length} verified options')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('eatout-chain-subway-ca')));
    expect(find.textContaining('Subway · Canada · '), findsOneWidget);
    expect(find.byKey(const Key('eatout-no-targets')), findsOneWidget, reason: 'no target is invented');
    await _tap(tester, find.byKey(const Key('eatout-set-targets')));
    await tester.enterText(find.byKey(const Key('eatout-target-max')), '650');
    await tester.enterText(find.byKey(const Key('eatout-target-protein')), '30');
    await _tap(tester, find.byKey(const Key('eatout-targets-apply')));
    expect(find.byKey(const Key('eatout-chip-max')), findsOneWidget);
    expect(find.byKey(const Key('eatout-suggestion-0')), findsOneWidget);
    expect(find.text('Sorted by: most protein'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('eatout-tab-order')));
    await _tap(tester, find.byKey(const Key('eatout-add')));
    await _tap(tester, find.byKey(const Key('eatout-menu-add-$chicken')));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(store.draft.order.lines, const [OrderLine(chicken, 1)]);
    expect(find.text('460 kcal'), findsWidgets);
    expect(ai.requests, isEmpty, reason: 'no AI request without Send');
    expect(fakes.journal.meals, isEmpty);
    expect(fakes.journal.saved, isEmpty);
    expect(store.draft.chainId, 'subway-ca');
  });

  testWidgets('Eating out is its own panel under the summary, before History; it names the catalog\'s chains and opens Eating out for the day picked', (tester) async {
    final (overrides, fakes, _, ai) = await _fixture(tester);
    await pumpApp(tester, overrides, size: const Size(390, 1600));
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    final eat = find.byType(EatScreen);
    await _tap(tester, find.descendant(of: eat, matching: find.byTooltip('Previous day')));
    final panel = find.descendant(of: eat, matching: find.byKey(const Key('eat-eating-out')));
    expect(panel, findsOneWidget);
    expect(find.descendant(of: find.byType(NutritionSurface), matching: find.byKey(const Key('eat-eating-out'))), findsNothing, reason: 'the small summary entry is gone');
    expect(find.descendant(of: find.byType(NutritionSurface), matching: find.byKey(const Key('eat-saved-meals'))), findsOneWidget, reason: 'Saved meals keeps its entry');
    final y = tester.getTopLeft(panel).dy;
    expect(tester.getBottomLeft(find.byType(NutritionSurface)).dy < y && y < tester.getTopLeft(find.descendant(of: eat, matching: find.byKey(const Key('eat-history')))).dy, isTrue);
    for (final words in ['Find a restaurant order that fits your goals.', 'Choose a restaurant ']) {
      expect(find.descendant(of: panel, matching: find.textContaining(words, findRichText: true)), findsOneWidget);
    }
    final line = tester.widget<Text>(find.descendant(of: panel, matching: find.textContaining('Pizza'))).data!;
    expect(line.replaceAll(String.fromCharCode(0xa0), ' '), "McDonald's · Tim Hortons · Subway · Pizza Pizza");
    // One action for screen readers: the whole panel, read once.
    expect(find.bySemanticsLabel(RegExp(r"^Eating out\. Find a restaurant order .*Pizza Pizza\. Choose a restaurant$")), findsOneWidget);

    await _tap(tester, panel);
    expect(tester.widget<EatingOutScreen>(find.byType(EatingOutScreen)).dayKey, '2026-10-10', reason: 'the day picked on Eat, not today');
    expect(ai.requests, isEmpty);
    expect(fakes.journal.meals, isEmpty);
    expect(fakes.journal.saved, isEmpty);
  });

  testWidgets('the coach introduces Eating out once, only on Eat in view, and Find an order opens it for the day; hints or coach off: no introduction, the panel stays', (tester) async {
    const earlier = {'one|eat.saved.new', 'one|eat.meals'}; // the hints before it have had their turn
    final food = [foodEntry('f1', day, 'Breakfast', 'Porridge', '1 bowl', calories: 300)];
    final (overrides, fakes, _, ai) = await _fixture(tester, food: food, coach: const CoachPrefs(dismissed: earlier));
    final c = await pumpApp(tester, overrides, size: const Size(390, 1600));
    expect(c.read(coachPrefsProvider).seen('one', 'eat.out'), isFalse, reason: 'Eat is built behind Today: not used up unseen');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    expect(c.read(coachPrefsProvider).seen('one', 'eat.out'), isFalse, reason: 'not while the keyboard is up');
    tester.view.resetViewInsets();
    // It waits for the next visit rather than popping in as the keyboard closes.
    for (final tab in ['nav-today', 'nav-eat']) {
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
    }
    final coach = find.byKey(const Key('eat-coach'));
    expect(find.descendant(of: coach, matching: find.textContaining('Eating out today?', findRichText: true)), findsOneWidget);
    expect(c.read(coachPrefsProvider).seen('one', 'eat.out'), isTrue);
    await _tap(tester, find.byKey(const Key('eat-coach-eating-out')));
    final screen = tester.widget<EatingOutScreen>(find.byType(EatingOutScreen));
    expect(screen.dayKey, day);
    expect(ai.requests, isEmpty, reason: 'the introduction and its shortcut ask nothing');
    expect(fakes.journal.saved, isEmpty);
    expect(fakes.journal.meals, isEmpty);

    for (final prefs in const [CoachPrefs(dismissed: earlier, hintsEnabled: false), CoachPrefs(dismissed: earlier, onTabs: false)]) {
      await tester.pumpWidget(const SizedBox());
      final (overrides, _, _, _) = await _fixture(tester, food: food, coach: prefs);
      final c = await pumpApp(tester, overrides, size: const Size(390, 1600));
      await tester.tap(find.byKey(const Key('nav-eat')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Eating out today?', findRichText: true), findsNothing);
      expect(c.read(coachPrefsProvider).seen('one', 'eat.out'), isFalse);
      expect(find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-eating-out'))), findsOneWidget);
    }
  });

  testWidgets('nothing logged or saved: the first visit stays about logging; the next visit introduces Eating out, not with the keyboard up, once, never with hints off', (tester) async {
    final coach = find.byKey(const Key('eat-coach'));
    final intro = find.descendant(of: coach, matching: find.textContaining('Eating out today?', findRichText: true));
    Future<void> visit(String tab) async {
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
    }

    final (overrides, fakes, _, ai) = await _fixture(tester);
    final c = await pumpApp(tester, overrides, size: const Size(390, 1600));
    await visit('nav-eat');
    expect(find.descendant(of: coach, matching: find.textContaining('Nothing logged yet today', findRichText: true)), findsOneWidget, reason: 'a first visit is about logging (the day\'s briefing)');
    await tester.drag(find.descendant(of: find.byType(EatScreen), matching: find.byType(Scrollable)).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.drag(find.descendant(of: find.byType(EatScreen), matching: find.byType(Scrollable)).first, const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(intro, findsNothing, reason: 'the words do not change during the visit');

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await visit('nav-today');
    await visit('nav-eat');
    expect(intro, findsNothing, reason: 'not while the keyboard is up');
    expect(c.read(coachPrefsProvider).seen('one', 'eat.out'), isFalse);
    tester.view.resetViewInsets();
    await visit('nav-today');
    await visit('nav-eat');
    expect(intro, findsOneWidget, reason: 'the next visit');
    expect(c.read(coachPrefsProvider).seen('one', 'eat.out'), isTrue);
    await _tap(tester, find.byKey(const Key('eat-coach-eating-out')));
    expect(tester.widget<EatingOutScreen>(find.byType(EatingOutScreen)).dayKey, day);
    expect(ai.requests, isEmpty);
    expect(fakes.journal.saved, isEmpty);

    // After a restart (same account, same phone): not again.
    final kept = c.read(coachPrefsProvider);
    await tester.pumpWidget(const SizedBox());
    final (again, _, _, _) = await _fixture(tester, coach: kept);
    await pumpApp(tester, again, size: const Size(390, 1600));
    await visit('nav-eat');
    expect(intro, findsNothing, reason: 'once');

    // Hints off: the first visit is behind it, still no introduction; the panel stays.
    await tester.pumpWidget(const SizedBox());
    final (off, _, _, _) = await _fixture(tester, coach: const CoachPrefs(hintsEnabled: false, dismissed: {'one|eat.first'}));
    final c3 = await pumpApp(tester, off, size: const Size(390, 1600));
    await visit('nav-eat');
    expect(intro, findsNothing);
    expect(c3.read(coachPrefsProvider).seen('one', 'eat.out'), isFalse);
    expect(find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-eating-out'))), findsOneWidget);
  });

  testWidgets('Send asks once; the targets are shown and editable; Undo; a suggestion is reviewed and logged once, one entry per item', (tester) async {
    final (overrides, fakes, store, ai) = await _fixture(tester, draft: const EatOutDraft(chainId: 'subway-ca'));
    ai.reply = (r) async => answer(r, lunch);
    final result = <bool?>[];
    await pumpApp(tester, overrides, home: _Launcher(result), size: const Size(390, 1800));
    await _tap(tester, find.byKey(const Key('open')));
    await tester.enterText(find.byKey(const Key('eatout-ask')), 'Lunch around 600 calories, more protein, keep the potato rings');
    await _tap(tester, find.byKey(const Key('eatout-send')));
    expect(ai.requests, hasLength(1));
    expect((ai.requests.single['chainId'], ai.requests.single['catalogVersion']), ('subway-ca', catalog.version));
    expect(find.text('Up to 600 kcal'), findsOneWidget);
    expect(find.text('At least 25 g protein'), findsOneWidget);
    expect(find.text('Keep Potato Rings × 1'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      if (find.byKey(Key('eatout-suggestion-$i')).evaluate().isEmpty) continue;
      expect(find.descendant(of: find.byKey(Key('eatout-suggestion-$i')), matching: find.text('1 × Potato Rings')), findsOneWidget, reason: 'kept in every suggestion');
    }
    expect(find.textContaining('Fits your selected targets.'), findsWidgets);

    await _tap(tester, find.byKey(const Key('eatout-undo')));
    expect(find.text('Up to 600 kcal'), findsNothing, reason: 'Undo restores what the answer replaced');
    expect(store.draft.preferences.isEmpty, isTrue);
    await tester.enterText(find.byKey(const Key('eatout-ask')), 'Lunch around 600 calories, more protein, keep the potato rings');
    await _tap(tester, find.byKey(const Key('eatout-send')));
    expect(ai.requests, hasLength(2));

    await _tap(tester, find.byKey(const Key('eatout-use-0')));
    final lines = store.draft.order.lines;
    expect(lines.map((l) => l.itemId), contains(rings));
    expect(fakes.journal.meals, isEmpty, reason: 'using a suggestion only changes the draft');
    await _tap(tester, find.byKey(const Key('eatout-review')));
    final log = find.byKey(const Key('meal-log'));
    await tester.ensureVisible(log);
    await tester.tap(log);
    await tester.tap(log, warnIfMissed: false); // a rapid second tap
    await tester.pumpAndSettle();
    expect(fakes.journal.meals, hasLength(1));
    final logged = fakes.journal.meals.single;
    expect(logged.length, lines.length, reason: 'one ordinary entry per item, no total entry');
    expect([for (final d in logged) (d.dayKey, d.meal, d.item!.source)], everyElement((day, 'Lunch', FoodItem.restaurant)));
    expect(result, [true]);
    expect(store.draft.order.isEmpty, isTrue, reason: 'a logged order is not left ready to log again');
    expect(store.draft.preferences.maxCalories, 600, reason: 'the targets stay for next time');
  });

  testWidgets('a late answer after an edit is not applied; failures keep the question and Retry asks the same request', (tester) async {
    final (overrides, _, store, ai) = await _fixture(tester, draft: const EatOutDraft(chainId: 'subway-ca', preferences: OrderPreferences(maxCalories: 700)));
    final held = Completer<Json>();
    ai.reply = (r) => held.future;
    await pumpApp(tester, overrides, home: const EatingOutScreen(dayKey: day, meal: 'Lunch'), size: const Size(390, 1600));
    await tester.enterText(find.byKey(const Key('eatout-ask')), 'keep the potato rings');
    await tester.tap(find.byKey(const Key('eatout-send')));
    await tester.pump();
    expect(find.text('Reading your request…'), findsWidgets);
    // The person edits while it is being read (the spinner keeps animating: frames, not settle).
    await tester.tap(find.byTooltip('Remove Up to 700 kcal'));
    await tester.pump(const Duration(milliseconds: 100));
    held.complete(answer(ai.requests.single, lunch));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eatout-stale')), findsOneWidget);
    expect(store.draft.preferences.isEmpty, isTrue, reason: 'the newer edit stands');
    expect(find.text('keep the potato rings'), findsOneWidget, reason: 'the question is kept');

    ai.reply = (r) async => throw const AskFailure(AskProblem.unavailable);
    await _tap(tester, find.byKey(const Key('eatout-send')));
    expect(find.byKey(const Key('eatout-problem')), findsOneWidget);
    expect(find.text('keep the potato rings'), findsOneWidget);
    ai.reply = (r) async => throw const AskFailure(AskProblem.busy);
    await _tap(tester, find.byKey(const Key('eatout-retry')));
    expect(ai.requests[2]['requestId'], ai.requests[1]['requestId'], reason: 'Retry is the same request');
    ai.reply = (r) async => throw const CatalogMismatch();
    await _tap(tester, find.byKey(const Key('eatout-retry')));
    expect(find.byKey(const Key('eatout-mismatch')), findsOneWidget);
    expect(store.draft.preferences.isEmpty, isTrue, reason: 'no failure invents an answer');

    // A question back is said, and changes nothing.
    ai.reply = (r) async => answer(r, const {'kind': 'clarify', 'clarification': 'Do you mean money or calories by budget?'});
    await tester.enterText(find.byKey(const Key('eatout-ask')), 'something on a budget');
    await _tap(tester, find.byKey(const Key('eatout-send')));
    expect(find.textContaining('Do you mean money or calories by budget?', findRichText: true), findsOneWidget);
    expect(store.draft.preferences.isEmpty, isTrue);
  });

  testWidgets('Save as meal opens the ordinary editor with restaurant foods and logs nothing', (tester) async {
    final (overrides, fakes, _, _) = await _fixture(tester, draft: const EatOutDraft(chainId: 'subway-ca', order: RestaurantOrder([OrderLine(chicken, 1), OrderLine(rings, 2)])));
    await pumpApp(tester, overrides, home: const EatingOutScreen(dayKey: day, meal: 'Lunch'), size: const Size(390, 1600));
    await _tap(tester, find.byKey(const Key('eatout-tab-order')));
    expect(find.text('760 kcal'), findsOneWidget, reason: '460 + 2 × 150, computed from the catalog');
    await _tap(tester, find.byKey(const Key('eatout-save-meal')));
    expect(find.text('Subway order'), findsOneWidget);
    expect(find.text('Rotisserie-Style Chicken · 6-inch'), findsOneWidget);
    expect(fakes.journal.meals, isEmpty);
    expect(fakes.journal.saved, isEmpty);
  });

  testWidgets('Arabic runs right to left and French fits at 320 px with large text, keyboard space included', (tester) async {
    for (final lang in ['ar', 'fr-CA']) {
      final (overrides, _, _, _) = await _fixture(tester, draft: const EatOutDraft(chainId: 'subway-ca', preferences: OrderPreferences(maxCalories: 600, minProtein: 25, keep: {rings: 1})));
      final c = await pumpApp(tester, overrides, home: const EatingOutScreen(dayKey: day, meal: 'Lunch'), size: const Size(320, 900), textScale: 1.6, settle: false);
      c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: lang);
      // As on a phone: the field is tapped, then the keyboard comes up and the field is kept in view.
      await tester.ensureVisible(find.byKey(const Key('eatout-ask')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eatout-ask')));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: lang);
      expect(tester.getRect(find.byKey(const Key('eatout-send'))).bottom, lessThanOrEqualTo(900 - 300), reason: '$lang: Send stays above the keyboard');
      expect(Directionality.of(tester.element(find.byKey(const Key('eatout-send')))), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      tester.view.resetViewInsets();
      final chip = find.byKey(const Key('eatout-chip-keep-$rings'));
      await tester.scrollUntilVisible(chip, 200, scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: chip, matching: find.textContaining('Potato Rings')), findsOneWidget, reason: '$lang: the official name is kept, not translated');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('under Reduce Motion and with the coach off, the help is a still avatar and asking still works', (tester) async {
    final (overrides, _, _, ai) = await _fixture(tester, draft: const EatOutDraft(chainId: 'subway-ca'));
    final c = await pumpApp(tester, overrides, home: const EatingOutScreen(dayKey: day, meal: 'Lunch'), size: const Size(390, 1400), settle: false);
    c.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
    c.read(coachPrefsProvider.notifier).setOnTabs(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eatout-coach-small')), findsOneWidget);
    expect(find.byKey(const Key('eatout-coach')), findsNothing);
    await _tap(tester, find.byKey(const Key('eatout-coach-small')));
    expect(tester.binding.focusManager.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>()?.key, const Key('eatout-ask'));
    expect(ai.requests, isEmpty, reason: 'the avatar opens the field; it sends nothing');
  });

  group('renders', () {
    if (!_render) {
      test('eating out renders are skipped without GOHARD_RENDER', () {});
      return;
    }
    Future<void> shot(WidgetTester tester, EatOutDraft draft, String name, {Size size = const Size(390, 1400), ThemeMode mode = ThemeMode.light, double text = 1, Future<void> Function()? then}) async {
      final store = AppearanceStore(MemorySecretStore())
        ..accent = Accent.blue
        ..mode = mode;
      final (overrides, _, _, ai) = await _fixture(tester, draft: draft, appearance: store);
      ai.reply = (r) async => answer(r, lunch);
      final c = await pumpApp(tester, overrides, home: const EatingOutScreen(dayKey: day, meal: 'Lunch'), size: size, textScale: text, insets: phoneInsets, settle: false);
      await tester.runAsync(() => c.read(rigImageProvider(c.read(coachPrefsProvider).guide).future)); // the guide's painted bust
      await tester.pumpAndSettle();
      await then?.call();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
      await tester.runAsync(() async {
        final file = File('$_out/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }

    const asked = EatOutDraft(chainId: 'subway-ca');
    Future<void> ask(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('eatout-ask')), 'Lunch around 600 calories, more protein, keep the potato rings');
      await tester.tap(find.byKey(const Key('eatout-send')));
      await tester.pumpAndSettle();
    }

    testWidgets('chains, suggestions, comparison and order', (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await shot(tester, const EatOutDraft(), 'chains-${mode.name}', mode: mode);
        await shot(tester, asked, 'suggestions-${mode.name}', size: const Size(390, 2000), mode: mode, then: () => ask(tester));
        await shot(tester, const EatOutDraft(chainId: 'subway-ca', order: RestaurantOrder([OrderLine('subway-ca:tuna-6in', 1), OrderLine(rings, 1)])), 'compare-${mode.name}',
            size: const Size(390, 2000), mode: mode, then: () => ask(tester));
        await shot(tester, const EatOutDraft(chainId: 'pizzapizza-ca', order: RestaurantOrder([OrderLine('pizzapizza-ca:small-pepperoni-slice', 2), OrderLine('pizzapizza-ca:classic-wings-5', 1)]),
            preferences: OrderPreferences(maxCalories: 900, minProtein: 40)), 'order-${mode.name}', size: const Size(390, 1500), mode: mode, then: () async {
          await tester.tap(find.byKey(const Key('eatout-tab-order')));
          await tester.pumpAndSettle();
        });
      }
      await shot(tester, asked, 'suggestions-320-large', size: const Size(320, 2600), text: 2, then: () => ask(tester));
    });

    testWidgets('320 px, large text, keyboard open', (tester) async {
      await shot(tester, asked, 'ask-320-keyboard', size: const Size(320, 700), text: 1.6, then: () async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.tap(find.byKey(const Key('eatout-ask')));
        await tester.pumpAndSettle();
      });
      tester.view.resetViewInsets();
    });
  });
}
