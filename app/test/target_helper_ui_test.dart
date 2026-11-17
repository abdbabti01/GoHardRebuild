import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/widgets.dart' show ChoiceTile;
import 'package:gohard_rebuild/features/nutrition/target_estimate.dart' show TargetGoal;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/nutrition/target_helper.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

const _day = '2026-11-17';

/// Help me set my targets (docs/NUTRITION_TARGETS.md): the three steps, the weigh-in, units, refusals, and that only
/// Use these targets saves anything.

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

Future<(ProviderContainer, RecordingProfiles)> _open(WidgetTester tester, {int? calorieGoal, int? proteinGoal, List<Json> metrics = const [], bool coach = true, double textScale = 1, String? language}) async {
  final profiles = RecordingProfiles();
  final List<Override> overrides = [
    ...(await tester.runAsync(() => overridesFor(day: _day, calorieGoal: calorieGoal, proteinGoal: proteinGoal, bodyMetrics: metrics)))!,
    profileRepositoryProvider.overrideWithValue(profiles),
  ];
  final c = await pumpApp(tester, overrides, home: const _Launcher(), size: const Size(390, 2400), textScale: textScale);
  if (!coach) c.read(coachPrefsProvider.notifier).setOnTabs(false);
  if (language != null) c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(language));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return (c, profiles);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
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

/// Step 2 for a 30-year-old man, 180 cm, active; the weight is the latest weigh-in unless [kg] is given.
Future<void> _about(WidgetTester tester, {String age = '30', String cm = '180', String? kg}) async {
  await _type(tester, 'tgt-age', age);
  await _type(tester, 'tgt-height-cm', cm);
  if (kg != null) await _type(tester, 'tgt-weight', kg);
  await _tap(tester, 'tgt-sex-male');
  await _tap(tester, 'tgt-activity-active');
}

void main() {
  testWidgets('Eat › Edit goals keeps direct editing and offers Help me set my targets as the secondary way in', (tester) async {
    final profiles = RecordingProfiles();
    await pumpApp(tester, [...(await tester.runAsync(() => overridesFor(day: _day)))!, profileRepositoryProvider.overrideWithValue(profiles)], size: const Size(390, 2400));
    await _tap(tester, 'nav-eat');
    // No targets yet: the existing summary says Set daily goals.
    expect(find.descendant(of: find.byKey(const Key('eat-goals')), matching: find.text('Set daily goals')), findsOneWidget);
    await _tap(tester, 'eat-goals');
    expect(find.byKey(const Key('goal-calories')), findsOneWidget, reason: 'manual entry is right there');
    expect(find.byKey(const Key('goal-save')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Help me set my targets'), findsOneWidget, reason: 'secondary (outlined), not the main action');
    await _tap(tester, 'goals-help');
    expect(find.text("What's your goal?"), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    // Set targets manually goes back to the goals sheet, with nothing saved.
    await _tap(tester, 'tgt-manual-0');
    expect(find.byKey(const Key('goal-calories')), findsOneWidget);
    expect(profiles.goals, isEmpty);
  });

  testWidgets('every goal from the latest weigh-in: distinct where the method supports it, explained where it does not', (tester) async {
    final (_, profiles) = await _open(tester, metrics: [_weighIn('2026-11-02', 82), _weighIn('2026-11-10', 80)]);
    expect(find.widgetWithText(ChoiceTile<TargetGoal?>, 'Lose fat and build muscle'), findsOneWidget);
    for (final line in ['Keep my weight roughly steady.', 'Aim to gradually lower my weight.', 'Support strength training and muscle growth; my weight may go up.',
        'Focus on body composition; my weight may change slowly.']) {
      expect(find.text(line), findsOneWidget);
    }
    expect(tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('tgt-continue')), matching: find.byType(FilledButton))).onPressed, isNull, reason: 'a goal first');

    final results = <String, (String, String, String)>{};
    for (final goal in ['maintain', 'lose', 'gain', 'recomp']) {
      await _tap(tester, 'tgt-goal-$goal');
      await _tap(tester, 'tgt-continue');
      // The latest weigh-in, with its own date; nothing to type.
      expect(_text(tester, 'tgt-latest-weight'), '80.0 kg');
      expect(_text(tester, 'tgt-latest-date'), 'Recorded Nov 10');
      if (goal == 'maintain') await _about(tester);
      await _tap(tester, 'tgt-continue');
      expect(find.text('Your starting targets'), findsOneWidget);
      results[goal] = (_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein'), _text(tester, 'tgt-why'));
      await _tap(tester, 'tgt-back');
      expect(_field(tester, 'tgt-age'), '30', reason: 'Back keeps the answers');
      await _tap(tester, 'tgt-back');
    }
    expect([for (final r in results.values) (r.$1, r.$2)], [('3130', '110'), ('2630', '130'), ('3480', '130'), ('3130', '160')]);
    expect(results['lose']!.$3, contains('500 kcal a day below'));
    expect(results['gain']!.$3, contains('Muscle grows with strength training'));
    expect(results['recomp']!.$3, contains('the same as Maintain weight'), reason: 'equal calories are explained, not forced apart');
    expect(results.values.map((r) => r.$3).join(), isNot(contains('per week')), reason: 'no rate of change is promised');
    expect(profiles.goals, isEmpty, reason: 'nothing is saved before Use these targets');
  });

  testWidgets('metric and imperial answers for the same body give the same targets; a typed weight is not a weigh-in', (tester) async {
    final (_, profiles) = await _open(tester);
    await _tap(tester, 'tgt-goal-gain');
    await _tap(tester, 'tgt-continue');
    expect(find.byKey(const Key('tgt-latest')), findsNothing, reason: 'no weigh-in yet: the field is asked for');
    expect(find.text('Used only for this estimate. It isn\'t added to Body progress.'), findsOneWidget);
    await _about(tester, cm: '180.34', kg: '80');
    await _tap(tester, 'tgt-continue');
    final metric = (_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein'));

    await _tap(tester, 'tgt-back');
    await _tap(tester, 'tgt-height-unit-inch');
    await _tap(tester, 'tgt-weight-unit-lb');
    expect((_field(tester, 'tgt-height-ft'), _field(tester, 'tgt-height-in'), _field(tester, 'tgt-weight')), ('5', '11', '176.4'), reason: 'switching converts what was typed');
    await _tap(tester, 'tgt-continue');
    expect((_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein')), metric);

    // Typed from scratch in feet, inches and pounds.
    await _tap(tester, 'tgt-back');
    await _type(tester, 'tgt-height-ft', '5');
    await _type(tester, 'tgt-height-in', '11');
    await _type(tester, 'tgt-weight', '176.37');
    await _tap(tester, 'tgt-continue');
    expect((_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein')), metric);
    expect(profiles.goals, isEmpty);
  });

  testWidgets('missing answers and answers outside the method get a reason and a way to set targets manually', (tester) async {
    await _open(tester, metrics: [_weighIn('2026-11-10', 48)]);
    await _tap(tester, 'tgt-goal-lose');
    await _tap(tester, 'tgt-continue');
    await _tap(tester, 'tgt-continue');
    expect(find.text('Needed for this estimate'), findsNWidgets(2), reason: 'age and height; the weight is the weigh-in');
    expect(find.text('Choose one to continue'), findsNWidgets(2));
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

  testWidgets('with targets saved: Current → Suggested, edits before saving, and only calories and protein are saved', (tester) async {
    final (_, profiles) = await _open(tester, calorieGoal: 2000, proteinGoal: 100, metrics: [_weighIn('2026-11-10', 80)]);
    await _tap(tester, 'tgt-goal-maintain');
    await _tap(tester, 'tgt-continue');
    await _about(tester);
    await _tap(tester, 'tgt-continue');
    expect(_text(tester, 'tgt-calories-compare'), 'Current 2,000 kcal → suggested 3,130 kcal');
    expect(_text(tester, 'tgt-protein-compare'), 'Current 100 g → suggested 110 g');
    expect(find.byKey(const Key('tgt-coach')), findsOneWidget);

    // Carbs and fat: under See macro breakdown, labelled as estimates only, following the edited numbers.
    expect(find.byKey(const Key('tgt-macro-note')), findsNothing);
    await _tap(tester, 'tgt-macros');
    expect(_text(tester, 'tgt-macro-note'), startsWith('Estimates only.'));
    expect((_text(tester, 'tgt-carbs'), _text(tester, 'tgt-fat')), ('about 435 g', 'about 105 g'));
    await _type(tester, 'tgt-calories', '3000');
    expect((_text(tester, 'tgt-carbs'), _text(tester, 'tgt-fat')), ('about 415 g', 'about 100 g'));

    // Cancel keeps the existing targets.
    await _tap(tester, 'tgt-cancel');
    expect(profiles.goals, isEmpty);
    expect(find.text('null'), findsOneWidget);

    await _tap(tester, 'open');
    await _tap(tester, 'tgt-goal-maintain');
    await _tap(tester, 'tgt-continue');
    await _about(tester);
    await _tap(tester, 'tgt-continue');
    await _type(tester, 'tgt-calories', '3,000');
    await _tap(tester, 'tgt-use');
    expect(profiles.goals, [(3000, 110)]);
    expect(profiles.waterGoals, isEmpty, reason: 'the water goal is not touched');
    expect(find.text('Targets saved'), findsOneWidget);
    expect(find.byType(TargetHelperScreen), findsNothing);
  });

  testWidgets('the goals form rules still apply to edited numbers', (tester) async {
    final (_, profiles) = await _open(tester, metrics: [_weighIn('2026-11-10', 80)]);
    await _tap(tester, 'tgt-goal-maintain');
    await _tap(tester, 'tgt-continue');
    await _about(tester);
    await _tap(tester, 'tgt-continue');
    expect(_text(tester, 'tgt-calories-compare'), 'Suggested 3,130 kcal');
    await _type(tester, 'tgt-calories', '300');
    await _tap(tester, 'tgt-use');
    expect(find.textContaining('500 to 10,000'), findsWidgets);
    expect(profiles.goals, isEmpty);
    expect(find.byType(TargetHelperScreen), findsOneWidget, reason: 'a refused save keeps the page and its numbers');
  });

  testWidgets('with the coach turned off the same explanation is plain text', (tester) async {
    await _open(tester, coach: false, metrics: [_weighIn('2026-11-10', 80)]);
    await _tap(tester, 'tgt-goal-maintain');
    await _tap(tester, 'tgt-continue');
    await _about(tester);
    await _tap(tester, 'tgt-continue');
    expect(find.byKey(const Key('tgt-coach')), findsNothing);
    expect(_text(tester, 'tgt-plain'), startsWith('This uses your weight, usual activity and goal'));
    expect(_field(tester, 'tgt-calories'), '3130');
  });

  for (final language in ['en', 'fr-CA', 'ar']) {
    testWidgets('$language at 200 % text: every step lays out without overflow and the result is the same', (tester) async {
      await _open(tester, language: language, textScale: 2, metrics: [_weighIn('2026-11-10', 80)]);
      await _tap(tester, 'tgt-goal-recomp');
      await _tap(tester, 'tgt-continue');
      expect(tester.takeException(), isNull);
      await _type(tester, 'tgt-age', '30');
      await _type(tester, 'tgt-height-cm', language == 'fr-CA' ? '180,0' : '180');
      await _tap(tester, 'tgt-sex-male');
      await _tap(tester, 'tgt-activity-active');
      await _tap(tester, 'tgt-continue');
      expect(tester.takeException(), isNull);
      expect((_field(tester, 'tgt-calories'), _field(tester, 'tgt-protein')), ('3130', '160'));
      await _tap(tester, 'tgt-macros');
      expect(tester.takeException(), isNull);
      if (language == 'ar') expect(Directionality.of(tester.element(find.byKey(const Key('tgt-why')))), TextDirection.rtl);
    });
  }
}
