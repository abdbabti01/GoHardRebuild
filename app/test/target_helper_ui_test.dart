import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/units.dart' show LoadUnit;
import 'package:gohard_rebuild/core/widgets.dart' show ChoiceTile;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/body/body_prefs.dart';
import 'package:gohard_rebuild/features/body/body_screens.dart' show BodyProgressScreen;
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_history.dart' show NutritionHistoryScreen;
import 'package:gohard_rebuild/features/nutrition/target_estimate.dart';
import 'package:gohard_rebuild/features/nutrition/target_helper.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

const _day = '2026-11-17';

/// Help me set my targets (docs/NUTRITION_TARGETS.md): the three steps, the weigh-in, units, the result's ledger and
/// details, edits that are kept, refusals, and that only Use these targets saves anything. Expected numbers are the
/// hand-worked reference values of target_estimate_test.dart.

/// A page that opens the helper and keeps what it popped with.
class _Launcher extends StatefulWidget {
  const _Launcher();
  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  Object? popped = 'open';
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(child: TextButton(key: const Key('open'), onPressed: () async {
        final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const TargetHelperScreen()));
        setState(() => popped = r);
      }, child: Text('$popped'))));
}

Json _weighIn(String day, double kg) => {'id': 'm-$day', 'dayKey': day, 'weightKg': kg, 'revision': 1, 'isDeleted': false, 'recordedAtUtc': '${day}T07:00:00Z'};

Future<(ProviderContainer, RecordingProfiles)> _open(WidgetTester tester,
    {int? calorieGoal, int? proteinGoal, List<Json> metrics = const [], bool coach = true, double textScale = 1, String? language, Size size = const Size(390, 2400), EdgeInsets insets = EdgeInsets.zero}) async {
  final profiles = RecordingProfiles();
  final List<Override> overrides = [
    ...(await tester.runAsync(() => overridesFor(day: _day, calorieGoal: calorieGoal, proteinGoal: proteinGoal, bodyMetrics: metrics)))!,
    profileRepositoryProvider.overrideWithValue(profiles),
    // Nothing here may write a weigh-in: reading the body repository at all fails the test.
    bodyRepositoryProvider.overrideWith((ref) => throw StateError('the target helper must not touch Body progress')),
  ];
  final c = await pumpApp(tester, overrides, home: const _Launcher(), size: size, textScale: textScale, insets: insets);
  if (!coach) c.read(coachPrefsProvider.notifier).setOnTabs(false);
  if (language != null) c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(language));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return (c, profiles);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String _field(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

/// Step 2 for a man: age, height in cm, an activity; the weight is the latest weigh-in unless [kg] is given.
Future<void> _about(WidgetTester tester, {String age = '34', String cm = '170', String? kg, String activity = 'inactive', String sex = 'male'}) async {
  await _type(tester, 'tgt-age', age);
  await _type(tester, 'tgt-height-cm', cm);
  if (kg != null) await _type(tester, 'tgt-weight', kg);
  await _tap(tester, 'tgt-sex-$sex');
  await _tap(tester, 'tgt-activity-$activity');
}

Future<void> _goal(WidgetTester tester, String goal, {String? priority}) async {
  await _tap(tester, 'tgt-goal-$goal');
  if (priority != null) await _tap(tester, 'tgt-priority-$priority');
  await _tap(tester, 'tgt-continue');
}

void main() {
  testWidgets('Eat › Edit goals keeps direct editing and offers Help me set my targets as the secondary way in', (tester) async {
    final profiles = RecordingProfiles();
    await pumpApp(tester, [...(await tester.runAsync(() => overridesFor(day: _day)))!, profileRepositoryProvider.overrideWithValue(profiles)], size: const Size(390, 2400));
    await _tap(tester, 'nav-eat');
    expect(find.descendant(of: find.byKey(const Key('eat-goals')), matching: find.text('Set daily goals')), findsOneWidget);
    await _tap(tester, 'eat-goals');
    expect(find.byKey(const Key('goal-calories')), findsOneWidget, reason: 'manual entry is right there');
    expect(find.widgetWithText(OutlinedButton, 'Help me set my targets'), findsOneWidget, reason: 'secondary (outlined), not the main action');
    await _tap(tester, 'goals-help');
    expect(find.text("What's your goal?"), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await _tap(tester, 'tgt-manual-0');
    expect(find.byKey(const Key('goal-calories')), findsOneWidget);
    expect(profiles.goals, isEmpty);
  });

  testWidgets('nothing is chosen for the person: recomposition asks what comes first, activity has no default', (tester) async {
    await _open(tester, metrics: [_weighIn('2026-11-10', 80)]);
    FilledButton continueButton() => tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('tgt-continue')), matching: find.byType(FilledButton)));
    expect(continueButton().onPressed, isNull, reason: 'a goal first');
    await _tap(tester, 'tgt-goal-recomp');
    expect(find.text('What comes first?'), findsOneWidget);
    expect(find.text('A moderate calorie deficit. Building muscle is less likely while eating less.'), findsOneWidget, reason: 'the trade-off is said');
    expect(continueButton().onPressed, isNull, reason: 'no default priority');
    await _tap(tester, 'tgt-priority-fatLoss');
    expect(continueButton().onPressed, isNotNull);
    await _tap(tester, 'tgt-continue');

    // One question for the whole usual week; workouts are already in it; nothing selected.
    expect(find.text('How active is your usual week?'), findsOneWidget);
    expect(_text(tester, 'tgt-activity-help'), allOf(contains("don't add exercise calories"), contains('How often you train is only part of it')));
    // Mostly seated describes daily life outside training; a few workouts fit there only when the rest of the week is seated.
    expect(find.textContaining("Outside training, your day is mostly seated"), findsOneWidget);
    expect(find.textContaining("If that's your week, a few one-hour workouts (3 or 4) still fit here."), findsOneWidget);
    for (final t in tester.widgetList<ChoiceTile<ActivityLevel?>>(find.byType(ChoiceTile<ActivityLevel?>))) {
      expect(t.groupValue, isNull);
    }
    await _tap(tester, 'tgt-continue');
    expect(find.text('Choose one to continue'), findsNWidgets(2), reason: 'sex and activity');
    expect(find.text('Your starting targets'), findsNothing);
  });

  testWidgets('the reference man losing weight: the ledger, the details used, and only calories and protein saved', (tester) async {
    // A phone-sized screen, so step 2 really scrolls.
    final (c, profiles) = await _open(tester, metrics: [_weighIn('2026-11-10', 80)], size: const Size(390, 844), insets: phoneInsets);
    final massBefore = c.read(bodyUnitsProvider).mass;
    await _goal(tester, 'lose');
    // A weight for this estimate only, in pounds.
    await _tap(tester, 'tgt-other-weight');
    await _tap(tester, 'tgt-weight-unit-lb');
    await _about(tester, kg: '199');
    // Step 2 scrolled to its end; step 3 must open at its top, its title clear of the app bar.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tgt-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Your starting targets'), findsOneWidget);
    expect(tester.getRect(find.text('Your starting targets')).top, greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom));
    expect(find.text('Step 3 of 3').hitTestable(), findsOneWidget);

    expect(_text(tester, 'tgt-goal-name'), 'Lose weight');
    // VoiceOver: the goal is read as one item and Change is its own button.
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(find.byKey(const Key('tgt-change-goal'))), isSemantics(label: 'Change goal', isButton: true));
    expect(tester.getSemantics(find.byKey(const Key('tgt-goal-name'))), isSemantics(label: 'Your goal\nLose weight'));
    semantics.dispose();
    expect(_text(tester, 'tgt-approach'), 'Eat a moderate amount below your estimated maintenance, with more protein.');
    expect((_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein')), ('2260', '145'));
    expect(_text(tester, 'tgt-calories-status'), 'Suggested estimate');
    expect((_text(tester, 'tgt-maintenance'), _text(tester, 'tgt-adjustment'), _text(tester, 'tgt-target')), ('2,760 kcal', '500 kcal less', '2,260 kcal'));
    expect(_text(tester, 'tgt-protein-math'), '145 g');
    expect(find.text('Protein: 1.6 g per kg × 199.0 lb'), findsOneWidget);
    expect(find.byKey(const Key('tgt-coach')), findsOneWidget);
    expect(find.textContaining('A day like yours uses about 2,760\u00A0kcal', findRichText: true), findsWidgets, reason: "the guide speaks to this calculation's numbers");

    // Details used, collapsed until asked for.
    expect(find.byKey(const Key('tgt-used-age')), findsNothing);
    await _tap(tester, 'tgt-details');
    expect((_text(tester, 'tgt-used-age'), _text(tester, 'tgt-used-height'), _text(tester, 'tgt-used-weight')), ('34 years', '170 cm', '199.0 lb'));
    expect(_text(tester, 'tgt-used-weight-note'), 'Entered for this estimate only; not added to Body progress');
    expect((_text(tester, 'tgt-used-sex'), _text(tester, 'tgt-used-activity')), ('Male', 'Mostly seated'));
    await _tap(tester, 'tgt-macros');
    expect((_text(tester, 'tgt-carbs'), _text(tester, 'tgt-fat')), ('about 250 g', 'about 75 g'));
    await _tap(tester, 'tgt-how');
    expect(_text(tester, 'tgt-how-2'), contains('an estimate, not an exact requirement'));

    await _tap(tester, 'tgt-use');
    expect(profiles.goals, [(2260, 145)]);
    expect(profiles.waterGoals, isEmpty, reason: 'the water goal is not touched');
    expect(c.read(bodyUnitsProvider).mass, massBefore, reason: "switching units here leaves Body progress's units");
    expect(massBefore, isNot(LoadUnit.lb));
    expect(find.text('Targets saved'), findsOneWidget);
  });

  testWidgets('an edited target stays the person\'s own when the goal or details change, and can go back to the suggestion', (tester) async {
    final (_, profiles) = await _open(tester, calorieGoal: 2000, proteinGoal: 100, metrics: [_weighIn('2026-11-10', 90.26488)]);
    await _goal(tester, 'lose');
    await _about(tester);
    await _tap(tester, 'tgt-continue');
    expect(_text(tester, 'tgt-calories-status'), 'Suggested estimate · Current goal 2,000 kcal');
    await _type(tester, 'tgt-calories', '2,100');
    expect(_text(tester, 'tgt-calories-status'), 'Your edited target · suggested 2,260 kcal · Current goal 2,000 kcal');
    expect(_text(tester, 'tgt-protein-status'), 'Suggested estimate · Current goal 100 g');

    // Change details: a lightly active week. The edit stays; the untouched protein follows (same goal, same 145 g).
    await _tap(tester, 'tgt-details');
    await _tap(tester, 'tgt-change-details');
    expect(_field(tester, 'tgt-age'), '34', reason: 'answers are kept');
    await _tap(tester, 'tgt-activity-lowActive');
    await _tap(tester, 'tgt-continue');
    expect(_field(tester, 'tgt-calories'), '2,100');
    expect(_text(tester, 'tgt-calories-status'), startsWith('Your edited target · suggested 2,470 kcal'));
    expect(_text(tester, 'tgt-target'), '2,470 kcal');

    // Change the goal: recomposition, steady weight. Protein had not been edited, so it follows to 180 g.
    await _tap(tester, 'tgt-change-goal');
    await _goal(tester, 'recomp', priority: 'steady');
    await _tap(tester, 'tgt-continue');
    expect(_text(tester, 'tgt-goal-priority'), 'Keep my weight about steady');
    expect(_text(tester, 'tgt-adjustment'), 'None');
    expect((_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein')), ('2,100', '180'));
    await _tap(tester, 'tgt-calories-reset');
    expect(_field(tester, 'tgt-calories'), '2970');
    expect(find.byKey(const Key('tgt-calories-reset')), findsNothing);

    // Cancel saves nothing.
    await _tap(tester, 'tgt-cancel');
    expect(profiles.goals, isEmpty);
    expect(find.text('null'), findsOneWidget);
  });

  testWidgets('the reference woman in feet, inches and pounds: fat loss first, with the protein cap explained', (tester) async {
    final (_, profiles) = await _open(tester, coach: false);
    await _goal(tester, 'recomp', priority: 'fatLoss');
    await _tap(tester, 'tgt-height-unit-inch');
    await _tap(tester, 'tgt-weight-unit-lb');
    await _type(tester, 'tgt-age', '28');
    await _type(tester, 'tgt-height-ft', '5');
    await _type(tester, 'tgt-height-in', '4');
    await _type(tester, 'tgt-weight', '222');
    await _tap(tester, 'tgt-sex-female');
    await _tap(tester, 'tgt-activity-inactive');
    await _tap(tester, 'tgt-continue');
    expect((_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein')), ('2000', '175'));
    expect((_text(tester, 'tgt-maintenance'), _text(tester, 'tgt-adjustment')), ('2,500 kcal', '500 kcal less'));
    expect(_text(tester, 'tgt-protein-math-note'), contains('35% of calories'));
    expect(_text(tester, 'tgt-approach'), contains('below maintenance'));
    // The guide is off: the same explanation as plain text.
    expect(find.byKey(const Key('tgt-coach')), findsNothing);
    expect(_text(tester, 'tgt-plain'), startsWith('A day like yours uses about 2,500\u00A0kcal. Start at 2,000\u00A0kcal with 175\u00A0g of protein'));
    await _tap(tester, 'tgt-details');
    expect(_text(tester, 'tgt-used-height'), '5 ft 4 in');
    expect(profiles.goals, isEmpty);
  });

  testWidgets('metric and imperial answers for the same body give the same targets', (tester) async {
    await _open(tester);
    await _goal(tester, 'gain');
    expect(find.byKey(const Key('tgt-latest')), findsNothing, reason: 'no weigh-in yet: the field is asked for');
    await _about(tester, cm: '162.56', kg: '100.69751', sex: 'female', age: '28');
    await _tap(tester, 'tgt-continue');
    expect((_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein')), ('2860', '160'));

    await _tap(tester, 'tgt-back');
    await _tap(tester, 'tgt-height-unit-inch');
    await _tap(tester, 'tgt-weight-unit-lb');
    expect((_field(tester, 'tgt-height-ft'), _field(tester, 'tgt-height-in'), _field(tester, 'tgt-weight')), ('5', '4', '222'), reason: 'switching converts what was typed');
    await _tap(tester, 'tgt-continue');
    expect((_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein')), ('2860', '160'));
  });

  testWidgets('missing answers and answers outside the method get a reason and a way to set targets manually', (tester) async {
    await _open(tester, metrics: [_weighIn('2026-11-10', 48)]);
    await _goal(tester, 'lose');
    await _tap(tester, 'tgt-continue');
    expect(find.text('Needed for this estimate'), findsNWidgets(2), reason: 'age and height; the weight is the weigh-in');
    expect(find.text('Your starting targets'), findsNothing, reason: 'no numbers from incomplete answers');

    await _type(tester, 'tgt-age', '17');
    await _type(tester, 'tgt-height-cm', '170');
    await _tap(tester, 'tgt-sex-female');
    await _tap(tester, 'tgt-activity-inactive');
    await _tap(tester, 'tgt-continue');
    expect(find.textContaining('for adults 19 and over'), findsOneWidget);
    expect(find.byKey(const Key('tgt-problem-manual')), findsOneWidget);

    // 48 kg at 170 cm is a BMI under 18.5: no weight-loss estimate.
    await _type(tester, 'tgt-age', '25');
    await _tap(tester, 'tgt-continue');
    expect(find.textContaining("won't estimate a weight-loss target"), findsOneWidget);
    expect(find.text('Your starting targets'), findsNothing);

    await _type(tester, 'tgt-height-cm', '300');
    await _tap(tester, 'tgt-continue');
    expect(find.textContaining('Outside what this estimate supports'), findsOneWidget);
    await _type(tester, 'tgt-height-cm', 'tall');
    await _tap(tester, 'tgt-continue');
    expect(find.text('Enter a number'), findsOneWidget);

    await _tap(tester, 'tgt-sex-skip');
    expect(find.text('true'), findsOneWidget, reason: 'Set targets manually leaves for the goals form');
  });

  testWidgets('the goals form rules still apply to edited numbers', (tester) async {
    final (_, profiles) = await _open(tester, metrics: [_weighIn('2026-11-10', 80)]);
    await _goal(tester, 'maintain');
    await _about(tester);
    await _tap(tester, 'tgt-continue');
    await _type(tester, 'tgt-calories', '300');
    await _tap(tester, 'tgt-use');
    expect(find.textContaining('500 to 10,000'), findsWidgets);
    expect(profiles.goals, isEmpty);
    expect(find.byType(TargetHelperScreen), findsOneWidget, reason: 'a refused save keeps the page and its numbers');
    // An edited protein that, with the fat share, passes the calories: the breakdown says there is no room for carbs.
    await _type(tester, 'tgt-calories', '1000');
    await _type(tester, 'tgt-protein', '300');
    await _tap(tester, 'tgt-macros');
    expect(_text(tester, 'tgt-carbs'), 'about 0 g');
    expect(find.byKey(const Key('tgt-macro-over')), findsOneWidget);
  });

  testWidgets('Checking your starting point links to Body progress and History & trends, and changes nothing', (tester) async {
    final (_, profiles) = await _open(tester, metrics: [_weighIn('2026-11-10', 80)]);
    await _goal(tester, 'maintain');
    await _about(tester);
    await _tap(tester, 'tgt-continue');
    await _tap(tester, 'tgt-check');
    expect(_text(tester, 'tgt-check-1'), contains("isn't a zero"));
    expect(_text(tester, 'tgt-check-3'), contains('never changes your targets'));
    await _tap(tester, 'tgt-open-history');
    expect(find.byType(NutritionHistoryScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_field(tester, 'tgt-calories'), isNotEmpty, reason: 'back on the result, as it was');
    expect(find.byType(BodyProgressScreen), findsNothing);
    expect(profiles.goals, isEmpty);
  });

  for (final language in ['en', 'fr-CA', 'ar']) {
    testWidgets('$language at 320 px and 200 % text: every step lays out without overflow and the result is the same', (tester) async {
      await _open(tester, language: language, textScale: 2, metrics: [_weighIn('2026-11-10', 80)], size: const Size(320, 2400));
      await _goal(tester, 'recomp', priority: 'steady');
      expect(tester.takeException(), isNull);
      await _type(tester, 'tgt-age', '30');
      await _type(tester, 'tgt-height-cm', language == 'fr-CA' ? '180,0' : '180');
      await _tap(tester, 'tgt-sex-male');
      await _tap(tester, 'tgt-activity-active');
      await _tap(tester, 'tgt-continue');
      expect(tester.takeException(), isNull);
      // Man, 30 y, 180 cm, 80 kg, active: 1,004.82 − 324.90 + 1,173.60 + 1,272.80 = 3,126.32 → 3,130; 2.0 × 80 = 160 g.
      expect((_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein')), ('3130', '160'));
      for (final k in ['tgt-details', 'tgt-macros', 'tgt-how', 'tgt-check']) {
        await _tap(tester, k);
        expect(tester.takeException(), isNull, reason: k);
      }
      if (language == 'ar') expect(Directionality.of(tester.element(find.byKey(const Key('tgt-approach')))), TextDirection.rtl);
    });
  }
}
