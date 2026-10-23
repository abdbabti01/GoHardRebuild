import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
    Locale('fr', 'CA'),
  ];

  /// Display name of the male lion coach. Stored ID stays 'leon'. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Leon'**
  String get coachNameLeon;

  /// Display name of the lioness coach. Stored ID stays 'leona'. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Leona'**
  String get coachNameLeona;

  /// What Leon is, in lower case (shown under his name in Appearance). The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'lion'**
  String get coachAnimalLion;

  /// What Leona is, in lower case (shown under her name in Appearance).
  ///
  /// In en, this message translates to:
  /// **'lioness'**
  String get coachAnimalLioness;

  /// Name of the AI conversation feature: screen heading and buttons that open it.
  ///
  /// In en, this message translates to:
  /// **'Ask GoHard'**
  String get coachAskTitle;

  /// Ask GoHard header subtitle beside the coach's name.
  ///
  /// In en, this message translates to:
  /// **'AI training assistant'**
  String get coachAskAiAssistant;

  /// What the conversation is about. label is a split, workout or exercise name (may be user content).
  ///
  /// In en, this message translates to:
  /// **'About: {label}'**
  String coachAskAbout(String label);

  /// Explanation shown in an empty Ask GoHard conversation.
  ///
  /// In en, this message translates to:
  /// **'Ask a question about your plan. Answers are written by AI from your draft and GoHard\'s reviewed guide, so check anything important. Nothing is sent until you press Send.'**
  String get coachAskIntro;

  /// Suggested question chip about an exercise; sent as the question when tapped.
  ///
  /// In en, this message translates to:
  /// **'Why was this exercise included?'**
  String get coachAskSuggestWhyIncluded;

  /// Suggested question chip about an exercise.
  ///
  /// In en, this message translates to:
  /// **'Can I replace it with a dumbbell exercise?'**
  String get coachAskSuggestDumbbell;

  /// Suggested question chip about an exercise's alternatives.
  ///
  /// In en, this message translates to:
  /// **'What are the benefits and trade-offs of these alternatives?'**
  String get coachAskSuggestAlternatives;

  /// Suggested question chip: 3 sets of 8 to 12 repetitions. Keep the notation 3 × 8–12.
  ///
  /// In en, this message translates to:
  /// **'What does 3 × 8–12 mean?'**
  String get coachAskSuggestSetsReps;

  /// Suggested question chip about a workout.
  ///
  /// In en, this message translates to:
  /// **'How could I shorten this workout?'**
  String get coachAskSuggestShorten;

  /// Suggested question chip about a plan's split.
  ///
  /// In en, this message translates to:
  /// **'Why this split for my schedule?'**
  String get coachAskSuggestWhySplit;

  /// Suggested question chip comparing two named splits.
  ///
  /// In en, this message translates to:
  /// **'How does Upper/Lower differ from Push/Pull/Legs?'**
  String get coachAskSuggestCompareSplits;

  /// Confirmation title before clearing the Ask GoHard conversation.
  ///
  /// In en, this message translates to:
  /// **'Clear this conversation?'**
  String get coachAskClearTitle;

  /// Confirmation body before clearing the conversation.
  ///
  /// In en, this message translates to:
  /// **'Its questions and answers are removed from this phone. Your draft is not changed.'**
  String get coachAskClearBody;

  /// Confirm button that clears the conversation.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get coachAskClearAction;

  /// Tooltip of the app bar button that clears the conversation.
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get coachAskClearTooltip;

  /// Hint in the Ask GoHard text field.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get coachAskInputHint;

  /// Tooltip of the send button: sends the question to the AI.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get coachAskSend;

  /// Screen-reader label of the person's own question bubble. text is user content.
  ///
  /// In en, this message translates to:
  /// **'You asked: {text}'**
  String coachAskYouAsked(String text);

  /// Shown while a question is being answered.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an answer'**
  String get coachAskWaiting;

  /// Button that sends the same failed question again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get coachAskRetry;

  /// Button that puts a failed question back in the text field.
  ///
  /// In en, this message translates to:
  /// **'Edit question'**
  String get coachAskEditQuestion;

  /// The person's own daily question limit was reached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve asked a lot today. Ask GoHard will answer again later; the built-in Quick guide still works.'**
  String get coachAskProblemLimit;

  /// The AI provider is rate limited or overloaded.
  ///
  /// In en, this message translates to:
  /// **'Ask GoHard is busy right now. Try again in a moment.'**
  String get coachAskProblemBusy;

  /// The request did not get through. Never call it 'offline'.
  ///
  /// In en, this message translates to:
  /// **'Ask GoHard couldn\'t be reached. That can be this phone\'s connection or the server. The built-in Quick guide still works.'**
  String get coachAskProblemUnreached;

  /// The server rejected the question as malformed.
  ///
  /// In en, this message translates to:
  /// **'That question couldn\'t be sent. Edit it and send it again (up to 600 characters).'**
  String get coachAskProblemInvalid;

  /// The app closed while a question was waiting.
  ///
  /// In en, this message translates to:
  /// **'This question didn\'t get an answer before Ask GoHard closed. Retry to ask it again.'**
  String get coachAskProblemInterrupted;

  /// Ask GoHard is not configured or failed.
  ///
  /// In en, this message translates to:
  /// **'Ask GoHard isn\'t available right now. Your question is kept, and the built-in Quick guide still works.'**
  String get coachAskProblemUnavailable;

  /// Label on every AI answer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated'**
  String get coachAskAiGenerated;

  /// An answer made before the draft changed.
  ///
  /// In en, this message translates to:
  /// **'Based on an earlier version of your draft'**
  String get coachAskStale;

  /// Collapses an answer's sources.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get coachAskLess;

  /// Expands an answer's sources.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get coachAskMore;

  /// Heading over the sources an AI answer cites.
  ///
  /// In en, this message translates to:
  /// **'Sources from GoHard\'s reviewed guide'**
  String get coachAskSourcesHeading;

  /// Label/title of an AI-suggested change to the plan draft.
  ///
  /// In en, this message translates to:
  /// **'Suggested change'**
  String get coachAskSuggestedChange;

  /// Shown when a suggestion has no summary.
  ///
  /// In en, this message translates to:
  /// **'A change to your draft'**
  String get coachAskChangeFallback;

  /// After a suggestion was applied to the draft.
  ///
  /// In en, this message translates to:
  /// **'Applied to your draft. It is saved like any other edit; nothing is activated.'**
  String get coachAskApplied;

  /// Undoes an applied suggestion.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get coachAskUndo;

  /// After Undo.
  ///
  /// In en, this message translates to:
  /// **'Undone: your draft is as it was before this suggestion.'**
  String get coachAskUndone;

  /// A suggestion seen outside the plan builder.
  ///
  /// In en, this message translates to:
  /// **'Open the plan builder to preview and apply suggestions.'**
  String get coachAskTextOnly;

  /// Opens the preview of a suggested change.
  ///
  /// In en, this message translates to:
  /// **'Preview change'**
  String get coachAskPreview;

  /// A suggestion that does not fit the draft.
  ///
  /// In en, this message translates to:
  /// **'This suggestion can\'t be applied to your draft.'**
  String get coachAskCantApply;

  /// Pill: the suggestion changes only the draft.
  ///
  /// In en, this message translates to:
  /// **'Draft only'**
  String get coachAskDraftOnly;

  /// Explains the scope of a suggested change.
  ///
  /// In en, this message translates to:
  /// **'Changes the draft in the builder, saved like any edit. Nothing is activated.'**
  String get coachAskDraftOnlyBody;

  /// Warning in the preview.
  ///
  /// In en, this message translates to:
  /// **'Your draft changed since this suggestion'**
  String get coachAskDraftChanged;

  /// Rebuilds the preview from the current draft.
  ///
  /// In en, this message translates to:
  /// **'Check against my current draft'**
  String get coachAskRecheck;

  /// Heading over the parts of a suggestion that were left out.
  ///
  /// In en, this message translates to:
  /// **'Not applicable to your current draft'**
  String get coachAskNotApplicableHeading;

  /// No part of the suggestion fits the current draft.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this suggestion still applies to your draft.'**
  String get coachAskNothingApplies;

  /// Applies the suggestion to the plan draft.
  ///
  /// In en, this message translates to:
  /// **'Apply to draft'**
  String get coachAskApply;

  /// Closes the preview without changes.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get coachAskKeep;

  /// Preview row for an added exercise. rx is a prescription such as 3 × 8–12.
  ///
  /// In en, this message translates to:
  /// **'Added: {name} · {rx}'**
  String coachAskChangeAdded(String name, String rx);

  /// Preview row for a removed exercise.
  ///
  /// In en, this message translates to:
  /// **'Removed: {name} · {rx}'**
  String coachAskChangeRemoved(String name, String rx);

  /// Before and after of a changed value; the arrow points in reading order.
  ///
  /// In en, this message translates to:
  /// **'{before} → {after}'**
  String coachAskChangeArrow(String before, String after);

  /// Preview note when a replaced exercise loses its target load. load is formatted with its unit.
  ///
  /// In en, this message translates to:
  /// **'Weight target {load} is cleared: a replacement starts without one and does not take on {name}\'s history.'**
  String coachAskWeightCleared(String load, String name);

  /// Preview note when the target load stays.
  ///
  /// In en, this message translates to:
  /// **'Weight target {load} is kept.'**
  String coachAskWeightKept(String load);

  /// Part of a suggestion left out: its workout is gone. op is the operation kind (code).
  ///
  /// In en, this message translates to:
  /// **'{op, select, removeExercise{Remove an exercise} replaceExercise{Replace an exercise} setPrescription{Change sets and reps} other{Add an exercise}}: the workout it names is no longer in your draft.'**
  String coachSkipWorkoutGone(String op);

  /// Part of a suggestion left out: its exercise is gone. workout is a workout name.
  ///
  /// In en, this message translates to:
  /// **'{op, select, removeExercise{Remove an exercise} replaceExercise{Replace an exercise} setPrescription{Change sets and reps} other{Add an exercise}}: that exercise is no longer in {workout}.'**
  String coachSkipExerciseGone(String op, String workout);

  /// Part of a suggestion left out.
  ///
  /// In en, this message translates to:
  /// **'Replace {exercise}: the suggested exercise isn\'t available to your account.'**
  String coachSkipReplaceUnavailable(String exercise);

  /// Part of a suggestion left out.
  ///
  /// In en, this message translates to:
  /// **'Replace {exercise}: it is already that exercise.'**
  String coachSkipReplaceSame(String exercise);

  /// Part of a suggestion left out.
  ///
  /// In en, this message translates to:
  /// **'Change {exercise}: the suggested values are outside what a plan allows.'**
  String coachSkipValuesOutside(String exercise);

  /// Part of a suggestion left out.
  ///
  /// In en, this message translates to:
  /// **'Add an exercise to {workout}: it isn\'t available to your account.'**
  String coachSkipAddUnavailable(String workout);

  /// Part of a suggestion left out.
  ///
  /// In en, this message translates to:
  /// **'Add {exercise} to {workout}: the suggested values are outside what a plan allows.'**
  String coachSkipAddOutside(String exercise, String workout);

  /// Part of a suggestion left out.
  ///
  /// In en, this message translates to:
  /// **'Add {exercise} to {workout}: the workout already has 30 exercises.'**
  String coachSkipAddFull(String exercise, String workout);

  /// Why Undo of a suggestion was refused.
  ///
  /// In en, this message translates to:
  /// **'Undo is no longer safe: {exercise} was changed after the suggestion was applied. Change it in the builder instead.'**
  String coachUndoRefused(String exercise);

  /// Name of the built-in reviewed help (offline, no AI).
  ///
  /// In en, this message translates to:
  /// **'Quick guide'**
  String get coachQuickGuide;

  /// Label of the built-in reviewed help, distinguishing it from AI answers.
  ///
  /// In en, this message translates to:
  /// **'Quick guide · built in'**
  String get coachQuickGuideBuiltIn;

  /// Label at the top of the Quick guide sheet.
  ///
  /// In en, this message translates to:
  /// **'Quick guide · built-in reviewed content'**
  String get coachQuickGuideReviewed;

  /// Link to the built-in guide after a failed question.
  ///
  /// In en, this message translates to:
  /// **'Open the Quick guide'**
  String get coachAskOpenQuickGuide;

  /// Heading over cited sources. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get coachGuideSources;

  /// Fallback title of a split entry with no name.
  ///
  /// In en, this message translates to:
  /// **'This split'**
  String get coachGuideThisSplit;

  /// Heading over a split's or exercise's benefits.
  ///
  /// In en, this message translates to:
  /// **'Benefits'**
  String get coachGuideBenefits;

  /// Heading over a split's or exercise's limitations.
  ///
  /// In en, this message translates to:
  /// **'Limitations'**
  String get coachGuideLimitations;

  /// Heading over an exercise's technique cues.
  ///
  /// In en, this message translates to:
  /// **'Technique cues'**
  String get coachGuideTechniqueCues;

  /// Heading over alternative exercises.
  ///
  /// In en, this message translates to:
  /// **'Alternatives'**
  String get coachGuideAlternatives;

  /// A custom exercise in the Quick guide: no claims.
  ///
  /// In en, this message translates to:
  /// **'Added by you. GoHard has no reviewed technique information for your own exercises.'**
  String get coachGuideCustomNoInfo;

  /// Muscles an exercise works, as a list.
  ///
  /// In en, this message translates to:
  /// **'Muscles: {list}'**
  String coachGuideMusclesLine(String list);

  /// Equipment for an exercise.
  ///
  /// In en, this message translates to:
  /// **'Equipment: {equipment}'**
  String coachGuideEquipmentLine(String equipment);

  /// Exercise's role in a plan.
  ///
  /// In en, this message translates to:
  /// **'Role: main lift'**
  String get coachGuideRoleMain;

  /// Exercise's role in a plan.
  ///
  /// In en, this message translates to:
  /// **'Role: accessory'**
  String get coachGuideRoleAccessory;

  /// Separator between items of a short list (keep the trailing space).
  ///
  /// In en, this message translates to:
  /// **', '**
  String get coachListSeparator;

  /// Between workouts of a rotation, in reading order (keep the spaces).
  ///
  /// In en, this message translates to:
  /// **' → '**
  String get coachCycleArrow;

  /// Sheet title explaining a suggested split. name is the split name.
  ///
  /// In en, this message translates to:
  /// **'Why {name}?'**
  String coachWhyTitle(String name);

  /// Section heading in the split explanation.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get coachSheetHowItWorks;

  /// Section heading over benefits.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get coachSheetGoodToKnow;

  /// Section heading over limitations of a split.
  ///
  /// In en, this message translates to:
  /// **'Trade-offs'**
  String get coachSheetTradeOffs;

  /// Section heading over the evidence note.
  ///
  /// In en, this message translates to:
  /// **'Choosing a split'**
  String get coachSheetChoosingSplit;

  /// Evidence note shown with split suggestions. Do not add claims.
  ///
  /// In en, this message translates to:
  /// **'Studies comparing splits with the same weekly volume found similar strength and muscle gains, so pick the structure you can keep doing.'**
  String get coachSplitEvidenceNote;

  /// Sheet title and action comparing candidate splits.
  ///
  /// In en, this message translates to:
  /// **'Compare splits'**
  String get coachCompareTitle;

  /// Split name marked as the suggested one.
  ///
  /// In en, this message translates to:
  /// **'{name} · Suggested'**
  String coachCompareSuggested(String name);

  /// Section heading: how the split falls on the chosen days.
  ///
  /// In en, this message translates to:
  /// **'Your week'**
  String get coachSheetYourWeek;

  /// Section heading: how a split organises the workouts. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Organisation'**
  String get coachSheetOrganisation;

  /// Section heading: how many days a week a split uses.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get coachSheetDays;

  /// Exercise information sheet for a custom exercise.
  ///
  /// In en, this message translates to:
  /// **'Added by you. GoHard has no checked technique notes for your own exercises.'**
  String get coachInfoCustom;

  /// Section heading in exercise information.
  ///
  /// In en, this message translates to:
  /// **'Category and equipment'**
  String get coachInfoCategoryEquipment;

  /// A catalog exercise without guide entry.
  ///
  /// In en, this message translates to:
  /// **'There are no built-in notes for this exercise yet.'**
  String get coachInfoNoNotes;

  /// Section heading in exercise information. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Muscles'**
  String get coachInfoMuscles;

  /// Section heading in exercise information.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get coachInfoEquipment;

  /// Section heading: the exercise's role here.
  ///
  /// In en, this message translates to:
  /// **'In this routine'**
  String get coachInfoInRoutine;

  /// Role of a main exercise (no workout name known).
  ///
  /// In en, this message translates to:
  /// **'A main exercise: a compound lift that works several large muscles, usually done early with longer rest.'**
  String get coachInfoRoleMain;

  /// Role of a main exercise in a named workout.
  ///
  /// In en, this message translates to:
  /// **'A main exercise in {workout}: a compound lift that works several large muscles, usually done early with longer rest.'**
  String coachInfoRoleMainIn(String workout);

  /// Role of an accessory exercise.
  ///
  /// In en, this message translates to:
  /// **'An accessory: extra work for specific muscles, usually after the main lifts.'**
  String get coachInfoRoleAccessory;

  /// Role of an accessory exercise in a named workout.
  ///
  /// In en, this message translates to:
  /// **'An accessory in {workout}: extra work for specific muscles, usually after the main lifts.'**
  String coachInfoRoleAccessoryIn(String workout);

  /// Section heading over technique cues. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Technique'**
  String get coachInfoTechnique;

  /// Section heading over sets, reps and rest. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get coachInfoPrescription;

  /// Opens Ask GoHard about the exercise.
  ///
  /// In en, this message translates to:
  /// **'Ask about this exercise'**
  String get coachInfoAsk;

  /// Opens the editor's replace-exercise control.
  ///
  /// In en, this message translates to:
  /// **'Replace…'**
  String get coachInfoReplace;

  /// Exercise has no sets/reps target.
  ///
  /// In en, this message translates to:
  /// **'No target set yet.'**
  String get coachRxNone;

  /// Number of sets in a prescription sentence.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String coachRxSets(int count);

  /// Duration of a timed set in a prescription sentence.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} seconds}}'**
  String coachRxSeconds(int count);

  /// Single rep target in a prescription sentence.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} reps}}'**
  String coachRxReps(int count);

  /// Rep range in a prescription sentence.
  ///
  /// In en, this message translates to:
  /// **'{lo} to {hi} reps'**
  String coachRxRepRange(int lo, int hi);

  /// Sets with their amount, e.g. '3 sets of 8 to 12 reps'.
  ///
  /// In en, this message translates to:
  /// **'{sets} of {amount}'**
  String coachRxSetsOf(String sets, String amount);

  /// A prescription sentence without rest.
  ///
  /// In en, this message translates to:
  /// **'{what}.'**
  String coachRxSentence(String what);

  /// A prescription sentence with rest in seconds.
  ///
  /// In en, this message translates to:
  /// **'{rest, plural, other{{what}, with {rest} seconds\' rest between sets.}}'**
  String coachRxSentenceRest(String what, int rest);

  /// Training days the person chose, spelled out. count is d0 to d7 (code).
  ///
  /// In en, this message translates to:
  /// **'{count, select, d0{no training days} d1{one training day} d2{two training days} d3{three training days} d4{four training days} d5{five training days} d6{six training days} d7{seven training days} other{{count} training days}}'**
  String coachGuideDays(String count);

  /// Equipment the person chose. equipment is a code.
  ///
  /// In en, this message translates to:
  /// **'{equipment, select, full_gym{gym equipment} dumbbells{dumbbells only} bodyweight{bodyweight only} other{gym equipment}}'**
  String coachGuideEquipment(String equipment);

  /// Why a starting plan was suggested. days and equipment are the phrases above.
  ///
  /// In en, this message translates to:
  /// **'Suggested because you selected {days} and {equipment}.'**
  String coachGuideSuggestedBecause(String days, String equipment);

  /// After a suggestion with dumbbells only.
  ///
  /// In en, this message translates to:
  /// **'Exercises use the dumbbell versions.'**
  String get coachGuideSwapDumbbell;

  /// After a suggestion with bodyweight only.
  ///
  /// In en, this message translates to:
  /// **'Exercises use the bodyweight versions.'**
  String get coachGuideSwapBodyweight;

  /// How a template sits on the chosen days: one workout per day.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, other{One workout on each of your {days} days.}}'**
  String coachGuideFitWeekly(int days);

  /// How a template's workouts rotate over the chosen days.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Its {workouts} workouts rotate across your 1 day.} other{Its {workouts} workouts rotate across your {days} days.}}'**
  String coachGuideFitRotate(int days, int workouts);

  /// A rotation with no fixed training days.
  ///
  /// In en, this message translates to:
  /// **'any day'**
  String get coachGuideAnyDay;

  /// A rotating schedule: the cycle of workouts and the weekdays.
  ///
  /// In en, this message translates to:
  /// **'{cycle}, on {days}. The order carries on across weeks.'**
  String coachGuideRotation(String cycle, String days);

  /// Inline link ending the coach's bubble text; opens Ask GoHard. The chevron mirrors itself in RTL.
  ///
  /// In en, this message translates to:
  /// **'Ask me ›'**
  String get coachAskMeInline;

  /// Button in the coach's bubble that opens Ask GoHard.
  ///
  /// In en, this message translates to:
  /// **'Ask me'**
  String get coachAskMe;

  /// Screen-reader label of the coach portrait/avatar button. name is Leon or Leona.
  ///
  /// In en, this message translates to:
  /// **'Ask GoHard: open the conversation with {name}'**
  String coachAskOpenWith(String name);

  /// Language choice that follows the phone's own language list.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// Supporting text under the System language choice, naming the language the app resolved to.
  ///
  /// In en, this message translates to:
  /// **'Phone language: {language}'**
  String languageSystemResolved(String language);

  /// Me row and sheet title for the app language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Explanation under the language choices.
  ///
  /// In en, this message translates to:
  /// **'Kept on this phone only. GoHard\'s own text changes; your notes, food names and exercise names you typed stay as written.'**
  String get languageFootnote;

  /// Bottom navigation tab and page title: the day overview.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// Bottom navigation tab and page title: workouts, plan and progress.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get navTrain;

  /// Bottom navigation tab and page title: food and water.
  ///
  /// In en, this message translates to:
  /// **'Eat'**
  String get navEat;

  /// Bottom navigation tab and page title: profile and settings.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get navMe;

  /// Dismisses a dialog or sheet without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Screen-reader label for a busy spinner on a button.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get busyWorking;

  /// Screen-reader value of a progress indicator.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent'**
  String percentValue(int percent);

  /// Motion preference: follow the phone's Reduce Motion setting.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get motionDevice;

  /// Motion preference: always reduce motion in this app.
  ///
  /// In en, this message translates to:
  /// **'Reduced'**
  String get motionReduced;

  /// Haptics preference: whatever the phone allows.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get hapticsDevice;

  /// Haptics preference: no touch feedback from this app.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get hapticsOff;

  /// A duration under a minute, abbreviated. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String durationSeconds(int seconds);

  /// A duration in whole minutes, abbreviated. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// A duration of an hour or more, abbreviated. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// Shown where a value is not known (never zero).
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get valueUnknown;

  /// Kilograms, abbreviated, after a load. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// Pounds, abbreviated, after a load. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'lb'**
  String get unitLb;

  /// Kilometres, abbreviated. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get unitKm;

  /// Miles, abbreviated. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'mi'**
  String get unitMi;

  /// Speed in kilometres per hour, abbreviated. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'km/h'**
  String get unitKmPerHour;

  /// Speed in miles per hour, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'mph'**
  String get unitMph;

  /// Metres (elevation), abbreviated. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get unitMetre;

  /// Feet (elevation), abbreviated.
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get unitFoot;

  /// A pace: minutes:seconds per distance unit. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'{pace} /{unit}'**
  String paceValue(String pace, String unit);

  /// Generic button: keep the changes made in a form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Generic button: close a sheet after finishing.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// Generic destructive button: erase the item.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Generic button: close without changes.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Generic button: change the item.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// Generic button after a failure.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// Generic button: go on to the next step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// Generic button: take an item out of a list (not erase history).
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// Generic acknowledgement button. The international abbreviation may match English.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// Fallback message for an unexpected error; never shows raw server details.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Nothing was lost; try again.'**
  String get errorGeneric;

  /// The app brand name. Never translated.
  ///
  /// In en, this message translates to:
  /// **'GoHard'**
  String get brandName;

  /// Common-food category (stored id 'Proteins'): chip and group heading in Add food.
  ///
  /// In en, this message translates to:
  /// **'Proteins'**
  String get foodCategoryProteins;

  /// Common-food category (stored id 'Carbohydrates'): group heading in Add food.
  ///
  /// In en, this message translates to:
  /// **'Carbohydrates'**
  String get foodCategoryCarbohydrates;

  /// Short chip label for the Carbohydrates common-food category.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get foodCategoryCarbsShort;

  /// Common-food category (stored id 'Vegetables').
  ///
  /// In en, this message translates to:
  /// **'Vegetables'**
  String get foodCategoryVegetables;

  /// Common-food category (stored id 'Fruits'). The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Fruits'**
  String get foodCategoryFruits;

  /// Common-food category (stored id 'Dairy').
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get foodCategoryDairy;

  /// Common-food category (stored id 'Fats & Oils').
  ///
  /// In en, this message translates to:
  /// **'Fats & Oils'**
  String get foodCategoryFatsOils;

  /// Common-food category (stored id 'Snacks').
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get foodCategorySnacks;

  /// Common-food category (stored id 'Beverages').
  ///
  /// In en, this message translates to:
  /// **'Beverages'**
  String get foodCategoryBeverages;

  /// First category chip in Add food: no category filter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get foodCategoryAll;

  /// Tag on a food row: the food is one of the user's favourites.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get foodTagFavourite;

  /// Tag on a food row: a food the user created or corrected.
  ///
  /// In en, this message translates to:
  /// **'My food'**
  String get foodTagMine;

  /// Tag on a food row: a food logged before.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get foodTagRecent;

  /// Detail of a recent food row for an entry typed by hand: offered with the same amount and values.
  ///
  /// In en, this message translates to:
  /// **'As you logged it'**
  String get foodAsYouLoggedIt;

  /// The amount a food's values are given for. basis is '100 g', '100 ml' or a provider serving label (provider content, not translated).
  ///
  /// In en, this message translates to:
  /// **'per {basis}'**
  String foodBasisPer(String basis);

  /// Word for one serving when the food's source gives no label.
  ///
  /// In en, this message translates to:
  /// **'serving'**
  String get foodServingFallback;

  /// Meal group (stored value 'Breakfast'). fr-CA: déjeuner is the morning meal.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealBreakfast;

  /// Meal group (stored value 'Lunch'). fr-CA: dîner is the midday meal.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealLunch;

  /// Meal group (stored value 'Dinner'). fr-CA: souper is the evening meal.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealDinner;

  /// Meal group (stored value 'Snack'): snacks eaten through the day.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// Unit after a calorie figure (kilocalories). The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get eatUnitKcal;

  /// Unit after a gram figure (protein, carbs, fat).
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get eatUnitGram;

  /// A calorie figure with its unit. value is pre-formatted. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'{value} kcal'**
  String eatKcalValue(String value);

  /// A gram figure with its unit. value is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{value} g'**
  String eatGramsValue(String value);

  /// Protein amount, e.g. a goal or a row value. value is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{value} g protein'**
  String eatProteinGramsValue(String value);

  /// Water amount in a summary line. amount includes its unit.
  ///
  /// In en, this message translates to:
  /// **'{amount} water'**
  String eatWaterValue(String amount);

  /// Caption naming the day shown when it is today (water sheet, day lists).
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get eatTodayCaption;

  /// Nutrient name: carbohydrates.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get eatCarbs;

  /// Nutrient name: fat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get eatFat;

  /// Nutrient name: calories (energy). The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get eatCalories;

  /// Nutrient name: protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get eatProtein;

  /// Goals form error: calories not a whole number.
  ///
  /// In en, this message translates to:
  /// **'A calorie goal is a whole number, or left blank for no goal.'**
  String get eatGoalCaloriesWhole;

  /// Goals form error: protein not a whole number.
  ///
  /// In en, this message translates to:
  /// **'A protein goal is a whole number, or left blank for no goal.'**
  String get eatGoalProteinWhole;

  /// Goals form error: water goal not a positive amount.
  ///
  /// In en, this message translates to:
  /// **'A water goal is an amount above zero, or left blank for no goal.'**
  String get eatGoalWaterInvalid;

  /// Goals form error: local save failed.
  ///
  /// In en, this message translates to:
  /// **'Your goals could not be saved on this phone. What you typed is still here.'**
  String get eatGoalsSaveFailed;

  /// Goals form field label.
  ///
  /// In en, this message translates to:
  /// **'Daily calories'**
  String get eatGoalCaloriesLabel;

  /// Goals form field label.
  ///
  /// In en, this message translates to:
  /// **'Daily protein'**
  String get eatGoalProteinLabel;

  /// Goals form field label.
  ///
  /// In en, this message translates to:
  /// **'Daily water'**
  String get eatGoalWaterLabel;

  /// Hint in an empty goal field.
  ///
  /// In en, this message translates to:
  /// **'No goal'**
  String get eatGoalNone;

  /// Helper under the calorie goal field: the allowed range.
  ///
  /// In en, this message translates to:
  /// **'500 to 10,000. Leave blank for no calorie goal.'**
  String get eatGoalCaloriesHelper;

  /// Helper under the protein goal field (grams).
  ///
  /// In en, this message translates to:
  /// **'10 to 500. Leave blank for no protein goal.'**
  String get eatGoalProteinHelper;

  /// Helper under the water goal field, in millilitres.
  ///
  /// In en, this message translates to:
  /// **'100 to 10,000. Leave blank for no water goal.'**
  String get eatGoalWaterHelperMl;

  /// Helper under the water goal field, in US fluid ounces.
  ///
  /// In en, this message translates to:
  /// **'3.4 to 338 (US fluid ounces). Leave blank for no water goal.'**
  String get eatGoalWaterHelperFlOz;

  /// Goals form button.
  ///
  /// In en, this message translates to:
  /// **'Save goals'**
  String get eatGoalsSave;

  /// Note under the goals form.
  ///
  /// In en, this message translates to:
  /// **'GoHard does not suggest a calorie or protein goal. If you are unsure what suits you, a dietitian or doctor can help.'**
  String get eatGoalsNoSuggestion;

  /// Title of the goals sheet opened from Eat.
  ///
  /// In en, this message translates to:
  /// **'Daily goals'**
  String get eatGoalsSheetTitle;

  /// Intro text of the goals sheet.
  ///
  /// In en, this message translates to:
  /// **'These repeat every day until you change them. Leave any of them blank for no goal.'**
  String get eatGoalsSheetIntro;

  /// Link to the goals sheet when a goal is set.
  ///
  /// In en, this message translates to:
  /// **'Edit goals'**
  String get eatEditGoals;

  /// Screen-reader label of the Edit goals link.
  ///
  /// In en, this message translates to:
  /// **'Edit daily goals'**
  String get eatEditGoalsSaid;

  /// Link to the goals sheet when no goal is set.
  ///
  /// In en, this message translates to:
  /// **'Set daily goals'**
  String get eatSetGoals;

  /// Link and sheet title: what nutrition values are shown.
  ///
  /// In en, this message translates to:
  /// **'Customize tracking'**
  String get eatCustomizeTracking;

  /// Intro of Customize tracking.
  ///
  /// In en, this message translates to:
  /// **'Calories and protein are always shown. Hiding something changes only what you see: nothing you logged or set is removed.'**
  String get eatTrackingIntro;

  /// Subtitle of the Water switch in Customize tracking. Today and Eat are tab names.
  ///
  /// In en, this message translates to:
  /// **'A water line on Today and Eat, with an optional goal'**
  String get eatTrackWaterSubtitle;

  /// Shown instead of the Water switch when the server cannot keep water.
  ///
  /// In en, this message translates to:
  /// **'Water tracking needs a newer version of your account\'s server. Nothing else changes.'**
  String get eatTrackWaterUnsupported;

  /// Subtitle of the Carbs switch. Eat is the tab name.
  ///
  /// In en, this message translates to:
  /// **'The carbohydrate total in Eat'**
  String get eatTrackCarbsSubtitle;

  /// Subtitle of the Fat switch. Eat is the tab name.
  ///
  /// In en, this message translates to:
  /// **'The fat total in Eat'**
  String get eatTrackFatSubtitle;

  /// Note in Customize tracking when the account keeps the choices.
  ///
  /// In en, this message translates to:
  /// **'These choices follow your account to your other phones.'**
  String get eatTrackSynced;

  /// Short unit: millilitres.
  ///
  /// In en, this message translates to:
  /// **'mL'**
  String get waterUnitMl;

  /// Short unit: US fluid ounces.
  ///
  /// In en, this message translates to:
  /// **'fl oz'**
  String get waterUnitFlOz;

  /// Name of the millilitre water unit. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Millilitres'**
  String get waterUnitMlName;

  /// Name of the US fluid ounce water unit.
  ///
  /// In en, this message translates to:
  /// **'US fluid ounces'**
  String get waterUnitFlOzName;

  /// Water line, sheet title and Customize tracking switch.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get waterTitle;

  /// Nothing was logged (not the same as a recorded zero).
  ///
  /// In en, this message translates to:
  /// **'No water logged'**
  String get waterNoneLogged;

  /// Screen-reader label of the water line while the day's entries are read.
  ///
  /// In en, this message translates to:
  /// **'Water, loading'**
  String get waterSaidLoading;

  /// Screen-reader label of the water line on an earlier day with nothing logged.
  ///
  /// In en, this message translates to:
  /// **'Water, no water logged'**
  String get waterSaidNone;

  /// Screen-reader label of the water line.
  ///
  /// In en, this message translates to:
  /// **'Water {amount}'**
  String waterSaid(String amount);

  /// Screen-reader label of the water line with a goal.
  ///
  /// In en, this message translates to:
  /// **'Water {amount} of {goal}, {percent} percent'**
  String waterSaidWithGoal(String amount, String goal, int percent);

  /// Screen-reader label of the quick-add button.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} millilitres of water'**
  String waterAddSaidMl(String amount);

  /// Screen-reader label of the quick-add button.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} fluid ounces of water'**
  String waterAddSaidFlOz(String amount);

  /// Button that removes the drink just added.
  ///
  /// In en, this message translates to:
  /// **'Undo {amount}'**
  String waterUndo(String amount);

  /// Screen-reader label of Undo.
  ///
  /// In en, this message translates to:
  /// **'Undo adding {amount} of water'**
  String waterUndoSaid(String amount);

  /// Button opening the custom water amount sheet.
  ///
  /// In en, this message translates to:
  /// **'Other amount'**
  String get waterOtherAmount;

  /// Screen-reader hint of the water line.
  ///
  /// In en, this message translates to:
  /// **'Opens water details for this day'**
  String get waterRowHint;

  /// Snack bar when a water entry could not be saved locally.
  ///
  /// In en, this message translates to:
  /// **'That could not be saved on this phone. Nothing was added.'**
  String get waterSaveFailed;

  /// Screen-reader announcement after adding water today.
  ///
  /// In en, this message translates to:
  /// **'Added {amount} of water. Undo available.'**
  String waterAddedAnnounce(String amount);

  /// Screen-reader announcement after adding water on an earlier day.
  ///
  /// In en, this message translates to:
  /// **'Added {amount} of water on {date}. Undo available.'**
  String waterAddedOnDayAnnounce(String amount, String date);

  /// Custom water sheet title and its button.
  ///
  /// In en, this message translates to:
  /// **'Add water'**
  String get waterAddTitle;

  /// Caption naming the earlier day water is added to.
  ///
  /// In en, this message translates to:
  /// **'For {date}'**
  String waterForDay(String date);

  /// Water amount field label.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get waterAmountLabel;

  /// Water amount error.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero.'**
  String get waterProblemNotAboveZero;

  /// Water amount error: over the per-entry maximum.
  ///
  /// In en, this message translates to:
  /// **'One entry can be at most 5 L. Log a larger amount in parts.'**
  String get waterProblemOverMax;

  /// Screen-reader label of the water goal bar.
  ///
  /// In en, this message translates to:
  /// **'Water goal'**
  String get waterGoalLabel;

  /// Water sheet: label over quick amounts, and the custom-amount button.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get waterAdd;

  /// Water sheet custom amount field label.
  ///
  /// In en, this message translates to:
  /// **'Another amount'**
  String get waterAnotherAmount;

  /// Water sheet: no entries on the day.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged on this day'**
  String get waterNothingThisDay;

  /// Water sheet heading over the day's entries.
  ///
  /// In en, this message translates to:
  /// **'Logged on this day'**
  String get waterLoggedThisDay;

  /// Subtitle of a water entry not yet synced.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone · tap to correct'**
  String get waterEntryPending;

  /// Subtitle of a water entry.
  ///
  /// In en, this message translates to:
  /// **'Tap to correct'**
  String get waterEntryTap;

  /// Tooltip of the delete button on a water entry.
  ///
  /// In en, this message translates to:
  /// **'Remove {amount}'**
  String waterRemoveTooltip(String amount);

  /// Water sheet footnote.
  ///
  /// In en, this message translates to:
  /// **'Only water you log here is counted, not drinks or food.'**
  String get waterOnlyLoggedNote;

  /// Dialog title for editing a water entry.
  ///
  /// In en, this message translates to:
  /// **'Correct this amount'**
  String get waterCorrectTitle;

  /// Dialog title and info button tooltip.
  ///
  /// In en, this message translates to:
  /// **'About the suggested water goal'**
  String get waterSuggestionAboutTitle;

  /// Body of the About the suggested water goal dialog. Do not add or change health claims.
  ///
  /// In en, this message translates to:
  /// **'{amount} a day is a general starting point, not a recommendation worked out for you. How much someone needs varies with body size, activity, heat and health; if a condition or medicine affects how much you should drink, follow your doctor\'s advice.\n\nOther drinks and food also contribute to hydration. GoHard counts only the water you log yourself, so your total here is not everything you drank.'**
  String waterSuggestionAboutBody(String amount);

  /// Offered while no water goal is set; nothing is saved until the user chooses it.
  ///
  /// In en, this message translates to:
  /// **'Suggested starting goal: {amount} daily.'**
  String waterSuggestedGoal(String amount);

  /// Note under the suggested water goal.
  ///
  /// In en, this message translates to:
  /// **'A general starting point; your needs may differ. Only water you log is counted.'**
  String get waterSuggestedGoalNote;

  /// Fills the water goal field with the suggestion (does not save).
  ///
  /// In en, this message translates to:
  /// **'Use {amount}'**
  String waterSuggestionUse(String amount);

  /// Unit after the day's protein figure (grams of protein).
  ///
  /// In en, this message translates to:
  /// **'g protein'**
  String get eatUnitGramProtein;

  /// Calories eaten against the goal. Both numbers pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{eaten} of {goal} kcal'**
  String eatGoalProgressCalories(String eaten, String goal);

  /// Protein eaten against the goal (grams).
  ///
  /// In en, this message translates to:
  /// **'Protein {eaten} of {goal} g'**
  String eatGoalProgressProtein(String eaten, String goal);

  /// Food is logged but none has calories (unknown, not zero).
  ///
  /// In en, this message translates to:
  /// **'No calorie value entered yet · goal {goal} kcal'**
  String eatGoalNoCalorieValue(String goal);

  /// Food is logged but none has protein (unknown, not zero).
  ///
  /// In en, this message translates to:
  /// **'No protein value entered yet · goal {goal} g'**
  String eatGoalNoProteinValue(String goal);

  /// Progress line when some foods have no value: a partial sum. progress is eatGoalProgress….
  ///
  /// In en, this message translates to:
  /// **'{progress} · known so far'**
  String eatGoalKnownSoFar(String progress);

  /// Calories above the goal.
  ///
  /// In en, this message translates to:
  /// **'{progress} · {diff} kcal over'**
  String eatGoalOverKcal(String progress, String diff);

  /// Calories remaining to the goal.
  ///
  /// In en, this message translates to:
  /// **'{progress} · {diff} kcal left'**
  String eatGoalLeftKcal(String progress, String diff);

  /// Protein above the goal.
  ///
  /// In en, this message translates to:
  /// **'{progress} · {diff} g over'**
  String eatGoalOverGrams(String progress, String diff);

  /// Protein remaining to the goal.
  ///
  /// In en, this message translates to:
  /// **'{progress} · {diff} g left'**
  String eatGoalLeftGrams(String progress, String diff);

  /// Eat summary heading on a day with no entries.
  ///
  /// In en, this message translates to:
  /// **'No food logged yet'**
  String get eatNoFoodLoggedYet;

  /// Eat summary label: every food has every value (complete totals).
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get eatTotals;

  /// Eat summary label: sums of entered values only, some foods lack a value.
  ///
  /// In en, this message translates to:
  /// **'Known totals'**
  String get eatKnownTotals;

  /// Eat summary label: food logged, but no nutrient values at all.
  ///
  /// In en, this message translates to:
  /// **'No nutrition entered for this food yet'**
  String get eatNoNutritionForFood;

  /// Overline label of the day's nutrition panel. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get eatNutritionOverline;

  /// Under 'No food logged yet'.
  ///
  /// In en, this message translates to:
  /// **'Nothing is recorded for this day. That is not the same as nothing eaten.'**
  String get eatNothingRecorded;

  /// The goals set, e.g. '2,200 kcal · 140 g protein'.
  ///
  /// In en, this message translates to:
  /// **'Your daily goal: {goals}'**
  String eatYourDailyGoal(String goals);

  /// Screen-reader label of a nutrient and its value.
  ///
  /// In en, this message translates to:
  /// **'{nutrient} {value}'**
  String eatNutrientSaid(String nutrient, String value);

  /// Screen-reader label: a nutrient with no known value.
  ///
  /// In en, this message translates to:
  /// **'{nutrient} unknown'**
  String eatNutrientUnknownSaid(String nutrient);

  /// Eat summary footnote when values are partial.
  ///
  /// In en, this message translates to:
  /// **'Some foods have no value for a nutrient, so these are sums of what you entered, not full totals.'**
  String get eatPartialNote;

  /// Some entries are not yet sent to the account.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone · sync pending'**
  String get eatSyncPending;

  /// Tag after a partial sum ('1,480 kcal · known').
  ///
  /// In en, this message translates to:
  /// **'known'**
  String get eatKnown;

  /// Under a partial calorie sum with no goal.
  ///
  /// In en, this message translates to:
  /// **'known so far'**
  String get eatKnownSoFar;

  /// Screen-reader: calories value. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'{nutrient} {value} kilocalories'**
  String eatSaidKcal(String nutrient, String value);

  /// Screen-reader: grams value.
  ///
  /// In en, this message translates to:
  /// **'{nutrient} {value} grams'**
  String eatSaidGrams(String nutrient, String value);

  /// Screen-reader: partial sum coverage, joined after the value with eatListSeparator.
  ///
  /// In en, this message translates to:
  /// **'known from {known} of {total} foods'**
  String eatSaidKnownFrom(int known, int total);

  /// Screen-reader: the calorie goal.
  ///
  /// In en, this message translates to:
  /// **'goal {goal} kilocalories'**
  String eatSaidGoalKcal(String goal);

  /// Screen-reader: the protein goal.
  ///
  /// In en, this message translates to:
  /// **'goal {goal} grams'**
  String eatSaidGoalGrams(String goal);

  /// Separator between parts of a screen-reader label (comma and space).
  ///
  /// In en, this message translates to:
  /// **', '**
  String get eatListSeparator;

  /// Screen-reader label of the calorie goal bar.
  ///
  /// In en, this message translates to:
  /// **'Calories goal'**
  String get eatCaloriesGoalBar;

  /// Screen-reader label of the protein goal bar.
  ///
  /// In en, this message translates to:
  /// **'Protein goal'**
  String get eatProteinGoalBar;

  /// Screen-reader hint on Today's missing-values note.
  ///
  /// In en, this message translates to:
  /// **'Opens the food journal'**
  String get eatOpensJournalHint;

  /// Today note: some foods lack a value.
  ///
  /// In en, this message translates to:
  /// **'Some nutrition values are missing'**
  String get eatSomeValuesMissing;

  /// Today note: food logged with no values at all.
  ///
  /// In en, this message translates to:
  /// **'No nutrition values entered yet'**
  String get eatNoValuesYet;

  /// Food form error: no name.
  ///
  /// In en, this message translates to:
  /// **'Enter what you ate.'**
  String get foodProblemNoName;

  /// Food form error: no amount (hand-typed food).
  ///
  /// In en, this message translates to:
  /// **'Enter how much, in your own words.'**
  String get foodProblemNoAmount;

  /// Food form error: name or amount too long.
  ///
  /// In en, this message translates to:
  /// **'That text is too long.'**
  String get foodProblemTooLong;

  /// Food form error: no meal.
  ///
  /// In en, this message translates to:
  /// **'Choose a meal.'**
  String get foodProblemNoMeal;

  /// Food form error: amount missing or zero.
  ///
  /// In en, this message translates to:
  /// **'Enter how much you had, as a number above zero.'**
  String get foodProblemNoQuantity;

  /// Food form error: a nutrient value out of range.
  ///
  /// In en, this message translates to:
  /// **'Nutrition values must be zero or more.'**
  String get foodProblemBadValues;

  /// Food form error: one nutrient field is not a number. nutrient is Calories/Protein/Carbs/Fat.
  ///
  /// In en, this message translates to:
  /// **'{nutrient} must be a number of zero or more, or left blank.'**
  String foodProblemBadValue(String nutrient);

  /// Saving a food to My foods: name missing or too long.
  ///
  /// In en, this message translates to:
  /// **'Give the food a name of up to 120 characters.'**
  String get foodProblemBadSavedName;

  /// Food form: local save failed.
  ///
  /// In en, this message translates to:
  /// **'This could not be saved on your phone. Your entry is still here. Try again.'**
  String get foodSaveFailedLocal;

  /// Toast after saving a food for later without logging it.
  ///
  /// In en, this message translates to:
  /// **'Saved to My foods. Nothing was logged.'**
  String get foodSavedToMine;

  /// Confirm dialog title. name is the entry's stored name (user content).
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String foodRemoveTitle(String name);

  /// Confirm dialog body. name and amount are stored user content; meal is the meal label; date is a long date.
  ///
  /// In en, this message translates to:
  /// **'This removes only \"{name}\" ({amount}) from {meal} on {date}. Your other food stays.'**
  String foodRemoveBody(String name, String amount, String meal, String date);

  /// Button removing one logged food.
  ///
  /// In en, this message translates to:
  /// **'Remove this food'**
  String get foodRemoveAction;

  /// Sheet title: the food's source in full.
  ///
  /// In en, this message translates to:
  /// **'Food details'**
  String get foodDetailsTitle;

  /// Food form title / overline when editing a logged food.
  ///
  /// In en, this message translates to:
  /// **'Edit food'**
  String get foodEditTitle;

  /// Food form title for a food typed by hand.
  ///
  /// In en, this message translates to:
  /// **'New food'**
  String get foodNewTitle;

  /// Under a nutrient the user corrected (not the source's).
  ///
  /// In en, this message translates to:
  /// **'Your value'**
  String get foodYourValue;

  /// Name field label for a food typed by hand.
  ///
  /// In en, this message translates to:
  /// **'What did you eat?'**
  String get foodWhatDidYouEat;

  /// Name field label for a food from a source.
  ///
  /// In en, this message translates to:
  /// **'Name in your journal'**
  String get foodNameInJournal;

  /// Meal dropdown label.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get foodMealLabel;

  /// Date row in the food form.
  ///
  /// In en, this message translates to:
  /// **'For {date}. Tap to change the date.'**
  String foodForDateTapToChange(String date);

  /// Coach help entry in the food form.
  ///
  /// In en, this message translates to:
  /// **'Help with amounts and portions'**
  String get foodHelpPortions;

  /// Star button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get foodFavouriteRemove;

  /// Star button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get foodFavouriteAdd;

  /// Food form button when editing.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get foodSaveChanges;

  /// Button that logs food as eaten (Eat summary and food form).
  ///
  /// In en, this message translates to:
  /// **'Log food'**
  String get foodLogButton;

  /// Cancel when editing a logged food.
  ///
  /// In en, this message translates to:
  /// **'Cancel and keep the recorded version'**
  String get foodCancelKeep;

  /// Food quantity field label.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get foodAmountLabel;

  /// Unit dropdown label (g, cup, egg…). The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Portion'**
  String get foodPortionLabel;

  /// Button and dialog title: define a portion such as '1 slice = 30 g'.
  ///
  /// In en, this message translates to:
  /// **'Add your own portion'**
  String get foodAddPortion;

  /// Coach tip in the food form.
  ///
  /// In en, this message translates to:
  /// **'You can count portions here. The weight is shown when a reliable conversion is available.'**
  String get foodPortionCoach;

  /// Amount field for a food typed by hand.
  ///
  /// In en, this message translates to:
  /// **'How much?'**
  String get foodHowMuch;

  /// Helper under the hand-typed amount field.
  ///
  /// In en, this message translates to:
  /// **'In your own words, for example \"200 g\" or \"2 slices\"'**
  String get foodHowMuchHelper;

  /// Food form heading over the nutrient fields.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get foodNutritionHeading;

  /// Food form heading with the amount spelled out.
  ///
  /// In en, this message translates to:
  /// **'Nutrition for {amount}'**
  String foodNutritionFor(String amount);

  /// Caption over nutrient fields for a hand-typed food.
  ///
  /// In en, this message translates to:
  /// **'Optional. Tap a value to enter it; a blank stays unknown and is never counted as zero.'**
  String get foodNutritionOptional;

  /// Caption over nutrient fields for a food from a source.
  ///
  /// In en, this message translates to:
  /// **'From the source, for this amount. Tap a value to correct it; a blank stays unknown and is never counted as zero.'**
  String get foodNutritionFromSource;

  /// The source lacks some nutrients. nutrients is a list such as 'carbs, fat'; count is how many.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This source gives no value for {nutrients}. It stays unknown unless you enter it.} other{This source gives no value for {nutrients}. They stay unknown unless you enter them.}}'**
  String foodSourceMissing(int count, String nutrients);

  /// Resets corrected nutrient values.
  ///
  /// In en, this message translates to:
  /// **'Use the source\'s values again'**
  String get foodUseSourceValues;

  /// Keeps the food for later; nothing is logged.
  ///
  /// In en, this message translates to:
  /// **'Save to My foods without logging'**
  String get foodSaveToMine;

  /// Screen-reader hint on the food header.
  ///
  /// In en, this message translates to:
  /// **'Shows the food details'**
  String get foodShowsDetailsHint;

  /// Credit line. credit is a provider name (e.g. USDA FoodData Central), not translated.
  ///
  /// In en, this message translates to:
  /// **'Source: {credit}'**
  String foodSource(String credit);

  /// Credit line for a food the user wrote.
  ///
  /// In en, this message translates to:
  /// **'Your own food'**
  String get foodYourOwn;

  /// A product barcode (digits, not translated).
  ///
  /// In en, this message translates to:
  /// **'Barcode {code}'**
  String foodBarcode(String code);

  /// Above the amount about to be logged.
  ///
  /// In en, this message translates to:
  /// **'You\'re logging'**
  String get foodYoureLogging;

  /// Label under the calories of the amount being logged.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get foodEnergy;

  /// Screen-reader word for an unknown value (shown as a dash).
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get foodUnknownSaid;

  /// Screen-reader calories. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'{value} kilocalories'**
  String foodKcalSaid(String value);

  /// Screen-reader grams.
  ///
  /// In en, this message translates to:
  /// **'{value} grams'**
  String foodGramsSaid(String value);

  /// Add portion error: name missing or not letters.
  ///
  /// In en, this message translates to:
  /// **'Name one portion in a word or two, such as \"slice\" or \"small bowl\".'**
  String get foodPortionNameInvalid;

  /// Add portion error. name is what the user typed.
  ///
  /// In en, this message translates to:
  /// **'This food already has a portion called \"{name}\".'**
  String foodPortionExists(String name);

  /// Add portion error. name is what the user typed.
  ///
  /// In en, this message translates to:
  /// **'Enter how much one {name} is, as a number above zero.'**
  String foodPortionAmountInvalid(String name);

  /// Add portion dialog caption. food is the provider's name (not translated).
  ///
  /// In en, this message translates to:
  /// **'For {food} only. Its nutrition values do not change, and nothing is logged.'**
  String foodPortionFor(String food);

  /// Add portion: name field label.
  ///
  /// In en, this message translates to:
  /// **'One portion is called'**
  String get foodPortionCalled;

  /// Add portion: example name.
  ///
  /// In en, this message translates to:
  /// **'slice'**
  String get foodPortionHint;

  /// Add portion: amount field label.
  ///
  /// In en, this message translates to:
  /// **'How much is one?'**
  String get foodPortionHowMuch;

  /// Add portion dialog button.
  ///
  /// In en, this message translates to:
  /// **'Add portion'**
  String get foodAddPortionButton;

  /// Food details: what the values are for. basis is foodBasisPer ('per 100 g').
  ///
  /// In en, this message translates to:
  /// **'Nutrition {basis}'**
  String foodNutritionBasis(String basis);

  /// Barcode lookup: the product database has no such product.
  ///
  /// In en, this message translates to:
  /// **'No product was found for barcode {code}. You can search for it by name or create your own food.'**
  String foodBarcodeNotFound(String code);

  /// Barcode lookup did not get through (cause unknown: phone or server).
  ///
  /// In en, this message translates to:
  /// **'Barcode {code} could not be looked up just now, and it has not been looked up on this phone before. That can be this phone\'s connection or the server. You can create your own food.'**
  String foodBarcodeOffline(String code);

  /// Barcode lookup timed out.
  ///
  /// In en, this message translates to:
  /// **'The product database took too long to answer for barcode {code}. Try again, or create your own food.'**
  String foodBarcodeTimeout(String code);

  /// Barcode lookup rate limited.
  ///
  /// In en, this message translates to:
  /// **'The product database has had too many requests for now. Try again in a few minutes, or create your own food.'**
  String get foodBarcodeRateLimited;

  /// Barcode lookup: invalid code.
  ///
  /// In en, this message translates to:
  /// **'That is not a product barcode.'**
  String get foodBarcodeInvalid;

  /// Barcode lookup: service unavailable.
  ///
  /// In en, this message translates to:
  /// **'The product database is not answering right now. Try again, or create your own food.'**
  String get foodBarcodeUnavailable;

  /// Busy line while a barcode is looked up.
  ///
  /// In en, this message translates to:
  /// **'Looking up barcode {code}…'**
  String foodBarcodeLookingUp(String code);

  /// Second sentence after a wider-search problem when local results are shown.
  ///
  /// In en, this message translates to:
  /// **'The foods above are from this phone and still work.'**
  String get foodSearchStillLocal;

  /// Second sentence after a wider-search problem when nothing local is shown.
  ///
  /// In en, this message translates to:
  /// **'You can still scan a barcode or create your own food.'**
  String get foodSearchStillScan;

  /// Wider search did not get through (phone or server).
  ///
  /// In en, this message translates to:
  /// **'The wider food database could not be reached just now. That can be this phone\'s connection or the server.'**
  String get foodSearchOffline;

  /// Wider search timed out.
  ///
  /// In en, this message translates to:
  /// **'The wider food database took too long to answer.'**
  String get foodSearchTimeout;

  /// Wider search rate limited.
  ///
  /// In en, this message translates to:
  /// **'The wider food database has had too many requests for now. Try again in a few minutes.'**
  String get foodSearchRateLimited;

  /// The server has no wider food search.
  ///
  /// In en, this message translates to:
  /// **'Wider food search is not set up on this server. Common foods, your own foods and barcodes still work.'**
  String get foodSearchNotConfigured;

  /// Wider search rejected the query.
  ///
  /// In en, this message translates to:
  /// **'That search could not be used. Try other words.'**
  String get foodSearchInvalid;

  /// Wider search unavailable.
  ///
  /// In en, this message translates to:
  /// **'The wider food database is not answering right now. Try again in a moment.'**
  String get foodSearchUnavailable;

  /// Add food guidance with nothing typed.
  ///
  /// In en, this message translates to:
  /// **'Type a food, such as \"egg\" or \"rice\", or pick a category. Everyday foods and your own are found without a connection.'**
  String get foodSearchGuide;

  /// Add food group heading: the user's own matches.
  ///
  /// In en, this message translates to:
  /// **'Your foods'**
  String get foodGroupYours;

  /// Add food group heading: bundled everyday foods.
  ///
  /// In en, this message translates to:
  /// **'Common foods'**
  String get foodGroupCommon;

  /// Add food group heading: wider database results.
  ///
  /// In en, this message translates to:
  /// **'More foods'**
  String get foodGroupMore;

  /// A category with no foods.
  ///
  /// In en, this message translates to:
  /// **'No common foods are filed under {category}.'**
  String foodCategoryEmpty(String category);

  /// Nothing in a category matches what was typed (user text).
  ///
  /// In en, this message translates to:
  /// **'No common food in {category} matches \"{query}\".'**
  String foodCategoryNoMatch(String category, String query);

  /// Note under category results. 'All' is the foodCategoryAll chip.
  ///
  /// In en, this message translates to:
  /// **'Only common foods have a category. Choose All to include your own foods and the wider database.'**
  String get foodCategoryNote;

  /// Wider search in progress.
  ///
  /// In en, this message translates to:
  /// **'Searching more foods…'**
  String get foodSearchBusy;

  /// No local match; the wider search has not been asked yet.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this phone matches \"{query}\".'**
  String foodSearchLocalEmpty(String query);

  /// Link asking the wider database.
  ///
  /// In en, this message translates to:
  /// **'Search more foods'**
  String get foodSearchMore;

  /// Under Search more foods. USDA FoodData Central is a proper name.
  ///
  /// In en, this message translates to:
  /// **'Look up \"{query}\" in USDA FoodData Central'**
  String foodSearchMoreSubtitle(String query);

  /// Wider search answered with nothing more (local matches exist).
  ///
  /// In en, this message translates to:
  /// **'The wider database has no other foods for \"{query}\".'**
  String foodSearchNoOthers(String query);

  /// Wider search answered with nothing (English).
  ///
  /// In en, this message translates to:
  /// **'No foods were found for \"{query}\". Try other words, scan the barcode, or create your own food.'**
  String foodSearchNoneFound(String query);

  /// Wider search found nothing for a non-English query: guidance, never 'this food does not exist'.
  ///
  /// In en, this message translates to:
  /// **'The wider database searches in English and found nothing for \"{query}\". Try the English name, scan the barcode, or enter it yourself.'**
  String foodSearchNoneNonEnglish(String query);

  /// Credit under wider results.
  ///
  /// In en, this message translates to:
  /// **'From USDA FoodData Central, in English, mostly foods sold or eaten in the United States. Values are as published and may differ from your packet.'**
  String get foodSearchCredit;

  /// Recent list empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get foodRecentEmptyTitle;

  /// Recent list empty.
  ///
  /// In en, this message translates to:
  /// **'Foods you log are listed here, ready to log again.'**
  String get foodRecentEmptyBody;

  /// Favourites list empty.
  ///
  /// In en, this message translates to:
  /// **'No favourites yet'**
  String get foodFavouritesEmptyTitle;

  /// Favourites list empty.
  ///
  /// In en, this message translates to:
  /// **'Mark a food with the star on its amount page to keep it here.'**
  String get foodFavouritesEmptyBody;

  /// My foods list empty.
  ///
  /// In en, this message translates to:
  /// **'No foods of your own yet'**
  String get foodMineEmptyTitle;

  /// My foods list empty.
  ///
  /// In en, this message translates to:
  /// **'Create your own food below, or use \"Save to My foods\" on any food\'s amount page.'**
  String get foodMineEmptyBody;

  /// Own list filtered to nothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this list matches \"{query}\".'**
  String foodListNoMatch(String query);

  /// Add food screen title.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get foodAddTitle;

  /// Coach help entry on Add food.
  ///
  /// In en, this message translates to:
  /// **'Help with finding a food'**
  String get foodHelpSearch;

  /// Search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search foods'**
  String get foodSearchHint;

  /// Clear button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get foodSearchClear;

  /// Button opening the barcode scanner.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get foodScanBarcode;

  /// Add food tab: search everything.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get foodScopeSearch;

  /// Add food tab and group: foods logged before.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get foodScopeRecent;

  /// Add food tab: starred foods.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get foodScopeFavourites;

  /// Add food tab: foods the user created.
  ///
  /// In en, this message translates to:
  /// **'My foods'**
  String get foodScopeMine;

  /// Coach tip on Add food. Names the three tabs.
  ///
  /// In en, this message translates to:
  /// **'Search for a food, scan a barcode or enter your own. Recent, Favourites and My foods are one tap away.'**
  String get foodSearchCoach;

  /// Manual entry row title.
  ///
  /// In en, this message translates to:
  /// **'Enter it yourself'**
  String get foodManualTitle;

  /// Manual entry row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find it? Create your own food'**
  String get foodManualSubtitle;

  /// Add food footer.
  ///
  /// In en, this message translates to:
  /// **'Choose a food to check the amount before logging.'**
  String get foodFooter;

  /// Data credits. Provider and license names stay as they are.
  ///
  /// In en, this message translates to:
  /// **'Common foods and wider search: USDA FoodData Central. Barcodes: Open Food Facts (Open Database License).'**
  String get foodCredits;

  /// Meal selector tooltip.
  ///
  /// In en, this message translates to:
  /// **'Change meal'**
  String get foodChangeMeal;

  /// Food row: protein unknown (dash, never zero).
  ///
  /// In en, this message translates to:
  /// **'— protein'**
  String get foodRowProteinUnknown;

  /// Screen-reader hint on a food row.
  ///
  /// In en, this message translates to:
  /// **'Choose this food'**
  String get foodChooseHint;

  /// Typed barcode error.
  ///
  /// In en, this message translates to:
  /// **'A barcode is 6 to 14 digits, as printed under the bars.'**
  String get barcodeTypedInvalid;

  /// Barcode scanner page title.
  ///
  /// In en, this message translates to:
  /// **'Scan a barcode'**
  String get barcodeTitle;

  /// Scanner instruction.
  ///
  /// In en, this message translates to:
  /// **'Hold the barcode on the packet inside the frame.'**
  String get barcodeHold;

  /// Button looking up the typed barcode.
  ///
  /// In en, this message translates to:
  /// **'Look up this barcode'**
  String get barcodeLookUp;

  /// Camera permission refused.
  ///
  /// In en, this message translates to:
  /// **'GoHard is not allowed to use the camera, so it cannot scan. You can allow it in the phone\'s settings, or type the barcode below.'**
  String get barcodeCameraRefused;

  /// No usable camera.
  ///
  /// In en, this message translates to:
  /// **'The camera cannot be used on this phone right now. You can type the barcode below.'**
  String get barcodeCameraUnavailable;

  /// Section label over the typed barcode field.
  ///
  /// In en, this message translates to:
  /// **'Or type the barcode'**
  String get barcodeOrType;

  /// Typed barcode field label.
  ///
  /// In en, this message translates to:
  /// **'Barcode digits'**
  String get barcodeDigitsLabel;

  /// Screen-reader label of the camera spinner.
  ///
  /// In en, this message translates to:
  /// **'Starting the camera'**
  String get barcodeCameraStarting;

  /// Torch button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Turn the light off'**
  String get barcodeTorchOff;

  /// Torch button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Turn the light on'**
  String get barcodeTorchOn;

  /// Help sheet title on Eat.
  ///
  /// In en, this message translates to:
  /// **'Your food journal'**
  String get eatHelpTitle;

  /// Help text on Eat. Names tabs Today and Me, and lists in Add food.
  ///
  /// In en, this message translates to:
  /// **'Add food under a meal: search, scan a barcode or enter your own. The totals add up only what you logged. Your daily goals are set from the summary here, on Today or in Me. Foods you eat again are saved in Add food: Favourites are foods you starred on their amount page; My foods are foods you wrote or corrected yourself. Choosing one only opens its amount: nothing is logged until you confirm it.'**
  String get eatHelpBody;

  /// Coach/help button opening the Favourites list.
  ///
  /// In en, this message translates to:
  /// **'Open Favourites'**
  String get eatOpenFavourites;

  /// Coach button opening My foods.
  ///
  /// In en, this message translates to:
  /// **'Open My foods'**
  String get eatOpenMine;

  /// One-time coach hint on Eat.
  ///
  /// In en, this message translates to:
  /// **'Your past meals and water, by day, week and month, are in History & trends.'**
  String get eatHintHistory;

  /// One-time coach hint on Eat.
  ///
  /// In en, this message translates to:
  /// **'Eat the same foods often? Tap the star on a food\'s amount page and it waits under Favourites in Add food.'**
  String get eatHintSavedNew;

  /// Coach hint when favourites exist.
  ///
  /// In en, this message translates to:
  /// **'Your favourite foods are one tap away. Pick one, check the amount, then log it.'**
  String get eatHintFavourites;

  /// Coach hint when own foods exist.
  ///
  /// In en, this message translates to:
  /// **'Foods you saved are in My foods. Pick one, check the amount, then log it.'**
  String get eatHintMine;

  /// Coach line on Eat (goals set, water on).
  ///
  /// In en, this message translates to:
  /// **'Log a meal or some water and see how the day adds up against your goals.'**
  String get eatSayGoalWater;

  /// Coach line on Eat (goals set).
  ///
  /// In en, this message translates to:
  /// **'Log a meal and see how the day adds up against your goals.'**
  String get eatSayGoal;

  /// Coach line on Eat (no goals, water on).
  ///
  /// In en, this message translates to:
  /// **'Log a meal or some water, or set your daily goals.'**
  String get eatSayNoGoalWater;

  /// Coach line on Eat (no goals).
  ///
  /// In en, this message translates to:
  /// **'Log a meal, or set your daily goals.'**
  String get eatSayNoGoal;

  /// Compact protein on a logged food row (P = protein).
  ///
  /// In en, this message translates to:
  /// **'P {value} g'**
  String eatMacroProtein(String value);

  /// Compact carbs on a logged food row (C = carbs; G = glucides).
  ///
  /// In en, this message translates to:
  /// **'C {value} g'**
  String eatMacroCarbs(String value);

  /// Compact fat on a logged food row (F = fat; L = lipides).
  ///
  /// In en, this message translates to:
  /// **'F {value} g'**
  String eatMacroFat(String value);

  /// Logged food with no values (unknown, not zero).
  ///
  /// In en, this message translates to:
  /// **'No nutrition entered'**
  String get eatNoNutritionEntered;

  /// Sync status of an entry (lower case, after ' · ').
  ///
  /// In en, this message translates to:
  /// **'needs review'**
  String get eatNeedsReview;

  /// Sync status of an entry (lower case, after ' · ').
  ///
  /// In en, this message translates to:
  /// **'sync pending'**
  String get eatSyncPendingShort;

  /// Meal calories when no food in it has calories.
  ///
  /// In en, this message translates to:
  /// **'Calories unknown'**
  String get eatCaloriesUnknown;

  /// Partial calorie sum (some foods lack calories).
  ///
  /// In en, this message translates to:
  /// **'{value} kcal known'**
  String eatKcalKnown(String value);

  /// Screen-reader label of the coach help button on Eat.
  ///
  /// In en, this message translates to:
  /// **'Help with your food journal'**
  String get eatHelpLabel;

  /// Screen-reader label of the coach avatar. coach is the coach's display name.
  ///
  /// In en, this message translates to:
  /// **'Help with your food journal, from {coach}'**
  String eatHelpFrom(String coach);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get eatPreviousDay;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get eatNextDay;

  /// Button and screen title: past days, charts, calendar.
  ///
  /// In en, this message translates to:
  /// **'History & trends'**
  String get eatHistoryTrends;

  /// Button on an earlier day.
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get eatBackToToday;

  /// Eat: journal read error.
  ///
  /// In en, this message translates to:
  /// **'Your food journal could not be read from this phone. Pull down to try again.'**
  String get eatJournalReadError;

  /// Eat: loading.
  ///
  /// In en, this message translates to:
  /// **'Loading your journal…'**
  String get eatJournalLoading;

  /// Eat heading over the meals, today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s meals'**
  String get eatTodaysMeals;

  /// Eat heading over the meals, another day.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get eatMeals;

  /// Screen-reader label of a meal's Add food button. meal is the stored meal id.
  ///
  /// In en, this message translates to:
  /// **'{meal, select, Breakfast{Add food to breakfast} Lunch{Add food to lunch} Dinner{Add food to dinner} Snack{Add food to snack} other{Add food}}'**
  String eatAddFoodToMeal(String meal);

  /// A meal's footer button.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get eatAddFood;

  /// Eat footnote.
  ///
  /// In en, this message translates to:
  /// **'Only food you logged as eaten appears here.'**
  String get eatOnlyLoggedNote;

  /// Number of logged foods (entries) on a day.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 food} other{{count} foods}}'**
  String trendsFoodCount(int count);

  /// A day that has not come yet.
  ///
  /// In en, this message translates to:
  /// **'Future'**
  String get trendsFuture;

  /// Nothing logged that day (not a zero).
  ///
  /// In en, this message translates to:
  /// **'No food logged'**
  String get trendsNoFoodLogged;

  /// Foods logged, none with this value. foods is trendsFoodCount.
  ///
  /// In en, this message translates to:
  /// **'{metric} not entered · {foods} logged'**
  String trendsDayUnknown(String metric, String foods);

  /// Partial day: known sum and how many foods lack the value. noun is trendsNoun….
  ///
  /// In en, this message translates to:
  /// **'{amount} known · {unknown} of {foods} without {noun} values'**
  String trendsDayPartial(
    String amount,
    int unknown,
    String foods,
    String noun,
  );

  /// A real recorded zero (every food says 0).
  ///
  /// In en, this message translates to:
  /// **'{amount} recorded'**
  String trendsDayZero(String amount);

  /// Qualifies 'values': 'days with calorie values'.
  ///
  /// In en, this message translates to:
  /// **'calorie'**
  String get trendsNounCalorie;

  /// Qualifies 'values'.
  ///
  /// In en, this message translates to:
  /// **'protein'**
  String get trendsNounProtein;

  /// Qualifies 'values'.
  ///
  /// In en, this message translates to:
  /// **'carb'**
  String get trendsNounCarb;

  /// Qualifies 'values'.
  ///
  /// In en, this message translates to:
  /// **'fat'**
  String get trendsNounFat;

  /// Qualifies 'values'.
  ///
  /// In en, this message translates to:
  /// **'water'**
  String get trendsNounWater;

  /// Help text on History & trends; explains the chart marks – ? ★.
  ///
  /// In en, this message translates to:
  /// **'Each bar is one day\'s logged total. Tap or slide across the chart to choose a day, then View day opens its meals and water. A dash means nothing was logged that day; a question mark means foods were logged without this value; a star means some foods have no value, so the sum is what is known. Averages use only days with a known value.'**
  String get trendsHelpBody;

  /// Coach avatar label.
  ///
  /// In en, this message translates to:
  /// **'Help with History & trends'**
  String get trendsHelpLabel;

  /// Coach line on History & trends.
  ///
  /// In en, this message translates to:
  /// **'Tap a day to see what you logged.'**
  String get trendsCoachSay;

  /// Period choice.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get trendsWeek;

  /// Period choice.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get trendsMonth;

  /// Date picker help text.
  ///
  /// In en, this message translates to:
  /// **'Choose a day'**
  String get trendsChooseDay;

  /// History read error.
  ///
  /// In en, this message translates to:
  /// **'Your water could not be read from this phone.'**
  String get trendsWaterReadError;

  /// History read error.
  ///
  /// In en, this message translates to:
  /// **'Your food journal could not be read from this phone.'**
  String get trendsFoodReadError;

  /// Loading.
  ///
  /// In en, this message translates to:
  /// **'Reading your journal on this phone…'**
  String get trendsReading;

  /// Chart title.
  ///
  /// In en, this message translates to:
  /// **'{metric} by day'**
  String trendsByDay(String metric);

  /// Chart legend for the dash mark.
  ///
  /// In en, this message translates to:
  /// **'Not logged'**
  String get trendsLegendNotLogged;

  /// Chart legend for the ? mark.
  ///
  /// In en, this message translates to:
  /// **'Not entered'**
  String get trendsLegendNotEntered;

  /// Chart legend for the ★ mark.
  ///
  /// In en, this message translates to:
  /// **'Some values missing'**
  String get trendsLegendPartial;

  /// Chart legend for the ○ mark.
  ///
  /// In en, this message translates to:
  /// **'Recorded zero'**
  String get trendsLegendZero;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Days in this period'**
  String get trendsDaysInPeriod;

  /// Link and page title.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get trendsCalendar;

  /// Screen-reader label of the Calendar link.
  ///
  /// In en, this message translates to:
  /// **'Calendar and all days with entries'**
  String get trendsCalendarSaid;

  /// Partial read error.
  ///
  /// In en, this message translates to:
  /// **'Food could not be read from this phone; water is shown.'**
  String get trendsFoodErrorWaterShown;

  /// Partial read error.
  ///
  /// In en, this message translates to:
  /// **'Water could not be read from this phone; food is shown.'**
  String get trendsWaterErrorFoodShown;

  /// Under a water day: foods also logged. foods is trendsFoodCount.
  ///
  /// In en, this message translates to:
  /// **'{foods} logged'**
  String trendsFoodsLogged(String foods);

  /// History footnote.
  ///
  /// In en, this message translates to:
  /// **'Totals add up only what was logged. A day with nothing logged, or a food without a value, is never counted as zero. Goals are not shown here: earlier days\' goals were not kept.'**
  String get trendsFootnote;

  /// Under the current week.
  ///
  /// In en, this message translates to:
  /// **'This week so far · {range}'**
  String trendsWeekSoFar(String range);

  /// Under the current month.
  ///
  /// In en, this message translates to:
  /// **'Month to date · {range}'**
  String trendsMonthToDate(String range);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get trendsPreviousWeek;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get trendsPreviousMonth;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get trendsNextWeek;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get trendsNextMonth;

  /// Screen-reader label of the period button.
  ///
  /// In en, this message translates to:
  /// **'Choose a day. Showing {period}'**
  String trendsPeriodSaid(String period);

  /// Screen-reader label of the period button, current period.
  ///
  /// In en, this message translates to:
  /// **'Choose a day. Showing {period}, {sub}'**
  String trendsPeriodSaidSub(String period, String sub);

  /// Button back to the current week.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get trendsThisWeek;

  /// Button back to the current month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get trendsThisMonth;

  /// Totals overline when some values are partial.
  ///
  /// In en, this message translates to:
  /// **'Known {metric} logged'**
  String trendsKnownLogged(String metric);

  /// Totals overline.
  ///
  /// In en, this message translates to:
  /// **'{metric} logged'**
  String trendsLogged(String metric);

  /// Period total when nothing is known.
  ///
  /// In en, this message translates to:
  /// **'No {noun} values'**
  String trendsNoValues(String noun);

  /// How many elapsed days of the period have a value.
  ///
  /// In en, this message translates to:
  /// **'{known} of {elapsed} days with {noun} values'**
  String trendsCoverage(int known, int elapsed, String noun);

  /// Same, for the current period.
  ///
  /// In en, this message translates to:
  /// **'{known} of {elapsed} days with {noun} values so far'**
  String trendsCoverageSoFar(int known, int elapsed, String noun);

  /// Water days of the period.
  ///
  /// In en, this message translates to:
  /// **'{known} of {elapsed} days with water logged'**
  String trendsCoverageWater(int known, int elapsed);

  /// Water days of the current period.
  ///
  /// In en, this message translates to:
  /// **'{known} of {elapsed} days with water logged so far'**
  String trendsCoverageWaterSoFar(int known, int elapsed);

  /// Days of the period with any food logged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day with food logged} other{{count} days with food logged}}'**
  String trendsDaysWithFood(int count);

  /// Of those days, how many have no value at all.
  ///
  /// In en, this message translates to:
  /// **'{count} without any {noun} value'**
  String trendsDaysWithoutValue(int count, String noun);

  /// Average label when some days are partial.
  ///
  /// In en, this message translates to:
  /// **'Daily average, known values'**
  String get trendsAverageKnown;

  /// Average label.
  ///
  /// In en, this message translates to:
  /// **'Daily average'**
  String get trendsAverage;

  /// What the average is over.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Across the one day with {noun} values} other{Across the {count} days with {noun} values}}'**
  String trendsAcross(int count, String noun);

  /// What the water average is over.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Across the one day with water logged} other{Across the {count} days with water logged}}'**
  String trendsAcrossWater(int count);

  /// Partial days note.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Includes 1 day where some foods have no {noun} value: only the known part is added.} other{Includes {count} days where some foods have no {noun} value: only the known part is added.}}'**
  String trendsPartialNote(int count, String noun);

  /// Opens the chosen day's journal.
  ///
  /// In en, this message translates to:
  /// **'View day'**
  String get trendsViewDay;

  /// Screen-reader label of View day.
  ///
  /// In en, this message translates to:
  /// **'View {date}'**
  String trendsViewDaySaid(String date);

  /// Screen-reader summary of the bar chart.
  ///
  /// In en, this message translates to:
  /// **'{metric} by day, {period}: {known} of {elapsed} days with a value. Each day is in the list of days below.'**
  String trendsChartSaid(String metric, String period, int known, int elapsed);

  /// Calendar list: a day's calories unknown (after ' · ').
  ///
  /// In en, this message translates to:
  /// **'calories unknown'**
  String get trendsCaloriesUnknownLower;

  /// Calendar page subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your meals and water, by day'**
  String get trendsCalendarSubtitle;

  /// Calendar caption.
  ///
  /// In en, this message translates to:
  /// **'Choose a day to see what was logged on it.'**
  String get trendsCalendarCaption;

  /// Calendar page label.
  ///
  /// In en, this message translates to:
  /// **'Days with entries'**
  String get trendsDaysWithEntries;

  /// Calendar empty state body.
  ///
  /// In en, this message translates to:
  /// **'Days you log food or water on are listed here.'**
  String get trendsNothingYetBody;

  /// Server code INVALID_CREDENTIALS on sign-in.
  ///
  /// In en, this message translates to:
  /// **'That email and password do not match an account.'**
  String get accountErrorInvalidCredentials;

  /// Server code EMAIL_IN_USE on registration.
  ///
  /// In en, this message translates to:
  /// **'An account with that email already exists. Sign in instead.'**
  String get accountErrorEmailInUse;

  /// Server code WEAK_PASSWORD.
  ///
  /// In en, this message translates to:
  /// **'Use a password of at least 15 characters.'**
  String get accountErrorWeakPassword;

  /// Server code INVALID_EMAIL.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get accountErrorInvalidEmail;

  /// Server code INVALID_DISPLAY_NAME.
  ///
  /// In en, this message translates to:
  /// **'Enter the name you want to see in the app.'**
  String get accountErrorInvalidDisplayName;

  /// Server code WRONG_PASSWORD when deleting the account.
  ///
  /// In en, this message translates to:
  /// **'That password is not correct. Your account was not deleted.'**
  String get accountErrorWrongPassword;

  /// HTTP 429 from the account server.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get accountErrorTooManyAttempts;

  /// Sign-in or registration could not reach the server.
  ///
  /// In en, this message translates to:
  /// **'The server cannot be reached. Check your connection and try again; nothing you typed was lost.'**
  String get accountErrorUnreachable;

  /// Account deletion could not reach the server.
  ///
  /// In en, this message translates to:
  /// **'The server cannot be reached, so nothing was deleted. Account deletion needs a connection.'**
  String get accountErrorUnreachableDelete;

  /// Display name validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a name of 1 to 80 characters.'**
  String get accountErrorNameLength;

  /// Calorie goal out of range.
  ///
  /// In en, this message translates to:
  /// **'A calorie goal is a whole number from 500 to 10,000, or left blank.'**
  String get accountErrorCalorieGoal;

  /// Protein goal out of range.
  ///
  /// In en, this message translates to:
  /// **'A protein goal is a whole number from 10 to 500 grams, or left blank.'**
  String get accountErrorProteinGoal;

  /// Water goal out of range.
  ///
  /// In en, this message translates to:
  /// **'A water goal is from 100 mL to 10 L (about 3.4 to 338 fl oz), or left blank.'**
  String get accountErrorWaterGoal;

  /// Title of the local workout reminder notification. The body is the planned workout's title (user/plan content).
  ///
  /// In en, this message translates to:
  /// **'Workout today'**
  String get reminderNotificationTitle;

  /// Android notification channel name, shown in the phone's notification settings.
  ///
  /// In en, this message translates to:
  /// **'Workout reminders'**
  String get reminderChannelName;

  /// Android notification channel description.
  ///
  /// In en, this message translates to:
  /// **'A reminder on days with a planned workout'**
  String get reminderChannelDescription;

  /// Phone permission state.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get permissionAllowed;

  /// Phone permission state.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get permissionNotAllowed;

  /// Location permission state when the platform cannot tell the two apart.
  ///
  /// In en, this message translates to:
  /// **'Not asked yet, or not allowed'**
  String get permissionNotAskedOrNotAllowed;

  /// Permission state the phone could not report.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get permissionUnknown;

  /// Subtitle of the Phone permissions page.
  ///
  /// In en, this message translates to:
  /// **'Controlled by the phone, not by GoHard\'s own settings.'**
  String get permissionsSubtitle;

  /// Permission row title.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get permissionLocation;

  /// Why GoHard uses location.
  ///
  /// In en, this message translates to:
  /// **'Approximate, while the app is open: automatic weather on Today and GPS runs. Asked when you use one of them.'**
  String get permissionLocationExplanation;

  /// Permission row title.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get permissionCamera;

  /// Why GoHard uses the camera.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning only. Asked the first time you scan; the scanner says so if it is not allowed.'**
  String get permissionCameraExplanation;

  /// Permission row title. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permissionNotifications;

  /// Why GoHard uses notifications.
  ///
  /// In en, this message translates to:
  /// **'Workout reminders only. Asked when you turn them on in Me.'**
  String get permissionNotificationsExplanation;

  /// Explanation below the permission rows.
  ///
  /// In en, this message translates to:
  /// **'GoHard asks for each one only when you use the feature that needs it. To allow or stop something you refused or allowed earlier, use the phone\'s Settings. App preferences such as Units, Appearance and Today background are in Me.'**
  String get permissionsFootnote;

  /// Button opening the OS settings for GoHard.
  ///
  /// In en, this message translates to:
  /// **'Open phone Settings'**
  String get permissionsOpenSettings;

  /// Sync review: this version of the record was removed.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get syncRemoved;

  /// Sync review description of a food entry. name and amount are user/provider content; meal is the stored meal id.
  ///
  /// In en, this message translates to:
  /// **'{name} · {amount} · {meal} · {date}'**
  String syncFoodLine(String name, String amount, String meal, String date);

  /// Sync review description of a food entry with known calories.
  ///
  /// In en, this message translates to:
  /// **'{name} · {amount} · {meal} · {date} · {calories} kcal'**
  String syncFoodLineCalories(
    String name,
    String amount,
    String meal,
    String date,
    String calories,
  );

  /// Sync review: a workout not finished. title is plan/user content.
  ///
  /// In en, this message translates to:
  /// **'{title} · {date} · in progress'**
  String syncWorkoutInProgress(String title, String date);

  /// Sync review: a finished workout; outcome is the stored outcome id.
  ///
  /// In en, this message translates to:
  /// **'{title} · {date} · finished ({outcome})'**
  String syncWorkoutFinished(String title, String date, String outcome);

  /// Sync review: training context without a primary plan.
  ///
  /// In en, this message translates to:
  /// **'No primary plan'**
  String get syncNoPrimaryPlan;

  /// Sync review: training context with a primary plan.
  ///
  /// In en, this message translates to:
  /// **'A primary plan is set'**
  String get syncPrimaryPlanSet;

  /// Sync review: a plan and its stored lifecycle id.
  ///
  /// In en, this message translates to:
  /// **'{title} · {lifecycle}'**
  String syncPlanLine(String title, String lifecycle);

  /// Sync review: profile name (user content), stored appearance id and load unit id.
  ///
  /// In en, this message translates to:
  /// **'{name} · {appearance} · {unit}'**
  String syncProfileLine(String name, String appearance, String unit);

  /// Sync review: the profile's calorie goal.
  ///
  /// In en, this message translates to:
  /// **'goal {value} kcal'**
  String syncGoalCalories(String value);

  /// Sync review: the profile's protein goal.
  ///
  /// In en, this message translates to:
  /// **'goal {value} g protein'**
  String syncGoalProtein(String value);

  /// Sync review: the profile's water goal in millilitres.
  ///
  /// In en, this message translates to:
  /// **'goal {value} mL water'**
  String syncGoalWater(String value);

  /// Sync review: a saved food without a name.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get syncFoodFallback;

  /// Sync review: the saved food is a favourite.
  ///
  /// In en, this message translates to:
  /// **'favourite'**
  String get syncFavourite;

  /// Sync review: a run.
  ///
  /// In en, this message translates to:
  /// **'Run · {date}'**
  String syncRunLine(String date);

  /// Sync review: a water entry.
  ///
  /// In en, this message translates to:
  /// **'Water · {amount} · {date}'**
  String syncWaterLine(String amount, String date);

  /// Sync review: weekly goals. workouts and runs are the two targets below.
  ///
  /// In en, this message translates to:
  /// **'Weekly goals from {date}: {workouts} · {runs}'**
  String syncWeeklyGoalsLine(String date, String workouts, String runs);

  /// Sync review: weekly goals without a workout target.
  ///
  /// In en, this message translates to:
  /// **'no workout target'**
  String get syncNoWorkoutTarget;

  /// Sync review: weekly workout target.
  ///
  /// In en, this message translates to:
  /// **'{count} workouts'**
  String syncWorkoutsTarget(int count);

  /// Sync review: weekly goals without a Run / Walk target.
  ///
  /// In en, this message translates to:
  /// **'no Run / Walk target'**
  String get syncNoRunWalkTarget;

  /// Sync review: weekly Run / Walk target.
  ///
  /// In en, this message translates to:
  /// **'{count} runs or walks'**
  String syncRunWalkTarget(int count);

  /// Sync review: an exercise without a weight increment.
  ///
  /// In en, this message translates to:
  /// **'No weight increment'**
  String get syncNoIncrement;

  /// Sync review: an exercise's weight increment.
  ///
  /// In en, this message translates to:
  /// **'Weight increment {load}'**
  String syncIncrement(String load);

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Recorded set'**
  String get syncKindSet;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Food entry'**
  String get syncKindFood;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get syncKindWorkout;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Primary plan change'**
  String get syncKindContext;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Plan change'**
  String get syncKindPlan;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get syncKindProfile;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get syncKindRun;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Body measurement'**
  String get syncKindMetric;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Suggested change'**
  String get syncKindProposal;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Saved food'**
  String get syncKindSavedFood;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Water entry'**
  String get syncKindWater;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Weekly goals'**
  String get syncKindWeeklyGoal;

  /// Sync review card title by record kind.
  ///
  /// In en, this message translates to:
  /// **'Weight increment'**
  String get syncKindIncrement;

  /// Why a change needs review: server code REVISION_CONFLICT.
  ///
  /// In en, this message translates to:
  /// **'It was also changed somewhere else, so the two versions differ.'**
  String get syncReasonRevisionConflict;

  /// Server codes SET_DELETED / ENTRY_DELETED.
  ///
  /// In en, this message translates to:
  /// **'It was removed somewhere else after you changed it here.'**
  String get syncReasonDeleted;

  /// Server code OCCASION_NOT_ELIGIBLE.
  ///
  /// In en, this message translates to:
  /// **'That planned workout was already started, recorded or skipped somewhere else.'**
  String get syncReasonOccasionNotEligible;

  /// Server code ALREADY_FINISHED.
  ///
  /// In en, this message translates to:
  /// **'This workout was already finished somewhere else.'**
  String get syncReasonAlreadyFinished;

  /// Server code SET_DEPENDENCY_MISMATCH.
  ///
  /// In en, this message translates to:
  /// **'The sets in your account differ from the sets on this phone.'**
  String get syncReasonSetMismatch;

  /// Plan lifecycle conflict codes.
  ///
  /// In en, this message translates to:
  /// **'Your plans changed somewhere else before this reached your account.'**
  String get syncReasonPlansChanged;

  /// Server code NOT_FOUND.
  ///
  /// In en, this message translates to:
  /// **'It no longer exists in your account.'**
  String get syncReasonNotFound;

  /// Any other refusal; code is the stable error code (not translated).
  ///
  /// In en, this message translates to:
  /// **'Your account did not accept it ({code}).'**
  String syncReasonOther(String code);

  /// Placed in syncReasonOther when no code was recorded.
  ///
  /// In en, this message translates to:
  /// **'unknown reason'**
  String get syncReasonUnknownCode;

  /// Sync review page title.
  ///
  /// In en, this message translates to:
  /// **'Review saved changes'**
  String get syncReviewTitle;

  /// Sync review intro.
  ///
  /// In en, this message translates to:
  /// **'Everything below is saved on this phone. Each item differs from your account or was not accepted, so it needs your decision.'**
  String get syncReviewIntro;

  /// Sync review empty state title.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review'**
  String get syncReviewEmptyTitle;

  /// Sync review empty state body.
  ///
  /// In en, this message translates to:
  /// **'All your changes are either synced or waiting to sync normally.'**
  String get syncReviewEmptyBody;

  /// Label above the local version.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get syncOnThisPhone;

  /// Label above the account's version.
  ///
  /// In en, this message translates to:
  /// **'In your account'**
  String get syncInYourAccount;

  /// Conflict resolution button.
  ///
  /// In en, this message translates to:
  /// **'Keep the version on this phone'**
  String get syncKeepLocal;

  /// Snackbar after keeping the local version.
  ///
  /// In en, this message translates to:
  /// **'Kept your version. The account\'s version is retained as the alternative.'**
  String get syncKeptLocal;

  /// Button when a planned workout start was refused.
  ///
  /// In en, this message translates to:
  /// **'Keep it as a manual workout'**
  String get syncKeepManual;

  /// Snackbar after keeping a workout as manual.
  ///
  /// In en, this message translates to:
  /// **'Kept as manual training. Every recorded set is preserved.'**
  String get syncKeptManual;

  /// Conflict resolution button.
  ///
  /// In en, this message translates to:
  /// **'Use the account\'s version'**
  String get syncUseServer;

  /// Snackbar after using the account's version.
  ///
  /// In en, this message translates to:
  /// **'Using the account\'s version. Your version is retained as the alternative.'**
  String get syncUsingServer;

  /// Button for a change the account never accepted.
  ///
  /// In en, this message translates to:
  /// **'Remove it from this phone'**
  String get syncRemoveFromPhone;

  /// Button and dialog action: discard the local change.
  ///
  /// In en, this message translates to:
  /// **'Drop my change'**
  String get syncDropChange;

  /// Confirm dialog title.
  ///
  /// In en, this message translates to:
  /// **'Remove it from this phone?'**
  String get syncRemoveConfirmTitle;

  /// Confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'Your account never accepted this, so removing it here removes it completely.'**
  String get syncRemoveConfirmBody;

  /// Confirm dialog body for a workout.
  ///
  /// In en, this message translates to:
  /// **'Your account never accepted this, so removing it here removes it completely, including its recorded sets.'**
  String get syncRemoveConfirmBodyWorkout;

  /// Confirm dialog title.
  ///
  /// In en, this message translates to:
  /// **'Drop this change?'**
  String get syncDropConfirmTitle;

  /// Confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'Your account\'s version will be shown again.'**
  String get syncDropConfirmBody;

  /// Snackbar after dropping or removing a change.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get syncDiscardDone;

  /// Snackbar when notification permission is refused.
  ///
  /// In en, this message translates to:
  /// **'Notifications are not allowed for GoHard, so reminders stay off. You can allow them in the phone\'s settings.'**
  String get meRemindersNotAllowed;

  /// Snackbar when a local save failed.
  ///
  /// In en, this message translates to:
  /// **'That preference could not be saved on this phone.'**
  String get mePrefNotSaved;

  /// Me row and sheet title.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get meUnits;

  /// Lifting unit choice.
  ///
  /// In en, this message translates to:
  /// **'Kilograms'**
  String get meUnitKilograms;

  /// Lifting unit choice.
  ///
  /// In en, this message translates to:
  /// **'Pounds'**
  String get meUnitPounds;

  /// Units sheet note under the lifting unit.
  ///
  /// In en, this message translates to:
  /// **'Changes how loads are entered and shown. Your recorded training is stored in kilograms and is never rewritten. Time is shown in minutes and seconds.'**
  String get meUnitsLoadNote;

  /// Body progress unit choice.
  ///
  /// In en, this message translates to:
  /// **'Body weight in kilograms'**
  String get meUnitBodyKg;

  /// Body progress unit choice.
  ///
  /// In en, this message translates to:
  /// **'Body weight in pounds'**
  String get meUnitBodyLb;

  /// Body progress unit choice.
  ///
  /// In en, this message translates to:
  /// **'Measurements in centimetres (cm)'**
  String get meUnitBodyCm;

  /// Body progress unit choice.
  ///
  /// In en, this message translates to:
  /// **'Measurements in inches (in)'**
  String get meUnitBodyIn;

  /// Units sheet note under body units.
  ///
  /// In en, this message translates to:
  /// **'For Body progress only: your lifting unit stays as it is. Stored in kilograms and centimetres, so changing this never changes a measurement. Set on this phone for this account.'**
  String get meUnitsBodyNote;

  /// Units sheet section.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get meUnitsTemperature;

  /// Temperature unit choice. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Fahrenheit (°F)'**
  String get meUnitFahrenheit;

  /// Temperature unit choice. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Celsius (°C)'**
  String get meUnitCelsius;

  /// Units sheet note.
  ///
  /// In en, this message translates to:
  /// **'For the weather on Today. Set on this phone.'**
  String get meUnitsTemperatureNote;

  /// Units sheet section.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get meUnitsWater;

  /// Water unit choice. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Millilitres (mL, L)'**
  String get meUnitMillilitres;

  /// Water unit choice.
  ///
  /// In en, this message translates to:
  /// **'US fluid ounces (fl oz)'**
  String get meUnitFluidOunces;

  /// Units sheet note.
  ///
  /// In en, this message translates to:
  /// **'For water you log. Stored in millilitres, so changing this never changes an amount. Fluid ounces are a volume, not a weight. Set on this phone.'**
  String get meUnitsWaterNote;

  /// Units sheet section.
  ///
  /// In en, this message translates to:
  /// **'Run / Walk'**
  String get meUnitsRunWalk;

  /// Distance unit choice.
  ///
  /// In en, this message translates to:
  /// **'Kilometres (min/km, km/h, m)'**
  String get meUnitKilometres;

  /// Distance unit choice.
  ///
  /// In en, this message translates to:
  /// **'Miles (min/mi, mph, ft)'**
  String get meUnitMiles;

  /// Units sheet note.
  ///
  /// In en, this message translates to:
  /// **'Distance, pace, speed and elevation. Routes are stored in metres, so changing this never changes a recording. Set on this phone.'**
  String get meUnitsRunWalkNote;

  /// Sync status word.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get meSyncNeedsReview;

  /// Sync status detail when changes need a decision.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved change needs review. Nothing was lost. Tap to review.} other{{count} saved changes need review. Nothing was lost. Tap to review.}}'**
  String meSyncNeedsReviewDetail(int count);

  /// Sync status word while the account cannot be reached.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get meSyncNotSynced;

  /// Sync status detail while the account cannot be reached.
  ///
  /// In en, this message translates to:
  /// **'Can\'t sync right now · tap to try again'**
  String get meSyncUnreachableDetail;

  /// Sync status detail while unreachable with changes waiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync, saved on this phone.\nCan\'t sync right now · tap to try again} other{{count} changes waiting to sync, saved on this phone.\nCan\'t sync right now · tap to try again}}'**
  String meSyncUnreachableWaitingDetail(int count);

  /// Sync status word with changes waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get meSyncWaiting;

  /// Sync status detail with changes waiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change saved on this phone, waiting to sync} other{{count} changes saved on this phone, waiting to sync}}'**
  String meSyncWaitingDetail(int count);

  /// Sync status word when everything is synced.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get meSyncSaved;

  /// Sync status detail when everything is synced.
  ///
  /// In en, this message translates to:
  /// **'Everything is saved to your account'**
  String get meSyncSavedDetail;

  /// App version with its build number. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'{version} (build {build})'**
  String meBuildNumber(String version, String build);

  /// Technical build line at the bottom of Me.
  ///
  /// In en, this message translates to:
  /// **'{version} · commit {commit} · contract {contract}\nServer: {server}'**
  String meBuildLine(
    String version,
    String commit,
    String contract,
    String server,
  );

  /// Me identity row subtitle and page title.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get meEditProfile;

  /// Shown before the profile has loaded.
  ///
  /// In en, this message translates to:
  /// **'Your profile has not loaded on this phone yet.'**
  String get meProfileNotLoaded;

  /// Me group heading (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get meGroupPersonal;

  /// Me group heading.
  ///
  /// In en, this message translates to:
  /// **'Activity & tracking'**
  String get meGroupActivity;

  /// Me group heading.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get meGroupPreferences;

  /// Me group heading.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get meGroupAccount;

  /// Me Body progress row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Weight, measurements and comparisons'**
  String get meBodySubtitle;

  /// Me row and page title.
  ///
  /// In en, this message translates to:
  /// **'Nutrition goals'**
  String get meGoals;

  /// Nutrition goals row when no goal is set.
  ///
  /// In en, this message translates to:
  /// **'None set'**
  String get meGoalsNoneSet;

  /// Nutrition goals row subtitle when goals exist.
  ///
  /// In en, this message translates to:
  /// **'Daily goals you set'**
  String get meGoalsSet;

  /// Coach help button label.
  ///
  /// In en, this message translates to:
  /// **'Help with nutrition goals'**
  String get meGoalsHelp;

  /// Coach tip on the nutrition goals page.
  ///
  /// In en, this message translates to:
  /// **'These are your daily tracking targets. You can leave either one blank.'**
  String get meGoalsCoachSay;

  /// Nutrition goals panel title.
  ///
  /// In en, this message translates to:
  /// **'Set your own daily targets. Any of them may be left blank.'**
  String get meGoalsPanelTitle;

  /// Nutrition goals panel body.
  ///
  /// In en, this message translates to:
  /// **'They repeat every day until you change them. Today and Eat show your progress once you set one.'**
  String get meGoalsPanelBody;

  /// Me row title.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get meSteps;

  /// Steps row subtitle when on.
  ///
  /// In en, this message translates to:
  /// **'Counted with this phone'**
  String get meStepsOnSubtitle;

  /// Steps row subtitle when off.
  ///
  /// In en, this message translates to:
  /// **'Off · counted with your phone when on'**
  String get meStepsOffSubtitle;

  /// A setting is on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get meOn;

  /// A setting is off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get meOff;

  /// Me row and page title.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get meAppearance;

  /// Appearance page subtitle.
  ///
  /// In en, this message translates to:
  /// **'Make GoHard feel like yours.'**
  String get meAppearanceSubtitle;

  /// Coach help button label.
  ///
  /// In en, this message translates to:
  /// **'Help with these settings'**
  String get meAppearanceHelp;

  /// Coach tip on Appearance, spoken by the coach.
  ///
  /// In en, this message translates to:
  /// **'Pick your guide and when I show up. Motion & haptics sets how much I move.'**
  String get meAppearanceCoachSay;

  /// Appearance section title.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get meAccentTitle;

  /// Appearance section explanation.
  ///
  /// In en, this message translates to:
  /// **'Used for buttons, highlights and the panels.'**
  String get meAccentBody;

  /// Accent colour name.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get meAccentBlue;

  /// Accent colour name.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get meAccentGreen;

  /// Accent colour name.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get meAccentPink;

  /// Screen-reader label of an accent swatch.
  ///
  /// In en, this message translates to:
  /// **'{accent} accent'**
  String meAccentSemantics(String accent);

  /// Appearance section title: light/dark/system. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get meModeTitle;

  /// Appearance mode explanation.
  ///
  /// In en, this message translates to:
  /// **'System follows your phone\'s appearance.'**
  String get meModeBody;

  /// Appearance mode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get meModeLight;

  /// Appearance mode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get meModeDark;

  /// Appearance mode that follows the phone.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get meModeSystem;

  /// Screen-reader label of the preview image.
  ///
  /// In en, this message translates to:
  /// **'Preview of Today in this appearance'**
  String get meAppearancePreviewSemantics;

  /// Overline on the appearance preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get meAppearancePreview;

  /// Line in the appearance preview.
  ///
  /// In en, this message translates to:
  /// **'Your accent, your mode.'**
  String get meAppearancePreviewLine;

  /// Pictured (non-interactive) button in the preview.
  ///
  /// In en, this message translates to:
  /// **'Resume workout'**
  String get meAppearancePreviewButton;

  /// Appearance section title. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get meCoachTitle;

  /// Coach section explanation.
  ///
  /// In en, this message translates to:
  /// **'Leon, a lion, or Leona, a lioness. The same coach either way: only the look changes.'**
  String get meCoachBody;

  /// Screen-reader label of a coach card.
  ///
  /// In en, this message translates to:
  /// **'{name}, {animal}'**
  String meCoachChoiceSemantics(String name, String animal);

  /// Switch title.
  ///
  /// In en, this message translates to:
  /// **'Show coach on Today'**
  String get meCoachOnToday;

  /// Switch subtitle when on.
  ///
  /// In en, this message translates to:
  /// **'{guide} beside your greeting.'**
  String meCoachOnTodayOn(String guide);

  /// Switch subtitle when off.
  ///
  /// In en, this message translates to:
  /// **'Off. Ask GoHard is still {guide}, on Train.'**
  String meCoachOnTodayOff(String guide);

  /// Switch title.
  ///
  /// In en, this message translates to:
  /// **'Show coach on Train and Eat'**
  String get meCoachOnTabs;

  /// Switch subtitle when on.
  ///
  /// In en, this message translates to:
  /// **'{guide} with a short tip under the title.'**
  String meCoachOnTabsOn(String guide);

  /// Switch subtitle when off.
  ///
  /// In en, this message translates to:
  /// **'Off. Help is still a tap on {guide}\'s avatar.'**
  String meCoachOnTabsOff(String guide);

  /// Switch title.
  ///
  /// In en, this message translates to:
  /// **'Coaching hints'**
  String get meCoachHints;

  /// Switch subtitle when on.
  ///
  /// In en, this message translates to:
  /// **'A short tip from {guide} beside GoHard\'s help, once each.'**
  String meCoachHintsOn(String guide);

  /// Switch subtitle when off.
  ///
  /// In en, this message translates to:
  /// **'Off. Help is still there when you ask.'**
  String get meCoachHintsOff;

  /// Row that resets seen hints.
  ///
  /// In en, this message translates to:
  /// **'Show coaching hints again'**
  String get meCoachHintsReset;

  /// Snackbar after resetting hints.
  ///
  /// In en, this message translates to:
  /// **'Coaching hints you have seen can show again.'**
  String get meCoachHintsResetDone;

  /// Row opening the Today background choice.
  ///
  /// In en, this message translates to:
  /// **'Today background'**
  String get meTodayBackground;

  /// Me row and page title.
  ///
  /// In en, this message translates to:
  /// **'Motion & haptics'**
  String get meMotionHaptics;

  /// Motion & haptics page subtitle.
  ///
  /// In en, this message translates to:
  /// **'How GoHard moves and taps on this phone.'**
  String get meMotionSubtitle;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get meMotionSection;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get meHapticsSection;

  /// Me row value: motion reduced, haptics as the phone allows.
  ///
  /// In en, this message translates to:
  /// **'Reduced motion'**
  String get meMotionReducedSummary;

  /// Me row value: haptics off.
  ///
  /// In en, this message translates to:
  /// **'Haptics off'**
  String get meHapticsOffSummary;

  /// Me row value: both reduced.
  ///
  /// In en, this message translates to:
  /// **'Reduced · Haptics off'**
  String get meMotionReducedHapticsOffSummary;

  /// Motion explanation when the phone reduces motion.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone. Reduce Motion is on there, so screens and progress change without movement.'**
  String get meMotionDevicePhoneReduces;

  /// Motion explanation when the phone does not reduce motion.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone\'s Reduce Motion setting. It is off there, so short transitions are shown.'**
  String get meMotionDevicePhoneMoves;

  /// Motion explanation when Reduced is chosen.
  ///
  /// In en, this message translates to:
  /// **'Screens, sheets and progress change without movement, whatever your phone is set to.'**
  String get meMotionReducedExplanation;

  /// Haptics explanation.
  ///
  /// In en, this message translates to:
  /// **'A light tap when you make a selection or confirm an action, if your phone allows vibration. Never for syncing or typing.'**
  String get meHapticsDeviceExplanation;

  /// Haptics explanation when off.
  ///
  /// In en, this message translates to:
  /// **'GoHard does not vibrate this phone.'**
  String get meHapticsOffExplanation;

  /// Footnote on device preference pages.
  ///
  /// In en, this message translates to:
  /// **'Changes apply immediately and are remembered on this phone.'**
  String get mePrefsApplyNow;

  /// Me row and page title.
  ///
  /// In en, this message translates to:
  /// **'Phone permissions'**
  String get mePermissions;

  /// Me row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Location, camera and notifications'**
  String get mePermissionsSubtitle;

  /// Me switch title.
  ///
  /// In en, this message translates to:
  /// **'Workout reminders'**
  String get meReminders;

  /// Reminders switch subtitle when on.
  ///
  /// In en, this message translates to:
  /// **'On days with a planned workout. None while your plan is paused.'**
  String get meRemindersOnSubtitle;

  /// Me row title.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get meReminderTime;

  /// Reminder time row subtitle.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s local time'**
  String get meReminderTimeSubtitle;

  /// Me row title.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get meSyncStatus;

  /// Me row and page title.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get meDeleteAccount;

  /// Me row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently erases your account and data'**
  String get meDeleteAccountSubtitle;

  /// Me row and dialog action.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get meSignOut;

  /// Sign-out dialog title.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get meSignOutConfirmTitle;

  /// Sign-out dialog body; count is the number of changes not yet synced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Your workouts, food and plans stay saved. They stay private to your account on this phone and continue syncing when you sign in again.} =1{Your workouts, food and plans stay saved, including 1 change not yet synced. They stay private to your account on this phone and continue syncing when you sign in again.} other{Your workouts, food and plans stay saved, including {count} changes not yet synced. They stay private to your account on this phone and continue syncing when you sign in again.}}'**
  String meSignOutConfirmBody(int count);

  /// Edit profile button.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get meSaveName;

  /// Edit profile local save failure.
  ///
  /// In en, this message translates to:
  /// **'Your name could not be saved on this phone. What you typed is still here.'**
  String get meNameNotSaved;

  /// Edit profile field label.
  ///
  /// In en, this message translates to:
  /// **'Name shown in the app'**
  String get meNameField;

  /// Edit profile: the sign-in email (user content).
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String meSignedInAs(String email);

  /// Delete account validation.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm.'**
  String get meDeletePasswordMissing;

  /// Delete account dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get meDeleteConfirmTitle;

  /// Delete account dialog body.
  ///
  /// In en, this message translates to:
  /// **'Your account and all of its workouts, food, plans and measurements will be permanently erased. This cannot be undone.'**
  String get meDeleteConfirmBody;

  /// Delete account dialog action.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get meDeleteConfirmAction;

  /// Delete account page button.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get meDeleteButton;

  /// Delete account page cancel.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get meDeleteKeep;

  /// Delete account page explanation.
  ///
  /// In en, this message translates to:
  /// **'This permanently erases your account and everything in it, on the server and on this phone. Signing out is different: it keeps everything.'**
  String get meDeleteExplanation;

  /// Delete account warning about unsynced changes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change on this phone has not synced yet and will be erased too.} other{{count} changes on this phone have not synced yet and will be erased too.}}'**
  String meDeletePendingWarning(int count);

  /// Delete account password field label.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get meDeletePasswordField;

  /// Body progress page and Me row title.
  ///
  /// In en, this message translates to:
  /// **'Body progress'**
  String get bodyTitle;

  /// Body measurement name.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get bodyFieldWeight;

  /// Body measurement name (also a How to measure heading).
  ///
  /// In en, this message translates to:
  /// **'Waist'**
  String get bodyFieldWaist;

  /// Body measurement name.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get bodyFieldChest;

  /// Body measurement name: the person's own left arm (anatomical side).
  ///
  /// In en, this message translates to:
  /// **'Left upper arm'**
  String get bodyFieldLeftUpperArm;

  /// Body measurement name: the person's own right arm (anatomical side).
  ///
  /// In en, this message translates to:
  /// **'Right upper arm'**
  String get bodyFieldRightUpperArm;

  /// Body measurement name: the person's own left thigh.
  ///
  /// In en, this message translates to:
  /// **'Left thigh'**
  String get bodyFieldLeftThigh;

  /// Body measurement name: the person's own right thigh.
  ///
  /// In en, this message translates to:
  /// **'Right thigh'**
  String get bodyFieldRightThigh;

  /// Body measurement name (percent).
  ///
  /// In en, this message translates to:
  /// **'Body fat'**
  String get bodyFieldBodyFat;

  /// A measurement and its value, e.g. Waist 90 cm.
  ///
  /// In en, this message translates to:
  /// **'{field} {value}'**
  String bodyFieldValue(String field, String value);

  /// Centimetres, abbreviated. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get bodyUnitCm;

  /// Inches, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get bodyUnitIn;

  /// Percentage points, abbreviated (body fat change). The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get bodyUnitPoints;

  /// Label beside the weight unit choice in the log form.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get bodyUnitWeight;

  /// Label beside the length unit choice in the log form.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get bodyUnitLength;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, or leave it blank.'**
  String get bodyErrorNotANumber;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Weight is above 0 and at most 700 kg (1,543 lb).'**
  String get bodyErrorWeightRange;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Use a value above 0 and at most 500 cm (196.85 in).'**
  String get bodyErrorLengthRange;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Body fat is from 0 to 100 %.'**
  String get bodyErrorFatRange;

  /// Save refused.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one measurement to save.'**
  String get bodyErrorNothingEntered;

  /// Save refused.
  ///
  /// In en, this message translates to:
  /// **'{field} is out of range.'**
  String bodyErrorFieldOutOfRange(String field);

  /// Save refused.
  ///
  /// In en, this message translates to:
  /// **'A note is at most 200 characters.'**
  String get bodyErrorNoteTooLong;

  /// Save refused on an older server.
  ///
  /// In en, this message translates to:
  /// **'Your account\'s server cannot store these measurements yet. Weight and body fat can be saved now.'**
  String get bodyErrorMeasurementsNeedServer;

  /// Correction refused.
  ///
  /// In en, this message translates to:
  /// **'An entry needs at least one measurement. To remove it, use Delete entry.'**
  String get bodyErrorNeedsOneMeasurement;

  /// Correction refused on an older server.
  ///
  /// In en, this message translates to:
  /// **'Correcting an entry needs an update to your account\'s server. Your changes are still here.'**
  String get bodyErrorCorrectionNeedsServer;

  /// Chart range segment.
  ///
  /// In en, this message translates to:
  /// **'{range, select, weeks4{4 weeks} weeks12{12 weeks} other{All}}'**
  String bodyRangeLabel(String range);

  /// The chart range as a phrase inside other body messages.
  ///
  /// In en, this message translates to:
  /// **'{range, select, weeks4{in the last 4 weeks} weeks12{in the last 12 weeks} other{in all your history}}'**
  String bodyRangeWords(String range);

  /// Error state title.
  ///
  /// In en, this message translates to:
  /// **'This could not be read'**
  String get bodyReadErrorTitle;

  /// Error state body.
  ///
  /// In en, this message translates to:
  /// **'Your measurements on this phone could not be read just now. Nothing was changed; try again.'**
  String get bodyReadErrorBody;

  /// History row sync state.
  ///
  /// In en, this message translates to:
  /// **'Needs review in Me › Sync status'**
  String get bodySyncNeedsReview;

  /// History row sync state.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone · waiting to sync'**
  String get bodySyncWaiting;

  /// Day list header when order is known.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry this day, in the order it was saved.} other{{count} entries this day, in the order they were saved.}}'**
  String bodyDayEntriesKnown(int count);

  /// Day list header when order is unknown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry this day. The order it was taken in is not known.} other{{count} entries this day. The order they were taken in is not known.}}'**
  String bodyDayEntriesUnknown(int count);

  /// An entry's first-saved time.
  ///
  /// In en, this message translates to:
  /// **'Saved at {time}'**
  String bodySavedAt(String time);

  /// History subtitle part: first-saved time.
  ///
  /// In en, this message translates to:
  /// **'saved {time}'**
  String bodySavedAtLower(String time);

  /// Unnamed entry in a day list.
  ///
  /// In en, this message translates to:
  /// **'Entry {number}'**
  String bodyEntryNumber(int number);

  /// Coach help button label.
  ///
  /// In en, this message translates to:
  /// **'Help with body progress'**
  String get bodyHelp;

  /// Coach tip on Body progress.
  ///
  /// In en, this message translates to:
  /// **'Track what matters to you. Every measurement is optional.'**
  String get bodyCoachSay;

  /// Link, tooltip and page title.
  ///
  /// In en, this message translates to:
  /// **'How to measure'**
  String get bodyHowToMeasure;

  /// Empty state title.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get bodyEmptyTitle;

  /// Empty state body.
  ///
  /// In en, this message translates to:
  /// **'Log a weight or any one measurement when it helps you. Nothing here is required.'**
  String get bodyEmptyBody;

  /// Button and log form title.
  ///
  /// In en, this message translates to:
  /// **'Log measurements'**
  String get bodyLogMeasurements;

  /// Pending changes on a server without measurements support.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change saved on this phone. Some wait for your account\'s server to support body measurements.} other{{count} changes saved on this phone. Some wait for your account\'s server to support body measurements.}}'**
  String bodyPendingOldServer(int count);

  /// Pending changes waiting to sync.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change saved on this phone · waiting to sync} other{{count} changes saved on this phone · waiting to sync}}'**
  String bodyPendingWaiting(int count);

  /// Link and history page title.
  ///
  /// In en, this message translates to:
  /// **'All measurements'**
  String get bodyAllMeasurements;

  /// Panel overline.
  ///
  /// In en, this message translates to:
  /// **'Latest weight'**
  String get bodyLatestWeight;

  /// A value not recorded (never zero).
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get bodyNotRecorded;

  /// Inside a screen-reader sentence.
  ///
  /// In en, this message translates to:
  /// **'not recorded'**
  String get bodyNotRecordedLower;

  /// Stacked comparison cell for a missing value.
  ///
  /// In en, this message translates to:
  /// **'— Not recorded'**
  String get bodyDashNotRecorded;

  /// Under Not recorded weight.
  ///
  /// In en, this message translates to:
  /// **'Your other measurements are below.'**
  String get bodyOtherBelow;

  /// Value averaged from same-day entries of unknown order.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Average of 1 entry on {date}} other{Average of {count} entries on {date}}}'**
  String bodyAverageOfEntries(int count, String date);

  /// Date of the latest weight.
  ///
  /// In en, this message translates to:
  /// **'Recorded {date}'**
  String bodyRecordedOn(String date);

  /// Panel label.
  ///
  /// In en, this message translates to:
  /// **'7-day average'**
  String get bodySevenDayAverage;

  /// No 7-day average.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get bodyNotAvailable;

  /// Inside a screen-reader sentence.
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get bodyNotAvailableLower;

  /// Panel line.
  ///
  /// In en, this message translates to:
  /// **'No weight in the last 7 days'**
  String get bodyNoWeightSevenDays;

  /// Days behind the 7-day average.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recorded day of 7} other{{count} recorded days of 7}}'**
  String bodyRecordedDaysOfSeven(int count);

  /// A date range.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String bodyDateRange(String from, String to);

  /// Button: log measurements.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get bodyLog;

  /// Button and page title.
  ///
  /// In en, this message translates to:
  /// **'Compare dates'**
  String get bodyCompareDates;

  /// Chart section header.
  ///
  /// In en, this message translates to:
  /// **'{field} over time'**
  String bodyOverTime(String field);

  /// Link to a metric's page.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get bodySeeAll;

  /// Chart with no weight ever.
  ///
  /// In en, this message translates to:
  /// **'No weight recorded yet. Log one to see it over time.'**
  String get bodyChartNoWeight;

  /// Chart with no values ever; field is the measurement name in lower case.
  ///
  /// In en, this message translates to:
  /// **'No {field} recorded yet.'**
  String bodyChartNone(String field);

  /// Chart with no values in the range; range is bodyRangeWords.
  ///
  /// In en, this message translates to:
  /// **'No {field} {range}. Choose a longer range.'**
  String bodyChartEmptyInRange(String field, String range);

  /// Chart legend.
  ///
  /// In en, this message translates to:
  /// **'Points: each entry · line: daily average'**
  String get bodyChartLegendDaily;

  /// Chart legend.
  ///
  /// In en, this message translates to:
  /// **'Each point is an entry you recorded'**
  String get bodyChartLegendPoints;

  /// Screen-reader summary of the chart; readings is a '; '-separated list of bodyReading.
  ///
  /// In en, this message translates to:
  /// **'{field} {range}: {count, plural, =1{1 entry} other{{count} entries}}. {readings}.'**
  String bodyChartSemantics(
    String field,
    String range,
    int count,
    String readings,
  );

  /// One reading in the chart summary.
  ///
  /// In en, this message translates to:
  /// **'{date}, {value}'**
  String bodyReading(String date, String value);

  /// Chart with one day.
  ///
  /// In en, this message translates to:
  /// **'One day recorded {range}. A change needs at least two.'**
  String bodyOneDayInRange(String range);

  /// Change across the chart range.
  ///
  /// In en, this message translates to:
  /// **'First to latest day in this range: {change}'**
  String bodyRangeChange(String change);

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Latest measurements'**
  String get bodyLatestMeasurements;

  /// No other measurements.
  ///
  /// In en, this message translates to:
  /// **'No measurements other than weight yet. Log measurements to add waist, chest, arms or thighs.'**
  String get bodyLatestNone;

  /// Metric page subtitle.
  ///
  /// In en, this message translates to:
  /// **'Body fat you entered, in %'**
  String get bodyMetricFatSubtitle;

  /// Metric page subtitle.
  ///
  /// In en, this message translates to:
  /// **'In {unit}'**
  String bodyMetricUnitSubtitle(String unit);

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Entries in this range'**
  String get bodyEntriesInRange;

  /// History subtitle.
  ///
  /// In en, this message translates to:
  /// **'Every entry, newest first'**
  String get bodyHistorySubtitle;

  /// History empty state.
  ///
  /// In en, this message translates to:
  /// **'Your entries appear here once you log one.'**
  String get bodyHistoryEmptyBody;

  /// History row without values.
  ///
  /// In en, this message translates to:
  /// **'No measurement'**
  String get bodyNoMeasurement;

  /// History subtitle part; count is at least 2.
  ///
  /// In en, this message translates to:
  /// **'one of {count} entries, order not known'**
  String bodyOneOfEntriesLower(int count);

  /// Compare picker subtitle; count is at least 2.
  ///
  /// In en, this message translates to:
  /// **'One of {count} entries this day, order not known'**
  String bodyOneOfEntriesDay(int count);

  /// The entry's note (user content) in quotation marks.
  ///
  /// In en, this message translates to:
  /// **'“{note}”'**
  String bodyQuotedNote(String note);

  /// Unit switch refused.
  ///
  /// In en, this message translates to:
  /// **'A field holds text that is not a number. Correct or clear it, then change the unit.'**
  String get bodyConvertBlocked;

  /// Date row subtitle and date picker title.
  ///
  /// In en, this message translates to:
  /// **'Date measured'**
  String get bodyDateMeasured;

  /// Date validation.
  ///
  /// In en, this message translates to:
  /// **'Choose today or an earlier date.'**
  String get bodyFutureDate;

  /// Form error.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted fields. Nothing was saved.'**
  String get bodyCheckFields;

  /// Snackbar after saving.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone · it syncs to your account when it can'**
  String get bodySavedToast;

  /// Local save failure.
  ///
  /// In en, this message translates to:
  /// **'That could not be saved on this phone. Everything you typed is still here.'**
  String get bodySaveFailed;

  /// Delete dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get bodyDeleteConfirmTitle;

  /// Delete dialog body.
  ///
  /// In en, this message translates to:
  /// **'The entry from {date} will be removed from your measurements.'**
  String bodyDeleteConfirmBody(String date);

  /// Local delete failure.
  ///
  /// In en, this message translates to:
  /// **'That could not be removed on this phone. Try again.'**
  String get bodyDeleteFailed;

  /// Row and sheet title.
  ///
  /// In en, this message translates to:
  /// **'Choose measurements'**
  String get bodyChooseMeasurements;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Body fat, a note, or fewer fields'**
  String get bodyChooseSubtitle;

  /// Sheet explanation.
  ///
  /// In en, this message translates to:
  /// **'Choose what this form shows. Hiding a field never removes anything you recorded.'**
  String get bodyChooseExplanation;

  /// Checkbox: show the note field. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get bodyNote;

  /// Note field label.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get bodyNoteOptional;

  /// Back with unsaved changes.
  ///
  /// In en, this message translates to:
  /// **'Discard your changes?'**
  String get bodyDiscardTitle;

  /// Discard dialog body.
  ///
  /// In en, this message translates to:
  /// **'What you typed has not been saved.'**
  String get bodyDiscardBody;

  /// Discard dialog action.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get bodyDiscard;

  /// Discard dialog cancel.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get bodyKeepEditing;

  /// Log form title when correcting.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get bodyEditEntry;

  /// Log form subtitle.
  ///
  /// In en, this message translates to:
  /// **'Every measurement is optional.'**
  String get bodyEveryOptional;

  /// Button closing the keyboard.
  ///
  /// In en, this message translates to:
  /// **'Done typing'**
  String get bodyDoneTyping;

  /// Save button for a new entry.
  ///
  /// In en, this message translates to:
  /// **'Save measurements'**
  String get bodySaveMeasurements;

  /// Save button when correcting.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get bodySaveChanges;

  /// Form footnote.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one measurement to save. Blank means not measured.'**
  String get bodyAtLeastOne;

  /// Delete button.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get bodyDeleteEntry;

  /// Picker sheet title.
  ///
  /// In en, this message translates to:
  /// **'Compare from'**
  String get bodyCompareFrom;

  /// Picker sheet title.
  ///
  /// In en, this message translates to:
  /// **'Compare to'**
  String get bodyCompareTo;

  /// Picker sheet note.
  ///
  /// In en, this message translates to:
  /// **'Only days with a saved entry can be chosen.'**
  String get bodyCompareOnlySaved;

  /// Compare page subtitle.
  ///
  /// In en, this message translates to:
  /// **'Changes between your recorded entries.'**
  String get bodyCompareSubtitle;

  /// Coach help button label.
  ///
  /// In en, this message translates to:
  /// **'Help with comparing'**
  String get bodyCompareHelp;

  /// Coach tip on Compare.
  ///
  /// In en, this message translates to:
  /// **'Compare the same measurement on two dates. A dash means it was not recorded that day.'**
  String get bodyCompareCoachSay;

  /// Compare empty state title.
  ///
  /// In en, this message translates to:
  /// **'Two dates needed'**
  String get bodyTwoDatesTitle;

  /// Compare empty state body.
  ///
  /// In en, this message translates to:
  /// **'Comparing needs entries on two different days. You have none yet.'**
  String get bodyTwoDatesNone;

  /// Compare empty state body.
  ///
  /// In en, this message translates to:
  /// **'Comparing needs entries on two different days. You have entries on {date} only.'**
  String bodyTwoDatesOne(String date);

  /// Compare notice.
  ///
  /// In en, this message translates to:
  /// **'An entry you chose is no longer available, so the default is shown.'**
  String get bodyCompareLost;

  /// Compare notice.
  ///
  /// In en, this message translates to:
  /// **'Those days have more than one entry and their order is not known. Choose the entries to compare.'**
  String get bodyCompareChoose;

  /// Compare notice.
  ///
  /// In en, this message translates to:
  /// **'From and To are the same entry. Choose another one.'**
  String get bodyCompareSame;

  /// Picker with nothing chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get bodyChoose;

  /// Compare picker label: the earlier entry.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get bodyFrom;

  /// Compare picker label: the later entry.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get bodyTo;

  /// Weight change between the two entries.
  ///
  /// In en, this message translates to:
  /// **'Change  {change}'**
  String bodyCompareWeightChange(String change);

  /// No weight change available.
  ///
  /// In en, this message translates to:
  /// **'Change  —  needs a weight on both days'**
  String get bodyCompareWeightNoChange;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get bodyMeasurements;

  /// Comparison column header.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get bodyChange;

  /// Stacked comparison change.
  ///
  /// In en, this message translates to:
  /// **'Change: {change}'**
  String bodyChangeValue(String change);

  /// Stacked comparison value.
  ///
  /// In en, this message translates to:
  /// **'{date}: {value}'**
  String bodyDatedValue(String date, String value);

  /// Screen-reader label of a comparison row.
  ///
  /// In en, this message translates to:
  /// **'{field}: {fromDate} {fromValue}, {toDate} {toValue}, change {change}'**
  String bodyCompareRowSemantics(
    String field,
    String fromDate,
    String fromValue,
    String toDate,
    String toValue,
    String change,
  );

  /// Comparison footnote.
  ///
  /// In en, this message translates to:
  /// **'Body fat change is in percentage points.'**
  String get bodyFatPointsNote;

  /// Comparison footnote.
  ///
  /// In en, this message translates to:
  /// **'Recorded values only. A change is shown only where both entries have that measurement.'**
  String get bodyRecordedOnly;

  /// How to measure subtitle.
  ///
  /// In en, this message translates to:
  /// **'Measure the same way each time, so entries compare.'**
  String get bodyHowSubtitle;

  /// How to measure heading.
  ///
  /// In en, this message translates to:
  /// **'Any tape measurement'**
  String get bodyHowTapeTitle;

  /// How to measure guidance; translate faithfully, add nothing.
  ///
  /// In en, this message translates to:
  /// **'Use a flexible tape. Keep it level and snug, without pressing into the skin, and read it at the same place every time.'**
  String get bodyHowTapeBody;

  /// How to measure guidance (NHANES); translate faithfully.
  ///
  /// In en, this message translates to:
  /// **'Find the top of your hip bone at the side. Wrap the tape around your waist at that level, parallel to the floor, and read it at the end of a normal breath out.'**
  String get bodyHowWaistBody;

  /// How to measure heading.
  ///
  /// In en, this message translates to:
  /// **'Upper arm'**
  String get bodyHowArmTitle;

  /// How to measure guidance (NHANES); translate faithfully.
  ///
  /// In en, this message translates to:
  /// **'Find the midpoint between the bony tip of your shoulder and the point of your elbow, at the back of the arm. With the arm relaxed and hanging loosely, wrap the tape around the arm at that point. Tensing the muscle changes the reading. Measure the left and right arm separately.'**
  String get bodyHowArmBody;

  /// How to measure heading.
  ///
  /// In en, this message translates to:
  /// **'Chest and thighs'**
  String get bodyHowChestThighsTitle;

  /// How to measure guidance; translate faithfully.
  ///
  /// In en, this message translates to:
  /// **'GoHard has no verified standard landmark for these. Choose one place, note it if that helps, and measure there each time with the same tape fit. Measure the left and right thigh separately.'**
  String get bodyHowChestThighsBody;

  /// How to measure heading.
  ///
  /// In en, this message translates to:
  /// **'Weight and body fat'**
  String get bodyHowWeightFatTitle;

  /// How to measure guidance; translate faithfully.
  ///
  /// In en, this message translates to:
  /// **'Optional. Enter body fat only if you have a value from a method you trust; GoHard does not estimate it.'**
  String get bodyHowWeightFatBody;

  /// Citation; keep the source and section titles in English as published.
  ///
  /// In en, this message translates to:
  /// **'Source: Centers for Disease Control and Prevention, National Center for Health Statistics. NHANES Anthropometry Procedures Manual, January 2017: 3.4.6 Upper Arm Length, 3.4.7 Arm Circumference, 3.4.8 Abdominal (Waist) Circumference.'**
  String get bodyHowSource;

  /// Disclaimer.
  ///
  /// In en, this message translates to:
  /// **'This is measuring technique, not health advice. GoHard does not judge measurements.'**
  String get bodyHowNotAdvice;

  /// Separator between items of a short list (weekday names, workout names).
  ///
  /// In en, this message translates to:
  /// **', '**
  String get planListComma;

  /// Arrow between workouts in a rotation order, pointing in the reading direction.
  ///
  /// In en, this message translates to:
  /// **' → '**
  String get planSequenceArrow;

  /// A date change: from one date to another.
  ///
  /// In en, this message translates to:
  /// **'{from}  →  {to}'**
  String planDateMove(String from, String to);

  /// A plan block from its start date to its end date (or a dash).
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String planDateSpan(String start, String end);

  /// Compact week range inside one month, e.g. "Oct 5 – 11". month is the short month name.
  ///
  /// In en, this message translates to:
  /// **'{month} {startDay} – {endDay}'**
  String planDateRangeSameMonth(String month, String startDay, String endDay);

  /// Compact week range across months, e.g. "Sep 28 – Oct 4". start and end are short day-month dates.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String planDateRange(String start, String end);

  /// A workout name and its date.
  ///
  /// In en, this message translates to:
  /// **'{title}, {date}'**
  String planTitleDate(String title, String date);

  /// Placeholder name for a workout whose name is missing.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get planWorkoutFallback;

  /// Default name of a new plan the user builds themselves (they can rename it).
  ///
  /// In en, this message translates to:
  /// **'My plan'**
  String get planDefaultTitle;

  /// Name of a duplicated plan or workout. name is the user's own name.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String planCopyName(String name);

  /// Schedule type: each workout on its own weekday.
  ///
  /// In en, this message translates to:
  /// **'Fixed weekdays'**
  String get planModeFixed;

  /// Schedule type: an ordered cycle of workouts continuing across weeks.
  ///
  /// In en, this message translates to:
  /// **'Rotating sequence'**
  String get planModeRotating;

  /// Training week number of a plan.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String planWeekN(int week);

  /// Training week number out of the plan length.
  ///
  /// In en, this message translates to:
  /// **'Week {week} of {total}'**
  String planWeekNOfM(int week, int total);

  /// Week number inside a line of facts (lower case in English).
  ///
  /// In en, this message translates to:
  /// **'week {week}'**
  String planWeekLower(int week);

  /// Position of a workout in a rotating plan (1-based).
  ///
  /// In en, this message translates to:
  /// **'Session {n}'**
  String planSessionN(int n);

  /// Position of a workout in a rotation, inside a line of facts.
  ///
  /// In en, this message translates to:
  /// **'session {n}'**
  String planSessionLower(int n);

  /// Rotation workout position with its step in the cycle and the cycle number.
  ///
  /// In en, this message translates to:
  /// **'Session {n} · step {step} of {total}, cycle {cycle}'**
  String planSessionStep(int n, int step, int total, int cycle);

  /// A plan length in weeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String planWeeksCount(int count);

  /// A plan length in weeks where English always says "weeks".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} weeks}}'**
  String planWeeksPlain(int count);

  /// Number of planned workouts in a block.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} workouts}}'**
  String planWorkoutsPlain(int count);

  /// Number of exercises in a workout.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise} other{{count} exercises}}'**
  String planExerciseCount(int count);

  /// Number of exercises where English always says "exercises".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} exercises}}'**
  String planExercisesPlain(int count);

  /// Number of planned sets in a workout.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 planned set} other{{count} planned sets}}'**
  String planPlannedSetCount(int count);

  /// Number of target sets where English always says "sets".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} sets}}'**
  String planSetsPlain(int count);

  /// Number of target sets of an exercise when it has no reps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String planSetCount(int count);

  /// A rep target with no set count, e.g. "8 reps".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} reps}}'**
  String planRepCount(int count);

  /// Sets times reps or time, e.g. "3 × 8–12" or "3 × 45 s". amount is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{sets} × {amount}'**
  String planRxSetsTimes(int sets, String amount);

  /// Rest between sets in whole minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min rest'**
  String planRestMinutes(int minutes);

  /// Rest between sets in seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s rest'**
  String planRestSeconds(int seconds);

  /// An exercise with no set, rep, time or rest target.
  ///
  /// In en, this message translates to:
  /// **'No target'**
  String get planNoTarget;

  /// The user's own target load for an exercise. load is formatted with its unit.
  ///
  /// In en, this message translates to:
  /// **'Target {load}'**
  String planTargetLoad(String load);

  /// The time the user plans to spend per workout.
  ///
  /// In en, this message translates to:
  /// **'Planned time {minutes} min'**
  String planPlannedTime(int minutes);

  /// A plan with no end date.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get planOngoing;

  /// A plan with no end date, inside a line of facts.
  ///
  /// In en, this message translates to:
  /// **'ongoing'**
  String get planOngoingLower;

  /// When a plan starts, inside a line of facts.
  ///
  /// In en, this message translates to:
  /// **'starts {date}'**
  String planStartsOn(String date);

  /// When a plan ends, inside a line of facts.
  ///
  /// In en, this message translates to:
  /// **'ends {date}'**
  String planEndsOn(String date);

  /// Screen-reader word marking a day as today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get planTodayLower;

  /// Small label under the date of today's workout.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get planTodayLabel;

  /// Screen-reader text for a day with no workout.
  ///
  /// In en, this message translates to:
  /// **'rest day'**
  String get planRestDayLower;

  /// Marks the next workout of a rotation.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get planNext;

  /// Shown with every split suggestion. Keep the meaning exactly; no added claims.
  ///
  /// In en, this message translates to:
  /// **'Studies comparing splits with the same weekly volume found similar strength and muscle gains, so pick the structure you can keep doing.'**
  String get planSplitEvidenceNote;

  /// Why full-body is suggested for 1–3 training days.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{With 1 day a week, full-body sessions train every muscle group each time you train.} other{With {days} days a week, full-body sessions train every muscle group each time you train.}}'**
  String planSuggestReasonFew(int days);

  /// Why upper/lower is suggested for 4 training days.
  ///
  /// In en, this message translates to:
  /// **'With 4 days, alternating upper and lower body trains each half twice a week.'**
  String get planSuggestReasonFour;

  /// Why upper/lower plus push/pull/legs is suggested for 5 training days.
  ///
  /// In en, this message translates to:
  /// **'With 5 days, an upper and a lower day plus push, pull and legs trains each area about twice a week.'**
  String get planSuggestReasonFive;

  /// Why push/pull/legs is suggested for 6 days.
  ///
  /// In en, this message translates to:
  /// **'With {days} days, repeating push, pull and legs trains each area twice a week.'**
  String planSuggestReasonMany(int days);

  /// Why push/pull/legs is suggested for 7 days.
  ///
  /// In en, this message translates to:
  /// **'With {days} days, repeating push, pull and legs trains each area twice a week and leaves one day for rest.'**
  String planSuggestReasonSeven(int days);

  /// Older plan setup answer: training direction.
  ///
  /// In en, this message translates to:
  /// **'Get stronger'**
  String get planDirectionStrength;

  /// Older plan setup answer: training direction.
  ///
  /// In en, this message translates to:
  /// **'Build muscle'**
  String get planDirectionMuscle;

  /// Older plan setup answer: training direction.
  ///
  /// In en, this message translates to:
  /// **'Lose fat'**
  String get planDirectionFatLoss;

  /// Older plan setup answer: training direction.
  ///
  /// In en, this message translates to:
  /// **'General fitness'**
  String get planDirectionGeneral;

  /// Older plan setup answer: sessions per week.
  ///
  /// In en, this message translates to:
  /// **'{count} a week'**
  String planSetupPerWeek(String count);

  /// Older plan setup answer: minutes per session.
  ///
  /// In en, this message translates to:
  /// **'about {minutes} min'**
  String planSetupAbout(String minutes);

  /// Split line of an older reviewed plan without setup answers.
  ///
  /// In en, this message translates to:
  /// **'Reviewed plan'**
  String get planReviewedPlan;

  /// Split line of a plan the user built themselves.
  ///
  /// In en, this message translates to:
  /// **'Your own split'**
  String get planOwnSplit;

  /// Split line while the starter template name is not known.
  ///
  /// In en, this message translates to:
  /// **'Starter split'**
  String get planStarterSplit;

  /// Equipment choice.
  ///
  /// In en, this message translates to:
  /// **'Full gym'**
  String get builderEquipmentFullGym;

  /// Equipment choice.
  ///
  /// In en, this message translates to:
  /// **'Dumbbells only'**
  String get builderEquipmentDumbbells;

  /// Equipment choice.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight only'**
  String get builderEquipmentBodyweight;

  /// Training experience choice.
  ///
  /// In en, this message translates to:
  /// **'New to training'**
  String get builderExperienceNew;

  /// Training experience choice.
  ///
  /// In en, this message translates to:
  /// **'Comfortable with the basics'**
  String get builderExperienceComfortable;

  /// Training experience choice.
  ///
  /// In en, this message translates to:
  /// **'Experienced'**
  String get builderExperienceExperienced;

  /// A plan's state word (lower case in English).
  ///
  /// In en, this message translates to:
  /// **'{state, select, draft{draft} active{active} paused{paused} closed{closed} other{{state}}}'**
  String planLifecycle(String state);

  /// Where a recorded workout came from: a manual workout.
  ///
  /// In en, this message translates to:
  /// **'Manual workout · not part of a plan'**
  String get planProvenanceManual;

  /// A recorded workout whose plan is no longer on the phone. title is the workout name.
  ///
  /// In en, this message translates to:
  /// **'From a plan that is no longer on this phone · {title}'**
  String planProvenanceGone(String title);

  /// The plan a recorded workout came from, with its state. plan is the plan name (user content).
  ///
  /// In en, this message translates to:
  /// **'{state, select, archived{From {plan} (archived)} closed{From {plan} (closed)} paused{From {plan} (paused)} other{From {plan}}}'**
  String planProvenanceFrom(String plan, String state);

  /// Rotation step of a recorded workout.
  ///
  /// In en, this message translates to:
  /// **'session {n} of the rotation'**
  String planSessionOfRotation(int n);

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'Give the plan a name of up to 60 characters.'**
  String get planErrTitle;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'Choose a length between 1 and 52 weeks. Only a rotating sequence can run without an end.'**
  String get planErrDuration;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'Choose a planned time between 10 and 240 minutes, or none.'**
  String get planErrTimeBudget;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'Check the workouts: each needs a name, and sets, reps, rest and weights must be in range.'**
  String get planErrWorkouts;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'Check the schedule: every day or step needs a workout, with one workout per weekday.'**
  String get planErrSchedule;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'Add at least one exercise to every scheduled workout before you activate the plan.'**
  String get planErrNotUsable;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'This plan was made with a newer version of the app. Update the app to change it.'**
  String get planErrNewerApp;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'An exercise in this plan is not available to your account.'**
  String get planErrUnknownExercise;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'An active plan keeps its start date. Duplicate it to start again on another day.'**
  String get planErrStartLocked;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'An active plan keeps its schedule type. Duplicate it to switch between weekdays and a rotation.'**
  String get planErrModeLocked;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'A rotating plan has no fixed dates. Skip the workout, or do it next time you train.'**
  String get planErrNotMovable;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'Give the exercise a name of up to 80 characters.'**
  String get planErrExerciseName;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'This plan changed after you started editing it. Start again from the plan as it is now.'**
  String get planErrChangedSinceEdit;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'This plan is closed. Duplicate it to train with it again.'**
  String get planErrNotActive;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'This exercise is no longer in that plan workout, so its target was not changed. Review the plan instead.'**
  String get planErrTargetContext;

  /// Plan rule error.
  ///
  /// In en, this message translates to:
  /// **'This target was changed again since then, so the earlier one was not restored. Edit it instead.'**
  String get planErrTargetChanged;

  /// Fallback for an unknown plan error. code is a technical code; show as is.
  ///
  /// In en, this message translates to:
  /// **'That change could not be applied ({code}).'**
  String planErrUnknown(String code);

  /// Schedule rule error.
  ///
  /// In en, this message translates to:
  /// **'That leaves no recovery day between two workouts.'**
  String get planErrRecovery;

  /// Schedule rule error.
  ///
  /// In en, this message translates to:
  /// **'That workout is already recorded, skipped or in progress, so it cannot move.'**
  String get planErrNotEligible;

  /// Schedule rule error.
  ///
  /// In en, this message translates to:
  /// **'The schedule changed since you reviewed it. Review it again.'**
  String get planErrStaleReview;

  /// Schedule rule error.
  ///
  /// In en, this message translates to:
  /// **'Choose exactly as many days as workouts per week.'**
  String get planErrWeekdayCount;

  /// Schedule rule error.
  ///
  /// In en, this message translates to:
  /// **'Enter a real calendar date.'**
  String get planErrInvalidDate;

  /// Schedule rule error.
  ///
  /// In en, this message translates to:
  /// **'That workout is no longer part of this plan.'**
  String get planErrNoLongerInPlan;

  /// A plan decision refused because another plan is primary.
  ///
  /// In en, this message translates to:
  /// **'Another plan is already your primary plan. Review the replacement first.'**
  String get planPrimaryExists;

  /// A plan change could not be saved on the phone.
  ///
  /// In en, this message translates to:
  /// **'That could not be saved on this phone. Nothing changed.'**
  String get planLocalSaveFailed;

  /// Train section: workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get trainSectionWorkouts;

  /// Train section: the plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get trainSectionPlan;

  /// Train section: progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get trainSectionProgress;

  /// Ask GoHard context label on Train › Plan without a plan.
  ///
  /// In en, this message translates to:
  /// **'Starting a plan'**
  String get trainAskStartingPlan;

  /// Ask GoHard context label for the plan when it has no name.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get trainAskYourPlan;

  /// Ask GoHard context label on Train › Progress.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get trainAskYourProgress;

  /// Ask GoHard context label on Train › Workouts.
  ///
  /// In en, this message translates to:
  /// **'Your training'**
  String get trainAskYourTraining;

  /// Coach line: a plan being built is saved.
  ///
  /// In en, this message translates to:
  /// **'Your plan in progress is saved on this phone. Pick up where you left off.'**
  String get planStartInProgressCoach;

  /// Title: a plan being built on this phone.
  ///
  /// In en, this message translates to:
  /// **'Plan in progress'**
  String get planStartInProgressTitle;

  /// Body under Plan in progress.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. Nothing is scheduled until you start it.'**
  String get planStartInProgressBody;

  /// Button: continue building the plan.
  ///
  /// In en, this message translates to:
  /// **'Continue my plan'**
  String get planStartContinue;

  /// Coach line: a saved draft plan.
  ///
  /// In en, this message translates to:
  /// **'Your plan is saved as a draft. Review it, then start it when you\'re ready.'**
  String get planStartDraftCoach;

  /// Title: a saved draft plan.
  ///
  /// In en, this message translates to:
  /// **'Your plan is ready to review'**
  String get planStartDraftTitle;

  /// Body under the draft title.
  ///
  /// In en, this message translates to:
  /// **'A saved draft does not schedule anything until you start it.'**
  String get planStartDraftBody;

  /// Button: review the draft plan.
  ///
  /// In en, this message translates to:
  /// **'Review my plan'**
  String get planStartReview;

  /// Coach line with no plan.
  ///
  /// In en, this message translates to:
  /// **'Let\'s build your training plan. Choose a familiar split or make your own.'**
  String get planStartNewCoach;

  /// Empty state title with no plan.
  ///
  /// In en, this message translates to:
  /// **'No plan yet'**
  String get planStartNewTitle;

  /// Empty state body with no plan.
  ///
  /// In en, this message translates to:
  /// **'Choose a familiar split or make your own. Nothing is scheduled until you review it.'**
  String get planStartNewBody;

  /// Button: create a plan.
  ///
  /// In en, this message translates to:
  /// **'Create my plan'**
  String get planStartCreate;

  /// Coach line on a paused plan.
  ///
  /// In en, this message translates to:
  /// **'Your plan is paused, so nothing counts as missed. Resume it below when you\'re ready.'**
  String get trainCoachPlanPaused;

  /// Coach line on the plan.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your plan week by week. Tap a workout for its details, or ask me about the schedule.'**
  String get trainCoachPlanWeek;

  /// Coach line with an open workout.
  ///
  /// In en, this message translates to:
  /// **'A workout is still open. Resume it below when you\'re ready.'**
  String get trainCoachWorkoutOpen;

  /// Coach line on Workouts with a plan.
  ///
  /// In en, this message translates to:
  /// **'Start your planned workout from Today, or record one of your own here.'**
  String get trainCoachWorkoutsPlan;

  /// Coach line on Workouts without a plan.
  ///
  /// In en, this message translates to:
  /// **'Record a workout of your own here. A plan can schedule them for you.'**
  String get trainCoachWorkoutsNoPlan;

  /// Section header: planned workouts due today.
  ///
  /// In en, this message translates to:
  /// **'Scheduled today'**
  String get trainScheduledToday;

  /// Subtitle of a workout due today. summary is "5 exercises · 18 planned sets".
  ///
  /// In en, this message translates to:
  /// **'Due today · {summary}'**
  String trainDueToday(String summary);

  /// Section header: workouts not finished.
  ///
  /// In en, this message translates to:
  /// **'Open workouts'**
  String get trainOpenWorkouts;

  /// Row: start a workout without a plan.
  ///
  /// In en, this message translates to:
  /// **'Start a manual workout'**
  String get trainStartManual;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Train without a plan. It never ticks off a planned workout.'**
  String get trainStartManualSubtitle;

  /// Row: record a run or walk.
  ///
  /// In en, this message translates to:
  /// **'Run / Walk'**
  String get trainRunWalk;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Record a run or a walk outdoors, with its route'**
  String get trainRunWalkSubtitle;

  /// Row: run and walk history.
  ///
  /// In en, this message translates to:
  /// **'Run / Walk history'**
  String get trainRunWalkHistory;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Every run and walk, routes and personal bests'**
  String get trainRunWalkHistorySubtitle;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'No workouts recorded yet'**
  String get trainRecentEmptyTitle;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'When you finish a workout, what you actually did shows up here.'**
  String get trainRecentEmptyBody;

  /// State of an open workout saved for later.
  ///
  /// In en, this message translates to:
  /// **'Saved for later'**
  String get trainSavedForLater;

  /// State of an open workout.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get trainInProgress;

  /// Open workout line: its state and when it started.
  ///
  /// In en, this message translates to:
  /// **'{status} · started {date}'**
  String trainOpenStatusLine(String status, String date);

  /// Count of sets recorded in an open workout.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set recorded} other{{count} sets recorded}}'**
  String trainSetsRecorded(int count);

  /// Button: resume an open workout.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get trainResume;

  /// Link: details of an open workout.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get trainDetails;

  /// Screen-reader label of the Details link. title is the workout name.
  ///
  /// In en, this message translates to:
  /// **'Details of {title}'**
  String trainDetailsOf(String title);

  /// Warning: a local plan change conflicts with the account.
  ///
  /// In en, this message translates to:
  /// **'A plan change saved on this phone differs from your account. Review it from the notice at the bottom of the screen.'**
  String get planNeedsReview;

  /// Link: start a manual workout.
  ///
  /// In en, this message translates to:
  /// **'Train without a plan'**
  String get planTrainWithoutPlan;

  /// Screen-reader label of Train without a plan.
  ///
  /// In en, this message translates to:
  /// **'Start a manual workout without a plan'**
  String get planTrainWithoutPlanSaid;

  /// Section header: other plans.
  ///
  /// In en, this message translates to:
  /// **'Saved and past plans'**
  String get planSavedAndPast;

  /// Subtitle of a saved built draft. mode is Fixed weekdays / Rotating sequence.
  ///
  /// In en, this message translates to:
  /// **'Draft · {mode} · not started · would start {date}'**
  String planSavedDraftReady(String mode, String date);

  /// Subtitle of a saved built draft without exercises.
  ///
  /// In en, this message translates to:
  /// **'Draft · {mode} · add exercises to use it'**
  String planSavedDraftEmpty(String mode);

  /// Subtitle of a saved older draft.
  ///
  /// In en, this message translates to:
  /// **'Draft · not started · would start {date}'**
  String planSavedDraftOld(String date);

  /// Subtitle of a paused plan.
  ///
  /// In en, this message translates to:
  /// **'Paused · not your primary plan'**
  String get planSavedPaused;

  /// Subtitle of an active plan that is not primary.
  ///
  /// In en, this message translates to:
  /// **'Active · not your primary plan'**
  String get planSavedActive;

  /// Closed plan outcome.
  ///
  /// In en, this message translates to:
  /// **'Stopped early'**
  String get planStoppedEarly;

  /// Closed plan outcome.
  ///
  /// In en, this message translates to:
  /// **'Finished for now'**
  String get planFinishedForNow;

  /// Row: archived plans with their number.
  ///
  /// In en, this message translates to:
  /// **'Archived plans ({count})'**
  String planArchivedCount(int count);

  /// Plan note: not started yet.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get planNotStarted;

  /// Plan note / week state: paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get planPaused;

  /// Plan note: end date.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String planEnds(String date);

  /// Plan note: no end date.
  ///
  /// In en, this message translates to:
  /// **'Ongoing, no end date'**
  String get planOngoingNoEnd;

  /// Plan pass: start date before it starts.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String planStarts(String date);

  /// Status line on a paused plan.
  ///
  /// In en, this message translates to:
  /// **'Plan paused. No new workouts are expected, and nothing counts as missed while it is paused.'**
  String get planPausedLine;

  /// Button: resume the plan.
  ///
  /// In en, this message translates to:
  /// **'Resume plan'**
  String get planResume;

  /// Row: a suggested change to review.
  ///
  /// In en, this message translates to:
  /// **'Suggested change to review'**
  String get planSuggestedChange;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Manage this plan'**
  String get planManage;

  /// Action: edit the plan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get planEdit;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts, exercises and schedule from a date you choose. Recorded workouts never change.'**
  String get planEditSubtitle;

  /// Action: pause the plan.
  ///
  /// In en, this message translates to:
  /// **'Pause plan'**
  String get planPause;

  /// Action: duplicate the plan.
  ///
  /// In en, this message translates to:
  /// **'Duplicate plan'**
  String get planDuplicate;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'A new draft with the same workouts and schedule. This plan stays as it is.'**
  String get planDuplicateSubtitle;

  /// Row: request a movement swap.
  ///
  /// In en, this message translates to:
  /// **'Replace a movement in remaining workouts'**
  String get planReplaceMovement;

  /// Row: review or close the block.
  ///
  /// In en, this message translates to:
  /// **'Review or finish this block'**
  String get planReviewBlockRow;

  /// Row: create another plan.
  ///
  /// In en, this message translates to:
  /// **'Create a different plan'**
  String get planCreateDifferent;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Starting it will ask before replacing this one.'**
  String get planCreateDifferentSubtitle;

  /// Note under Manage this plan.
  ///
  /// In en, this message translates to:
  /// **'Your primary plan is paused, finished or replaced before it can be archived. Saved and past plans can be archived from their page.'**
  String get planArchiveNote;

  /// Section header: week grid.
  ///
  /// In en, this message translates to:
  /// **'Choose a week'**
  String get planChooseWeek;

  /// Section header: the current week.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get planThisWeek;

  /// Workouts completed in a week out of those expected.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} completed'**
  String planCompletedOf(int done, int total);

  /// Screen-reader label of the week progress rail.
  ///
  /// In en, this message translates to:
  /// **'Workouts completed in this week'**
  String get planWeekRailLabel;

  /// Empty week.
  ///
  /// In en, this message translates to:
  /// **'No workouts are planned in this week.'**
  String get planNoWorkoutsThisWeek;

  /// Note on the next rotation workout.
  ///
  /// In en, this message translates to:
  /// **'Next in the cycle'**
  String get planNextInCycle;

  /// Note on a projected rotation workout.
  ///
  /// In en, this message translates to:
  /// **'Projected'**
  String get planProjected;

  /// Projected, inside a line of facts.
  ///
  /// In en, this message translates to:
  /// **'projected'**
  String get planProjectedLower;

  /// Section header: the rotation.
  ///
  /// In en, this message translates to:
  /// **'Your cycle'**
  String get planYourCycle;

  /// Cycle number of a rotation. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Cycle {n}'**
  String planCycleN(int n);

  /// Rotation explanation with no training days chosen.
  ///
  /// In en, this message translates to:
  /// **'A rotation has no fixed dates. The next workout waits for you until you finish or skip it, and the cycle carries on across weeks. Upcoming days assume you train every day.'**
  String get planRotationNoteEveryDay;

  /// Rotation explanation with training days. days is a list of short weekday names.
  ///
  /// In en, this message translates to:
  /// **'A rotation has no fixed dates. The next workout waits for you until you finish or skip it, and the cycle carries on across weeks. Upcoming days follow your training days ({days}); the others are rest days.'**
  String planRotationNoteDays(String days);

  /// Section header: the next seven days.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get planComingUp;

  /// Nothing left in a rotation.
  ///
  /// In en, this message translates to:
  /// **'Nothing is left in this plan.'**
  String get planNothingLeft;

  /// Section header: recent rotation sessions.
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get planRecentSessions;

  /// Screen reader: one rotation step. name is the workout name.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}, {name}'**
  String planCycleStepSemantics(int step, int total, String name);

  /// Screen reader: the next rotation step.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}, {name}, next'**
  String planCycleStepNextSemantics(int step, int total, String name);

  /// Rotation pass line at the plan's end.
  ///
  /// In en, this message translates to:
  /// **'Cycle {cycle} · nothing left'**
  String planCycleNothingLeft(int cycle);

  /// Rotation pass line. name is the next workout.
  ///
  /// In en, this message translates to:
  /// **'Cycle {cycle} · step {step} of {total} · {name} next'**
  String planCycleLine(int cycle, int step, int total, String name);

  /// Screen reader for the plan pass. week is "Week 2 of 8".
  ///
  /// In en, this message translates to:
  /// **'{title}. {week}. {done} / {total} workouts completed.'**
  String planPassSemantics(String title, String week, int done, int total);

  /// Screen reader for the plan pass with a percentage.
  ///
  /// In en, this message translates to:
  /// **'{title}. {week}. {done} / {total} workouts completed, {percent}.'**
  String planPassSemanticsPercent(
    String title,
    String week,
    int done,
    int total,
    String percent,
  );

  /// Screen reader for a rotation pass. cycleLine is the cycle position line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{title}. {week}. 1 session completed this week. {cycleLine}.} other{{title}. {week}. {count} sessions completed this week. {cycleLine}.}}'**
  String planPassRotationSemantics(
    String title,
    String week,
    int count,
    String cycleLine,
  );

  /// Overline on the plan pass.
  ///
  /// In en, this message translates to:
  /// **'Training plan'**
  String get planTrainingPlanOverline;

  /// Label next to the completed count.
  ///
  /// In en, this message translates to:
  /// **'Workouts completed'**
  String get planWorkoutsCompleted;

  /// Label next to the count of rotation sessions completed this week (the number is shown before it).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Session completed this week} other{Sessions completed this week}}'**
  String planSessionsThisWeek(int count);

  /// A moved workout and its original date.
  ///
  /// In en, this message translates to:
  /// **'Moved · originally {date}'**
  String planMovedOriginally(String date);

  /// Week state.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planWeekDone;

  /// Week state.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get planWeekCurrent;

  /// Week state: completed out of expected.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String planWeekPartial(int done, int total);

  /// Week/occasion count: missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get planWeekMissed;

  /// Week/occasion count: skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get planWeekSkipped;

  /// Week state.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get planWeekUpcoming;

  /// Week state: no workouts.
  ///
  /// In en, this message translates to:
  /// **'No workouts'**
  String get planWeekEmpty;

  /// Screen reader: the tile is the current calendar week.
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get planThisWeekLower;

  /// Screen reader: a week with no expected workouts.
  ///
  /// In en, this message translates to:
  /// **'no workouts'**
  String get planNoWorkoutsLower;

  /// Screen reader: workouts completed in a week.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} workouts completed'**
  String planWorkoutsCompletedOf(int done, int total);

  /// Confirm title. title is the plan name.
  ///
  /// In en, this message translates to:
  /// **'Pause {title}?'**
  String planPauseTitle(String title);

  /// Confirm body when pausing a plan.
  ///
  /// In en, this message translates to:
  /// **'Future workouts stop being expected from today, and nothing will count as missed while it is paused. Your history and remaining workouts are kept.'**
  String get planPauseBody;

  /// Extra paragraph when an open workout exists. workout is its name.
  ///
  /// In en, this message translates to:
  /// **'Your open workout \"{workout}\" is not affected: its clock keeps running and you can still finish it.'**
  String planPauseOpenWorkout(String workout);

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Pause this plan'**
  String get planPauseAction;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Plan paused.'**
  String get planPausedToast;

  /// Date picker title. title is the workout name.
  ///
  /// In en, this message translates to:
  /// **'Move {title} to'**
  String planMoveHelp(String title);

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Move this workout?'**
  String get planMoveTitle;

  /// Confirm body for moving a workout. Dates are long dates.
  ///
  /// In en, this message translates to:
  /// **'Workout: {title} (week {week})\nCurrent date: {current}\nProposed date: {proposed}\nOriginally planned: {original}\nBlock ends: {end}\n\nIt stays the same workout in the same training week. No other workout changes, and the repeating schedule stays as it is.'**
  String planMoveBody(
    String title,
    int week,
    String current,
    String proposed,
    String original,
    String end,
  );

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Move workout'**
  String get planMoveAction;

  /// Confirm cancel.
  ///
  /// In en, this message translates to:
  /// **'Keep current dates'**
  String get planMoveCancel;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Moved to {date}.'**
  String planMovedToast(String date);

  /// Confirm title. title is the workout name.
  ///
  /// In en, this message translates to:
  /// **'Skip {title}?'**
  String planSkipTitle(String title);

  /// Confirm body for skipping a rotation workout.
  ///
  /// In en, this message translates to:
  /// **'{title} will be marked Skipped today and the rotation moves on to the workout after it. That next workout is not put on today: it comes up on your next training day, or you can start it now. No workout, sets or completion credit are created.'**
  String planSkipBodyRotation(String title);

  /// Confirm body for skipping a dated workout.
  ///
  /// In en, this message translates to:
  /// **'The workout planned for {date} will be marked Skipped. No workout, sets or completion credit are created, and it will not count as training.'**
  String planSkipBodyFixed(String date);

  /// Action: skip this workout.
  ///
  /// In en, this message translates to:
  /// **'Skip this workout'**
  String get planSkipAction;

  /// Confirm cancel.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get planSkipCancel;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Marked as skipped.'**
  String get planSkippedToast;

  /// When a projected rotation workout comes up.
  ///
  /// In en, this message translates to:
  /// **'Planned for {date}. A rotation has no fixed dates: this is when it comes up if you keep to your training days.'**
  String planVirtualWhen(String date);

  /// A moved workout's date and original date.
  ///
  /// In en, this message translates to:
  /// **'{date} · originally {original}'**
  String planDateOriginally(String date, String original);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Resume workout'**
  String get planResumeWorkout;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'View what was recorded'**
  String get planViewRecorded;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Undo skip'**
  String get planUndoSkip;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'No longer skipped.'**
  String get planUnskippedToast;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'Skipped. The rotation has moved on past it, so it stays skipped.'**
  String get planSkippedStays;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'The plan is paused. Resume the plan to start or reschedule its workouts.'**
  String get planPausedNoStart;

  /// Button: start an upcoming rotation workout now.
  ///
  /// In en, this message translates to:
  /// **'Start this workout now'**
  String get planStartNowRotation;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get planStartWorkout;

  /// Button: take a rest day today instead.
  ///
  /// In en, this message translates to:
  /// **'Rest today instead'**
  String get planRestInstead;

  /// Snackbar. title is the workout name.
  ///
  /// In en, this message translates to:
  /// **'Rest day. Nothing was skipped: {title} waits for your next training day.'**
  String planRestToast(String title);

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'A rotation has no dates to move: this workout waits for you until you do it or skip it.'**
  String get planRotationNoMove;

  /// Status line. title is the next workout.
  ///
  /// In en, this message translates to:
  /// **'Comes after {title}. A rotation runs in order: do or skip the next one first.'**
  String planComesAfter(String title);

  /// Status line when the next workout is unknown.
  ///
  /// In en, this message translates to:
  /// **'Comes after the workouts before it. A rotation runs in order: do or skip the next one first.'**
  String get planComesAfterEarlier;

  /// Warning on a missed workout.
  ///
  /// In en, this message translates to:
  /// **'Missed on {date}. Move it, skip it or do it now. It is never marked done by itself.'**
  String planMissedOn(String date);

  /// Button on a missed workout.
  ///
  /// In en, this message translates to:
  /// **'Start now'**
  String get planStartNowMissed;

  /// Button on an upcoming workout.
  ///
  /// In en, this message translates to:
  /// **'Start this workout early'**
  String get planStartEarly;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Move to another date'**
  String get planMoveDate;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Edit this workout only'**
  String get planEditOnlyThis;

  /// Sheet title.
  ///
  /// In en, this message translates to:
  /// **'Change the schedule'**
  String get planChangeSchedule;

  /// Row and picker title.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get planStartDate;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Block length'**
  String get planBlockLength;

  /// Caption above weekday checkboxes.
  ///
  /// In en, this message translates to:
  /// **'Training days (choose {count})'**
  String planTrainingDaysChoose(int count);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Update the draft'**
  String get planUpdateDraft;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Cancel and keep the reviewed schedule'**
  String get planCancelKeepSchedule;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot be reached. The draft is unchanged.'**
  String get planUnreachableDraft;

  /// Confirm title. title is the current plan.
  ///
  /// In en, this message translates to:
  /// **'Finish {title} and start this plan?'**
  String planFinishAndStartTitle(String title);

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Pause {title} and start this plan?'**
  String planPauseAndStartTitle(String title);

  /// Confirm body.
  ///
  /// In en, this message translates to:
  /// **'\"{current}\" will be closed as finished for now. \"{plan}\" becomes your primary plan from {date}. All recorded workouts are kept.'**
  String planStartFinishBody(String current, String plan, String date);

  /// Confirm body.
  ///
  /// In en, this message translates to:
  /// **'\"{current}\" will be paused, not deleted. You can resume it later. \"{plan}\" becomes your primary plan from {date}. All recorded workouts are kept.'**
  String planStartPauseBody(String current, String plan, String date);

  /// Extra paragraph.
  ///
  /// In en, this message translates to:
  /// **'Your open workout \"{workout}\" stays open with its recorded sets; you can still finish it.'**
  String planOpenWorkoutStaysOpen(String workout);

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Finish and start'**
  String get planFinishAndStart;

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Pause and start'**
  String get planPauseAndStart;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Plan saved. It starts {date}.'**
  String planSavedStarts(String date);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Your plan has started.'**
  String get planStarted;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'Draft — add exercises to use it. Every scheduled workout needs at least one exercise before the plan can start.'**
  String get planDraftNeedsExercises;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Start this plan'**
  String get planStartThis;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Finish current block and start'**
  String get planFinishBlockStart;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Replace my current plan'**
  String get planReplaceCurrent;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save for later'**
  String get planSaveForLater;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Draft · nothing is scheduled yet'**
  String get planDraftNothingScheduled;

  /// Cycle order. names are joined workout names.
  ///
  /// In en, this message translates to:
  /// **'Cycle: {names}'**
  String planCycleList(String names);

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Any day: the next workout is there whenever you train.'**
  String get planAnyDayNext;

  /// Caption. days is a list of short weekday names.
  ///
  /// In en, this message translates to:
  /// **'Training days: {days}'**
  String planTrainingDaysList(String days);

  /// Caption. value is "name, date" or a dash.
  ///
  /// In en, this message translates to:
  /// **'First workout: {value}'**
  String planFirstWorkout(String value);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Change dates, days or length'**
  String get planChangeDates;

  /// Panel.
  ///
  /// In en, this message translates to:
  /// **'You are following \"{title}\". Starting this plan will finish it. That needs your explicit confirmation; nothing is deleted.'**
  String planFollowingFinish(String title);

  /// Panel.
  ///
  /// In en, this message translates to:
  /// **'You are following \"{title}\". Starting this plan will pause it. That needs your explicit confirmation; nothing is deleted.'**
  String planFollowingPause(String title);

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Next sessions'**
  String get planNextSessions;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'First week'**
  String get planFirstWeek;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'A rotation has no fixed dates. These are the days the sequence would fall on from today; it waits for you if you miss one.'**
  String get planRotationReviewNote;

  /// Empty workout.
  ///
  /// In en, this message translates to:
  /// **'No exercises yet.'**
  String get planNoExercisesYetDot;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'The same workouts repeat each week with a recovery day between them. Targets are guidance; what you record is what counts.'**
  String get planRepeatOld;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'The sequence continues in order across weeks; it never restarts on Monday. It moves on only when you finish or skip a workout. Targets are guidance; what you record is what counts.'**
  String get planRepeatRotation;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'These workouts repeat on the same weekdays each week. Targets are guidance; what you record is what counts.'**
  String get planRepeatFixed;

  /// Page title. title is the plan name.
  ///
  /// In en, this message translates to:
  /// **'Resume {title}'**
  String planResumeTitle(String title);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Resume with these dates'**
  String get planResumeAccept;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Plan resumed.'**
  String get planResumedToast;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Keep paused'**
  String get planKeepPaused;

  /// Row title.
  ///
  /// In en, this message translates to:
  /// **'Next workout on'**
  String get planNextWorkoutOn;

  /// Date picker title.
  ///
  /// In en, this message translates to:
  /// **'Resume date'**
  String get planResumeDateHelp;

  /// Warning.
  ///
  /// In en, this message translates to:
  /// **'This makes it your primary plan and pauses \"{title}\".'**
  String planResumeDisplaces(String title);

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'No dates need to change. Remaining workouts keep their current dates.'**
  String get planResumeNoChanges;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Every remaining workout moves by the same number of days, keeping its spacing. Recorded, skipped and in-progress workouts keep their dates.'**
  String get planResumeShifts;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'The block would end {date}.'**
  String planBlockWouldEnd(String date);

  /// Extra paragraph.
  ///
  /// In en, this message translates to:
  /// **'Your open workout \"{workout}\" can still be finished afterwards; its result stays with this block.'**
  String planCloseOpenWorkout(String workout);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Block closed. Your history is kept.'**
  String get planBlockClosedToast;

  /// Page title and button.
  ///
  /// In en, this message translates to:
  /// **'Review this block'**
  String get planReviewBlock;

  /// Block count label.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get planCountFinished;

  /// Block count label.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get planCountPartial;

  /// Block count label.
  ///
  /// In en, this message translates to:
  /// **'Still ahead or in progress'**
  String get planCountRemaining;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Counts come from what was actually recorded for each planned workout. Reaching the end date does not by itself mean the training happened.'**
  String get planCountsNote;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'This block was stopped early.'**
  String get planBlockStoppedEarly;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'This block was finished for now.'**
  String get planBlockFinished;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Continue this goal'**
  String get planContinueGoal;

  /// Date picker title.
  ///
  /// In en, this message translates to:
  /// **'Next block starts'**
  String get planNextBlockStarts;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot be reached. Nothing was created.'**
  String get planUnreachableNothingCreated;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Creates a new draft with the same setup. It does not start until you review and start it.'**
  String get planContinueNote;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Finish for now'**
  String get planFinishForNow;

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Close this block?'**
  String get planCloseBlockTitle;

  /// Confirm body.
  ///
  /// In en, this message translates to:
  /// **'The block is closed as finished for now and your primary plan slot is freed. This does not say the goal was achieved.'**
  String get planCloseBlockBody;

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Close this block'**
  String get planCloseBlockAction;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Stop early'**
  String get planStopEarly;

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Stop this block early?'**
  String get planStopTitle;

  /// Confirm body. count is the remaining planned workouts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 planned workout will no longer be expected. The block is recorded as stopped early, not as finished.} other{{count} planned workouts will no longer be expected. The block is recorded as stopped early, not as finished.}}'**
  String planStopBody(int count);

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Stop this block'**
  String get planStopAction;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Resume as my primary plan'**
  String get planResumeAsPrimary;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Duplicate as a new plan'**
  String get planDuplicateAsNew;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Move out of the archive'**
  String get planUnarchive;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Archive (hide from this list)'**
  String get planArchiveHide;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Restored to your plans.'**
  String get planRestoredToast;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Archived. Its outcome and history are unchanged.'**
  String get planArchivedToast;

  /// State of a closed plan's workout that never happened.
  ///
  /// In en, this message translates to:
  /// **'Not done'**
  String get planNotDone;

  /// Page title.
  ///
  /// In en, this message translates to:
  /// **'Archived plans'**
  String get planArchivedTitle;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Archiving only hides a plan. Its outcome and recorded workouts are unchanged.'**
  String get planArchivedNote;

  /// Page title.
  ///
  /// In en, this message translates to:
  /// **'Replace a movement'**
  String get planReplaceMovementTitle;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Show me the change'**
  String get planShowChange;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot be reached. Nothing was changed.'**
  String get planUnreachableNothingChanged;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'You already chose to keep the current plan for exactly this change.'**
  String get planProposalDeclinedUnchanged;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to change for that choice.'**
  String get planNothingToChange;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Only remaining workouts that have not been started are affected. You will review the exact change before it applies.'**
  String get planSubstitutionNote;

  /// Section label: the movement to replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get planReplaceLabel;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'No remaining workout has a movement to replace.'**
  String get planNoMovement;

  /// Row title: the replacement movement.
  ///
  /// In en, this message translates to:
  /// **'With'**
  String get planWith;

  /// Row subtitle before a choice.
  ///
  /// In en, this message translates to:
  /// **'Choose a movement'**
  String get planChooseMovement;

  /// Exercise picker title.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get planReplaceWith;

  /// Warning.
  ///
  /// In en, this message translates to:
  /// **'Choose a movement from the list. Custom movements can be used inside a workout, not in a plan change.'**
  String get planCustomNotInPlanChange;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Change applied to the reviewed workouts.'**
  String get planChangeApplied;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Kept your current plan.'**
  String get planKeptCurrent;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'This suggestion no longer matches your plan or records, so it was not applied. Nothing changed.'**
  String get planSuggestionStale;

  /// Page title.
  ///
  /// In en, this message translates to:
  /// **'Suggested change'**
  String get planSuggestedChangeTitle;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Accept this change'**
  String get planAcceptChange;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Keep current plan'**
  String get planKeepCurrent;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Dismiss this suggestion'**
  String get planDismissSuggestion;

  /// Warning.
  ///
  /// In en, this message translates to:
  /// **'Your plan or recorded workouts changed after this was suggested, so it can no longer be applied as reviewed. Request it again if you still want it.'**
  String get planProposalStaleLine;

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'You accepted this change.'**
  String get planAcceptedLine;

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'You kept your current plan.'**
  String get planDeclinedLine;

  /// Section label: how many unstarted workouts the change affects.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Affects 1 unstarted workout} other{Affects {count} unstarted workouts}}'**
  String planAffects(int count);

  /// Proposed date change.
  ///
  /// In en, this message translates to:
  /// **'Now {from}  →  proposed {to}'**
  String planProposalMove(String from, String to);

  /// Proposed movement swap. from is a catalog key or name, to the proposed name.
  ///
  /// In en, this message translates to:
  /// **'Now: {from}\nProposed: {to}'**
  String planProposalNow(String from, String to);

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Recorded and in-progress workouts are never changed by a suggestion.'**
  String get planProposalNote;

  /// Builder step name.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get builderStepAvailability;

  /// Builder step name. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get builderStepStructure;

  /// Builder step name; also the section of the plan's workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get builderStepWorkouts;

  /// Builder step name.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get builderStepReview;

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Start over?'**
  String get builderStartOverTitle;

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Discard it'**
  String get builderDiscardAction;

  /// Confirm body.
  ///
  /// In en, this message translates to:
  /// **'The plan in progress is deleted from this phone. Nothing else changes: no plan was created from it.'**
  String get builderDiscardBody;

  /// Page title.
  ///
  /// In en, this message translates to:
  /// **'Create plan'**
  String get builderCreatePlan;

  /// A plan with no name yet.
  ///
  /// In en, this message translates to:
  /// **'Untitled plan'**
  String get builderUntitled;

  /// Where the saved plan in progress stopped.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 4 · {name}. Saved on this phone; nothing is active yet.'**
  String builderStepSaved(int step, String name);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Continue this plan'**
  String get builderContinuePlan;

  /// Link.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get builderStartOver;

  /// Screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Start over and discard this plan in progress'**
  String get builderStartOverSaid;

  /// Intro.
  ///
  /// In en, this message translates to:
  /// **'Both ways make a plan of your own that you can change at any time.'**
  String get builderBothWays;

  /// Choice card.
  ///
  /// In en, this message translates to:
  /// **'Guide me'**
  String get builderGuideMe;

  /// Choice card caption.
  ///
  /// In en, this message translates to:
  /// **'Help me choose a starting plan.'**
  String get builderGuideMeAbout;

  /// Choice card.
  ///
  /// In en, this message translates to:
  /// **'I know what I want'**
  String get builderKnowWhat;

  /// Choice card caption.
  ///
  /// In en, this message translates to:
  /// **'Choose a template or build my own.'**
  String get builderKnowWhatAbout;

  /// Screen reader for a choice card.
  ///
  /// In en, this message translates to:
  /// **'{label}. {about}'**
  String builderChoiceSemantics(String label, String about);

  /// Row.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get builderFromTemplate;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Preview a familiar split such as Upper / Lower or Push / Pull / Legs, then make it yours.'**
  String get builderFromTemplateSubtitle;

  /// Row.
  ///
  /// In en, this message translates to:
  /// **'Build my own'**
  String get builderBuildOwn;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Name your workouts, add exercises and arrange your week.'**
  String get builderBuildOwnSubtitle;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'This plan changed since you last edited it, so you start from the plan as it is now.'**
  String get builderPlanChanged;

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Continue your changes?'**
  String get builderContinueChangesTitle;

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Continue changes'**
  String get builderContinueChanges;

  /// Confirm cancel.
  ///
  /// In en, this message translates to:
  /// **'Start from the saved plan'**
  String get builderStartFromSaved;

  /// Confirm body. title is the plan name.
  ///
  /// In en, this message translates to:
  /// **'You were changing \"{title}\" and did not save. Continue where you left off, or start again from the plan as it is now.'**
  String builderContinueChangesBody(String title);

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Replace your plan in progress?'**
  String get builderReplaceInProgressTitle;

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Replace it'**
  String get builderReplaceIt;

  /// Confirm body.
  ///
  /// In en, this message translates to:
  /// **'\"{existing}\" is not finished. Duplicating \"{plan}\" replaces it on this phone.'**
  String builderReplaceInProgressBody(String existing, String plan);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'The latest change could not be saved on this phone. Keep this screen open and try again.'**
  String get builderSaveFailed;

  /// Coach help label.
  ///
  /// In en, this message translates to:
  /// **'Help with your training week'**
  String get builderHelpWeek;

  /// Coach line.
  ///
  /// In en, this message translates to:
  /// **'Pick the days you can train and your equipment. The next step suggests a starting point from these answers.'**
  String get builderCoachWeek;

  /// Ask GoHard context label.
  ///
  /// In en, this message translates to:
  /// **'Your training week'**
  String get builderAskWeek;

  /// Coach help label.
  ///
  /// In en, this message translates to:
  /// **'Help with choosing a split'**
  String get builderHelpSplit;

  /// Coach line.
  ///
  /// In en, this message translates to:
  /// **'Unsure which split fits your week? Let\'s compare your options.'**
  String get builderCoachSplit;

  /// Ask GoHard context label.
  ///
  /// In en, this message translates to:
  /// **'Choosing a split'**
  String get builderAskSplit;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Compare splits'**
  String get builderCompareSplits;

  /// Coach help label.
  ///
  /// In en, this message translates to:
  /// **'Help with these workouts'**
  String get builderHelpWorkouts;

  /// Coach line.
  ///
  /// In en, this message translates to:
  /// **'Questions about sets, reps or a movement? The info button beside each exercise has the built-in guide.'**
  String get builderCoachWorkouts;

  /// Blocking message.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day.'**
  String get builderChooseDay;

  /// Blocking message.
  ///
  /// In en, this message translates to:
  /// **'Choose a starting plan to continue.'**
  String get builderChooseStarting;

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Pause {title} and activate this plan?'**
  String builderPauseActivateTitle(String title);

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Pause and activate'**
  String get builderPauseActivate;

  /// Confirm body.
  ///
  /// In en, this message translates to:
  /// **'\"{current}\" will be paused, not deleted. Its history and recorded workouts are kept, and you can resume it later. \"{plan}\" becomes your plan from {date}.'**
  String builderPauseActivateBody(String current, String plan, String date);

  /// Extra paragraph.
  ///
  /// In en, this message translates to:
  /// **'Your open workout \"{workout}\" stays open with its recorded sets.'**
  String builderOpenWorkoutStays(String workout);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" is active. It starts {date}.'**
  String builderActiveStarts(String title, String date);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" is active.'**
  String builderActive(String title);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Draft saved on this phone. Nothing is active yet.'**
  String get builderDraftSaved;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Changes saved.'**
  String get builderChangesSaved;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Changes saved from {date}.'**
  String builderChangesSavedFrom(String date);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get builderBack;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get builderNext;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get builderSaveChanges;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Activate plan'**
  String get builderActivate;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get builderSaveDraft;

  /// Screen reader: builder progress.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 4: {name}'**
  String builderProgressSemantics(int step, String name);

  /// Overline: builder progress.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 4 · {name}'**
  String builderProgressOverline(int step, String name);

  /// Default name of a workout the user builds (letter A, B, C…). They can rename it.
  ///
  /// In en, this message translates to:
  /// **'Workout {letter}'**
  String builderDefaultWorkoutName(String letter);

  /// Intro of the availability step (Guide me).
  ///
  /// In en, this message translates to:
  /// **'Answer these and the next step suggests a starting plan from them, with up to two alternatives. Nothing is created until you choose, and you can change everything later.'**
  String get builderPrefsGuided;

  /// Intro of the availability step.
  ///
  /// In en, this message translates to:
  /// **'A few answers to suggest a starting point. You can change everything later.'**
  String get builderPrefsIntro;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Days a week'**
  String get builderDaysAWeek;

  /// Screen reader for a days-a-week chip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day a week} other{{count} days a week}}'**
  String builderDaysAWeekCount(int count);

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Which days'**
  String get builderWhichDays;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get builderEquipment;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Planned time per workout (optional)'**
  String get builderPlannedTime;

  /// Chip.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get builderNoLimit;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'The time you plan to spend. It is your choice, not a calculated length of the workout.'**
  String get builderPlannedTimeNote;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add your training experience (optional)'**
  String get builderAddExperience;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Training experience (optional)'**
  String get builderExperience;

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Replace your workouts?'**
  String get builderReplaceWorkoutsTitle;

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Replace them'**
  String get builderReplaceThem;

  /// Confirm body. source is a template name or "your own names"; now/next are workout name lists.
  ///
  /// In en, this message translates to:
  /// **'This starts the workouts again from {source}.\n\nNow: {now}\nAfter: {next}\n\nChanges you made to the exercises are not kept.'**
  String builderReplaceWorkoutsBody(String source, String now, String next);

  /// Source of workouts: the user's own names.
  ///
  /// In en, this message translates to:
  /// **'your own names'**
  String get builderYourOwnNames;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'Using this starting plan. It is a draft: change anything in the next steps.'**
  String get builderUsingStarting;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Use this starting plan'**
  String get builderUseStarting;

  /// Warning. name is the template now suggested.
  ///
  /// In en, this message translates to:
  /// **'Your answers now suggest {name}. Your edited workouts stay as they are unless you choose Use this starting plan below.'**
  String builderAnswersChanged(String name);

  /// Overline.
  ///
  /// In en, this message translates to:
  /// **'Suggested starting plan'**
  String get builderSuggestedStarting;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Your week'**
  String get builderYourWeek;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Why this suggestion?'**
  String get builderWhySuggestion;

  /// Section label above the other templates (Guide me).
  ///
  /// In en, this message translates to:
  /// **'Other starting points'**
  String get builderOtherStartingPoints;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Also fits your days'**
  String get builderAlsoFits;

  /// A day with no workout.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get builderRest;

  /// Subtitle of Rest.
  ///
  /// In en, this message translates to:
  /// **'No workout on this day'**
  String get builderRestSubtitle;

  /// Sheet title and button.
  ///
  /// In en, this message translates to:
  /// **'Add a step'**
  String get builderAddStep;

  /// Sheet title.
  ///
  /// In en, this message translates to:
  /// **'Plan length'**
  String get builderPlanLength;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get builderWeeks;

  /// Field helper.
  ///
  /// In en, this message translates to:
  /// **'1 to 52 weeks'**
  String get builderWeeksHelper;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Choose 1 to 52 weeks.'**
  String get builderWeeksError;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Use this length'**
  String get builderUseLength;

  /// Template preview of Build my own.
  ///
  /// In en, this message translates to:
  /// **'Name your own workouts and choose their days.'**
  String get builderTemplateCustomPreview;

  /// Template preview: one workout per chosen day. names is a list.
  ///
  /// In en, this message translates to:
  /// **'Your {count} days: {names}'**
  String builderTemplateWeekly(int count, String names);

  /// Template preview: workouts rotating over the days. names is joined with arrows.
  ///
  /// In en, this message translates to:
  /// **'Rotates {names} over your {count} days'**
  String builderTemplateRotates(String names, int count);

  /// Suggestion line. reason is a full sentence.
  ///
  /// In en, this message translates to:
  /// **'Suggested: {name}. {reason}'**
  String builderSuggestedLine(String name, String reason);

  /// Template title marked as suggested.
  ///
  /// In en, this message translates to:
  /// **'{name} · Suggested'**
  String builderTemplateSuggested(String name);

  /// Switch title.
  ///
  /// In en, this message translates to:
  /// **'Include starting exercises'**
  String get builderIncludeExercises;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'A starting routine with sets, reps and rest and no weights. Change anything in the next step.'**
  String get builderWithExercisesOn;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts start empty. The plan stays a draft until every scheduled workout has an exercise.'**
  String get builderWithExercisesOff;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Your workouts'**
  String get builderYourWorkouts;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Name each different workout once. A workout can repeat on several days.'**
  String get builderNameOnce;

  /// Field label: the nth workout.
  ///
  /// In en, this message translates to:
  /// **'Workout {n}'**
  String builderWorkoutN(int n);

  /// A workout with no name, inside a sentence.
  ///
  /// In en, this message translates to:
  /// **'workout {n}'**
  String builderWorkoutNLower(int n);

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Give it a name.'**
  String get builderGiveName;

  /// Tooltip and confirm title. name is a workout name.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String builderRemoveNamed(String name);

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String builderRemoveTitle(String name);

  /// Confirm body.
  ///
  /// In en, this message translates to:
  /// **'Its exercises are removed with it, and every day or step that used it.'**
  String get builderRemoveBody;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add a workout'**
  String get builderAddAWorkout;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'One workout per weekday. A workout can be used on several days. A missed workout stays on its day until you move or skip it.'**
  String get builderFixedNote;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'The cycle'**
  String get builderTheCycle;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Workouts follow this order and start again from the top when it ends. The order carries on across weeks; it does not restart on Monday.'**
  String get builderCycleNote;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Move step {n} up'**
  String builderMoveStepUp(int n);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Move step {n} down'**
  String builderMoveStepDown(int n);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove step {n}'**
  String builderRemoveStep(int n);

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Training days'**
  String get builderTrainingDays;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'The next workout goes on the next of these days. With none chosen, any day can be a training day.'**
  String get builderTrainingDaysNote;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get builderPlanName;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get builderName;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get builderSchedule;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'An active plan keeps its schedule type. Duplicate it to switch.'**
  String get builderModeLocked;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Fixed weekdays: each workout has its own weekday, and a missed one stays on its day.'**
  String get builderFixedExplain;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Rotating sequence: an ordered cycle that continues across weeks and moves on only when you finish or skip a workout.'**
  String get builderRotatingExplain;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Start and length'**
  String get builderStartAndLength;

  /// Row title.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get builderStarts;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'An active plan keeps its start date.'**
  String get builderStartLocked;

  /// Date picker title.
  ///
  /// In en, this message translates to:
  /// **'Plan starts'**
  String get builderPlanStartsHelp;

  /// Chip.
  ///
  /// In en, this message translates to:
  /// **'Other length'**
  String get builderOtherLength;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'A rotation can run for 1 to 52 weeks, or keep going with no end.'**
  String get builderRotationLength;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'A fixed-weekday plan has an end: 1 to 52 weeks.'**
  String get builderFixedLength;

  /// Section label: schedule from a date.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String builderFromDate(String date);

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Second week'**
  String get builderSecondWeek;

  /// Summary of a fixed plan. weeks is pre-formatted ("8 weeks").
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} workouts over {weeks}, the last on {date}. The same week repeats until then.}}'**
  String builderReviewSummary(int count, String weeks, String date);

  /// Review: the cycle. names joined with arrows.
  ///
  /// In en, this message translates to:
  /// **'Cycle: {names}, then it starts again.'**
  String builderCycleThenAgain(String names);

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Any day can be a training day.'**
  String get builderAnyDayTraining;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Training days: {days}.'**
  String builderTrainingDaysDot(String days);

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Next workouts if you train on each training day'**
  String get builderNextIfTrain;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'These dates are a projection. A missed day does not skip a workout: the same one waits for your next training day.'**
  String get builderProjectionNote;

  /// Review fact: planned time.
  ///
  /// In en, this message translates to:
  /// **'planned time {minutes} min'**
  String builderPlannedTimeLower(int minutes);

  /// Warning. names are workout names.
  ///
  /// In en, this message translates to:
  /// **'Draft — add exercises to {names} before this plan can be activated.'**
  String builderDraftMissing(String names);

  /// Panel.
  ///
  /// In en, this message translates to:
  /// **'You are following \"{title}\". Activating this plan pauses it. Its history and recorded workouts are kept, and you can resume it later.'**
  String builderFollowingActivate(String title);

  /// Row title and picker title.
  ///
  /// In en, this message translates to:
  /// **'Changes apply from'**
  String get builderChangesApplyFrom;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Workouts you recorded or skipped, and one in progress, stay exactly as they are. Earlier workouts and any you edited on their own do not change.'**
  String get builderEditKeeps;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'This plan has not started, so it is rebuilt with these changes.'**
  String get builderRebuilt;

  /// Empty workout in review.
  ///
  /// In en, this message translates to:
  /// **'No exercises yet'**
  String get builderNoExercises;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Targets are a starting point, not a prescription. What you record is what counts.'**
  String get builderTargetsNote;

  /// Where a rotation uses a workout. steps is a list of step numbers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Step {steps}} other{Steps {steps}}}'**
  String builderUsageSteps(int count, String steps);

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Sets: a whole number from 1 to 20.'**
  String get builderRxSetsError;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Reps: 1 to 100.'**
  String get builderRxRepsError;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'The highest reps cannot be fewer than the lowest.'**
  String get builderRxRepsOrder;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Time: 1 to 3600 seconds.'**
  String get builderRxTimeError;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Rest: 0 to 900 seconds (15 minutes).'**
  String get builderRxRestError;

  /// Field error. max is a formatted load.
  ///
  /// In en, this message translates to:
  /// **'A weight from 0 to {max}, or leave it empty.'**
  String builderRxLoadError(String max);

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Notes: up to 500 characters.'**
  String get builderRxNotesError;

  /// Coach help label.
  ///
  /// In en, this message translates to:
  /// **'Help with sets, reps and this exercise'**
  String get builderRxHelp;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get builderRxSets;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Time per set (seconds)'**
  String get builderRxSeconds;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Reps, lowest'**
  String get builderRxRepsMin;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Reps, highest'**
  String get builderRxRepsMax;

  /// Field helper.
  ///
  /// In en, this message translates to:
  /// **'The same number twice is an exact target.'**
  String get builderRxRepsHelper;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Rest between sets (seconds)'**
  String get builderRxRest;

  /// Field label. unit is kg or lb.
  ///
  /// In en, this message translates to:
  /// **'Target weight ({unit}), optional'**
  String builderRxLoad(String unit);

  /// Field helper.
  ///
  /// In en, this message translates to:
  /// **'A target you set for yourself. It is not your last recorded weight, and the app never fills it in.'**
  String get builderRxLoadHelper;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Notes, optional'**
  String get builderRxNotes;

  /// Coach line.
  ///
  /// In en, this message translates to:
  /// **'Questions about sets, reps or this movement?'**
  String get builderCoachExercise;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'About this exercise'**
  String get builderAboutExercise;

  /// Exercise picker title. name is the exercise.
  ///
  /// In en, this message translates to:
  /// **'Replace {name}'**
  String builderReplaceExercise(String name);

  /// Warning.
  ///
  /// In en, this message translates to:
  /// **'No exercises yet. Add at least one so this workout can be scheduled.'**
  String get builderNoExercisesWarn;

  /// Hint and menu item.
  ///
  /// In en, this message translates to:
  /// **'Edit sets, reps and rest'**
  String get builderEditRx;

  /// Tooltip. name is an exercise.
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String builderAbout(String name);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Move {name} up'**
  String builderMoveUp(String name);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Move {name} down'**
  String builderMoveDown(String name);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'More for {name}'**
  String builderMoreFor(String name);

  /// Menu item.
  ///
  /// In en, this message translates to:
  /// **'Replace with another exercise'**
  String get builderReplaceWithAnother;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get builderAddExercise;

  /// Exercise picker title. name is a workout.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}'**
  String builderAddTo(String name);

  /// Sheet title.
  ///
  /// In en, this message translates to:
  /// **'Copy a workout'**
  String get builderCopyWorkout;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'The copy becomes a new workout of this plan with the same exercises. Nothing links back to where it came from.'**
  String get builderCopyNote;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'This plan'**
  String get builderThisPlan;

  /// Section label.
  ///
  /// In en, this message translates to:
  /// **'Workouts you recorded (their planned exercises)'**
  String get builderRecordedSection;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Copied. Choose its days in Structure to schedule it.'**
  String get builderCopied;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Tap an exercise to change its sets, reps and rest. Targets are a starting point; what you record is what counts.'**
  String get builderWorkoutsIntro;

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled yet. Choose its days in Structure.'**
  String get builderNotScheduled;

  /// Menu item.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get builderRename;

  /// Menu item.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get builderDuplicate;

  /// Sheet title.
  ///
  /// In en, this message translates to:
  /// **'Rename workout'**
  String get builderRenameWorkout;

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String builderDeleteTitle(String name);

  /// Confirm action.
  ///
  /// In en, this message translates to:
  /// **'Delete workout'**
  String get builderDeleteWorkout;

  /// Confirm body.
  ///
  /// In en, this message translates to:
  /// **'It is removed from this plan and from every day or step that uses it. Workouts you already recorded keep their own copy.'**
  String get builderDeleteBody;

  /// Button and confirm action.
  ///
  /// In en, this message translates to:
  /// **'Add workout'**
  String get builderAddWorkout;

  /// Sheet title.
  ///
  /// In en, this message translates to:
  /// **'New workout'**
  String get builderNewWorkout;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Copy from…'**
  String get builderCopyFrom;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'Give the workout a name.'**
  String get builderGiveWorkoutName;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Saved for {date} only.'**
  String builderSavedOnly(String date);

  /// Page title.
  ///
  /// In en, this message translates to:
  /// **'This workout only'**
  String get builderThisWorkoutOnly;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save this workout'**
  String get builderSaveThisWorkout;

  /// Status line.
  ///
  /// In en, this message translates to:
  /// **'Only the workout on {date} changes. The rest of \"{plan}\" stays as it is, and later changes to the plan leave this one alone.'**
  String builderOnlyThisChanges(String date, String plan);

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Workout name'**
  String get builderWorkoutName;

  /// Activity type as a title or segment label. kind is the stored type id: run or walk.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Walk} other{Run}}'**
  String runActivityTitle(String kind);

  /// Title of the Run / Walk screen and its help sheet.
  ///
  /// In en, this message translates to:
  /// **'Run / Walk'**
  String get runTitle;

  /// Run / Walk history: the app bar button and the history screen title.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get runHistory;

  /// Screen reader label of the coach avatar on the Run / Walk Ready screen.
  ///
  /// In en, this message translates to:
  /// **'Help with Run / Walk'**
  String get runHelpAvatar;

  /// Coach bubble on Ready when intervals are set.
  ///
  /// In en, this message translates to:
  /// **'Intervals are set. Start when you\'re ready.'**
  String get runCoachReadyIntervals;

  /// Coach bubble on Ready.
  ///
  /// In en, this message translates to:
  /// **'Choose your setup. Start when ready.'**
  String get runCoachReady;

  /// Coach help sheet text on Run / Walk.
  ///
  /// In en, this message translates to:
  /// **'Choose Run or Walk, then Start. GoHard records your route while the screen is locked or another app is open, and saves it on this phone first. Pause any time; Finish lets you review before saving. Intervals alternate running and walking in one activity; with Voice and alerts on, I say each change aloud.'**
  String get runHelpBody;

  /// Ready's main Start button. kind: run or walk.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Start walk} other{Start run}}'**
  String runStartButton(String kind);

  /// Ready's Start button when intervals are set. kind: run or walk.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Start walk intervals} other{Start run intervals}}'**
  String runStartIntervalsButton(String kind);

  /// Confirmation title when location is not allowed.
  ///
  /// In en, this message translates to:
  /// **'Start without GPS?'**
  String get runStartNoGpsTitle;

  /// Confirmation body when starting without GPS.
  ///
  /// In en, this message translates to:
  /// **'The time is recorded, and you can type a distance when you finish. No route or GPS distance is recorded.'**
  String get runStartNoGpsBody;

  /// Confirm button: start recording time without GPS.
  ///
  /// In en, this message translates to:
  /// **'Start timer only'**
  String get runStartNoGpsAction;

  /// Error when the activity could not be started locally.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{The walk could not be started on this phone. Nothing was recorded.} other{The run could not be started on this phone. Nothing was recorded.}}'**
  String runStartFailed(String kind);

  /// State value of a Ready setup row (voice, auto-pause).
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get runStateOn;

  /// State value of a Ready setup row (intervals, voice, auto-pause).
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get runStateOff;

  /// Voice row value on Ready. interval is a distance with unit ("1 km") or minutes ("5 min").
  ///
  /// In en, this message translates to:
  /// **'On · every {interval}'**
  String runVoiceValueEvery(String interval);

  /// Screen reader label of Ready's map before a position.
  ///
  /// In en, this message translates to:
  /// **'Map, no position yet'**
  String get runMapNoPosition;

  /// Screen reader label of Ready's map with a position.
  ///
  /// In en, this message translates to:
  /// **'Map showing your current position'**
  String get runMapHere;

  /// Title of the expanded map page, and the Map view segment while recording.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get runMapTitle;

  /// Warning line in a test build with simulated GPS.
  ///
  /// In en, this message translates to:
  /// **'Simulated GPS (test build)'**
  String get runSimulatedGps;

  /// Overline of Ready's setup group.
  ///
  /// In en, this message translates to:
  /// **'Your setup'**
  String get runSetupTitle;

  /// Intervals: setup row, sheet title, activity heading.
  ///
  /// In en, this message translates to:
  /// **'Intervals'**
  String get runSetupIntervals;

  /// Voice and alerts setup row and sheet title.
  ///
  /// In en, this message translates to:
  /// **'Voice and alerts'**
  String get runSetupVoice;

  /// Auto-pause setup row, sheet and switch title.
  ///
  /// In en, this message translates to:
  /// **'Auto-pause'**
  String get runSetupAutoPause;

  /// Auto-pause row value when intervals are set.
  ///
  /// In en, this message translates to:
  /// **'Not used with intervals'**
  String get runAutoPauseNotWithIntervals;

  /// Auto-pause switch explanation.
  ///
  /// In en, this message translates to:
  /// **'Pauses when you stop for a while and resumes when you move on.'**
  String get runAutoPauseSubtitle;

  /// Note in the auto-pause sheet when intervals are set.
  ///
  /// In en, this message translates to:
  /// **'Not used with intervals: walking to recover is not a pause. This choice applies to your free runs and walks.'**
  String get runAutoPauseIntervalsNote;

  /// Intervals row summary. run/walk are durations ("1 min", "90 s"); reps is the count.
  ///
  /// In en, this message translates to:
  /// **'Run {run} · Walk {walk} · × {reps}'**
  String runPlanShort(String run, String walk, int reps);

  /// GPS card title while reading location settings.
  ///
  /// In en, this message translates to:
  /// **'Checking GPS…'**
  String get runGpsChecking;

  /// GPS card detail.
  ///
  /// In en, this message translates to:
  /// **'Reading this phone\'s location settings.'**
  String get runGpsCheckingDetail;

  /// GPS card title: location services are off.
  ///
  /// In en, this message translates to:
  /// **'Location is off'**
  String get runGpsOff;

  /// GPS card detail.
  ///
  /// In en, this message translates to:
  /// **'Turn on location to record a route.'**
  String get runGpsOffDetail;

  /// GPS card action: open location settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get runGpsOpenSettings;

  /// GPS card title.
  ///
  /// In en, this message translates to:
  /// **'Location not allowed yet'**
  String get runGpsNotAllowed;

  /// GPS card detail.
  ///
  /// In en, this message translates to:
  /// **'Allow location while using GoHard to record your route.'**
  String get runGpsNotAllowedDetail;

  /// GPS card action: ask for location permission.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get runGpsAllow;

  /// GPS card title.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for GoHard'**
  String get runGpsBlocked;

  /// GPS card detail.
  ///
  /// In en, this message translates to:
  /// **'Allow it in Settings, or start with the timer only.'**
  String get runGpsBlockedDetail;

  /// GPS card action.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get runGpsOpenAppSettings;

  /// GPS card title: only approximate location allowed.
  ///
  /// In en, this message translates to:
  /// **'Precise location is off'**
  String get runGpsApproximate;

  /// GPS card detail.
  ///
  /// In en, this message translates to:
  /// **'Approximate location cannot measure a route.'**
  String get runGpsApproximateDetail;

  /// GPS card action.
  ///
  /// In en, this message translates to:
  /// **'Allow precise location'**
  String get runGpsAllowPrecise;

  /// GPS card title.
  ///
  /// In en, this message translates to:
  /// **'Location is not available'**
  String get runGpsUnavailable;

  /// GPS card detail.
  ///
  /// In en, this message translates to:
  /// **'You can still start with the timer only.'**
  String get runGpsUnavailableDetail;

  /// GPS card title before the first fix.
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS…'**
  String get runGpsWaiting;

  /// GPS card detail.
  ///
  /// In en, this message translates to:
  /// **'Outdoors, with a clear view of the sky, it takes a few seconds.'**
  String get runGpsWaitingDetail;

  /// GPS card title with a good fix.
  ///
  /// In en, this message translates to:
  /// **'GPS ready'**
  String get runGpsReady;

  /// GPS card title with a poor fix.
  ///
  /// In en, this message translates to:
  /// **'GPS signal weak'**
  String get runGpsWeak;

  /// GPS signal quality.
  ///
  /// In en, this message translates to:
  /// **'Good signal'**
  String get runGpsSignalGood;

  /// GPS signal quality.
  ///
  /// In en, this message translates to:
  /// **'Fair signal'**
  String get runGpsSignalFair;

  /// GPS signal quality.
  ///
  /// In en, this message translates to:
  /// **'Weak signal'**
  String get runGpsSignalWeak;

  /// GPS card detail. accuracy is pre-formatted ("±5 m").
  ///
  /// In en, this message translates to:
  /// **'{quality} · {accuracy} accuracy'**
  String runGpsAccuracyDetail(String quality, String accuracy);

  /// Recording status pill.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get runStatusPaused;

  /// Recording status pill.
  ///
  /// In en, this message translates to:
  /// **'Auto-paused'**
  String get runStatusAutoPaused;

  /// Recording status pill: the recorder stopped (app closed).
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get runStatusInterrupted;

  /// Screen reader label of the live map.
  ///
  /// In en, this message translates to:
  /// **'Route so far'**
  String get runMapRouteSoFar;

  /// Screen reader label of the live map with its distance.
  ///
  /// In en, this message translates to:
  /// **'Route so far, {distance}'**
  String runMapRouteSoFarDistance(String distance);

  /// Recording control: stop and review.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get runFinish;

  /// Recording control.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get runResume;

  /// Recording control. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get runPause;

  /// Note on an interrupted activity from the build before routes.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{This walk was started before routes were kept. Its time and distance so far are kept; resume to record the rest with a route.} other{This run was started before routes were kept. Its time and distance so far are kept; resume to record the rest with a route.}}'**
  String runInterruptedLegacy(String kind);

  /// Note on an interrupted recording.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped when GoHard was closed. The time since then is left out. Resume to go on, or Finish to save it.'**
  String get runInterrupted;

  /// Note while recording without GPS.
  ///
  /// In en, this message translates to:
  /// **'Timer only: no GPS route or distance is recorded. You can type a distance when you finish.'**
  String get runTimerOnlyNote;

  /// Error while recording: local storage writes fail.
  ///
  /// In en, this message translates to:
  /// **'This phone is not saving the recording right now. Keep GoHard open; it keeps trying.'**
  String get runNotSaving;

  /// Warning while recording: the GPS stream ended with an error.
  ///
  /// In en, this message translates to:
  /// **'GPS stopped giving positions. The timer goes on; distance resumes when GPS does.'**
  String get runGpsStopped;

  /// Tooltip of the speaker button while recording, voice on.
  ///
  /// In en, this message translates to:
  /// **'Voice updates on. Turn off'**
  String get runVoiceToggleOn;

  /// Tooltip of the speaker button while recording, voice off.
  ///
  /// In en, this message translates to:
  /// **'Voice updates off. Turn on'**
  String get runVoiceToggleOff;

  /// Screen reader label of the coach help button while recording.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Help with recording a walk} other{Help with recording a run}}'**
  String runHelpRecording(String kind);

  /// Recording view segment: the dial and figures. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get runViewStats;

  /// Steps figure label and row title.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get runSteps;

  /// Steps figure while recording when only part was counted.
  ///
  /// In en, this message translates to:
  /// **'Steps (partly)'**
  String get runStepsPartly;

  /// Steps figure label when steps could not be counted.
  ///
  /// In en, this message translates to:
  /// **'Steps not counted'**
  String get runStepsNotCounted;

  /// Steps figure on the save review when only part was counted.
  ///
  /// In en, this message translates to:
  /// **'Steps (part of the time)'**
  String get runStepsPartOfTime;

  /// Label of the recording's active time.
  ///
  /// In en, this message translates to:
  /// **'Active time'**
  String get runActiveTime;

  /// Screen reader text of the active time.
  ///
  /// In en, this message translates to:
  /// **'Active time {duration}'**
  String runActiveTimeSaid(String duration);

  /// Screen reader text of the dial while paused.
  ///
  /// In en, this message translates to:
  /// **'Active time {duration}, paused'**
  String runActiveTimePausedSaid(String duration);

  /// Screen reader text of a figure: its label then its value with unit.
  ///
  /// In en, this message translates to:
  /// **'{label} {value}'**
  String runFigureSaid(String label, String value);

  /// Screen reader text of a figure with no value.
  ///
  /// In en, this message translates to:
  /// **'{label} not known'**
  String runFigureSaidUnknown(String label);

  /// Distance figure label. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get runDistance;

  /// Average pace over moving time, figure label.
  ///
  /// In en, this message translates to:
  /// **'Avg. moving pace'**
  String get runAvgMovingPace;

  /// GPS chip on the map while recording.
  ///
  /// In en, this message translates to:
  /// **'Timer only'**
  String get runChipTimerOnly;

  /// GPS chip.
  ///
  /// In en, this message translates to:
  /// **'GPS off'**
  String get runChipGpsOff;

  /// GPS chip.
  ///
  /// In en, this message translates to:
  /// **'GPS lost'**
  String get runChipGpsLost;

  /// GPS chip.
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS'**
  String get runChipWaiting;

  /// GPS chip with accuracy ("±5 m"). The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'GPS · {accuracy}'**
  String runChipGps(String accuracy);

  /// Default title of an activity started 5–12 h. Becomes the user's stored title.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Morning walk} other{Morning run}}'**
  String runTitleMorning(String kind);

  /// Default title, 12–17 h.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Afternoon walk} other{Afternoon run}}'**
  String runTitleAfternoon(String kind);

  /// Default title, 17–21 h.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Evening walk} other{Evening run}}'**
  String runTitleEvening(String kind);

  /// Default title, 21–5 h.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Night walk} other{Night run}}'**
  String runTitleNight(String kind);

  /// Save review page title.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Save your walk} other{Save your run}}'**
  String runSaveTitle(String kind);

  /// Save review primary button.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Save walk} other{Save run}}'**
  String runSaveButton(String kind);

  /// Screen reader label of a saved route map.
  ///
  /// In en, this message translates to:
  /// **'Recorded route'**
  String get runRecordedRoute;

  /// Save review line when there is no route.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{No GPS route was recorded for this walk.} other{No GPS route was recorded for this run.}}'**
  String runNoRouteFor(String kind);

  /// Save review line for a legacy activity without a route.
  ///
  /// In en, this message translates to:
  /// **'Route not recorded.'**
  String get runRouteNotRecordedLine;

  /// Title of the no-route panel and history row note.
  ///
  /// In en, this message translates to:
  /// **'Route not recorded'**
  String get runRouteNotRecorded;

  /// Distance figure label without GPS distance.
  ///
  /// In en, this message translates to:
  /// **'Distance not measured'**
  String get runDistanceNotMeasured;

  /// Figure label.
  ///
  /// In en, this message translates to:
  /// **'Moving time'**
  String get runMovingTime;

  /// Screen reader text.
  ///
  /// In en, this message translates to:
  /// **'Moving time {duration}'**
  String runMovingTimeSaid(String duration);

  /// Activity title field.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get runTitleField;

  /// Notes field on the save review.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get runNotesOptional;

  /// Notes field in the edit sheet. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get runNotesField;

  /// Typed distance field when GPS measured nothing.
  ///
  /// In en, this message translates to:
  /// **'Distance (optional)'**
  String get runDistanceOptional;

  /// Typed distance field when GPS measured a distance.
  ///
  /// In en, this message translates to:
  /// **'Correct the distance (optional)'**
  String get runCorrectDistance;

  /// Helper of the typed distance field.
  ///
  /// In en, this message translates to:
  /// **'Typed, not measured by GPS.'**
  String get runDistanceTypedHelper;

  /// Helper of the correct-distance field.
  ///
  /// In en, this message translates to:
  /// **'The GPS measurement is kept beside it; the route is not changed.'**
  String get runDistanceGpsKeptHelper;

  /// Edit sheet helper of the correct-distance field.
  ///
  /// In en, this message translates to:
  /// **'Blank keeps the GPS measurement ({distance}).'**
  String runBlankKeepsGps(String distance);

  /// Save review: back to recording.
  ///
  /// In en, this message translates to:
  /// **'Resume recording'**
  String get runResumeRecording;

  /// Save review discard button and its confirm action.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Discard walk} other{Discard run}}'**
  String runDiscardButton(String kind);

  /// Discard confirmation title.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Discard this walk?} other{Discard this run?}}'**
  String runDiscardTitle(String kind);

  /// Discard confirmation body.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{The walk and its route are deleted from this phone and your account. This cannot be undone.} other{The run and its route are deleted from this phone and your account. This cannot be undone.}}'**
  String runDiscardBody(String kind);

  /// Typed distance validation error.
  ///
  /// In en, this message translates to:
  /// **'Enter the distance as a number, or leave it blank.'**
  String get runDistanceInvalid;

  /// Title validation error on save.
  ///
  /// In en, this message translates to:
  /// **'Give it a title of 1 to 80 characters.'**
  String get runTitleInvalid;

  /// Title validation error in the edit sheet.
  ///
  /// In en, this message translates to:
  /// **'Give it a title.'**
  String get runTitleRequired;

  /// Save review error.
  ///
  /// In en, this message translates to:
  /// **'It could not be saved on this phone. Nothing was lost; try Save again.'**
  String get runSaveFailed;

  /// Interval setup sheet intro.
  ///
  /// In en, this message translates to:
  /// **'Alternate running and walking. Walking to recover is part of the session, not a pause: it is one activity.'**
  String get runIntervalsIntro;

  /// Interval setup: the preset and its source (NHS Couch to 5K). Keep the source name.
  ///
  /// In en, this message translates to:
  /// **'Starting point: Run 1 min, walk 1½ min, 8 times, as in week 1 of the NHS Couch to 5K plan. Change anything.'**
  String get runIntervalsPresetNote;

  /// Button: reset intervals to the preset.
  ///
  /// In en, this message translates to:
  /// **'Use it'**
  String get runIntervalsUsePreset;

  /// Interval setup row.
  ///
  /// In en, this message translates to:
  /// **'Warm-up walk'**
  String get runIntervalWarmup;

  /// Interval setup row: run phase length.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get runIntervalRun;

  /// Interval setup row: walk phase length.
  ///
  /// In en, this message translates to:
  /// **'Walk / recover'**
  String get runIntervalWalk;

  /// Interval setup row: number of rounds.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get runIntervalRepeats;

  /// Interval setup row.
  ///
  /// In en, this message translates to:
  /// **'Cool-down walk'**
  String get runIntervalCooldown;

  /// Interval setup value: no warm-up or cool-down.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get runIntervalNone;

  /// Screen reader value: no warm-up or cool-down.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get runIntervalNoneSaid;

  /// Interval repeats shown ("8 ×").
  ///
  /// In en, this message translates to:
  /// **'{count} ×'**
  String runIntervalRepsValue(int count);

  /// Screen reader value of the repeats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} times}}'**
  String runIntervalRepsSaid(int count);

  /// Tooltip of the minus button of an interval row.
  ///
  /// In en, this message translates to:
  /// **'Less {label}'**
  String runIntervalLess(String label);

  /// Tooltip of the plus button of an interval row.
  ///
  /// In en, this message translates to:
  /// **'More {label}'**
  String runIntervalMore(String label);

  /// Interval setup total. time is a clock ("30:00").
  ///
  /// In en, this message translates to:
  /// **'Programmed active time {time}'**
  String runIntervalTotal(String time);

  /// Interval setup primary button.
  ///
  /// In en, this message translates to:
  /// **'Use these intervals'**
  String get runIntervalsUse;

  /// Interval setup button.
  ///
  /// In en, this message translates to:
  /// **'Turn intervals off'**
  String get runIntervalsOff;

  /// Plan summary part.
  ///
  /// In en, this message translates to:
  /// **'{time} warm-up'**
  String runPlanWarmup(String time);

  /// Plan summary part. run/walk are clocks ("1:00").
  ///
  /// In en, this message translates to:
  /// **'{reps} × run {run}, walk {walk}'**
  String runPlanRepeats(int reps, String run, String walk);

  /// Plan summary part.
  ///
  /// In en, this message translates to:
  /// **'{time} cool-down'**
  String runPlanCooldown(String time);

  /// Interval phase name.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get runPhaseWarmup;

  /// Interval phase name.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get runPhaseRun;

  /// Interval phase name.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get runPhaseWalk;

  /// Interval phase name.
  ///
  /// In en, this message translates to:
  /// **'Cool-down'**
  String get runPhaseCooldown;

  /// A duration said aloud or to screen readers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String runSpokenSeconds(int count);

  /// A duration said aloud or to screen readers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String runSpokenMinutes(int count);

  /// Minutes and seconds said together ("1 minute 30 seconds"). Both pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{minutes} {seconds}'**
  String runSpokenMinutesSeconds(String minutes, String seconds);

  /// Interval bar: current round.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String runRoundOf(int round, int total);

  /// Interval bar button.
  ///
  /// In en, this message translates to:
  /// **'Skip phase'**
  String get runSkipPhase;

  /// Time left in a phase (clock or spoken duration).
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String runTimeLeft(String time);

  /// Interval bar: next phase and its length.
  ///
  /// In en, this message translates to:
  /// **'Next: {phase} {time}'**
  String runNextPhase(String phase, String time);

  /// Screen reader: next phase name (lower case in English).
  ///
  /// In en, this message translates to:
  /// **'Next: {phase}'**
  String runNextPhaseSaid(String phase);

  /// Panel title after the last phase.
  ///
  /// In en, this message translates to:
  /// **'Intervals finished'**
  String get runIntervalsFinished;

  /// Panel text after the last phase.
  ///
  /// In en, this message translates to:
  /// **'Still recording. Keep going freely, or finish and review.'**
  String get runIntervalsStillRecording;

  /// Button after the last phase.
  ///
  /// In en, this message translates to:
  /// **'Continue freely'**
  String get runContinueFreely;

  /// Button after the last phase.
  ///
  /// In en, this message translates to:
  /// **'Finish and review'**
  String get runFinishAndReview;

  /// Coach cue (shown and spoken) after the last phase.
  ///
  /// In en, this message translates to:
  /// **'Intervals finished. Continue freely, or finish and review.'**
  String get runCueIntervalsDone;

  /// Coach cue with no phase left.
  ///
  /// In en, this message translates to:
  /// **'Intervals finished.'**
  String get runCueIntervalsFinished;

  /// Coach cue as the warm-up begins. duration is spoken ("5 minutes").
  ///
  /// In en, this message translates to:
  /// **'Warm up: walk for {duration}.'**
  String runCueWarmup(String duration);

  /// Coach cue as a run phase begins.
  ///
  /// In en, this message translates to:
  /// **'Run for {duration}.'**
  String runCueRun(String duration);

  /// Coach cue as the last run phase begins.
  ///
  /// In en, this message translates to:
  /// **'Final round. Run for {duration}.'**
  String runCueFinalRun(String duration);

  /// Coach cue as a walk phase begins.
  ///
  /// In en, this message translates to:
  /// **'Walk and recover for {duration}.'**
  String runCueWalk(String duration);

  /// Coach cue as the cool-down begins.
  ///
  /// In en, this message translates to:
  /// **'Cool down: walk for {duration}.'**
  String runCueCooldown(String duration);

  /// Coach update shown on screen. distance with unit ("2 km").
  ///
  /// In en, this message translates to:
  /// **'{distance} completed.'**
  String runCueDistanceDone(String distance);

  /// Coach update on screen. time is a clock.
  ///
  /// In en, this message translates to:
  /// **'Active time {time}.'**
  String runCueActiveTime(String time);

  /// Coach update on screen. pace with unit ("5:33 /km").
  ///
  /// In en, this message translates to:
  /// **'Avg. moving pace {pace}.'**
  String runCuePace(String pace);

  /// Coach time update on screen.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min active.'**
  String runCueMinutesActive(int minutes);

  /// Spoken whole distance in kilometres.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 kilometre} other{{count} kilometres}}'**
  String runSaidKilometres(int count);

  /// Spoken whole distance in miles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 mile} other{{count} miles}}'**
  String runSaidMiles(int count);

  /// Spoken decimal distance ("1.5 kilometres").
  ///
  /// In en, this message translates to:
  /// **'{value} kilometres'**
  String runSaidKilometresDecimal(String value);

  /// Spoken decimal distance in miles.
  ///
  /// In en, this message translates to:
  /// **'{value} miles'**
  String runSaidMilesDecimal(String value);

  /// Spoken update. duration spoken ("10 minutes").
  ///
  /// In en, this message translates to:
  /// **'Active time {duration}.'**
  String runSaidActiveTime(String duration);

  /// Spoken pace. unit: km or mi.
  ///
  /// In en, this message translates to:
  /// **'{unit, select, mi{Average moving pace {duration} per mile.} other{Average moving pace {duration} per kilometre.}}'**
  String runSaidPace(String unit, String duration);

  /// Spoken time update.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute active.} other{{minutes} minutes active.}}'**
  String runSaidMinutesActive(int minutes);

  /// Voice preview said by the coach. name is the coach display name (Leon/Leona; ليون/ليونا in Arabic).
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m {name}. I\'ll tell you when to run, when to walk, and how far you\'ve gone.'**
  String runVoicePreviewLine(String name);

  /// Voice sheet switch.
  ///
  /// In en, this message translates to:
  /// **'Voice updates'**
  String get runVoiceUpdates;

  /// Voice switch subtitle. name is the coach display name; guide (leon or leona) only selects verb agreement in Arabic.
  ///
  /// In en, this message translates to:
  /// **'{name} says interval changes, updates and personal bests aloud, in a voice installed on this phone. Nothing is sent anywhere.'**
  String runVoiceUpdatesSubtitle(String guide, String name);

  /// Voice sheet: label of the update mode.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get runVoiceUpdatesLabel;

  /// Update mode: none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get runVoiceUpdatesNone;

  /// Update mode: by distance. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get runVoiceUpdatesDistance;

  /// Update mode: by time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get runVoiceUpdatesTime;

  /// Voice sheet explanation.
  ///
  /// In en, this message translates to:
  /// **'Each update says the distance, the active time and the average moving pace (moving time ÷ distance), only once GPS has measured enough.'**
  String get runVoiceUpdatesExplain;

  /// Voice choice field.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get runVoiceField;

  /// Voice field helper: the chosen voice is gone.
  ///
  /// In en, this message translates to:
  /// **'The voice chosen before is not installed or needs a connection: the phone\'s own voice is used.'**
  String get runVoiceMissing;

  /// Voice field helper: no installed offline voice in the app's language. Name the app language in fr/ar.
  ///
  /// In en, this message translates to:
  /// **'No voice for this language that works offline is installed, so nothing is said aloud. Prompts still show on screen and vibration still works.'**
  String get runVoiceNoneForLanguage;

  /// Voice field helper.
  ///
  /// In en, this message translates to:
  /// **'Only voices that work without a connection are listed.'**
  String get runVoiceOfflineOnly;

  /// Voice choice: automatic, an installed offline voice in the app language.
  ///
  /// In en, this message translates to:
  /// **'The phone\'s own voice'**
  String get runVoicePhoneDefault;

  /// Voice sheet button.
  ///
  /// In en, this message translates to:
  /// **'Preview voice'**
  String get runVoicePreview;

  /// Voice sheet switch.
  ///
  /// In en, this message translates to:
  /// **'Vibrate at interval changes'**
  String get runVoiceVibrate;

  /// Voice sheet switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Also with the screen locked on Android. On iPhone, while GoHard is open.'**
  String get runVoiceVibrateSubtitle;

  /// Voice sheet switch.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get runVoiceCountdown;

  /// Voice sheet switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'A tick each second for the last three seconds of a phase.'**
  String get runVoiceCountdownSubtitle;

  /// Voice sheet footnote.
  ///
  /// In en, this message translates to:
  /// **'Interval changes are always shown on screen. These choices are kept on this phone.'**
  String get runVoiceFooter;

  /// Personal bests title, row and page.
  ///
  /// In en, this message translates to:
  /// **'Personal bests'**
  String get runPersonalBests;

  /// A personal best with no activity yet.
  ///
  /// In en, this message translates to:
  /// **'Not set yet'**
  String get runBestNotSet;

  /// Personal best category.
  ///
  /// In en, this message translates to:
  /// **'Longest run'**
  String get runBestLongestRun;

  /// Personal best category.
  ///
  /// In en, this message translates to:
  /// **'Longest walk'**
  String get runBestLongestWalk;

  /// Personal best category (always 1 km).
  ///
  /// In en, this message translates to:
  /// **'Fastest 1 km run'**
  String get runBestFastest1kRun;

  /// Personal best category (always 5 km).
  ///
  /// In en, this message translates to:
  /// **'Fastest 5 km run'**
  String get runBestFastest5kRun;

  /// Personal best category (always 1 km).
  ///
  /// In en, this message translates to:
  /// **'Fastest 1 km walk'**
  String get runBestFastest1kWalk;

  /// Personal bests footnote.
  ///
  /// In en, this message translates to:
  /// **'From saved activities whose distance GPS measured. A fastest time is the quickest continuous stretch of that distance, timed from its start to its end; a pause or a GPS gap breaks a stretch. Typed or corrected distances do not count.'**
  String get runBestsFootnote;

  /// Added to the bests footnote when older activities lack fastest times.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 earlier activity was saved before fastest times were kept and counts only for distance, if measured.} other{{count} earlier activities were saved before fastest times were kept and count only for distance, if measured.}}'**
  String runBestsUnchecked(int count);

  /// History bests row with no record.
  ///
  /// In en, this message translates to:
  /// **'None yet: they come from saved activities measured by GPS'**
  String get runBestsNoneYet;

  /// Pill on an activity holding a record.
  ///
  /// In en, this message translates to:
  /// **'Personal best · {label}'**
  String runBestPill(String label);

  /// Part of the new-record message, lower case (the first is capitalized in code).
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{your longest walk so far, {distance}} other{your longest run so far, {distance}}}'**
  String runRecordLongest(String kind, String distance);

  /// Part of the new-record message. benchmark is "1 km" or "5 km"; time a clock.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{your fastest {benchmark} walk so far, {time}} other{your fastest {benchmark} run so far, {time}}}'**
  String runRecordFastest(String kind, String benchmark, String time);

  /// Two new-record parts together.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String runRecordsTwo(String first, String second);

  /// Three new-record parts together.
  ///
  /// In en, this message translates to:
  /// **'{first}, {second} and {third}'**
  String runRecordsThree(String first, String second, String third);

  /// When an activity started: short date, year, time of day.
  ///
  /// In en, this message translates to:
  /// **'{date}, {year} · {time}'**
  String runActivityWhen(String date, String year, String time);

  /// Activity menu item.
  ///
  /// In en, this message translates to:
  /// **'Export GPX'**
  String get runExportGpx;

  /// Activity distance label.
  ///
  /// In en, this message translates to:
  /// **'Distance not recorded'**
  String get runDistanceNotRecorded;

  /// Activity distance label.
  ///
  /// In en, this message translates to:
  /// **'Distance (typed)'**
  String get runDistanceTyped;

  /// Activity distance label.
  ///
  /// In en, this message translates to:
  /// **'Distance (corrected)'**
  String get runDistanceCorrected;

  /// Activity time label (legacy activity).
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get runTime;

  /// Screen reader text.
  ///
  /// In en, this message translates to:
  /// **'Time {duration}'**
  String runTimeSaid(String duration);

  /// Elapsed time (clock).
  ///
  /// In en, this message translates to:
  /// **'Elapsed {time}'**
  String runElapsed(String time);

  /// Activity line.
  ///
  /// In en, this message translates to:
  /// **'Elevation gain not measured'**
  String get runElevationGainNotMeasured;

  /// Activity line.
  ///
  /// In en, this message translates to:
  /// **'Elevation gain {value}'**
  String runElevationGain(String value);

  /// Activity detail tab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get runTabOverview;

  /// Activity detail tab: pace per km or mile.
  ///
  /// In en, this message translates to:
  /// **'Splits'**
  String get runTabSplits;

  /// Activity detail tab.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get runTabCharts;

  /// Activity summary sync state.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone, waiting to sync'**
  String get runSyncPending;

  /// Activity summary sync state.
  ///
  /// In en, this message translates to:
  /// **'Needs your review in Me › Sync'**
  String get runSyncReview;

  /// Activity summary sync state.
  ///
  /// In en, this message translates to:
  /// **'Saved to your account'**
  String get runSyncSaved;

  /// Route sync state.
  ///
  /// In en, this message translates to:
  /// **'Route saved to your account'**
  String get runRouteSyncSaved;

  /// Route sync state.
  ///
  /// In en, this message translates to:
  /// **'No route to sync'**
  String get runRouteSyncNone;

  /// Route sync state.
  ///
  /// In en, this message translates to:
  /// **'Route kept on the phone that recorded it'**
  String get runRouteSyncKept;

  /// Route sync state.
  ///
  /// In en, this message translates to:
  /// **'Route upload needs attention'**
  String get runRouteSyncAttention;

  /// Route sync state.
  ///
  /// In en, this message translates to:
  /// **'Route on this phone, waiting to upload'**
  String get runRouteSyncWaiting;

  /// Activity row.
  ///
  /// In en, this message translates to:
  /// **'Avg. speed'**
  String get runAvgSpeed;

  /// Activity row.
  ///
  /// In en, this message translates to:
  /// **'Elevation loss'**
  String get runElevationLoss;

  /// Activity row: the GPS distance beside a corrected one.
  ///
  /// In en, this message translates to:
  /// **'Measured by GPS'**
  String get runMeasuredByGps;

  /// Activity row.
  ///
  /// In en, this message translates to:
  /// **'GPS points used'**
  String get runGpsPointsUsed;

  /// GPS points used, with rejected count.
  ///
  /// In en, this message translates to:
  /// **'{points} ({count} left out as inaccurate)'**
  String runGpsPointsRejected(String points, int count);

  /// Activity row: stretches without GPS.
  ///
  /// In en, this message translates to:
  /// **'Gaps'**
  String get runGaps;

  /// Gaps row value.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} stretch(es) without GPS, not counted}}'**
  String runGapsValue(int count);

  /// Activity row: legacy distance.
  ///
  /// In en, this message translates to:
  /// **'Before routes were kept'**
  String get runBeforeRoutes;

  /// Legacy distance row value.
  ///
  /// In en, this message translates to:
  /// **'{distance} with no route'**
  String runBeforeRoutesValue(String distance);

  /// Activity row: sync state of the summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get runSummary;

  /// Activity row: sync state of the route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get runRoute;

  /// Note on a partial route.
  ///
  /// In en, this message translates to:
  /// **'Part of this route was not recorded. Distance and pace cover only what GPS measured.'**
  String get runPartialRoute;

  /// Interval session summary.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} runs completed'**
  String runIntervalsRunsCompleted(int done, int total);

  /// A skipped interval phase.
  ///
  /// In en, this message translates to:
  /// **'Ended early (planned {time})'**
  String runEndedEarly(String time);

  /// Splits tab, empty.
  ///
  /// In en, this message translates to:
  /// **'No splits: there is no GPS distance.'**
  String get runNoSplits;

  /// Splits tab hint.
  ///
  /// In en, this message translates to:
  /// **'Select a split to see it on the map.'**
  String get runSelectSplit;

  /// The last, partial split.
  ///
  /// In en, this message translates to:
  /// **'{number} · last {distance}'**
  String runSplitLast(int number, String distance);

  /// Split subtitle.
  ///
  /// In en, this message translates to:
  /// **'Partial split'**
  String get runPartialSplit;

  /// Split subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shown on the map'**
  String get runShownOnMap;

  /// Charts tab, empty.
  ///
  /// In en, this message translates to:
  /// **'No charts: no GPS route was recorded.'**
  String get runNoCharts;

  /// Pace chart title.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get runChartPace;

  /// Pace chart note. step is "100 m" or "0.1 mi".
  ///
  /// In en, this message translates to:
  /// **'Every {step}; faster is higher. Breaks are gaps or pauses.'**
  String runChartPaceNote(String step);

  /// Charts tab.
  ///
  /// In en, this message translates to:
  /// **'Too little distance for a pace chart.'**
  String get runChartPaceTooShort;

  /// Elevation chart title.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get runChartElevation;

  /// Elevation chart caption.
  ///
  /// In en, this message translates to:
  /// **'Gain not measured'**
  String get runGainNotMeasured;

  /// Elevation chart caption.
  ///
  /// In en, this message translates to:
  /// **'{value} gain'**
  String runGainShort(String value);

  /// Charts tab.
  ///
  /// In en, this message translates to:
  /// **'This phone did not report altitude precise enough to chart.'**
  String get runNoAltitude;

  /// Screen reader label of a chart.
  ///
  /// In en, this message translates to:
  /// **'Chart from {from} to {to} over {distance}'**
  String runChartSaid(String from, String to, String distance);

  /// Edit sheet button.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get runSaveChanges;

  /// Edit sheet error.
  ///
  /// In en, this message translates to:
  /// **'That could not be saved on this phone. Your changes are still here.'**
  String get runEditSaveFailed;

  /// Delete confirmation title.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Delete this walk?} other{Delete this run?}}'**
  String runDeleteTitle(String kind);

  /// Delete confirmation body. date is a long date.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{The walk from {date} and its route are deleted from this phone and your account.} other{The run from {date} and its route are deleted from this phone and your account.}}'**
  String runDeleteBody(String kind, String date);

  /// Delete confirmation button.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Delete walk} other{Delete run}}'**
  String runDeleteAction(String kind);

  /// Delete error toast.
  ///
  /// In en, this message translates to:
  /// **'It could not be deleted on this phone. Nothing changed.'**
  String get runDeleteFailed;

  /// Export error toast.
  ///
  /// In en, this message translates to:
  /// **'The GPX file could not be made on this phone.'**
  String get runGpxFailed;

  /// No-route panel, legacy activity.
  ///
  /// In en, this message translates to:
  /// **'Recorded before GoHard kept routes. Its time and distance are as they were saved.'**
  String get runNoRouteLegacy;

  /// No-route panel, typed distance.
  ///
  /// In en, this message translates to:
  /// **'Timed without GPS; the distance was typed.'**
  String get runNoRouteManual;

  /// No-route panel.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{No GPS position was recorded for this walk.} other{No GPS position was recorded for this run.}}'**
  String runNoRoutePositions(String kind);

  /// History filter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get runFilterAll;

  /// History row of the open activity.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Walk in progress} other{Run in progress}}'**
  String runInProgress(String kind);

  /// History row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Started {date}'**
  String runStartedOn(String date);

  /// History totals.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get runThisWeek;

  /// History totals.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get runThisMonth;

  /// History empty title. filter: all, run or walk.
  ///
  /// In en, this message translates to:
  /// **'{filter, select, run{No runs yet} walk{No walks yet} other{No activities yet}}'**
  String runHistoryEmpty(String filter);

  /// History empty text.
  ///
  /// In en, this message translates to:
  /// **'{filter, select, run{Saved runs appear here, every one of them.} walk{Saved walks appear here, every one of them.} other{Saved runs and walks appear here, every one of them.}}'**
  String runHistoryEmptyBody(String filter);

  /// History empty action.
  ///
  /// In en, this message translates to:
  /// **'Start one'**
  String get runStartOne;

  /// Screen reader text of a totals tile.
  ///
  /// In en, this message translates to:
  /// **'{label}: {count} saved, {distance}, {duration} active'**
  String runTotalsSaid(
    String label,
    int count,
    String distance,
    String duration,
  );

  /// Screen reader text of a totals tile where some distances are unknown.
  ///
  /// In en, this message translates to:
  /// **'{label}: {count} saved, {distance} where distance is known, {duration} active'**
  String runTotalsSaidPartial(
    String label,
    int count,
    String distance,
    String duration,
  );

  /// Totals tile line: activity count and active time.
  ///
  /// In en, this message translates to:
  /// **'{count} · {duration} active'**
  String runTotalsLine(int count, String duration);

  /// Android foreground recording notification title.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{GoHard is recording your walk} other{GoHard is recording your run}}'**
  String runNotificationTitle(String kind);

  /// Android foreground recording notification text.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Open GoHard to pause or finish. Location is used only for this walk.} other{Open GoHard to pause or finish. Location is used only for this run.}}'**
  String runNotificationText(String kind);

  /// Android notification channel name.
  ///
  /// In en, this message translates to:
  /// **'Run / Walk recording'**
  String get runNotificationChannel;

  /// Default screen reader label of a route map.
  ///
  /// In en, this message translates to:
  /// **'Route map'**
  String get runMapRoute;

  /// Map button state: camera follows.
  ///
  /// In en, this message translates to:
  /// **'Following your position'**
  String get runMapFollowing;

  /// Map button.
  ///
  /// In en, this message translates to:
  /// **'Recenter'**
  String get runMapRecenter;

  /// Map button: show the whole route.
  ///
  /// In en, this message translates to:
  /// **'Fit route'**
  String get runMapFit;

  /// Map button.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get runMapZoomIn;

  /// Map button.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get runMapZoomOut;

  /// Caption when map tiles are unavailable.
  ///
  /// In en, this message translates to:
  /// **'Route drawn without a map'**
  String get runMapNoTiles;

  /// Map button: open a larger map.
  ///
  /// In en, this message translates to:
  /// **'Expand map'**
  String get runMapExpand;

  /// Steps sheet title and setup row label.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get stepsTitle;

  /// Steps switch.
  ///
  /// In en, this message translates to:
  /// **'Count steps'**
  String get stepsCount;

  /// Steps switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'With this phone\'s motion sensor: during a run or walk, and today\'s total. Walking without your phone is not counted.'**
  String get stepsCountSubtitle;

  /// Steps access state.
  ///
  /// In en, this message translates to:
  /// **'Motion access is not allowed yet.'**
  String get stepsMotionNotAllowed;

  /// Steps access state.
  ///
  /// In en, this message translates to:
  /// **'Motion access is off for GoHard. Turn it on in the phone\'s settings.'**
  String get stepsMotionBlocked;

  /// Steps access state.
  ///
  /// In en, this message translates to:
  /// **'This phone has no step counter. Run / Walk records everything else.'**
  String get stepsNoCounter;

  /// Steps action: ask for motion access.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get stepsAllow;

  /// Steps action: open the phone's settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get stepsSettings;

  /// Steps goal field.
  ///
  /// In en, this message translates to:
  /// **'Daily steps goal (optional)'**
  String get stepsGoalLabel;

  /// Steps goal helper.
  ///
  /// In en, this message translates to:
  /// **'Your own number. Leave it blank for none.'**
  String get stepsGoalHelper;

  /// Steps switch: show the tile on Today.
  ///
  /// In en, this message translates to:
  /// **'Show Steps on Today'**
  String get stepsOnToday;

  /// Steps switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Only what Today shows. Counting and access are not changed.'**
  String get stepsOnTodaySubtitle;

  /// Steps sheet footnote. source is "This iPhone" or "Health Connect".
  ///
  /// In en, this message translates to:
  /// **'Today\'s total is read from {source} and stays on this phone: it is never sent to your account. The steps of a run or walk are saved with it and sync with your account. The two are never added together.'**
  String stepsFooter(String source);

  /// Ready steps row label.
  ///
  /// In en, this message translates to:
  /// **'Steps off'**
  String get stepsOff;

  /// Ready steps row label.
  ///
  /// In en, this message translates to:
  /// **'Steps on'**
  String get stepsOn;

  /// Ready steps row value.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get stepsChecking;

  /// Ready steps row value.
  ///
  /// In en, this message translates to:
  /// **'Simulated (test build)'**
  String get stepsSimulated;

  /// Ready steps row value.
  ///
  /// In en, this message translates to:
  /// **'Counted with this phone'**
  String get stepsCounted;

  /// Ready steps row value.
  ///
  /// In en, this message translates to:
  /// **'Motion access needed'**
  String get stepsMotionNeeded;

  /// Ready steps row value.
  ///
  /// In en, this message translates to:
  /// **'Motion access off'**
  String get stepsMotionOff;

  /// Ready steps row value.
  ///
  /// In en, this message translates to:
  /// **'Not on this phone'**
  String get stepsNotOnPhone;

  /// Ready steps row action.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get stepsEnable;

  /// Activity steps value counted only part of the time.
  ///
  /// In en, this message translates to:
  /// **'{steps} (part of the time)'**
  String stepsPartOfTime(String steps);

  /// Activity steps value.
  ///
  /// In en, this message translates to:
  /// **'Not counted: motion access is off'**
  String get stepsNotCountedMotion;

  /// Activity steps value.
  ///
  /// In en, this message translates to:
  /// **'Not counted: no step sensor'**
  String get stepsNotCountedSensor;

  /// Activity steps value: steps were off.
  ///
  /// In en, this message translates to:
  /// **'Not counted'**
  String get stepsNotCounted;

  /// Activity steps value: saved before steps existed (unknown, not zero).
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get stepsNotRecorded;

  /// Daily steps unavailable on iPhone.
  ///
  /// In en, this message translates to:
  /// **'This iPhone cannot count steps.'**
  String get stepsDailyUnavailableIos;

  /// Daily steps unavailable on Android. Health Connect is a product name.
  ///
  /// In en, this message translates to:
  /// **'Daily steps on Android come from Health Connect, which is not available on this phone.'**
  String get stepsDailyUnavailableAndroid;

  /// Name of the daily steps source on iPhone.
  ///
  /// In en, this message translates to:
  /// **'This iPhone'**
  String get stepsSourceIphone;

  /// Name of the simulated daily steps source.
  ///
  /// In en, this message translates to:
  /// **'This phone (simulated)'**
  String get stepsSourceSimulated;

  /// Overline on the training pass card above the plan's name.
  ///
  /// In en, this message translates to:
  /// **'Training plan'**
  String get shellPassCardOverline;

  /// Screen-reader sentence for the training pass card. shape says which optional parts exist. title is the plan name (user content), week the calendar position, count and caption the completed figure and its words, percent the progress. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'{shape, select, weekPercent{{title}. {week}. {count} {caption}, {percent}.} week{{title}. {week}. {count} {caption}.} percent{{title}. {count} {caption}, {percent}.} other{{title}. {count} {caption}.}}'**
  String shellPassCardSemantics(
    String shape,
    String title,
    String week,
    String count,
    String caption,
    String percent,
  );

  /// Title of the full-screen notice when this app version is too old for the server.
  ///
  /// In en, this message translates to:
  /// **'Update GoHard to continue'**
  String get shellUpdateTitle;

  /// Explanation on the update-required notice.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is too old for your account\'s server, so it has stopped syncing.'**
  String get shellUpdateBody;

  /// Update-required notice, when nothing is waiting to sync.
  ///
  /// In en, this message translates to:
  /// **'Everything you saved on this phone is still here.'**
  String get shellUpdateSavedHere;

  /// Update-required notice with the number of saved changes waiting to sync (1 or more).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Everything you saved on this phone is still here, including 1 change waiting to sync. They will sync after you update.} other{Everything you saved on this phone is still here, including {count} changes waiting to sync. They will sync after you update.}}'**
  String shellUpdateSavedPending(int count);

  /// Button on the update-required notice: asks the server again whether this version is accepted.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get shellUpdateCheckAgain;

  /// Title of the developer notice shown when the build has no server address.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get shellConfigTitle;

  /// Developer notice under the configuration problem.
  ///
  /// In en, this message translates to:
  /// **'This build has no default server on purpose. Start it with the development script so it knows which API to use.'**
  String get shellConfigBody;

  /// Explanation of the Can't sync state (Today and Me).
  ///
  /// In en, this message translates to:
  /// **'The last attempt to reach your account did not get through. That can be this phone\'s connection or the server.'**
  String get shellCantSyncDetail;

  /// Banner above the navigation bar when saved changes need a decision.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved change needs your review. Nothing was lost. Tap to review.} other{{count} saved changes need your review. Nothing was lost. Tap to review.}}'**
  String shellReviewBanner(int count);

  /// Sign-in/create-account error when a field is empty.
  ///
  /// In en, this message translates to:
  /// **'Fill in every field to continue.'**
  String get authFillEveryField;

  /// Page title of the create-account form.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountTitle;

  /// Page title of the sign-in form.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// Lead line under Create account.
  ///
  /// In en, this message translates to:
  /// **'Know what to do next, and keep a record of what you actually did.'**
  String get authRegisterLead;

  /// Lead line under Welcome back.
  ///
  /// In en, this message translates to:
  /// **'Sign in to pick up where you left off.'**
  String get authSignInLead;

  /// Three short lines on the sign-in photo panel (keep the line breaks).
  ///
  /// In en, this message translates to:
  /// **'Plan it.\nRecord it.\nKeep going.'**
  String get authTagline;

  /// Notice on the sign-in screen after the session expired.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in expired. Sign in again to keep syncing; everything saved on this phone is still here.'**
  String get authNoticeExpired;

  /// Notice on the sign-in screen after deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Your account and its data were deleted.'**
  String get authNoticeAccountDeleted;

  /// Name field on the create-account form.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authNameLabel;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Password field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Tooltip of the password visibility button while the password is shown.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// Tooltip of the password visibility button while the password is hidden.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// Submit button of the create-account form.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountButton;

  /// Submit button of the sign-in form.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInButton;

  /// Switches the create-account form to sign-in.
  ///
  /// In en, this message translates to:
  /// **'I already have an account · Sign in'**
  String get authToggleToSignIn;

  /// Switches the sign-in form to create-account.
  ///
  /// In en, this message translates to:
  /// **'New to GoHard? Create account'**
  String get authToggleToRegister;

  /// Setup step 1 page title.
  ///
  /// In en, this message translates to:
  /// **'Choose your coach'**
  String get setupCoachTitle;

  /// Setup step 1 explanation. Leon and Leona are the coach names.
  ///
  /// In en, this message translates to:
  /// **'Leon or Leona: the same help either way, only the look changes. You can change this later in Appearance.'**
  String get setupCoachSubtitle;

  /// Skips the rest of setup.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get setupNotNow;

  /// The chosen coach introduces itself in its speech bubble. name is the coach's name.
  ///
  /// In en, this message translates to:
  /// **'I\'m {name}. Tap me on any screen when you\'d like a hand.'**
  String setupCoachHello(String name);

  /// Coach bubble title when the user's name is unknown.
  ///
  /// In en, this message translates to:
  /// **'Hi!'**
  String get setupHi;

  /// Coach bubble title with the user's first name (user content).
  ///
  /// In en, this message translates to:
  /// **'Hi {name}!'**
  String setupHiName(String name);

  /// Setup step 2 page title.
  ///
  /// In en, this message translates to:
  /// **'Optional features'**
  String get setupFeaturesTitle;

  /// Setup step 2 explanation. Me is the profile tab.
  ///
  /// In en, this message translates to:
  /// **'Turn on what you want now, or later in Me. The phone asks for access only when you use a feature that needs it.'**
  String get setupFeaturesSubtitle;

  /// Setup row: weather scene at the top of the Today tab.
  ///
  /// In en, this message translates to:
  /// **'Weather on Today'**
  String get setupWeatherTitle;

  /// Setup weather row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your approximate location, or choose a city without sharing it.'**
  String get setupWeatherSubtitle;

  /// Setup row: workout reminder notifications.
  ///
  /// In en, this message translates to:
  /// **'Workout reminders'**
  String get setupRemindersTitle;

  /// Setup reminders row subtitle.
  ///
  /// In en, this message translates to:
  /// **'On days with a planned workout. Notifications are asked for when you turn this on.'**
  String get setupRemindersSubtitle;

  /// Setup row: scanning food barcodes.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning'**
  String get setupBarcodeTitle;

  /// Setup barcode row subtitle. Eat is the nutrition tab.
  ///
  /// In en, this message translates to:
  /// **'Ready in Eat. The camera is asked for the first time you scan.'**
  String get setupBarcodeSubtitle;

  /// Setup row: runs measured by GPS.
  ///
  /// In en, this message translates to:
  /// **'GPS runs'**
  String get setupGpsTitle;

  /// Setup GPS row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready on Today. Location is asked for when you start a run.'**
  String get setupGpsSubtitle;

  /// Footnote at the end of setup.
  ///
  /// In en, this message translates to:
  /// **'Anything you allow or refuse can be changed later in the phone\'s Settings; Me › Phone permissions shows what is allowed now.'**
  String get setupPermissionsFootnote;

  /// Setup progress at the top trailing edge.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String setupStep(int step, int total);

  /// Today greeting by time of day (morning 5–12, afternoon 12–18, evening otherwise). name is the user's first name (user content).
  ///
  /// In en, this message translates to:
  /// **'{part, select, morning{Good morning, {name}!} afternoon{Good afternoon, {name}!} other{Good evening, {name}!}}'**
  String todayGreetingNamed(String part, String name);

  /// Today greeting by time of day when no name is known.
  ///
  /// In en, this message translates to:
  /// **'{part, select, morning{Good morning!} afternoon{Good afternoon!} other{Good evening!}}'**
  String todayGreetingPlain(String part);

  /// Greeting line right after finishing a workout.
  ///
  /// In en, this message translates to:
  /// **'Your workout is saved. Nice work.'**
  String get todayLineSaved;

  /// Greeting line while a workout is open.
  ///
  /// In en, this message translates to:
  /// **'Your workout is ready to resume.'**
  String get todayLineResume;

  /// Greeting line naming today's planned workout. title is the workout name from the plan.
  ///
  /// In en, this message translates to:
  /// **'{title} is planned today.'**
  String todayLineDue(String title);

  /// Greeting line when today's planned workout is completed.
  ///
  /// In en, this message translates to:
  /// **'Today\'s workout is done.'**
  String get todayLineFinished;

  /// Greeting line when today's planned workout was partly completed.
  ///
  /// In en, this message translates to:
  /// **'Today\'s workout is saved.'**
  String get todayLinePartial;

  /// Greeting line when today's planned workout was skipped.
  ///
  /// In en, this message translates to:
  /// **'Today\'s workout is skipped.'**
  String get todayLineSkipped;

  /// Greeting line on a planned rest day.
  ///
  /// In en, this message translates to:
  /// **'A planned rest day today.'**
  String get todayLineRest;

  /// Greeting line while the plan is paused.
  ///
  /// In en, this message translates to:
  /// **'Your plan is paused today.'**
  String get todayLinePaused;

  /// Coach bubble introducing the Steps tile.
  ///
  /// In en, this message translates to:
  /// **'Want to track your daily movement? Enable steps here.'**
  String get todayCoachStepsIntro;

  /// Button in the coach bubble that opens the Steps sheet.
  ///
  /// In en, this message translates to:
  /// **'Enable steps'**
  String get todayCoachEnableSteps;

  /// Coach bubble line when there is nothing definite to say about today.
  ///
  /// In en, this message translates to:
  /// **'Need a hand with today?'**
  String get todayCoachNeedHand;

  /// Today's sky line: why the scenic view shows instead of weather.
  ///
  /// In en, this message translates to:
  /// **'Location not allowed yet'**
  String get todaySkyNeedsPermission;

  /// Today's sky line: location permission refused.
  ///
  /// In en, this message translates to:
  /// **'Location not allowed'**
  String get todaySkyDenied;

  /// Today's sky line: location services are off on the phone.
  ///
  /// In en, this message translates to:
  /// **'Location is off'**
  String get todaySkyServicesOff;

  /// Today's sky line: the phone did not find its location in time.
  ///
  /// In en, this message translates to:
  /// **'No location in time'**
  String get todaySkyTimeout;

  /// Today's sky line: the weather service did not answer.
  ///
  /// In en, this message translates to:
  /// **'Weather could not be reached'**
  String get todaySkyOffline;

  /// Today's sky line: weather unavailable.
  ///
  /// In en, this message translates to:
  /// **'Weather unavailable'**
  String get todaySkyUnavailable;

  /// Today's sky line: city mode with no city chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a city'**
  String get todaySkyNoCity;

  /// Today's sky line: temperature and weather condition.
  ///
  /// In en, this message translates to:
  /// **'{temperature} · {condition}'**
  String todaySkyWeather(String temperature, String condition);

  /// Today's sky line when Weather is chosen but the decorative scene shows; reason says why.
  ///
  /// In en, this message translates to:
  /// **'Scenic view · {reason}'**
  String todaySkyScenic(String reason);

  /// Screen-reader hint on Today's sky line.
  ///
  /// In en, this message translates to:
  /// **'Opens the Today background setting'**
  String get todaySkyHint;

  /// Expanded Can't sync explanation on Today with nothing waiting.
  ///
  /// In en, this message translates to:
  /// **'The last attempt to reach your account did not get through. That can be this phone\'s connection or the server. You are seeing what is saved on this phone. Nothing is waiting to sync.'**
  String get todayCantSyncDetailNothingWaiting;

  /// Expanded Can't sync explanation on Today with changes waiting.
  ///
  /// In en, this message translates to:
  /// **'The last attempt to reach your account did not get through. That can be this phone\'s connection or the server. You are seeing what is saved on this phone. Your changes are kept here and sync by themselves once the account answers.'**
  String get todayCantSyncDetailWaiting;

  /// Today error when local training records cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Your training could not be read from this phone. Pull down to try again.'**
  String get todayTrainingError;

  /// Today loading state for training.
  ///
  /// In en, this message translates to:
  /// **'Loading your training…'**
  String get todayTrainingLoading;

  /// Status badge: a workout is open.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get todayStatusInProgress;

  /// Status badge: today's planned workout (séance, feminine) is completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get todayStatusCompleted;

  /// Status badge: today's planned workout was partly completed.
  ///
  /// In en, this message translates to:
  /// **'Partly completed'**
  String get todayStatusPartly;

  /// Status badge: today's planned workout was skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped today'**
  String get todayStatusSkipped;

  /// Status badge: a planned workout was missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get todayStatusMissed;

  /// Status badge: the plan is paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get todayStatusPaused;

  /// Status badge: the planned workout is due today.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get todayStatusDue;

  /// Status badge: the open workout was saved for later.
  ///
  /// In en, this message translates to:
  /// **'Saved for later'**
  String get todayStatusSavedForLater;

  /// Status badge on a planned rest day.
  ///
  /// In en, this message translates to:
  /// **'Planned rest day'**
  String get todayStatusRestDay;

  /// Status badge while the plan is paused.
  ///
  /// In en, this message translates to:
  /// **'Plan paused'**
  String get todayStatusPlanPaused;

  /// Status badge: the plan starts on a later date. date is a short formatted date.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String todayStatusStarts(String date);

  /// Status badge: the plan block has ended and can be reviewed.
  ///
  /// In en, this message translates to:
  /// **'Block ready to review'**
  String get todayStatusBlockReview;

  /// Status badge: a drafted plan awaits review.
  ///
  /// In en, this message translates to:
  /// **'Your plan is ready to review'**
  String get todayStatusDraftReview;

  /// Today: no next workout in the plan block.
  ///
  /// In en, this message translates to:
  /// **'No further workout is scheduled in this block.'**
  String get todayNextNone;

  /// Today: the next workout of a rotating plan. title is the workout name.
  ///
  /// In en, this message translates to:
  /// **'Next in your rotation: {title}.'**
  String todayNextRotation(String title);

  /// Today: the next workout of a rotating plan and its day (weekday or date).
  ///
  /// In en, this message translates to:
  /// **'Next in your rotation: {title} · {day}.'**
  String todayNextRotationDay(String title, String day);

  /// Today: the next planned workout and its day (weekday or date).
  ///
  /// In en, this message translates to:
  /// **'Next: {title} · {day}.'**
  String todayNext(String title, String day);

  /// Quiet link opening the workout details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get todayDetailsLink;

  /// Screen-reader label of the Details link.
  ///
  /// In en, this message translates to:
  /// **'Workout details'**
  String get todayDetailsSaid;

  /// Screen-reader heading of Today's workout panel.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get todayWorkoutLabel;

  /// Number of exercises in a workout.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise} other{{count} exercises}}'**
  String todayExerciseCount(int count);

  /// Number of planned sets in a workout (English keeps 'sets' for every count).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} planned sets}}'**
  String todayPlannedSets(int count);

  /// Where today's workout sits in a rotation cycle.
  ///
  /// In en, this message translates to:
  /// **'Step {position} of {total}'**
  String todayRotationStep(int position, int total);

  /// Sequence number of a planned session.
  ///
  /// In en, this message translates to:
  /// **'Session {number}'**
  String todaySessionNumber(int number);

  /// Plan week of a planned workout.
  ///
  /// In en, this message translates to:
  /// **'Week {number}'**
  String todayWeekNumber(int number);

  /// Planned session length in minutes (abbreviated).
  ///
  /// In en, this message translates to:
  /// **'{minutes} min planned'**
  String todayMinutesPlanned(int minutes);

  /// Screen-reader label of the sets progress ring.
  ///
  /// In en, this message translates to:
  /// **'{counted} of {planned} planned sets recorded'**
  String todaySetsRingLabel(int counted, int planned);

  /// Under the recorded count inside the progress ring: out of how many planned sets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{of {count} sets}}'**
  String todayOfSets(int count);

  /// Under the percentage beside the progress ring.
  ///
  /// In en, this message translates to:
  /// **'recorded'**
  String get todayRecordedCaption;

  /// Count of sets recorded in an open workout.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set recorded} other{{count} sets recorded}}'**
  String todaySetsRecorded(int count);

  /// Open workout without exercises.
  ///
  /// In en, this message translates to:
  /// **'No exercise added yet'**
  String get todayNoExercise;

  /// Button resuming an open workout.
  ///
  /// In en, this message translates to:
  /// **'Resume workout'**
  String get todayResumeWorkout;

  /// Button starting today's planned workout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get todayStartWorkout;

  /// Today's planned workout was skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped: nothing was recorded for it and it does not count as training.'**
  String get todayResolvedSkipped;

  /// Today's planned workout was completed.
  ///
  /// In en, this message translates to:
  /// **'Finished: all planned sets recorded.'**
  String get todayResolvedFinished;

  /// Today's planned workout was partly completed.
  ///
  /// In en, this message translates to:
  /// **'Finished partially: some planned work was not recorded.'**
  String get todayResolvedPartial;

  /// After a resolved workout that ended the plan block.
  ///
  /// In en, this message translates to:
  /// **'That was the last workout of this block.'**
  String get todayBlockLast;

  /// Confirmation after undoing a skip.
  ///
  /// In en, this message translates to:
  /// **'No longer skipped.'**
  String get todayUnskipSaved;

  /// Button undoing a skipped workout.
  ///
  /// In en, this message translates to:
  /// **'Undo skip'**
  String get todayUndoSkip;

  /// Button opening the block review.
  ///
  /// In en, this message translates to:
  /// **'Review this block'**
  String get todayReviewBlock;

  /// Button starting the rotation's next workout now.
  ///
  /// In en, this message translates to:
  /// **'Train this now'**
  String get todayTrainNow;

  /// Button opening Train › Plan.
  ///
  /// In en, this message translates to:
  /// **'View plan'**
  String get todayViewPlan;

  /// Subtitle of another workout planned today, with its state.
  ///
  /// In en, this message translates to:
  /// **'Also today · {status}'**
  String todayAlsoToday(String status);

  /// Link to earlier missed workouts that still need a decision.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 earlier workout is unresolved} other{{count} earlier workouts are unresolved}}'**
  String todayMissedUnresolved(int count);

  /// Title of Today's panel on a rest day.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get todayRestDayTitle;

  /// Rest day chosen by the user in a rotating plan.
  ///
  /// In en, this message translates to:
  /// **'You chose to rest today. Nothing was skipped and your rotation waits for you.'**
  String get todayRestChosen;

  /// Rest day text when earlier workouts are missed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 earlier workout is unresolved; move or skip it when you choose.} other{{count} earlier workouts are unresolved; move or skip them when you choose.}}'**
  String todayRestMissed(int count);

  /// Button opening the plan to resolve missed workouts.
  ///
  /// In en, this message translates to:
  /// **'Resolve missed training'**
  String get todayResolveMissed;

  /// Button undoing a chosen rest day.
  ///
  /// In en, this message translates to:
  /// **'Train today'**
  String get todayTrainToday;

  /// Today while the plan is paused.
  ///
  /// In en, this message translates to:
  /// **'No workouts are expected while the plan is paused, and nothing counts as missed.'**
  String get todayPausedText;

  /// Button resuming a paused plan.
  ///
  /// In en, this message translates to:
  /// **'Resume plan'**
  String get todayResumePlan;

  /// Today before the plan's start date. date is a long formatted date.
  ///
  /// In en, this message translates to:
  /// **'Your plan begins on {date}. Nothing is due before then.'**
  String todayStartsLaterText(String date);

  /// Today when the plan block is ready to review.
  ///
  /// In en, this message translates to:
  /// **'This block has reached its end or has nothing left to do. Review what was actually recorded and choose what comes next.'**
  String get todayBlockReviewText;

  /// Today when a plan draft awaits review.
  ///
  /// In en, this message translates to:
  /// **'This draft has not started. Nothing is scheduled until you start it.'**
  String get todayDraftText;

  /// Button opening the plan draft review.
  ///
  /// In en, this message translates to:
  /// **'Review your plan'**
  String get todayReviewPlan;

  /// Today panel title without a plan.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get todayNoPlanTitle;

  /// Today without a plan.
  ///
  /// In en, this message translates to:
  /// **'Start from a familiar split or build your own and review it before you commit, or just train manually today.'**
  String get todayNoPlanText;

  /// Button opening plan creation.
  ///
  /// In en, this message translates to:
  /// **'Create my plan'**
  String get todayCreatePlan;

  /// Button starting a workout outside the plan.
  ///
  /// In en, this message translates to:
  /// **'Start a manual workout'**
  String get todayStartManual;

  /// Row of a workout saved for later. date is a short formatted date.
  ///
  /// In en, this message translates to:
  /// **'Saved for later · started {date}'**
  String todayParkedSubtitle(String date);

  /// A workout started outside the plan.
  ///
  /// In en, this message translates to:
  /// **'Manual workout'**
  String get todayManualWorkout;

  /// A workout from the plan (recorded today list).
  ///
  /// In en, this message translates to:
  /// **'Planned workout'**
  String get todayPlannedWorkout;

  /// Overline of an open planned workout from another day. date is a short formatted date.
  ///
  /// In en, this message translates to:
  /// **'Planned workout from {date}'**
  String todayPlannedWorkoutFrom(String date);

  /// Run/walk time under one minute.
  ///
  /// In en, this message translates to:
  /// **'Under 1 min'**
  String get todayUnderOneMinute;

  /// Run/Walk tile state. kind is walk or run.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Walk paused} other{Run paused}}'**
  String todayActivityPaused(String kind);

  /// Run/Walk tile state after the recording was interrupted. kind is walk or run.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Walk interrupted} other{Run interrupted}}'**
  String todayActivityInterrupted(String kind);

  /// Run/Walk tile state while the finished activity awaits review. kind is walk or run.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Walk not saved yet} other{Run not saved yet}}'**
  String todayActivityNotSaved(String kind);

  /// Run/Walk tile state while recording. kind is walk or run.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Walk in progress} other{Run in progress}}'**
  String todayActivityInProgress(String kind);

  /// Run/Walk tile state after finishing today. kind is walk or run.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{Walk completed} other{Run completed}}'**
  String todayActivityCompleted(String kind);

  /// Open run/walk begun on another day. date is a short formatted date.
  ///
  /// In en, this message translates to:
  /// **'Started {date}'**
  String todayStartedOn(String date);

  /// Open run/walk begun today.
  ///
  /// In en, this message translates to:
  /// **'Started today'**
  String get todayStartedToday;

  /// Second line under 'Run completed': when (lower case).
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get todayCompletedWhen;

  /// Run/Walk tile button resuming the open activity.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get todayRunResume;

  /// Run/Walk tile button after one was finished today.
  ///
  /// In en, this message translates to:
  /// **'Start new'**
  String get todayRunStartNew;

  /// Run/Walk tile button with nothing recorded today.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get todayRunStart;

  /// Run/Walk tile with nothing recorded today.
  ///
  /// In en, this message translates to:
  /// **'No run or walk today'**
  String get todayNoRunWalk;

  /// Overline of the Run/Walk tile.
  ///
  /// In en, this message translates to:
  /// **'Run / Walk'**
  String get todayRunWalkLabel;

  /// Overline of the Steps tile.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get todayStepsLabel;

  /// Steps tile headline before steps are on.
  ///
  /// In en, this message translates to:
  /// **'Track your steps'**
  String get todayStepsTrack;

  /// Steps tile line before steps are on.
  ///
  /// In en, this message translates to:
  /// **'Count with your phone.'**
  String get todayStepsCountWithPhone;

  /// Steps tile button turning steps on.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get todayStepsEnable;

  /// Steps tile while reading.
  ///
  /// In en, this message translates to:
  /// **'Reading steps'**
  String get todayStepsReading;

  /// When the step count was read. time is the phone's clock format. Keep on one line.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String todayStepsUpdated(String time);

  /// Steps tile link when no goal is set.
  ///
  /// In en, this message translates to:
  /// **'Set a goal'**
  String get todayStepsSetGoal;

  /// Steps tile link when a goal is set.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get todayStepsEditGoal;

  /// Screen-reader label of Set a goal.
  ///
  /// In en, this message translates to:
  /// **'Set a steps goal'**
  String get todayStepsSetGoalSaid;

  /// Screen-reader label of Edit goal.
  ///
  /// In en, this message translates to:
  /// **'Edit steps goal'**
  String get todayStepsEditGoalSaid;

  /// Steps tile when the source has no count for today (not zero).
  ///
  /// In en, this message translates to:
  /// **'No steps recorded today'**
  String get todayStepsNone;

  /// Steps tile when access was refused for good.
  ///
  /// In en, this message translates to:
  /// **'Access is off. Allow it in Settings.'**
  String get todayStepsBlocked;

  /// Steps tile when access is not yet allowed.
  ///
  /// In en, this message translates to:
  /// **'Allow access to see today\'s steps.'**
  String get todayStepsAllowHint;

  /// Steps tile button opening the phone's settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get todayStepsSettings;

  /// Steps tile button asking for access.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get todayStepsAllow;

  /// Steps tile when reading failed.
  ///
  /// In en, this message translates to:
  /// **'Could not read steps just now.'**
  String get todayStepsFailed;

  /// Screen-reader label of the Steps tile before steps are on.
  ///
  /// In en, this message translates to:
  /// **'Steps. Track your steps: count with your phone.'**
  String get todayStepsOffSaid;

  /// Screen-reader label of the Steps tile. value is the count or 'not known'; details are the tile's lines.
  ///
  /// In en, this message translates to:
  /// **'Steps today: {value}. {details}'**
  String todayStepsSaid(String value, String details);

  /// Screen-reader value when there is no step count.
  ///
  /// In en, this message translates to:
  /// **'not known'**
  String get todayStepsNotKnown;

  /// Screen-reader label of the Steps tile plus what a tap does.
  ///
  /// In en, this message translates to:
  /// **'{said} Opens Steps.'**
  String todayStepsOpens(String said);

  /// Under the step count: out of the goal. goal is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'of {goal}'**
  String todayStepsOfGoal(String goal);

  /// Screen-reader label of the steps goal bar.
  ///
  /// In en, this message translates to:
  /// **'Steps goal'**
  String get todayStepsGoalLabel;

  /// Steps tile in a test build with a simulated source.
  ///
  /// In en, this message translates to:
  /// **'Simulated (test build)'**
  String get todayStepsSimulated;

  /// Overline of Today's nutrition panel. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get todayNutritionLabel;

  /// Today nutrition panel error.
  ///
  /// In en, this message translates to:
  /// **'Today\'s food could not be read from this phone.'**
  String get todayFoodError;

  /// Today nutrition panel loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get todayLoading;

  /// Today nutrition panel with nothing logged (not zero eaten).
  ///
  /// In en, this message translates to:
  /// **'No food logged today'**
  String get todayNoFood;

  /// Today nutrition panel: the calorie/protein goals. goals is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'Your daily goal: {goals}'**
  String todayDailyGoal(String goals);

  /// Button opening the food form.
  ///
  /// In en, this message translates to:
  /// **'Log food'**
  String get todayLogFood;

  /// Quiet link opening Eat's food journal. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get todayJournal;

  /// Screen-reader label of the Journal link.
  ///
  /// In en, this message translates to:
  /// **'Food journal'**
  String get todayJournalSaid;

  /// Overline of what was recorded today.
  ///
  /// In en, this message translates to:
  /// **'Recorded today'**
  String get todayRecordedTodayOverline;

  /// Number of sets performed in a recorded workout.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String todaySetCount(int count);

  /// Current weather condition from its WMO code (c + code). English matches the provider's wording.
  ///
  /// In en, this message translates to:
  /// **'{code, select, c0{Clear sky} c1{Mainly clear} c2{Partly cloudy} c3{Overcast} c45{Fog} c48{Depositing rime fog} c51{Light drizzle} c53{Moderate drizzle} c55{Dense drizzle} c56{Light freezing drizzle} c57{Dense freezing drizzle} c61{Slight rain} c63{Moderate rain} c65{Heavy rain} c66{Light freezing rain} c67{Heavy freezing rain} c71{Slight snowfall} c73{Moderate snowfall} c75{Heavy snowfall} c77{Snow grains} c80{Slight rain showers} c81{Moderate rain showers} c82{Violent rain showers} c85{Slight snow showers} c86{Heavy snow showers} c95{Thunderstorm} c96{Thunderstorm with slight hail} c97{Heavy thunderstorm} c99{Thunderstorm with heavy hail} other{Weather}}'**
  String weatherCondition(String code);

  /// Weather condition family when no finer description is known.
  ///
  /// In en, this message translates to:
  /// **'{family, select, clear{Clear} partly{Partly cloudy} cloudy{Overcast} fog{Fog} rain{Rain} snow{Snow} storm{Thunderstorm} other{Weather}}'**
  String weatherFamily(String family);

  /// Temperature in degrees Celsius (whole number, may be negative).
  ///
  /// In en, this message translates to:
  /// **'{degrees}°C'**
  String weatherTemperatureC(int degrees);

  /// Temperature in degrees Fahrenheit (whole number, may be negative).
  ///
  /// In en, this message translates to:
  /// **'{degrees}°F'**
  String weatherTemperatureF(int degrees);

  /// Why the decorative scene shows: no weather answer yet.
  ///
  /// In en, this message translates to:
  /// **'No weather yet'**
  String get weatherFallbackNoAnswer;

  /// Why the decorative scene shows: the cached weather is for another place.
  ///
  /// In en, this message translates to:
  /// **'Weather is for another place'**
  String get weatherFallbackOtherPlace;

  /// Why the decorative scene shows: the weather is too old.
  ///
  /// In en, this message translates to:
  /// **'Weather is out of date'**
  String get weatherFallbackStale;

  /// Why the decorative scene shows: the weather's time is ahead of the phone's clock.
  ///
  /// In en, this message translates to:
  /// **'Weather time is ahead'**
  String get weatherFallbackAhead;

  /// Why the decorative scene shows: unknown weather.
  ///
  /// In en, this message translates to:
  /// **'Unrecognised weather'**
  String get weatherFallbackUnknownCode;

  /// Why the decorative scene shows: no artwork for this weather.
  ///
  /// In en, this message translates to:
  /// **'No scene for this weather'**
  String get weatherFallbackNoArt;

  /// Today background choice: decorative dusk scene.
  ///
  /// In en, this message translates to:
  /// **'Scenic'**
  String get weatherBackgroundScenic;

  /// Today background choice: current weather scene.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weatherBackgroundWeather;

  /// Today background choice: plain page colour.
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get weatherBackgroundPlain;

  /// Appearance row value: weather for the phone's approximate location.
  ///
  /// In en, this message translates to:
  /// **'Weather · Automatic'**
  String get weatherSummaryAutomatic;

  /// Appearance row value: weather for a chosen city (provider place name).
  ///
  /// In en, this message translates to:
  /// **'Weather · {city}'**
  String weatherSummaryCity(String city);

  /// Page title of the Today background setting.
  ///
  /// In en, this message translates to:
  /// **'Today background'**
  String get weatherBackgroundTitle;

  /// Subtitle of the Today background setting.
  ///
  /// In en, this message translates to:
  /// **'Only the top of Today uses it. Changes apply immediately.'**
  String get weatherBackgroundSubtitle;

  /// Subtitle of the Scenic choice.
  ///
  /// In en, this message translates to:
  /// **'A decorative dusk scene. Works without a connection.'**
  String get weatherBackgroundScenicDetail;

  /// Subtitle of the Weather choice.
  ///
  /// In en, this message translates to:
  /// **'A scene for the current weather where you choose. Dusk when none is available.'**
  String get weatherBackgroundWeatherDetail;

  /// Subtitle of the Plain choice.
  ///
  /// In en, this message translates to:
  /// **'The plain page colour.'**
  String get weatherBackgroundPlainDetail;

  /// Section label and basis row label: where the weather is for.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get weatherLocationSection;

  /// Weather location choice: the phone's approximate location.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get weatherAutomatic;

  /// Subtitle of the Automatic location choice.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s approximate location, about 10 km'**
  String get weatherAutomaticDetail;

  /// Weather location choice: a chosen city.
  ///
  /// In en, this message translates to:
  /// **'Selected city'**
  String get weatherSelectedCity;

  /// Subtitle of Selected city before one is chosen.
  ///
  /// In en, this message translates to:
  /// **'Search for a city'**
  String get weatherSearchForCity;

  /// Button opening the city search.
  ///
  /// In en, this message translates to:
  /// **'Change city'**
  String get weatherChangeCity;

  /// Section label above the current weather details.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get weatherNowSection;

  /// Dialog title before the system location prompt.
  ///
  /// In en, this message translates to:
  /// **'Use your approximate location?'**
  String get weatherConsentTitle;

  /// Dialog body before the system location prompt.
  ///
  /// In en, this message translates to:
  /// **'GoHard uses this phone\'s location only to choose a weather scene for the top of Today. It is rounded to about 10 km before it leaves the phone and is not kept as a history. You can choose a city instead.'**
  String get weatherConsentBody;

  /// Declines the location dialog.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get weatherNotNow;

  /// City search sheet title.
  ///
  /// In en, this message translates to:
  /// **'Choose a city'**
  String get weatherChooseCity;

  /// Weather setting: location permission not asked yet.
  ///
  /// In en, this message translates to:
  /// **'Automatic needs permission to use this phone\'s approximate location.'**
  String get weatherIssueNeedsPermission;

  /// Button asking for location.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get weatherUseMyLocation;

  /// Weather setting: location refused.
  ///
  /// In en, this message translates to:
  /// **'Location was not allowed. Choose a city, or try again.'**
  String get weatherIssueDenied;

  /// Weather setting: location refused for good.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off for GoHard. Allow it in Settings, or choose a city.'**
  String get weatherIssueDeniedForever;

  /// Button opening the app's settings on the phone.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get weatherOpenSettings;

  /// Weather setting: location services off.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off on this phone. Turn it on, or choose a city.'**
  String get weatherIssueServicesOff;

  /// Button opening the phone's location settings.
  ///
  /// In en, this message translates to:
  /// **'Location settings'**
  String get weatherLocationSettings;

  /// Weather setting: location timed out.
  ///
  /// In en, this message translates to:
  /// **'This phone did not find its location in time. Dusk shows until it does.'**
  String get weatherIssueTimeout;

  /// Weather setting: no city chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a city to see its weather.'**
  String get weatherIssueNoCity;

  /// Weather setting: weather service unreachable.
  ///
  /// In en, this message translates to:
  /// **'Weather could not be reached just now. Dusk shows until it can.'**
  String get weatherIssueUnreachable;

  /// Where the shown weather is for, in Automatic mode.
  ///
  /// In en, this message translates to:
  /// **'Your approximate location'**
  String get weatherApproximateLocation;

  /// When the shown weather is valid. time is the phone's clock format.
  ///
  /// In en, this message translates to:
  /// **'As of {time}'**
  String weatherAsOf(String time);

  /// When and where the shown weather is valid. place is a provider place name or 'Your approximate location'.
  ///
  /// In en, this message translates to:
  /// **'As of {time} · {place}'**
  String weatherAsOfPlace(String time, String place);

  /// While the weather is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Checking the weather…'**
  String get weatherChecking;

  /// When there is no usable weather.
  ///
  /// In en, this message translates to:
  /// **'No current weather. Showing the decorative dusk scene.'**
  String get weatherNone;

  /// Required attribution for MET Norway weather data. Keep names, licence and URL unchanged.
  ///
  /// In en, this message translates to:
  /// **'Data from MET Norway (api.met.no), CC BY 4.0: creativecommons.org/licenses/by/4.0. Its weather symbols are converted to WMO codes here.'**
  String get weatherCreditMet;

  /// Required attribution for Open-Meteo weather data. Keep names, licence and URL unchanged.
  ///
  /// In en, this message translates to:
  /// **'Weather data by Open-Meteo.com, CC BY 4.0: creativecommons.org/licenses/by/4.0.'**
  String get weatherCreditOpenMeteo;

  /// Attribution before any weather answer. Keep names and licence unchanged.
  ///
  /// In en, this message translates to:
  /// **'Weather data by Open-Meteo.com, or MET Norway when it is busy (CC BY 4.0).'**
  String get weatherCreditDefault;

  /// After the attribution: the conditions come from a weather model.
  ///
  /// In en, this message translates to:
  /// **'Conditions are model data.'**
  String get weatherModelData;

  /// Disclaimer under the weather details.
  ///
  /// In en, this message translates to:
  /// **'Scenes are illustrative: not a forecast or a view of your location.'**
  String get weatherIllustrative;

  /// Heading of the diagnostic rows explaining the current scene.
  ///
  /// In en, this message translates to:
  /// **'What the scene is based on'**
  String get weatherBasisTitle;

  /// Basis row: city mode with no city.
  ///
  /// In en, this message translates to:
  /// **'No city chosen'**
  String get weatherNoCityChosen;

  /// Basis row value for Automatic location.
  ///
  /// In en, this message translates to:
  /// **'Automatic (this phone, about 10 km)'**
  String get weatherAutomaticBasis;

  /// Basis row label: the last failure's technical code.
  ///
  /// In en, this message translates to:
  /// **'Last attempt'**
  String get weatherBasisLastAttempt;

  /// Basis row label: the scene shown.
  ///
  /// In en, this message translates to:
  /// **'Scene'**
  String get weatherBasisScene;

  /// Basis row value: the technical scene id of a weather scene.
  ///
  /// In en, this message translates to:
  /// **'{key} (weather)'**
  String weatherBasisSceneWeather(String key);

  /// Basis row value: decorative scene and why (lower case start in English).
  ///
  /// In en, this message translates to:
  /// **'scenic view · {reason}'**
  String weatherBasisSceneScenic(String reason);

  /// Basis row label: the provider's description and WMO code.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get weatherBasisCondition;

  /// Basis row label: which provider answered. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get weatherBasisSource;

  /// Basis row label: day or night at the weather's place.
  ///
  /// In en, this message translates to:
  /// **'Day or night there'**
  String get weatherBasisDayNight;

  /// Basis row value: daytime.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get weatherDay;

  /// Basis row value: night.
  ///
  /// In en, this message translates to:
  /// **'night'**
  String get weatherNight;

  /// Basis row value: the provider did not say.
  ///
  /// In en, this message translates to:
  /// **'not given'**
  String get weatherNotGiven;

  /// Basis row label: the weather's valid time.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get weatherBasisValid;

  /// Basis row value: a time and how long ago it was.
  ///
  /// In en, this message translates to:
  /// **'{time} ({ago})'**
  String weatherValidAt(String time, String ago);

  /// Basis row label: the place's time zone id.
  ///
  /// In en, this message translates to:
  /// **'Time zone there'**
  String get weatherBasisTimezone;

  /// Basis row label: when the phone fetched the weather.
  ///
  /// In en, this message translates to:
  /// **'Fetched'**
  String get weatherBasisFetched;

  /// Basis row label: which location setting the cached weather is for.
  ///
  /// In en, this message translates to:
  /// **'Kept for'**
  String get weatherBasisKeptFor;

  /// Basis row value: cached for the chosen city.
  ///
  /// In en, this message translates to:
  /// **'this city'**
  String get weatherKeptThisCity;

  /// Basis row value: cached for another location setting.
  ///
  /// In en, this message translates to:
  /// **'another location setting'**
  String get weatherKeptOther;

  /// Less than a minute ago.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get weatherJustNow;

  /// Minutes ago (abbreviated in English and French).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} min ago}}'**
  String weatherMinutesAgo(int count);

  /// Hours ago (abbreviated in English and French).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} h ago}}'**
  String weatherHoursAgo(int count);

  /// City search with a too-short query.
  ///
  /// In en, this message translates to:
  /// **'Type at least two letters.'**
  String get weatherTypeTwoLetters;

  /// City search in progress.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get weatherSearching;

  /// City search found nothing. query is what the user typed.
  ///
  /// In en, this message translates to:
  /// **'No places found for \"{query}\".'**
  String weatherNoPlaces(String query);

  /// City search failed.
  ///
  /// In en, this message translates to:
  /// **'Cities could not be searched just now.'**
  String get weatherCitySearchFailed;

  /// City search field label.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get weatherCityLabel;

  /// Tooltip of the city search button.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get weatherSearchTooltip;

  /// State of one planned workout (séance, feminine) in plan lists and badges. status is the state id.
  ///
  /// In en, this message translates to:
  /// **'{status, select, inProgress{In progress} finished{Completed} partial{Partial} skipped{Skipped} missed{Missed} due{Due} upcoming{Planned} other{Paused}}'**
  String todayOccasionStatus(String status);

  /// Today and Me: the last attempt to reach the account failed (never says offline).
  ///
  /// In en, this message translates to:
  /// **'Can\'t sync right now'**
  String get shellCantSyncLabel;

  /// Number of saved changes the account has not confirmed yet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync} other{{count} changes waiting to sync}}'**
  String shellWaitingToSync(int count);

  /// Today's sync line with the number of changes waiting (1 or more).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Can\'t sync right now · 1 change waiting to sync} other{Can\'t sync right now · {count} changes waiting to sync}}'**
  String shellCantSyncWaiting(int count);

  /// Planned number of sets in a prescription, e.g. "3 sets · 8–12 reps".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String workoutTargetSets(int count);

  /// Planned rep range in a prescription. range is digits like "8–12".
  ///
  /// In en, this message translates to:
  /// **'{range} reps'**
  String workoutTargetRepRange(String range);

  /// Planned single rep count in a prescription.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} reps}}'**
  String workoutTargetReps(int count);

  /// Shown when an exercise prescription has no sets, reps or time.
  ///
  /// In en, this message translates to:
  /// **'No target'**
  String get workoutNoTarget;

  /// Outcome of a workout session with every planned set recorded.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get workoutOutcomeFull;

  /// Outcome of a workout session finished with some planned work not recorded.
  ///
  /// In en, this message translates to:
  /// **'Finished partially'**
  String get workoutOutcomePartial;

  /// Outcome of a workout session saved with no recorded set.
  ///
  /// In en, this message translates to:
  /// **'No training logged'**
  String get workoutOutcomeNoData;

  /// Outcome of a manual workout session (no plan).
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get workoutOutcomeManual;

  /// Outcome of a workout session that is still open.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get workoutOutcomeOpen;

  /// A set recorded with no added load; also the hint of an empty load field.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get workoutSetBodyweight;

  /// A recorded set: load (with unit, or "Bodyweight") times reps.
  ///
  /// In en, this message translates to:
  /// **'{load} × {reps}'**
  String workoutSetLoadReps(String load, int reps);

  /// A recorded set with a load, reps and a time.
  ///
  /// In en, this message translates to:
  /// **'{load} × {reps} · {time}'**
  String workoutSetLoadRepsTime(String load, int reps, String time);

  /// Error under the set entry when the load is not a number.
  ///
  /// In en, this message translates to:
  /// **'Enter the load as a number of zero or more, or leave it blank for bodyweight.'**
  String get workoutInvalidLoadFormat;

  /// Error when a set load is negative or too large.
  ///
  /// In en, this message translates to:
  /// **'Enter a load of zero or more.'**
  String get workoutInvalidLoadRange;

  /// Error when a set has no reps and no time.
  ///
  /// In en, this message translates to:
  /// **'Enter the reps or time you actually did.'**
  String get workoutInvalidNothingDone;

  /// Error when reps or time are implausibly large.
  ///
  /// In en, this message translates to:
  /// **'That value is out of range.'**
  String get workoutInvalidOutOfRange;

  /// Error when removing an exercise that still has recorded sets.
  ///
  /// In en, this message translates to:
  /// **'Remove its recorded sets first.'**
  String get workoutInvalidHasSets;

  /// Back link from the workout panel to the Workouts overview.
  ///
  /// In en, this message translates to:
  /// **'All workouts'**
  String get workoutAllWorkoutsLink;

  /// Snackbar when switching exercise could not be saved.
  ///
  /// In en, this message translates to:
  /// **'The change of movement could not be saved on this phone. Your sets and entry are unchanged; try again.'**
  String get workoutSelectSaveFailed;

  /// Dialog title before Use last values overwrites typed values.
  ///
  /// In en, this message translates to:
  /// **'Replace what you typed?'**
  String get workoutUseLastConfirmTitle;

  /// Dialog body before Use last values overwrites typed values.
  ///
  /// In en, this message translates to:
  /// **'The entry for this set will show last time\'s values instead. Nothing is recorded until you tap Record set.'**
  String get workoutUseLastConfirmBody;

  /// Button copying the matching set from last session into the entry fields (records nothing).
  ///
  /// In en, this message translates to:
  /// **'Use last values'**
  String get workoutUseLastValues;

  /// Screen-reader label of Use last values with the set it copies.
  ///
  /// In en, this message translates to:
  /// **'Use last values: {set}'**
  String workoutUseLastValuesSemantic(String set);

  /// Cancel button keeping the typed values.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get workoutUseLastKeepMine;

  /// Snackbar after a set is recorded.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone: {set}'**
  String workoutSetSavedSnack(String set);

  /// Snackbar action that removes the set just recorded.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get workoutUndo;

  /// Error when recording a set failed on the phone.
  ///
  /// In en, this message translates to:
  /// **'Not saved. Your entry is still here. Tap again to retry.'**
  String get workoutSetNotSaved;

  /// Dialog title for editing a recorded set.
  ///
  /// In en, this message translates to:
  /// **'Edit set'**
  String get workoutEditSetTitle;

  /// Field label for the weight lifted in a set.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get workoutLoadLabel;

  /// Field label for the time of a timed set.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get workoutSecondsLabel;

  /// Field label for repetitions of a set.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get workoutRepsLabel;

  /// Big entry field label for a timed set.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get workoutTimeLabel;

  /// Unit suffix: seconds.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get workoutSecondsUnit;

  /// Entry field label with its unit, e.g. "Load (kg)".
  ///
  /// In en, this message translates to:
  /// **'{label} ({unit})'**
  String workoutFieldWithUnit(String label, String unit);

  /// Edit set dialog: deletes the recorded set.
  ///
  /// In en, this message translates to:
  /// **'Delete set'**
  String get workoutDeleteSet;

  /// Snackbar after a set is deleted.
  ///
  /// In en, this message translates to:
  /// **'Set removed.'**
  String get workoutSetRemoved;

  /// Snackbar when editing a set failed.
  ///
  /// In en, this message translates to:
  /// **'That change could not be saved on this phone. The set is unchanged.'**
  String get workoutSetEditFailed;

  /// Finish dialog title when no set was recorded.
  ///
  /// In en, this message translates to:
  /// **'No training logged'**
  String get workoutFinishNoDataTitle;

  /// Finish dialog title.
  ///
  /// In en, this message translates to:
  /// **'Finish workout?'**
  String get workoutFinishTitle;

  /// Finish dialog body for a planned workout with no recorded set.
  ///
  /// In en, this message translates to:
  /// **'No set has been recorded. You can save this as a record without training: it gives no training credit and leaves the planned workout available. Time on the clock alone is not training.'**
  String get workoutFinishNoDataBodyPlanned;

  /// Finish dialog body for a manual workout with no recorded set.
  ///
  /// In en, this message translates to:
  /// **'No set has been recorded. You can save this as a record without training: it gives no training credit. Time on the clock alone is not training.'**
  String get workoutFinishNoDataBodyManual;

  /// Finish dialog: what was recorded.
  ///
  /// In en, this message translates to:
  /// **'{sets, plural, =1{1 set} other{{sets} sets}} across {exercises, plural, =1{1 movement} other{{exercises} movements}} recorded.'**
  String workoutFinishSummary(int sets, int exercises);

  /// Finish dialog: exercises with fewer sets than planned. names is a list of exercise names.
  ///
  /// In en, this message translates to:
  /// **'Not fully recorded: {names}. You can still finish; it will be saved as partial.'**
  String workoutFinishMissing(String names);

  /// Separator between items of a short list of names.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get workoutListSeparator;

  /// Finish dialog: cancel and keep the workout open.
  ///
  /// In en, this message translates to:
  /// **'Keep training'**
  String get workoutKeepTraining;

  /// Finish dialog action when no set was recorded.
  ///
  /// In en, this message translates to:
  /// **'Save without training'**
  String get workoutSaveWithoutTraining;

  /// Button that finishes the workout session.
  ///
  /// In en, this message translates to:
  /// **'Finish workout'**
  String get workoutFinishButton;

  /// Snackbar when finishing failed.
  ///
  /// In en, this message translates to:
  /// **'The workout could not be finished on this phone. Nothing changed. Try again.'**
  String get workoutFinishFailed;

  /// Adds an exercise to a workout (menu item, button, picker title).
  ///
  /// In en, this message translates to:
  /// **'Add a movement'**
  String get workoutAddMovement;

  /// Exercise picker title when swapping an exercise.
  ///
  /// In en, this message translates to:
  /// **'Replace {name}'**
  String workoutReplaceMovementTitle(String name);

  /// Confirm dialog title before deleting a workout.
  ///
  /// In en, this message translates to:
  /// **'Remove this workout?'**
  String get workoutRemoveTitle;

  /// Confirm body before deleting an open workout. title is user content.
  ///
  /// In en, this message translates to:
  /// **'This removes \"{title}\" and every set recorded in it. This is the only way a workout is ever removed; it is never cleaned up automatically.'**
  String workoutRemoveOpenBody(String title);

  /// Deletes a workout session (menu item, confirm action, tooltip).
  ///
  /// In en, this message translates to:
  /// **'Remove workout'**
  String get workoutRemoveAction;

  /// Empty state when an opened workout no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This workout is not on this phone'**
  String get workoutMissingTitle;

  /// Empty state body when an opened workout no longer exists.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed. Nothing else changed.'**
  String get workoutMissingBody;

  /// Screen-reader label of the coach help button in the workout.
  ///
  /// In en, this message translates to:
  /// **'Help with recording this workout'**
  String get workoutHelpSemantic;

  /// Coach help sheet title in the workout.
  ///
  /// In en, this message translates to:
  /// **'Recording sets'**
  String get workoutHelpTitle;

  /// Coach help text in the workout.
  ///
  /// In en, this message translates to:
  /// **'Record each set as you finish it; the rest timer then starts on its own. Last time is what you actually did before, and Use last values only fills the entry. Save for later keeps everything.'**
  String get workoutHelpBody;

  /// Tooltip of the workout menu button.
  ///
  /// In en, this message translates to:
  /// **'Workout options'**
  String get workoutOptionsTooltip;

  /// Menu item: swap the current exercise.
  ///
  /// In en, this message translates to:
  /// **'Replace this movement'**
  String get workoutReplaceThisMovement;

  /// Menu item: remove the current exercise.
  ///
  /// In en, this message translates to:
  /// **'Remove this movement'**
  String get workoutRemoveThisMovement;

  /// Parks the open workout; nothing is finished.
  ///
  /// In en, this message translates to:
  /// **'Save for later'**
  String get workoutSaveForLater;

  /// Screen-reader label of the workout clock.
  ///
  /// In en, this message translates to:
  /// **'Workout time {duration}'**
  String workoutTimeSemantic(String duration);

  /// Screen-reader label of the paused workout clock.
  ///
  /// In en, this message translates to:
  /// **'Workout time {duration}, paused'**
  String workoutTimePausedSemantic(String duration);

  /// Resumes the paused workout clock.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get workoutResume;

  /// Pauses the workout clock. The French word or symbol may match English.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get workoutPause;

  /// Status in a workout saved for later.
  ///
  /// In en, this message translates to:
  /// **'Saved for later. Everything recorded is kept; resume it to record more.'**
  String get workoutParkedStatus;

  /// Button resuming a parked or open workout.
  ///
  /// In en, this message translates to:
  /// **'Resume workout'**
  String get workoutResumeWorkout;

  /// Status while the workout is paused.
  ///
  /// In en, this message translates to:
  /// **'Workout paused. Time and rest are frozen until you resume.'**
  String get workoutPausedStatus;

  /// Status when the workout has a sync conflict.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone; this workout needs review before it can sync. See the review notice below the screen.'**
  String get workoutNeedsReviewStatus;

  /// Sets recorded in a workout without a plan.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set recorded} other{{count} sets recorded}}'**
  String workoutSetsRecorded(int count);

  /// Planned sets recorded so far.
  ///
  /// In en, this message translates to:
  /// **'{counted} of {planned} planned sets recorded'**
  String workoutPlannedSetsRecorded(int counted, int planned);

  /// Screen-reader label of the planned sets progress bar.
  ///
  /// In en, this message translates to:
  /// **'Planned sets recorded'**
  String get workoutPlannedSetsRail;

  /// Empty workout title.
  ///
  /// In en, this message translates to:
  /// **'No movements yet'**
  String get workoutNoMovementsTitle;

  /// Empty workout body.
  ///
  /// In en, this message translates to:
  /// **'Add a movement to start recording sets.'**
  String get workoutNoMovementsBody;

  /// Overline above the current exercise.
  ///
  /// In en, this message translates to:
  /// **'Movement {index} of {total}'**
  String workoutMovementPosition(int index, int total);

  /// Overline above an exercise added beyond the plan.
  ///
  /// In en, this message translates to:
  /// **'Movement {index} of {total} · extra'**
  String workoutMovementPositionExtra(int index, int total);

  /// Note under a swapped exercise.
  ///
  /// In en, this message translates to:
  /// **'Recorded as {name}, in place of the planned movement.'**
  String workoutSubstitutedNote(String name);

  /// Link opening the exercise explanation.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get workoutAbout;

  /// Screen-reader label of the About link.
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String workoutAboutSemantic(String name);

  /// Label of the target load frozen into this workout.
  ///
  /// In en, this message translates to:
  /// **'Target in this workout'**
  String get workoutTargetInWorkout;

  /// Rest timer finished.
  ///
  /// In en, this message translates to:
  /// **'Rest ended'**
  String get workoutRestEnded;

  /// Overline of the running rest timer.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get workoutRestOverline;

  /// Rest timer started by another exercise.
  ///
  /// In en, this message translates to:
  /// **'Rest · from the previous movement'**
  String get workoutRestFromPrevious;

  /// Screen-reader label of the rest timer.
  ///
  /// In en, this message translates to:
  /// **'Rest, {duration} left'**
  String workoutRestSemantic(String duration);

  /// Adds 30 seconds to the rest timer.
  ///
  /// In en, this message translates to:
  /// **'+30 s'**
  String get workoutRestAdd30;

  /// Closes the ended rest timer.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get workoutRestDismiss;

  /// Ends the rest timer now.
  ///
  /// In en, this message translates to:
  /// **'Skip rest'**
  String get workoutRestSkip;

  /// Overline above the entry fields for the next set.
  ///
  /// In en, this message translates to:
  /// **'Set {number} · not recorded yet'**
  String workoutNextSetOverline(int number);

  /// Status when the last exercise reached its planned set count.
  ///
  /// In en, this message translates to:
  /// **'Target set count recorded. This is the last movement: add another set, or finish the workout when you are ready.'**
  String get workoutTargetReachedLast;

  /// Status when an exercise reached its planned set count.
  ///
  /// In en, this message translates to:
  /// **'Target set count recorded. Add another set, or move on when you are ready.'**
  String get workoutTargetReached;

  /// Main button recording the typed set.
  ///
  /// In en, this message translates to:
  /// **'Record set'**
  String get workoutRecordSet;

  /// Main button once the planned set count is reached.
  ///
  /// In en, this message translates to:
  /// **'Record another set'**
  String get workoutRecordAnotherSet;

  /// Button moving to the next exercise.
  ///
  /// In en, this message translates to:
  /// **'Next exercise · {name}'**
  String workoutNextExercise(String name);

  /// Section overline of recorded sets.
  ///
  /// In en, this message translates to:
  /// **'Recorded sets'**
  String get workoutRecordedSetsOverline;

  /// Empty recorded sets list.
  ///
  /// In en, this message translates to:
  /// **'None yet. Targets, last time and suggestions are not recorded sets.'**
  String get workoutNoRecordedSets;

  /// One recorded set in a list: its number and value.
  ///
  /// In en, this message translates to:
  /// **'{number}.  {set}'**
  String workoutSetRowTitle(int number, String set);

  /// Recorded set with a sync conflict.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get workoutSetNeedsReview;

  /// Recorded set not yet synced.
  ///
  /// In en, this message translates to:
  /// **'Recorded · saved on this phone, sync pending'**
  String get workoutSetPending;

  /// A set that is recorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get workoutSetRecorded;

  /// Section overline listing the workout exercises.
  ///
  /// In en, this message translates to:
  /// **'All movements'**
  String get workoutAllMovementsOverline;

  /// Sets recorded for one exercise with no planned count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} sets recorded}}'**
  String workoutMovementSetsRecorded(int count);

  /// Sets recorded for one exercise against its planned count.
  ///
  /// In en, this message translates to:
  /// **'{count} of {target} sets recorded'**
  String workoutMovementSetsOfTarget(int count, int target);

  /// Marks the selected exercise in the list.
  ///
  /// In en, this message translates to:
  /// **'{status} · current'**
  String workoutMovementCurrent(String status);

  /// Last time panel while loading.
  ///
  /// In en, this message translates to:
  /// **'Reading your previous sessions…'**
  String get workoutHistoryLoading;

  /// Last time panel when history cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Your previous sessions could not be read on this phone right now.'**
  String get workoutHistoryUnavailable;

  /// Last time panel for a free-text exercise.
  ///
  /// In en, this message translates to:
  /// **'No history: this movement is not linked to a saved exercise, so nothing is matched by name.'**
  String get workoutHistoryNoIdentity;

  /// Last time panel with no history.
  ///
  /// In en, this message translates to:
  /// **'No previous session recorded.'**
  String get workoutHistoryNone;

  /// Large-text comparison row: last session value.
  ///
  /// In en, this message translates to:
  /// **'Last time: {value}'**
  String workoutCompareLastLabeled(String value);

  /// Large-text comparison row: today value.
  ///
  /// In en, this message translates to:
  /// **'Today: {value}'**
  String workoutCompareTodayLabeled(String value);

  /// Screen-reader label of a set recorded today.
  ///
  /// In en, this message translates to:
  /// **'Recorded: {set}'**
  String workoutCompareRecordedSemantic(String set);

  /// Comparison table: the next set to record.
  ///
  /// In en, this message translates to:
  /// **'Next · not recorded yet'**
  String get workoutCompareNext;

  /// Comparison table: a planned set not yet recorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded yet'**
  String get workoutCompareNotYet;

  /// Large-text comparison block heading.
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String workoutCompareSetNumber(int number);

  /// Comparison table column: set number.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get workoutCompareSet;

  /// Comparison table column: sets recorded today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get workoutCompareToday;

  /// Panel title and column: the most recent earlier session of this exercise.
  ///
  /// In en, this message translates to:
  /// **'Last time'**
  String get workoutLastTime;

  /// Last time panel title with its date.
  ///
  /// In en, this message translates to:
  /// **'Last time · {date}'**
  String workoutLastTimeOn(String date);

  /// Link opening every earlier session of the exercise.
  ///
  /// In en, this message translates to:
  /// **'All sessions'**
  String get workoutAllSessions;

  /// Screen-reader label of All sessions.
  ///
  /// In en, this message translates to:
  /// **'All previous sessions'**
  String get workoutAllSessionsSemantic;

  /// Caption of the exercise history sheet.
  ///
  /// In en, this message translates to:
  /// **'Previous sessions, newest first: workouts that count as training, matched by this exercise and its place in the workout.'**
  String get workoutHistorySheetCaption;

  /// Preview of a planned workout that disappeared.
  ///
  /// In en, this message translates to:
  /// **'This workout is no longer planned'**
  String get workoutPreviewGoneTitle;

  /// Preview of a planned workout that disappeared.
  ///
  /// In en, this message translates to:
  /// **'The plan changed since it was opened. Nothing was started or recorded.'**
  String get workoutPreviewGoneBody;

  /// Position of a workout in a rotating plan.
  ///
  /// In en, this message translates to:
  /// **'Session {number}'**
  String workoutPreviewSession(int number);

  /// Week of a workout in a fixed plan.
  ///
  /// In en, this message translates to:
  /// **'Week {number}'**
  String workoutPreviewWeek(int number);

  /// Number of exercises in a planned workout.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise} other{{count} exercises}}'**
  String workoutPreviewExerciseCount(int count);

  /// Number of planned sets in a planned workout.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 planned set} other{{count} planned sets}}'**
  String workoutPreviewPlannedSets(int count);

  /// Date of a planned workout scheduled today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get workoutPreviewToday;

  /// Planned session length chosen by the user.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min planned'**
  String workoutPreviewMinutesPlanned(int minutes);

  /// Starts a workout session.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get workoutStart;

  /// Opens the recorded result of this planned workout.
  ///
  /// In en, this message translates to:
  /// **'View what was recorded'**
  String get workoutPreviewViewRecorded;

  /// Opens the move/skip/edit sheet of a planned workout.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get workoutPreviewMoreOptions;

  /// Screen-reader label of More options.
  ///
  /// In en, this message translates to:
  /// **'Move, skip or edit this workout'**
  String get workoutPreviewMoreOptionsSemantic;

  /// Section header listing a planned workout exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get workoutPreviewExercises;

  /// Planned workout with no exercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises are planned in this workout.'**
  String get workoutPreviewNoExercises;

  /// Expands the planned workout exercise list.
  ///
  /// In en, this message translates to:
  /// **'See all {count} exercises'**
  String workoutPreviewSeeAll(int count);

  /// Why a planned workout cannot start.
  ///
  /// In en, this message translates to:
  /// **'The plan is paused. Resume the plan to start its workouts.'**
  String get workoutPreviewPlanPaused;

  /// Why a planned workout cannot start.
  ///
  /// In en, this message translates to:
  /// **'Skipped. Nothing was recorded for it.'**
  String get workoutPreviewSkipped;

  /// Why a planned workout in a rotation cannot start yet.
  ///
  /// In en, this message translates to:
  /// **'A rotation runs in order: this one comes up after the workouts before it.'**
  String get workoutPreviewRotationOrder;

  /// Why a planned workout cannot start.
  ///
  /// In en, this message translates to:
  /// **'This workout cannot be started now. More options shows what can be done with it.'**
  String get workoutPreviewCannotStart;

  /// Footer of the planned workout preview.
  ///
  /// In en, this message translates to:
  /// **'Last time is what you actually recorded before. Nothing here is recorded until you start.'**
  String get workoutPreviewFooter;

  /// Target load of a planned exercise.
  ///
  /// In en, this message translates to:
  /// **'Target {load}'**
  String workoutPreviewTarget(String load);

  /// Opens the target review when no weight target exists.
  ///
  /// In en, this message translates to:
  /// **'Set a target'**
  String get workoutSetATarget;

  /// Opens the target review.
  ///
  /// In en, this message translates to:
  /// **'Review target'**
  String get workoutReviewTarget;

  /// Screen-reader label of the target link.
  ///
  /// In en, this message translates to:
  /// **'Target for {name}'**
  String workoutTargetForSemantic(String name);

  /// Explanation of a finished workout.
  ///
  /// In en, this message translates to:
  /// **'Every planned movement has its target number of sets recorded.'**
  String get workoutOutcomeFullExplain;

  /// Explanation of a partially finished workout.
  ///
  /// In en, this message translates to:
  /// **'Actual training was recorded. Some planned work was not; that is shown below.'**
  String get workoutOutcomePartialExplain;

  /// Explanation of a planned workout saved with no data.
  ///
  /// In en, this message translates to:
  /// **'No training was logged, so this gives no training credit and the planned workout is still available.'**
  String get workoutOutcomeNoDataExplainPlanned;

  /// Explanation of a manual workout saved with no data.
  ///
  /// In en, this message translates to:
  /// **'No training was logged, so this gives no training credit.'**
  String get workoutOutcomeNoDataExplainManual;

  /// Explanation of a manual workout result.
  ///
  /// In en, this message translates to:
  /// **'Recorded as manual training. It does not tick off a planned workout.'**
  String get workoutOutcomeManualExplain;

  /// Explanation of an open workout.
  ///
  /// In en, this message translates to:
  /// **'This workout is still open. It is never finished automatically.'**
  String get workoutOutcomeOpenExplain;

  /// Confirm body before deleting a recorded workout. title is user content.
  ///
  /// In en, this message translates to:
  /// **'This removes \"{title}\" from {date} and its {count, plural, =1{1 recorded set} other{{count} recorded sets}} from your history.'**
  String workoutRemoveRecordedBody(String title, String date, int count);

  /// Date of a manual workout.
  ///
  /// In en, this message translates to:
  /// **'{date} · manual'**
  String workoutDateManual(String date);

  /// Status of something saved locally, not yet synced.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone · sync pending'**
  String get workoutSyncPending;

  /// Status of a workout with a sync conflict.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone; needs your review before it can sync.'**
  String get workoutDetailNeedsReview;

  /// Result fact: active workout time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get workoutFactTime;

  /// Result fact: number of sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get workoutFactSets;

  /// Result fact: number of exercises with sets.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get workoutFactMovements;

  /// The planned prescription of an exercise in a result.
  ///
  /// In en, this message translates to:
  /// **'Planned · {target}'**
  String workoutPlannedTarget(String target);

  /// A planned exercise with no recorded set.
  ///
  /// In en, this message translates to:
  /// **'Not recorded.'**
  String get workoutExerciseNotRecorded;

  /// An added exercise with no recorded set.
  ///
  /// In en, this message translates to:
  /// **'No sets recorded.'**
  String get workoutExerciseNoSets;

  /// Result of a workout without exercises.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded'**
  String get workoutDetailEmptyTitle;

  /// Result of a workout without exercises.
  ///
  /// In en, this message translates to:
  /// **'This workout has no movements.'**
  String get workoutDetailEmptyBody;

  /// Page title / row listing all recorded workouts.
  ///
  /// In en, this message translates to:
  /// **'Workout history'**
  String get workoutHistoryTitle;

  /// Empty workout history.
  ///
  /// In en, this message translates to:
  /// **'No workouts yet'**
  String get workoutHistoryEmptyTitle;

  /// Empty workout history.
  ///
  /// In en, this message translates to:
  /// **'Workouts you record will appear here with what you actually did.'**
  String get workoutHistoryEmptyBody;

  /// Number of recorded sets in a workout row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String workoutSetCount(int count);

  /// Tag of a workout recorded without a plan.
  ///
  /// In en, this message translates to:
  /// **'manual'**
  String get workoutManualTag;

  /// Dialog title when another workout is in front. title is user content.
  ///
  /// In en, this message translates to:
  /// **'{title} is still open'**
  String workoutStillOpenTitle(String title);

  /// Dialog body when another workout is in front.
  ///
  /// In en, this message translates to:
  /// **'Only one workout is in front at a time. Resume it, or save it for later. Saving for later keeps every recorded set and never finishes it.'**
  String get workoutStillOpenBody;

  /// Dialog action parking the other workout.
  ///
  /// In en, this message translates to:
  /// **'Save it for later and continue'**
  String get workoutStillOpenPark;

  /// Dialog action resuming the other workout.
  ///
  /// In en, this message translates to:
  /// **'Resume it'**
  String get workoutStillOpenResume;

  /// Snackbar when starting failed.
  ///
  /// In en, this message translates to:
  /// **'The workout could not be started on this phone. Nothing was recorded. Try again.'**
  String get workoutStartFailed;

  /// Default exercise picker title.
  ///
  /// In en, this message translates to:
  /// **'Choose a movement'**
  String get workoutPickerTitle;

  /// Exercise search field label.
  ///
  /// In en, this message translates to:
  /// **'Search exercises'**
  String get workoutPickerSearch;

  /// Exercise picker when the catalog is missing.
  ///
  /// In en, this message translates to:
  /// **'The exercise list has not been downloaded to this phone yet. You can still create your own exercise.'**
  String get workoutPickerCatalogEmpty;

  /// Filter / field label: muscle group.
  ///
  /// In en, this message translates to:
  /// **'Muscle group'**
  String get workoutPickerMuscle;

  /// Filter / field label: equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get workoutPickerEquipment;

  /// Exercise search with no result.
  ///
  /// In en, this message translates to:
  /// **'No exercise matches that. Try another name or filter, or create your own.'**
  String get workoutPickerNoMatch;

  /// Tag of an exercise done for time.
  ///
  /// In en, this message translates to:
  /// **'timed'**
  String get workoutPickerTimedTag;

  /// Tag of a custom exercise.
  ///
  /// In en, this message translates to:
  /// **'Your exercise'**
  String get workoutPickerYourExercise;

  /// Row creating a custom exercise.
  ///
  /// In en, this message translates to:
  /// **'Create your own exercise'**
  String get workoutPickerCreate;

  /// Row creating a custom exercise from the search text (user content).
  ///
  /// In en, this message translates to:
  /// **'Create “{name}” as your own exercise'**
  String workoutPickerCreateNamed(String name);

  /// Subtitle of the create exercise row.
  ///
  /// In en, this message translates to:
  /// **'Private to your account. It keeps its own history.'**
  String get workoutPickerCreateSubtitle;

  /// Sheet title creating a custom exercise.
  ///
  /// In en, this message translates to:
  /// **'Your own exercise'**
  String get workoutCustomTitle;

  /// Generic local save failure.
  ///
  /// In en, this message translates to:
  /// **'It could not be saved on this phone. Try again.'**
  String get workoutSaveFailedRetry;

  /// Caption of the custom exercise form.
  ///
  /// In en, this message translates to:
  /// **'Only you can see your own exercises. Renaming one later never changes what you already recorded.'**
  String get workoutCustomCaption;

  /// Name field label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workoutCustomName;

  /// Switch: the exercise is done for time.
  ///
  /// In en, this message translates to:
  /// **'Timed'**
  String get workoutCustomTimed;

  /// Explains the Timed switch.
  ///
  /// In en, this message translates to:
  /// **'Held or done for a time, like a plank, instead of counted reps.'**
  String get workoutCustomTimedHelp;

  /// Saves the custom exercise.
  ///
  /// In en, this message translates to:
  /// **'Save exercise'**
  String get workoutCustomSave;

  /// Page title for a workout without a plan.
  ///
  /// In en, this message translates to:
  /// **'Manual workout'**
  String get workoutManualTitle;

  /// Caption of the manual workout setup.
  ///
  /// In en, this message translates to:
  /// **'Train without a plan. This is recorded as real training and never ticks off a planned workout.'**
  String get workoutManualCaption;

  /// Default name of a manual workout (hint, and stored when the name is left blank).
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workoutManualDefaultName;

  /// Manual setup section of chosen exercises.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get workoutManualMovements;

  /// Manual setup with no exercise chosen.
  ///
  /// In en, this message translates to:
  /// **'None yet. You can also add movements after starting.'**
  String get workoutManualNone;

  /// Tooltip removing a chosen exercise.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String workoutManualRemove(String name);

  /// Both sessions happened on the same date.
  ///
  /// In en, this message translates to:
  /// **'both on {date}'**
  String workoutProgressionDaysBoth(String date);

  /// The dates of the two sessions compared.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String workoutProgressionDaysPair(String first, String second);

  /// Why a next target can be suggested: both sessions reached the top of the rep range.
  ///
  /// In en, this message translates to:
  /// **'In your last two {workout} sessions ({days}) you recorded all {sets} sets of {exercise} at {target} with {top} or more reps, the top of your {range} range.'**
  String workoutProgressionQualified(
    String workout,
    String days,
    int sets,
    String exercise,
    String target,
    int top,
    String range,
  );

  /// Follows the qualified sentence when no increment is saved.
  ///
  /// In en, this message translates to:
  /// **'Choose the weight increment your equipment allows to see a next target.'**
  String get workoutProgressionConfigureIncrement;

  /// Follows the qualified sentence when the increment is over 5%.
  ///
  /// In en, this message translates to:
  /// **'Your increment of {increment} is more than 5% of that target, so GoHard does not suggest it automatically. You can still review the target yourself.'**
  String workoutProgressionIncrementTooLarge(String increment);

  /// Why the target stays.
  ///
  /// In en, this message translates to:
  /// **'A set in one of your last two {workout} sessions was below {top} reps at {target}.'**
  String workoutProgressionBelowTop(String workout, int top, String target);

  /// Why the target stays.
  ///
  /// In en, this message translates to:
  /// **'One of your last two {workout} sessions has fewer than {sets} sets of {exercise} recorded.'**
  String workoutProgressionSetsMissing(
    String workout,
    int sets,
    String exercise,
  );

  /// Why the target stays.
  ///
  /// In en, this message translates to:
  /// **'One of your last two {workout} sessions has more than {sets} sets of {exercise}, and warm-ups are not marked, so they cannot be compared.'**
  String workoutProgressionExtraSets(String workout, int sets, String exercise);

  /// Why the target stays.
  ///
  /// In en, this message translates to:
  /// **'A set in one of your last two {workout} sessions has no load recorded.'**
  String workoutProgressionLoadUnknown(String workout);

  /// Why the target stays.
  ///
  /// In en, this message translates to:
  /// **'One of your last two {workout} sessions used a load other than {target}.'**
  String workoutProgressionLoadDiffers(String workout, String target);

  /// Why the target stays.
  ///
  /// In en, this message translates to:
  /// **'One of your last two {workout} sessions was saved as partly completed.'**
  String workoutProgressionPartial(String workout);

  /// Why the target stays.
  ///
  /// In en, this message translates to:
  /// **'One of your last two {workout} sessions did not include {exercise} as planned.'**
  String workoutProgressionNotAsPlanned(String workout, String exercise);

  /// Follows the reason the target stays.
  ///
  /// In en, this message translates to:
  /// **'The target stays at {target}.'**
  String workoutProgressionStays(String target);

  /// More sessions needed after a target change.
  ///
  /// In en, this message translates to:
  /// **'Your target changed since your last {workout} session. Two sessions at {target} are needed before a step up is considered.'**
  String workoutProgressionTargetChanged(String workout, String target);

  /// More sessions needed.
  ///
  /// In en, this message translates to:
  /// **'Two {workout} sessions at {target} are needed before a step up is considered; {count} recorded so far.'**
  String workoutProgressionNeedTwo(String workout, String target, int count);

  /// No load target to compare.
  ///
  /// In en, this message translates to:
  /// **'This exercise has no weight target in {workout}. Set one if you want sessions compared against it.'**
  String workoutProgressionNoLoadTarget(String workout);

  /// No sets/reps to compare.
  ///
  /// In en, this message translates to:
  /// **'This exercise has no set count and rep range in {workout} to compare against.'**
  String workoutProgressionNoRange(String workout);

  /// Progression unsupported: timed.
  ///
  /// In en, this message translates to:
  /// **'This exercise is timed, so GoHard does not calculate a weight for it. You can set targets yourself.'**
  String get workoutProgressionTimed;

  /// Progression unsupported: bodyweight or assisted.
  ///
  /// In en, this message translates to:
  /// **'GoHard does not calculate weights for bodyweight or assisted exercises. You can set targets yourself.'**
  String get workoutProgressionBodyweight;

  /// Progression unsupported: no identity.
  ///
  /// In en, this message translates to:
  /// **'This exercise is not linked to a saved exercise, so its sessions are not compared.'**
  String get workoutProgressionNoIdentity;

  /// Section of optional next targets.
  ///
  /// In en, this message translates to:
  /// **'Next time'**
  String get workoutNextTimeHeader;

  /// Coach help entry about next targets.
  ///
  /// In en, this message translates to:
  /// **'About next targets'**
  String get workoutNextTimeHelpLabel;

  /// Coach bubble over the next target card.
  ///
  /// In en, this message translates to:
  /// **'You reached the top of your rep range in your last two comparable sessions of {exercise}. You can review an optional next target.'**
  String workoutNextTimeCoachIncrease(String exercise);

  /// Coach bubble when no increment is saved.
  ///
  /// In en, this message translates to:
  /// **'You reached the top of your rep range in your last two comparable sessions of {exercise}. Tell me your weight increment and I can size a next target.'**
  String workoutNextTimeCoachIncrement(String exercise);

  /// Title of the progression help sheet and its link.
  ///
  /// In en, this message translates to:
  /// **'How progression works'**
  String get workoutProgressionHowTitle;

  /// Row of another suggested next target. change is "current → proposed".
  ///
  /// In en, this message translates to:
  /// **'{change} · Review'**
  String workoutNextTimeRowReview(String change);

  /// Opens the weight increment sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose your weight increment'**
  String get workoutChooseIncrement;

  /// Label of the current target load.
  ///
  /// In en, this message translates to:
  /// **'Current target'**
  String get workoutCurrentTarget;

  /// Label of the suggested next target load.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get workoutProposed;

  /// Opens the next target review.
  ///
  /// In en, this message translates to:
  /// **'Review next target'**
  String get workoutReviewNextTarget;

  /// Declines the suggestion; the plan is unchanged.
  ///
  /// In en, this message translates to:
  /// **'Keep current target'**
  String get workoutKeepCurrentTarget;

  /// Snackbar after Keep current target.
  ///
  /// In en, this message translates to:
  /// **'Kept {load}. Nothing in your plan changed.'**
  String workoutKeptTarget(String load);

  /// Snackbar when a local save failed.
  ///
  /// In en, this message translates to:
  /// **'That could not be saved on this phone. Nothing changed; try again.'**
  String get workoutSaveFailedNothingChanged;

  /// Workspace line when the plan has no weight target.
  ///
  /// In en, this message translates to:
  /// **'No next weight target'**
  String get workoutNoNextTarget;

  /// Workspace line with the plan next target.
  ///
  /// In en, this message translates to:
  /// **'Next target · {load}'**
  String workoutNextTargetValue(String load);

  /// Link when a next target is suggested.
  ///
  /// In en, this message translates to:
  /// **'Review suggestion'**
  String get workoutReviewSuggestion;

  /// Link opening the next target review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get workoutReview;

  /// Screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Set a next target for {name}'**
  String workoutSetNextTargetSemantic(String name);

  /// Screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Review the next target for {name}'**
  String workoutReviewNextTargetSemantic(String name);

  /// Next target review sheet title.
  ///
  /// In en, this message translates to:
  /// **'Next target'**
  String get workoutNextTargetTitle;

  /// Target review load error.
  ///
  /// In en, this message translates to:
  /// **'Enter a weight above zero, or leave it empty for no weight target.'**
  String get workoutTargetLoadError;

  /// Target review sets/reps error.
  ///
  /// In en, this message translates to:
  /// **'Use 1 to 20 sets and a rep range from 1 to 100, the lower number first.'**
  String get workoutTargetRangeError;

  /// Target review save failure.
  ///
  /// In en, this message translates to:
  /// **'It could not be saved on this phone. Nothing changed; try again.'**
  String get workoutTargetSaveFailed;

  /// Snackbar after restoring the previous target.
  ///
  /// In en, this message translates to:
  /// **'Previous target restored.'**
  String get workoutTargetRestored;

  /// Target review for an exercise no longer in the plan.
  ///
  /// In en, this message translates to:
  /// **'This exercise is no longer in that plan workout, so there is no next target to review. Nothing was changed.'**
  String get workoutTargetGone;

  /// When an accepted next target applies.
  ///
  /// In en, this message translates to:
  /// **'Applies from the next time you start {workout}, until you change it. Today\'s workout and earlier ones keep what they recorded.'**
  String workoutTargetScope(String workout);

  /// Target review heading line.
  ///
  /// In en, this message translates to:
  /// **'Current target: {load} · {prescription}'**
  String workoutReviewCurrent(String load, String prescription);

  /// Used inside a sentence when there is no target load.
  ///
  /// In en, this message translates to:
  /// **'no weight target'**
  String get workoutNoWeightTarget;

  /// Status after saving a next target.
  ///
  /// In en, this message translates to:
  /// **'Next target saved. {scope}'**
  String workoutTargetSaved(String scope);

  /// Reopens the review form.
  ///
  /// In en, this message translates to:
  /// **'Edit next target'**
  String get workoutEditNextTarget;

  /// Restores the target an accepted one replaced.
  ///
  /// In en, this message translates to:
  /// **'Restore previous target ({target})'**
  String workoutRestorePrevious(String target);

  /// Confirm button without a load.
  ///
  /// In en, this message translates to:
  /// **'Save next target'**
  String get workoutSaveNextTarget;

  /// Confirm button with a load.
  ///
  /// In en, this message translates to:
  /// **'Use {load} from next session'**
  String workoutUseLoadFromNext(String load);

  /// Overline of the sessions behind a suggestion.
  ///
  /// In en, this message translates to:
  /// **'Your last sessions'**
  String get workoutYourLastSessions;

  /// One earlier session and its sets.
  ///
  /// In en, this message translates to:
  /// **'{date}: {sets}'**
  String workoutSessionLine(String date, String sets);

  /// A session with no recorded set of the exercise.
  ///
  /// In en, this message translates to:
  /// **'not recorded'**
  String get workoutNotRecordedLower;

  /// Explains the proposed target.
  ///
  /// In en, this message translates to:
  /// **'Suggested: {proposed}, one increment of {increment}. Only the weight is suggested; sets and reps change only if you edit them.'**
  String workoutSuggestedLine(String proposed, String increment);

  /// Target review load field.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get workoutWeightLabel;

  /// Fills the load field from history.
  ///
  /// In en, this message translates to:
  /// **'Use last recorded load ({load})'**
  String workoutUseLastRecordedLoad(String load);

  /// Target review sets field.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get workoutSetsLabel;

  /// Target review lower rep field.
  ///
  /// In en, this message translates to:
  /// **'Reps from'**
  String get workoutRepsFrom;

  /// Target review upper rep field (stacked layout).
  ///
  /// In en, this message translates to:
  /// **'Reps to'**
  String get workoutRepsTo;

  /// Target review upper rep field beside "Reps from".
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get workoutRepsToShort;

  /// Opens the increment sheet when one is saved.
  ///
  /// In en, this message translates to:
  /// **'Weight increment {increment} · Change'**
  String workoutIncrementChange(String increment);

  /// Disabled confirm button.
  ///
  /// In en, this message translates to:
  /// **'No change to save'**
  String get workoutNoChangeToSave;

  /// Increment sheet title.
  ///
  /// In en, this message translates to:
  /// **'Weight increment'**
  String get workoutIncrementTitle;

  /// Increment error.
  ///
  /// In en, this message translates to:
  /// **'Enter a step above zero and up to {max}.'**
  String workoutIncrementRangeError(String max);

  /// Increment sheet explanation.
  ///
  /// In en, this message translates to:
  /// **'The step GoHard adds when it suggests a heavier target for {exercise}, and only then. Pick the smallest increase your plates, dumbbells or machine allow. Gyms differ, so nothing is chosen for you.'**
  String workoutIncrementCaption(String exercise);

  /// Increment sheet convention note.
  ///
  /// In en, this message translates to:
  /// **'GoHard keeps a load exactly as you record it. Use the same convention as your sets: if you record dumbbells per hand, enter the step per hand; for a barbell, the total change on the bar.'**
  String get workoutIncrementConvention;

  /// The saved increment.
  ///
  /// In en, this message translates to:
  /// **'Saved: {increment}'**
  String workoutIncrementSaved(String increment);

  /// The saved increment, not yet synced.
  ///
  /// In en, this message translates to:
  /// **'Saved: {increment} · sync pending'**
  String workoutIncrementSavedPending(String increment);

  /// Custom increment field.
  ///
  /// In en, this message translates to:
  /// **'Another step'**
  String get workoutIncrementAnother;

  /// Increment when the server lacks the capability.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. Your account\'s server does not keep increments yet; it will sync once the server is updated.'**
  String get workoutIncrementLocalOnly;

  /// Disabled save button of the increment sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose a step'**
  String get workoutChooseStep;

  /// Save button of the increment sheet.
  ///
  /// In en, this message translates to:
  /// **'Save {increment}'**
  String workoutSaveStep(String increment);

  /// Clears the saved increment.
  ///
  /// In en, this message translates to:
  /// **'Remove this increment'**
  String get workoutIncrementRemove;

  /// Progression help paragraph.
  ///
  /// In en, this message translates to:
  /// **'A target is what you plan to lift. Last time is what you recorded before. Today shows only the sets you actually record. Suggestions never record a set.'**
  String get workoutProgressionHelp1;

  /// Progression help paragraph.
  ///
  /// In en, this message translates to:
  /// **'GoHard looks at your two most recent sessions of the same plan workout. If both have every planned set of an exercise at its target weight, with reps at the top of its range, it suggests the target plus one weight increment that you chose.'**
  String get workoutProgressionHelp2;

  /// Progression help paragraph.
  ///
  /// In en, this message translates to:
  /// **'It never goes further back than those two sessions, never adds sets, changes reps or swaps exercises, and never lowers a weight on its own. Timed, bodyweight and assisted exercises keep manual targets.'**
  String get workoutProgressionHelp3;

  /// Progression help paragraph.
  ///
  /// In en, this message translates to:
  /// **'An increment larger than 5% of the current target is not suggested automatically; you can still set the target yourself. That limit is a GoHard product choice, not a safety threshold.'**
  String get workoutProgressionHelp4;

  /// Progression help paragraph.
  ///
  /// In en, this message translates to:
  /// **'Reps say nothing about effort, form, pain or recovery. A suggestion is optional: review it, edit it or keep your current target. Nothing changes until you confirm.'**
  String get workoutProgressionHelp5;

  /// Sources paragraph of the progression help. Keep the facts and years exactly.
  ///
  /// In en, this message translates to:
  /// **'Published guidance: the 2009 ACSM position stand describes raising the load by about 2–10% once you can do one or two reps more than your target in two consecutive sessions. The 2026 ACSM position stand advises progressive resistance training, and notes that continued overload matters mainly for longer-term progress. GoHard\'s rule (the top of your range in your last two sessions, one increment you chose, at most 5%) is its own product choice; neither paper tests or validates it.'**
  String get workoutProgressionHelpSources;

  /// Coach line on Train › Progress with a workouts goal.
  ///
  /// In en, this message translates to:
  /// **'{count} of {target} workouts recorded this week.'**
  String progressCoachWorkoutsOfTarget(int count, int target);

  /// Coach line with a Run / Walk goal.
  ///
  /// In en, this message translates to:
  /// **'{count} of {target} runs or walks recorded this week.'**
  String progressCoachRunWalkOfTarget(int count, int target);

  /// Coach line: this week counts.
  ///
  /// In en, this message translates to:
  /// **'This week so far: {workouts, plural, =1{1 workout} other{{workouts} workouts}} and {activities, plural, =1{1 run or walk} other{{activities} runs or walks}} recorded.'**
  String progressCoachSoFar(int workouts, int activities);

  /// Coach line: this week counts, no goals set.
  ///
  /// In en, this message translates to:
  /// **'This week so far: {workouts, plural, =1{1 workout} other{{workouts} workouts}} and {activities, plural, =1{1 run or walk} other{{activities} runs or walks}} recorded. Set weekly goals below if you\'d like a target.'**
  String progressCoachSoFarSetGoals(int workouts, int activities);

  /// Coach line: empty week.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet this week. Set weekly goals below if you\'d like a target.'**
  String get progressCoachNothingYet;

  /// Topic label passed with an Ask GoHard question from the recap.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get progressCoachContextLabel;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Strength trends'**
  String get progressStrengthTrends;

  /// Link to all exercise trends.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get progressSeeAll;

  /// Screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'See all exercise trends'**
  String get progressSeeAllTrendsSemantic;

  /// Trends empty with training recorded.
  ///
  /// In en, this message translates to:
  /// **'No exercise with a stable identity has recorded sets yet. Movements typed as free text have no trend.'**
  String get progressNoStableTrend;

  /// Trends empty state.
  ///
  /// In en, this message translates to:
  /// **'No training recorded yet'**
  String get progressNoTrainingTitle;

  /// Trends empty state.
  ///
  /// In en, this message translates to:
  /// **'Trends are built only from workouts you actually record. There is nothing to chart until then.'**
  String get progressNoTrainingBody;

  /// Button in the empty trends state.
  ///
  /// In en, this message translates to:
  /// **'Start a manual workout'**
  String get progressStartManual;

  /// Link to Me › Body progress.
  ///
  /// In en, this message translates to:
  /// **'Body progress'**
  String get progressBodyLink;

  /// Screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Open Body progress: weight and measurements'**
  String get progressBodyLinkSemantic;

  /// Section header: plan adherence.
  ///
  /// In en, this message translates to:
  /// **'Am I following my plan?'**
  String get progressPlanHeader;

  /// Adherence without a primary plan.
  ///
  /// In en, this message translates to:
  /// **'You have no primary plan right now. Manual training still counts as training.'**
  String get progressNoPrimary;

  /// Adherence before any workout is due.
  ///
  /// In en, this message translates to:
  /// **'No planned workout has come due yet.'**
  String get progressNothingDue;

  /// Adherence count.
  ///
  /// In en, this message translates to:
  /// **'{recorded} of {due} due workouts recorded'**
  String progressDueRecorded(int recorded, int due);

  /// Screen-reader label of the adherence bar.
  ///
  /// In en, this message translates to:
  /// **'Due workouts recorded'**
  String get progressDueRail;

  /// Adherence breakdown.
  ///
  /// In en, this message translates to:
  /// **'{full} completed · {partial} partial · {skipped} skipped · {missed} missed'**
  String progressAdherenceBreakdown(
    int full,
    int partial,
    int skipped,
    int missed,
  );

  /// Link to Train › Plan without a plan.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get progressPlansLink;

  /// Link to Train › Plan.
  ///
  /// In en, this message translates to:
  /// **'View your plan'**
  String get progressViewPlan;

  /// Screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Open Train, Plan'**
  String get progressOpenPlanSemantic;

  /// Note under plan adherence.
  ///
  /// In en, this message translates to:
  /// **'Weekly goals are separate: they never schedule, move or complete a planned workout.'**
  String get progressGoalsSeparate;

  /// Section header: weekly consistency.
  ///
  /// In en, this message translates to:
  /// **'Am I consistent?'**
  String get progressConsistencyHeader;

  /// Consistency chart caption.
  ///
  /// In en, this message translates to:
  /// **'Days with recorded training in each of the last 8 weeks. {count, plural, =1{1 session} other{{count} sessions}} in total.'**
  String progressConsistencyCaption(int count);

  /// Screen-reader label of the consistency bars.
  ///
  /// In en, this message translates to:
  /// **'Training days per week, oldest first: {days}'**
  String progressConsistencySemantic(String days);

  /// Weekly goal row label.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get progressWorkoutsLabel;

  /// Weekly goal row label.
  ///
  /// In en, this message translates to:
  /// **'Run / Walk'**
  String get progressRunWalkLabel;

  /// A count of workouts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 workout} other{{count} workouts}}'**
  String progressWorkoutCount(int count);

  /// A count of runs or walks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 run or walk} other{{count} runs or walks}}'**
  String progressRunWalkCount(int count);

  /// A count of runs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 run} other{{count} runs}}'**
  String progressRunCount(int count);

  /// A count of walks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 walk} other{{count} walks}}'**
  String progressWalkCount(int count);

  /// Screen-reader label of a goal row without a target.
  ///
  /// In en, this message translates to:
  /// **'{what}: {counted} recorded this week, no target.'**
  String progressGoalSaidNoTarget(String what, String counted);

  /// Screen-reader label of a goal row with a target.
  ///
  /// In en, this message translates to:
  /// **'{what}: {count} of {target} this week.'**
  String progressGoalSaidTarget(String what, int count, int target);

  /// Overline of the week panel.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get progressThisWeek;

  /// Heading of the week panel.
  ///
  /// In en, this message translates to:
  /// **'Your weekly rhythm'**
  String get progressWeeklyRhythm;

  /// Link editing weekly goals.
  ///
  /// In en, this message translates to:
  /// **'Edit goals'**
  String get progressEditGoals;

  /// Link setting weekly goals.
  ///
  /// In en, this message translates to:
  /// **'Set weekly goals'**
  String get progressSetGoals;

  /// Screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Edit weekly goals'**
  String get progressEditGoalsSemantic;

  /// Status when the server lacks weekly goals.
  ///
  /// In en, this message translates to:
  /// **'Weekly goals are not available on your account\'s server yet, so none can be saved. Your counts are still shown.'**
  String get progressGoalsUnavailable;

  /// Status of unsynced goals.
  ///
  /// In en, this message translates to:
  /// **'Goals saved on this phone · sync pending'**
  String get progressGoalsPending;

  /// Status of conflicting goals.
  ///
  /// In en, this message translates to:
  /// **'This week\'s goals were also changed on another device. Review them from the notice at the bottom of the screen.'**
  String get progressGoalsReview;

  /// Goal row count without a target.
  ///
  /// In en, this message translates to:
  /// **'{count} recorded'**
  String progressCountRecorded(int count);

  /// Goal row count against a target.
  ///
  /// In en, this message translates to:
  /// **'{count} of {target}'**
  String progressCountOfTarget(int count, int target);

  /// Recap goal row count, goal reached.
  ///
  /// In en, this message translates to:
  /// **'{count} of {target} · reached'**
  String progressCountOfTargetReached(int count, int target);

  /// Screen-reader label of a goal bar.
  ///
  /// In en, this message translates to:
  /// **'{label} goal'**
  String progressGoalRail(String label);

  /// Weekly goals sheet title.
  ///
  /// In en, this message translates to:
  /// **'Weekly goals'**
  String get progressGoalsTitle;

  /// Snackbar when saving goals failed.
  ///
  /// In en, this message translates to:
  /// **'Your goals could not be saved on this phone. Nothing changed.'**
  String get progressGoalsSaveFailed;

  /// Snackbar after clearing goals.
  ///
  /// In en, this message translates to:
  /// **'Weekly goals cleared from this week.'**
  String get progressGoalsCleared;

  /// Snackbar after saving goals.
  ///
  /// In en, this message translates to:
  /// **'Weekly goals saved.'**
  String get progressGoalsSaved;

  /// Weekly goal field error.
  ///
  /// In en, this message translates to:
  /// **'Use a whole number from {min} to {max}, or leave it blank.'**
  String progressGoalRangeError(int min, int max);

  /// Weekly goal field helper.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max} a week, or blank for no target'**
  String progressGoalFieldHelper(int min, int max);

  /// Weekly goals sheet helper.
  ///
  /// In en, this message translates to:
  /// **'These are weekly activity targets. Your training plan stays the same.'**
  String get progressGoalsHelper;

  /// Weekly goals sheet caption.
  ///
  /// In en, this message translates to:
  /// **'They apply from this week ({range}) until you change them. Earlier weeks keep the goals they had. Leave a field blank for no target.'**
  String progressGoalsApply(String range);

  /// Weekly goal field.
  ///
  /// In en, this message translates to:
  /// **'Workouts per week'**
  String get progressGoalWorkoutsField;

  /// Weekly goal field.
  ///
  /// In en, this message translates to:
  /// **'Runs and walks per week'**
  String get progressGoalRunWalkField;

  /// Saves weekly goals.
  ///
  /// In en, this message translates to:
  /// **'Save goals'**
  String get progressGoalsSave;

  /// Screen-reader label of the recap link.
  ///
  /// In en, this message translates to:
  /// **'Last week\'s recap, {range}'**
  String progressRecapLinkSemantic(String range);

  /// Screen-reader label of the recap link.
  ///
  /// In en, this message translates to:
  /// **'Last week\'s recap, {range}. Earlier weeks are inside.'**
  String progressRecapLinkSemanticOlder(String range);

  /// Recap link title.
  ///
  /// In en, this message translates to:
  /// **'Last week\'s recap'**
  String get progressRecapLinkTitle;

  /// Recap link subtitle.
  ///
  /// In en, this message translates to:
  /// **'{range} · earlier weeks inside'**
  String progressRecapLinkOlder(String range);

  /// Screen-reader label of a trend preview.
  ///
  /// In en, this message translates to:
  /// **'{name}. Latest recorded {value} on {date}. {metric}. {count, plural, =1{1 session} other{{count} sessions}} charted.'**
  String progressTrendPreviewSemantic(
    String name,
    String value,
    String date,
    String metric,
    int count,
  );

  /// Trend preview caption.
  ///
  /// In en, this message translates to:
  /// **'Latest recorded · {date}'**
  String progressLatestRecordedOn(String date);

  /// Trend screen label.
  ///
  /// In en, this message translates to:
  /// **'Latest recorded'**
  String get progressLatestRecorded;

  /// A rep count as a trend value or rep choice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} reps}}'**
  String progressRepsValue(int count);

  /// Trend metric.
  ///
  /// In en, this message translates to:
  /// **'Top set load · {reps} reps'**
  String progressMetricLoad(int reps);

  /// Trend metric.
  ///
  /// In en, this message translates to:
  /// **'Most reps in a set · no added load'**
  String get progressMetricReps;

  /// Trend metric.
  ///
  /// In en, this message translates to:
  /// **'Longest recorded time'**
  String get progressMetricDuration;

  /// Trend metric when nothing is comparable.
  ///
  /// In en, this message translates to:
  /// **'No comparable measure'**
  String get progressMetricNone;

  /// Trend change of zero.
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get progressNoChange;

  /// Signed change in reps. signed is "+3" or "−2".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{signed} rep} other{{signed} reps}}'**
  String progressChangeReps(String signed, int count);

  /// Chart range choice.
  ///
  /// In en, this message translates to:
  /// **'4 weeks'**
  String get progressRange4Weeks;

  /// Chart range choice.
  ///
  /// In en, this message translates to:
  /// **'12 weeks'**
  String get progressRange12Weeks;

  /// Chart range choice: all history.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get progressRangeAll;

  /// Adverbial phrase for the chosen chart range, inserted in sentences.
  ///
  /// In en, this message translates to:
  /// **'{range, select, weeks4{in the last 4 weeks} weeks12{in the last 12 weeks} other{in all your history}}'**
  String progressRangeWords(String range);

  /// Trend with no session in range.
  ///
  /// In en, this message translates to:
  /// **'No session {rangeWords}'**
  String progressNoSessionRange(String rangeWords);

  /// Page title.
  ///
  /// In en, this message translates to:
  /// **'Exercise trends'**
  String get progressTrendsTitle;

  /// Page subtitle.
  ///
  /// In en, this message translates to:
  /// **'Exercises you have recorded, most recent first'**
  String get progressTrendsSubtitle;

  /// Search field label.
  ///
  /// In en, this message translates to:
  /// **'Search your exercises'**
  String get progressTrendsSearch;

  /// Empty trends list.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get progressTrendsEmptyTitle;

  /// Empty trends list.
  ///
  /// In en, this message translates to:
  /// **'An exercise appears here once a finished workout has recorded sets of it.'**
  String get progressTrendsEmptyBody;

  /// Trends search with no match.
  ///
  /// In en, this message translates to:
  /// **'No match'**
  String get progressTrendsNoMatchTitle;

  /// Trends search with no match. query is user input.
  ///
  /// In en, this message translates to:
  /// **'None of your recorded exercises matches \"{query}\".'**
  String progressTrendsNoMatchBody(String query);

  /// Trend list row subtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}} · latest {date}'**
  String progressTrendRowSubtitle(int count, String date);

  /// Trend read error.
  ///
  /// In en, this message translates to:
  /// **'This could not be read'**
  String get progressReadErrorTitle;

  /// Trend read error.
  ///
  /// In en, this message translates to:
  /// **'Your records on this phone could not be read just now. Nothing was changed; try again.'**
  String get progressReadErrorBody;

  /// Trend of an exercise without sets.
  ///
  /// In en, this message translates to:
  /// **'No recorded sets'**
  String get progressNoRecordedSetsTitle;

  /// Trend of an exercise without sets.
  ///
  /// In en, this message translates to:
  /// **'This exercise has no recorded sets in a finished workout any more.'**
  String get progressNoRecordedSetsBody;

  /// All sessions page without sets.
  ///
  /// In en, this message translates to:
  /// **'This exercise has no recorded sets any more.'**
  String get progressNoRecordedSetsAnyMore;

  /// Label before rep count choices.
  ///
  /// In en, this message translates to:
  /// **'Compare sets of'**
  String get progressCompareSetsOf;

  /// Trend with no comparable measure.
  ///
  /// In en, this message translates to:
  /// **'These sets have no reps with a load, no reps alone and no recorded time, so there is nothing comparable to chart. Every recorded session is listed below.'**
  String get progressNothingComparable;

  /// Chart caption.
  ///
  /// In en, this message translates to:
  /// **'Recorded sessions only'**
  String get progressRecordedOnly;

  /// Caption of the change value.
  ///
  /// In en, this message translates to:
  /// **'first to latest, this range'**
  String get progressFirstToLatest;

  /// Chart empty for the range.
  ///
  /// In en, this message translates to:
  /// **'No session with a set of {reps} reps {rangeWords}. Choose a longer range or another rep count.'**
  String progressEmptyRangeLoad(int reps, String rangeWords);

  /// Chart empty for the range.
  ///
  /// In en, this message translates to:
  /// **'No session {rangeWords}. Choose a longer range.'**
  String progressEmptyRange(String rangeWords);

  /// Screen-reader label of the trend chart; points lists each date and value.
  ///
  /// In en, this message translates to:
  /// **'{metric}, {rangeWords}: {count, plural, =1{1 session} other{{count} sessions}}. {points}.'**
  String progressChartSemantic(
    String metric,
    String rangeWords,
    int count,
    String points,
  );

  /// Chart with one point.
  ///
  /// In en, this message translates to:
  /// **'One comparable session so far. A change needs at least two.'**
  String get progressOnePoint;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Sessions in this range'**
  String get progressSessionsInRange;

  /// Explains the session rows.
  ///
  /// In en, this message translates to:
  /// **'Each row is the heaviest set of {reps} reps in that workout. Shown at the same rep count.'**
  String progressRowsExplainLoad(int reps);

  /// Explains the session rows.
  ///
  /// In en, this message translates to:
  /// **'Each row is that workout\'s best set by this measure.'**
  String get progressRowsExplain;

  /// Sets left out of a load chart.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recorded set without both reps and a load is not in this chart.} other{{count} recorded sets without both reps and a load are not in this chart.}}'**
  String progressExcludedLoad(int count);

  /// Sets left out of a reps chart.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recorded set with a load or without reps is not in this chart.} other{{count} recorded sets with a load or without reps are not in this chart.}}'**
  String progressExcludedReps(int count);

  /// Sets left out of a time chart.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recorded set without a recorded time is not in this chart.} other{{count} recorded sets without a recorded time are not in this chart.}}'**
  String progressExcludedDuration(int count);

  /// Link to all sessions of the exercise.
  ///
  /// In en, this message translates to:
  /// **'All {count, plural, =1{1 session} other{{count} sessions}} and sets'**
  String progressAllSessionsLink(int count);

  /// All sessions page fallback title.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get progressSessionsTitle;

  /// All sessions page subtitle.
  ///
  /// In en, this message translates to:
  /// **'Every recorded session, newest first'**
  String get progressAllSessionsSubtitle;

  /// Recap page title.
  ///
  /// In en, this message translates to:
  /// **'Weekly recap'**
  String get progressRecapTitle;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get progressPreviousWeek;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get progressNextWeek;

  /// Recap heading for last week.
  ///
  /// In en, this message translates to:
  /// **'Last week · {range}'**
  String progressRecapLastWeek(String range);

  /// Recap heading for an older week.
  ///
  /// In en, this message translates to:
  /// **'Week of {range}'**
  String progressRecapWeekOf(String range);

  /// Screen-reader recap sentence.
  ///
  /// In en, this message translates to:
  /// **'Last week {range}.'**
  String progressRecapSemLastWeek(String range);

  /// Screen-reader recap sentence.
  ///
  /// In en, this message translates to:
  /// **'Week of {range}.'**
  String progressRecapSemWeekOf(String range);

  /// Screen-reader recap sentence.
  ///
  /// In en, this message translates to:
  /// **'No activity was recorded.'**
  String get progressRecapSemNoActivity;

  /// Screen-reader recap sentence. list like "2 workouts, 1 run".
  ///
  /// In en, this message translates to:
  /// **'{list} recorded.'**
  String progressRecapSemRecorded(String list);

  /// Screen-reader recap sentence. kind is walking/running/mixed.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walking{Walking distance} running{Running distance} other{Run / Walk distance}} {distance}.'**
  String progressRecapSemDistance(String kind, String distance);

  /// Screen-reader recap sentence.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walking{Walking distance} running{Running distance} other{Run / Walk distance}} {distance}, some distances not recorded.'**
  String progressRecapSemDistanceIncomplete(String kind, String distance);

  /// Screen-reader recap sentence.
  ///
  /// In en, this message translates to:
  /// **'Active time {duration}.'**
  String progressRecapSemActive(String duration);

  /// A total that is unknown (not zero).
  ///
  /// In en, this message translates to:
  /// **'not recorded'**
  String get progressNotRecorded;

  /// Recap panel heading.
  ///
  /// In en, this message translates to:
  /// **'Your week, recorded'**
  String get progressRecapHeading;

  /// Recap panel empty.
  ///
  /// In en, this message translates to:
  /// **'No activity was recorded this week.'**
  String get progressRecapEmpty;

  /// Label under the workouts count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Workout} other{Workouts}}'**
  String progressRecapWorkoutsLabel(int count);

  /// Label under the activity count (walks only).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Walk} other{Walks}}'**
  String progressRecapWalks(int count);

  /// Label under the activity count (runs only).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Run} other{Runs}}'**
  String progressRecapRuns(int count);

  /// Label under the activity count (both).
  ///
  /// In en, this message translates to:
  /// **'Runs and walks'**
  String get progressRecapRunsAndWalks;

  /// Recap stat label. kind is walking/running/mixed.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walking{Walking distance} running{Running distance} other{Run / Walk distance}}'**
  String progressRecapDistanceLabel(String kind);

  /// Recap stat label.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walking{Walking time} running{Running time} other{Run / Walk time}}'**
  String progressRecapTimeLabel(String kind);

  /// Recap note: activities missing distance.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 activity had no distance recorded and is not in the total.} other{{count} activities had no distance recorded and are not in the total.}}'**
  String progressRecapIncomplete(int count);

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Your weekly targets'**
  String get progressRecapTargets;

  /// Recap without goals.
  ///
  /// In en, this message translates to:
  /// **'No goals were set for this week.'**
  String get progressRecapNoGoals;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Strength highlight'**
  String get progressRecapHighlight;

  /// Highlight row subtitle. dates is "first → last".
  ///
  /// In en, this message translates to:
  /// **'{dates} · recorded at {reps} reps'**
  String progressRecapHighlightSubtitle(String dates, int reps);

  /// Joins the last item of a list.
  ///
  /// In en, this message translates to:
  /// **'{head} and {last}'**
  String progressListJoin(String head, String last);

  /// Recap coach line.
  ///
  /// In en, this message translates to:
  /// **'No activity was recorded in the week of {range}.'**
  String progressRecapCoachEmpty(String range);

  /// Recap coach line.
  ///
  /// In en, this message translates to:
  /// **'You recorded {list} in the week of {range}.'**
  String progressRecapCoach(String list, String range);

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'This week\'s sessions'**
  String get progressRecapSessions;

  /// Recap without sessions.
  ///
  /// In en, this message translates to:
  /// **'Nothing was recorded between {start} and {end}.'**
  String progressRecapNothingBetween(String start, String end);

  /// Screen-reader label of a recap goal.
  ///
  /// In en, this message translates to:
  /// **'{label}: {count} of {target}.'**
  String progressTargetRowSemantic(String label, int count, int target);

  /// Screen-reader label of a reached recap goal.
  ///
  /// In en, this message translates to:
  /// **'{label}: {count} of {target}, reached.'**
  String progressTargetRowSemanticReached(String label, int count, int target);

  /// Server code PASSWORD_TOO_LONG, or the same local check.
  ///
  /// In en, this message translates to:
  /// **'That password is longer than 256 characters. Use a shorter one.'**
  String get accountErrorPasswordTooLong;

  /// New password and its confirmation differ.
  ///
  /// In en, this message translates to:
  /// **'The two new passwords are not the same.'**
  String get accountErrorPasswordMismatch;

  /// The code field does not hold 8 digits.
  ///
  /// In en, this message translates to:
  /// **'Enter all 8 digits of the code.'**
  String get accountErrorCodeIncomplete;

  /// Server code INVALID_CODE: wrong code (or no code was sent to this address).
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. Check the latest email from GoHard, or ask for a new code.'**
  String get accountErrorCodeInvalid;

  /// Server code CODE_EXPIRED.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Ask for a new one.'**
  String get accountErrorCodeExpired;

  /// Server code TOO_MANY_ATTEMPTS: the code is locked after too many tries.
  ///
  /// In en, this message translates to:
  /// **'Too many tries for this code. Ask for a new code.'**
  String get accountErrorCodeAttempts;

  /// Server code EMAIL_COOLDOWN. seconds = wait before another code (s = seconds, short unit).
  ///
  /// In en, this message translates to:
  /// **'Please wait {seconds} s before asking for another code.'**
  String accountErrorCooldown(int seconds);

  /// Server has no email sender configured (EMAIL_UNAVAILABLE). Said before promising any email.
  ///
  /// In en, this message translates to:
  /// **'Email recovery isn\'t available yet. Your account and data are safe; try again later.'**
  String get accountEmailUnavailable;

  /// Server code EMAIL_BUSY: the global email budget is used up for now.
  ///
  /// In en, this message translates to:
  /// **'GoHard is sending too many emails right now. Try again in a few minutes.'**
  String get accountErrorEmailBusy;

  /// Server code INVALID_RESET_TOKEN: the reset step timed out or was already used.
  ///
  /// In en, this message translates to:
  /// **'This reset has expired or was already used. Ask for a new code to start again.'**
  String get accountErrorResetExpired;

  /// The account server is older than this feature (404).
  ///
  /// In en, this message translates to:
  /// **'Your account\'s server doesn\'t offer this yet. Nothing was changed.'**
  String get accountErrorNotSupported;

  /// No answer to "set new password": it may or may not have changed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm the change. Try signing in with your new password; if that doesn\'t work, ask for a new code.'**
  String get accountErrorUncertainReset;

  /// No answer to "change password" while signed in.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm whether your password changed. Nothing on this phone was lost. If you\'re asked to sign in, try the new password first.'**
  String get accountErrorUncertainChange;

  /// Label of the one field for an emailed 8-digit code.
  ///
  /// In en, this message translates to:
  /// **'8-digit code'**
  String get codeFieldLabel;

  /// Helper under the code field.
  ///
  /// In en, this message translates to:
  /// **'From the email GoHard sent you. You can paste it.'**
  String get codeFieldHelper;

  /// Button: send the code again.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get codeResend;

  /// Disabled resend button while the cooldown runs. s = seconds (short unit).
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds} s'**
  String codeResendIn(int seconds);

  /// Under the code field: a sent request is not proof of delivery.
  ///
  /// In en, this message translates to:
  /// **'It can take a minute to arrive. Check spam or junk too.'**
  String get codeDeliveryNote;

  /// Field: the new password.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// Field: the new password again.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get newPasswordConfirmLabel;

  /// Field: the password in use now.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// The one password rule, shown beside every new-password field.
  ///
  /// In en, this message translates to:
  /// **'At least 15 characters. A few unrelated words work well; any characters are fine.'**
  String get passwordRule;

  /// Sign-in: link to password recovery.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// Sign-in notice after a password reset or change.
  ///
  /// In en, this message translates to:
  /// **'Your password was changed. Sign in with your new password; everything on this phone is still here.'**
  String get authNoticePasswordChanged;

  /// Forgot password, step 1 title.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetTitle;

  /// Forgot password, step 1. Does not say whether an account exists.
  ///
  /// In en, this message translates to:
  /// **'Enter your account\'s email. If an account uses it, we\'ll send it a reset code.'**
  String get resetEmailLead;

  /// Button: request a reset code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get resetSendCode;

  /// Forgot password, step 2 title.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get resetCodeTitle;

  /// Step 2. email = the address typed (user content). Acknowledges a request, not delivery.
  ///
  /// In en, this message translates to:
  /// **'If an account uses {email}, we\'ve sent it an 8-digit code. It\'s valid for 10 minutes.'**
  String resetCodeLead(String email);

  /// Button: go back and correct the email.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get resetUseAnotherEmail;

  /// Forgot password, step 3 title.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetPasswordTitle;

  /// Step 3 lead.
  ///
  /// In en, this message translates to:
  /// **'Choose your new password. Every device will be signed out.'**
  String get resetPasswordLead;

  /// Button: save the new password.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get resetSetPassword;

  /// Button after an unconfirmed reset: go and try signing in.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get resetGoToSignIn;

  /// Me › Password page title.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// Change password lead.
  ///
  /// In en, this message translates to:
  /// **'Your current password is checked by GoHard before anything changes.'**
  String get changePasswordLead;

  /// Warning before changing the password.
  ///
  /// In en, this message translates to:
  /// **'Changing it signs you out on every device, this one too. Your data stays on this phone and syncs again when you sign in.'**
  String get changePasswordSignsOut;

  /// Button: change the password.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordButton;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere?'**
  String get changePasswordConfirmTitle;

  /// Confirmation dialog body.
  ///
  /// In en, this message translates to:
  /// **'After the change you\'ll sign in again with the new password, on this phone and every other device.'**
  String get changePasswordConfirmBody;

  /// Change password needs a connection.
  ///
  /// In en, this message translates to:
  /// **'Changing your password needs a connection. Nothing is saved for later.'**
  String get changePasswordOffline;

  /// Verify email page title.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyTitle;

  /// Verify email lead. email = the account address (user content).
  ///
  /// In en, this message translates to:
  /// **'We\'ll send an 8-digit code to {email} to confirm it\'s yours.'**
  String verifyLead(String email);

  /// Button: send a verification code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get verifySend;

  /// Button: confirm with the code.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyConfirm;

  /// Button: leave without verifying.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get verifyLater;

  /// The server confirms the address is verified.
  ///
  /// In en, this message translates to:
  /// **'Your email is verified.'**
  String get verifyVerified;

  /// Toast after verifying.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get verifyDone;

  /// Me › Account row title.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get meEmail;

  /// Me › Email value when verified by the server.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get meEmailVerified;

  /// Me › Email value when not verified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get meEmailNotVerified;

  /// Me › Account row title.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get mePassword;

  /// Me › Password row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get mePasswordSubtitle;

  /// Sign-up refused: the server has no email sender, so a new account could never be verified. No account exists.
  ///
  /// In en, this message translates to:
  /// **'New accounts can\'t be created right now because email verification isn\'t available. Nothing was created; please try again later.'**
  String get accountErrorRegistrationUnavailable;

  /// Title of the step every new account completes before setup.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyGateTitle;

  /// Under the title: where the code went (the registered address).
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-digit code we sent to {email}.'**
  String verifyGateLead(String email);

  /// Why the step is required (new account).
  ///
  /// In en, this message translates to:
  /// **'Verifying your email is needed to finish setting up your account. It confirms this address is yours and changes nothing else.'**
  String get verifyGateWhy;

  /// Button: ask the server whether the address was verified meanwhile (on another device).
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get verifyCheckAgain;

  /// Quiet button on the verification step.
  ///
  /// In en, this message translates to:
  /// **'Sign out or use another account'**
  String get verifyGateSignOut;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get verifyGateSignOutTitle;

  /// Confirmation body: signing out deletes nothing and does not change the pending account.
  ///
  /// In en, this message translates to:
  /// **'This account stays as it is, waiting for verification. Sign in again any time to verify it.'**
  String get verifyGateSignOutBody;

  /// Under the verify form when nothing is due.
  ///
  /// In en, this message translates to:
  /// **'Verifying confirms this address is yours. It changes nothing else.'**
  String get verifyScope;

  /// Under the verify form for an existing account in its grace period: the server's deadline.
  ///
  /// In en, this message translates to:
  /// **'Verify by {date} to keep syncing. It confirms this address is yours and changes nothing else.'**
  String verifyGraceWhy(String date);

  /// Under the verify form for an existing account past its deadline.
  ///
  /// In en, this message translates to:
  /// **'Syncing is paused until you verify. Everything you save stays on this phone and goes up once you verify.'**
  String get verifyPausedWhy;

  /// Today notice for an existing account in its grace period (the server's deadline).
  ///
  /// In en, this message translates to:
  /// **'Verify your email by {date} to keep syncing.'**
  String todayVerifyBy(String date);

  /// Today notice for an existing account past its deadline.
  ///
  /// In en, this message translates to:
  /// **'Verify your email to sync again. What you save stays on this phone.'**
  String get todayVerifyPaused;

  /// The one action of the Today notice: opens the verification form.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get todayVerifyAction;

  /// Me › Email second line: the grace deadline.
  ///
  /// In en, this message translates to:
  /// **'Verify by {date}'**
  String meEmailVerifyBy(String date);

  /// Me › Email second line past the deadline.
  ///
  /// In en, this message translates to:
  /// **'Syncing paused until verified'**
  String get meEmailPaused;

  /// Eat › History & trends panel subtitle.
  ///
  /// In en, this message translates to:
  /// **'Review your intake by week or month'**
  String get eatHistoryTrendsSubtitle;

  /// Screen-reader label of the whole Eat › History & trends panel.
  ///
  /// In en, this message translates to:
  /// **'History and trends. Review your intake by week or month'**
  String get eatHistoryTrendsSaid;

  /// Train › Workouts section header: the latest recorded sessions.
  ///
  /// In en, this message translates to:
  /// **'Recent workouts'**
  String get trainRecentWorkouts;

  /// Link in the Recent workouts header: opens Workout history.
  ///
  /// In en, this message translates to:
  /// **'View all history'**
  String get trainViewAllHistory;

  /// Screen-reader label of View all history.
  ///
  /// In en, this message translates to:
  /// **'View all workout history'**
  String get trainViewAllHistorySaid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'fr':
      {
        switch (locale.countryCode) {
          case 'CA':
            return AppLocalizationsFrCa();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
