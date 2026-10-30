// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get coachNameLeon => 'Leon';

  @override
  String get coachNameLeona => 'Leona';

  @override
  String get coachAnimalLion => 'lion';

  @override
  String get coachAnimalLioness => 'lioness';

  @override
  String get coachAskTitle => 'Ask GoHard';

  @override
  String get coachAskAiAssistant => 'AI training assistant';

  @override
  String coachAskAbout(String label) {
    return 'About: $label';
  }

  @override
  String get coachAskIntro =>
      'Ask a question about your plan. Answers are written by AI from your draft and GoHard\'s reviewed guide, so check anything important. Nothing is sent until you press Send.';

  @override
  String get coachAskSuggestWhyIncluded => 'Why was this exercise included?';

  @override
  String get coachAskSuggestDumbbell =>
      'Can I replace it with a dumbbell exercise?';

  @override
  String get coachAskSuggestAlternatives =>
      'What are the benefits and trade-offs of these alternatives?';

  @override
  String get coachAskSuggestSetsReps => 'What does 3 × 8–12 mean?';

  @override
  String get coachAskSuggestShorten => 'How could I shorten this workout?';

  @override
  String get coachAskSuggestWhySplit => 'Why this split for my schedule?';

  @override
  String get coachAskSuggestCompareSplits =>
      'How does Upper/Lower differ from Push/Pull/Legs?';

  @override
  String get coachAskClearTitle => 'Clear this conversation?';

  @override
  String get coachAskClearBody =>
      'Its questions and answers are removed from this phone. Your draft is not changed.';

  @override
  String get coachAskClearAction => 'Clear';

  @override
  String get coachAskClearTooltip => 'Clear conversation';

  @override
  String get coachAskInputHint => 'Ask a question';

  @override
  String get coachAskSend => 'Send';

  @override
  String coachAskYouAsked(String text) {
    return 'You asked: $text';
  }

  @override
  String get coachAskWaiting => 'Waiting for an answer';

  @override
  String get coachAskRetry => 'Retry';

  @override
  String get coachAskEditQuestion => 'Edit question';

  @override
  String get coachAskProblemLimit =>
      'You\'ve asked a lot today. Ask GoHard will answer again later; the built-in Quick guide still works.';

  @override
  String get coachAskProblemBusy =>
      'Ask GoHard is busy right now. Try again in a moment.';

  @override
  String get coachAskProblemUnreached =>
      'Ask GoHard couldn\'t be reached. That can be this phone\'s connection or the server. The built-in Quick guide still works.';

  @override
  String get coachAskProblemInvalid =>
      'That question couldn\'t be sent. Edit it and send it again (up to 600 characters).';

  @override
  String get coachAskProblemInterrupted =>
      'This question didn\'t get an answer before Ask GoHard closed. Retry to ask it again.';

  @override
  String get coachAskProblemUnavailable =>
      'Ask GoHard isn\'t available right now. Your question is kept, and the built-in Quick guide still works.';

  @override
  String get coachAskAiGenerated => 'AI-generated';

  @override
  String get coachAskStale => 'Based on an earlier version of your draft';

  @override
  String get coachAskLess => 'Less';

  @override
  String get coachAskMore => 'More';

  @override
  String get coachAskSourcesHeading => 'Sources from GoHard\'s reviewed guide';

  @override
  String get coachAskSuggestedChange => 'Suggested change';

  @override
  String get coachAskChangeFallback => 'A change to your draft';

  @override
  String get coachAskApplied =>
      'Applied to your draft. It is saved like any other edit; nothing is activated.';

  @override
  String get coachAskUndo => 'Undo';

  @override
  String get coachAskUndone =>
      'Undone: your draft is as it was before this suggestion.';

  @override
  String get coachAskTextOnly =>
      'Open the plan builder to preview and apply suggestions.';

  @override
  String get coachAskPreview => 'Preview change';

  @override
  String get coachAskCantApply =>
      'This suggestion can\'t be applied to your draft.';

  @override
  String get coachAskDraftOnly => 'Draft only';

  @override
  String get coachAskDraftOnlyBody =>
      'Changes the draft in the builder, saved like any edit. Nothing is activated.';

  @override
  String get coachAskDraftChanged => 'Your draft changed since this suggestion';

  @override
  String get coachAskRecheck => 'Check against my current draft';

  @override
  String get coachAskNotApplicableHeading =>
      'Not applicable to your current draft';

  @override
  String get coachAskNothingApplies =>
      'Nothing in this suggestion still applies to your draft.';

  @override
  String get coachAskApply => 'Apply to draft';

  @override
  String get coachAskKeep => 'Keep current';

  @override
  String coachAskChangeAdded(String name, String rx) {
    return 'Added: $name · $rx';
  }

  @override
  String coachAskChangeRemoved(String name, String rx) {
    return 'Removed: $name · $rx';
  }

  @override
  String coachAskChangeArrow(String before, String after) {
    return '$before → $after';
  }

  @override
  String coachAskWeightCleared(String load, String name) {
    return 'Weight target $load is cleared: a replacement starts without one and does not take on $name\'s history.';
  }

  @override
  String coachAskWeightKept(String load) {
    return 'Weight target $load is kept.';
  }

  @override
  String coachSkipWorkoutGone(String op) {
    String _temp0 = intl.Intl.selectLogic(op, {
      'removeExercise': 'Remove an exercise',
      'replaceExercise': 'Replace an exercise',
      'setPrescription': 'Change sets and reps',
      'other': 'Add an exercise',
    });
    return '$_temp0: the workout it names is no longer in your draft.';
  }

  @override
  String coachSkipExerciseGone(String op, String workout) {
    String _temp0 = intl.Intl.selectLogic(op, {
      'removeExercise': 'Remove an exercise',
      'replaceExercise': 'Replace an exercise',
      'setPrescription': 'Change sets and reps',
      'other': 'Add an exercise',
    });
    return '$_temp0: that exercise is no longer in $workout.';
  }

  @override
  String coachSkipReplaceUnavailable(String exercise) {
    return 'Replace $exercise: the suggested exercise isn\'t available to your account.';
  }

  @override
  String coachSkipReplaceSame(String exercise) {
    return 'Replace $exercise: it is already that exercise.';
  }

  @override
  String coachSkipValuesOutside(String exercise) {
    return 'Change $exercise: the suggested values are outside what a plan allows.';
  }

  @override
  String coachSkipAddUnavailable(String workout) {
    return 'Add an exercise to $workout: it isn\'t available to your account.';
  }

  @override
  String coachSkipAddOutside(String exercise, String workout) {
    return 'Add $exercise to $workout: the suggested values are outside what a plan allows.';
  }

  @override
  String coachSkipAddFull(String exercise, String workout) {
    return 'Add $exercise to $workout: the workout already has 30 exercises.';
  }

  @override
  String coachUndoRefused(String exercise) {
    return 'Undo is no longer safe: $exercise was changed after the suggestion was applied. Change it in the builder instead.';
  }

  @override
  String get coachQuickGuide => 'Quick guide';

  @override
  String get coachQuickGuideBuiltIn => 'Quick guide · built in';

  @override
  String get coachQuickGuideReviewed =>
      'Quick guide · built-in reviewed content';

  @override
  String get coachAskOpenQuickGuide => 'Open the Quick guide';

  @override
  String get coachGuideSources => 'Sources';

  @override
  String get coachGuideThisSplit => 'This split';

  @override
  String get coachGuideBenefits => 'Benefits';

  @override
  String get coachGuideLimitations => 'Limitations';

  @override
  String get coachGuideTechniqueCues => 'Technique cues';

  @override
  String get coachGuideAlternatives => 'Alternatives';

  @override
  String get coachGuideCustomNoInfo =>
      'Added by you. GoHard has no reviewed technique information for your own exercises.';

  @override
  String coachGuideMusclesLine(String list) {
    return 'Muscles: $list';
  }

  @override
  String coachGuideEquipmentLine(String equipment) {
    return 'Equipment: $equipment';
  }

  @override
  String get coachGuideRoleMain => 'Role: main lift';

  @override
  String get coachGuideRoleAccessory => 'Role: accessory';

  @override
  String get coachListSeparator => ', ';

  @override
  String get coachCycleArrow => ' → ';

  @override
  String coachWhyTitle(String name) {
    return 'Why $name?';
  }

  @override
  String get coachSheetHowItWorks => 'How it works';

  @override
  String get coachSheetGoodToKnow => 'Good to know';

  @override
  String get coachSheetTradeOffs => 'Trade-offs';

  @override
  String get coachSheetChoosingSplit => 'Choosing a split';

  @override
  String get coachSplitEvidenceNote =>
      'Studies comparing splits with the same weekly volume found similar strength and muscle gains, so pick the structure you can keep doing.';

  @override
  String get coachCompareTitle => 'Compare splits';

  @override
  String coachCompareSuggested(String name) {
    return '$name · Suggested';
  }

  @override
  String get coachSheetYourWeek => 'Your week';

  @override
  String get coachSheetOrganisation => 'Organisation';

  @override
  String get coachSheetDays => 'Days';

  @override
  String get coachInfoCustom =>
      'Added by you. GoHard has no checked technique notes for your own exercises.';

  @override
  String get coachInfoCategoryEquipment => 'Category and equipment';

  @override
  String get coachInfoNoNotes =>
      'There are no built-in notes for this exercise yet.';

  @override
  String get coachInfoMuscles => 'Muscles';

  @override
  String get coachInfoEquipment => 'Equipment';

  @override
  String get coachInfoInRoutine => 'In this routine';

  @override
  String get coachInfoRoleMain =>
      'A main exercise: a compound lift that works several large muscles, usually done early with longer rest.';

  @override
  String coachInfoRoleMainIn(String workout) {
    return 'A main exercise in $workout: a compound lift that works several large muscles, usually done early with longer rest.';
  }

  @override
  String get coachInfoRoleAccessory =>
      'An accessory: extra work for specific muscles, usually after the main lifts.';

  @override
  String coachInfoRoleAccessoryIn(String workout) {
    return 'An accessory in $workout: extra work for specific muscles, usually after the main lifts.';
  }

  @override
  String get coachInfoTechnique => 'Technique';

  @override
  String get coachInfoPrescription => 'Prescription';

  @override
  String get coachInfoAsk => 'Ask about this exercise';

  @override
  String get coachInfoReplace => 'Replace…';

  @override
  String get coachRxNone => 'No target set yet.';

  @override
  String coachRxSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String coachRxSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
    );
    return '$_temp0';
  }

  @override
  String coachRxReps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reps',
    );
    return '$_temp0';
  }

  @override
  String coachRxRepRange(int lo, int hi) {
    return '$lo to $hi reps';
  }

  @override
  String coachRxSetsOf(String sets, String amount) {
    return '$sets of $amount';
  }

  @override
  String coachRxSentence(String what) {
    return '$what.';
  }

  @override
  String coachRxSentenceRest(String what, int rest) {
    String _temp0 = intl.Intl.pluralLogic(
      rest,
      locale: localeName,
      other: '$what, with $rest seconds\' rest between sets.',
    );
    return '$_temp0';
  }

  @override
  String coachGuideDays(String count) {
    String _temp0 = intl.Intl.selectLogic(count, {
      'd0': 'no training days',
      'd1': 'one training day',
      'd2': 'two training days',
      'd3': 'three training days',
      'd4': 'four training days',
      'd5': 'five training days',
      'd6': 'six training days',
      'd7': 'seven training days',
      'other': '$count training days',
    });
    return '$_temp0';
  }

  @override
  String coachGuideEquipment(String equipment) {
    String _temp0 = intl.Intl.selectLogic(equipment, {
      'full_gym': 'gym equipment',
      'dumbbells': 'dumbbells only',
      'bodyweight': 'bodyweight only',
      'other': 'gym equipment',
    });
    return '$_temp0';
  }

  @override
  String coachGuideSuggestedBecause(String days, String equipment) {
    return 'Suggested because you selected $days and $equipment.';
  }

  @override
  String get coachGuideSwapDumbbell => 'Exercises use the dumbbell versions.';

  @override
  String get coachGuideSwapBodyweight =>
      'Exercises use the bodyweight versions.';

  @override
  String coachGuideFitWeekly(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'One workout on each of your $days days.',
    );
    return '$_temp0';
  }

  @override
  String coachGuideFitRotate(int days, int workouts) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Its $workouts workouts rotate across your $days days.',
      one: 'Its $workouts workouts rotate across your 1 day.',
    );
    return '$_temp0';
  }

  @override
  String get coachGuideAnyDay => 'any day';

  @override
  String coachGuideRotation(String cycle, String days) {
    return '$cycle, on $days. The order carries on across weeks.';
  }

  @override
  String get coachAskMeInline => 'Ask me ›';

  @override
  String get coachAskMe => 'Ask me';

  @override
  String coachAskOpenWith(String name) {
    return 'Ask GoHard: open the conversation with $name';
  }

  @override
  String get languageSystem => 'System';

  @override
  String languageSystemResolved(String language) {
    return 'Phone language: $language';
  }

  @override
  String get languageTitle => 'Language';

  @override
  String get languageFootnote =>
      'Kept on this phone only. GoHard\'s own text changes; your notes, food names and exercise names you typed stay as written.';

  @override
  String get navToday => 'Today';

  @override
  String get navTrain => 'Train';

  @override
  String get navEat => 'Eat';

  @override
  String get navMe => 'Me';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get busyWorking => 'Working';

  @override
  String percentValue(int percent) {
    return '$percent percent';
  }

  @override
  String get motionDevice => 'Device';

  @override
  String get motionReduced => 'Reduced';

  @override
  String get hapticsDevice => 'Device';

  @override
  String get hapticsOff => 'Off';

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get valueUnknown => '—';

  @override
  String get unitKg => 'kg';

  @override
  String get unitLb => 'lb';

  @override
  String get unitKm => 'km';

  @override
  String get unitMi => 'mi';

  @override
  String get unitKmPerHour => 'km/h';

  @override
  String get unitMph => 'mph';

  @override
  String get unitMetre => 'm';

  @override
  String get unitFoot => 'ft';

  @override
  String paceValue(String pace, String unit) {
    return '$pace /$unit';
  }

  @override
  String get actionSave => 'Save';

  @override
  String get actionDone => 'Done';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionClose => 'Close';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionOk => 'OK';

  @override
  String get errorGeneric =>
      'Something went wrong. Nothing was lost; try again.';

  @override
  String get brandName => 'GoHard';

  @override
  String get foodCategoryProteins => 'Proteins';

  @override
  String get foodCategoryCarbohydrates => 'Carbohydrates';

  @override
  String get foodCategoryCarbsShort => 'Carbs';

  @override
  String get foodCategoryVegetables => 'Vegetables';

  @override
  String get foodCategoryFruits => 'Fruits';

  @override
  String get foodCategoryDairy => 'Dairy';

  @override
  String get foodCategoryFatsOils => 'Fats & Oils';

  @override
  String get foodCategorySnacks => 'Snacks';

  @override
  String get foodCategoryBeverages => 'Beverages';

  @override
  String get foodCategoryAll => 'All';

  @override
  String get foodTagFavourite => 'Favourite';

  @override
  String get foodTagMine => 'My food';

  @override
  String get foodTagRecent => 'Recent';

  @override
  String get foodAsYouLoggedIt => 'As you logged it';

  @override
  String foodBasisPer(String basis) {
    return 'per $basis';
  }

  @override
  String get foodServingFallback => 'serving';

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealSnack => 'Snack';

  @override
  String get eatUnitKcal => 'kcal';

  @override
  String get eatUnitGram => 'g';

  @override
  String eatKcalValue(String value) {
    return '$value kcal';
  }

  @override
  String eatGramsValue(String value) {
    return '$value g';
  }

  @override
  String eatProteinGramsValue(String value) {
    return '$value g protein';
  }

  @override
  String eatWaterValue(String amount) {
    return '$amount water';
  }

  @override
  String get eatTodayCaption => 'Today';

  @override
  String get eatCarbs => 'Carbs';

  @override
  String get eatFat => 'Fat';

  @override
  String get eatCalories => 'Calories';

  @override
  String get eatProtein => 'Protein';

  @override
  String get eatGoalCaloriesWhole =>
      'A calorie goal is a whole number, or left blank for no goal.';

  @override
  String get eatGoalProteinWhole =>
      'A protein goal is a whole number, or left blank for no goal.';

  @override
  String get eatGoalWaterInvalid =>
      'A water goal is an amount above zero, or left blank for no goal.';

  @override
  String get eatGoalsSaveFailed =>
      'Your goals could not be saved on this phone. What you typed is still here.';

  @override
  String get eatGoalCaloriesLabel => 'Daily calories';

  @override
  String get eatGoalProteinLabel => 'Daily protein';

  @override
  String get eatGoalWaterLabel => 'Daily water';

  @override
  String get eatGoalNone => 'No goal';

  @override
  String get eatGoalCaloriesHelper =>
      '500 to 10,000. Leave blank for no calorie goal.';

  @override
  String get eatGoalProteinHelper =>
      '10 to 500. Leave blank for no protein goal.';

  @override
  String get eatGoalWaterHelperMl =>
      '100 to 10,000. Leave blank for no water goal.';

  @override
  String get eatGoalWaterHelperFlOz =>
      '3.4 to 338 (US fluid ounces). Leave blank for no water goal.';

  @override
  String get eatGoalsSave => 'Save goals';

  @override
  String get eatGoalsNoSuggestion =>
      'GoHard does not suggest a calorie or protein goal. If you are unsure what suits you, a dietitian or doctor can help.';

  @override
  String get eatGoalsSheetTitle => 'Daily goals';

  @override
  String get eatGoalsSheetIntro =>
      'These repeat every day until you change them. Leave any of them blank for no goal.';

  @override
  String get eatEditGoals => 'Edit goals';

  @override
  String get eatEditGoalsSaid => 'Edit daily goals';

  @override
  String get eatSetGoals => 'Set daily goals';

  @override
  String get eatCustomizeTracking => 'Customize tracking';

  @override
  String get eatTrackingIntro =>
      'Calories and protein are always shown. Hiding something changes only what you see: nothing you logged or set is removed.';

  @override
  String get eatTrackWaterSubtitle =>
      'A water line on Today and Eat, with an optional goal';

  @override
  String get eatTrackWaterUnsupported =>
      'Water tracking needs a newer version of your account\'s server. Nothing else changes.';

  @override
  String get eatTrackCarbsSubtitle => 'The carbohydrate total in Eat';

  @override
  String get eatTrackFatSubtitle => 'The fat total in Eat';

  @override
  String get eatTrackSynced =>
      'These choices follow your account to your other phones.';

  @override
  String get waterUnitMl => 'mL';

  @override
  String get waterUnitFlOz => 'fl oz';

  @override
  String get waterUnitMlName => 'Millilitres';

  @override
  String get waterUnitFlOzName => 'US fluid ounces';

  @override
  String get waterTitle => 'Water';

  @override
  String get waterNoneLogged => 'No water logged';

  @override
  String get waterSaidLoading => 'Water, loading';

  @override
  String get waterSaidNone => 'Water, no water logged';

  @override
  String waterSaid(String amount) {
    return 'Water $amount';
  }

  @override
  String waterSaidWithGoal(String amount, String goal, int percent) {
    return 'Water $amount of $goal, $percent percent';
  }

  @override
  String waterAddSaidMl(String amount) {
    return 'Add $amount millilitres of water';
  }

  @override
  String waterAddSaidFlOz(String amount) {
    return 'Add $amount fluid ounces of water';
  }

  @override
  String waterUndo(String amount) {
    return 'Undo $amount';
  }

  @override
  String waterUndoSaid(String amount) {
    return 'Undo adding $amount of water';
  }

  @override
  String get waterOtherAmount => 'Other amount';

  @override
  String get waterRowHint => 'Opens water details for this day';

  @override
  String get waterSaveFailed =>
      'That could not be saved on this phone. Nothing was added.';

  @override
  String waterAddedAnnounce(String amount) {
    return 'Added $amount of water. Undo available.';
  }

  @override
  String waterAddedOnDayAnnounce(String amount, String date) {
    return 'Added $amount of water on $date. Undo available.';
  }

  @override
  String get waterAddTitle => 'Add water';

  @override
  String waterForDay(String date) {
    return 'For $date';
  }

  @override
  String get waterAmountLabel => 'Amount';

  @override
  String get waterProblemNotAboveZero => 'Enter an amount above zero.';

  @override
  String get waterProblemOverMax =>
      'One entry can be at most 5 L. Log a larger amount in parts.';

  @override
  String get waterGoalLabel => 'Water goal';

  @override
  String get waterAdd => 'Add';

  @override
  String get waterAnotherAmount => 'Another amount';

  @override
  String get waterNothingThisDay => 'Nothing logged on this day';

  @override
  String get waterLoggedThisDay => 'Logged on this day';

  @override
  String get waterEntryPending => 'Saved on this phone · tap to correct';

  @override
  String get waterEntryTap => 'Tap to correct';

  @override
  String waterRemoveTooltip(String amount) {
    return 'Remove $amount';
  }

  @override
  String get waterOnlyLoggedNote =>
      'Only water you log here is counted, not drinks or food.';

  @override
  String get waterCorrectTitle => 'Correct this amount';

  @override
  String get waterSuggestionAboutTitle => 'About the suggested water goal';

  @override
  String waterSuggestionAboutBody(String amount) {
    return '$amount a day is a general starting point, not a recommendation worked out for you. How much someone needs varies with body size, activity, heat and health; if a condition or medicine affects how much you should drink, follow your doctor\'s advice.\n\nOther drinks and food also contribute to hydration. GoHard counts only the water you log yourself, so your total here is not everything you drank.';
  }

  @override
  String waterSuggestedGoal(String amount) {
    return 'Suggested starting goal: $amount daily.';
  }

  @override
  String get waterSuggestedGoalNote =>
      'A general starting point; your needs may differ. Only water you log is counted.';

  @override
  String waterSuggestionUse(String amount) {
    return 'Use $amount';
  }

  @override
  String get eatUnitGramProtein => 'g protein';

  @override
  String eatGoalProgressCalories(String eaten, String goal) {
    return '$eaten of $goal kcal';
  }

  @override
  String eatGoalProgressProtein(String eaten, String goal) {
    return 'Protein $eaten of $goal g';
  }

  @override
  String eatGoalNoCalorieValue(String goal) {
    return 'No calorie value entered yet · goal $goal kcal';
  }

  @override
  String eatGoalNoProteinValue(String goal) {
    return 'No protein value entered yet · goal $goal g';
  }

  @override
  String eatGoalKnownSoFar(String progress) {
    return '$progress · known so far';
  }

  @override
  String eatGoalOverKcal(String progress, String diff) {
    return '$progress · $diff kcal over';
  }

  @override
  String eatGoalLeftKcal(String progress, String diff) {
    return '$progress · $diff kcal left';
  }

  @override
  String eatGoalOverGrams(String progress, String diff) {
    return '$progress · $diff g over';
  }

  @override
  String eatGoalLeftGrams(String progress, String diff) {
    return '$progress · $diff g left';
  }

  @override
  String get eatNoFoodLoggedYet => 'No food logged yet';

  @override
  String get eatTotals => 'Totals';

  @override
  String get eatKnownTotals => 'Known totals';

  @override
  String get eatNoNutritionForFood => 'No nutrition entered for this food yet';

  @override
  String get eatNutritionOverline => 'Nutrition';

  @override
  String get eatNothingRecorded =>
      'Nothing is recorded for this day. That is not the same as nothing eaten.';

  @override
  String eatYourDailyGoal(String goals) {
    return 'Your daily goal: $goals';
  }

  @override
  String eatNutrientSaid(String nutrient, String value) {
    return '$nutrient $value';
  }

  @override
  String eatNutrientUnknownSaid(String nutrient) {
    return '$nutrient unknown';
  }

  @override
  String get eatPartialNote =>
      'Some foods have no value for a nutrient, so these are sums of what you entered, not full totals.';

  @override
  String get eatSyncPending => 'Saved on this phone · sync pending';

  @override
  String get eatKnown => 'known';

  @override
  String get eatKnownSoFar => 'known so far';

  @override
  String eatSaidKcal(String nutrient, String value) {
    return '$nutrient $value kilocalories';
  }

  @override
  String eatSaidGrams(String nutrient, String value) {
    return '$nutrient $value grams';
  }

  @override
  String eatSaidKnownFrom(int known, int total) {
    return 'known from $known of $total foods';
  }

  @override
  String eatSaidGoalKcal(String goal) {
    return 'goal $goal kilocalories';
  }

  @override
  String eatSaidGoalGrams(String goal) {
    return 'goal $goal grams';
  }

  @override
  String get eatListSeparator => ', ';

  @override
  String get eatCaloriesGoalBar => 'Calories goal';

  @override
  String get eatProteinGoalBar => 'Protein goal';

  @override
  String get eatOpensJournalHint => 'Opens the food journal';

  @override
  String get eatSomeValuesMissing => 'Some nutrition values are missing';

  @override
  String get eatNoValuesYet => 'No nutrition values entered yet';

  @override
  String get foodProblemNoName => 'Enter what you ate.';

  @override
  String get foodProblemNoAmount => 'Enter how much, in your own words.';

  @override
  String get foodProblemTooLong => 'That text is too long.';

  @override
  String get foodProblemNoMeal => 'Choose a meal.';

  @override
  String get foodProblemNoQuantity =>
      'Enter how much you had, as a number above zero.';

  @override
  String get foodProblemBadValues => 'Nutrition values must be zero or more.';

  @override
  String foodProblemBadValue(String nutrient) {
    return '$nutrient must be a number of zero or more, or left blank.';
  }

  @override
  String get foodProblemBadSavedName =>
      'Give the food a name of up to 120 characters.';

  @override
  String get foodSaveFailedLocal =>
      'This could not be saved on your phone. Your entry is still here. Try again.';

  @override
  String get foodSavedToMine => 'Saved to My foods. Nothing was logged.';

  @override
  String foodRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String foodRemoveBody(String name, String amount, String meal, String date) {
    return 'This removes only \"$name\" ($amount) from $meal on $date. Your other food stays.';
  }

  @override
  String get foodRemoveAction => 'Remove this food';

  @override
  String get foodDetailsTitle => 'Food details';

  @override
  String get foodEditTitle => 'Edit food';

  @override
  String get foodNewTitle => 'New food';

  @override
  String get foodYourValue => 'Your value';

  @override
  String get foodWhatDidYouEat => 'What did you eat?';

  @override
  String get foodNameInJournal => 'Name in your journal';

  @override
  String get foodMealLabel => 'Meal';

  @override
  String foodForDateTapToChange(String date) {
    return 'For $date. Tap to change the date.';
  }

  @override
  String get foodHelpPortions => 'Help with amounts and portions';

  @override
  String get foodFavouriteRemove => 'Remove from favourites';

  @override
  String get foodFavouriteAdd => 'Add to favourites';

  @override
  String get foodSaveChanges => 'Save changes';

  @override
  String get foodLogButton => 'Log food';

  @override
  String get foodCancelKeep => 'Cancel and keep the recorded version';

  @override
  String get foodAmountLabel => 'Amount';

  @override
  String get foodPortionLabel => 'Portion';

  @override
  String get foodAddPortion => 'Add your own portion';

  @override
  String get foodPortionCoach =>
      'You can count portions here. The weight is shown when a reliable conversion is available.';

  @override
  String get foodHowMuch => 'How much?';

  @override
  String get foodHowMuchHelper =>
      'In your own words, for example \"200 g\" or \"2 slices\"';

  @override
  String get foodNutritionHeading => 'Nutrition';

  @override
  String foodNutritionFor(String amount) {
    return 'Nutrition for $amount';
  }

  @override
  String get foodNutritionOptional =>
      'Optional. Tap a value to enter it; a blank stays unknown and is never counted as zero.';

  @override
  String get foodNutritionFromSource =>
      'From the source, for this amount. Tap a value to correct it; a blank stays unknown and is never counted as zero.';

  @override
  String foodSourceMissing(int count, String nutrients) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This source gives no value for $nutrients. They stay unknown unless you enter them.',
      one:
          'This source gives no value for $nutrients. It stays unknown unless you enter it.',
    );
    return '$_temp0';
  }

  @override
  String get foodUseSourceValues => 'Use the source\'s values again';

  @override
  String get foodSaveToMine => 'Save to My foods without logging';

  @override
  String get foodShowsDetailsHint => 'Shows the food details';

  @override
  String foodSource(String credit) {
    return 'Source: $credit';
  }

  @override
  String get foodYourOwn => 'Your own food';

  @override
  String foodBarcode(String code) {
    return 'Barcode $code';
  }

  @override
  String get foodYoureLogging => 'You\'re logging';

  @override
  String get foodEnergy => 'Energy';

  @override
  String get foodUnknownSaid => 'unknown';

  @override
  String foodKcalSaid(String value) {
    return '$value kilocalories';
  }

  @override
  String foodGramsSaid(String value) {
    return '$value grams';
  }

  @override
  String get foodPortionNameInvalid =>
      'Name one portion in a word or two, such as \"slice\" or \"small bowl\".';

  @override
  String foodPortionExists(String name) {
    return 'This food already has a portion called \"$name\".';
  }

  @override
  String foodPortionAmountInvalid(String name) {
    return 'Enter how much one $name is, as a number above zero.';
  }

  @override
  String foodPortionFor(String food) {
    return 'For $food only. Its nutrition values do not change, and nothing is logged.';
  }

  @override
  String get foodPortionCalled => 'One portion is called';

  @override
  String get foodPortionHint => 'slice';

  @override
  String get foodPortionHowMuch => 'How much is one?';

  @override
  String get foodAddPortionButton => 'Add portion';

  @override
  String foodNutritionBasis(String basis) {
    return 'Nutrition $basis';
  }

  @override
  String foodBarcodeNotFound(String code) {
    return 'No product was found for barcode $code. You can search for it by name or create your own food.';
  }

  @override
  String foodBarcodeOffline(String code) {
    return 'Barcode $code could not be looked up just now, and it has not been looked up on this phone before. That can be this phone\'s connection or the server. You can create your own food.';
  }

  @override
  String foodBarcodeTimeout(String code) {
    return 'The product database took too long to answer for barcode $code. Try again, or create your own food.';
  }

  @override
  String get foodBarcodeRateLimited =>
      'The product database has had too many requests for now. Try again in a few minutes, or create your own food.';

  @override
  String get foodBarcodeInvalid => 'That is not a product barcode.';

  @override
  String get foodBarcodeUnavailable =>
      'The product database is not answering right now. Try again, or create your own food.';

  @override
  String foodBarcodeLookingUp(String code) {
    return 'Looking up barcode $code…';
  }

  @override
  String get foodSearchStillLocal =>
      'The foods above are from this phone and still work.';

  @override
  String get foodSearchStillScan =>
      'You can still scan a barcode or create your own food.';

  @override
  String get foodSearchOffline =>
      'The wider food database could not be reached just now. That can be this phone\'s connection or the server.';

  @override
  String get foodSearchTimeout =>
      'The wider food database took too long to answer.';

  @override
  String get foodSearchRateLimited =>
      'The wider food database has had too many requests for now. Try again in a few minutes.';

  @override
  String get foodSearchNotConfigured =>
      'Wider food search is not set up on this server. Common foods, your own foods and barcodes still work.';

  @override
  String get foodSearchInvalid =>
      'That search could not be used. Try other words.';

  @override
  String get foodSearchUnavailable =>
      'The wider food database is not answering right now. Try again in a moment.';

  @override
  String get foodSearchGuide =>
      'Type a food, such as \"egg\" or \"rice\", or pick a category. Everyday foods and your own are found without a connection.';

  @override
  String get foodGroupYours => 'Your foods';

  @override
  String get foodGroupCommon => 'Common foods';

  @override
  String get foodGroupMore => 'More foods';

  @override
  String foodCategoryEmpty(String category) {
    return 'No common foods are filed under $category.';
  }

  @override
  String foodCategoryNoMatch(String category, String query) {
    return 'No common food in $category matches \"$query\".';
  }

  @override
  String get foodCategoryNote =>
      'Only common foods have a category. Choose All to include your own foods and the wider database.';

  @override
  String get foodSearchBusy => 'Searching more foods…';

  @override
  String foodSearchLocalEmpty(String query) {
    return 'Nothing on this phone matches \"$query\".';
  }

  @override
  String get foodSearchMore => 'Search more foods';

  @override
  String foodSearchMoreSubtitle(String query) {
    return 'Look up \"$query\" in USDA FoodData Central';
  }

  @override
  String foodSearchNoOthers(String query) {
    return 'The wider database has no other foods for \"$query\".';
  }

  @override
  String foodSearchNoneFound(String query) {
    return 'No foods were found for \"$query\". Try other words, scan the barcode, or create your own food.';
  }

  @override
  String foodSearchNoneNonEnglish(String query) {
    return 'The wider database searches in English and found nothing for \"$query\". Try the English name, scan the barcode, or enter it yourself.';
  }

  @override
  String get foodSearchCredit =>
      'From USDA FoodData Central, in English, mostly foods sold or eaten in the United States. Values are as published and may differ from your packet.';

  @override
  String get foodRecentEmptyTitle => 'Nothing logged yet';

  @override
  String get foodRecentEmptyBody =>
      'Foods you log are listed here, ready to log again.';

  @override
  String get foodFavouritesEmptyTitle => 'No favourites yet';

  @override
  String get foodFavouritesEmptyBody =>
      'Mark a food with the star on its amount page to keep it here.';

  @override
  String get foodMineEmptyTitle => 'No foods of your own yet';

  @override
  String get foodMineEmptyBody =>
      'Create your own food below, or use \"Save to My foods\" on any food\'s amount page.';

  @override
  String foodListNoMatch(String query) {
    return 'Nothing in this list matches \"$query\".';
  }

  @override
  String get foodAddTitle => 'Add food';

  @override
  String get foodHelpSearch => 'Help with finding a food';

  @override
  String get foodSearchHint => 'Search foods';

  @override
  String get foodSearchClear => 'Clear search';

  @override
  String get foodScanBarcode => 'Scan barcode';

  @override
  String get foodScopeSearch => 'Search';

  @override
  String get foodScopeRecent => 'Recent';

  @override
  String get foodScopeFavourites => 'Favourites';

  @override
  String get foodScopeMine => 'My foods';

  @override
  String get foodSearchCoach =>
      'Search for a food, scan a barcode or enter your own. Recent, Favourites and My foods are one tap away.';

  @override
  String get foodManualTitle => 'Enter it yourself';

  @override
  String get foodManualSubtitle => 'Can\'t find it? Create your own food';

  @override
  String get foodFooter => 'Choose a food to check the amount before logging.';

  @override
  String get foodCredits =>
      'Common foods and wider search: USDA FoodData Central. Barcodes: Open Food Facts (Open Database License).';

  @override
  String get foodChangeMeal => 'Change meal';

  @override
  String get foodRowProteinUnknown => '— protein';

  @override
  String get foodChooseHint => 'Choose this food';

  @override
  String get barcodeTypedInvalid =>
      'A barcode is 6 to 14 digits, as printed under the bars.';

  @override
  String get barcodeTitle => 'Scan a barcode';

  @override
  String get barcodeHold => 'Hold the barcode on the packet inside the frame.';

  @override
  String get barcodeLookUp => 'Look up this barcode';

  @override
  String get barcodeCameraRefused =>
      'GoHard is not allowed to use the camera, so it cannot scan. You can allow it in the phone\'s settings, or type the barcode below.';

  @override
  String get barcodeCameraUnavailable =>
      'The camera cannot be used on this phone right now. You can type the barcode below.';

  @override
  String get barcodeOrType => 'Or type the barcode';

  @override
  String get barcodeDigitsLabel => 'Barcode digits';

  @override
  String get barcodeCameraStarting => 'Starting the camera';

  @override
  String get barcodeTorchOff => 'Turn the light off';

  @override
  String get barcodeTorchOn => 'Turn the light on';

  @override
  String get eatHelpTitle => 'Your food journal';

  @override
  String get eatHelpBody =>
      'Add food under a meal: search, scan a barcode or enter your own. The totals add up only what you logged. Your daily goals are set from the summary here, on Today or in Me. Foods you eat again are saved in Add food: Favourites are foods you starred on their amount page; My foods are foods you wrote or corrected yourself. Choosing one only opens its amount: nothing is logged until you confirm it.';

  @override
  String get eatOpenFavourites => 'Open Favourites';

  @override
  String get eatOpenMine => 'Open My foods';

  @override
  String get eatHintHistory =>
      'Your past meals and water, by day, week and month, are in History & trends.';

  @override
  String get eatHintSavedNew =>
      'Eat the same foods often? Tap the star on a food\'s amount page and it waits under Favourites in Add food.';

  @override
  String get eatHintFavourites =>
      'Your favourite foods are one tap away. Pick one, check the amount, then log it.';

  @override
  String get eatHintMine =>
      'Foods you saved are in My foods. Pick one, check the amount, then log it.';

  @override
  String eatMacroProtein(String value) {
    return 'P $value g';
  }

  @override
  String eatMacroCarbs(String value) {
    return 'C $value g';
  }

  @override
  String eatMacroFat(String value) {
    return 'F $value g';
  }

  @override
  String get eatNoNutritionEntered => 'No nutrition entered';

  @override
  String get eatNeedsReview => 'needs review';

  @override
  String get eatSyncPendingShort => 'sync pending';

  @override
  String get eatCaloriesUnknown => 'Calories unknown';

  @override
  String eatKcalKnown(String value) {
    return '$value kcal known';
  }

  @override
  String get eatHelpLabel => 'Help with your food journal';

  @override
  String eatHelpFrom(String coach) {
    return 'Help with your food journal, from $coach';
  }

  @override
  String get eatPreviousDay => 'Previous day';

  @override
  String get eatNextDay => 'Next day';

  @override
  String get eatHistoryTrends => 'History & trends';

  @override
  String get eatBackToToday => 'Back to today';

  @override
  String get eatJournalReadError =>
      'Your food journal could not be read from this phone. Pull down to try again.';

  @override
  String get eatJournalLoading => 'Loading your journal…';

  @override
  String get eatTodaysMeals => 'Today\'s meals';

  @override
  String get eatMeals => 'Meals';

  @override
  String eatAddFoodToMeal(String meal) {
    String _temp0 = intl.Intl.selectLogic(meal, {
      'Breakfast': 'Add food to breakfast',
      'Lunch': 'Add food to lunch',
      'Dinner': 'Add food to dinner',
      'Snack': 'Add food to snack',
      'other': 'Add food',
    });
    return '$_temp0';
  }

  @override
  String get eatAddFood => 'Add food';

  @override
  String get eatOnlyLoggedNote => 'Only food you logged as eaten appears here.';

  @override
  String trendsFoodCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foods',
      one: '1 food',
    );
    return '$_temp0';
  }

  @override
  String get trendsFuture => 'Future';

  @override
  String get trendsNoFoodLogged => 'No food logged';

  @override
  String trendsDayUnknown(String metric, String foods) {
    return '$metric not entered · $foods logged';
  }

  @override
  String trendsDayPartial(
    String amount,
    int unknown,
    String foods,
    String noun,
  ) {
    return '$amount known · $unknown of $foods without $noun values';
  }

  @override
  String trendsDayZero(String amount) {
    return '$amount recorded';
  }

  @override
  String get trendsNounCalorie => 'calorie';

  @override
  String get trendsNounProtein => 'protein';

  @override
  String get trendsNounCarb => 'carb';

  @override
  String get trendsNounFat => 'fat';

  @override
  String get trendsNounWater => 'water';

  @override
  String get trendsHelpBody =>
      'Each bar is one day\'s logged total. Tap or slide across the chart to choose a day, then View day opens its meals and water. A dash means nothing was logged that day; a question mark means foods were logged without this value; a star means some foods have no value, so the sum is what is known. Averages use only days with a known value.';

  @override
  String get trendsHelpLabel => 'Help with History & trends';

  @override
  String get trendsCoachSay => 'Tap a day to see what you logged.';

  @override
  String get trendsWeek => 'Week';

  @override
  String get trendsMonth => 'Month';

  @override
  String get trendsChooseDay => 'Choose a day';

  @override
  String get trendsWaterReadError =>
      'Your water could not be read from this phone.';

  @override
  String get trendsFoodReadError =>
      'Your food journal could not be read from this phone.';

  @override
  String get trendsReading => 'Reading your journal on this phone…';

  @override
  String trendsByDay(String metric) {
    return '$metric by day';
  }

  @override
  String get trendsLegendNotLogged => 'Not logged';

  @override
  String get trendsLegendNotEntered => 'Not entered';

  @override
  String get trendsLegendPartial => 'Some values missing';

  @override
  String get trendsLegendZero => 'Recorded zero';

  @override
  String get trendsDaysInPeriod => 'Days in this period';

  @override
  String get trendsCalendar => 'Calendar';

  @override
  String get trendsCalendarSaid => 'Calendar and all days with entries';

  @override
  String get trendsFoodErrorWaterShown =>
      'Food could not be read from this phone; water is shown.';

  @override
  String get trendsWaterErrorFoodShown =>
      'Water could not be read from this phone; food is shown.';

  @override
  String trendsFoodsLogged(String foods) {
    return '$foods logged';
  }

  @override
  String get trendsFootnote =>
      'Totals add up only what was logged. A day with nothing logged, or a food without a value, is never counted as zero. Goals are not shown here: earlier days\' goals were not kept.';

  @override
  String trendsWeekSoFar(String range) {
    return 'This week so far · $range';
  }

  @override
  String trendsMonthToDate(String range) {
    return 'Month to date · $range';
  }

  @override
  String get trendsPreviousWeek => 'Previous week';

  @override
  String get trendsPreviousMonth => 'Previous month';

  @override
  String get trendsNextWeek => 'Next week';

  @override
  String get trendsNextMonth => 'Next month';

  @override
  String trendsPeriodSaid(String period) {
    return 'Choose a day. Showing $period';
  }

  @override
  String trendsPeriodSaidSub(String period, String sub) {
    return 'Choose a day. Showing $period, $sub';
  }

  @override
  String get trendsThisWeek => 'This week';

  @override
  String get trendsThisMonth => 'This month';

  @override
  String trendsKnownLogged(String metric) {
    return 'Known $metric logged';
  }

  @override
  String trendsLogged(String metric) {
    return '$metric logged';
  }

  @override
  String trendsNoValues(String noun) {
    return 'No $noun values';
  }

  @override
  String trendsCoverage(int known, int elapsed, String noun) {
    return '$known of $elapsed days with $noun values';
  }

  @override
  String trendsCoverageSoFar(int known, int elapsed, String noun) {
    return '$known of $elapsed days with $noun values so far';
  }

  @override
  String trendsCoverageWater(int known, int elapsed) {
    return '$known of $elapsed days with water logged';
  }

  @override
  String trendsCoverageWaterSoFar(int known, int elapsed) {
    return '$known of $elapsed days with water logged so far';
  }

  @override
  String trendsDaysWithFood(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days with food logged',
      one: '1 day with food logged',
    );
    return '$_temp0';
  }

  @override
  String trendsDaysWithoutValue(int count, String noun) {
    return '$count without any $noun value';
  }

  @override
  String get trendsAverageKnown => 'Daily average, known values';

  @override
  String get trendsAverage => 'Daily average';

  @override
  String trendsAcross(int count, String noun) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Across the $count days with $noun values',
      one: 'Across the one day with $noun values',
    );
    return '$_temp0';
  }

  @override
  String trendsAcrossWater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Across the $count days with water logged',
      one: 'Across the one day with water logged',
    );
    return '$_temp0';
  }

  @override
  String trendsPartialNote(int count, String noun) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Includes $count days where some foods have no $noun value: only the known part is added.',
      one:
          'Includes 1 day where some foods have no $noun value: only the known part is added.',
    );
    return '$_temp0';
  }

  @override
  String get trendsViewDay => 'View day';

  @override
  String trendsViewDaySaid(String date) {
    return 'View $date';
  }

  @override
  String trendsChartSaid(String metric, String period, int known, int elapsed) {
    return '$metric by day, $period: $known of $elapsed days with a value. Each day is in the list of days below.';
  }

  @override
  String get trendsCaloriesUnknownLower => 'calories unknown';

  @override
  String get trendsCalendarSubtitle => 'Your meals and water, by day';

  @override
  String get trendsCalendarCaption =>
      'Choose a day to see what was logged on it.';

  @override
  String get trendsDaysWithEntries => 'Days with entries';

  @override
  String get trendsNothingYetBody =>
      'Days you log food or water on are listed here.';

  @override
  String get accountErrorInvalidCredentials =>
      'That email and password do not match an account.';

  @override
  String get accountErrorEmailInUse =>
      'An account with that email already exists. Sign in instead.';

  @override
  String get accountErrorWeakPassword =>
      'Use a password of at least 15 characters.';

  @override
  String get accountErrorInvalidEmail => 'Enter a valid email address.';

  @override
  String get accountErrorInvalidDisplayName =>
      'Enter the name you want to see in the app.';

  @override
  String get accountErrorWrongPassword =>
      'That password is not correct. Your account was not deleted.';

  @override
  String get accountErrorTooManyAttempts =>
      'Too many attempts. Wait a minute and try again.';

  @override
  String get accountErrorUnreachable =>
      'The server cannot be reached. Check your connection and try again; nothing you typed was lost.';

  @override
  String get accountErrorUnreachableDelete =>
      'The server cannot be reached, so nothing was deleted. Account deletion needs a connection.';

  @override
  String get accountErrorNameLength => 'Enter a name of 1 to 80 characters.';

  @override
  String get accountErrorCalorieGoal =>
      'A calorie goal is a whole number from 500 to 10,000, or left blank.';

  @override
  String get accountErrorProteinGoal =>
      'A protein goal is a whole number from 10 to 500 grams, or left blank.';

  @override
  String get accountErrorWaterGoal =>
      'A water goal is from 100 mL to 10 L (about 3.4 to 338 fl oz), or left blank.';

  @override
  String get reminderNotificationTitle => 'Workout today';

  @override
  String get reminderChannelName => 'Workout reminders';

  @override
  String get reminderChannelDescription =>
      'A reminder on days with a planned workout';

  @override
  String get permissionAllowed => 'Allowed';

  @override
  String get permissionNotAllowed => 'Not allowed';

  @override
  String get permissionNotAskedOrNotAllowed => 'Not asked yet, or not allowed';

  @override
  String get permissionUnknown => 'Unknown';

  @override
  String get permissionsSubtitle =>
      'Controlled by the phone, not by GoHard\'s own settings.';

  @override
  String get permissionLocation => 'Location';

  @override
  String get permissionLocationExplanation =>
      'Approximate, while the app is open: automatic weather on Today and GPS runs. Asked when you use one of them.';

  @override
  String get permissionCamera => 'Camera';

  @override
  String get permissionCameraExplanation =>
      'Barcode scanning only. Asked the first time you scan; the scanner says so if it is not allowed.';

  @override
  String get permissionNotifications => 'Notifications';

  @override
  String get permissionNotificationsExplanation =>
      'Workout reminders only. Asked when you turn them on in Me.';

  @override
  String get permissionsFootnote =>
      'GoHard asks for each one only when you use the feature that needs it. To allow or stop something you refused or allowed earlier, use the phone\'s Settings. App preferences such as Units, Appearance and Today background are in Me.';

  @override
  String get permissionsOpenSettings => 'Open phone Settings';

  @override
  String get syncRemoved => 'Removed';

  @override
  String syncFoodLine(String name, String amount, String meal, String date) {
    return '$name · $amount · $meal · $date';
  }

  @override
  String syncFoodLineCalories(
    String name,
    String amount,
    String meal,
    String date,
    String calories,
  ) {
    return '$name · $amount · $meal · $date · $calories kcal';
  }

  @override
  String syncWorkoutInProgress(String title, String date) {
    return '$title · $date · in progress';
  }

  @override
  String syncWorkoutFinished(String title, String date, String outcome) {
    return '$title · $date · finished ($outcome)';
  }

  @override
  String get syncNoPrimaryPlan => 'No primary plan';

  @override
  String get syncPrimaryPlanSet => 'A primary plan is set';

  @override
  String syncPlanLine(String title, String lifecycle) {
    return '$title · $lifecycle';
  }

  @override
  String syncProfileLine(String name, String appearance, String unit) {
    return '$name · $appearance · $unit';
  }

  @override
  String syncGoalCalories(String value) {
    return 'goal $value kcal';
  }

  @override
  String syncGoalProtein(String value) {
    return 'goal $value g protein';
  }

  @override
  String syncGoalWater(String value) {
    return 'goal $value mL water';
  }

  @override
  String get syncFoodFallback => 'Food';

  @override
  String get syncFavourite => 'favourite';

  @override
  String syncRunLine(String date) {
    return 'Run · $date';
  }

  @override
  String syncWaterLine(String amount, String date) {
    return 'Water · $amount · $date';
  }

  @override
  String syncWeeklyGoalsLine(String date, String workouts, String runs) {
    return 'Weekly goals from $date: $workouts · $runs';
  }

  @override
  String get syncNoWorkoutTarget => 'no workout target';

  @override
  String syncWorkoutsTarget(int count) {
    return '$count workouts';
  }

  @override
  String get syncNoRunWalkTarget => 'no Run / Walk target';

  @override
  String syncRunWalkTarget(int count) {
    return '$count runs or walks';
  }

  @override
  String get syncNoIncrement => 'No weight increment';

  @override
  String syncIncrement(String load) {
    return 'Weight increment $load';
  }

  @override
  String get syncKindSet => 'Recorded set';

  @override
  String get syncKindFood => 'Food entry';

  @override
  String get syncKindWorkout => 'Workout';

  @override
  String get syncKindContext => 'Primary plan change';

  @override
  String get syncKindPlan => 'Plan change';

  @override
  String get syncKindProfile => 'Profile';

  @override
  String get syncKindRun => 'Run';

  @override
  String get syncKindMetric => 'Body measurement';

  @override
  String get syncKindProposal => 'Suggested change';

  @override
  String get syncKindSavedFood => 'Saved food';

  @override
  String get syncKindWater => 'Water entry';

  @override
  String get syncKindWeeklyGoal => 'Weekly goals';

  @override
  String get syncKindIncrement => 'Weight increment';

  @override
  String get syncReasonRevisionConflict =>
      'It was also changed somewhere else, so the two versions differ.';

  @override
  String get syncReasonDeleted =>
      'It was removed somewhere else after you changed it here.';

  @override
  String get syncReasonOccasionNotEligible =>
      'That planned workout was already started, recorded or skipped somewhere else.';

  @override
  String get syncReasonAlreadyFinished =>
      'This workout was already finished somewhere else.';

  @override
  String get syncReasonSetMismatch =>
      'The sets in your account differ from the sets on this phone.';

  @override
  String get syncReasonPlansChanged =>
      'Your plans changed somewhere else before this reached your account.';

  @override
  String get syncReasonNotFound => 'It no longer exists in your account.';

  @override
  String syncReasonOther(String code) {
    return 'Your account did not accept it ($code).';
  }

  @override
  String get syncReasonUnknownCode => 'unknown reason';

  @override
  String get syncReviewTitle => 'Review saved changes';

  @override
  String get syncReviewIntro =>
      'Everything below is saved on this phone. Each item differs from your account or was not accepted, so it needs your decision.';

  @override
  String get syncReviewEmptyTitle => 'Nothing to review';

  @override
  String get syncReviewEmptyBody =>
      'All your changes are either synced or waiting to sync normally.';

  @override
  String get syncOnThisPhone => 'On this phone';

  @override
  String get syncInYourAccount => 'In your account';

  @override
  String get syncKeepLocal => 'Keep the version on this phone';

  @override
  String get syncKeptLocal =>
      'Kept your version. The account\'s version is retained as the alternative.';

  @override
  String get syncKeepManual => 'Keep it as a manual workout';

  @override
  String get syncKeptManual =>
      'Kept as manual training. Every recorded set is preserved.';

  @override
  String get syncUseServer => 'Use the account\'s version';

  @override
  String get syncUsingServer =>
      'Using the account\'s version. Your version is retained as the alternative.';

  @override
  String get syncRemoveFromPhone => 'Remove it from this phone';

  @override
  String get syncDropChange => 'Drop my change';

  @override
  String get syncRemoveConfirmTitle => 'Remove it from this phone?';

  @override
  String get syncRemoveConfirmBody =>
      'Your account never accepted this, so removing it here removes it completely.';

  @override
  String get syncRemoveConfirmBodyWorkout =>
      'Your account never accepted this, so removing it here removes it completely, including its recorded sets.';

  @override
  String get syncDropConfirmTitle => 'Drop this change?';

  @override
  String get syncDropConfirmBody =>
      'Your account\'s version will be shown again.';

  @override
  String get syncDiscardDone => 'Done.';

  @override
  String get meRemindersNotAllowed =>
      'Notifications are not allowed for GoHard, so reminders stay off. You can allow them in the phone\'s settings.';

  @override
  String get mePrefNotSaved =>
      'That preference could not be saved on this phone.';

  @override
  String get meUnits => 'Units';

  @override
  String get meUnitKilograms => 'Kilograms';

  @override
  String get meUnitPounds => 'Pounds';

  @override
  String get meUnitsLoadNote =>
      'Changes how loads are entered and shown. Your recorded training is stored in kilograms and is never rewritten. Time is shown in minutes and seconds.';

  @override
  String get meUnitBodyKg => 'Body weight in kilograms';

  @override
  String get meUnitBodyLb => 'Body weight in pounds';

  @override
  String get meUnitBodyCm => 'Measurements in centimetres (cm)';

  @override
  String get meUnitBodyIn => 'Measurements in inches (in)';

  @override
  String get meUnitsBodyNote =>
      'For Body progress only: your lifting unit stays as it is. Stored in kilograms and centimetres, so changing this never changes a measurement. Set on this phone for this account.';

  @override
  String get meUnitsTemperature => 'Temperature';

  @override
  String get meUnitFahrenheit => 'Fahrenheit (°F)';

  @override
  String get meUnitCelsius => 'Celsius (°C)';

  @override
  String get meUnitsTemperatureNote =>
      'For the weather on Today. Set on this phone.';

  @override
  String get meUnitsWater => 'Water';

  @override
  String get meUnitMillilitres => 'Millilitres (mL, L)';

  @override
  String get meUnitFluidOunces => 'US fluid ounces (fl oz)';

  @override
  String get meUnitsWaterNote =>
      'For water you log. Stored in millilitres, so changing this never changes an amount. Fluid ounces are a volume, not a weight. Set on this phone.';

  @override
  String get meUnitsRunWalk => 'Run / Walk';

  @override
  String get meUnitKilometres => 'Kilometres (min/km, km/h, m)';

  @override
  String get meUnitMiles => 'Miles (min/mi, mph, ft)';

  @override
  String get meUnitsRunWalkNote =>
      'Distance, pace, speed and elevation. Routes are stored in metres, so changing this never changes a recording. Set on this phone.';

  @override
  String get meSyncNeedsReview => 'Needs review';

  @override
  String meSyncNeedsReviewDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count saved changes need review. Nothing was lost. Tap to review.',
      one: '1 saved change needs review. Nothing was lost. Tap to review.',
    );
    return '$_temp0';
  }

  @override
  String get meSyncNotSynced => 'Not synced';

  @override
  String get meSyncUnreachableDetail =>
      'Can\'t sync right now · tap to try again';

  @override
  String meSyncUnreachableWaitingDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes waiting to sync, saved on this phone.\nCan\'t sync right now · tap to try again',
      one: '1 change waiting to sync, saved on this phone.\nCan\'t sync right now · tap to try again',
    );
    return '$_temp0';
  }

  @override
  String get meSyncWaiting => 'Waiting';

  @override
  String meSyncWaitingDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes saved on this phone, waiting to sync',
      one: '1 change saved on this phone, waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get meSyncSaved => 'Saved';

  @override
  String get meSyncSavedDetail => 'Everything is saved to your account';

  @override
  String meBuildNumber(String version, String build) {
    return '$version (build $build)';
  }

  @override
  String meBuildLine(
    String version,
    String commit,
    String contract,
    String server,
  ) {
    return '$version · commit $commit · contract $contract\nServer: $server';
  }

  @override
  String get meEditProfile => 'Edit profile';

  @override
  String get meProfileNotLoaded =>
      'Your profile has not loaded on this phone yet.';

  @override
  String get meGroupPersonal => 'Personal';

  @override
  String get meGroupActivity => 'Activity & tracking';

  @override
  String get meGroupPreferences => 'Preferences';

  @override
  String get meGroupAccount => 'Account';

  @override
  String get meBodySubtitle => 'Weight, measurements and comparisons';

  @override
  String get meGoals => 'Nutrition goals';

  @override
  String get meGoalsNoneSet => 'None set';

  @override
  String get meGoalsSet => 'Daily goals you set';

  @override
  String get meGoalsHelp => 'Help with nutrition goals';

  @override
  String get meGoalsCoachSay =>
      'These are your daily tracking targets. You can leave either one blank.';

  @override
  String get meGoalsPanelTitle =>
      'Set your own daily targets. Any of them may be left blank.';

  @override
  String get meGoalsPanelBody =>
      'They repeat every day until you change them. Today and Eat show your progress once you set one.';

  @override
  String get meSteps => 'Steps';

  @override
  String get meStepsOnSubtitle => 'Counted with this phone';

  @override
  String get meStepsOffSubtitle => 'Off · counted with your phone when on';

  @override
  String get meOn => 'On';

  @override
  String get meOff => 'Off';

  @override
  String get meAppearance => 'Appearance';

  @override
  String get meAppearanceSubtitle => 'Make GoHard feel like yours.';

  @override
  String get meAppearanceHelp => 'Help with these settings';

  @override
  String get meAppearanceCoachSay =>
      'Pick your guide and when I show up. Motion & haptics sets how much I move.';

  @override
  String get meAccentTitle => 'Accent';

  @override
  String get meAccentBody => 'Used for buttons, highlights and the panels.';

  @override
  String get meAccentBlue => 'Blue';

  @override
  String get meAccentGreen => 'Green';

  @override
  String get meAccentPink => 'Pink';

  @override
  String meAccentSemantics(String accent) {
    return '$accent accent';
  }

  @override
  String get meModeTitle => 'Mode';

  @override
  String get meModeBody => 'System follows your phone\'s appearance.';

  @override
  String get meModeLight => 'Light';

  @override
  String get meModeDark => 'Dark';

  @override
  String get meModeSystem => 'System';

  @override
  String get meAppearancePreviewSemantics =>
      'Preview of Today in this appearance';

  @override
  String get meAppearancePreview => 'Preview';

  @override
  String get meAppearancePreviewLine => 'Your accent, your mode.';

  @override
  String get meAppearancePreviewButton => 'Resume workout';

  @override
  String get meCoachTitle => 'Coach';

  @override
  String get meCoachBody =>
      'Leon, a lion, or Leona, a lioness. The same coach either way: only the look changes.';

  @override
  String meCoachChoiceSemantics(String name, String animal) {
    return '$name, $animal';
  }

  @override
  String get meCoachOnToday => 'Show coach on Today';

  @override
  String meCoachOnTodayOn(String guide) {
    return '$guide beside your greeting.';
  }

  @override
  String meCoachOnTodayOff(String guide) {
    return 'Off. Ask GoHard is still $guide, on Train.';
  }

  @override
  String get meCoachOnTabs => 'Show coach on Train and Eat';

  @override
  String meCoachOnTabsOn(String guide) {
    return '$guide with a short tip under the title.';
  }

  @override
  String meCoachOnTabsOff(String guide) {
    return 'Off. Help is still a tap on $guide\'s avatar.';
  }

  @override
  String get meCoachHints => 'Coaching hints';

  @override
  String meCoachHintsOn(String guide) {
    return 'A short tip from $guide beside GoHard\'s help, once each.';
  }

  @override
  String get meCoachHintsOff => 'Off. Help is still there when you ask.';

  @override
  String get meCoachHintsReset => 'Show coaching hints again';

  @override
  String get meCoachHintsResetDone =>
      'Coaching hints you have seen can show again.';

  @override
  String get meTodayBackground => 'Today background';

  @override
  String get meMotionHaptics => 'Motion & haptics';

  @override
  String get meMotionSubtitle => 'How GoHard moves and taps on this phone.';

  @override
  String get meMotionSection => 'Motion';

  @override
  String get meHapticsSection => 'Haptics';

  @override
  String get meMotionReducedSummary => 'Reduced motion';

  @override
  String get meHapticsOffSummary => 'Haptics off';

  @override
  String get meMotionReducedHapticsOffSummary => 'Reduced · Haptics off';

  @override
  String get meMotionDevicePhoneReduces =>
      'Follows your phone. Reduce Motion is on there, so screens and progress change without movement.';

  @override
  String get meMotionDevicePhoneMoves =>
      'Follows your phone\'s Reduce Motion setting. It is off there, so short transitions are shown.';

  @override
  String get meMotionReducedExplanation =>
      'Screens, sheets and progress change without movement, whatever your phone is set to.';

  @override
  String get meHapticsDeviceExplanation =>
      'A light tap when you make a selection or confirm an action, if your phone allows vibration. Never for syncing or typing.';

  @override
  String get meHapticsOffExplanation => 'GoHard does not vibrate this phone.';

  @override
  String get mePrefsApplyNow =>
      'Changes apply immediately and are remembered on this phone.';

  @override
  String get mePermissions => 'Phone permissions';

  @override
  String get mePermissionsSubtitle => 'Location, camera and notifications';

  @override
  String get meReminders => 'Workout reminders';

  @override
  String get meRemindersOnSubtitle =>
      'On days with a planned workout. None while your plan is paused.';

  @override
  String get meReminderTime => 'Reminder time';

  @override
  String get meReminderTimeSubtitle => 'This phone\'s local time';

  @override
  String get meSyncStatus => 'Sync status';

  @override
  String get meDeleteAccount => 'Delete account';

  @override
  String get meDeleteAccountSubtitle =>
      'Permanently erases your account and data';

  @override
  String get meSignOut => 'Sign out';

  @override
  String get meSignOutConfirmTitle => 'Sign out?';

  @override
  String meSignOutConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your workouts, food and plans stay saved, including $count changes not yet synced. They stay private to your account on this phone and continue syncing when you sign in again.',
      one: 'Your workouts, food and plans stay saved, including 1 change not yet synced. They stay private to your account on this phone and continue syncing when you sign in again.',
      zero: 'Your workouts, food and plans stay saved. They stay private to your account on this phone and continue syncing when you sign in again.',
    );
    return '$_temp0';
  }

  @override
  String get meSaveName => 'Save name';

  @override
  String get meNameNotSaved =>
      'Your name could not be saved on this phone. What you typed is still here.';

  @override
  String get meNameField => 'Name shown in the app';

  @override
  String meSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get meDeletePasswordMissing => 'Enter your password to confirm.';

  @override
  String get meDeleteConfirmTitle => 'Delete your account?';

  @override
  String get meDeleteConfirmBody =>
      'Your account and all of its workouts, food, plans and measurements will be permanently erased. This cannot be undone.';

  @override
  String get meDeleteConfirmAction => 'Delete everything';

  @override
  String get meDeleteButton => 'Delete my account';

  @override
  String get meDeleteKeep => 'Keep my account';

  @override
  String get meDeleteExplanation =>
      'This permanently erases your account and everything in it, on the server and on this phone. Signing out is different: it keeps everything.';

  @override
  String meDeletePendingWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes on this phone have not synced yet and will be erased too.',
      one: '1 change on this phone has not synced yet and will be erased too.',
    );
    return '$_temp0';
  }

  @override
  String get meDeletePasswordField => 'Your password';

  @override
  String get bodyTitle => 'Body progress';

  @override
  String get bodyFieldWeight => 'Weight';

  @override
  String get bodyFieldWaist => 'Waist';

  @override
  String get bodyFieldChest => 'Chest';

  @override
  String get bodyFieldLeftUpperArm => 'Left upper arm';

  @override
  String get bodyFieldRightUpperArm => 'Right upper arm';

  @override
  String get bodyFieldLeftThigh => 'Left thigh';

  @override
  String get bodyFieldRightThigh => 'Right thigh';

  @override
  String get bodyFieldBodyFat => 'Body fat';

  @override
  String bodyFieldValue(String field, String value) {
    return '$field $value';
  }

  @override
  String get bodyUnitCm => 'cm';

  @override
  String get bodyUnitIn => 'in';

  @override
  String get bodyUnitPoints => 'pts';

  @override
  String get bodyUnitWeight => 'Weight';

  @override
  String get bodyUnitLength => 'Length';

  @override
  String get bodyErrorNotANumber => 'Enter a number, or leave it blank.';

  @override
  String get bodyErrorWeightRange =>
      'Weight is above 0 and at most 700 kg (1,543 lb).';

  @override
  String get bodyErrorLengthRange =>
      'Use a value above 0 and at most 500 cm (196.85 in).';

  @override
  String get bodyErrorFatRange => 'Body fat is from 0 to 100 %.';

  @override
  String get bodyErrorNothingEntered =>
      'Enter at least one measurement to save.';

  @override
  String bodyErrorFieldOutOfRange(String field) {
    return '$field is out of range.';
  }

  @override
  String get bodyErrorNoteTooLong => 'A note is at most 200 characters.';

  @override
  String get bodyErrorMeasurementsNeedServer =>
      'Your account\'s server cannot store these measurements yet. Weight and body fat can be saved now.';

  @override
  String get bodyErrorNeedsOneMeasurement =>
      'An entry needs at least one measurement. To remove it, use Delete entry.';

  @override
  String get bodyErrorCorrectionNeedsServer =>
      'Correcting an entry needs an update to your account\'s server. Your changes are still here.';

  @override
  String bodyRangeLabel(String range) {
    String _temp0 = intl.Intl.selectLogic(range, {
      'weeks4': '4 weeks',
      'weeks12': '12 weeks',
      'other': 'All',
    });
    return '$_temp0';
  }

  @override
  String bodyRangeWords(String range) {
    String _temp0 = intl.Intl.selectLogic(range, {
      'weeks4': 'in the last 4 weeks',
      'weeks12': 'in the last 12 weeks',
      'other': 'in all your history',
    });
    return '$_temp0';
  }

  @override
  String get bodyReadErrorTitle => 'This could not be read';

  @override
  String get bodyReadErrorBody =>
      'Your measurements on this phone could not be read just now. Nothing was changed; try again.';

  @override
  String get bodySyncNeedsReview => 'Needs review in Me › Sync status';

  @override
  String get bodySyncWaiting => 'Saved on this phone · waiting to sync';

  @override
  String bodyDayEntriesKnown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries this day, in the order they were saved.',
      one: '1 entry this day, in the order it was saved.',
    );
    return '$_temp0';
  }

  @override
  String bodyDayEntriesUnknown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count entries this day. The order they were taken in is not known.',
      one: '1 entry this day. The order it was taken in is not known.',
    );
    return '$_temp0';
  }

  @override
  String bodySavedAt(String time) {
    return 'Saved at $time';
  }

  @override
  String bodySavedAtLower(String time) {
    return 'saved $time';
  }

  @override
  String bodyEntryNumber(int number) {
    return 'Entry $number';
  }

  @override
  String get bodyHelp => 'Help with body progress';

  @override
  String get bodyCoachSay =>
      'Track what matters to you. Every measurement is optional.';

  @override
  String get bodyHowToMeasure => 'How to measure';

  @override
  String get bodyEmptyTitle => 'Nothing recorded yet';

  @override
  String get bodyEmptyBody =>
      'Log a weight or any one measurement when it helps you. Nothing here is required.';

  @override
  String get bodyLogMeasurements => 'Log measurements';

  @override
  String bodyPendingOldServer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes saved on this phone. Some wait for your account\'s server to support body measurements.',
      one: '1 change saved on this phone. Some wait for your account\'s server to support body measurements.',
    );
    return '$_temp0';
  }

  @override
  String bodyPendingWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes saved on this phone · waiting to sync',
      one: '1 change saved on this phone · waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get bodyAllMeasurements => 'All measurements';

  @override
  String get bodyLatestWeight => 'Latest weight';

  @override
  String get bodyNotRecorded => 'Not recorded';

  @override
  String get bodyNotRecordedLower => 'not recorded';

  @override
  String get bodyDashNotRecorded => '— Not recorded';

  @override
  String get bodyOtherBelow => 'Your other measurements are below.';

  @override
  String bodyAverageOfEntries(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Average of $count entries on $date',
      one: 'Average of 1 entry on $date',
    );
    return '$_temp0';
  }

  @override
  String bodyRecordedOn(String date) {
    return 'Recorded $date';
  }

  @override
  String get bodySevenDayAverage => '7-day average';

  @override
  String get bodyNotAvailable => 'Not available';

  @override
  String get bodyNotAvailableLower => 'not available';

  @override
  String get bodyNoWeightSevenDays => 'No weight in the last 7 days';

  @override
  String bodyRecordedDaysOfSeven(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recorded days of 7',
      one: '1 recorded day of 7',
    );
    return '$_temp0';
  }

  @override
  String bodyDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get bodyLog => 'Log';

  @override
  String get bodyCompareDates => 'Compare dates';

  @override
  String bodyOverTime(String field) {
    return '$field over time';
  }

  @override
  String get bodySeeAll => 'See all';

  @override
  String get bodyChartNoWeight =>
      'No weight recorded yet. Log one to see it over time.';

  @override
  String bodyChartNone(String field) {
    return 'No $field recorded yet.';
  }

  @override
  String bodyChartEmptyInRange(String field, String range) {
    return 'No $field $range. Choose a longer range.';
  }

  @override
  String get bodyChartLegendDaily => 'Points: each entry · line: daily average';

  @override
  String get bodyChartLegendPoints => 'Each point is an entry you recorded';

  @override
  String bodyChartSemantics(
    String field,
    String range,
    int count,
    String readings,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$field $range: $_temp0. $readings.';
  }

  @override
  String bodyReading(String date, String value) {
    return '$date, $value';
  }

  @override
  String bodyOneDayInRange(String range) {
    return 'One day recorded $range. A change needs at least two.';
  }

  @override
  String bodyRangeChange(String change) {
    return 'First to latest day in this range: $change';
  }

  @override
  String get bodyLatestMeasurements => 'Latest measurements';

  @override
  String get bodyLatestNone =>
      'No measurements other than weight yet. Log measurements to add waist, chest, arms or thighs.';

  @override
  String get bodyMetricFatSubtitle => 'Body fat you entered, in %';

  @override
  String bodyMetricUnitSubtitle(String unit) {
    return 'In $unit';
  }

  @override
  String get bodyEntriesInRange => 'Entries in this range';

  @override
  String get bodyHistorySubtitle => 'Every entry, newest first';

  @override
  String get bodyHistoryEmptyBody =>
      'Your entries appear here once you log one.';

  @override
  String get bodyNoMeasurement => 'No measurement';

  @override
  String bodyOneOfEntriesLower(int count) {
    return 'one of $count entries, order not known';
  }

  @override
  String bodyOneOfEntriesDay(int count) {
    return 'One of $count entries this day, order not known';
  }

  @override
  String bodyQuotedNote(String note) {
    return '“$note”';
  }

  @override
  String get bodyConvertBlocked =>
      'A field holds text that is not a number. Correct or clear it, then change the unit.';

  @override
  String get bodyDateMeasured => 'Date measured';

  @override
  String get bodyFutureDate => 'Choose today or an earlier date.';

  @override
  String get bodyCheckFields =>
      'Check the highlighted fields. Nothing was saved.';

  @override
  String get bodySavedToast =>
      'Saved on this phone · it syncs to your account when it can';

  @override
  String get bodySaveFailed =>
      'That could not be saved on this phone. Everything you typed is still here.';

  @override
  String get bodyDeleteConfirmTitle => 'Delete this entry?';

  @override
  String bodyDeleteConfirmBody(String date) {
    return 'The entry from $date will be removed from your measurements.';
  }

  @override
  String get bodyDeleteFailed =>
      'That could not be removed on this phone. Try again.';

  @override
  String get bodyChooseMeasurements => 'Choose measurements';

  @override
  String get bodyChooseSubtitle => 'Body fat, a note, or fewer fields';

  @override
  String get bodyChooseExplanation =>
      'Choose what this form shows. Hiding a field never removes anything you recorded.';

  @override
  String get bodyNote => 'Note';

  @override
  String get bodyNoteOptional => 'Note (optional)';

  @override
  String get bodyDiscardTitle => 'Discard your changes?';

  @override
  String get bodyDiscardBody => 'What you typed has not been saved.';

  @override
  String get bodyDiscard => 'Discard';

  @override
  String get bodyKeepEditing => 'Keep editing';

  @override
  String get bodyEditEntry => 'Edit entry';

  @override
  String get bodyEveryOptional => 'Every measurement is optional.';

  @override
  String get bodyDoneTyping => 'Done typing';

  @override
  String get bodySaveMeasurements => 'Save measurements';

  @override
  String get bodySaveChanges => 'Save changes';

  @override
  String get bodyAtLeastOne =>
      'Enter at least one measurement to save. Blank means not measured.';

  @override
  String get bodyDeleteEntry => 'Delete entry';

  @override
  String get bodyCompareFrom => 'Compare from';

  @override
  String get bodyCompareTo => 'Compare to';

  @override
  String get bodyCompareOnlySaved =>
      'Only days with a saved entry can be chosen.';

  @override
  String get bodyCompareSubtitle => 'Changes between your recorded entries.';

  @override
  String get bodyCompareHelp => 'Help with comparing';

  @override
  String get bodyCompareCoachSay =>
      'Compare the same measurement on two dates. A dash means it was not recorded that day.';

  @override
  String get bodyTwoDatesTitle => 'Two dates needed';

  @override
  String get bodyTwoDatesNone =>
      'Comparing needs entries on two different days. You have none yet.';

  @override
  String bodyTwoDatesOne(String date) {
    return 'Comparing needs entries on two different days. You have entries on $date only.';
  }

  @override
  String get bodyCompareLost =>
      'An entry you chose is no longer available, so the default is shown.';

  @override
  String get bodyCompareChoose =>
      'Those days have more than one entry and their order is not known. Choose the entries to compare.';

  @override
  String get bodyCompareSame =>
      'From and To are the same entry. Choose another one.';

  @override
  String get bodyChoose => 'Choose';

  @override
  String get bodyFrom => 'From';

  @override
  String get bodyTo => 'To';

  @override
  String bodyCompareWeightChange(String change) {
    return 'Change  $change';
  }

  @override
  String get bodyCompareWeightNoChange =>
      'Change  —  needs a weight on both days';

  @override
  String get bodyMeasurements => 'Measurements';

  @override
  String get bodyChange => 'Change';

  @override
  String bodyChangeValue(String change) {
    return 'Change: $change';
  }

  @override
  String bodyDatedValue(String date, String value) {
    return '$date: $value';
  }

  @override
  String bodyCompareRowSemantics(
    String field,
    String fromDate,
    String fromValue,
    String toDate,
    String toValue,
    String change,
  ) {
    return '$field: $fromDate $fromValue, $toDate $toValue, change $change';
  }

  @override
  String get bodyFatPointsNote => 'Body fat change is in percentage points.';

  @override
  String get bodyRecordedOnly =>
      'Recorded values only. A change is shown only where both entries have that measurement.';

  @override
  String get bodyHowSubtitle =>
      'Measure the same way each time, so entries compare.';

  @override
  String get bodyHowTapeTitle => 'Any tape measurement';

  @override
  String get bodyHowTapeBody =>
      'Use a flexible tape. Keep it level and snug, without pressing into the skin, and read it at the same place every time.';

  @override
  String get bodyHowWaistBody =>
      'Find the top of your hip bone at the side. Wrap the tape around your waist at that level, parallel to the floor, and read it at the end of a normal breath out.';

  @override
  String get bodyHowArmTitle => 'Upper arm';

  @override
  String get bodyHowArmBody =>
      'Find the midpoint between the bony tip of your shoulder and the point of your elbow, at the back of the arm. With the arm relaxed and hanging loosely, wrap the tape around the arm at that point. Tensing the muscle changes the reading. Measure the left and right arm separately.';

  @override
  String get bodyHowChestThighsTitle => 'Chest and thighs';

  @override
  String get bodyHowChestThighsBody =>
      'GoHard has no verified standard landmark for these. Choose one place, note it if that helps, and measure there each time with the same tape fit. Measure the left and right thigh separately.';

  @override
  String get bodyHowWeightFatTitle => 'Weight and body fat';

  @override
  String get bodyHowWeightFatBody =>
      'Optional. Enter body fat only if you have a value from a method you trust; GoHard does not estimate it.';

  @override
  String get bodyHowSource =>
      'Source: Centers for Disease Control and Prevention, National Center for Health Statistics. NHANES Anthropometry Procedures Manual, January 2017: 3.4.6 Upper Arm Length, 3.4.7 Arm Circumference, 3.4.8 Abdominal (Waist) Circumference.';

  @override
  String get bodyHowNotAdvice =>
      'This is measuring technique, not health advice. GoHard does not judge measurements.';

  @override
  String get planListComma => ', ';

  @override
  String get planSequenceArrow => ' → ';

  @override
  String planDateMove(String from, String to) {
    return '$from  →  $to';
  }

  @override
  String planDateSpan(String start, String end) {
    return '$start to $end';
  }

  @override
  String planDateRangeSameMonth(String month, String startDay, String endDay) {
    return '$month $startDay – $endDay';
  }

  @override
  String planDateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String planTitleDate(String title, String date) {
    return '$title, $date';
  }

  @override
  String get planWorkoutFallback => 'Workout';

  @override
  String get planDefaultTitle => 'My plan';

  @override
  String planCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get planModeFixed => 'Fixed weekdays';

  @override
  String get planModeRotating => 'Rotating sequence';

  @override
  String planWeekN(int week) {
    return 'Week $week';
  }

  @override
  String planWeekNOfM(int week, int total) {
    return 'Week $week of $total';
  }

  @override
  String planWeekLower(int week) {
    return 'week $week';
  }

  @override
  String planSessionN(int n) {
    return 'Session $n';
  }

  @override
  String planSessionLower(int n) {
    return 'session $n';
  }

  @override
  String planSessionStep(int n, int step, int total, int cycle) {
    return 'Session $n · step $step of $total, cycle $cycle';
  }

  @override
  String planWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String planWeeksPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
    );
    return '$_temp0';
  }

  @override
  String planWorkoutsPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts',
    );
    return '$_temp0';
  }

  @override
  String planExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
      one: '1 exercise',
    );
    return '$_temp0';
  }

  @override
  String planExercisesPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
    );
    return '$_temp0';
  }

  @override
  String planPlannedSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planned sets',
      one: '1 planned set',
    );
    return '$_temp0';
  }

  @override
  String planSetsPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
    );
    return '$_temp0';
  }

  @override
  String planSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String planRepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reps',
    );
    return '$_temp0';
  }

  @override
  String planRxSetsTimes(int sets, String amount) {
    return '$sets × $amount';
  }

  @override
  String planRestMinutes(int minutes) {
    return '$minutes min rest';
  }

  @override
  String planRestSeconds(int seconds) {
    return '$seconds s rest';
  }

  @override
  String get planNoTarget => 'No target';

  @override
  String planTargetLoad(String load) {
    return 'Target $load';
  }

  @override
  String planPlannedTime(int minutes) {
    return 'Planned time $minutes min';
  }

  @override
  String get planOngoing => 'Ongoing';

  @override
  String get planOngoingLower => 'ongoing';

  @override
  String planStartsOn(String date) {
    return 'starts $date';
  }

  @override
  String planEndsOn(String date) {
    return 'ends $date';
  }

  @override
  String get planTodayLower => 'today';

  @override
  String get planTodayLabel => 'Today';

  @override
  String get planRestDayLower => 'rest day';

  @override
  String get planNext => 'Next';

  @override
  String get planSplitEvidenceNote =>
      'Studies comparing splits with the same weekly volume found similar strength and muscle gains, so pick the structure you can keep doing.';

  @override
  String planSuggestReasonFew(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'With $days days a week, full-body sessions train every muscle group each time you train.',
      one: 'With 1 day a week, full-body sessions train every muscle group each time you train.',
    );
    return '$_temp0';
  }

  @override
  String get planSuggestReasonFour =>
      'With 4 days, alternating upper and lower body trains each half twice a week.';

  @override
  String get planSuggestReasonFive =>
      'With 5 days, an upper and a lower day plus push, pull and legs trains each area about twice a week.';

  @override
  String planSuggestReasonMany(int days) {
    return 'With $days days, repeating push, pull and legs trains each area twice a week.';
  }

  @override
  String planSuggestReasonSeven(int days) {
    return 'With $days days, repeating push, pull and legs trains each area twice a week and leaves one day for rest.';
  }

  @override
  String get planDirectionStrength => 'Get stronger';

  @override
  String get planDirectionMuscle => 'Build muscle';

  @override
  String get planDirectionFatLoss => 'Lose fat';

  @override
  String get planDirectionGeneral => 'General fitness';

  @override
  String planSetupPerWeek(String count) {
    return '$count a week';
  }

  @override
  String planSetupAbout(String minutes) {
    return 'about $minutes min';
  }

  @override
  String get planReviewedPlan => 'Reviewed plan';

  @override
  String get planOwnSplit => 'Your own split';

  @override
  String get planStarterSplit => 'Starter split';

  @override
  String get builderEquipmentFullGym => 'Full gym';

  @override
  String get builderEquipmentDumbbells => 'Dumbbells only';

  @override
  String get builderEquipmentBodyweight => 'Bodyweight only';

  @override
  String get builderExperienceNew => 'New to training';

  @override
  String get builderExperienceComfortable => 'Comfortable with the basics';

  @override
  String get builderExperienceExperienced => 'Experienced';

  @override
  String planLifecycle(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'draft': 'draft',
      'active': 'active',
      'paused': 'paused',
      'closed': 'closed',
      'other': '$state',
    });
    return '$_temp0';
  }

  @override
  String get planProvenanceManual => 'Manual workout · not part of a plan';

  @override
  String planProvenanceGone(String title) {
    return 'From a plan that is no longer on this phone · $title';
  }

  @override
  String planProvenanceFrom(String plan, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'archived': 'From $plan (archived)',
      'closed': 'From $plan (closed)',
      'paused': 'From $plan (paused)',
      'other': 'From $plan',
    });
    return '$_temp0';
  }

  @override
  String planSessionOfRotation(int n) {
    return 'session $n of the rotation';
  }

  @override
  String get planErrTitle => 'Give the plan a name of up to 60 characters.';

  @override
  String get planErrDuration =>
      'Choose a length between 1 and 52 weeks. Only a rotating sequence can run without an end.';

  @override
  String get planErrTimeBudget =>
      'Choose a planned time between 10 and 240 minutes, or none.';

  @override
  String get planErrWorkouts =>
      'Check the workouts: each needs a name, and sets, reps, rest and weights must be in range.';

  @override
  String get planErrSchedule =>
      'Check the schedule: every day or step needs a workout, with one workout per weekday.';

  @override
  String get planErrNotUsable =>
      'Add at least one exercise to every scheduled workout before you activate the plan.';

  @override
  String get planErrNewerApp =>
      'This plan was made with a newer version of the app. Update the app to change it.';

  @override
  String get planErrUnknownExercise =>
      'An exercise in this plan is not available to your account.';

  @override
  String get planErrStartLocked =>
      'An active plan keeps its start date. Duplicate it to start again on another day.';

  @override
  String get planErrModeLocked =>
      'An active plan keeps its schedule type. Duplicate it to switch between weekdays and a rotation.';

  @override
  String get planErrNotMovable =>
      'A rotating plan has no fixed dates. Skip the workout, or do it next time you train.';

  @override
  String get planErrExerciseName =>
      'Give the exercise a name of up to 80 characters.';

  @override
  String get planErrChangedSinceEdit =>
      'This plan changed after you started editing it. Start again from the plan as it is now.';

  @override
  String get planErrNotActive =>
      'This plan is closed. Duplicate it to train with it again.';

  @override
  String get planErrTargetContext =>
      'This exercise is no longer in that plan workout, so its target was not changed. Review the plan instead.';

  @override
  String get planErrTargetChanged =>
      'This target was changed again since then, so the earlier one was not restored. Edit it instead.';

  @override
  String planErrUnknown(String code) {
    return 'That change could not be applied ($code).';
  }

  @override
  String get planErrRecovery =>
      'That leaves no recovery day between two workouts.';

  @override
  String get planErrNotEligible =>
      'That workout is already recorded, skipped or in progress, so it cannot move.';

  @override
  String get planErrStaleReview =>
      'The schedule changed since you reviewed it. Review it again.';

  @override
  String get planErrWeekdayCount =>
      'Choose exactly as many days as workouts per week.';

  @override
  String get planErrInvalidDate => 'Enter a real calendar date.';

  @override
  String get planErrNoLongerInPlan =>
      'That workout is no longer part of this plan.';

  @override
  String get planPrimaryExists =>
      'Another plan is already your primary plan. Review the replacement first.';

  @override
  String get planLocalSaveFailed =>
      'That could not be saved on this phone. Nothing changed.';

  @override
  String get trainSectionWorkouts => 'Workouts';

  @override
  String get trainSectionPlan => 'Plan';

  @override
  String get trainSectionProgress => 'Progress';

  @override
  String get trainAskStartingPlan => 'Starting a plan';

  @override
  String get trainAskYourPlan => 'Your plan';

  @override
  String get trainAskYourProgress => 'Your progress';

  @override
  String get trainAskYourTraining => 'Your training';

  @override
  String get planStartInProgressCoach =>
      'Your plan in progress is saved on this phone. Pick up where you left off.';

  @override
  String get planStartInProgressTitle => 'Plan in progress';

  @override
  String get planStartInProgressBody =>
      'Saved on this phone. Nothing is scheduled until you start it.';

  @override
  String get planStartContinue => 'Continue my plan';

  @override
  String get planStartDraftCoach =>
      'Your plan is saved as a draft. Review it, then start it when you\'re ready.';

  @override
  String get planStartDraftTitle => 'Your plan is ready to review';

  @override
  String get planStartDraftBody =>
      'A saved draft does not schedule anything until you start it.';

  @override
  String get planStartReview => 'Review my plan';

  @override
  String get planStartNewCoach =>
      'Let\'s build your training plan. Choose a familiar split or make your own.';

  @override
  String get planStartNewTitle => 'No plan yet';

  @override
  String get planStartNewBody =>
      'Choose a familiar split or make your own. Nothing is scheduled until you review it.';

  @override
  String get planStartCreate => 'Create my plan';

  @override
  String get trainCoachPlanPaused =>
      'Your plan is paused, so nothing counts as missed. Resume it below when you\'re ready.';

  @override
  String get trainCoachPlanWeek =>
      'Here\'s your plan week by week. Tap a workout for its details, or ask me about the schedule.';

  @override
  String get trainCoachWorkoutOpen =>
      'A workout is still open. Resume it below when you\'re ready.';

  @override
  String get trainCoachWorkoutsPlan =>
      'Start your planned workout from Today, or record one of your own here.';

  @override
  String get trainCoachWorkoutsNoPlan =>
      'Record a workout of your own here. A plan can schedule them for you.';

  @override
  String get trainScheduledToday => 'Scheduled today';

  @override
  String trainDueToday(String summary) {
    return 'Due today · $summary';
  }

  @override
  String get trainOpenWorkouts => 'Open workouts';

  @override
  String get trainStartManual => 'Start a manual workout';

  @override
  String get trainStartManualSubtitle =>
      'Train without a plan. It never ticks off a planned workout.';

  @override
  String get trainRunWalk => 'Run / Walk';

  @override
  String get trainRunWalkSubtitle =>
      'Record a run or a walk outdoors, with its route';

  @override
  String get trainRunWalkHistory => 'Run / Walk history';

  @override
  String get trainRunWalkHistorySubtitle =>
      'Every run and walk, routes and personal bests';

  @override
  String get trainRecentEmptyTitle => 'No workouts recorded yet';

  @override
  String get trainRecentEmptyBody =>
      'When you finish a workout, what you actually did shows up here.';

  @override
  String get trainSavedForLater => 'Saved for later';

  @override
  String get trainInProgress => 'In progress';

  @override
  String trainOpenStatusLine(String status, String date) {
    return '$status · started $date';
  }

  @override
  String trainSetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets recorded',
      one: '1 set recorded',
    );
    return '$_temp0';
  }

  @override
  String get trainResume => 'Resume';

  @override
  String get trainDetails => 'Details';

  @override
  String trainDetailsOf(String title) {
    return 'Details of $title';
  }

  @override
  String get planNeedsReview =>
      'A plan change saved on this phone differs from your account. Review it from the notice at the bottom of the screen.';

  @override
  String get planTrainWithoutPlan => 'Train without a plan';

  @override
  String get planTrainWithoutPlanSaid =>
      'Start a manual workout without a plan';

  @override
  String get planSavedAndPast => 'Saved and past plans';

  @override
  String planSavedDraftReady(String mode, String date) {
    return 'Draft · $mode · not started · would start $date';
  }

  @override
  String planSavedDraftEmpty(String mode) {
    return 'Draft · $mode · add exercises to use it';
  }

  @override
  String planSavedDraftOld(String date) {
    return 'Draft · not started · would start $date';
  }

  @override
  String get planSavedPaused => 'Paused · not your primary plan';

  @override
  String get planSavedActive => 'Active · not your primary plan';

  @override
  String get planStoppedEarly => 'Stopped early';

  @override
  String get planFinishedForNow => 'Finished for now';

  @override
  String planArchivedCount(int count) {
    return 'Archived plans ($count)';
  }

  @override
  String get planNotStarted => 'Not started';

  @override
  String get planPaused => 'Paused';

  @override
  String planEnds(String date) {
    return 'Ends $date';
  }

  @override
  String get planOngoingNoEnd => 'Ongoing, no end date';

  @override
  String planStarts(String date) {
    return 'Starts $date';
  }

  @override
  String get planPausedLine =>
      'Plan paused. No new workouts are expected, and nothing counts as missed while it is paused.';

  @override
  String get planResume => 'Resume plan';

  @override
  String get planSuggestedChange => 'Suggested change to review';

  @override
  String get planManage => 'Manage this plan';

  @override
  String get planEdit => 'Edit plan';

  @override
  String get planEditSubtitle =>
      'Workouts, exercises and schedule from a date you choose. Recorded workouts never change.';

  @override
  String get planPause => 'Pause plan';

  @override
  String get planDuplicate => 'Duplicate plan';

  @override
  String get planDuplicateSubtitle =>
      'A new draft with the same workouts and schedule. This plan stays as it is.';

  @override
  String get planReplaceMovement => 'Replace a movement in remaining workouts';

  @override
  String get planReviewBlockRow => 'Review or finish this block';

  @override
  String get planCreateDifferent => 'Create a different plan';

  @override
  String get planCreateDifferentSubtitle =>
      'Starting it will ask before replacing this one.';

  @override
  String get planArchiveNote =>
      'Your primary plan is paused, finished or replaced before it can be archived. Saved and past plans can be archived from their page.';

  @override
  String get planChooseWeek => 'Choose a week';

  @override
  String get planThisWeek => 'This week';

  @override
  String planCompletedOf(int done, int total) {
    return '$done of $total completed';
  }

  @override
  String get planWeekRailLabel => 'Workouts completed in this week';

  @override
  String get planNoWorkoutsThisWeek => 'No workouts are planned in this week.';

  @override
  String get planNextInCycle => 'Next in the cycle';

  @override
  String get planProjected => 'Projected';

  @override
  String get planProjectedLower => 'projected';

  @override
  String get planYourCycle => 'Your cycle';

  @override
  String planCycleN(int n) {
    return 'Cycle $n';
  }

  @override
  String get planRotationNoteEveryDay =>
      'A rotation has no fixed dates. The next workout waits for you until you finish or skip it, and the cycle carries on across weeks. Upcoming days assume you train every day.';

  @override
  String planRotationNoteDays(String days) {
    return 'A rotation has no fixed dates. The next workout waits for you until you finish or skip it, and the cycle carries on across weeks. Upcoming days follow your training days ($days); the others are rest days.';
  }

  @override
  String get planComingUp => 'Coming up';

  @override
  String get planNothingLeft => 'Nothing is left in this plan.';

  @override
  String get planRecentSessions => 'Recent sessions';

  @override
  String planCycleStepSemantics(int step, int total, String name) {
    return 'Step $step of $total, $name';
  }

  @override
  String planCycleStepNextSemantics(int step, int total, String name) {
    return 'Step $step of $total, $name, next';
  }

  @override
  String planCycleNothingLeft(int cycle) {
    return 'Cycle $cycle · nothing left';
  }

  @override
  String planCycleLine(int cycle, int step, int total, String name) {
    return 'Cycle $cycle · step $step of $total · $name next';
  }

  @override
  String planPassSemantics(String title, String week, int done, int total) {
    return '$title. $week. $done / $total workouts completed.';
  }

  @override
  String planPassSemanticsPercent(
    String title,
    String week,
    int done,
    int total,
    String percent,
  ) {
    return '$title. $week. $done / $total workouts completed, $percent.';
  }

  @override
  String planPassRotationSemantics(
    String title,
    String week,
    int count,
    String cycleLine,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$title. $week. $count sessions completed this week. $cycleLine.',
      one: '$title. $week. 1 session completed this week. $cycleLine.',
    );
    return '$_temp0';
  }

  @override
  String get planTrainingPlanOverline => 'Training plan';

  @override
  String get planWorkoutsCompleted => 'Workouts completed';

  @override
  String planSessionsThisWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sessions completed this week',
      one: 'Session completed this week',
    );
    return '$_temp0';
  }

  @override
  String planMovedOriginally(String date) {
    return 'Moved · originally $date';
  }

  @override
  String get planWeekDone => 'Done';

  @override
  String get planWeekCurrent => 'Current';

  @override
  String planWeekPartial(int done, int total) {
    return '$done of $total';
  }

  @override
  String get planWeekMissed => 'Missed';

  @override
  String get planWeekSkipped => 'Skipped';

  @override
  String get planWeekUpcoming => 'Upcoming';

  @override
  String get planWeekEmpty => 'No workouts';

  @override
  String get planThisWeekLower => 'this week';

  @override
  String get planNoWorkoutsLower => 'no workouts';

  @override
  String planWorkoutsCompletedOf(int done, int total) {
    return '$done of $total workouts completed';
  }

  @override
  String planPauseTitle(String title) {
    return 'Pause $title?';
  }

  @override
  String get planPauseBody =>
      'Future workouts stop being expected from today, and nothing will count as missed while it is paused. Your history and remaining workouts are kept.';

  @override
  String planPauseOpenWorkout(String workout) {
    return 'Your open workout \"$workout\" is not affected: its clock keeps running and you can still finish it.';
  }

  @override
  String get planPauseAction => 'Pause this plan';

  @override
  String get planPausedToast => 'Plan paused.';

  @override
  String planMoveHelp(String title) {
    return 'Move $title to';
  }

  @override
  String get planMoveTitle => 'Move this workout?';

  @override
  String planMoveBody(
    String title,
    int week,
    String current,
    String proposed,
    String original,
    String end,
  ) {
    return 'Workout: $title (week $week)\nCurrent date: $current\nProposed date: $proposed\nOriginally planned: $original\nBlock ends: $end\n\nIt stays the same workout in the same training week. No other workout changes, and the repeating schedule stays as it is.';
  }

  @override
  String get planMoveAction => 'Move workout';

  @override
  String get planMoveCancel => 'Keep current dates';

  @override
  String planMovedToast(String date) {
    return 'Moved to $date.';
  }

  @override
  String planSkipTitle(String title) {
    return 'Skip $title?';
  }

  @override
  String planSkipBodyRotation(String title) {
    return '$title will be marked Skipped today and the rotation moves on to the workout after it. That next workout is not put on today: it comes up on your next training day, or you can start it now. No workout, sets or completion credit are created.';
  }

  @override
  String planSkipBodyFixed(String date) {
    return 'The workout planned for $date will be marked Skipped. No workout, sets or completion credit are created, and it will not count as training.';
  }

  @override
  String get planSkipAction => 'Skip this workout';

  @override
  String get planSkipCancel => 'Keep it';

  @override
  String get planSkippedToast => 'Marked as skipped.';

  @override
  String planVirtualWhen(String date) {
    return 'Planned for $date. A rotation has no fixed dates: this is when it comes up if you keep to your training days.';
  }

  @override
  String planDateOriginally(String date, String original) {
    return '$date · originally $original';
  }

  @override
  String get planResumeWorkout => 'Resume workout';

  @override
  String get planViewRecorded => 'View what was recorded';

  @override
  String get planUndoSkip => 'Undo skip';

  @override
  String get planUnskippedToast => 'No longer skipped.';

  @override
  String get planSkippedStays =>
      'Skipped. The rotation has moved on past it, so it stays skipped.';

  @override
  String get planPausedNoStart =>
      'The plan is paused. Resume the plan to start or reschedule its workouts.';

  @override
  String get planStartNowRotation => 'Start this workout now';

  @override
  String get planStartWorkout => 'Start workout';

  @override
  String get planRestInstead => 'Rest today instead';

  @override
  String planRestToast(String title) {
    return 'Rest day. Nothing was skipped: $title waits for your next training day.';
  }

  @override
  String get planRotationNoMove =>
      'A rotation has no dates to move: this workout waits for you until you do it or skip it.';

  @override
  String planComesAfter(String title) {
    return 'Comes after $title. A rotation runs in order: do or skip the next one first.';
  }

  @override
  String get planComesAfterEarlier =>
      'Comes after the workouts before it. A rotation runs in order: do or skip the next one first.';

  @override
  String planMissedOn(String date) {
    return 'Missed on $date. Move it, skip it or do it now. It is never marked done by itself.';
  }

  @override
  String get planStartNowMissed => 'Start now';

  @override
  String get planStartEarly => 'Start this workout early';

  @override
  String get planMoveDate => 'Move to another date';

  @override
  String get planEditOnlyThis => 'Edit this workout only';

  @override
  String get planChangeSchedule => 'Change the schedule';

  @override
  String get planStartDate => 'Start date';

  @override
  String get planBlockLength => 'Block length';

  @override
  String planTrainingDaysChoose(int count) {
    return 'Training days (choose $count)';
  }

  @override
  String get planUpdateDraft => 'Update the draft';

  @override
  String get planCancelKeepSchedule => 'Cancel and keep the reviewed schedule';

  @override
  String get planUnreachableDraft =>
      'Your account cannot be reached. The draft is unchanged.';

  @override
  String planFinishAndStartTitle(String title) {
    return 'Finish $title and start this plan?';
  }

  @override
  String planPauseAndStartTitle(String title) {
    return 'Pause $title and start this plan?';
  }

  @override
  String planStartFinishBody(String current, String plan, String date) {
    return '\"$current\" will be closed as finished for now. \"$plan\" becomes your primary plan from $date. All recorded workouts are kept.';
  }

  @override
  String planStartPauseBody(String current, String plan, String date) {
    return '\"$current\" will be paused, not deleted. You can resume it later. \"$plan\" becomes your primary plan from $date. All recorded workouts are kept.';
  }

  @override
  String planOpenWorkoutStaysOpen(String workout) {
    return 'Your open workout \"$workout\" stays open with its recorded sets; you can still finish it.';
  }

  @override
  String get planFinishAndStart => 'Finish and start';

  @override
  String get planPauseAndStart => 'Pause and start';

  @override
  String planSavedStarts(String date) {
    return 'Plan saved. It starts $date.';
  }

  @override
  String get planStarted => 'Your plan has started.';

  @override
  String get planDraftNeedsExercises =>
      'Draft — add exercises to use it. Every scheduled workout needs at least one exercise before the plan can start.';

  @override
  String get planStartThis => 'Start this plan';

  @override
  String get planFinishBlockStart => 'Finish current block and start';

  @override
  String get planReplaceCurrent => 'Replace my current plan';

  @override
  String get planSaveForLater => 'Save for later';

  @override
  String get planDraftNothingScheduled => 'Draft · nothing is scheduled yet';

  @override
  String planCycleList(String names) {
    return 'Cycle: $names';
  }

  @override
  String get planAnyDayNext =>
      'Any day: the next workout is there whenever you train.';

  @override
  String planTrainingDaysList(String days) {
    return 'Training days: $days';
  }

  @override
  String planFirstWorkout(String value) {
    return 'First workout: $value';
  }

  @override
  String get planChangeDates => 'Change dates, days or length';

  @override
  String planFollowingFinish(String title) {
    return 'You are following \"$title\". Starting this plan will finish it. That needs your explicit confirmation; nothing is deleted.';
  }

  @override
  String planFollowingPause(String title) {
    return 'You are following \"$title\". Starting this plan will pause it. That needs your explicit confirmation; nothing is deleted.';
  }

  @override
  String get planNextSessions => 'Next sessions';

  @override
  String get planFirstWeek => 'First week';

  @override
  String get planRotationReviewNote =>
      'A rotation has no fixed dates. These are the days the sequence would fall on from today; it waits for you if you miss one.';

  @override
  String get planNoExercisesYetDot => 'No exercises yet.';

  @override
  String get planRepeatOld =>
      'The same workouts repeat each week with a recovery day between them. Targets are guidance; what you record is what counts.';

  @override
  String get planRepeatRotation =>
      'The sequence continues in order across weeks; it never restarts on Monday. It moves on only when you finish or skip a workout. Targets are guidance; what you record is what counts.';

  @override
  String get planRepeatFixed =>
      'These workouts repeat on the same weekdays each week. Targets are guidance; what you record is what counts.';

  @override
  String planResumeTitle(String title) {
    return 'Resume $title';
  }

  @override
  String get planResumeAccept => 'Resume with these dates';

  @override
  String get planResumedToast => 'Plan resumed.';

  @override
  String get planKeepPaused => 'Keep paused';

  @override
  String get planNextWorkoutOn => 'Next workout on';

  @override
  String get planResumeDateHelp => 'Resume date';

  @override
  String planResumeDisplaces(String title) {
    return 'This makes it your primary plan and pauses \"$title\".';
  }

  @override
  String get planResumeNoChanges =>
      'No dates need to change. Remaining workouts keep their current dates.';

  @override
  String get planResumeShifts =>
      'Every remaining workout moves by the same number of days, keeping its spacing. Recorded, skipped and in-progress workouts keep their dates.';

  @override
  String planBlockWouldEnd(String date) {
    return 'The block would end $date.';
  }

  @override
  String planCloseOpenWorkout(String workout) {
    return 'Your open workout \"$workout\" can still be finished afterwards; its result stays with this block.';
  }

  @override
  String get planBlockClosedToast => 'Block closed. Your history is kept.';

  @override
  String get planReviewBlock => 'Review this block';

  @override
  String get planCountFinished => 'Finished';

  @override
  String get planCountPartial => 'Partial';

  @override
  String get planCountRemaining => 'Still ahead or in progress';

  @override
  String get planCountsNote =>
      'Counts come from what was actually recorded for each planned workout. Reaching the end date does not by itself mean the training happened.';

  @override
  String get planBlockStoppedEarly => 'This block was stopped early.';

  @override
  String get planBlockFinished => 'This block was finished for now.';

  @override
  String get planContinueGoal => 'Continue this goal';

  @override
  String get planNextBlockStarts => 'Next block starts';

  @override
  String get planUnreachableNothingCreated =>
      'Your account cannot be reached. Nothing was created.';

  @override
  String get planContinueNote =>
      'Creates a new draft with the same setup. It does not start until you review and start it.';

  @override
  String get planFinishForNow => 'Finish for now';

  @override
  String get planCloseBlockTitle => 'Close this block?';

  @override
  String get planCloseBlockBody =>
      'The block is closed as finished for now and your primary plan slot is freed. This does not say the goal was achieved.';

  @override
  String get planCloseBlockAction => 'Close this block';

  @override
  String get planStopEarly => 'Stop early';

  @override
  String get planStopTitle => 'Stop this block early?';

  @override
  String planStopBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count planned workouts will no longer be expected. The block is recorded as stopped early, not as finished.',
      one: '1 planned workout will no longer be expected. The block is recorded as stopped early, not as finished.',
    );
    return '$_temp0';
  }

  @override
  String get planStopAction => 'Stop this block';

  @override
  String get planResumeAsPrimary => 'Resume as my primary plan';

  @override
  String get planDuplicateAsNew => 'Duplicate as a new plan';

  @override
  String get planUnarchive => 'Move out of the archive';

  @override
  String get planArchiveHide => 'Archive (hide from this list)';

  @override
  String get planRestoredToast => 'Restored to your plans.';

  @override
  String get planArchivedToast =>
      'Archived. Its outcome and history are unchanged.';

  @override
  String get planNotDone => 'Not done';

  @override
  String get planArchivedTitle => 'Archived plans';

  @override
  String get planArchivedNote =>
      'Archiving only hides a plan. Its outcome and recorded workouts are unchanged.';

  @override
  String get planReplaceMovementTitle => 'Replace a movement';

  @override
  String get planShowChange => 'Show me the change';

  @override
  String get planUnreachableNothingChanged =>
      'Your account cannot be reached. Nothing was changed.';

  @override
  String get planProposalDeclinedUnchanged =>
      'You already chose to keep the current plan for exactly this change.';

  @override
  String get planNothingToChange =>
      'There is nothing to change for that choice.';

  @override
  String get planSubstitutionNote =>
      'Only remaining workouts that have not been started are affected. You will review the exact change before it applies.';

  @override
  String get planReplaceLabel => 'Replace';

  @override
  String get planNoMovement =>
      'No remaining workout has a movement to replace.';

  @override
  String get planWith => 'With';

  @override
  String get planChooseMovement => 'Choose a movement';

  @override
  String get planReplaceWith => 'Replace with';

  @override
  String get planCustomNotInPlanChange =>
      'Choose a movement from the list. Custom movements can be used inside a workout, not in a plan change.';

  @override
  String get planChangeApplied => 'Change applied to the reviewed workouts.';

  @override
  String get planKeptCurrent => 'Kept your current plan.';

  @override
  String get planSuggestionStale =>
      'This suggestion no longer matches your plan or records, so it was not applied. Nothing changed.';

  @override
  String get planSuggestedChangeTitle => 'Suggested change';

  @override
  String get planAcceptChange => 'Accept this change';

  @override
  String get planKeepCurrent => 'Keep current plan';

  @override
  String get planDismissSuggestion => 'Dismiss this suggestion';

  @override
  String get planProposalStaleLine =>
      'Your plan or recorded workouts changed after this was suggested, so it can no longer be applied as reviewed. Request it again if you still want it.';

  @override
  String get planAcceptedLine => 'You accepted this change.';

  @override
  String get planDeclinedLine => 'You kept your current plan.';

  @override
  String planAffects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Affects $count unstarted workouts',
      one: 'Affects 1 unstarted workout',
    );
    return '$_temp0';
  }

  @override
  String planProposalMove(String from, String to) {
    return 'Now $from  →  proposed $to';
  }

  @override
  String planProposalNow(String from, String to) {
    return 'Now: $from\nProposed: $to';
  }

  @override
  String get planProposalNote =>
      'Recorded and in-progress workouts are never changed by a suggestion.';

  @override
  String get builderStepAvailability => 'Availability';

  @override
  String get builderStepStructure => 'Structure';

  @override
  String get builderStepWorkouts => 'Workouts';

  @override
  String get builderStepReview => 'Review';

  @override
  String get builderStartOverTitle => 'Start over?';

  @override
  String get builderDiscardAction => 'Discard it';

  @override
  String get builderDiscardBody =>
      'The plan in progress is deleted from this phone. Nothing else changes: no plan was created from it.';

  @override
  String get builderCreatePlan => 'Create plan';

  @override
  String get builderUntitled => 'Untitled plan';

  @override
  String builderStepSaved(int step, String name) {
    return 'Step $step of 4 · $name. Saved on this phone; nothing is active yet.';
  }

  @override
  String get builderContinuePlan => 'Continue this plan';

  @override
  String get builderStartOver => 'Start over';

  @override
  String get builderStartOverSaid =>
      'Start over and discard this plan in progress';

  @override
  String get builderBothWays =>
      'Both ways make a plan of your own that you can change at any time.';

  @override
  String get builderGuideMe => 'Guide me';

  @override
  String get builderGuideMeAbout => 'Help me choose a starting plan.';

  @override
  String get builderKnowWhat => 'I know what I want';

  @override
  String get builderKnowWhatAbout => 'Choose a template or build my own.';

  @override
  String builderChoiceSemantics(String label, String about) {
    return '$label. $about';
  }

  @override
  String get builderFromTemplate => 'Start from a template';

  @override
  String get builderFromTemplateSubtitle =>
      'Preview a familiar split such as Upper / Lower or Push / Pull / Legs, then make it yours.';

  @override
  String get builderBuildOwn => 'Build my own';

  @override
  String get builderBuildOwnSubtitle =>
      'Name your workouts, add exercises and arrange your week.';

  @override
  String get builderPlanChanged =>
      'This plan changed since you last edited it, so you start from the plan as it is now.';

  @override
  String get builderContinueChangesTitle => 'Continue your changes?';

  @override
  String get builderContinueChanges => 'Continue changes';

  @override
  String get builderStartFromSaved => 'Start from the saved plan';

  @override
  String builderContinueChangesBody(String title) {
    return 'You were changing \"$title\" and did not save. Continue where you left off, or start again from the plan as it is now.';
  }

  @override
  String get builderReplaceInProgressTitle => 'Replace your plan in progress?';

  @override
  String get builderReplaceIt => 'Replace it';

  @override
  String builderReplaceInProgressBody(String existing, String plan) {
    return '\"$existing\" is not finished. Duplicating \"$plan\" replaces it on this phone.';
  }

  @override
  String get builderSaveFailed =>
      'The latest change could not be saved on this phone. Keep this screen open and try again.';

  @override
  String get builderHelpWeek => 'Help with your training week';

  @override
  String get builderCoachWeek =>
      'Pick the days you can train and your equipment. The next step suggests a starting point from these answers.';

  @override
  String get builderAskWeek => 'Your training week';

  @override
  String get builderHelpSplit => 'Help with choosing a split';

  @override
  String get builderCoachSplit =>
      'Unsure which split fits your week? Let\'s compare your options.';

  @override
  String get builderAskSplit => 'Choosing a split';

  @override
  String get builderCompareSplits => 'Compare splits';

  @override
  String get builderHelpWorkouts => 'Help with these workouts';

  @override
  String get builderCoachWorkouts =>
      'Questions about sets, reps or a movement? The info button beside each exercise has the built-in guide.';

  @override
  String get builderChooseDay => 'Choose at least one day.';

  @override
  String get builderChooseStarting => 'Choose a starting plan to continue.';

  @override
  String builderPauseActivateTitle(String title) {
    return 'Pause $title and activate this plan?';
  }

  @override
  String get builderPauseActivate => 'Pause and activate';

  @override
  String builderPauseActivateBody(String current, String plan, String date) {
    return '\"$current\" will be paused, not deleted. Its history and recorded workouts are kept, and you can resume it later. \"$plan\" becomes your plan from $date.';
  }

  @override
  String builderOpenWorkoutStays(String workout) {
    return 'Your open workout \"$workout\" stays open with its recorded sets.';
  }

  @override
  String builderActiveStarts(String title, String date) {
    return '\"$title\" is active. It starts $date.';
  }

  @override
  String builderActive(String title) {
    return '\"$title\" is active.';
  }

  @override
  String get builderDraftSaved =>
      'Draft saved on this phone. Nothing is active yet.';

  @override
  String get builderChangesSaved => 'Changes saved.';

  @override
  String builderChangesSavedFrom(String date) {
    return 'Changes saved from $date.';
  }

  @override
  String get builderBack => 'Back';

  @override
  String get builderNext => 'Next';

  @override
  String get builderSaveChanges => 'Save changes';

  @override
  String get builderActivate => 'Activate plan';

  @override
  String get builderSaveDraft => 'Save draft';

  @override
  String builderProgressSemantics(int step, String name) {
    return 'Step $step of 4: $name';
  }

  @override
  String builderProgressOverline(int step, String name) {
    return 'Step $step of 4 · $name';
  }

  @override
  String builderDefaultWorkoutName(String letter) {
    return 'Workout $letter';
  }

  @override
  String get builderPrefsGuided =>
      'Answer these and the next step suggests a starting plan from them, with up to two alternatives. Nothing is created until you choose, and you can change everything later.';

  @override
  String get builderPrefsIntro =>
      'A few answers to suggest a starting point. You can change everything later.';

  @override
  String get builderDaysAWeek => 'Days a week';

  @override
  String builderDaysAWeekCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days a week',
      one: '1 day a week',
    );
    return '$_temp0';
  }

  @override
  String get builderWhichDays => 'Which days';

  @override
  String get builderEquipment => 'Equipment';

  @override
  String get builderPlannedTime => 'Planned time per workout (optional)';

  @override
  String get builderNoLimit => 'No limit';

  @override
  String get builderPlannedTimeNote =>
      'The time you plan to spend. It is your choice, not a calculated length of the workout.';

  @override
  String get builderAddExperience => 'Add your training experience (optional)';

  @override
  String get builderExperience => 'Training experience (optional)';

  @override
  String get builderReplaceWorkoutsTitle => 'Replace your workouts?';

  @override
  String get builderReplaceThem => 'Replace them';

  @override
  String builderReplaceWorkoutsBody(String source, String now, String next) {
    return 'This starts the workouts again from $source.\n\nNow: $now\nAfter: $next\n\nChanges you made to the exercises are not kept.';
  }

  @override
  String get builderYourOwnNames => 'your own names';

  @override
  String get builderUsingStarting =>
      'Using this starting plan. It is a draft: change anything in the next steps.';

  @override
  String get builderUseStarting => 'Use this starting plan';

  @override
  String builderAnswersChanged(String name) {
    return 'Your answers now suggest $name. Your edited workouts stay as they are unless you choose Use this starting plan below.';
  }

  @override
  String get builderSuggestedStarting => 'Suggested starting plan';

  @override
  String get builderYourWeek => 'Your week';

  @override
  String get builderWhySuggestion => 'Why this suggestion?';

  @override
  String get builderOtherStartingPoints => 'Other starting points';

  @override
  String get builderAlsoFits => 'Also fits your days';

  @override
  String get builderRest => 'Rest';

  @override
  String get builderRestSubtitle => 'No workout on this day';

  @override
  String get builderAddStep => 'Add a step';

  @override
  String get builderPlanLength => 'Plan length';

  @override
  String get builderWeeks => 'Weeks';

  @override
  String get builderWeeksHelper => '1 to 52 weeks';

  @override
  String get builderWeeksError => 'Choose 1 to 52 weeks.';

  @override
  String get builderUseLength => 'Use this length';

  @override
  String get builderTemplateCustomPreview =>
      'Name your own workouts and choose their days.';

  @override
  String builderTemplateWeekly(int count, String names) {
    return 'Your $count days: $names';
  }

  @override
  String builderTemplateRotates(String names, int count) {
    return 'Rotates $names over your $count days';
  }

  @override
  String builderSuggestedLine(String name, String reason) {
    return 'Suggested: $name. $reason';
  }

  @override
  String builderTemplateSuggested(String name) {
    return '$name · Suggested';
  }

  @override
  String get builderIncludeExercises => 'Include starting exercises';

  @override
  String get builderWithExercisesOn =>
      'A starting routine with sets, reps and rest and no weights. Change anything in the next step.';

  @override
  String get builderWithExercisesOff =>
      'Workouts start empty. The plan stays a draft until every scheduled workout has an exercise.';

  @override
  String get builderYourWorkouts => 'Your workouts';

  @override
  String get builderNameOnce =>
      'Name each different workout once. A workout can repeat on several days.';

  @override
  String builderWorkoutN(int n) {
    return 'Workout $n';
  }

  @override
  String builderWorkoutNLower(int n) {
    return 'workout $n';
  }

  @override
  String get builderGiveName => 'Give it a name.';

  @override
  String builderRemoveNamed(String name) {
    return 'Remove $name';
  }

  @override
  String builderRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get builderRemoveBody =>
      'Its exercises are removed with it, and every day or step that used it.';

  @override
  String get builderAddAWorkout => 'Add a workout';

  @override
  String get builderFixedNote =>
      'One workout per weekday. A workout can be used on several days. A missed workout stays on its day until you move or skip it.';

  @override
  String get builderTheCycle => 'The cycle';

  @override
  String get builderCycleNote =>
      'Workouts follow this order and start again from the top when it ends. The order carries on across weeks; it does not restart on Monday.';

  @override
  String builderMoveStepUp(int n) {
    return 'Move step $n up';
  }

  @override
  String builderMoveStepDown(int n) {
    return 'Move step $n down';
  }

  @override
  String builderRemoveStep(int n) {
    return 'Remove step $n';
  }

  @override
  String get builderTrainingDays => 'Training days';

  @override
  String get builderTrainingDaysNote =>
      'The next workout goes on the next of these days. With none chosen, any day can be a training day.';

  @override
  String get builderPlanName => 'Plan name';

  @override
  String get builderName => 'Name';

  @override
  String get builderSchedule => 'Schedule';

  @override
  String get builderModeLocked =>
      'An active plan keeps its schedule type. Duplicate it to switch.';

  @override
  String get builderFixedExplain =>
      'Fixed weekdays: each workout has its own weekday, and a missed one stays on its day.';

  @override
  String get builderRotatingExplain =>
      'Rotating sequence: an ordered cycle that continues across weeks and moves on only when you finish or skip a workout.';

  @override
  String get builderStartAndLength => 'Start and length';

  @override
  String get builderStarts => 'Starts';

  @override
  String get builderStartLocked => 'An active plan keeps its start date.';

  @override
  String get builderPlanStartsHelp => 'Plan starts';

  @override
  String get builderOtherLength => 'Other length';

  @override
  String get builderRotationLength =>
      'A rotation can run for 1 to 52 weeks, or keep going with no end.';

  @override
  String get builderFixedLength =>
      'A fixed-weekday plan has an end: 1 to 52 weeks.';

  @override
  String builderFromDate(String date) {
    return 'From $date';
  }

  @override
  String get builderSecondWeek => 'Second week';

  @override
  String builderReviewSummary(int count, String weeks, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count workouts over $weeks, the last on $date. The same week repeats until then.',
    );
    return '$_temp0';
  }

  @override
  String builderCycleThenAgain(String names) {
    return 'Cycle: $names, then it starts again.';
  }

  @override
  String get builderAnyDayTraining => 'Any day can be a training day.';

  @override
  String builderTrainingDaysDot(String days) {
    return 'Training days: $days.';
  }

  @override
  String get builderNextIfTrain =>
      'Next workouts if you train on each training day';

  @override
  String get builderProjectionNote =>
      'These dates are a projection. A missed day does not skip a workout: the same one waits for your next training day.';

  @override
  String builderPlannedTimeLower(int minutes) {
    return 'planned time $minutes min';
  }

  @override
  String builderDraftMissing(String names) {
    return 'Draft — add exercises to $names before this plan can be activated.';
  }

  @override
  String builderFollowingActivate(String title) {
    return 'You are following \"$title\". Activating this plan pauses it. Its history and recorded workouts are kept, and you can resume it later.';
  }

  @override
  String get builderChangesApplyFrom => 'Changes apply from';

  @override
  String get builderEditKeeps =>
      'Workouts you recorded or skipped, and one in progress, stay exactly as they are. Earlier workouts and any you edited on their own do not change.';

  @override
  String get builderRebuilt =>
      'This plan has not started, so it is rebuilt with these changes.';

  @override
  String get builderNoExercises => 'No exercises yet';

  @override
  String get builderTargetsNote =>
      'Targets are a starting point, not a prescription. What you record is what counts.';

  @override
  String builderUsageSteps(int count, String steps) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Steps $steps',
      one: 'Step $steps',
    );
    return '$_temp0';
  }

  @override
  String get builderRxSetsError => 'Sets: a whole number from 1 to 20.';

  @override
  String get builderRxRepsError => 'Reps: 1 to 100.';

  @override
  String get builderRxRepsOrder =>
      'The highest reps cannot be fewer than the lowest.';

  @override
  String get builderRxTimeError => 'Time: 1 to 3600 seconds.';

  @override
  String get builderRxRestError => 'Rest: 0 to 900 seconds (15 minutes).';

  @override
  String builderRxLoadError(String max) {
    return 'A weight from 0 to $max, or leave it empty.';
  }

  @override
  String get builderRxNotesError => 'Notes: up to 500 characters.';

  @override
  String get builderRxHelp => 'Help with sets, reps and this exercise';

  @override
  String get builderRxSets => 'Sets';

  @override
  String get builderRxSeconds => 'Time per set (seconds)';

  @override
  String get builderRxRepsMin => 'Reps, lowest';

  @override
  String get builderRxRepsMax => 'Reps, highest';

  @override
  String get builderRxRepsHelper => 'The same number twice is an exact target.';

  @override
  String get builderRxRest => 'Rest between sets (seconds)';

  @override
  String builderRxLoad(String unit) {
    return 'Target weight ($unit), optional';
  }

  @override
  String get builderRxLoadHelper =>
      'A target you set for yourself. It is not your last recorded weight, and the app never fills it in.';

  @override
  String get builderRxNotes => 'Notes, optional';

  @override
  String get builderCoachExercise =>
      'Questions about sets, reps or this movement?';

  @override
  String get builderAboutExercise => 'About this exercise';

  @override
  String builderReplaceExercise(String name) {
    return 'Replace $name';
  }

  @override
  String get builderNoExercisesWarn =>
      'No exercises yet. Add at least one so this workout can be scheduled.';

  @override
  String get builderEditRx => 'Edit sets, reps and rest';

  @override
  String builderAbout(String name) {
    return 'About $name';
  }

  @override
  String builderMoveUp(String name) {
    return 'Move $name up';
  }

  @override
  String builderMoveDown(String name) {
    return 'Move $name down';
  }

  @override
  String builderMoreFor(String name) {
    return 'More for $name';
  }

  @override
  String get builderReplaceWithAnother => 'Replace with another exercise';

  @override
  String get builderAddExercise => 'Add exercise';

  @override
  String builderAddTo(String name) {
    return 'Add to $name';
  }

  @override
  String get builderCopyWorkout => 'Copy a workout';

  @override
  String get builderCopyNote =>
      'The copy becomes a new workout of this plan with the same exercises. Nothing links back to where it came from.';

  @override
  String get builderThisPlan => 'This plan';

  @override
  String get builderRecordedSection =>
      'Workouts you recorded (their planned exercises)';

  @override
  String get builderCopied =>
      'Copied. Choose its days in Structure to schedule it.';

  @override
  String get builderWorkoutsIntro =>
      'Tap an exercise to change its sets, reps and rest. Targets are a starting point; what you record is what counts.';

  @override
  String get builderNotScheduled =>
      'Not scheduled yet. Choose its days in Structure.';

  @override
  String get builderRename => 'Rename';

  @override
  String get builderDuplicate => 'Duplicate';

  @override
  String get builderRenameWorkout => 'Rename workout';

  @override
  String builderDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get builderDeleteWorkout => 'Delete workout';

  @override
  String get builderDeleteBody =>
      'It is removed from this plan and from every day or step that uses it. Workouts you already recorded keep their own copy.';

  @override
  String get builderAddWorkout => 'Add workout';

  @override
  String get builderNewWorkout => 'New workout';

  @override
  String get builderCopyFrom => 'Copy from…';

  @override
  String get builderGiveWorkoutName => 'Give the workout a name.';

  @override
  String builderSavedOnly(String date) {
    return 'Saved for $date only.';
  }

  @override
  String get builderThisWorkoutOnly => 'This workout only';

  @override
  String get builderSaveThisWorkout => 'Save this workout';

  @override
  String builderOnlyThisChanges(String date, String plan) {
    return 'Only the workout on $date changes. The rest of \"$plan\" stays as it is, and later changes to the plan leave this one alone.';
  }

  @override
  String get builderWorkoutName => 'Workout name';

  @override
  String runActivityTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Walk',
      'other': 'Run',
    });
    return '$_temp0';
  }

  @override
  String get runTitle => 'Run / Walk';

  @override
  String get runHistory => 'History';

  @override
  String get runHelpAvatar => 'Help with Run / Walk';

  @override
  String get runCoachReadyIntervals =>
      'Intervals are set. Start when you\'re ready.';

  @override
  String get runCoachReady => 'Choose your setup. Start when ready.';

  @override
  String get runHelpBody =>
      'Choose Run or Walk, then Start. GoHard records your route while the screen is locked or another app is open, and saves it on this phone first. Pause any time; Finish lets you review before saving. Intervals alternate running and walking in one activity; with Voice and alerts on, I say each change aloud.';

  @override
  String runStartButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Start walk',
      'other': 'Start run',
    });
    return '$_temp0';
  }

  @override
  String runStartIntervalsButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Start walk intervals',
      'other': 'Start run intervals',
    });
    return '$_temp0';
  }

  @override
  String get runStartNoGpsTitle => 'Start without GPS?';

  @override
  String get runStartNoGpsBody =>
      'The time is recorded, and you can type a distance when you finish. No route or GPS distance is recorded.';

  @override
  String get runStartNoGpsAction => 'Start timer only';

  @override
  String runStartFailed(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk':
          'The walk could not be started on this phone. Nothing was recorded.',
      'other':
          'The run could not be started on this phone. Nothing was recorded.',
    });
    return '$_temp0';
  }

  @override
  String get runStateOn => 'On';

  @override
  String get runStateOff => 'Off';

  @override
  String runVoiceValueEvery(String interval) {
    return 'On · every $interval';
  }

  @override
  String get runMapNoPosition => 'Map, no position yet';

  @override
  String get runMapHere => 'Map showing your current position';

  @override
  String get runMapTitle => 'Map';

  @override
  String get runSimulatedGps => 'Simulated GPS (test build)';

  @override
  String get runSetupTitle => 'Your setup';

  @override
  String get runSetupIntervals => 'Intervals';

  @override
  String get runSetupVoice => 'Voice and alerts';

  @override
  String get runSetupAutoPause => 'Auto-pause';

  @override
  String get runAutoPauseNotWithIntervals => 'Not used with intervals';

  @override
  String get runAutoPauseSubtitle =>
      'Pauses when you stop for a while and resumes when you move on.';

  @override
  String get runAutoPauseIntervalsNote =>
      'Not used with intervals: walking to recover is not a pause. This choice applies to your free runs and walks.';

  @override
  String runPlanShort(String run, String walk, int reps) {
    return 'Run $run · Walk $walk · × $reps';
  }

  @override
  String get runGpsChecking => 'Checking GPS…';

  @override
  String get runGpsCheckingDetail => 'Reading this phone\'s location settings.';

  @override
  String get runGpsOff => 'Location is off';

  @override
  String get runGpsOffDetail => 'Turn on location to record a route.';

  @override
  String get runGpsOpenSettings => 'Open settings';

  @override
  String get runGpsNotAllowed => 'Location not allowed yet';

  @override
  String get runGpsNotAllowedDetail =>
      'Allow location while using GoHard to record your route.';

  @override
  String get runGpsAllow => 'Allow';

  @override
  String get runGpsBlocked => 'Location is blocked for GoHard';

  @override
  String get runGpsBlockedDetail =>
      'Allow it in Settings, or start with the timer only.';

  @override
  String get runGpsOpenAppSettings => 'Open app settings';

  @override
  String get runGpsApproximate => 'Precise location is off';

  @override
  String get runGpsApproximateDetail =>
      'Approximate location cannot measure a route.';

  @override
  String get runGpsAllowPrecise => 'Allow precise location';

  @override
  String get runGpsUnavailable => 'Location is not available';

  @override
  String get runGpsUnavailableDetail =>
      'You can still start with the timer only.';

  @override
  String get runGpsWaiting => 'Waiting for GPS…';

  @override
  String get runGpsWaitingDetail =>
      'Outdoors, with a clear view of the sky, it takes a few seconds.';

  @override
  String get runGpsReady => 'GPS ready';

  @override
  String get runGpsWeak => 'GPS signal weak';

  @override
  String get runGpsSignalGood => 'Good signal';

  @override
  String get runGpsSignalFair => 'Fair signal';

  @override
  String get runGpsSignalWeak => 'Weak signal';

  @override
  String runGpsAccuracyDetail(String quality, String accuracy) {
    return '$quality · $accuracy accuracy';
  }

  @override
  String get runStatusPaused => 'Paused';

  @override
  String get runStatusAutoPaused => 'Auto-paused';

  @override
  String get runStatusInterrupted => 'Interrupted';

  @override
  String get runMapRouteSoFar => 'Route so far';

  @override
  String runMapRouteSoFarDistance(String distance) {
    return 'Route so far, $distance';
  }

  @override
  String get runFinish => 'Finish';

  @override
  String get runResume => 'Resume';

  @override
  String get runPause => 'Pause';

  @override
  String runInterruptedLegacy(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'This walk was started before routes were kept. Its time and distance so far are kept; resume to record the rest with a route.',
      'other': 'This run was started before routes were kept. Its time and distance so far are kept; resume to record the rest with a route.',
    });
    return '$_temp0';
  }

  @override
  String get runInterrupted =>
      'Recording stopped when GoHard was closed. The time since then is left out. Resume to go on, or Finish to save it.';

  @override
  String get runTimerOnlyNote =>
      'Timer only: no GPS route or distance is recorded. You can type a distance when you finish.';

  @override
  String get runNotSaving =>
      'This phone is not saving the recording right now. Keep GoHard open; it keeps trying.';

  @override
  String get runGpsStopped =>
      'GPS stopped giving positions. The timer goes on; distance resumes when GPS does.';

  @override
  String get runVoiceToggleOn => 'Voice updates on. Turn off';

  @override
  String get runVoiceToggleOff => 'Voice updates off. Turn on';

  @override
  String runHelpRecording(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Help with recording a walk',
      'other': 'Help with recording a run',
    });
    return '$_temp0';
  }

  @override
  String get runViewStats => 'Stats';

  @override
  String get runSteps => 'Steps';

  @override
  String get runStepsPartly => 'Steps (partly)';

  @override
  String get runStepsNotCounted => 'Steps not counted';

  @override
  String get runStepsPartOfTime => 'Steps (part of the time)';

  @override
  String get runActiveTime => 'Active time';

  @override
  String runActiveTimeSaid(String duration) {
    return 'Active time $duration';
  }

  @override
  String runActiveTimePausedSaid(String duration) {
    return 'Active time $duration, paused';
  }

  @override
  String runFigureSaid(String label, String value) {
    return '$label $value';
  }

  @override
  String runFigureSaidUnknown(String label) {
    return '$label not known';
  }

  @override
  String get runDistance => 'Distance';

  @override
  String get runAvgMovingPace => 'Avg. moving pace';

  @override
  String get runChipTimerOnly => 'Timer only';

  @override
  String get runChipGpsOff => 'GPS off';

  @override
  String get runChipGpsLost => 'GPS lost';

  @override
  String get runChipWaiting => 'Waiting for GPS';

  @override
  String runChipGps(String accuracy) {
    return 'GPS · $accuracy';
  }

  @override
  String runTitleMorning(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Morning walk',
      'other': 'Morning run',
    });
    return '$_temp0';
  }

  @override
  String runTitleAfternoon(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Afternoon walk',
      'other': 'Afternoon run',
    });
    return '$_temp0';
  }

  @override
  String runTitleEvening(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Evening walk',
      'other': 'Evening run',
    });
    return '$_temp0';
  }

  @override
  String runTitleNight(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Night walk',
      'other': 'Night run',
    });
    return '$_temp0';
  }

  @override
  String runSaveTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Save your walk',
      'other': 'Save your run',
    });
    return '$_temp0';
  }

  @override
  String runSaveButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Save walk',
      'other': 'Save run',
    });
    return '$_temp0';
  }

  @override
  String get runRecordedRoute => 'Recorded route';

  @override
  String runNoRouteFor(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'No GPS route was recorded for this walk.',
      'other': 'No GPS route was recorded for this run.',
    });
    return '$_temp0';
  }

  @override
  String get runRouteNotRecordedLine => 'Route not recorded.';

  @override
  String get runRouteNotRecorded => 'Route not recorded';

  @override
  String get runDistanceNotMeasured => 'Distance not measured';

  @override
  String get runMovingTime => 'Moving time';

  @override
  String runMovingTimeSaid(String duration) {
    return 'Moving time $duration';
  }

  @override
  String get runTitleField => 'Title';

  @override
  String get runNotesOptional => 'Notes (optional)';

  @override
  String get runNotesField => 'Notes';

  @override
  String get runDistanceOptional => 'Distance (optional)';

  @override
  String get runCorrectDistance => 'Correct the distance (optional)';

  @override
  String get runDistanceTypedHelper => 'Typed, not measured by GPS.';

  @override
  String get runDistanceGpsKeptHelper =>
      'The GPS measurement is kept beside it; the route is not changed.';

  @override
  String runBlankKeepsGps(String distance) {
    return 'Blank keeps the GPS measurement ($distance).';
  }

  @override
  String get runResumeRecording => 'Resume recording';

  @override
  String runDiscardButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Discard walk',
      'other': 'Discard run',
    });
    return '$_temp0';
  }

  @override
  String runDiscardTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Discard this walk?',
      'other': 'Discard this run?',
    });
    return '$_temp0';
  }

  @override
  String runDiscardBody(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'The walk and its route are deleted from this phone and your account. This cannot be undone.',
      'other': 'The run and its route are deleted from this phone and your account. This cannot be undone.',
    });
    return '$_temp0';
  }

  @override
  String get runDistanceInvalid =>
      'Enter the distance as a number, or leave it blank.';

  @override
  String get runTitleInvalid => 'Give it a title of 1 to 80 characters.';

  @override
  String get runTitleRequired => 'Give it a title.';

  @override
  String get runSaveFailed =>
      'It could not be saved on this phone. Nothing was lost; try Save again.';

  @override
  String get runIntervalsIntro =>
      'Alternate running and walking. Walking to recover is part of the session, not a pause: it is one activity.';

  @override
  String get runIntervalsPresetNote =>
      'Starting point: Run 1 min, walk 1½ min, 8 times, as in week 1 of the NHS Couch to 5K plan. Change anything.';

  @override
  String get runIntervalsUsePreset => 'Use it';

  @override
  String get runIntervalWarmup => 'Warm-up walk';

  @override
  String get runIntervalRun => 'Run';

  @override
  String get runIntervalWalk => 'Walk / recover';

  @override
  String get runIntervalRepeats => 'Repeats';

  @override
  String get runIntervalCooldown => 'Cool-down walk';

  @override
  String get runIntervalNone => 'None';

  @override
  String get runIntervalNoneSaid => 'none';

  @override
  String runIntervalRepsValue(int count) {
    return '$count ×';
  }

  @override
  String runIntervalRepsSaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
    );
    return '$_temp0';
  }

  @override
  String runIntervalLess(String label) {
    return 'Less $label';
  }

  @override
  String runIntervalMore(String label) {
    return 'More $label';
  }

  @override
  String runIntervalTotal(String time) {
    return 'Programmed active time $time';
  }

  @override
  String get runIntervalsUse => 'Use these intervals';

  @override
  String get runIntervalsOff => 'Turn intervals off';

  @override
  String runPlanWarmup(String time) {
    return '$time warm-up';
  }

  @override
  String runPlanRepeats(int reps, String run, String walk) {
    return '$reps × run $run, walk $walk';
  }

  @override
  String runPlanCooldown(String time) {
    return '$time cool-down';
  }

  @override
  String get runPhaseWarmup => 'Warm-up';

  @override
  String get runPhaseRun => 'Run';

  @override
  String get runPhaseWalk => 'Walk';

  @override
  String get runPhaseCooldown => 'Cool-down';

  @override
  String runSpokenSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String runSpokenMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String runSpokenMinutesSeconds(String minutes, String seconds) {
    return '$minutes $seconds';
  }

  @override
  String runRoundOf(int round, int total) {
    return 'Round $round of $total';
  }

  @override
  String get runSkipPhase => 'Skip phase';

  @override
  String runTimeLeft(String time) {
    return '$time left';
  }

  @override
  String runNextPhase(String phase, String time) {
    return 'Next: $phase $time';
  }

  @override
  String runNextPhaseSaid(String phase) {
    return 'Next: $phase';
  }

  @override
  String get runIntervalsFinished => 'Intervals finished';

  @override
  String get runIntervalsStillRecording =>
      'Still recording. Keep going freely, or finish and review.';

  @override
  String get runContinueFreely => 'Continue freely';

  @override
  String get runFinishAndReview => 'Finish and review';

  @override
  String get runCueIntervalsDone =>
      'Intervals finished. Continue freely, or finish and review.';

  @override
  String get runCueIntervalsFinished => 'Intervals finished.';

  @override
  String runCueWarmup(String duration) {
    return 'Warm up: walk for $duration.';
  }

  @override
  String runCueRun(String duration) {
    return 'Run for $duration.';
  }

  @override
  String runCueFinalRun(String duration) {
    return 'Final round. Run for $duration.';
  }

  @override
  String runCueWalk(String duration) {
    return 'Walk and recover for $duration.';
  }

  @override
  String runCueCooldown(String duration) {
    return 'Cool down: walk for $duration.';
  }

  @override
  String runCueDistanceDone(String distance) {
    return '$distance completed.';
  }

  @override
  String runCueActiveTime(String time) {
    return 'Active time $time.';
  }

  @override
  String runCuePace(String pace) {
    return 'Avg. moving pace $pace.';
  }

  @override
  String runCueMinutesActive(int minutes) {
    return '$minutes min active.';
  }

  @override
  String runSaidKilometres(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kilometres',
      one: '1 kilometre',
    );
    return '$_temp0';
  }

  @override
  String runSaidMiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miles',
      one: '1 mile',
    );
    return '$_temp0';
  }

  @override
  String runSaidKilometresDecimal(String value) {
    return '$value kilometres';
  }

  @override
  String runSaidMilesDecimal(String value) {
    return '$value miles';
  }

  @override
  String runSaidActiveTime(String duration) {
    return 'Active time $duration.';
  }

  @override
  String runSaidPace(String unit, String duration) {
    String _temp0 = intl.Intl.selectLogic(unit, {
      'mi': 'Average moving pace $duration per mile.',
      'other': 'Average moving pace $duration per kilometre.',
    });
    return '$_temp0';
  }

  @override
  String runSaidMinutesActive(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes active.',
      one: '1 minute active.',
    );
    return '$_temp0';
  }

  @override
  String runVoicePreviewLine(String name) {
    return 'Hi, I\'m $name. I\'ll tell you when to run, when to walk, and how far you\'ve gone.';
  }

  @override
  String get runVoiceUpdates => 'Voice updates';

  @override
  String runVoiceUpdatesSubtitle(String guide, String name) {
    return '$name says interval changes, updates and personal bests aloud, in a voice installed on this phone. Nothing is sent anywhere.';
  }

  @override
  String get runVoiceUpdatesLabel => 'Updates';

  @override
  String get runVoiceUpdatesNone => 'None';

  @override
  String get runVoiceUpdatesDistance => 'Distance';

  @override
  String get runVoiceUpdatesTime => 'Time';

  @override
  String get runVoiceUpdatesExplain =>
      'Each update says the distance, the active time and the average moving pace (moving time ÷ distance), only once GPS has measured enough.';

  @override
  String get runVoiceField => 'Voice';

  @override
  String get runVoiceMissing =>
      'The voice chosen before is not installed or needs a connection: the phone\'s own voice is used.';

  @override
  String get runVoiceNoneForLanguage =>
      'No voice for this language that works offline is installed, so nothing is said aloud. Prompts still show on screen and vibration still works.';

  @override
  String get runVoiceOfflineOnly =>
      'Only voices that work without a connection are listed.';

  @override
  String get runVoicePhoneDefault => 'The phone\'s own voice';

  @override
  String get runVoicePreview => 'Preview voice';

  @override
  String get runVoiceVibrate => 'Vibrate at interval changes';

  @override
  String get runVoiceVibrateSubtitle =>
      'Also with the screen locked on Android. On iPhone, while GoHard is open.';

  @override
  String get runVoiceCountdown => 'Countdown';

  @override
  String get runVoiceCountdownSubtitle =>
      'A tick each second for the last three seconds of a phase.';

  @override
  String get runVoiceFooter =>
      'Interval changes are always shown on screen. These choices are kept on this phone.';

  @override
  String get runPersonalBests => 'Personal bests';

  @override
  String get runBestNotSet => 'Not set yet';

  @override
  String get runBestLongestRun => 'Longest run';

  @override
  String get runBestLongestWalk => 'Longest walk';

  @override
  String get runBestFastest1kRun => 'Fastest 1 km run';

  @override
  String get runBestFastest5kRun => 'Fastest 5 km run';

  @override
  String get runBestFastest1kWalk => 'Fastest 1 km walk';

  @override
  String get runBestsFootnote =>
      'From saved activities whose distance GPS measured. A fastest time is the quickest continuous stretch of that distance, timed from its start to its end; a pause or a GPS gap breaks a stretch. Typed or corrected distances do not count.';

  @override
  String runBestsUnchecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count earlier activities were saved before fastest times were kept and count only for distance, if measured.',
      one: '1 earlier activity was saved before fastest times were kept and counts only for distance, if measured.',
    );
    return '$_temp0';
  }

  @override
  String get runBestsNoneYet =>
      'None yet: they come from saved activities measured by GPS';

  @override
  String runBestPill(String label) {
    return 'Personal best · $label';
  }

  @override
  String runRecordLongest(String kind, String distance) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'your longest walk so far, $distance',
      'other': 'your longest run so far, $distance',
    });
    return '$_temp0';
  }

  @override
  String runRecordFastest(String kind, String benchmark, String time) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'your fastest $benchmark walk so far, $time',
      'other': 'your fastest $benchmark run so far, $time',
    });
    return '$_temp0';
  }

  @override
  String runRecordsTwo(String first, String second) {
    return '$first and $second';
  }

  @override
  String runRecordsThree(String first, String second, String third) {
    return '$first, $second and $third';
  }

  @override
  String runActivityWhen(String date, String year, String time) {
    return '$date, $year · $time';
  }

  @override
  String get runExportGpx => 'Export GPX';

  @override
  String get runDistanceNotRecorded => 'Distance not recorded';

  @override
  String get runDistanceTyped => 'Distance (typed)';

  @override
  String get runDistanceCorrected => 'Distance (corrected)';

  @override
  String get runTime => 'Time';

  @override
  String runTimeSaid(String duration) {
    return 'Time $duration';
  }

  @override
  String runElapsed(String time) {
    return 'Elapsed $time';
  }

  @override
  String get runElevationGainNotMeasured => 'Elevation gain not measured';

  @override
  String runElevationGain(String value) {
    return 'Elevation gain $value';
  }

  @override
  String get runTabOverview => 'Overview';

  @override
  String get runTabSplits => 'Splits';

  @override
  String get runTabCharts => 'Charts';

  @override
  String get runSyncPending => 'Saved on this phone, waiting to sync';

  @override
  String get runSyncReview => 'Needs your review in Me › Sync';

  @override
  String get runSyncSaved => 'Saved to your account';

  @override
  String get runRouteSyncSaved => 'Route saved to your account';

  @override
  String get runRouteSyncNone => 'No route to sync';

  @override
  String get runRouteSyncKept => 'Route kept on the phone that recorded it';

  @override
  String get runRouteSyncAttention => 'Route upload needs attention';

  @override
  String get runRouteSyncWaiting => 'Route on this phone, waiting to upload';

  @override
  String get runAvgSpeed => 'Avg. speed';

  @override
  String get runElevationLoss => 'Elevation loss';

  @override
  String get runMeasuredByGps => 'Measured by GPS';

  @override
  String get runGpsPointsUsed => 'GPS points used';

  @override
  String runGpsPointsRejected(String points, int count) {
    return '$points ($count left out as inaccurate)';
  }

  @override
  String get runGaps => 'Gaps';

  @override
  String runGapsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stretch(es) without GPS, not counted',
    );
    return '$_temp0';
  }

  @override
  String get runBeforeRoutes => 'Before routes were kept';

  @override
  String runBeforeRoutesValue(String distance) {
    return '$distance with no route';
  }

  @override
  String get runSummary => 'Summary';

  @override
  String get runRoute => 'Route';

  @override
  String get runPartialRoute =>
      'Part of this route was not recorded. Distance and pace cover only what GPS measured.';

  @override
  String runIntervalsRunsCompleted(int done, int total) {
    return '$done of $total runs completed';
  }

  @override
  String runEndedEarly(String time) {
    return 'Ended early (planned $time)';
  }

  @override
  String get runNoSplits => 'No splits: there is no GPS distance.';

  @override
  String get runSelectSplit => 'Select a split to see it on the map.';

  @override
  String runSplitLast(int number, String distance) {
    return '$number · last $distance';
  }

  @override
  String get runPartialSplit => 'Partial split';

  @override
  String get runShownOnMap => 'Shown on the map';

  @override
  String get runNoCharts => 'No charts: no GPS route was recorded.';

  @override
  String get runChartPace => 'Pace';

  @override
  String runChartPaceNote(String step) {
    return 'Every $step; faster is higher. Breaks are gaps or pauses.';
  }

  @override
  String get runChartPaceTooShort => 'Too little distance for a pace chart.';

  @override
  String get runChartElevation => 'Elevation';

  @override
  String get runGainNotMeasured => 'Gain not measured';

  @override
  String runGainShort(String value) {
    return '$value gain';
  }

  @override
  String get runNoAltitude =>
      'This phone did not report altitude precise enough to chart.';

  @override
  String runChartSaid(String from, String to, String distance) {
    return 'Chart from $from to $to over $distance';
  }

  @override
  String get runSaveChanges => 'Save changes';

  @override
  String get runEditSaveFailed =>
      'That could not be saved on this phone. Your changes are still here.';

  @override
  String runDeleteTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Delete this walk?',
      'other': 'Delete this run?',
    });
    return '$_temp0';
  }

  @override
  String runDeleteBody(String kind, String date) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk':
          'The walk from $date and its route are deleted from this phone and your account.',
      'other':
          'The run from $date and its route are deleted from this phone and your account.',
    });
    return '$_temp0';
  }

  @override
  String runDeleteAction(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Delete walk',
      'other': 'Delete run',
    });
    return '$_temp0';
  }

  @override
  String get runDeleteFailed =>
      'It could not be deleted on this phone. Nothing changed.';

  @override
  String get runGpxFailed => 'The GPX file could not be made on this phone.';

  @override
  String get runNoRouteLegacy =>
      'Recorded before GoHard kept routes. Its time and distance are as they were saved.';

  @override
  String get runNoRouteManual => 'Timed without GPS; the distance was typed.';

  @override
  String runNoRoutePositions(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'No GPS position was recorded for this walk.',
      'other': 'No GPS position was recorded for this run.',
    });
    return '$_temp0';
  }

  @override
  String get runFilterAll => 'All';

  @override
  String runInProgress(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Walk in progress',
      'other': 'Run in progress',
    });
    return '$_temp0';
  }

  @override
  String runStartedOn(String date) {
    return 'Started $date';
  }

  @override
  String get runThisWeek => 'This week';

  @override
  String get runThisMonth => 'This month';

  @override
  String runHistoryEmpty(String filter) {
    String _temp0 = intl.Intl.selectLogic(filter, {
      'run': 'No runs yet',
      'walk': 'No walks yet',
      'other': 'No activities yet',
    });
    return '$_temp0';
  }

  @override
  String runHistoryEmptyBody(String filter) {
    String _temp0 = intl.Intl.selectLogic(filter, {
      'run': 'Saved runs appear here, every one of them.',
      'walk': 'Saved walks appear here, every one of them.',
      'other': 'Saved runs and walks appear here, every one of them.',
    });
    return '$_temp0';
  }

  @override
  String get runStartOne => 'Start one';

  @override
  String runTotalsSaid(
    String label,
    int count,
    String distance,
    String duration,
  ) {
    return '$label: $count saved, $distance, $duration active';
  }

  @override
  String runTotalsSaidPartial(
    String label,
    int count,
    String distance,
    String duration,
  ) {
    return '$label: $count saved, $distance where distance is known, $duration active';
  }

  @override
  String runTotalsLine(int count, String duration) {
    return '$count · $duration active';
  }

  @override
  String runNotificationTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'GoHard is recording your walk',
      'other': 'GoHard is recording your run',
    });
    return '$_temp0';
  }

  @override
  String runNotificationText(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Open GoHard to pause or finish. Location is used only for this walk.',
      'other':
          'Open GoHard to pause or finish. Location is used only for this run.',
    });
    return '$_temp0';
  }

  @override
  String get runNotificationChannel => 'Run / Walk recording';

  @override
  String get runMapRoute => 'Route map';

  @override
  String get runMapFollowing => 'Following your position';

  @override
  String get runMapRecenter => 'Recenter';

  @override
  String get runMapFit => 'Fit route';

  @override
  String get runMapZoomIn => 'Zoom in';

  @override
  String get runMapZoomOut => 'Zoom out';

  @override
  String get runMapNoTiles => 'Route drawn without a map';

  @override
  String get runMapExpand => 'Expand map';

  @override
  String get stepsTitle => 'Steps';

  @override
  String get stepsCount => 'Count steps';

  @override
  String get stepsCountSubtitle =>
      'With this phone\'s motion sensor: during a run or walk, and today\'s total. Walking without your phone is not counted.';

  @override
  String get stepsMotionNotAllowed => 'Motion access is not allowed yet.';

  @override
  String get stepsMotionBlocked =>
      'Motion access is off for GoHard. Turn it on in the phone\'s settings.';

  @override
  String get stepsNoCounter =>
      'This phone has no step counter. Run / Walk records everything else.';

  @override
  String get stepsAllow => 'Allow';

  @override
  String get stepsSettings => 'Settings';

  @override
  String get stepsGoalLabel => 'Daily steps goal (optional)';

  @override
  String get stepsGoalHelper => 'Your own number. Leave it blank for none.';

  @override
  String get stepsOnToday => 'Show Steps on Today';

  @override
  String get stepsOnTodaySubtitle =>
      'Only what Today shows. Counting and access are not changed.';

  @override
  String stepsFooter(String source) {
    return 'Today\'s total is read from $source and stays on this phone: it is never sent to your account. The steps of a run or walk are saved with it and sync with your account. The two are never added together.';
  }

  @override
  String get stepsOff => 'Steps off';

  @override
  String get stepsOn => 'Steps on';

  @override
  String get stepsChecking => 'Checking…';

  @override
  String get stepsSimulated => 'Simulated (test build)';

  @override
  String get stepsCounted => 'Counted with this phone';

  @override
  String get stepsMotionNeeded => 'Motion access needed';

  @override
  String get stepsMotionOff => 'Motion access off';

  @override
  String get stepsNotOnPhone => 'Not on this phone';

  @override
  String get stepsEnable => 'Enable';

  @override
  String stepsPartOfTime(String steps) {
    return '$steps (part of the time)';
  }

  @override
  String get stepsNotCountedMotion => 'Not counted: motion access is off';

  @override
  String get stepsNotCountedSensor => 'Not counted: no step sensor';

  @override
  String get stepsNotCounted => 'Not counted';

  @override
  String get stepsNotRecorded => 'Not recorded';

  @override
  String get stepsDailyUnavailableIos => 'This iPhone cannot count steps.';

  @override
  String get stepsDailyUnavailableAndroid =>
      'Daily steps on Android come from Health Connect, which is not available on this phone.';

  @override
  String get stepsSourceIphone => 'This iPhone';

  @override
  String get stepsSourceSimulated => 'This phone (simulated)';

  @override
  String get shellPassCardOverline => 'Training plan';

  @override
  String shellPassCardSemantics(
    String shape,
    String title,
    String week,
    String count,
    String caption,
    String percent,
  ) {
    String _temp0 = intl.Intl.selectLogic(shape, {
      'weekPercent': '$title. $week. $count $caption, $percent.',
      'week': '$title. $week. $count $caption.',
      'percent': '$title. $count $caption, $percent.',
      'other': '$title. $count $caption.',
    });
    return '$_temp0';
  }

  @override
  String get shellUpdateTitle => 'Update GoHard to continue';

  @override
  String get shellUpdateBody =>
      'This version of the app is too old for your account\'s server, so it has stopped syncing.';

  @override
  String get shellUpdateSavedHere =>
      'Everything you saved on this phone is still here.';

  @override
  String shellUpdateSavedPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Everything you saved on this phone is still here, including $count changes waiting to sync. They will sync after you update.',
      one: 'Everything you saved on this phone is still here, including 1 change waiting to sync. They will sync after you update.',
    );
    return '$_temp0';
  }

  @override
  String get shellUpdateCheckAgain => 'Check again';

  @override
  String get shellConfigTitle => 'Not configured';

  @override
  String get shellConfigBody =>
      'This build has no default server on purpose. Start it with the development script so it knows which API to use.';

  @override
  String get shellCantSyncDetail =>
      'The last attempt to reach your account did not get through. That can be this phone\'s connection or the server.';

  @override
  String shellReviewBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count saved changes need your review. Nothing was lost. Tap to review.',
      one: '1 saved change needs your review. Nothing was lost. Tap to review.',
    );
    return '$_temp0';
  }

  @override
  String get authFillEveryField => 'Fill in every field to continue.';

  @override
  String get authCreateAccountTitle => 'Create account';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authRegisterLead =>
      'Know what to do next, and keep a record of what you actually did.';

  @override
  String get authSignInLead => 'Sign in to pick up where you left off.';

  @override
  String get authTagline => 'Plan it.\nRecord it.\nKeep going.';

  @override
  String get authNoticeExpired =>
      'Your sign-in expired. Sign in again to keep syncing; everything saved on this phone is still here.';

  @override
  String get authNoticeAccountDeleted =>
      'Your account and its data were deleted.';

  @override
  String get authNameLabel => 'Your name';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authCreateAccountButton => 'Create account';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authToggleToSignIn => 'I already have an account · Sign in';

  @override
  String get authToggleToRegister => 'New to GoHard? Create account';

  @override
  String get setupCoachTitle => 'Choose your coach';

  @override
  String get setupCoachSubtitle =>
      'Leon or Leona: the same help either way, only the look changes. You can change this later in Appearance.';

  @override
  String get setupNotNow => 'Not now';

  @override
  String setupCoachHello(String name) {
    return 'I\'m $name. Tap me on any screen when you\'d like a hand.';
  }

  @override
  String get setupHi => 'Hi!';

  @override
  String setupHiName(String name) {
    return 'Hi $name!';
  }

  @override
  String get setupFeaturesTitle => 'Optional features';

  @override
  String get setupFeaturesSubtitle =>
      'Turn on what you want now, or later in Me. The phone asks for access only when you use a feature that needs it.';

  @override
  String get setupWeatherTitle => 'Weather on Today';

  @override
  String get setupWeatherSubtitle =>
      'Use your approximate location, or choose a city without sharing it.';

  @override
  String get setupRemindersTitle => 'Workout reminders';

  @override
  String get setupRemindersSubtitle =>
      'On days with a planned workout. Notifications are asked for when you turn this on.';

  @override
  String get setupBarcodeTitle => 'Barcode scanning';

  @override
  String get setupBarcodeSubtitle =>
      'Ready in Eat. The camera is asked for the first time you scan.';

  @override
  String get setupGpsTitle => 'GPS runs';

  @override
  String get setupGpsSubtitle =>
      'Ready on Today. Location is asked for when you start a run.';

  @override
  String get setupPermissionsFootnote =>
      'Anything you allow or refuse can be changed later in the phone\'s Settings; Me › Phone permissions shows what is allowed now.';

  @override
  String setupStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String todayGreetingNamed(String part, String name) {
    String _temp0 = intl.Intl.selectLogic(part, {
      'morning': 'Good morning, $name!',
      'afternoon': 'Good afternoon, $name!',
      'other': 'Good evening, $name!',
    });
    return '$_temp0';
  }

  @override
  String todayGreetingPlain(String part) {
    String _temp0 = intl.Intl.selectLogic(part, {
      'morning': 'Good morning!',
      'afternoon': 'Good afternoon!',
      'other': 'Good evening!',
    });
    return '$_temp0';
  }

  @override
  String get todayLineSaved => 'Your workout is saved. Nice work.';

  @override
  String get todayLineResume => 'Your workout is ready to resume.';

  @override
  String todayLineDue(String title) {
    return '$title is planned today.';
  }

  @override
  String get todayLineFinished => 'Today\'s workout is done.';

  @override
  String get todayLinePartial => 'Today\'s workout is saved.';

  @override
  String get todayLineSkipped => 'Today\'s workout is skipped.';

  @override
  String get todayLineRest => 'A planned rest day today.';

  @override
  String get todayLinePaused => 'Your plan is paused today.';

  @override
  String get todayCoachStepsIntro =>
      'Want to track your daily movement? Enable steps here.';

  @override
  String get todayCoachEnableSteps => 'Enable steps';

  @override
  String get todayCoachNeedHand => 'Need a hand with today?';

  @override
  String get todaySkyNeedsPermission => 'Location not allowed yet';

  @override
  String get todaySkyDenied => 'Location not allowed';

  @override
  String get todaySkyServicesOff => 'Location is off';

  @override
  String get todaySkyTimeout => 'No location in time';

  @override
  String get todaySkyOffline => 'Weather could not be reached';

  @override
  String get todaySkyUnavailable => 'Weather unavailable';

  @override
  String get todaySkyNoCity => 'Choose a city';

  @override
  String todaySkyWeather(String temperature, String condition) {
    return '$temperature · $condition';
  }

  @override
  String todaySkyScenic(String reason) {
    return 'Scenic view · $reason';
  }

  @override
  String get todaySkyHint => 'Opens the Today background setting';

  @override
  String get todayCantSyncDetailNothingWaiting =>
      'The last attempt to reach your account did not get through. That can be this phone\'s connection or the server. You are seeing what is saved on this phone. Nothing is waiting to sync.';

  @override
  String get todayCantSyncDetailWaiting =>
      'The last attempt to reach your account did not get through. That can be this phone\'s connection or the server. You are seeing what is saved on this phone. Your changes are kept here and sync by themselves once the account answers.';

  @override
  String get todayTrainingError =>
      'Your training could not be read from this phone. Pull down to try again.';

  @override
  String get todayTrainingLoading => 'Loading your training…';

  @override
  String get todayStatusInProgress => 'In progress';

  @override
  String get todayStatusCompleted => 'Completed';

  @override
  String get todayStatusPartly => 'Partly completed';

  @override
  String get todayStatusSkipped => 'Skipped today';

  @override
  String get todayStatusMissed => 'Missed';

  @override
  String get todayStatusPaused => 'Paused';

  @override
  String get todayStatusDue => 'Due today';

  @override
  String get todayStatusSavedForLater => 'Saved for later';

  @override
  String get todayStatusRestDay => 'Planned rest day';

  @override
  String get todayStatusPlanPaused => 'Plan paused';

  @override
  String todayStatusStarts(String date) {
    return 'Starts $date';
  }

  @override
  String get todayStatusBlockReview => 'Block ready to review';

  @override
  String get todayStatusDraftReview => 'Your plan is ready to review';

  @override
  String get todayNextNone => 'No further workout is scheduled in this block.';

  @override
  String todayNextRotation(String title) {
    return 'Next in your rotation: $title.';
  }

  @override
  String todayNextRotationDay(String title, String day) {
    return 'Next in your rotation: $title · $day.';
  }

  @override
  String todayNext(String title, String day) {
    return 'Next: $title · $day.';
  }

  @override
  String get todayDetailsLink => 'Details';

  @override
  String get todayDetailsSaid => 'Workout details';

  @override
  String get todayWorkoutLabel => 'Workout';

  @override
  String todayExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
      one: '1 exercise',
    );
    return '$_temp0';
  }

  @override
  String todayPlannedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planned sets',
    );
    return '$_temp0';
  }

  @override
  String todayRotationStep(int position, int total) {
    return 'Step $position of $total';
  }

  @override
  String todaySessionNumber(int number) {
    return 'Session $number';
  }

  @override
  String todayWeekNumber(int number) {
    return 'Week $number';
  }

  @override
  String todayMinutesPlanned(int minutes) {
    return '$minutes min planned';
  }

  @override
  String todaySetsRingLabel(int counted, int planned) {
    return '$counted of $planned planned sets recorded';
  }

  @override
  String todayOfSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'of $count sets',
    );
    return '$_temp0';
  }

  @override
  String get todayRecordedCaption => 'recorded';

  @override
  String todaySetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets recorded',
      one: '1 set recorded',
    );
    return '$_temp0';
  }

  @override
  String get todayNoExercise => 'No exercise added yet';

  @override
  String get todayResumeWorkout => 'Resume workout';

  @override
  String get todayStartWorkout => 'Start workout';

  @override
  String get todayResolvedSkipped =>
      'Skipped: nothing was recorded for it and it does not count as training.';

  @override
  String get todayResolvedFinished => 'Finished: all planned sets recorded.';

  @override
  String get todayResolvedPartial =>
      'Finished partially: some planned work was not recorded.';

  @override
  String get todayBlockLast => 'That was the last workout of this block.';

  @override
  String get todayUnskipSaved => 'No longer skipped.';

  @override
  String get todayUndoSkip => 'Undo skip';

  @override
  String get todayReviewBlock => 'Review this block';

  @override
  String get todayTrainNow => 'Train this now';

  @override
  String get todayViewPlan => 'View plan';

  @override
  String todayAlsoToday(String status) {
    return 'Also today · $status';
  }

  @override
  String todayMissedUnresolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count earlier workouts are unresolved',
      one: '1 earlier workout is unresolved',
    );
    return '$_temp0';
  }

  @override
  String get todayRestDayTitle => 'Rest day';

  @override
  String get todayRestChosen =>
      'You chose to rest today. Nothing was skipped and your rotation waits for you.';

  @override
  String todayRestMissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count earlier workouts are unresolved; move or skip them when you choose.',
      one: '1 earlier workout is unresolved; move or skip it when you choose.',
    );
    return '$_temp0';
  }

  @override
  String get todayResolveMissed => 'Resolve missed training';

  @override
  String get todayTrainToday => 'Train today';

  @override
  String get todayPausedText =>
      'No workouts are expected while the plan is paused, and nothing counts as missed.';

  @override
  String get todayResumePlan => 'Resume plan';

  @override
  String todayStartsLaterText(String date) {
    return 'Your plan begins on $date. Nothing is due before then.';
  }

  @override
  String get todayBlockReviewText =>
      'This block has reached its end or has nothing left to do. Review what was actually recorded and choose what comes next.';

  @override
  String get todayDraftText =>
      'This draft has not started. Nothing is scheduled until you start it.';

  @override
  String get todayReviewPlan => 'Review your plan';

  @override
  String get todayNoPlanTitle => 'No active plan';

  @override
  String get todayNoPlanText =>
      'Start from a familiar split or build your own and review it before you commit, or just train manually today.';

  @override
  String get todayCreatePlan => 'Create my plan';

  @override
  String get todayStartManual => 'Start a manual workout';

  @override
  String todayParkedSubtitle(String date) {
    return 'Saved for later · started $date';
  }

  @override
  String get todayManualWorkout => 'Manual workout';

  @override
  String get todayPlannedWorkout => 'Planned workout';

  @override
  String todayPlannedWorkoutFrom(String date) {
    return 'Planned workout from $date';
  }

  @override
  String get todayUnderOneMinute => 'Under 1 min';

  @override
  String todayActivityPaused(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Walk paused',
      'other': 'Run paused',
    });
    return '$_temp0';
  }

  @override
  String todayActivityInterrupted(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Walk interrupted',
      'other': 'Run interrupted',
    });
    return '$_temp0';
  }

  @override
  String todayActivityNotSaved(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Walk not saved yet',
      'other': 'Run not saved yet',
    });
    return '$_temp0';
  }

  @override
  String todayActivityInProgress(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Walk in progress',
      'other': 'Run in progress',
    });
    return '$_temp0';
  }

  @override
  String todayActivityCompleted(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Walk completed',
      'other': 'Run completed',
    });
    return '$_temp0';
  }

  @override
  String todayStartedOn(String date) {
    return 'Started $date';
  }

  @override
  String get todayStartedToday => 'Started today';

  @override
  String get todayCompletedWhen => 'today';

  @override
  String get todayRunResume => 'Resume';

  @override
  String get todayRunStartNew => 'Start new';

  @override
  String get todayRunStart => 'Start';

  @override
  String get todayNoRunWalk => 'No run or walk today';

  @override
  String get todayRunWalkLabel => 'Run / Walk';

  @override
  String get todayStepsLabel => 'Steps';

  @override
  String get todayStepsTrack => 'Track your steps';

  @override
  String get todayStepsCountWithPhone => 'Count with your phone.';

  @override
  String get todayStepsEnable => 'Enable';

  @override
  String get todayStepsReading => 'Reading steps';

  @override
  String todayStepsUpdated(String time) {
    return 'Updated $time';
  }

  @override
  String get todayStepsSetGoal => 'Set a goal';

  @override
  String get todayStepsEditGoal => 'Edit goal';

  @override
  String get todayStepsSetGoalSaid => 'Set a steps goal';

  @override
  String get todayStepsEditGoalSaid => 'Edit steps goal';

  @override
  String get todayStepsNone => 'No steps recorded today';

  @override
  String get todayStepsBlocked => 'Access is off. Allow it in Settings.';

  @override
  String get todayStepsAllowHint => 'Allow access to see today\'s steps.';

  @override
  String get todayStepsSettings => 'Settings';

  @override
  String get todayStepsAllow => 'Allow';

  @override
  String get todayStepsFailed => 'Could not read steps just now.';

  @override
  String get todayStepsOffSaid =>
      'Steps. Track your steps: count with your phone.';

  @override
  String todayStepsSaid(String value, String details) {
    return 'Steps today: $value. $details';
  }

  @override
  String get todayStepsNotKnown => 'not known';

  @override
  String todayStepsOpens(String said) {
    return '$said Opens Steps.';
  }

  @override
  String todayStepsOfGoal(String goal) {
    return 'of $goal';
  }

  @override
  String get todayStepsGoalLabel => 'Steps goal';

  @override
  String get todayStepsSimulated => 'Simulated (test build)';

  @override
  String get todayNutritionLabel => 'Nutrition';

  @override
  String get todayFoodError =>
      'Today\'s food could not be read from this phone.';

  @override
  String get todayLoading => 'Loading…';

  @override
  String get todayNoFood => 'No food logged today';

  @override
  String todayDailyGoal(String goals) {
    return 'Your daily goal: $goals';
  }

  @override
  String get todayLogFood => 'Log food';

  @override
  String get todayJournal => 'Journal';

  @override
  String get todayJournalSaid => 'Food journal';

  @override
  String get todayRecordedTodayOverline => 'Recorded today';

  @override
  String todaySetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String weatherCondition(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'c0': 'Clear sky',
      'c1': 'Mainly clear',
      'c2': 'Partly cloudy',
      'c3': 'Overcast',
      'c45': 'Fog',
      'c48': 'Depositing rime fog',
      'c51': 'Light drizzle',
      'c53': 'Moderate drizzle',
      'c55': 'Dense drizzle',
      'c56': 'Light freezing drizzle',
      'c57': 'Dense freezing drizzle',
      'c61': 'Slight rain',
      'c63': 'Moderate rain',
      'c65': 'Heavy rain',
      'c66': 'Light freezing rain',
      'c67': 'Heavy freezing rain',
      'c71': 'Slight snowfall',
      'c73': 'Moderate snowfall',
      'c75': 'Heavy snowfall',
      'c77': 'Snow grains',
      'c80': 'Slight rain showers',
      'c81': 'Moderate rain showers',
      'c82': 'Violent rain showers',
      'c85': 'Slight snow showers',
      'c86': 'Heavy snow showers',
      'c95': 'Thunderstorm',
      'c96': 'Thunderstorm with slight hail',
      'c97': 'Heavy thunderstorm',
      'c99': 'Thunderstorm with heavy hail',
      'other': 'Weather',
    });
    return '$_temp0';
  }

  @override
  String weatherFamily(String family) {
    String _temp0 = intl.Intl.selectLogic(family, {
      'clear': 'Clear',
      'partly': 'Partly cloudy',
      'cloudy': 'Overcast',
      'fog': 'Fog',
      'rain': 'Rain',
      'snow': 'Snow',
      'storm': 'Thunderstorm',
      'other': 'Weather',
    });
    return '$_temp0';
  }

  @override
  String weatherTemperatureC(int degrees) {
    return '$degrees°C';
  }

  @override
  String weatherTemperatureF(int degrees) {
    return '$degrees°F';
  }

  @override
  String get weatherFallbackNoAnswer => 'No weather yet';

  @override
  String get weatherFallbackOtherPlace => 'Weather is for another place';

  @override
  String get weatherFallbackStale => 'Weather is out of date';

  @override
  String get weatherFallbackAhead => 'Weather time is ahead';

  @override
  String get weatherFallbackUnknownCode => 'Unrecognised weather';

  @override
  String get weatherFallbackNoArt => 'No scene for this weather';

  @override
  String get weatherBackgroundScenic => 'Scenic';

  @override
  String get weatherBackgroundWeather => 'Weather';

  @override
  String get weatherBackgroundPlain => 'Plain';

  @override
  String get weatherSummaryAutomatic => 'Weather · Automatic';

  @override
  String weatherSummaryCity(String city) {
    return 'Weather · $city';
  }

  @override
  String get weatherBackgroundTitle => 'Today background';

  @override
  String get weatherBackgroundSubtitle =>
      'Only the top of Today uses it. Changes apply immediately.';

  @override
  String get weatherBackgroundScenicDetail =>
      'A decorative dusk scene. Works without a connection.';

  @override
  String get weatherBackgroundWeatherDetail =>
      'A scene for the current weather where you choose. Dusk when none is available.';

  @override
  String get weatherBackgroundPlainDetail => 'The plain page colour.';

  @override
  String get weatherLocationSection => 'Location';

  @override
  String get weatherAutomatic => 'Automatic';

  @override
  String get weatherAutomaticDetail =>
      'This phone\'s approximate location, about 10 km';

  @override
  String get weatherSelectedCity => 'Selected city';

  @override
  String get weatherSearchForCity => 'Search for a city';

  @override
  String get weatherChangeCity => 'Change city';

  @override
  String get weatherNowSection => 'Now';

  @override
  String get weatherConsentTitle => 'Use your approximate location?';

  @override
  String get weatherConsentBody =>
      'GoHard uses this phone\'s location only to choose a weather scene for the top of Today. It is rounded to about 10 km before it leaves the phone and is not kept as a history. You can choose a city instead.';

  @override
  String get weatherNotNow => 'Not now';

  @override
  String get weatherChooseCity => 'Choose a city';

  @override
  String get weatherIssueNeedsPermission =>
      'Automatic needs permission to use this phone\'s approximate location.';

  @override
  String get weatherUseMyLocation => 'Use my location';

  @override
  String get weatherIssueDenied =>
      'Location was not allowed. Choose a city, or try again.';

  @override
  String get weatherIssueDeniedForever =>
      'Location is turned off for GoHard. Allow it in Settings, or choose a city.';

  @override
  String get weatherOpenSettings => 'Open Settings';

  @override
  String get weatherIssueServicesOff =>
      'Location is turned off on this phone. Turn it on, or choose a city.';

  @override
  String get weatherLocationSettings => 'Location settings';

  @override
  String get weatherIssueTimeout =>
      'This phone did not find its location in time. Dusk shows until it does.';

  @override
  String get weatherIssueNoCity => 'Choose a city to see its weather.';

  @override
  String get weatherIssueUnreachable =>
      'Weather could not be reached just now. Dusk shows until it can.';

  @override
  String get weatherApproximateLocation => 'Your approximate location';

  @override
  String weatherAsOf(String time) {
    return 'As of $time';
  }

  @override
  String weatherAsOfPlace(String time, String place) {
    return 'As of $time · $place';
  }

  @override
  String get weatherChecking => 'Checking the weather…';

  @override
  String get weatherNone =>
      'No current weather. Showing the decorative dusk scene.';

  @override
  String get weatherCreditMet =>
      'Data from MET Norway (api.met.no), CC BY 4.0: creativecommons.org/licenses/by/4.0. Its weather symbols are converted to WMO codes here.';

  @override
  String get weatherCreditOpenMeteo =>
      'Weather data by Open-Meteo.com, CC BY 4.0: creativecommons.org/licenses/by/4.0.';

  @override
  String get weatherCreditDefault =>
      'Weather data by Open-Meteo.com, or MET Norway when it is busy (CC BY 4.0).';

  @override
  String get weatherModelData => 'Conditions are model data.';

  @override
  String get weatherIllustrative =>
      'Scenes are illustrative: not a forecast or a view of your location.';

  @override
  String get weatherBasisTitle => 'What the scene is based on';

  @override
  String get weatherNoCityChosen => 'No city chosen';

  @override
  String get weatherAutomaticBasis => 'Automatic (this phone, about 10 km)';

  @override
  String get weatherBasisLastAttempt => 'Last attempt';

  @override
  String get weatherBasisScene => 'Scene';

  @override
  String weatherBasisSceneWeather(String key) {
    return '$key (weather)';
  }

  @override
  String weatherBasisSceneScenic(String reason) {
    return 'scenic view · $reason';
  }

  @override
  String get weatherBasisCondition => 'Condition';

  @override
  String get weatherBasisSource => 'Source';

  @override
  String get weatherBasisDayNight => 'Day or night there';

  @override
  String get weatherDay => 'day';

  @override
  String get weatherNight => 'night';

  @override
  String get weatherNotGiven => 'not given';

  @override
  String get weatherBasisValid => 'Valid';

  @override
  String weatherValidAt(String time, String ago) {
    return '$time ($ago)';
  }

  @override
  String get weatherBasisTimezone => 'Time zone there';

  @override
  String get weatherBasisFetched => 'Fetched';

  @override
  String get weatherBasisKeptFor => 'Kept for';

  @override
  String get weatherKeptThisCity => 'this city';

  @override
  String get weatherKeptOther => 'another location setting';

  @override
  String get weatherJustNow => 'just now';

  @override
  String weatherMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
    );
    return '$_temp0';
  }

  @override
  String weatherHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h ago',
    );
    return '$_temp0';
  }

  @override
  String get weatherTypeTwoLetters => 'Type at least two letters.';

  @override
  String get weatherSearching => 'Searching…';

  @override
  String weatherNoPlaces(String query) {
    return 'No places found for \"$query\".';
  }

  @override
  String get weatherCitySearchFailed =>
      'Cities could not be searched just now.';

  @override
  String get weatherCityLabel => 'City';

  @override
  String get weatherSearchTooltip => 'Search';

  @override
  String todayOccasionStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'inProgress': 'In progress',
      'finished': 'Completed',
      'partial': 'Partial',
      'skipped': 'Skipped',
      'missed': 'Missed',
      'due': 'Due',
      'upcoming': 'Planned',
      'other': 'Paused',
    });
    return '$_temp0';
  }

  @override
  String get shellCantSyncLabel => 'Can\'t sync right now';

  @override
  String shellWaitingToSync(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String shellCantSyncWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Can\'t sync right now · $count changes waiting to sync',
      one: 'Can\'t sync right now · 1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String workoutTargetSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String workoutTargetRepRange(String range) {
    return '$range reps';
  }

  @override
  String workoutTargetReps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reps',
    );
    return '$_temp0';
  }

  @override
  String get workoutNoTarget => 'No target';

  @override
  String get workoutOutcomeFull => 'Finished';

  @override
  String get workoutOutcomePartial => 'Finished partially';

  @override
  String get workoutOutcomeNoData => 'No training logged';

  @override
  String get workoutOutcomeManual => 'Recorded';

  @override
  String get workoutOutcomeOpen => 'In progress';

  @override
  String get workoutSetBodyweight => 'Bodyweight';

  @override
  String workoutSetLoadReps(String load, int reps) {
    return '$load × $reps';
  }

  @override
  String workoutSetLoadRepsTime(String load, int reps, String time) {
    return '$load × $reps · $time';
  }

  @override
  String get workoutInvalidLoadFormat =>
      'Enter the load as a number of zero or more, or leave it blank for bodyweight.';

  @override
  String get workoutInvalidLoadRange => 'Enter a load of zero or more.';

  @override
  String get workoutInvalidNothingDone =>
      'Enter the reps or time you actually did.';

  @override
  String get workoutInvalidOutOfRange => 'That value is out of range.';

  @override
  String get workoutInvalidHasSets => 'Remove its recorded sets first.';

  @override
  String get workoutAllWorkoutsLink => 'All workouts';

  @override
  String get workoutSelectSaveFailed =>
      'The change of movement could not be saved on this phone. Your sets and entry are unchanged; try again.';

  @override
  String get workoutUseLastConfirmTitle => 'Replace what you typed?';

  @override
  String get workoutUseLastConfirmBody =>
      'The entry for this set will show last time\'s values instead. Nothing is recorded until you tap Record set.';

  @override
  String get workoutUseLastValues => 'Use last values';

  @override
  String workoutUseLastValuesSemantic(String set) {
    return 'Use last values: $set';
  }

  @override
  String get workoutUseLastKeepMine => 'Keep mine';

  @override
  String workoutSetSavedSnack(String set) {
    return 'Saved on this phone: $set';
  }

  @override
  String get workoutUndo => 'Undo';

  @override
  String get workoutSetNotSaved =>
      'Not saved. Your entry is still here. Tap again to retry.';

  @override
  String get workoutEditSetTitle => 'Edit set';

  @override
  String get workoutLoadLabel => 'Load';

  @override
  String get workoutSecondsLabel => 'Seconds';

  @override
  String get workoutRepsLabel => 'Reps';

  @override
  String get workoutTimeLabel => 'Time';

  @override
  String get workoutSecondsUnit => 's';

  @override
  String workoutFieldWithUnit(String label, String unit) {
    return '$label ($unit)';
  }

  @override
  String get workoutDeleteSet => 'Delete set';

  @override
  String get workoutSetRemoved => 'Set removed.';

  @override
  String get workoutSetEditFailed =>
      'That change could not be saved on this phone. The set is unchanged.';

  @override
  String get workoutFinishNoDataTitle => 'No training logged';

  @override
  String get workoutFinishTitle => 'Finish workout?';

  @override
  String get workoutFinishNoDataBodyPlanned =>
      'No set has been recorded. You can save this as a record without training: it gives no training credit and leaves the planned workout available. Time on the clock alone is not training.';

  @override
  String get workoutFinishNoDataBodyManual =>
      'No set has been recorded. You can save this as a record without training: it gives no training credit. Time on the clock alone is not training.';

  @override
  String workoutFinishSummary(int sets, int exercises) {
    String _temp0 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    String _temp1 = intl.Intl.pluralLogic(
      exercises,
      locale: localeName,
      other: '$exercises movements',
      one: '1 movement',
    );
    return '$_temp0 across $_temp1 recorded.';
  }

  @override
  String workoutFinishMissing(String names) {
    return 'Not fully recorded: $names. You can still finish; it will be saved as partial.';
  }

  @override
  String get workoutListSeparator => ', ';

  @override
  String get workoutKeepTraining => 'Keep training';

  @override
  String get workoutSaveWithoutTraining => 'Save without training';

  @override
  String get workoutFinishButton => 'Finish workout';

  @override
  String get workoutFinishFailed =>
      'The workout could not be finished on this phone. Nothing changed. Try again.';

  @override
  String get workoutAddMovement => 'Add a movement';

  @override
  String workoutReplaceMovementTitle(String name) {
    return 'Replace $name';
  }

  @override
  String get workoutRemoveTitle => 'Remove this workout?';

  @override
  String workoutRemoveOpenBody(String title) {
    return 'This removes \"$title\" and every set recorded in it. This is the only way a workout is ever removed; it is never cleaned up automatically.';
  }

  @override
  String get workoutRemoveAction => 'Remove workout';

  @override
  String get workoutMissingTitle => 'This workout is not on this phone';

  @override
  String get workoutMissingBody =>
      'It may have been removed. Nothing else changed.';

  @override
  String get workoutHelpSemantic => 'Help with recording this workout';

  @override
  String get workoutHelpTitle => 'Recording sets';

  @override
  String get workoutHelpBody =>
      'Record each set as you finish it; the rest timer then starts on its own. Last time is what you actually did before, and Use last values only fills the entry. Save for later keeps everything.';

  @override
  String get workoutOptionsTooltip => 'Workout options';

  @override
  String get workoutReplaceThisMovement => 'Replace this movement';

  @override
  String get workoutRemoveThisMovement => 'Remove this movement';

  @override
  String get workoutSaveForLater => 'Save for later';

  @override
  String workoutTimeSemantic(String duration) {
    return 'Workout time $duration';
  }

  @override
  String workoutTimePausedSemantic(String duration) {
    return 'Workout time $duration, paused';
  }

  @override
  String get workoutResume => 'Resume';

  @override
  String get workoutPause => 'Pause';

  @override
  String get workoutParkedStatus =>
      'Saved for later. Everything recorded is kept; resume it to record more.';

  @override
  String get workoutResumeWorkout => 'Resume workout';

  @override
  String get workoutPausedStatus =>
      'Workout paused. Time and rest are frozen until you resume.';

  @override
  String get workoutNeedsReviewStatus =>
      'Saved on this phone; this workout needs review before it can sync. See the review notice below the screen.';

  @override
  String workoutSetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets recorded',
      one: '1 set recorded',
    );
    return '$_temp0';
  }

  @override
  String workoutPlannedSetsRecorded(int counted, int planned) {
    return '$counted of $planned planned sets recorded';
  }

  @override
  String get workoutPlannedSetsRail => 'Planned sets recorded';

  @override
  String get workoutNoMovementsTitle => 'No movements yet';

  @override
  String get workoutNoMovementsBody =>
      'Add a movement to start recording sets.';

  @override
  String workoutMovementPosition(int index, int total) {
    return 'Movement $index of $total';
  }

  @override
  String workoutMovementPositionExtra(int index, int total) {
    return 'Movement $index of $total · extra';
  }

  @override
  String workoutSubstitutedNote(String name) {
    return 'Recorded as $name, in place of the planned movement.';
  }

  @override
  String get workoutAbout => 'About';

  @override
  String workoutAboutSemantic(String name) {
    return 'About $name';
  }

  @override
  String get workoutTargetInWorkout => 'Target in this workout';

  @override
  String get workoutRestEnded => 'Rest ended';

  @override
  String get workoutRestOverline => 'Rest';

  @override
  String get workoutRestFromPrevious => 'Rest · from the previous movement';

  @override
  String workoutRestSemantic(String duration) {
    return 'Rest, $duration left';
  }

  @override
  String get workoutRestAdd30 => '+30 s';

  @override
  String get workoutRestDismiss => 'Dismiss';

  @override
  String get workoutRestSkip => 'Skip rest';

  @override
  String workoutNextSetOverline(int number) {
    return 'Set $number · not recorded yet';
  }

  @override
  String get workoutTargetReachedLast =>
      'Target set count recorded. This is the last movement: add another set, or finish the workout when you are ready.';

  @override
  String get workoutTargetReached =>
      'Target set count recorded. Add another set, or move on when you are ready.';

  @override
  String get workoutRecordSet => 'Record set';

  @override
  String get workoutRecordAnotherSet => 'Record another set';

  @override
  String workoutNextExercise(String name) {
    return 'Next exercise · $name';
  }

  @override
  String get workoutRecordedSetsOverline => 'Recorded sets';

  @override
  String get workoutNoRecordedSets =>
      'None yet. Targets, last time and suggestions are not recorded sets.';

  @override
  String workoutSetRowTitle(int number, String set) {
    return '$number.  $set';
  }

  @override
  String get workoutSetNeedsReview => 'Needs review';

  @override
  String get workoutSetPending =>
      'Recorded · saved on this phone, sync pending';

  @override
  String get workoutSetRecorded => 'Recorded';

  @override
  String get workoutAllMovementsOverline => 'All movements';

  @override
  String workoutMovementSetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets recorded',
    );
    return '$_temp0';
  }

  @override
  String workoutMovementSetsOfTarget(int count, int target) {
    return '$count of $target sets recorded';
  }

  @override
  String workoutMovementCurrent(String status) {
    return '$status · current';
  }

  @override
  String get workoutHistoryLoading => 'Reading your previous sessions…';

  @override
  String get workoutHistoryUnavailable =>
      'Your previous sessions could not be read on this phone right now.';

  @override
  String get workoutHistoryNoIdentity =>
      'No history: this movement is not linked to a saved exercise, so nothing is matched by name.';

  @override
  String get workoutHistoryNone => 'No previous session recorded.';

  @override
  String workoutCompareLastLabeled(String value) {
    return 'Last time: $value';
  }

  @override
  String workoutCompareTodayLabeled(String value) {
    return 'Today: $value';
  }

  @override
  String workoutCompareRecordedSemantic(String set) {
    return 'Recorded: $set';
  }

  @override
  String get workoutCompareNext => 'Next · not recorded yet';

  @override
  String get workoutCompareNotYet => 'Not recorded yet';

  @override
  String workoutCompareSetNumber(int number) {
    return 'Set $number';
  }

  @override
  String get workoutCompareSet => 'Set';

  @override
  String get workoutCompareToday => 'Today';

  @override
  String get workoutLastTime => 'Last time';

  @override
  String workoutLastTimeOn(String date) {
    return 'Last time · $date';
  }

  @override
  String get workoutAllSessions => 'All sessions';

  @override
  String get workoutAllSessionsSemantic => 'All previous sessions';

  @override
  String get workoutHistorySheetCaption =>
      'Previous sessions, newest first: workouts that count as training, matched by this exercise and its place in the workout.';

  @override
  String get workoutPreviewGoneTitle => 'This workout is no longer planned';

  @override
  String get workoutPreviewGoneBody =>
      'The plan changed since it was opened. Nothing was started or recorded.';

  @override
  String workoutPreviewSession(int number) {
    return 'Session $number';
  }

  @override
  String workoutPreviewWeek(int number) {
    return 'Week $number';
  }

  @override
  String workoutPreviewExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
      one: '1 exercise',
    );
    return '$_temp0';
  }

  @override
  String workoutPreviewPlannedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planned sets',
      one: '1 planned set',
    );
    return '$_temp0';
  }

  @override
  String get workoutPreviewToday => 'Today';

  @override
  String workoutPreviewMinutesPlanned(int minutes) {
    return '$minutes min planned';
  }

  @override
  String get workoutStart => 'Start workout';

  @override
  String get workoutPreviewViewRecorded => 'View what was recorded';

  @override
  String get workoutPreviewMoreOptions => 'More options';

  @override
  String get workoutPreviewMoreOptionsSemantic =>
      'Move, skip or edit this workout';

  @override
  String get workoutPreviewExercises => 'Exercises';

  @override
  String get workoutPreviewNoExercises =>
      'No exercises are planned in this workout.';

  @override
  String workoutPreviewSeeAll(int count) {
    return 'See all $count exercises';
  }

  @override
  String get workoutPreviewPlanPaused =>
      'The plan is paused. Resume the plan to start its workouts.';

  @override
  String get workoutPreviewSkipped => 'Skipped. Nothing was recorded for it.';

  @override
  String get workoutPreviewRotationOrder =>
      'A rotation runs in order: this one comes up after the workouts before it.';

  @override
  String get workoutPreviewCannotStart =>
      'This workout cannot be started now. More options shows what can be done with it.';

  @override
  String get workoutPreviewFooter =>
      'Last time is what you actually recorded before. Nothing here is recorded until you start.';

  @override
  String workoutPreviewTarget(String load) {
    return 'Target $load';
  }

  @override
  String get workoutSetATarget => 'Set a target';

  @override
  String get workoutReviewTarget => 'Review target';

  @override
  String workoutTargetForSemantic(String name) {
    return 'Target for $name';
  }

  @override
  String get workoutOutcomeFullExplain =>
      'Every planned movement has its target number of sets recorded.';

  @override
  String get workoutOutcomePartialExplain =>
      'Actual training was recorded. Some planned work was not; that is shown below.';

  @override
  String get workoutOutcomeNoDataExplainPlanned =>
      'No training was logged, so this gives no training credit and the planned workout is still available.';

  @override
  String get workoutOutcomeNoDataExplainManual =>
      'No training was logged, so this gives no training credit.';

  @override
  String get workoutOutcomeManualExplain =>
      'Recorded as manual training. It does not tick off a planned workout.';

  @override
  String get workoutOutcomeOpenExplain =>
      'This workout is still open. It is never finished automatically.';

  @override
  String workoutRemoveRecordedBody(String title, String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recorded sets',
      one: '1 recorded set',
    );
    return 'This removes \"$title\" from $date and its $_temp0 from your history.';
  }

  @override
  String workoutDateManual(String date) {
    return '$date · manual';
  }

  @override
  String get workoutSyncPending => 'Saved on this phone · sync pending';

  @override
  String get workoutDetailNeedsReview =>
      'Saved on this phone; needs your review before it can sync.';

  @override
  String get workoutFactTime => 'Time';

  @override
  String get workoutFactSets => 'Sets';

  @override
  String get workoutFactMovements => 'Movements';

  @override
  String workoutPlannedTarget(String target) {
    return 'Planned · $target';
  }

  @override
  String get workoutExerciseNotRecorded => 'Not recorded.';

  @override
  String get workoutExerciseNoSets => 'No sets recorded.';

  @override
  String get workoutDetailEmptyTitle => 'Nothing recorded';

  @override
  String get workoutDetailEmptyBody => 'This workout has no movements.';

  @override
  String get workoutHistoryTitle => 'Workout history';

  @override
  String get workoutHistoryEmptyTitle => 'No workouts yet';

  @override
  String get workoutHistoryEmptyBody =>
      'Workouts you record will appear here with what you actually did.';

  @override
  String workoutSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String get workoutManualTag => 'manual';

  @override
  String workoutStillOpenTitle(String title) {
    return '$title is still open';
  }

  @override
  String get workoutStillOpenBody =>
      'Only one workout is in front at a time. Resume it, or save it for later. Saving for later keeps every recorded set and never finishes it.';

  @override
  String get workoutStillOpenPark => 'Save it for later and continue';

  @override
  String get workoutStillOpenResume => 'Resume it';

  @override
  String get workoutStartFailed =>
      'The workout could not be started on this phone. Nothing was recorded. Try again.';

  @override
  String get workoutPickerTitle => 'Choose a movement';

  @override
  String get workoutPickerSearch => 'Search exercises';

  @override
  String get workoutPickerCatalogEmpty =>
      'The exercise list has not been downloaded to this phone yet. You can still create your own exercise.';

  @override
  String get workoutPickerMuscle => 'Muscle group';

  @override
  String get workoutPickerEquipment => 'Equipment';

  @override
  String get workoutPickerNoMatch =>
      'No exercise matches that. Try another name or filter, or create your own.';

  @override
  String get workoutPickerTimedTag => 'timed';

  @override
  String get workoutPickerYourExercise => 'Your exercise';

  @override
  String get workoutPickerCreate => 'Create your own exercise';

  @override
  String workoutPickerCreateNamed(String name) {
    return 'Create “$name” as your own exercise';
  }

  @override
  String get workoutPickerCreateSubtitle =>
      'Private to your account. It keeps its own history.';

  @override
  String get workoutCustomTitle => 'Your own exercise';

  @override
  String get workoutSaveFailedRetry =>
      'It could not be saved on this phone. Try again.';

  @override
  String get workoutCustomCaption =>
      'Only you can see your own exercises. Renaming one later never changes what you already recorded.';

  @override
  String get workoutCustomName => 'Name';

  @override
  String get workoutCustomTimed => 'Timed';

  @override
  String get workoutCustomTimedHelp =>
      'Held or done for a time, like a plank, instead of counted reps.';

  @override
  String get workoutCustomSave => 'Save exercise';

  @override
  String get workoutManualTitle => 'Manual workout';

  @override
  String get workoutManualCaption =>
      'Train without a plan. This is recorded as real training and never ticks off a planned workout.';

  @override
  String get workoutManualDefaultName => 'Workout';

  @override
  String get workoutManualMovements => 'Movements';

  @override
  String get workoutManualNone =>
      'None yet. You can also add movements after starting.';

  @override
  String workoutManualRemove(String name) {
    return 'Remove $name';
  }

  @override
  String workoutProgressionDaysBoth(String date) {
    return 'both on $date';
  }

  @override
  String workoutProgressionDaysPair(String first, String second) {
    return '$first and $second';
  }

  @override
  String workoutProgressionQualified(
    String workout,
    String days,
    int sets,
    String exercise,
    String target,
    int top,
    String range,
  ) {
    return 'In your last two $workout sessions ($days) you recorded all $sets sets of $exercise at $target with $top or more reps, the top of your $range range.';
  }

  @override
  String get workoutProgressionConfigureIncrement =>
      'Choose the weight increment your equipment allows to see a next target.';

  @override
  String workoutProgressionIncrementTooLarge(String increment) {
    return 'Your increment of $increment is more than 5% of that target, so GoHard does not suggest it automatically. You can still review the target yourself.';
  }

  @override
  String workoutProgressionBelowTop(String workout, int top, String target) {
    return 'A set in one of your last two $workout sessions was below $top reps at $target.';
  }

  @override
  String workoutProgressionSetsMissing(
    String workout,
    int sets,
    String exercise,
  ) {
    return 'One of your last two $workout sessions has fewer than $sets sets of $exercise recorded.';
  }

  @override
  String workoutProgressionExtraSets(
    String workout,
    int sets,
    String exercise,
  ) {
    return 'One of your last two $workout sessions has more than $sets sets of $exercise, and warm-ups are not marked, so they cannot be compared.';
  }

  @override
  String workoutProgressionLoadUnknown(String workout) {
    return 'A set in one of your last two $workout sessions has no load recorded.';
  }

  @override
  String workoutProgressionLoadDiffers(String workout, String target) {
    return 'One of your last two $workout sessions used a load other than $target.';
  }

  @override
  String workoutProgressionPartial(String workout) {
    return 'One of your last two $workout sessions was saved as partly completed.';
  }

  @override
  String workoutProgressionNotAsPlanned(String workout, String exercise) {
    return 'One of your last two $workout sessions did not include $exercise as planned.';
  }

  @override
  String workoutProgressionStays(String target) {
    return 'The target stays at $target.';
  }

  @override
  String workoutProgressionTargetChanged(String workout, String target) {
    return 'Your target changed since your last $workout session. Two sessions at $target are needed before a step up is considered.';
  }

  @override
  String workoutProgressionNeedTwo(String workout, String target, int count) {
    return 'Two $workout sessions at $target are needed before a step up is considered; $count recorded so far.';
  }

  @override
  String workoutProgressionNoLoadTarget(String workout) {
    return 'This exercise has no weight target in $workout. Set one if you want sessions compared against it.';
  }

  @override
  String workoutProgressionNoRange(String workout) {
    return 'This exercise has no set count and rep range in $workout to compare against.';
  }

  @override
  String get workoutProgressionTimed =>
      'This exercise is timed, so GoHard does not calculate a weight for it. You can set targets yourself.';

  @override
  String get workoutProgressionBodyweight =>
      'GoHard does not calculate weights for bodyweight or assisted exercises. You can set targets yourself.';

  @override
  String get workoutProgressionNoIdentity =>
      'This exercise is not linked to a saved exercise, so its sessions are not compared.';

  @override
  String get workoutNextTimeHeader => 'Next time';

  @override
  String get workoutNextTimeHelpLabel => 'About next targets';

  @override
  String workoutNextTimeCoachIncrease(String exercise) {
    return 'You reached the top of your rep range in your last two comparable sessions of $exercise. You can review an optional next target.';
  }

  @override
  String workoutNextTimeCoachIncrement(String exercise) {
    return 'You reached the top of your rep range in your last two comparable sessions of $exercise. Tell me your weight increment and I can size a next target.';
  }

  @override
  String get workoutProgressionHowTitle => 'How progression works';

  @override
  String workoutNextTimeRowReview(String change) {
    return '$change · Review';
  }

  @override
  String get workoutChooseIncrement => 'Choose your weight increment';

  @override
  String get workoutCurrentTarget => 'Current target';

  @override
  String get workoutProposed => 'Proposed';

  @override
  String get workoutReviewNextTarget => 'Review next target';

  @override
  String get workoutKeepCurrentTarget => 'Keep current target';

  @override
  String workoutKeptTarget(String load) {
    return 'Kept $load. Nothing in your plan changed.';
  }

  @override
  String get workoutSaveFailedNothingChanged =>
      'That could not be saved on this phone. Nothing changed; try again.';

  @override
  String get workoutNoNextTarget => 'No next weight target';

  @override
  String workoutNextTargetValue(String load) {
    return 'Next target · $load';
  }

  @override
  String get workoutReviewSuggestion => 'Review suggestion';

  @override
  String get workoutReview => 'Review';

  @override
  String workoutSetNextTargetSemantic(String name) {
    return 'Set a next target for $name';
  }

  @override
  String workoutReviewNextTargetSemantic(String name) {
    return 'Review the next target for $name';
  }

  @override
  String get workoutNextTargetTitle => 'Next target';

  @override
  String get workoutTargetLoadError =>
      'Enter a weight above zero, or leave it empty for no weight target.';

  @override
  String get workoutTargetRangeError =>
      'Use 1 to 20 sets and a rep range from 1 to 100, the lower number first.';

  @override
  String get workoutTargetSaveFailed =>
      'It could not be saved on this phone. Nothing changed; try again.';

  @override
  String get workoutTargetRestored => 'Previous target restored.';

  @override
  String get workoutTargetGone =>
      'This exercise is no longer in that plan workout, so there is no next target to review. Nothing was changed.';

  @override
  String workoutTargetScope(String workout) {
    return 'Applies from the next time you start $workout, until you change it. Today\'s workout and earlier ones keep what they recorded.';
  }

  @override
  String workoutReviewCurrent(String load, String prescription) {
    return 'Current target: $load · $prescription';
  }

  @override
  String get workoutNoWeightTarget => 'no weight target';

  @override
  String workoutTargetSaved(String scope) {
    return 'Next target saved. $scope';
  }

  @override
  String get workoutEditNextTarget => 'Edit next target';

  @override
  String workoutRestorePrevious(String target) {
    return 'Restore previous target ($target)';
  }

  @override
  String get workoutSaveNextTarget => 'Save next target';

  @override
  String workoutUseLoadFromNext(String load) {
    return 'Use $load from next session';
  }

  @override
  String get workoutYourLastSessions => 'Your last sessions';

  @override
  String workoutSessionLine(String date, String sets) {
    return '$date: $sets';
  }

  @override
  String get workoutNotRecordedLower => 'not recorded';

  @override
  String workoutSuggestedLine(String proposed, String increment) {
    return 'Suggested: $proposed, one increment of $increment. Only the weight is suggested; sets and reps change only if you edit them.';
  }

  @override
  String get workoutWeightLabel => 'Weight';

  @override
  String workoutUseLastRecordedLoad(String load) {
    return 'Use last recorded load ($load)';
  }

  @override
  String get workoutSetsLabel => 'Sets';

  @override
  String get workoutRepsFrom => 'Reps from';

  @override
  String get workoutRepsTo => 'Reps to';

  @override
  String get workoutRepsToShort => 'to';

  @override
  String workoutIncrementChange(String increment) {
    return 'Weight increment $increment · Change';
  }

  @override
  String get workoutNoChangeToSave => 'No change to save';

  @override
  String get workoutIncrementTitle => 'Weight increment';

  @override
  String workoutIncrementRangeError(String max) {
    return 'Enter a step above zero and up to $max.';
  }

  @override
  String workoutIncrementCaption(String exercise) {
    return 'The step GoHard adds when it suggests a heavier target for $exercise, and only then. Pick the smallest increase your plates, dumbbells or machine allow. Gyms differ, so nothing is chosen for you.';
  }

  @override
  String get workoutIncrementConvention =>
      'GoHard keeps a load exactly as you record it. Use the same convention as your sets: if you record dumbbells per hand, enter the step per hand; for a barbell, the total change on the bar.';

  @override
  String workoutIncrementSaved(String increment) {
    return 'Saved: $increment';
  }

  @override
  String workoutIncrementSavedPending(String increment) {
    return 'Saved: $increment · sync pending';
  }

  @override
  String get workoutIncrementAnother => 'Another step';

  @override
  String get workoutIncrementLocalOnly =>
      'Saved on this phone. Your account\'s server does not keep increments yet; it will sync once the server is updated.';

  @override
  String get workoutChooseStep => 'Choose a step';

  @override
  String workoutSaveStep(String increment) {
    return 'Save $increment';
  }

  @override
  String get workoutIncrementRemove => 'Remove this increment';

  @override
  String get workoutProgressionHelp1 =>
      'A target is what you plan to lift. Last time is what you recorded before. Today shows only the sets you actually record. Suggestions never record a set.';

  @override
  String get workoutProgressionHelp2 =>
      'GoHard looks at your two most recent sessions of the same plan workout. If both have every planned set of an exercise at its target weight, with reps at the top of its range, it suggests the target plus one weight increment that you chose.';

  @override
  String get workoutProgressionHelp3 =>
      'It never goes further back than those two sessions, never adds sets, changes reps or swaps exercises, and never lowers a weight on its own. Timed, bodyweight and assisted exercises keep manual targets.';

  @override
  String get workoutProgressionHelp4 =>
      'An increment larger than 5% of the current target is not suggested automatically; you can still set the target yourself. That limit is a GoHard product choice, not a safety threshold.';

  @override
  String get workoutProgressionHelp5 =>
      'Reps say nothing about effort, form, pain or recovery. A suggestion is optional: review it, edit it or keep your current target. Nothing changes until you confirm.';

  @override
  String get workoutProgressionHelpSources =>
      'Published guidance: the 2009 ACSM position stand describes raising the load by about 2–10% once you can do one or two reps more than your target in two consecutive sessions. The 2026 ACSM position stand advises progressive resistance training, and notes that continued overload matters mainly for longer-term progress. GoHard\'s rule (the top of your range in your last two sessions, one increment you chose, at most 5%) is its own product choice; neither paper tests or validates it.';

  @override
  String progressCoachWorkoutsOfTarget(int count, int target) {
    return '$count of $target workouts recorded this week.';
  }

  @override
  String progressCoachRunWalkOfTarget(int count, int target) {
    return '$count of $target runs or walks recorded this week.';
  }

  @override
  String progressCoachSoFar(int workouts, int activities) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts workouts',
      one: '1 workout',
    );
    String _temp1 = intl.Intl.pluralLogic(
      activities,
      locale: localeName,
      other: '$activities runs or walks',
      one: '1 run or walk',
    );
    return 'This week so far: $_temp0 and $_temp1 recorded.';
  }

  @override
  String progressCoachSoFarSetGoals(int workouts, int activities) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts workouts',
      one: '1 workout',
    );
    String _temp1 = intl.Intl.pluralLogic(
      activities,
      locale: localeName,
      other: '$activities runs or walks',
      one: '1 run or walk',
    );
    return 'This week so far: $_temp0 and $_temp1 recorded. Set weekly goals below if you\'d like a target.';
  }

  @override
  String get progressCoachNothingYet =>
      'Nothing recorded yet this week. Set weekly goals below if you\'d like a target.';

  @override
  String get progressCoachContextLabel => 'Your progress';

  @override
  String get progressStrengthTrends => 'Strength trends';

  @override
  String get progressSeeAll => 'See all';

  @override
  String get progressSeeAllTrendsSemantic => 'See all exercise trends';

  @override
  String get progressNoStableTrend =>
      'No exercise with a stable identity has recorded sets yet. Movements typed as free text have no trend.';

  @override
  String get progressNoTrainingTitle => 'No training recorded yet';

  @override
  String get progressNoTrainingBody =>
      'Trends are built only from workouts you actually record. There is nothing to chart until then.';

  @override
  String get progressStartManual => 'Start a manual workout';

  @override
  String get progressBodyLink => 'Body progress';

  @override
  String get progressBodyLinkSemantic =>
      'Open Body progress: weight and measurements';

  @override
  String get progressPlanHeader => 'Am I following my plan?';

  @override
  String get progressNoPrimary =>
      'You have no primary plan right now. Manual training still counts as training.';

  @override
  String get progressNothingDue => 'No planned workout has come due yet.';

  @override
  String progressDueRecorded(int recorded, int due) {
    return '$recorded of $due due workouts recorded';
  }

  @override
  String get progressDueRail => 'Due workouts recorded';

  @override
  String progressAdherenceBreakdown(
    int full,
    int partial,
    int skipped,
    int missed,
  ) {
    return '$full completed · $partial partial · $skipped skipped · $missed missed';
  }

  @override
  String get progressPlansLink => 'Plans';

  @override
  String get progressViewPlan => 'View your plan';

  @override
  String get progressOpenPlanSemantic => 'Open Train, Plan';

  @override
  String get progressGoalsSeparate =>
      'Weekly goals are separate: they never schedule, move or complete a planned workout.';

  @override
  String get progressConsistencyHeader => 'Am I consistent?';

  @override
  String progressConsistencyCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return 'Days with recorded training in each of the last 8 weeks. $_temp0 in total.';
  }

  @override
  String progressConsistencySemantic(String days) {
    return 'Training days per week, oldest first: $days';
  }

  @override
  String get progressWorkoutsLabel => 'Workouts';

  @override
  String get progressRunWalkLabel => 'Run / Walk';

  @override
  String progressWorkoutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts',
      one: '1 workout',
    );
    return '$_temp0';
  }

  @override
  String progressRunWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count runs or walks',
      one: '1 run or walk',
    );
    return '$_temp0';
  }

  @override
  String progressRunCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count runs',
      one: '1 run',
    );
    return '$_temp0';
  }

  @override
  String progressWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count walks',
      one: '1 walk',
    );
    return '$_temp0';
  }

  @override
  String progressGoalSaidNoTarget(String what, String counted) {
    return '$what: $counted recorded this week, no target.';
  }

  @override
  String progressGoalSaidTarget(String what, int count, int target) {
    return '$what: $count of $target this week.';
  }

  @override
  String get progressThisWeek => 'This week';

  @override
  String get progressWeeklyRhythm => 'Your weekly rhythm';

  @override
  String get progressEditGoals => 'Edit goals';

  @override
  String get progressSetGoals => 'Set weekly goals';

  @override
  String get progressEditGoalsSemantic => 'Edit weekly goals';

  @override
  String get progressGoalsUnavailable =>
      'Weekly goals are not available on your account\'s server yet, so none can be saved. Your counts are still shown.';

  @override
  String get progressGoalsPending => 'Goals saved on this phone · sync pending';

  @override
  String get progressGoalsReview =>
      'This week\'s goals were also changed on another device. Review them from the notice at the bottom of the screen.';

  @override
  String progressCountRecorded(int count) {
    return '$count recorded';
  }

  @override
  String progressCountOfTarget(int count, int target) {
    return '$count of $target';
  }

  @override
  String progressCountOfTargetReached(int count, int target) {
    return '$count of $target · reached';
  }

  @override
  String progressGoalRail(String label) {
    return '$label goal';
  }

  @override
  String get progressGoalsTitle => 'Weekly goals';

  @override
  String get progressGoalsSaveFailed =>
      'Your goals could not be saved on this phone. Nothing changed.';

  @override
  String get progressGoalsCleared => 'Weekly goals cleared from this week.';

  @override
  String get progressGoalsSaved => 'Weekly goals saved.';

  @override
  String progressGoalRangeError(int min, int max) {
    return 'Use a whole number from $min to $max, or leave it blank.';
  }

  @override
  String progressGoalFieldHelper(int min, int max) {
    return '$min to $max a week, or blank for no target';
  }

  @override
  String get progressGoalsHelper =>
      'These are weekly activity targets. Your training plan stays the same.';

  @override
  String progressGoalsApply(String range) {
    return 'They apply from this week ($range) until you change them. Earlier weeks keep the goals they had. Leave a field blank for no target.';
  }

  @override
  String get progressGoalWorkoutsField => 'Workouts per week';

  @override
  String get progressGoalRunWalkField => 'Runs and walks per week';

  @override
  String get progressGoalsSave => 'Save goals';

  @override
  String progressRecapLinkSemantic(String range) {
    return 'Last week\'s recap, $range';
  }

  @override
  String progressRecapLinkSemanticOlder(String range) {
    return 'Last week\'s recap, $range. Earlier weeks are inside.';
  }

  @override
  String get progressRecapLinkTitle => 'Last week\'s recap';

  @override
  String progressRecapLinkOlder(String range) {
    return '$range · earlier weeks inside';
  }

  @override
  String progressTrendPreviewSemantic(
    String name,
    String value,
    String date,
    String metric,
    int count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$name. Latest recorded $value on $date. $metric. $_temp0 charted.';
  }

  @override
  String progressLatestRecordedOn(String date) {
    return 'Latest recorded · $date';
  }

  @override
  String get progressLatestRecorded => 'Latest recorded';

  @override
  String progressRepsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reps',
    );
    return '$_temp0';
  }

  @override
  String progressMetricLoad(int reps) {
    return 'Top set load · $reps reps';
  }

  @override
  String get progressMetricReps => 'Most reps in a set · no added load';

  @override
  String get progressMetricDuration => 'Longest recorded time';

  @override
  String get progressMetricNone => 'No comparable measure';

  @override
  String get progressNoChange => 'No change';

  @override
  String progressChangeReps(String signed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$signed reps',
      one: '$signed rep',
    );
    return '$_temp0';
  }

  @override
  String get progressRange4Weeks => '4 weeks';

  @override
  String get progressRange12Weeks => '12 weeks';

  @override
  String get progressRangeAll => 'All';

  @override
  String progressRangeWords(String range) {
    String _temp0 = intl.Intl.selectLogic(range, {
      'weeks4': 'in the last 4 weeks',
      'weeks12': 'in the last 12 weeks',
      'other': 'in all your history',
    });
    return '$_temp0';
  }

  @override
  String progressNoSessionRange(String rangeWords) {
    return 'No session $rangeWords';
  }

  @override
  String get progressTrendsTitle => 'Exercise trends';

  @override
  String get progressTrendsSubtitle =>
      'Exercises you have recorded, most recent first';

  @override
  String get progressTrendsSearch => 'Search your exercises';

  @override
  String get progressTrendsEmptyTitle => 'Nothing recorded yet';

  @override
  String get progressTrendsEmptyBody =>
      'An exercise appears here once a finished workout has recorded sets of it.';

  @override
  String get progressTrendsNoMatchTitle => 'No match';

  @override
  String progressTrendsNoMatchBody(String query) {
    return 'None of your recorded exercises matches \"$query\".';
  }

  @override
  String progressTrendRowSubtitle(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0 · latest $date';
  }

  @override
  String get progressReadErrorTitle => 'This could not be read';

  @override
  String get progressReadErrorBody =>
      'Your records on this phone could not be read just now. Nothing was changed; try again.';

  @override
  String get progressNoRecordedSetsTitle => 'No recorded sets';

  @override
  String get progressNoRecordedSetsBody =>
      'This exercise has no recorded sets in a finished workout any more.';

  @override
  String get progressNoRecordedSetsAnyMore =>
      'This exercise has no recorded sets any more.';

  @override
  String get progressCompareSetsOf => 'Compare sets of';

  @override
  String get progressNothingComparable =>
      'These sets have no reps with a load, no reps alone and no recorded time, so there is nothing comparable to chart. Every recorded session is listed below.';

  @override
  String get progressRecordedOnly => 'Recorded sessions only';

  @override
  String get progressFirstToLatest => 'first to latest, this range';

  @override
  String progressEmptyRangeLoad(int reps, String rangeWords) {
    return 'No session with a set of $reps reps $rangeWords. Choose a longer range or another rep count.';
  }

  @override
  String progressEmptyRange(String rangeWords) {
    return 'No session $rangeWords. Choose a longer range.';
  }

  @override
  String progressChartSemantic(
    String metric,
    String rangeWords,
    int count,
    String points,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$metric, $rangeWords: $_temp0. $points.';
  }

  @override
  String get progressOnePoint =>
      'One comparable session so far. A change needs at least two.';

  @override
  String get progressSessionsInRange => 'Sessions in this range';

  @override
  String progressRowsExplainLoad(int reps) {
    return 'Each row is the heaviest set of $reps reps in that workout. Shown at the same rep count.';
  }

  @override
  String get progressRowsExplain =>
      'Each row is that workout\'s best set by this measure.';

  @override
  String progressExcludedLoad(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count recorded sets without both reps and a load are not in this chart.',
      one: '1 recorded set without both reps and a load is not in this chart.',
    );
    return '$_temp0';
  }

  @override
  String progressExcludedReps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count recorded sets with a load or without reps are not in this chart.',
      one: '1 recorded set with a load or without reps is not in this chart.',
    );
    return '$_temp0';
  }

  @override
  String progressExcludedDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count recorded sets without a recorded time are not in this chart.',
      one: '1 recorded set without a recorded time is not in this chart.',
    );
    return '$_temp0';
  }

  @override
  String progressAllSessionsLink(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return 'All $_temp0 and sets';
  }

  @override
  String get progressSessionsTitle => 'Sessions';

  @override
  String get progressAllSessionsSubtitle =>
      'Every recorded session, newest first';

  @override
  String get progressRecapTitle => 'Weekly recap';

  @override
  String get progressPreviousWeek => 'Previous week';

  @override
  String get progressNextWeek => 'Next week';

  @override
  String progressRecapLastWeek(String range) {
    return 'Last week · $range';
  }

  @override
  String progressRecapWeekOf(String range) {
    return 'Week of $range';
  }

  @override
  String progressRecapSemLastWeek(String range) {
    return 'Last week $range.';
  }

  @override
  String progressRecapSemWeekOf(String range) {
    return 'Week of $range.';
  }

  @override
  String get progressRecapSemNoActivity => 'No activity was recorded.';

  @override
  String progressRecapSemRecorded(String list) {
    return '$list recorded.';
  }

  @override
  String progressRecapSemDistance(String kind, String distance) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'Walking distance',
      'running': 'Running distance',
      'other': 'Run / Walk distance',
    });
    return '$_temp0 $distance.';
  }

  @override
  String progressRecapSemDistanceIncomplete(String kind, String distance) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'Walking distance',
      'running': 'Running distance',
      'other': 'Run / Walk distance',
    });
    return '$_temp0 $distance, some distances not recorded.';
  }

  @override
  String progressRecapSemActive(String duration) {
    return 'Active time $duration.';
  }

  @override
  String get progressNotRecorded => 'not recorded';

  @override
  String get progressRecapHeading => 'Your week, recorded';

  @override
  String get progressRecapEmpty => 'No activity was recorded this week.';

  @override
  String progressRecapWorkoutsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Workouts',
      one: 'Workout',
    );
    return '$_temp0';
  }

  @override
  String progressRecapWalks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Walks',
      one: 'Walk',
    );
    return '$_temp0';
  }

  @override
  String progressRecapRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Runs',
      one: 'Run',
    );
    return '$_temp0';
  }

  @override
  String get progressRecapRunsAndWalks => 'Runs and walks';

  @override
  String progressRecapDistanceLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'Walking distance',
      'running': 'Running distance',
      'other': 'Run / Walk distance',
    });
    return '$_temp0';
  }

  @override
  String progressRecapTimeLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'Walking time',
      'running': 'Running time',
      'other': 'Run / Walk time',
    });
    return '$_temp0';
  }

  @override
  String progressRecapIncomplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count activities had no distance recorded and are not in the total.',
      one: '1 activity had no distance recorded and is not in the total.',
    );
    return '$_temp0';
  }

  @override
  String get progressRecapTargets => 'Your weekly targets';

  @override
  String get progressRecapNoGoals => 'No goals were set for this week.';

  @override
  String get progressRecapHighlight => 'Strength highlight';

  @override
  String progressRecapHighlightSubtitle(String dates, int reps) {
    return '$dates · recorded at $reps reps';
  }

  @override
  String progressListJoin(String head, String last) {
    return '$head and $last';
  }

  @override
  String progressRecapCoachEmpty(String range) {
    return 'No activity was recorded in the week of $range.';
  }

  @override
  String progressRecapCoach(String list, String range) {
    return 'You recorded $list in the week of $range.';
  }

  @override
  String get progressRecapSessions => 'This week\'s sessions';

  @override
  String progressRecapNothingBetween(String start, String end) {
    return 'Nothing was recorded between $start and $end.';
  }

  @override
  String progressTargetRowSemantic(String label, int count, int target) {
    return '$label: $count of $target.';
  }

  @override
  String progressTargetRowSemanticReached(String label, int count, int target) {
    return '$label: $count of $target, reached.';
  }

  @override
  String get accountErrorPasswordTooLong =>
      'That password is longer than 256 characters. Use a shorter one.';

  @override
  String get accountErrorPasswordMismatch =>
      'The two new passwords are not the same.';

  @override
  String get accountErrorCodeIncomplete => 'Enter all 8 digits of the code.';

  @override
  String get accountErrorCodeInvalid =>
      'That code isn\'t right. Check the latest email from GoHard, or ask for a new code.';

  @override
  String get accountErrorCodeExpired =>
      'That code has expired. Ask for a new one.';

  @override
  String get accountErrorCodeAttempts =>
      'Too many tries for this code. Ask for a new code.';

  @override
  String accountErrorCooldown(int seconds) {
    return 'Please wait $seconds s before asking for another code.';
  }

  @override
  String get accountEmailUnavailable =>
      'Email recovery isn\'t available yet. Your account and data are safe; try again later.';

  @override
  String get accountErrorEmailBusy =>
      'GoHard is sending too many emails right now. Try again in a few minutes.';

  @override
  String get accountErrorResetExpired =>
      'This reset has expired or was already used. Ask for a new code to start again.';

  @override
  String get accountErrorNotSupported =>
      'Your account\'s server doesn\'t offer this yet. Nothing was changed.';

  @override
  String get accountErrorUncertainReset =>
      'We couldn\'t confirm the change. Try signing in with your new password; if that doesn\'t work, ask for a new code.';

  @override
  String get accountErrorUncertainChange =>
      'We couldn\'t confirm whether your password changed. Nothing on this phone was lost. If you\'re asked to sign in, try the new password first.';

  @override
  String get codeFieldLabel => '8-digit code';

  @override
  String get codeFieldHelper =>
      'From the email GoHard sent you. You can paste it.';

  @override
  String get codeResend => 'Resend code';

  @override
  String codeResendIn(int seconds) {
    return 'Resend in $seconds s';
  }

  @override
  String get codeDeliveryNote =>
      'It can take a minute to arrive. Check spam or junk too.';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get newPasswordConfirmLabel => 'Confirm new password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get passwordRule =>
      'At least 15 characters. A few unrelated words work well; any characters are fine.';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNoticePasswordChanged =>
      'Your password was changed. Sign in with your new password; everything on this phone is still here.';

  @override
  String get resetTitle => 'Reset password';

  @override
  String get resetEmailLead =>
      'Enter your account\'s email. If an account uses it, we\'ll send it a reset code.';

  @override
  String get resetSendCode => 'Send code';

  @override
  String get resetCodeTitle => 'Enter the code';

  @override
  String resetCodeLead(String email) {
    return 'If an account uses $email, we\'ve sent it an 8-digit code. It\'s valid for 10 minutes.';
  }

  @override
  String get resetUseAnotherEmail => 'Use a different email';

  @override
  String get resetPasswordTitle => 'New password';

  @override
  String get resetPasswordLead =>
      'Choose your new password. Every device will be signed out.';

  @override
  String get resetSetPassword => 'Set new password';

  @override
  String get resetGoToSignIn => 'Go to sign in';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordLead =>
      'Your current password is checked by GoHard before anything changes.';

  @override
  String get changePasswordSignsOut =>
      'Changing it signs you out on every device, this one too. Your data stays on this phone and syncs again when you sign in.';

  @override
  String get changePasswordButton => 'Change password';

  @override
  String get changePasswordConfirmTitle => 'Sign out everywhere?';

  @override
  String get changePasswordConfirmBody =>
      'After the change you\'ll sign in again with the new password, on this phone and every other device.';

  @override
  String get changePasswordOffline =>
      'Changing your password needs a connection. Nothing is saved for later.';

  @override
  String get verifyTitle => 'Verify email';

  @override
  String verifyLead(String email) {
    return 'We\'ll send an 8-digit code to $email to confirm it\'s yours.';
  }

  @override
  String get verifySend => 'Send code';

  @override
  String get verifyConfirm => 'Verify';

  @override
  String get verifyLater => 'Later';

  @override
  String get verifyVerified => 'Your email is verified.';

  @override
  String get verifyDone => 'Email verified';

  @override
  String get meEmail => 'Email';

  @override
  String get meEmailVerified => 'Verified';

  @override
  String get meEmailNotVerified => 'Not verified';

  @override
  String get mePassword => 'Password';

  @override
  String get mePasswordSubtitle => 'Change password';

  @override
  String get accountErrorRegistrationUnavailable =>
      'New accounts can\'t be created right now because email verification isn\'t available. Nothing was created; please try again later.';

  @override
  String get verifyGateTitle => 'Verify your email';

  @override
  String verifyGateLead(String email) {
    return 'Enter the 8-digit code we sent to $email.';
  }

  @override
  String get verifyGateWhy =>
      'Verifying your email is needed to finish setting up your account. It confirms this address is yours and changes nothing else.';

  @override
  String get verifyCheckAgain => 'Check again';

  @override
  String get verifyGateSignOut => 'Sign out or use another account';

  @override
  String get verifyGateSignOutTitle => 'Sign out?';

  @override
  String get verifyGateSignOutBody =>
      'This account stays as it is, waiting for verification. Sign in again any time to verify it.';

  @override
  String get verifyScope =>
      'Verifying confirms this address is yours. It changes nothing else.';

  @override
  String verifyGraceWhy(String date) {
    return 'Verify by $date to keep syncing. It confirms this address is yours and changes nothing else.';
  }

  @override
  String get verifyPausedWhy =>
      'Syncing is paused until you verify. Everything you save stays on this phone and goes up once you verify.';

  @override
  String todayVerifyBy(String date) {
    return 'Verify your email by $date to keep syncing.';
  }

  @override
  String get todayVerifyPaused =>
      'Verify your email to sync again. What you save stays on this phone.';

  @override
  String get todayVerifyAction => 'Verify';

  @override
  String meEmailVerifyBy(String date) {
    return 'Verify by $date';
  }

  @override
  String get meEmailPaused => 'Syncing paused until verified';

  @override
  String get eatHistoryTrendsSubtitle => 'Review your intake by week or month';

  @override
  String get eatHistoryTrendsSaid =>
      'History and trends. Review your intake by week or month';

  @override
  String get trainRecentWorkouts => 'Recent workouts';

  @override
  String get trainViewAllHistory => 'View all history';

  @override
  String get trainViewAllHistorySaid => 'View all workout history';

  @override
  String get mealsLibraryTitle => 'Saved meals & recipes';

  @override
  String get mealsFromAddFoodSubtitle =>
      'Several foods at once, with the amounts checked first';

  @override
  String mealsForContext(String meal, String date) {
    return 'Logs to $meal · $date';
  }

  @override
  String get mealsTabMeals => 'Meals';

  @override
  String get mealsTabRecipes => 'Recipes';

  @override
  String get mealsNewMeal => 'New meal';

  @override
  String get mealsNewRecipe => 'New recipe';

  @override
  String get mealsEditMeal => 'Edit meal';

  @override
  String get mealsEditRecipe => 'Edit recipe';

  @override
  String get mealsSearchHint => 'Search by name';

  @override
  String mealsNoMatch(String query) {
    return 'Nothing saved matches “$query”.';
  }

  @override
  String get mealsEmptyMealsTitle => 'No saved meals yet';

  @override
  String get mealsEmptyMealsBody =>
      'A saved meal keeps several foods with their usual amounts, like 2 eggs and 60 g of oats. When you log it, you can change the amounts first.';

  @override
  String get mealsEmptyRecipesTitle => 'No recipes yet';

  @override
  String get mealsEmptyRecipesBody =>
      'A recipe is a whole batch of ingredients and the number of servings it makes. You log the portion you had.';

  @override
  String get mealsUntitled => 'Untitled';

  @override
  String get mealsUnsavedDraft => 'Unsaved changes';

  @override
  String mealsFoodsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foods',
      one: '1 food',
    );
    return '$_temp0';
  }

  @override
  String mealsIngredientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ingredients',
      one: '1 ingredient',
    );
    return '$_temp0';
  }

  @override
  String mealsMakesServings(num count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'makes $value servings',
      one: 'makes 1 serving',
    );
    return '$_temp0';
  }

  @override
  String mealsServingsAmount(num count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$value servings',
      one: '1 serving',
    );
    return '$_temp0';
  }

  @override
  String mealsPerServing(String value) {
    return '$value per serving';
  }

  @override
  String mealsMenuLabel(String name) {
    return 'Options for $name';
  }

  @override
  String get mealsDuplicate => 'Duplicate';

  @override
  String mealsCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String mealsDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get mealsDeleteBody =>
      'It is removed from Saved meals & recipes. Food you already logged from it stays exactly as it is.';

  @override
  String get mealsDeleted => 'Deleted. Your logged food is unchanged.';

  @override
  String get mealsServerUnavailable =>
      'Your account’s server doesn’t take saved meals and recipes yet. Drafts stay on this phone; saving and logging them wait until it does.';

  @override
  String get mealsHelpLabel => 'Help with saved meals and recipes';

  @override
  String get mealsCoachLibrary =>
      'A saved meal keeps foods and their usual amounts. When you log it, you can halve, double or change any of them first.';

  @override
  String get mealsCoachRecipe =>
      'A recipe divides a whole batch into the servings you choose.';

  @override
  String get eatHintMeals =>
      'Eat this often? Save the meal and adjust the amounts next time.';

  @override
  String get mealsSaved => 'Your meal is in Saved meals & recipes.';

  @override
  String get mealsSavedRecipe => 'Your recipe is in Saved meals & recipes.';

  @override
  String get mealsSaveAsMeal => 'Save as meal';

  @override
  String mealsSaveAsMealSaid(String meal) {
    return 'Save $meal as a saved meal';
  }

  @override
  String get mealsNameLabel => 'Name';

  @override
  String get mealsFoodsHeading => 'Foods';

  @override
  String get mealsIngredientsHeading => 'Ingredients (whole batch)';

  @override
  String get mealsAddFood => 'Add food';

  @override
  String get mealsAddIngredient => 'Add ingredient';

  @override
  String mealsRemoveFood(String name) {
    return 'Remove $name';
  }

  @override
  String get mealsServingsLabel => 'Servings the batch makes';

  @override
  String get mealsServingsHelper =>
      'However many you divide it into. Nothing is guessed.';

  @override
  String get mealsWeightLabel => 'Weight of the finished batch (optional)';

  @override
  String get mealsWeightHelper =>
      'Weigh it once it’s made to log portions in grams. The raw ingredients’ weight is never used for this.';

  @override
  String get mealsTotalHeading => 'Whole meal';

  @override
  String get mealsBatchHeading => 'Whole batch';

  @override
  String get mealsPerServingHeading => 'One serving';

  @override
  String get mealsSomeMissing =>
      'Some foods have no value for a nutrient: figures marked “known” are sums of what is known, not full totals.';

  @override
  String get mealsSaveAsNew => 'Save as new';

  @override
  String get mealsDiscard => 'Discard changes';

  @override
  String get mealsDiscardTitle => 'Discard your changes?';

  @override
  String get mealsDiscardBody => 'The saved version stays as it was.';

  @override
  String get mealsDiscardBodyNew =>
      'This unsaved meal is removed from this phone.';

  @override
  String get mealsResumed => 'Your unsaved changes from before are back.';

  @override
  String get mealsChangedElsewhereTitle => 'Changed on another device';

  @override
  String get mealsChangedElsewhereBody =>
      'This was changed on another device since you started. Save your version over it?';

  @override
  String get mealsSaveMine => 'Save mine';

  @override
  String get mealsDeletedElsewhere =>
      'This was deleted on another device. Use Save as new to keep it.';

  @override
  String get mealsProblemNoName => 'Give it a name.';

  @override
  String get mealsProblemNameTooLong =>
      'The name is too long (120 characters at most).';

  @override
  String get mealsProblemNoFoods => 'Add at least one food.';

  @override
  String get mealsProblemTooMany => '30 foods at most.';

  @override
  String get mealsProblemBadQuantity => 'Every amount must be more than 0.';

  @override
  String get mealsProblemBadServings =>
      'Enter how many servings the batch makes (more than 0, at most 1,000).';

  @override
  String get mealsProblemBadWeight =>
      'Enter the finished weight in grams (more than 0), or leave it empty.';

  @override
  String get mealsProblemTooLarge =>
      'This is too large to save. Remove some foods.';

  @override
  String get mealsProblemBadMultiplier =>
      'Enter a multiplier above 0, at most 20.';

  @override
  String get mealsProblemBadPortion => 'Enter how much you had (more than 0).';

  @override
  String get foodProblemTooLarge =>
      'This food’s details are too large to save.';

  @override
  String get mealsUseAmount => 'Use this amount';

  @override
  String get mealsReviewNote =>
      'Check the amounts. Nothing is logged until you confirm.';

  @override
  String get mealsAmountsHeading => 'Amounts this time';

  @override
  String get mealsMultiplierCustom => 'Other…';

  @override
  String get mealsMultiplierTitle => 'Multiply every amount';

  @override
  String get mealsMultiplierLabel => 'Multiplier';

  @override
  String mealsMultiplierSaid(String value) {
    return '$value times every amount';
  }

  @override
  String get mealsLogMeal => 'Log meal';

  @override
  String get mealsLogPortion => 'Log portion';

  @override
  String mealsLogged(String meal) {
    return 'Logged to $meal.';
  }

  @override
  String get mealsPortionChanged => 'Portion updated.';

  @override
  String get mealsUpdateSaved => 'Update saved meal';

  @override
  String get mealsUpdateTitle => 'Update the saved meal?';

  @override
  String mealsUpdateBody(String name) {
    return 'The amounts shown become $name’s saved amounts, as one meal. Nothing is logged, and food you logged before doesn’t change.';
  }

  @override
  String get mealsUpdated => 'Saved meal updated. Nothing was logged.';

  @override
  String get mealsSaveAsNewTitle => 'Save as a new meal';

  @override
  String mealsSaveAsNewBody(String name) {
    return 'The amounts shown are saved as one new meal. $name stays as it is, and nothing is logged.';
  }

  @override
  String get mealsSavedNew => 'Saved as a new meal. Nothing was logged.';

  @override
  String get mealsPortionHeading => 'How much you had';

  @override
  String get mealsPortionAmount => 'Amount';

  @override
  String get mealsMeasureServings => 'Servings';

  @override
  String get mealsMeasureGrams => 'Grams';

  @override
  String get mealsNoWeight =>
      'To log grams, add the finished batch’s weight to the recipe.';

  @override
  String mealsThisPortion(String amount) {
    return 'This portion: $amount';
  }

  @override
  String get mealsThisTimeIngredients => 'Ingredients this time (whole batch)';

  @override
  String get mealsThisTimeNote =>
      'Changes here are for this portion only. The saved recipe stays as it is.';

  @override
  String get mealsThisTimeChanged =>
      'Changed for this portion only. To change the recipe itself, use Edit recipe.';

  @override
  String get mealsThisTimeTotal => 'This time';

  @override
  String get eatOutTitle => 'Eating out';

  @override
  String get eatOutEntrySubtitle =>
      'Verified Canadian menus: choose or improve an order';

  @override
  String get eatOutPanelBody => 'Find a restaurant order that fits your goals.';

  @override
  String get eatOutPanelAction => 'Choose a restaurant';

  @override
  String get eatHintEatingOut =>
      'Eating out today? I can help you choose an order—or improve the one you want.';

  @override
  String get eatHintEatingOutAction => 'Find an order';

  @override
  String eatOutForContext(String meal, String date) {
    return 'For $meal · $date';
  }

  @override
  String eatOutChainContext(String chain, String meal, String date) {
    return '$chain · Canada · $meal · $date';
  }

  @override
  String get eatOutChooseChain => 'Choose a restaurant';

  @override
  String eatOutChainCanada(String chain) {
    return '$chain · Canada';
  }

  @override
  String eatOutChainOptions(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verified options',
      one: '1 verified option',
    );
    return '$_temp0 · checked $date';
  }

  @override
  String get eatOutChainUnavailable => 'Menu not added yet: no verified data';

  @override
  String eatOutChainNotYet(String chain) {
    return 'No verified $chain menu yet';
  }

  @override
  String get eatOutChainBlocked =>
      'GoHard only offers items whose nutrition comes from the chain\'s own published Canadian information. This chain\'s official data couldn\'t be read in yet, so nothing is offered rather than a guess. You can still log your own entry from Add food.';

  @override
  String get eatOutChangeChain => 'Change restaurant';

  @override
  String get eatOutCoverageNote =>
      'A selection of standard items, not the full menu. Not every location sells every item. Prices, ordering and delivery aren\'t part of GoHard.';

  @override
  String eatOutAskLabel(String guide) {
    return 'Ask $guide about eating out';
  }

  @override
  String get eatOutAskHint =>
      'Tell me what you want, e.g. keep the potato rings, more protein';

  @override
  String get eatOutAskUnavailable =>
      'Asking in words isn\'t available on this server. Targets, the menu and suggestions all work without it.';

  @override
  String get eatOutAskInvalid =>
      'That request couldn\'t be sent. Shorten it (up to 600 characters) and send it again.';

  @override
  String get eatOutProblemLimit =>
      'You\'ve asked a lot today. Asking in words works again later; targets and the menu still work.';

  @override
  String get eatOutProblemBusy =>
      'The assistant is busy right now. Your request is kept; try again in a moment.';

  @override
  String get eatOutProblemUnreached =>
      'Your request couldn\'t be sent: that can be this phone\'s connection or the server. It\'s kept, and the menu works offline.';

  @override
  String get eatOutProblemUnavailable =>
      'The assistant isn\'t available right now. Your request is kept; targets and the menu still work.';

  @override
  String get eatOutStale =>
      'Your order or targets changed while I was reading that. Nothing was changed: send it again to use what you have now.';

  @override
  String get eatOutMenuChanged =>
      'The menu was updated on the server. Update it here before asking again.';

  @override
  String get eatOutUpdateMenu => 'Update menu';

  @override
  String eatOutSwitchTo(String chain) {
    return 'Switch to $chain';
  }

  @override
  String get eatOutCoachIntro =>
      'Eating out? Tell me where you\'re going and what you want to keep.';

  @override
  String eatOutCoachChain(String chain) {
    return 'Set a calorie limit or a protein target, or tell me what you\'d like at $chain. I\'ll show orders that fit.';
  }

  @override
  String get eatOutCoachImprove =>
      'Want to change something in your order? Tell me what to keep and what matters most.';

  @override
  String get eatOutCoachReading => 'Reading your request…';

  @override
  String get eatOutCoachUnderstood =>
      'Here\'s what I understood: check your targets below and change anything I got wrong. Every number comes from the verified menu.';

  @override
  String eatOutCoachUnknown(String names) {
    return 'I couldn\'t find $names on this menu.';
  }

  @override
  String get eatOutCoachUnsupported =>
      'I only have verified menus for the restaurants listed here, so I can\'t help with that one.';

  @override
  String get eatOutCoachContradiction =>
      'Your request asks for two things that rule each other out. Which one should I keep?';

  @override
  String get eatOutCoachClarify =>
      'Could you say a bit more? For example a calorie limit, or which item and size you mean.';

  @override
  String eatOutCoachAsks(String question) {
    return '$question';
  }

  @override
  String get eatOutYourTargets => 'Your targets';

  @override
  String get eatOutNoTargetsYet => 'None yet. Nothing is chosen for you.';

  @override
  String eatOutChipMax(String kcal) {
    return 'Up to $kcal kcal';
  }

  @override
  String eatOutChipMin(String kcal) {
    return 'At least $kcal kcal';
  }

  @override
  String eatOutChipProtein(String grams) {
    return 'At least $grams g protein';
  }

  @override
  String eatOutChipKeep(String name, int count) {
    return 'Keep $name × $count';
  }

  @override
  String eatOutChipExclude(String name) {
    return 'Not $name';
  }

  @override
  String eatOutChipPrefer(String kind) {
    return 'Prefer: $kind';
  }

  @override
  String eatOutChipAvoid(String kind) {
    return 'Avoid: $kind';
  }

  @override
  String eatOutRemoveTarget(String target) {
    return 'Remove $target';
  }

  @override
  String get eatOutHelpChoose => 'Help me choose';

  @override
  String eatOutYourOrder(int count) {
    return 'Your order ($count)';
  }

  @override
  String get eatOutNoTargetsTitle => 'What should an order fit?';

  @override
  String get eatOutNoTargetsBody =>
      'Set a calorie limit or a protein target, or ask me in your own words. You can also build an order yourself.';

  @override
  String get eatOutSetTargets => 'Set targets';

  @override
  String eatOutSortedBy(String priority) {
    return 'Sorted by: $priority';
  }

  @override
  String get eatOutPriorityProtein => 'most protein';

  @override
  String get eatOutPriorityCalories => 'fewest calories';

  @override
  String get eatOutPriorityClosest => 'closest to your calorie limit';

  @override
  String get eatOutNoneFits =>
      'Nothing fits all your targets. These are the closest, with what each one misses. Kept and excluded items are never changed.';

  @override
  String get eatOutNothingPossible =>
      'No order can be built from these choices. Remove an excluded item or kind.';

  @override
  String get eatOutContradiction =>
      'The minimum is above the maximum, or an item is both kept and excluded. Change one of them.';

  @override
  String eatOutLine(int count, String name) {
    return '$count × $name';
  }

  @override
  String eatOutProteinValue(String grams) {
    return '$grams g protein';
  }

  @override
  String get eatOutFits => 'Fits your selected targets.';

  @override
  String eatOutKeeps(String names) {
    return 'Keeps $names.';
  }

  @override
  String eatOutMisses(String misses) {
    return 'Misses: $misses';
  }

  @override
  String eatOutMissOver(String kcal) {
    return '$kcal kcal over your limit';
  }

  @override
  String eatOutMissUnder(String kcal) {
    return '$kcal kcal under your minimum';
  }

  @override
  String eatOutMissProtein(String grams) {
    return '$grams g protein short';
  }

  @override
  String eatOutVersusOrder(String kcal, String protein) {
    return 'Compared with your order: $kcal kcal, $protein g protein';
  }

  @override
  String get eatOutUseOrder => 'Use this order';

  @override
  String get eatOutUseInstead => 'Use instead of my order';

  @override
  String get eatOutOrderEmptyTitle => 'No items yet';

  @override
  String get eatOutOrderEmptyBody =>
      'Add items from the menu, or choose a suggestion. Nothing is logged until you review it.';

  @override
  String get eatOutAddFromMenu => 'Add from the menu';

  @override
  String eatOutMenuTitle(String chain) {
    return '$chain menu · Canada';
  }

  @override
  String get eatOutMenuFilter => 'Filter the menu';

  @override
  String eatOutAddItem(String name) {
    return 'Add $name';
  }

  @override
  String eatOutInOrder(int count) {
    return '$count in order';
  }

  @override
  String eatOutEach(String kcal) {
    return '$kcal kcal each';
  }

  @override
  String eatOutLess(String name) {
    return 'One less $name';
  }

  @override
  String eatOutMore(String name) {
    return 'One more $name';
  }

  @override
  String eatOutCountSaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String eatOutNoLongerListed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items are no longer on this menu.',
      one: '1 item is no longer on this menu.',
    );
    return '$_temp0';
  }

  @override
  String get eatOutRemoveThem => 'Remove';

  @override
  String get eatOutOrderTotal => 'Order total';

  @override
  String eatOutSodium(String mg) {
    return 'Sodium $mg mg';
  }

  @override
  String get eatOutReview => 'Review and log';

  @override
  String eatOutOrderName(String chain) {
    return '$chain order';
  }

  @override
  String eatOutSourceLine(String source, String published, String checked) {
    return 'Source: $source. Published: $published. Checked $checked.';
  }

  @override
  String get eatOutNotStated => 'not stated';

  @override
  String get eatOutCustomNote =>
      'Only listed items and sizes are calculated. A change such as no sauce or extra cheese has no verified values, so it can\'t be calculated reliably.';

  @override
  String get eatOutOwnEstimate => 'Log your own estimate instead';

  @override
  String get eatOutTargetsTitle => 'Targets for this order';

  @override
  String get eatOutTargetsNote =>
      'For this meal only, not your daily goals. Leave any field blank.';

  @override
  String get eatOutTargetMax => 'Maximum calories';

  @override
  String get eatOutTargetMin => 'Minimum calories';

  @override
  String get eatOutTargetProtein => 'Minimum protein';

  @override
  String get eatOutSortLabel => 'When several orders fit, show first';

  @override
  String get eatOutSortAutomatic => 'Automatic (from your targets)';

  @override
  String get eatOutApplyTargets => 'Use these targets';

  @override
  String get eatOutTargetsInvalid =>
      'Use whole numbers: calories 100 to 4,000 (minimum from 0), protein 1 to 300 g.';

  @override
  String get eatOutKindSandwich => 'sandwich';

  @override
  String get eatOutKindWrap => 'wrap';

  @override
  String get eatOutKindSalad => 'salad';

  @override
  String get eatOutKindBowl => 'bowl';

  @override
  String get eatOutKindBreakfast => 'breakfast';

  @override
  String get eatOutKindPizza => 'pizza';

  @override
  String get eatOutKindChicken => 'chicken';

  @override
  String get eatOutKindSide => 'side';

  @override
  String get eatOutKindDessert => 'dessert';

  @override
  String get eatOutKindDrink => 'drink';

  @override
  String eatOutChainOfficial(String chain) {
    return '$chain Canada\'s published nutrition information';
  }

  @override
  String eatOutPublished(String date) {
    return 'published $date';
  }

  @override
  String eatOutChecked(String date) {
    return 'checked $date';
  }

  @override
  String eatOutBuildNote(String note) {
    return 'Standard build: $note';
  }

  @override
  String get eatOutSodiumLabel => 'Sodium';

  @override
  String get eatOutFibreLabel => 'Fibre';

  @override
  String get eatOutSatFatLabel => 'Saturated fat';

  @override
  String get dcTitle => 'Help with today';

  @override
  String dcAboutDay(String date) {
    return 'About $date';
  }

  @override
  String get dcEarlierDay => 'This is an earlier day, not today.';

  @override
  String get dcPrivacy =>
      'When you type a request, your words and the names of your saved meals, recipes and foods are sent to read it. Your journal, goals and numbers are not sent: every number is worked out on this phone.';

  @override
  String get dcIntro =>
      'I can sum up today, show what\'s in your journal, and suggest portions from your saved meals, recipes and foods. Every number comes from your own records, and nothing is logged until you choose Log.';

  @override
  String get dcInputHint => 'Ask about today or food';

  @override
  String get dcNoAi =>
      'Typed requests aren\'t available on this server. The suggested requests above still work.';

  @override
  String get dcWaiting => 'Reading your request…';

  @override
  String get dcStillWorks =>
      'Your journal, saved meals and the suggested requests still work.';

  @override
  String get dcAiRead => 'Request read by AI · numbers from your records';

  @override
  String get dcBuiltIn => 'Built in · from your records';

  @override
  String dcBasisToday(String date) {
    return 'Today, $date: your plan and journal on this phone';
  }

  @override
  String dcBasisDay(String date) {
    return '$date: your journal on this phone';
  }

  @override
  String dcSwitchedToToday(String date) {
    return 'Switched to today, $date.';
  }

  @override
  String get dcStale => 'Your records changed since this answer.';

  @override
  String get dcRecalculate => 'Recalculate';

  @override
  String get dcStaleReview =>
      'This changed since the suggestion. Recalculate it first.';

  @override
  String get dcTrainingLoading => 'Today\'s training is still loading.';

  @override
  String get dcTrainingNoPlan => 'No training plan is active.';

  @override
  String get dcTrainingNothingDefinite =>
      'Nothing definite is planned for training today.';

  @override
  String dcWorkoutsRecorded(String count) {
    return 'Workouts finished today: $count.';
  }

  @override
  String get dcNoWorkoutRecorded => 'No workout is recorded today.';

  @override
  String get dcRunOpen => 'A run or walk is in progress.';

  @override
  String get dcJournalLoading => 'The journal for this day is still loading.';

  @override
  String get dcJournalEmpty =>
      'Nothing is in the journal for this day yet. That only means nothing was logged.';

  @override
  String dcJournalLine(String count, String kcal, String protein) {
    return 'Foods in the journal: $count · $kcal · $protein';
  }

  @override
  String get dcLoggedOnly =>
      'This is what was logged, which may not be everything eaten.';

  @override
  String get dcTodayChoice => 'What would you like to look at?';

  @override
  String get dcPending =>
      'Some changes on this phone haven\'t reached your account yet. I\'m using what\'s on this phone; something saved only here can\'t be found by name until it syncs.';

  @override
  String dcProteinKnown(String value) {
    return '$value g protein known';
  }

  @override
  String get dcProteinUnknown => 'Protein unknown';

  @override
  String dcTimesSaved(String value) {
    return '$value× the saved amounts';
  }

  @override
  String get dcGoalProteinNotSet =>
      'You haven\'t set a daily protein goal. You can set one in Eat, or tell me what you\'d like from this meal.';

  @override
  String get dcGoalCaloriesNotSet =>
      'You haven\'t set a daily calorie goal. You can set one in Eat, or tell me what you\'d like from this meal.';

  @override
  String dcGoalProteinNone(String goal) {
    return 'No protein is logged yet today. Your goal is $goal g.';
  }

  @override
  String dcGoalProteinPartial(String known, String goal) {
    return 'At least $known g of protein is known so far toward your $goal g goal. Some foods have no protein value, so the exact gap is not known.';
  }

  @override
  String dcGoalProteinReached(String logged, String goal) {
    return '$logged g of protein is logged; your goal is $goal g.';
  }

  @override
  String dcGoalProteinLeft(String logged, String goal, String left) {
    return '$logged g of your $goal g protein goal is logged: $left g to go.';
  }

  @override
  String dcGoalKcalNone(String goal) {
    return 'No calories are logged yet today. Your goal is $goal kcal.';
  }

  @override
  String dcGoalKcalPartial(String known, String goal) {
    return 'At least $known kcal is known so far toward your $goal kcal goal. Some foods have no calorie value, so the exact gap is not known.';
  }

  @override
  String dcGoalKcalReached(String logged, String goal) {
    return '$logged kcal is logged; your goal is $goal kcal.';
  }

  @override
  String dcGoalKcalLeft(String logged, String goal, String left) {
    return '$logged of your $goal kcal goal is logged: $left kcal left.';
  }

  @override
  String get dcGoalNotMealSize =>
      'A daily goal isn\'t a meal size: choose what suits this meal.';

  @override
  String get dcFromSaved => 'From your saved meals, recipes and foods:';

  @override
  String get dcNoItems =>
      'You have no saved meals, recipes or favourite foods yet, so I have nothing of yours to suggest. Find a food in Add food, or try Eating out.';

  @override
  String get dcNoProteinKnown =>
      'None of your saved items has a known value for that.';

  @override
  String dcUnderKcal(String kcal) {
    return 'at most $kcal kcal';
  }

  @override
  String dcAtLeastProtein(String g) {
    return 'at least $g g protein';
  }

  @override
  String get dcAnd => ' and ';

  @override
  String dcFitsHeading(String targets) {
    return 'These fit $targets:';
  }

  @override
  String dcNothingFits(String targets) {
    return 'Nothing saved fits $targets. The nearest, with what each misses:';
  }

  @override
  String dcNothingKnownFits(String targets) {
    return 'I can\'t check $targets: your saved items don\'t have those values known.';
  }

  @override
  String get dcUnknownLeftOut =>
      'Items with an unknown value for these targets were left out.';

  @override
  String get dcChangeWhich => 'Which target would you like to change?';

  @override
  String dcMisses(String misses) {
    return 'Misses: $misses';
  }

  @override
  String dcMissOverKcal(String kcal) {
    return '$kcal kcal over';
  }

  @override
  String dcMissUnderProtein(String g) {
    return '$g g protein short';
  }

  @override
  String dcAddsProtein(String adds, String total, String goal) {
    return 'Adds $adds g protein: $total of $goal g logged after this.';
  }

  @override
  String dcAddsKcal(String adds, String total, String goal) {
    return 'Adds $adds kcal: $total of $goal kcal logged after this.';
  }

  @override
  String get dcChoose => 'I found more than one. Which do you mean?';

  @override
  String get dcThatItem => 'that item';

  @override
  String dcNotFound(String names) {
    return 'I couldn\'t find $names in your saved meals, recipes or foods. Find it in Add food, or save it as a meal.';
  }

  @override
  String get dcNeedItem => 'Which saved meal, recipe or food do you mean?';

  @override
  String get dcSmallest =>
      'That\'s the smallest practical portion I can suggest for this.';

  @override
  String get dcLargest =>
      'That\'s the largest practical portion I can suggest for this.';

  @override
  String get dcCantGrams =>
      'This can\'t be measured in grams: its finished weight isn\'t known. Use servings, or weigh the batch in the recipe.';

  @override
  String get dcCantMeasure =>
      'That amount doesn\'t fit how this is measured. Try servings or a multiplier.';

  @override
  String dcMoreProtein(String more, String diff, String less) {
    return '$more has $diff g more protein than $less.';
  }

  @override
  String dcMoreKcal(String more, String diff, String less) {
    return '$more has $diff kcal more than $less.';
  }

  @override
  String get dcSameProtein => 'They have the same protein.';

  @override
  String get dcSameKcal => 'They have the same calories.';

  @override
  String get dcCompareUnknown =>
      'Some values are unknown for one of them, so I can\'t compare those.';

  @override
  String get dcTraining =>
      'Questions about your workouts and plan go to Ask GoHard, the training assistant.';

  @override
  String get dcRestaurant =>
      'Restaurant orders are in Eating out, with verified menus.';

  @override
  String get dcClarify =>
      'Could you say a bit more? For example which saved meal, or a calorie limit for this meal.';

  @override
  String get dcUnsupported =>
      'I can help with today\'s plan and records, and with food from your saved meals, recipes and foods. I can\'t help with medical or health questions.';

  @override
  String get dcActionReview => 'Review portion';

  @override
  String get dcActionWorkout => 'View workout';

  @override
  String get dcActionJournal => 'Open journal';

  @override
  String get dcActionGoals => 'Edit goals';

  @override
  String get dcActionAddFood => 'Find a food';

  @override
  String get dcActionTraining => 'Ask about training';

  @override
  String get dcActionChooseMeal => 'Choose a meal';

  @override
  String get dcChipToday => 'Help me with today';

  @override
  String get dcChipRecorded => 'What have I recorded today?';

  @override
  String get dcChipProtein => 'Help me reach my protein goal';

  @override
  String get dcChipSaved => 'What could I have from my saved meals?';

  @override
  String get dcChipSmaller => 'Make that a smaller portion';

  @override
  String dcOpenWith(String guide) {
    return 'Help with today: open the conversation with $guide';
  }

  @override
  String get dcProblemLimit =>
      'You\'ve asked a lot today. Typed requests will work again later; the suggested requests still work.';

  @override
  String get dcProblemBusy =>
      'Reading requests is busy right now. Try again in a moment.';

  @override
  String get dcProblemUnreached =>
      'Your request couldn\'t be sent. That can be this phone\'s connection or the server.';

  @override
  String get dcProblemInterrupted =>
      'This request didn\'t get an answer before the app closed. Retry to ask again.';

  @override
  String get dcProblemUnavailable =>
      'Reading typed requests isn\'t available right now. Your request is kept.';

  @override
  String habitUsualName(String meal) {
    return '$meal (usual)';
  }

  @override
  String habitSay(String meal) {
    return 'Your usual $meal? Review it or choose something else.';
  }

  @override
  String habitSaySaved(String meal, String name) {
    return 'Your usual $meal: $name? Review it or choose something else.';
  }

  @override
  String habitWhy(String meal, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Logged at $meal on $count recent days.',
      one: 'Logged at $meal on 1 recent day.',
    );
    return '$_temp0';
  }

  @override
  String get habitReview => 'Review usual meal';

  @override
  String get habitOther => 'Choose something else';

  @override
  String get habitNotToday => 'Not today';

  @override
  String get habitSettingTitle => 'Meal suggestions';

  @override
  String get habitSettingBody =>
      'GoHard can notice meals you log again and again and offer them on Eat: “Your usual breakfast?” You always choose: nothing is logged, changed or scheduled for you. It is worked out on this phone from your own journal, and nothing is sent anywhere.';

  @override
  String habitSettingRules(int minDays, int windowDays) {
    return 'A suggestion needs the same foods, logged at the same meal, on at least $minDays different days in the last $windowDays days. Foods typed by hand are left out, and an old habit stops being suggested by itself.';
  }

  @override
  String get habitSettingSwitch => 'Suggest my usual meals';

  @override
  String get habitSettingOffNote =>
      'Turning this off keeps every journal entry and saved meal.';

  @override
  String get habitIntro =>
      'I can notice meals you log often and suggest them here. You always choose, and nothing is logged for you. Turn this on?';

  @override
  String get habitTurnOn => 'Turn on';

  @override
  String get habitNotNow => 'Not now';

  @override
  String get mealsLogThisTime => 'Log this time';

  @override
  String get mealsSaveVariation => 'Save as a variation';

  @override
  String get mealsSaveVariationTitle => 'Save as a variation';

  @override
  String mealsVariationName(String name) {
    return '$name (variation)';
  }

  @override
  String get mealsSaveAsMealBody =>
      'The foods and amounts shown become a saved meal. Nothing is logged.';

  @override
  String get mealsReviewActionsNote =>
      'Log this time records these amounts only; the saved meal stays as it is. Update saved meal changes it for next time. Nothing already logged changes.';

  @override
  String get dcIngredientMealOnly =>
      'I can change one food inside a saved meal. For a recipe or a food, change the amount in its review.';

  @override
  String dcIngredientWhich(String meal) {
    return 'Which food in $meal?';
  }

  @override
  String dcIngredientNotFound(String words, String meal) {
    return 'I could not find “$words” in $meal. Here it is as saved; you can change any food in the review.';
  }

  @override
  String dcIngredientNeedAmount(String food) {
    return 'How much $food this time? Say it in grams or servings, or change it in the review.';
  }

  @override
  String dcIngredientCantGrams(String food) {
    return '$food in this meal has no weight, so grams cannot be used. Use its own unit in the review.';
  }

  @override
  String dcIngredientCantMeasure(String food) {
    return '$food cannot be measured that way. Change its amount in the review.';
  }

  @override
  String dcIngredientLine(String meal, String amount, String food) {
    return '$meal with $amount of $food this time. Your saved meal stays as it is unless you update it.';
  }

  @override
  String dcIngredientAmount(String food, String amount) {
    return '$food: $amount this time';
  }

  @override
  String get reminderDoseBody => 'Tap to confirm in GoHard.';

  @override
  String get reminderTaken => 'Taken';

  @override
  String get reminderSnooze => 'Snooze';

  @override
  String get reminderSkip => 'Skip';

  @override
  String get reminderMealChannelName => 'Meal reminders';

  @override
  String get reminderMealChannelDescription =>
      'Reminders to log a meal, at times you chose';

  @override
  String get reminderDoseChannelName => 'Medication and supplement reminders';

  @override
  String get reminderDoseChannelDescription =>
      'Your own medication and supplement reminders';

  @override
  String get reminderCategoryMeal => 'Meal';

  @override
  String get reminderCategoryMedication => 'Medication';

  @override
  String get reminderCategorySupplement => 'Supplement';

  @override
  String get reminderEveryDay => 'Every day';

  @override
  String get reminderWeekdays => 'Monday to Friday';

  @override
  String get reminderNotAllowed =>
      'Saved. Notifications are not allowed for GoHard, so it cannot appear yet. You can allow them in the phone’s settings.';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersSubtitle =>
      'Phone notifications you set up. Nothing is scheduled until you add one.';

  @override
  String meRemindersPageSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count on',
      one: '1 on',
      zero: 'None on',
    );
    return '$_temp0';
  }

  @override
  String get reminderDenied =>
      'Notifications are off for GoHard in the phone’s settings, so these reminders cannot appear.';

  @override
  String get reminderTodayHeading => 'Today';

  @override
  String get reminderWorkoutHeading => 'Workouts';

  @override
  String get reminderOwnHeading => 'Meals, medication and supplements';

  @override
  String get reminderNone => 'None yet.';

  @override
  String get reminderPaused => 'Paused';

  @override
  String get reminderAdd => 'Add a reminder';

  @override
  String reminderThrough(String date) {
    return 'Scheduled through $date. Opening GoHard schedules the following days.';
  }

  @override
  String get reminderPolicy =>
      'Times are local: a reminder set for 8:00 comes at 8:00 wherever the phone is, and follows daylight saving time. On a day when that time does not exist it comes just after the change; when it happens twice it comes once. GoHard schedules the next 7 days whenever it is opened. The phone decides the exact moment, so a reminder can arrive a little late. A meal reminder is not sent once that meal is logged on this phone that day. Reminders and answers are kept on this phone for this account only: they are not saved to your account or sent to any AI.';

  @override
  String get reminderUnconfirmed => 'Unconfirmed';

  @override
  String get reminderStatusTaken => 'Taken';

  @override
  String get reminderStatusSkipped => 'Skipped';

  @override
  String get reminderStatusSnoozed => 'Snoozed';

  @override
  String reminderOccurrence(String date, String time) {
    return '$date at $time';
  }

  @override
  String reminderSnoozeFor(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Snooze $minutes minutes',
      one: 'Snooze 1 minute',
    );
    return '$_temp0';
  }

  @override
  String reminderMealDefaultName(String meal) {
    return 'Log $meal';
  }

  @override
  String get reminderProblemName =>
      'Give the reminder a name (up to 60 characters).';

  @override
  String get reminderProblemTime => 'Choose a time.';

  @override
  String get reminderProblemDays => 'Choose at least one day.';

  @override
  String get reminderSaved => 'Reminder saved.';

  @override
  String reminderDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get reminderDeleteBody =>
      'Its notifications are cancelled. Answers you already gave stay on this phone.';

  @override
  String get reminderNewTitle => 'New reminder';

  @override
  String get reminderEditTitle => 'Edit reminder';

  @override
  String get reminderNameLabel => 'Name';

  @override
  String get reminderDoseNameLabel => 'Name, as you want to see it';

  @override
  String reminderSuggestedTime(String meal, String time) {
    return 'You often log $meal around $time. Use that time?';
  }

  @override
  String reminderUseTime(String time) {
    return 'Use $time';
  }

  @override
  String get reminderOwnTime => 'Choose my own time';

  @override
  String get reminderTimeLabel => 'Time';

  @override
  String get reminderDaysLabel => 'Days';

  @override
  String get reminderInstructionsLabel => 'Instructions (optional)';

  @override
  String get reminderInstructionsHelp =>
      'Your own words, such as what your prescriber or the label says. GoHard never suggests a dose or a schedule.';

  @override
  String get reminderPrivateLabel => 'Hide details on the lock screen';

  @override
  String get reminderPrivateHelp =>
      'The notification says only “Time for your medication” or “Time for your supplement”: no name, dose or instructions.';

  @override
  String get reminderOnLabel => 'On';

  @override
  String get reminderMealNote =>
      'If that meal is already logged on this phone that day, the reminder is not sent.';

  @override
  String get reminderDoseNote =>
      'A reminder only reminds you and lets you confirm; it is not medical advice. If you do not answer, it stays Unconfirmed.';

  @override
  String reminderSuggestSay(String meal, String time) {
    return 'You often log $meal around $time. Want a reminder to log it?';
  }

  @override
  String get reminderAddThis => 'Add a reminder';

  @override
  String get eatMealReminders => 'Meal reminders';

  @override
  String reminderMealTitle(String meal) {
    return 'Time to log $meal.';
  }

  @override
  String get reminderMealTap => 'Tap to open Eat.';

  @override
  String get reminderHiddenMedication => 'Time for your medication.';

  @override
  String get reminderHiddenSupplement => 'Time for your supplement.';

  @override
  String ebPastEmpty(String day) {
    return 'Nothing was recorded on $day.';
  }

  @override
  String ebPast(String day, String totals) {
    return 'On $day you recorded $totals.';
  }

  @override
  String ebPastOver(String kcal) {
    return 'That is $kcal kcal above your target.';
  }

  @override
  String ebPastUnder(String kcal) {
    return 'That is $kcal kcal under your target.';
  }

  @override
  String ebAtLeastKcal(String kcal) {
    return 'at least $kcal kcal';
  }

  @override
  String ebAtLeastProtein(String protein) {
    return 'at least $protein g protein';
  }

  @override
  String ebEmpty(String meal) {
    return 'Nothing logged yet today. Want ideas for $meal?';
  }

  @override
  String ebOver(String kcal) {
    return 'Today’s recorded calories are $kcal kcal above your target. That’s okay. If you’re still hungry, I can suggest lighter options.';
  }

  @override
  String ebNear(String kcal) {
    return 'You’re near your calorie target ($kcal kcal left), with time left in the day. Want help planning your next meal?';
  }

  @override
  String ebProteinReached(String protein, String goal) {
    return 'You’ve reached your protein goal: $protein g of $goal g. Want ideas for your next meal?';
  }

  @override
  String ebUnknownKcal(String kcal) {
    return 'Some foods today have no calorie value, so the total is incomplete: at least $kcal kcal recorded. Want some options?';
  }

  @override
  String ebProteinIncomplete(String protein) {
    return 'At least $protein g protein recorded; some values are missing.';
  }

  @override
  String ebProteinLeft(String protein) {
    return '$protein g protein left.';
  }

  @override
  String ebOverPlain(String kcal) {
    return 'Recorded calories are $kcal kcal above your target today.';
  }

  @override
  String ebLeftBoth(String kcal, String protein) {
    return 'You have $kcal kcal and $protein g protein left. Want some options?';
  }

  @override
  String ebKcalLeft(String kcal) {
    return 'You have $kcal kcal left today.';
  }

  @override
  String get ebProteinDone => 'Protein goal reached.';

  @override
  String get ebWantOptions => 'Want some options?';

  @override
  String ebLogged(String meal) {
    return '$meal is logged. Want ideas for your next meal?';
  }

  @override
  String get ebIdeas => 'What could I eat?';

  @override
  String get ebSetGoals => 'Set goals';

  @override
  String get ebSettingTitle => 'Nutrition heads-ups';

  @override
  String get ebSettingBody =>
      'On Eat, Leon or Leona can say when you are near or above your calorie target, or when your protein goal is reached, once a day each. They only appear inside GoHard, never as notifications, and are not medical advice.';

  @override
  String get ebSettingSwitch => 'Show nutrition heads-ups';

  @override
  String get dcIdeasToday =>
      'Ideas are for today. For an earlier day, add what was eaten with Choose something else.';

  @override
  String get dcEatIntro =>
      'A few ways to go. For new ideas, ask for something specific, like “something quick with more protein”.';

  @override
  String get dcNoIdeas =>
      'No idea fits that. Try other words, or choose something yourself.';

  @override
  String get dcIdeasHeading =>
      'Ideas, with every value worked out from food records:';

  @override
  String get dcNoPrices => 'GoHard has no prices, so it can’t check cost.';

  @override
  String get dcNotTimed =>
      'GoHard doesn’t know preparation times; check the foods.';

  @override
  String get dcNotChecked =>
      'GoHard doesn’t check dietary labels such as vegetarian; check the foods.';

  @override
  String get dcIdeaQuickProtein => 'Something quick with more protein';

  @override
  String get dcIdeaSweet => 'Something sweet';

  @override
  String get dcIdeaNoCooking => 'No cooking';

  @override
  String get dcIdeaVegetarian => 'A vegetarian meal';

  @override
  String get dcIdeaDifferent => 'Something different from my usual';

  @override
  String dcIdeaNeedsMatch(String foods) {
    return 'Needs a food match: $foods. No totals until it is found.';
  }

  @override
  String get dcIdeaUnknownTarget =>
      'Some values are missing, so GoHard can’t say whether it meets what you asked.';

  @override
  String get dcIdeaCalculated => 'Calculated from food records.';

  @override
  String get dcIdeaLabel => 'An idea from Leon or Leona';

  @override
  String dcIdeaUnmatchedFood(String food) {
    return '$food (not matched yet)';
  }

  @override
  String get dcReviewMeal => 'Review meal';

  @override
  String get dcFindFood => 'Find food';

  @override
  String get dcAnotherIdea => 'Other ideas';

  @override
  String get dcAnotherIdeaText => 'Other ideas, different from these';

  @override
  String get dcIdeaConfirm => 'Confirm the foods below to see totals.';

  @override
  String dcIdeaWhich(String food) {
    return 'Which $food?';
  }

  @override
  String dcIdeaAmountNeeded(String food) {
    return 'How much $food? The proposed amount does not fit this food’s units.';
  }

  @override
  String get dcChooseAmount => 'Choose amount';

  @override
  String dcIdeaPrepDiffers(String food, String asked) {
    return 'You chose $food, not $asked as the idea said. Amounts differ between preparations, so the proposed amount is not used.';
  }
}
