import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../coach/coach_bubble.dart';
import 'food_repository.dart' show mealLabel;
import 'log_food_screen.dart';
import 'meal_habits.dart';
import 'saved_meals.dart';
import 'saved_meals_screens.dart' show MealReviewScreen;

/// Meal suggestions on the phone (docs/MEAL_HABITS_REMINDERS.md › Habits): the account's choice, the meals set aside
/// for a day, and the usual meal for a meal of today. Off until the person turns them on; turning them off removes
/// nothing from the journal or the saved meals.

/// `suggest`: true / false once chosen, absent before. `skipped`: `day|meal` set aside with Not today.
final habitPrefsProvider = StreamProvider<Json>((ref) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) return Stream.value(const {});
  return ref.watch(syncProvider).watch(owner, Kinds.habit).map((rows) => rows.where((r) => r.id == 'prefs').map((r) => jsonDecode(r.body) as Json).firstOrNull ?? const {});
});

/// Whether meal suggestions are on for this account on this phone (null: not chosen yet).
final habitSuggestProvider = Provider<bool?>((ref) => ref.watch(habitPrefsProvider).value?['suggest'] as bool?);

final logTimesProvider = StreamProvider<List<LogTime>>((ref) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) return Stream.value(const []);
  return ref.watch(syncProvider).watch(owner, Kinds.logTime).map((rows) => [
        for (final r in rows)
          if (jsonDecode(r.body) case {'day': final String day, 'meal': final String meal, 'minute': final int minute}) (day: day, meal: meal, minute: minute),
      ]);
});

Future<void> _putPrefs(WidgetRef ref, Json Function(Json) change) async {
  final owner = ref.read(ownerProvider);
  if (owner == null) return;
  final now = ref.read(habitPrefsProvider).value ?? const {};
  await ref.read(syncProvider).putLocal(owner, LocalWrite(Kinds.habit, 'prefs', change({...now})));
}

/// The person's explicit choice. Off keeps every journal entry and saved meal; it only stops suggestions.
Future<void> setMealSuggestions(WidgetRef ref, bool on) => _putPrefs(ref, (j) => j..['suggest'] = on);

/// Not today: no suggestion for [meal] on [day]. Only the last few days are kept.
Future<void> skipMealToday(WidgetRef ref, String day, String meal) => _putPrefs(ref, (j) {
      final kept = [for (final s in (j['skipped'] as List? ?? const []).cast<String>()) if (s.compareTo(addDays(day, -3)) >= 0) s];
      return j..['skipped'] = [...kept, '$day|$meal'];
    });

/// Nutrition heads-ups on Eat (docs/EAT_COMPANION.md): on unless the person turned them off. Separate from reminders.
final headsUpsOnProvider = Provider<bool>((ref) => ref.watch(habitPrefsProvider).value?['headsUps'] as bool? ?? true);

/// Heads-ups already said (`day|kind`), so each is said at most once a day.
final headsUpsSeenProvider = Provider<Set<String>>((ref) => {...(ref.watch(habitPrefsProvider).value?['seen'] as List? ?? const []).cast<String>()});

Future<void> setHeadsUps(WidgetRef ref, bool on) => _putPrefs(ref, (j) => j..['headsUps'] = on);

/// [key] (`day|kind`) has been said. Only the last few days are kept.
Future<void> markHeadsUpSeen(WidgetRef ref, String key) => _putPrefs(ref, (j) {
      final kept = [for (final s in (j['seen'] as List? ?? const []).cast<String>()) if (s.compareTo(addDays(key.split('|').first, -3)) >= 0 && s != key) s];
      return j..['seen'] = [...kept, key];
    });

/// The usual [meal] to suggest today, or null: suggestions off or not chosen, set aside today, that meal already
/// logged today, or no habit in the records.
final usualMealProvider = Provider.family<UsualMeal?, String>((ref, meal) {
  if (ref.watch(habitSuggestProvider) != true) return null;
  final today = ref.watch(todayKeyProvider);
  final skipped = (ref.watch(habitPrefsProvider).value?['skipped'] as List? ?? const []).contains('$today|$meal');
  if (skipped) return null;
  final journal = ref.watch(foodJournalProvider).value;
  if (journal == null) return null;
  final entries = [for (final r in journal) if (!r.value.isDeleted) r.value];
  if (entries.any((e) => e.dayKey == today && e.meal == meal)) return null;
  return usualMeal(entries, today: today, meal: meal, saved: [for (final r in ref.watch(savedMealsProvider).value ?? const <Stored<SavedMeal>>[]) r.value]);
});

/// Whether the journal has enough recent days for suggestions to be worth offering (used only to time the
/// introduction; nothing is suggested before the person turns suggestions on).
final habitIntroDueProvider = Provider<bool>((ref) {
  if (ref.watch(habitSuggestProvider) != null) return false;
  final today = ref.watch(todayKeyProvider), from = addDays(today, -HabitRules.windowDays);
  final days = {
    for (final r in ref.watch(foodJournalProvider).value ?? const <Stored<FoodEntry>>[])
      if (!r.value.isDeleted && r.value.dayKey.compareTo(from) >= 0 && r.value.dayKey.compareTo(today) < 0) r.value.dayKey,
  };
  return days.length >= HabitRules.minDays;
});

/// The time this account usually logs [meal], from this phone's records, when they support one.
final usualLogTimeProvider = Provider.family<String?, String>((ref, meal) {
  final today = ref.watch(todayKeyProvider);
  final logged = {for (final r in ref.watch(foodJournalProvider).value ?? const <Stored<FoodEntry>>[]) if (!r.value.isDeleted) '${r.value.dayKey}|${r.value.meal}'};
  return usualLogTime(ref.watch(logTimesProvider).value ?? const [], meal: meal, today: today, logged: logged);
});

/// Review usual meal: the saved meal or the most recent day's foods and amounts, in the ordinary review. Only its Log
/// records anything.
Future<void> reviewUsualMeal(BuildContext context, UsualMeal u, String day) {
  final l = context.l10n;
  return push(context, MealReviewScreen(body: u.body(l.habitUsualName(mealLabel(l, u.meal))), saved: u.saved, dayKey: day, meal: u.meal));
}

/// Choose something else: the usual Add food, on this meal.
Future<void> chooseOtherFood(BuildContext context, String day, String meal) => push(context, LogFoodScreen(dayKey: day, meal: meal));

/// "Your usual breakfast?", or with the saved meal it is ("Your usual lunch, My chicken meal?").
String _question(AppLocalizations l, UsualMeal u) {
  final meal = mealLabel(l, u.meal).toLowerCase();
  return u.saved == null ? l.habitSay(meal) : l.habitSaySaved(meal, u.saved!.body.name);
}

/// What the coach says about a usual meal, with its three choices.
CoachSay usualMealSay(BuildContext context, WidgetRef ref, UsualMeal u, String day) {
  final l = context.l10n, meal = mealLabel(l, u.meal);
  return CoachSay(
    '${_question(l, u)} ${l.habitWhy(meal.toLowerCase(), u.days)}',
    primary: (label: l.habitReview, key: const Key('habit-review'), onPressed: () => reviewUsualMeal(context, u, day)),
    guide: (label: l.habitOther, key: const Key('habit-other'), onPressed: () => chooseOtherFood(context, day, u.meal)),
    also: [(label: l.habitNotToday, key: const Key('habit-not-today'), onPressed: () => skipMealToday(ref, day, u.meal))],
  );
}

/// The same suggestion without the coach (Show coach on Train and Eat is off): a compact pale panel on Eat.
class UsualMealPanel extends ConsumerWidget {
  const UsualMealPanel({super.key, required this.usual, required this.day});
  final UsualMeal usual;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n, meal = mealLabel(l, usual.meal);
    return PanelTheme(
      child: Builder(
        builder: (context) => PanelSurface(
          key: const Key('habit-panel'),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_question(l, usual), style: context.sansStyle(16, weight: FontWeight.w600)),
            Text(l.habitWhy(meal.toLowerCase(), usual.days), style: context.caption),
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              TextButton(key: const Key('habit-review'), onPressed: () => reviewUsualMeal(context, usual, day), child: Text(l.habitReview)),
              TextButton(key: const Key('habit-other'), onPressed: () => chooseOtherFood(context, day, usual.meal), child: Text(l.habitOther)),
              TextButton(key: const Key('habit-not-today'), onPressed: () => skipMealToday(ref, day, usual.meal), child: Text(l.habitNotToday)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Eat's briefing without the coach (Show coach on Train and Eat off): its words and What could I eat?, in a compact
/// pale panel, so the action is still there.
class BriefingPanel extends StatelessWidget {
  const BriefingPanel({super.key, required this.text, this.ideas, this.label});
  final String text;

  /// The action's words: What could I eat?, or Find something to eat once every goal is reached.
  final String? label;
  final VoidCallback? ideas;

  @override
  Widget build(BuildContext context) => PanelTheme(
        child: Builder(
          builder: (context) => PanelSurface(
            key: const Key('eat-brief-panel'),
            padding: EdgeInsets.fromLTRB(16, 14, 12, ideas == null ? 14 : 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text, key: const Key('eat-brief-text'), style: context.body),
              if (ideas != null) TextButton(key: const Key('eat-brief-ideas'), onPressed: ideas, child: Text(label ?? context.l10n.ebIdeas)),
            ]),
          ),
        ),
      );
}

/// Me › Meal suggestions: what the feature does, and the one switch.
class MealSuggestionsScreen extends ConsumerWidget {
  const MealSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final on = ref.watch(habitSuggestProvider) ?? false;
    return AppPage(title: l.habitSettingTitle, children: [
      Text(l.habitSettingBody, style: context.body),
      const SizedBox(height: 10),
      Text(l.habitSettingRules(HabitRules.minDays, HabitRules.windowDays), style: context.caption),
      const SizedBox(height: 16),
      GroupCard(children: [
        MergeSemantics(
          child: GroupRow(
            key: const Key('habit-switch'), icon: Icons.auto_awesome_outlined, title: l.habitSettingSwitch, subtitle: on ? l.meOn : l.meOff,
            trailing: Switch(value: on, onChanged: (v) => setMealSuggestions(ref, v)),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Text(l.habitSettingOffNote, style: context.caption),
      const SizedBox(height: 22),
      Semantics(header: true, child: Text(l.ebSettingTitle, style: context.titleStyle(20))),
      const SizedBox(height: 6),
      Text(l.ebSettingBody, style: context.body),
      const SizedBox(height: 12),
      GroupCard(children: [
        MergeSemantics(
          child: GroupRow(
            key: const Key('headsups-switch'), icon: Icons.tips_and_updates_outlined, title: l.ebSettingSwitch,
            subtitle: ref.watch(headsUpsOnProvider) ? l.meOn : l.meOff,
            trailing: Switch(value: ref.watch(headsUpsOnProvider), onChanged: (v) => setHeadsUps(ref, v)),
          ),
        ),
      ]),
    ]);
  }
}
