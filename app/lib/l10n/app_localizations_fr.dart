// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get coachNameLeon => 'Leon';

  @override
  String get coachNameLeona => 'Leona';

  @override
  String get coachAnimalLion => 'lion';

  @override
  String get coachAnimalLioness => 'lionne';

  @override
  String get coachAskTitle => 'Demande à GoHard';

  @override
  String get coachAskAiAssistant => 'Assistant d\'entraînement IA';

  @override
  String coachAskAbout(String label) {
    return 'Sujet : $label';
  }

  @override
  String get coachAskIntro =>
      'Pose une question sur ton programme. Les réponses sont rédigées par une IA à partir de ton brouillon et du guide vérifié de GoHard : vérifie tout ce qui est important. Rien n\'est envoyé avant que tu appuies sur Envoyer.';

  @override
  String get coachAskSuggestWhyIncluded =>
      'Pourquoi cet exercice a-t-il été inclus?';

  @override
  String get coachAskSuggestDumbbell =>
      'Puis-je le remplacer par un exercice aux haltères?';

  @override
  String get coachAskSuggestAlternatives =>
      'Quels sont les avantages et les compromis de ces solutions de rechange?';

  @override
  String get coachAskSuggestSetsReps => 'Que veut dire 3 × 8–12?';

  @override
  String get coachAskSuggestShorten =>
      'Comment pourrais-je raccourcir cette séance?';

  @override
  String get coachAskSuggestWhySplit =>
      'Pourquoi cette répartition pour mon horaire?';

  @override
  String get coachAskSuggestCompareSplits =>
      'En quoi Haut/Bas diffère-t-il de Poussée/Tirage/Jambes?';

  @override
  String get coachAskClearTitle => 'Effacer cette conversation?';

  @override
  String get coachAskClearBody =>
      'Ses questions et réponses sont supprimées de ce téléphone. Ton brouillon ne change pas.';

  @override
  String get coachAskClearAction => 'Effacer';

  @override
  String get coachAskClearTooltip => 'Effacer la conversation';

  @override
  String get coachAskInputHint => 'Pose une question';

  @override
  String get coachAskSend => 'Envoyer';

  @override
  String coachAskYouAsked(String text) {
    return 'Ta question : $text';
  }

  @override
  String get coachAskWaiting => 'En attente d\'une réponse';

  @override
  String get coachAskRetry => 'Réessayer';

  @override
  String get coachAskEditQuestion => 'Modifier la question';

  @override
  String get coachAskProblemLimit =>
      'Tu as posé beaucoup de questions aujourd\'hui. Demande à GoHard répondra de nouveau plus tard; le Guide rapide intégré fonctionne toujours.';

  @override
  String get coachAskProblemBusy =>
      'Demande à GoHard est occupé pour le moment. Réessaie dans un instant.';

  @override
  String get coachAskProblemUnreached =>
      'Impossible de joindre Demande à GoHard. Cela peut venir de la connexion de ce téléphone ou du serveur. Le Guide rapide intégré fonctionne toujours.';

  @override
  String get coachAskProblemInvalid =>
      'Cette question n\'a pas pu être envoyée. Modifie-la et envoie-la de nouveau (600 caractères au maximum).';

  @override
  String get coachAskProblemInterrupted =>
      'Cette question n\'a pas reçu de réponse avant la fermeture de Demande à GoHard. Réessaie pour la poser de nouveau.';

  @override
  String get coachAskProblemUnavailable =>
      'Demande à GoHard n\'est pas disponible pour le moment. Ta question est conservée et le Guide rapide intégré fonctionne toujours.';

  @override
  String get coachAskAiGenerated => 'Généré par IA';

  @override
  String get coachAskStale =>
      'Basé sur une version antérieure de ton brouillon';

  @override
  String get coachAskLess => 'Moins';

  @override
  String get coachAskMore => 'Plus';

  @override
  String get coachAskSourcesHeading => 'Sources du guide vérifié de GoHard';

  @override
  String get coachAskSuggestedChange => 'Modification suggérée';

  @override
  String get coachAskChangeFallback => 'Une modification de ton brouillon';

  @override
  String get coachAskApplied =>
      'Appliquée à ton brouillon. Elle est enregistrée comme toute autre modification; rien n\'est activé.';

  @override
  String get coachAskUndo => 'Annuler la modification';

  @override
  String get coachAskUndone =>
      'Annulée : ton brouillon est comme avant cette suggestion.';

  @override
  String get coachAskTextOnly =>
      'Ouvre le créateur de programme pour prévisualiser et appliquer les suggestions.';

  @override
  String get coachAskPreview => 'Prévisualiser la modification';

  @override
  String get coachAskCantApply =>
      'Cette suggestion ne peut pas être appliquée à ton brouillon.';

  @override
  String get coachAskDraftOnly => 'Brouillon seulement';

  @override
  String get coachAskDraftOnlyBody =>
      'Modifie le brouillon dans le créateur, enregistré comme toute modification. Rien n\'est activé.';

  @override
  String get coachAskDraftChanged =>
      'Ton brouillon a changé depuis cette suggestion';

  @override
  String get coachAskRecheck => 'Vérifier avec mon brouillon actuel';

  @override
  String get coachAskNotApplicableHeading =>
      'Ne s\'applique pas à ton brouillon actuel';

  @override
  String get coachAskNothingApplies =>
      'Plus rien dans cette suggestion ne s\'applique à ton brouillon.';

  @override
  String get coachAskApply => 'Appliquer au brouillon';

  @override
  String get coachAskKeep => 'Garder l\'actuel';

  @override
  String coachAskChangeAdded(String name, String rx) {
    return 'Ajouté : $name · $rx';
  }

  @override
  String coachAskChangeRemoved(String name, String rx) {
    return 'Retiré : $name · $rx';
  }

  @override
  String coachAskChangeArrow(String before, String after) {
    return '$before → $after';
  }

  @override
  String coachAskWeightCleared(String load, String name) {
    return 'La charge cible $load est retirée : un remplacement commence sans charge cible et ne reprend pas l\'historique de $name.';
  }

  @override
  String coachAskWeightKept(String load) {
    return 'La charge cible $load est conservée.';
  }

  @override
  String coachSkipWorkoutGone(String op) {
    String _temp0 = intl.Intl.selectLogic(op, {
      'removeExercise': 'Retirer un exercice',
      'replaceExercise': 'Remplacer un exercice',
      'setPrescription': 'Modifier les séries et répétitions',
      'other': 'Ajouter un exercice',
    });
    return '$_temp0 : la séance indiquée n\'est plus dans ton brouillon.';
  }

  @override
  String coachSkipExerciseGone(String op, String workout) {
    String _temp0 = intl.Intl.selectLogic(op, {
      'removeExercise': 'Retirer un exercice',
      'replaceExercise': 'Remplacer un exercice',
      'setPrescription': 'Modifier les séries et répétitions',
      'other': 'Ajouter un exercice',
    });
    return '$_temp0 : cet exercice n\'est plus dans $workout.';
  }

  @override
  String coachSkipReplaceUnavailable(String exercise) {
    return 'Remplacer $exercise : l\'exercice suggéré n\'est pas offert dans ton compte.';
  }

  @override
  String coachSkipReplaceSame(String exercise) {
    return 'Remplacer $exercise : c\'est déjà cet exercice.';
  }

  @override
  String coachSkipValuesOutside(String exercise) {
    return 'Modifier $exercise : les valeurs suggérées dépassent ce qu\'un programme permet.';
  }

  @override
  String coachSkipAddUnavailable(String workout) {
    return 'Ajouter un exercice à $workout : il n\'est pas offert dans ton compte.';
  }

  @override
  String coachSkipAddOutside(String exercise, String workout) {
    return 'Ajouter $exercise à $workout : les valeurs suggérées dépassent ce qu\'un programme permet.';
  }

  @override
  String coachSkipAddFull(String exercise, String workout) {
    return 'Ajouter $exercise à $workout : la séance compte déjà 30 exercices.';
  }

  @override
  String coachUndoRefused(String exercise) {
    return 'L\'annulation n\'est plus sûre : $exercise a été modifié après l\'application de la suggestion. Modifie-le plutôt dans le créateur.';
  }

  @override
  String get coachQuickGuide => 'Guide rapide';

  @override
  String get coachQuickGuideBuiltIn => 'Guide rapide · intégré';

  @override
  String get coachQuickGuideReviewed =>
      'Guide rapide · contenu intégré vérifié';

  @override
  String get coachAskOpenQuickGuide => 'Ouvrir le Guide rapide';

  @override
  String get coachGuideSources => 'Sources';

  @override
  String get coachGuideThisSplit => 'Cette répartition';

  @override
  String get coachGuideBenefits => 'Avantages';

  @override
  String get coachGuideLimitations => 'Limites';

  @override
  String get coachGuideTechniqueCues => 'Repères techniques';

  @override
  String get coachGuideAlternatives => 'Solutions de rechange';

  @override
  String get coachGuideCustomNoInfo =>
      'Ajouté par toi. GoHard n\'a aucune information technique vérifiée pour tes propres exercices.';

  @override
  String coachGuideMusclesLine(String list) {
    return 'Muscles : $list';
  }

  @override
  String coachGuideEquipmentLine(String equipment) {
    return 'Équipement : $equipment';
  }

  @override
  String get coachGuideRoleMain => 'Rôle : mouvement principal';

  @override
  String get coachGuideRoleAccessory => 'Rôle : exercice complémentaire';

  @override
  String get coachListSeparator => ', ';

  @override
  String get coachCycleArrow => ' → ';

  @override
  String coachWhyTitle(String name) {
    return 'Pourquoi $name?';
  }

  @override
  String get coachSheetHowItWorks => 'Fonctionnement';

  @override
  String get coachSheetGoodToKnow => 'Bon à savoir';

  @override
  String get coachSheetTradeOffs => 'Compromis';

  @override
  String get coachSheetChoosingSplit => 'Choisir une répartition';

  @override
  String get coachSplitEvidenceNote =>
      'Les études qui comparent des répartitions au même volume hebdomadaire ont trouvé des gains de force et de muscle semblables : choisis la structure que tu peux maintenir.';

  @override
  String get coachCompareTitle => 'Comparer les répartitions';

  @override
  String coachCompareSuggested(String name) {
    return '$name · Suggérée';
  }

  @override
  String get coachSheetYourWeek => 'Ta semaine';

  @override
  String get coachSheetOrganisation => 'Organisation';

  @override
  String get coachSheetDays => 'Jours';

  @override
  String get coachInfoCustom =>
      'Ajouté par toi. GoHard n\'a aucune note technique vérifiée pour tes propres exercices.';

  @override
  String get coachInfoCategoryEquipment => 'Catégorie et équipement';

  @override
  String get coachInfoNoNotes =>
      'Il n\'y a pas encore de notes intégrées pour cet exercice.';

  @override
  String get coachInfoMuscles => 'Muscles';

  @override
  String get coachInfoEquipment => 'Équipement';

  @override
  String get coachInfoInRoutine => 'Dans cette routine';

  @override
  String get coachInfoRoleMain =>
      'Un exercice principal : un mouvement polyarticulaire qui sollicite plusieurs grands muscles, habituellement fait tôt avec un repos plus long.';

  @override
  String coachInfoRoleMainIn(String workout) {
    return 'Un exercice principal dans $workout : un mouvement polyarticulaire qui sollicite plusieurs grands muscles, habituellement fait tôt avec un repos plus long.';
  }

  @override
  String get coachInfoRoleAccessory =>
      'Un exercice complémentaire : du travail supplémentaire pour des muscles précis, habituellement après les mouvements principaux.';

  @override
  String coachInfoRoleAccessoryIn(String workout) {
    return 'Un exercice complémentaire dans $workout : du travail supplémentaire pour des muscles précis, habituellement après les mouvements principaux.';
  }

  @override
  String get coachInfoTechnique => 'Technique';

  @override
  String get coachInfoPrescription => 'Prescription';

  @override
  String get coachInfoAsk => 'Poser une question sur cet exercice';

  @override
  String get coachInfoReplace => 'Remplacer…';

  @override
  String get coachRxNone => 'Aucune cible définie pour l\'instant.';

  @override
  String coachRxSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '$count série',
    );
    return '$_temp0';
  }

  @override
  String coachRxSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secondes',
      one: '$count seconde',
    );
    return '$_temp0';
  }

  @override
  String coachRxReps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count répétitions',
      one: '$count répétition',
    );
    return '$_temp0';
  }

  @override
  String coachRxRepRange(int lo, int hi) {
    return '$lo à $hi répétitions';
  }

  @override
  String coachRxSetsOf(String sets, String amount) {
    return '$sets de $amount';
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
      other: '$what, avec $rest secondes de repos entre les séries.',
      one: '$what, avec $rest seconde de repos entre les séries.',
    );
    return '$_temp0';
  }

  @override
  String coachGuideDays(String count) {
    String _temp0 = intl.Intl.selectLogic(count, {
      'd0': 'aucun jour d\'entraînement',
      'd1': 'un jour d\'entraînement',
      'd2': 'deux jours d\'entraînement',
      'd3': 'trois jours d\'entraînement',
      'd4': 'quatre jours d\'entraînement',
      'd5': 'cinq jours d\'entraînement',
      'd6': 'six jours d\'entraînement',
      'd7': 'sept jours d\'entraînement',
      'other': '$count jours d\'entraînement',
    });
    return '$_temp0';
  }

  @override
  String coachGuideEquipment(String equipment) {
    String _temp0 = intl.Intl.selectLogic(equipment, {
      'full_gym': 'l\'équipement d\'un gym',
      'dumbbells': 'des haltères seulement',
      'bodyweight': 'le poids du corps seulement',
      'other': 'l\'équipement d\'un gym',
    });
    return '$_temp0';
  }

  @override
  String coachGuideSuggestedBecause(String days, String equipment) {
    return 'Suggéré parce que tu as choisi $days et $equipment.';
  }

  @override
  String get coachGuideSwapDumbbell =>
      'Les exercices utilisent les versions aux haltères.';

  @override
  String get coachGuideSwapBodyweight =>
      'Les exercices utilisent les versions au poids du corps.';

  @override
  String coachGuideFitWeekly(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Une séance pour chacun de tes $days jours.',
      one: 'Une séance pour ton jour.',
    );
    return '$_temp0';
  }

  @override
  String coachGuideFitRotate(int days, int workouts) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Ses $workouts séances alternent sur tes $days jours.',
      one: 'Ses $workouts séances alternent sur ton jour.',
    );
    return '$_temp0';
  }

  @override
  String get coachGuideAnyDay => 'n\'importe quel jour';

  @override
  String coachGuideRotation(String cycle, String days) {
    return '$cycle, le $days. L\'ordre se poursuit d\'une semaine à l\'autre.';
  }

  @override
  String get coachAskMeInline => 'Demande-moi ›';

  @override
  String get coachAskMe => 'Demande-moi';

  @override
  String coachAskOpenWith(String name) {
    return 'Demande à GoHard : ouvrir la conversation avec $name';
  }

  @override
  String get languageSystem => 'Système';

  @override
  String languageSystemResolved(String language) {
    return 'Langue du téléphone : $language';
  }

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageFootnote =>
      'Conservée sur ce téléphone seulement. Le texte de GoHard change; tes notes, noms d\'aliments et noms d\'exercices saisis restent tels quels.';

  @override
  String get navToday => 'Aujourd\'hui';

  @override
  String get navTrain => 'Entraînement';

  @override
  String get navEat => 'Nutrition';

  @override
  String get navMe => 'Profil';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get busyWorking => 'En cours';

  @override
  String percentValue(int percent) {
    return '$percent pour cent';
  }

  @override
  String get motionDevice => 'Appareil';

  @override
  String get motionReduced => 'Réduit';

  @override
  String get hapticsDevice => 'Appareil';

  @override
  String get hapticsOff => 'Désactivé';

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
  String get unitMph => 'mi/h';

  @override
  String get unitMetre => 'm';

  @override
  String get unitFoot => 'pi';

  @override
  String paceValue(String pace, String unit) {
    return '$pace /$unit';
  }

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionDone => 'Terminé';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionTryAgain => 'Réessayer';

  @override
  String get actionContinue => 'Continuer';

  @override
  String get actionRemove => 'Retirer';

  @override
  String get actionOk => 'OK';

  @override
  String get errorGeneric =>
      'Un problème est survenu. Rien n\'a été perdu; réessaie.';

  @override
  String get brandName => 'GoHard';

  @override
  String get foodCategoryProteins => 'Protéines';

  @override
  String get foodCategoryCarbohydrates => 'Glucides';

  @override
  String get foodCategoryCarbsShort => 'Glucides';

  @override
  String get foodCategoryVegetables => 'Légumes';

  @override
  String get foodCategoryFruits => 'Fruits';

  @override
  String get foodCategoryDairy => 'Produits laitiers';

  @override
  String get foodCategoryFatsOils => 'Matières grasses et huiles';

  @override
  String get foodCategorySnacks => 'Collations';

  @override
  String get foodCategoryBeverages => 'Boissons';

  @override
  String get foodCategoryAll => 'Tout';

  @override
  String get foodTagFavourite => 'Favori';

  @override
  String get foodTagMine => 'Mon aliment';

  @override
  String get foodTagRecent => 'Récent';

  @override
  String get foodAsYouLoggedIt => 'Comme tu l\'as consigné';

  @override
  String foodBasisPer(String basis) {
    return 'par $basis';
  }

  @override
  String get foodServingFallback => 'portion';

  @override
  String get mealBreakfast => 'Déjeuner';

  @override
  String get mealLunch => 'Dîner';

  @override
  String get mealDinner => 'Souper';

  @override
  String get mealSnack => 'Collations';

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
    return '$value g de protéines';
  }

  @override
  String eatWaterValue(String amount) {
    return '$amount d\'eau';
  }

  @override
  String get eatTodayCaption => 'Aujourd\'hui';

  @override
  String get eatCarbs => 'Glucides';

  @override
  String get eatFat => 'Lipides';

  @override
  String get eatCalories => 'Calories';

  @override
  String get eatProtein => 'Protéines';

  @override
  String get eatGoalCaloriesWhole =>
      'L\'objectif de calories est un nombre entier, ou laisse le champ vide pour aucun objectif.';

  @override
  String get eatGoalProteinWhole =>
      'L\'objectif de protéines est un nombre entier, ou laisse le champ vide pour aucun objectif.';

  @override
  String get eatGoalWaterInvalid =>
      'L\'objectif d\'eau est une quantité supérieure à zéro, ou laisse le champ vide pour aucun objectif.';

  @override
  String get eatGoalsSaveFailed =>
      'Tes objectifs n\'ont pas pu être enregistrés sur ce téléphone. Ce que tu as saisi est toujours là.';

  @override
  String get eatGoalCaloriesLabel => 'Calories par jour';

  @override
  String get eatGoalProteinLabel => 'Protéines par jour';

  @override
  String get eatGoalWaterLabel => 'Eau par jour';

  @override
  String get eatGoalNone => 'Aucun objectif';

  @override
  String get eatGoalCaloriesHelper =>
      'De 500 à 10 000. Laisse vide pour aucun objectif de calories.';

  @override
  String get eatGoalProteinHelper =>
      'De 10 à 500. Laisse vide pour aucun objectif de protéines.';

  @override
  String get eatGoalWaterHelperMl =>
      'De 100 à 10 000. Laisse vide pour aucun objectif d\'eau.';

  @override
  String get eatGoalWaterHelperFlOz =>
      'De 3,4 à 338 (onces liquides US). Laisse vide pour aucun objectif d\'eau.';

  @override
  String get eatGoalsSave => 'Enregistrer les objectifs';

  @override
  String get eatGoalsNoSuggestion =>
      'GoHard ne suggère aucun objectif de calories ou de protéines. Si tu ne sais pas ce qui te convient, un ou une diététiste ou un médecin peut t\'aider.';

  @override
  String get eatGoalsSheetTitle => 'Objectifs quotidiens';

  @override
  String get eatGoalsSheetIntro =>
      'Ils se répètent chaque jour jusqu\'à ce que tu les changes. Laisse un champ vide pour n\'avoir aucun objectif.';

  @override
  String get eatEditGoals => 'Modifier les objectifs';

  @override
  String get eatEditGoalsSaid => 'Modifier les objectifs quotidiens';

  @override
  String get eatSetGoals => 'Fixer des objectifs quotidiens';

  @override
  String get eatCustomizeTracking => 'Personnaliser le suivi';

  @override
  String get eatTrackingIntro =>
      'Les calories et les protéines sont toujours affichées. Masquer un élément change seulement ce que tu vois : rien de ce que tu as consigné ou fixé n\'est supprimé.';

  @override
  String get eatTrackWaterSubtitle =>
      'Une ligne d\'eau dans Aujourd\'hui et Nutrition, avec un objectif facultatif';

  @override
  String get eatTrackWaterUnsupported =>
      'Le suivi de l\'eau exige une version plus récente du serveur de ton compte. Rien d\'autre ne change.';

  @override
  String get eatTrackCarbsSubtitle => 'Le total des glucides dans Nutrition';

  @override
  String get eatTrackFatSubtitle => 'Le total des lipides dans Nutrition';

  @override
  String get eatTrackSynced =>
      'Ces choix suivent ton compte sur tes autres téléphones.';

  @override
  String get waterUnitMl => 'ml';

  @override
  String get waterUnitFlOz => 'oz liq.';

  @override
  String get waterUnitMlName => 'Millilitres';

  @override
  String get waterUnitFlOzName => 'Onces liquides US';

  @override
  String get waterTitle => 'Eau';

  @override
  String get waterNoneLogged => 'Aucune eau consignée';

  @override
  String get waterSaidLoading => 'Eau, chargement';

  @override
  String get waterSaidNone => 'Eau, aucune eau consignée';

  @override
  String waterSaid(String amount) {
    return 'Eau $amount';
  }

  @override
  String waterSaidWithGoal(String amount, String goal, int percent) {
    return 'Eau $amount sur $goal, $percent pour cent';
  }

  @override
  String waterAddSaidMl(String amount) {
    return 'Ajouter $amount millilitres d\'eau';
  }

  @override
  String waterAddSaidFlOz(String amount) {
    return 'Ajouter $amount onces liquides d\'eau';
  }

  @override
  String waterUndo(String amount) {
    return 'Annuler $amount';
  }

  @override
  String waterUndoSaid(String amount) {
    return 'Annuler l\'ajout de $amount d\'eau';
  }

  @override
  String get waterOtherAmount => 'Autre quantité';

  @override
  String get waterRowHint => 'Ouvre le détail de l\'eau pour ce jour';

  @override
  String get waterSaveFailed =>
      'Impossible d\'enregistrer sur ce téléphone. Rien n\'a été ajouté.';

  @override
  String waterAddedAnnounce(String amount) {
    return '$amount d\'eau ajoutés. Annulation possible.';
  }

  @override
  String waterAddedOnDayAnnounce(String amount, String date) {
    return '$amount d\'eau ajoutés le $date. Annulation possible.';
  }

  @override
  String get waterAddTitle => 'Ajouter de l\'eau';

  @override
  String waterForDay(String date) {
    return 'Pour le $date';
  }

  @override
  String get waterAmountLabel => 'Quantité';

  @override
  String get waterProblemNotAboveZero =>
      'Entre une quantité supérieure à zéro.';

  @override
  String get waterProblemOverMax =>
      'Une entrée peut contenir au plus 5 L. Consigne une plus grande quantité en plusieurs fois.';

  @override
  String get waterGoalLabel => 'Objectif d\'eau';

  @override
  String get waterAdd => 'Ajouter';

  @override
  String get waterAnotherAmount => 'Autre quantité';

  @override
  String get waterNothingThisDay => 'Rien de consigné ce jour-là';

  @override
  String get waterLoggedThisDay => 'Consigné ce jour-là';

  @override
  String get waterEntryPending =>
      'Enregistré sur ce téléphone · touche pour corriger';

  @override
  String get waterEntryTap => 'Touche pour corriger';

  @override
  String waterRemoveTooltip(String amount) {
    return 'Supprimer $amount';
  }

  @override
  String get waterOnlyLoggedNote =>
      'Seule l\'eau que tu consignes ici est comptée, pas les boissons ni les aliments.';

  @override
  String get waterCorrectTitle => 'Corriger cette quantité';

  @override
  String get waterSuggestionAboutTitle =>
      'À propos de l\'objectif d\'eau suggéré';

  @override
  String waterSuggestionAboutBody(String amount) {
    return '$amount par jour est un point de départ général, pas une recommandation établie pour toi. Les besoins varient selon la taille, l\'activité, la chaleur et la santé; si une maladie ou un médicament influence la quantité que tu devrais boire, suis les conseils de ton médecin.\n\nLes autres boissons et les aliments contribuent aussi à l\'hydratation. GoHard compte seulement l\'eau que tu consignes toi-même, donc ton total ici n\'est pas tout ce que tu as bu.';
  }

  @override
  String waterSuggestedGoal(String amount) {
    return 'Objectif de départ suggéré : $amount par jour.';
  }

  @override
  String get waterSuggestedGoalNote =>
      'Un point de départ général; tes besoins peuvent être différents. Seule l\'eau que tu consignes est comptée.';

  @override
  String waterSuggestionUse(String amount) {
    return 'Utiliser $amount';
  }

  @override
  String get eatUnitGramProtein => 'g de protéines';

  @override
  String eatGoalProgressCalories(String eaten, String goal) {
    return '$eaten sur $goal kcal';
  }

  @override
  String eatGoalProgressProtein(String eaten, String goal) {
    return 'Protéines : $eaten sur $goal g';
  }

  @override
  String eatGoalNoCalorieValue(String goal) {
    return 'Aucune valeur de calories entrée pour l\'instant · objectif $goal kcal';
  }

  @override
  String eatGoalNoProteinValue(String goal) {
    return 'Aucune valeur de protéines entrée pour l\'instant · objectif $goal g';
  }

  @override
  String eatGoalKnownSoFar(String progress) {
    return '$progress · connu jusqu\'ici';
  }

  @override
  String eatGoalOverKcal(String progress, String diff) {
    return '$progress · $diff kcal de plus';
  }

  @override
  String eatGoalLeftKcal(String progress, String diff) {
    return '$progress · $diff kcal restantes';
  }

  @override
  String eatGoalOverGrams(String progress, String diff) {
    return '$progress · $diff g de plus';
  }

  @override
  String eatGoalLeftGrams(String progress, String diff) {
    return '$progress · $diff g restants';
  }

  @override
  String get eatNoFoodLoggedYet => 'Aucun aliment consigné pour l\'instant';

  @override
  String get eatTotals => 'Totaux';

  @override
  String get eatKnownTotals => 'Totaux connus';

  @override
  String get eatNoNutritionForFood =>
      'Aucune valeur nutritive entrée pour ces aliments';

  @override
  String get eatNutritionOverline => 'Nutrition';

  @override
  String get eatNothingRecorded =>
      'Rien n\'est consigné pour ce jour. Ce n\'est pas la même chose que n\'avoir rien mangé.';

  @override
  String eatYourDailyGoal(String goals) {
    return 'Ton objectif quotidien : $goals';
  }

  @override
  String eatNutrientSaid(String nutrient, String value) {
    return '$nutrient $value';
  }

  @override
  String eatNutrientUnknownSaid(String nutrient) {
    return '$nutrient inconnu';
  }

  @override
  String get eatPartialNote =>
      'Certains aliments n\'ont pas de valeur pour un nutriment : ce sont donc des sommes de ce que tu as entré, pas des totaux complets.';

  @override
  String get eatSyncPending =>
      'Enregistré sur ce téléphone · synchronisation en attente';

  @override
  String get eatKnown => 'connu';

  @override
  String get eatKnownSoFar => 'connu jusqu\'ici';

  @override
  String eatSaidKcal(String nutrient, String value) {
    return '$nutrient $value kilocalories';
  }

  @override
  String eatSaidGrams(String nutrient, String value) {
    return '$nutrient $value grammes';
  }

  @override
  String eatSaidKnownFrom(int known, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      known,
      locale: localeName,
      other: 'connu de $known aliments sur $total',
      one: 'connu de 1 aliment sur $total',
      zero: 'connu de 0 aliment sur $total',
    );
    return '$_temp0';
  }

  @override
  String eatSaidGoalKcal(String goal) {
    return 'objectif $goal kilocalories';
  }

  @override
  String eatSaidGoalGrams(String goal) {
    return 'objectif $goal grammes';
  }

  @override
  String get eatListSeparator => ', ';

  @override
  String get eatCaloriesGoalBar => 'Objectif de calories';

  @override
  String get eatProteinGoalBar => 'Objectif de protéines';

  @override
  String get eatOpensJournalHint => 'Ouvre le journal alimentaire';

  @override
  String get eatSomeValuesMissing => 'Certaines valeurs nutritives manquent';

  @override
  String get eatNoValuesYet => 'Aucune valeur nutritive entrée pour l\'instant';

  @override
  String get foodProblemNoName => 'Entre ce que tu as mangé.';

  @override
  String get foodProblemNoAmount => 'Entre la quantité, dans tes mots.';

  @override
  String get foodProblemTooLong => 'Ce texte est trop long.';

  @override
  String get foodProblemNoMeal => 'Choisis un repas.';

  @override
  String get foodProblemNoQuantity =>
      'Entre la quantité consommée, un nombre supérieur à zéro.';

  @override
  String get foodProblemBadValues =>
      'Les valeurs nutritives doivent être de zéro ou plus.';

  @override
  String foodProblemBadValue(String nutrient) {
    return '$nutrient : entre un nombre de zéro ou plus, ou laisse vide.';
  }

  @override
  String get foodProblemBadSavedName =>
      'Donne à l\'aliment un nom de 120 caractères au plus.';

  @override
  String get foodSaveFailedLocal =>
      'Impossible d\'enregistrer sur ton téléphone. Ton entrée est toujours là. Réessaie.';

  @override
  String get foodSavedToMine =>
      'Enregistré dans Mes aliments. Rien n\'a été consigné.';

  @override
  String foodRemoveTitle(String name) {
    return 'Supprimer $name?';
  }

  @override
  String foodRemoveBody(String name, String amount, String meal, String date) {
    return 'Seul « $name » ($amount) sera supprimé ($meal, $date). Tes autres aliments restent.';
  }

  @override
  String get foodRemoveAction => 'Supprimer cet aliment';

  @override
  String get foodDetailsTitle => 'Détails de l\'aliment';

  @override
  String get foodEditTitle => 'Modifier l\'aliment';

  @override
  String get foodNewTitle => 'Nouvel aliment';

  @override
  String get foodYourValue => 'Ta valeur';

  @override
  String get foodWhatDidYouEat => 'Qu\'as-tu mangé?';

  @override
  String get foodNameInJournal => 'Nom dans ton journal';

  @override
  String get foodMealLabel => 'Repas';

  @override
  String foodForDateTapToChange(String date) {
    return 'Pour le $date. Touche pour changer la date.';
  }

  @override
  String get foodHelpPortions => 'Aide sur les quantités et les portions';

  @override
  String get foodFavouriteRemove => 'Retirer des favoris';

  @override
  String get foodFavouriteAdd => 'Ajouter aux favoris';

  @override
  String get foodSaveChanges => 'Enregistrer les modifications';

  @override
  String get foodLogButton => 'Consigner l\'aliment';

  @override
  String get foodCancelKeep => 'Annuler et garder la version consignée';

  @override
  String get foodAmountLabel => 'Quantité';

  @override
  String get foodPortionLabel => 'Portion';

  @override
  String get foodAddPortion => 'Ajouter ta propre portion';

  @override
  String get foodPortionCoach =>
      'Tu peux compter des portions ici. Le poids est affiché quand une conversion fiable existe.';

  @override
  String get foodHowMuch => 'Quelle quantité?';

  @override
  String get foodHowMuchHelper =>
      'Dans tes mots, par exemple « 200 g » ou « 2 tranches »';

  @override
  String get foodNutritionHeading => 'Valeurs nutritives';

  @override
  String foodNutritionFor(String amount) {
    return 'Valeurs nutritives pour $amount';
  }

  @override
  String get foodNutritionOptional =>
      'Facultatif. Touche une valeur pour l\'entrer; un champ vide reste inconnu et n\'est jamais compté comme zéro.';

  @override
  String get foodNutritionFromSource =>
      'Selon la source, pour cette quantité. Touche une valeur pour la corriger; un champ vide reste inconnu et n\'est jamais compté comme zéro.';

  @override
  String foodSourceMissing(int count, String nutrients) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cette source ne donne aucune valeur pour : $nutrients. Elles restent inconnues à moins que tu les entres.',
      one:
          'Cette source ne donne aucune valeur pour : $nutrients. Elle reste inconnue à moins que tu l\'entres.',
    );
    return '$_temp0';
  }

  @override
  String get foodUseSourceValues => 'Reprendre les valeurs de la source';

  @override
  String get foodSaveToMine => 'Enregistrer dans Mes aliments sans consigner';

  @override
  String get foodShowsDetailsHint => 'Affiche les détails de l\'aliment';

  @override
  String foodSource(String credit) {
    return 'Source : $credit';
  }

  @override
  String get foodYourOwn => 'Ton propre aliment';

  @override
  String foodBarcode(String code) {
    return 'Code-barres $code';
  }

  @override
  String get foodYoureLogging => 'Tu consignes';

  @override
  String get foodEnergy => 'Énergie';

  @override
  String get foodUnknownSaid => 'inconnu';

  @override
  String foodKcalSaid(String value) {
    return '$value kilocalories';
  }

  @override
  String foodGramsSaid(String value) {
    return '$value grammes';
  }

  @override
  String get foodPortionNameInvalid =>
      'Nomme une portion en un ou deux mots, comme « tranche » ou « petit bol ».';

  @override
  String foodPortionExists(String name) {
    return 'Cet aliment a déjà une portion appelée « $name ».';
  }

  @override
  String foodPortionAmountInvalid(String name) {
    return 'Entre la quantité d\'une portion « $name », un nombre supérieur à zéro.';
  }

  @override
  String foodPortionFor(String food) {
    return 'Pour $food seulement. Ses valeurs nutritives ne changent pas, et rien n\'est consigné.';
  }

  @override
  String get foodPortionCalled => 'Une portion s\'appelle';

  @override
  String get foodPortionHint => 'tranche';

  @override
  String get foodPortionHowMuch => 'Combien en vaut une?';

  @override
  String get foodAddPortionButton => 'Ajouter la portion';

  @override
  String foodNutritionBasis(String basis) {
    return 'Valeurs nutritives $basis';
  }

  @override
  String foodBarcodeNotFound(String code) {
    return 'Aucun produit trouvé pour le code-barres $code. Tu peux le chercher par nom ou créer ton propre aliment.';
  }

  @override
  String foodBarcodeOffline(String code) {
    return 'Le code-barres $code n\'a pas pu être recherché pour l\'instant, et il ne l\'a jamais été sur ce téléphone. La cause peut être la connexion du téléphone ou le serveur. Tu peux créer ton propre aliment.';
  }

  @override
  String foodBarcodeTimeout(String code) {
    return 'La base de produits a mis trop de temps à répondre pour le code-barres $code. Réessaie ou crée ton propre aliment.';
  }

  @override
  String get foodBarcodeRateLimited =>
      'La base de produits a reçu trop de demandes pour l\'instant. Réessaie dans quelques minutes ou crée ton propre aliment.';

  @override
  String get foodBarcodeInvalid => 'Ce n\'est pas un code-barres de produit.';

  @override
  String get foodBarcodeUnavailable =>
      'La base de produits ne répond pas pour l\'instant. Réessaie ou crée ton propre aliment.';

  @override
  String foodBarcodeLookingUp(String code) {
    return 'Recherche du code-barres $code…';
  }

  @override
  String get foodSearchStillLocal =>
      'Les aliments ci-dessus viennent de ce téléphone et fonctionnent toujours.';

  @override
  String get foodSearchStillScan =>
      'Tu peux quand même scanner un code-barres ou créer ton propre aliment.';

  @override
  String get foodSearchOffline =>
      'La base d\'aliments élargie est injoignable pour l\'instant. La cause peut être la connexion du téléphone ou le serveur.';

  @override
  String get foodSearchTimeout =>
      'La base d\'aliments élargie a mis trop de temps à répondre.';

  @override
  String get foodSearchRateLimited =>
      'La base d\'aliments élargie a reçu trop de demandes pour l\'instant. Réessaie dans quelques minutes.';

  @override
  String get foodSearchNotConfigured =>
      'La recherche élargie n\'est pas configurée sur ce serveur. Les aliments courants, tes aliments et les codes-barres fonctionnent toujours.';

  @override
  String get foodSearchInvalid =>
      'Cette recherche n\'a pas pu être utilisée. Essaie d\'autres mots.';

  @override
  String get foodSearchUnavailable =>
      'La base d\'aliments élargie ne répond pas pour l\'instant. Réessaie dans un moment.';

  @override
  String get foodSearchGuide =>
      'Tape un aliment, comme « œuf » ou « riz », ou choisis une catégorie. Les aliments courants et les tiens sont trouvés sans connexion.';

  @override
  String get foodGroupYours => 'Tes aliments';

  @override
  String get foodGroupCommon => 'Aliments courants';

  @override
  String get foodGroupMore => 'Plus d\'aliments';

  @override
  String foodCategoryEmpty(String category) {
    return 'Aucun aliment courant n\'est classé dans $category.';
  }

  @override
  String foodCategoryNoMatch(String category, String query) {
    return 'Aucun aliment courant de $category ne correspond à « $query ».';
  }

  @override
  String get foodCategoryNote =>
      'Seuls les aliments courants ont une catégorie. Choisis Tout pour inclure tes aliments et la base élargie.';

  @override
  String get foodSearchBusy => 'Recherche d\'autres aliments…';

  @override
  String foodSearchLocalEmpty(String query) {
    return 'Rien sur ce téléphone ne correspond à « $query ».';
  }

  @override
  String get foodSearchMore => 'Chercher plus d\'aliments';

  @override
  String foodSearchMoreSubtitle(String query) {
    return 'Chercher « $query » dans USDA FoodData Central';
  }

  @override
  String foodSearchNoOthers(String query) {
    return 'La base élargie n\'a pas d\'autres aliments pour « $query ».';
  }

  @override
  String foodSearchNoneFound(String query) {
    return 'Aucun aliment trouvé pour « $query ». Essaie d\'autres mots, scanne le code-barres ou crée ton propre aliment.';
  }

  @override
  String foodSearchNoneNonEnglish(String query) {
    return 'La base élargie cherche en anglais et n\'a rien trouvé pour « $query ». Essaie le nom anglais, scanne le code-barres ou entre-le toi-même.';
  }

  @override
  String get foodSearchCredit =>
      'De USDA FoodData Central, en anglais, surtout des aliments vendus ou consommés aux États-Unis. Les valeurs sont telles que publiées et peuvent différer de ton emballage.';

  @override
  String get foodRecentEmptyTitle => 'Rien de consigné pour l\'instant';

  @override
  String get foodRecentEmptyBody =>
      'Les aliments que tu consignes s\'affichent ici, prêts à être consignés de nouveau.';

  @override
  String get foodFavouritesEmptyTitle => 'Aucun favori pour l\'instant';

  @override
  String get foodFavouritesEmptyBody =>
      'Marque un aliment avec l\'étoile sur sa page de quantité pour le garder ici.';

  @override
  String get foodMineEmptyTitle => 'Aucun aliment à toi pour l\'instant';

  @override
  String get foodMineEmptyBody =>
      'Crée ton propre aliment ci-dessous, ou utilise « Enregistrer dans Mes aliments » sur la page de quantité d\'un aliment.';

  @override
  String foodListNoMatch(String query) {
    return 'Rien dans cette liste ne correspond à « $query ».';
  }

  @override
  String get foodAddTitle => 'Ajouter un aliment';

  @override
  String get foodHelpSearch => 'Aide pour trouver un aliment';

  @override
  String get foodSearchHint => 'Chercher des aliments';

  @override
  String get foodSearchClear => 'Effacer la recherche';

  @override
  String get foodScanBarcode => 'Scanner un code-barres';

  @override
  String get foodScopeSearch => 'Recherche';

  @override
  String get foodScopeRecent => 'Récents';

  @override
  String get foodScopeFavourites => 'Favoris';

  @override
  String get foodScopeMine => 'Mes aliments';

  @override
  String get foodSearchCoach =>
      'Cherche un aliment, scanne un code-barres ou entre le tien. Récents, Favoris et Mes aliments sont à portée de main.';

  @override
  String get foodManualTitle => 'L\'entrer toi-même';

  @override
  String get foodManualSubtitle => 'Introuvable? Crée ton propre aliment';

  @override
  String get foodFooter =>
      'Choisis un aliment pour vérifier la quantité avant de consigner.';

  @override
  String get foodCredits =>
      'Aliments courants et recherche élargie : USDA FoodData Central. Codes-barres : Open Food Facts (Open Database License).';

  @override
  String get foodChangeMeal => 'Changer de repas';

  @override
  String get foodRowProteinUnknown => '— protéines';

  @override
  String get foodChooseHint => 'Choisir cet aliment';

  @override
  String get barcodeTypedInvalid =>
      'Un code-barres compte de 6 à 14 chiffres, tels qu\'imprimés sous les barres.';

  @override
  String get barcodeTitle => 'Scanner un code-barres';

  @override
  String get barcodeHold =>
      'Place le code-barres de l\'emballage dans le cadre.';

  @override
  String get barcodeLookUp => 'Rechercher ce code-barres';

  @override
  String get barcodeCameraRefused =>
      'GoHard n\'a pas accès à la caméra, il ne peut donc pas scanner. Tu peux l\'autoriser dans les réglages du téléphone ou taper le code-barres ci-dessous.';

  @override
  String get barcodeCameraUnavailable =>
      'La caméra ne peut pas être utilisée sur ce téléphone pour l\'instant. Tu peux taper le code-barres ci-dessous.';

  @override
  String get barcodeOrType => 'Ou tape le code-barres';

  @override
  String get barcodeDigitsLabel => 'Chiffres du code-barres';

  @override
  String get barcodeCameraStarting => 'Démarrage de la caméra';

  @override
  String get barcodeTorchOff => 'Éteindre la lampe';

  @override
  String get barcodeTorchOn => 'Allumer la lampe';

  @override
  String get eatHelpTitle => 'Ton journal alimentaire';

  @override
  String get eatHelpBody =>
      'Ajoute un aliment sous un repas : cherche, scanne un code-barres ou entre le tien. Les totaux additionnent seulement ce que tu as consigné. Tes objectifs quotidiens se fixent à partir du résumé ici, dans Aujourd\'hui ou dans Profil. Les aliments que tu manges souvent sont gardés dans Ajouter un aliment : Favoris sont les aliments marqués d\'une étoile sur leur page de quantité; Mes aliments sont ceux que tu as écrits ou corrigés toi-même. En choisir un ouvre seulement sa quantité : rien n\'est consigné avant ta confirmation.';

  @override
  String get eatOpenFavourites => 'Ouvrir Favoris';

  @override
  String get eatOpenMine => 'Ouvrir Mes aliments';

  @override
  String get eatHintHistory =>
      'Tes repas et ton eau passés, par jour, semaine et mois, sont dans Historique et tendances.';

  @override
  String get eatHintSavedNew =>
      'Tu manges souvent les mêmes aliments? Touche l\'étoile sur la page de quantité d\'un aliment et il t\'attend dans Favoris, sous Ajouter un aliment.';

  @override
  String get eatHintFavourites =>
      'Tes aliments favoris sont à portée de main. Choisis-en un, vérifie la quantité, puis consigne-le.';

  @override
  String get eatHintMine =>
      'Les aliments que tu as gardés sont dans Mes aliments. Choisis-en un, vérifie la quantité, puis consigne-le.';

  @override
  String get eatSayGoalWater =>
      'Consigne un repas ou de l\'eau et vois où en est ta journée par rapport à tes objectifs.';

  @override
  String get eatSayGoal =>
      'Consigne un repas et vois où en est ta journée par rapport à tes objectifs.';

  @override
  String get eatSayNoGoalWater =>
      'Consigne un repas ou de l\'eau, ou fixe tes objectifs quotidiens.';

  @override
  String get eatSayNoGoal =>
      'Consigne un repas, ou fixe tes objectifs quotidiens.';

  @override
  String eatMacroProtein(String value) {
    return 'P $value g';
  }

  @override
  String eatMacroCarbs(String value) {
    return 'G $value g';
  }

  @override
  String eatMacroFat(String value) {
    return 'L $value g';
  }

  @override
  String get eatNoNutritionEntered => 'Aucune valeur nutritive entrée';

  @override
  String get eatNeedsReview => 'à vérifier';

  @override
  String get eatSyncPendingShort => 'synchronisation en attente';

  @override
  String get eatCaloriesUnknown => 'Calories inconnues';

  @override
  String eatKcalKnown(String value) {
    return '$value kcal connues';
  }

  @override
  String get eatHelpLabel => 'Aide sur ton journal alimentaire';

  @override
  String eatHelpFrom(String coach) {
    return 'Aide sur ton journal alimentaire, par $coach';
  }

  @override
  String get eatPreviousDay => 'Jour précédent';

  @override
  String get eatNextDay => 'Jour suivant';

  @override
  String get eatHistoryTrends => 'Historique et tendances';

  @override
  String get eatBackToToday => 'Revenir à aujourd\'hui';

  @override
  String get eatJournalReadError =>
      'Ton journal alimentaire n\'a pas pu être lu sur ce téléphone. Tire vers le bas pour réessayer.';

  @override
  String get eatJournalLoading => 'Chargement de ton journal…';

  @override
  String get eatTodaysMeals => 'Repas d\'aujourd\'hui';

  @override
  String get eatMeals => 'Repas';

  @override
  String eatAddFoodToMeal(String meal) {
    String _temp0 = intl.Intl.selectLogic(meal, {
      'Breakfast': 'Ajouter un aliment au déjeuner',
      'Lunch': 'Ajouter un aliment au dîner',
      'Dinner': 'Ajouter un aliment au souper',
      'Snack': 'Ajouter une collation',
      'other': 'Ajouter un aliment',
    });
    return '$_temp0';
  }

  @override
  String get eatAddFood => 'Ajouter un aliment';

  @override
  String get eatOnlyLoggedNote =>
      'Seuls les aliments que tu as consignés comme mangés apparaissent ici.';

  @override
  String trendsFoodCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aliments',
      one: '$count aliment',
    );
    return '$_temp0';
  }

  @override
  String get trendsFuture => 'À venir';

  @override
  String get trendsNoFoodLogged => 'Aucun aliment consigné';

  @override
  String trendsDayUnknown(String metric, String foods) {
    return '$metric non entrées · $foods consignés';
  }

  @override
  String trendsDayPartial(
    String amount,
    int unknown,
    String foods,
    String noun,
  ) {
    return '$amount connus · $unknown sur $foods sans valeur de $noun';
  }

  @override
  String trendsDayZero(String amount) {
    return '$amount consigné';
  }

  @override
  String get trendsNounCalorie => 'calories';

  @override
  String get trendsNounProtein => 'protéines';

  @override
  String get trendsNounCarb => 'glucides';

  @override
  String get trendsNounFat => 'lipides';

  @override
  String get trendsNounWater => 'eau';

  @override
  String get trendsHelpBody =>
      'Chaque barre est le total consigné d\'une journée. Touche ou glisse sur le graphique pour choisir un jour, puis Voir le jour ouvre ses repas et son eau. Un tiret veut dire que rien n\'a été consigné ce jour-là; un point d\'interrogation, que des aliments ont été consignés sans cette valeur; une étoile, que certains aliments n\'ont pas de valeur, donc la somme est ce qui est connu. Les moyennes utilisent seulement les jours avec une valeur connue.';

  @override
  String get trendsHelpLabel => 'Aide sur Historique et tendances';

  @override
  String get trendsCoachSay =>
      'Touche un jour pour voir ce que tu as consigné.';

  @override
  String get trendsWeek => 'Semaine';

  @override
  String get trendsMonth => 'Mois';

  @override
  String get trendsChooseDay => 'Choisis un jour';

  @override
  String get trendsWaterReadError =>
      'Ton eau n\'a pas pu être lue sur ce téléphone.';

  @override
  String get trendsFoodReadError =>
      'Ton journal alimentaire n\'a pas pu être lu sur ce téléphone.';

  @override
  String get trendsReading => 'Lecture de ton journal sur ce téléphone…';

  @override
  String trendsByDay(String metric) {
    return '$metric par jour';
  }

  @override
  String get trendsLegendNotLogged => 'Non consigné';

  @override
  String get trendsLegendNotEntered => 'Non entré';

  @override
  String get trendsLegendPartial => 'Certaines valeurs manquent';

  @override
  String get trendsLegendZero => 'Zéro consigné';

  @override
  String get trendsDaysInPeriod => 'Jours de cette période';

  @override
  String get trendsCalendar => 'Calendrier';

  @override
  String get trendsCalendarSaid =>
      'Calendrier et tous les jours avec des entrées';

  @override
  String get trendsFoodErrorWaterShown =>
      'Les aliments n\'ont pas pu être lus sur ce téléphone; l\'eau est affichée.';

  @override
  String get trendsWaterErrorFoodShown =>
      'L\'eau n\'a pas pu être lue sur ce téléphone; les aliments sont affichés.';

  @override
  String trendsFoodsLogged(String foods) {
    return '$foods consignés';
  }

  @override
  String get trendsFootnote =>
      'Les totaux additionnent seulement ce qui a été consigné. Un jour sans rien de consigné, ou un aliment sans valeur, n\'est jamais compté comme zéro. Les objectifs ne sont pas affichés ici : ceux des jours passés n\'ont pas été gardés.';

  @override
  String trendsWeekSoFar(String range) {
    return 'Cette semaine jusqu\'ici · $range';
  }

  @override
  String trendsMonthToDate(String range) {
    return 'Mois en cours · $range';
  }

  @override
  String get trendsPreviousWeek => 'Semaine précédente';

  @override
  String get trendsPreviousMonth => 'Mois précédent';

  @override
  String get trendsNextWeek => 'Semaine suivante';

  @override
  String get trendsNextMonth => 'Mois suivant';

  @override
  String trendsPeriodSaid(String period) {
    return 'Choisis un jour. Affichage : $period';
  }

  @override
  String trendsPeriodSaidSub(String period, String sub) {
    return 'Choisis un jour. Affichage : $period, $sub';
  }

  @override
  String get trendsThisWeek => 'Cette semaine';

  @override
  String get trendsThisMonth => 'Ce mois-ci';

  @override
  String trendsKnownLogged(String metric) {
    return '$metric connues consignées';
  }

  @override
  String trendsLogged(String metric) {
    return '$metric consignées';
  }

  @override
  String trendsNoValues(String noun) {
    return 'Aucune valeur de $noun';
  }

  @override
  String trendsCoverage(int known, int elapsed, String noun) {
    return '$known sur $elapsed jours avec des valeurs de $noun';
  }

  @override
  String trendsCoverageSoFar(int known, int elapsed, String noun) {
    return '$known sur $elapsed jours avec des valeurs de $noun jusqu\'ici';
  }

  @override
  String trendsCoverageWater(int known, int elapsed) {
    return '$known sur $elapsed jours avec de l\'eau consignée';
  }

  @override
  String trendsCoverageWaterSoFar(int known, int elapsed) {
    return '$known sur $elapsed jours avec de l\'eau consignée jusqu\'ici';
  }

  @override
  String trendsDaysWithFood(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours avec des aliments consignés',
      one: '$count jour avec des aliments consignés',
    );
    return '$_temp0';
  }

  @override
  String trendsDaysWithoutValue(int count, String noun) {
    return '$count sans aucune valeur de $noun';
  }

  @override
  String get trendsAverageKnown => 'Moyenne quotidienne, valeurs connues';

  @override
  String get trendsAverage => 'Moyenne quotidienne';

  @override
  String trendsAcross(int count, String noun) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sur les $count jours avec des valeurs de $noun',
      one: 'Sur $count jour avec des valeurs de $noun',
    );
    return '$_temp0';
  }

  @override
  String trendsAcrossWater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sur les $count jours avec de l\'eau consignée',
      one: 'Sur $count jour avec de l\'eau consignée',
    );
    return '$_temp0';
  }

  @override
  String trendsPartialNote(int count, String noun) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Inclut $count jours où certains aliments n\'ont pas de valeur de $noun : seule la partie connue est additionnée.',
      one:
          'Inclut $count jour où certains aliments n\'ont pas de valeur de $noun : seule la partie connue est additionnée.',
    );
    return '$_temp0';
  }

  @override
  String get trendsViewDay => 'Voir le jour';

  @override
  String trendsViewDaySaid(String date) {
    return 'Voir le $date';
  }

  @override
  String trendsChartSaid(String metric, String period, int known, int elapsed) {
    return '$metric par jour, $period : $known sur $elapsed jours avec une valeur. Chaque jour figure dans la liste ci-dessous.';
  }

  @override
  String get trendsCaloriesUnknownLower => 'calories inconnues';

  @override
  String get trendsCalendarSubtitle => 'Tes repas et ton eau, par jour';

  @override
  String get trendsCalendarCaption =>
      'Choisis un jour pour voir ce qui a été consigné.';

  @override
  String get trendsDaysWithEntries => 'Jours avec des entrées';

  @override
  String get trendsNothingYetBody =>
      'Les jours où tu consignes des aliments ou de l\'eau s\'affichent ici.';

  @override
  String get accountErrorInvalidCredentials =>
      'Ce courriel et ce mot de passe ne correspondent à aucun compte.';

  @override
  String get accountErrorEmailInUse =>
      'Un compte existe déjà avec ce courriel. Connecte-toi plutôt.';

  @override
  String get accountErrorWeakPassword =>
      'Utilise un mot de passe d\'au moins 15 caractères.';

  @override
  String get accountErrorInvalidEmail => 'Entre une adresse courriel valide.';

  @override
  String get accountErrorInvalidDisplayName =>
      'Entre le nom que tu veux voir dans l\'application.';

  @override
  String get accountErrorWrongPassword =>
      'Ce mot de passe est incorrect. Ton compte n\'a pas été supprimé.';

  @override
  String get accountErrorTooManyAttempts =>
      'Trop de tentatives. Attends une minute et réessaie.';

  @override
  String get accountErrorUnreachable =>
      'Le serveur est injoignable. Vérifie ta connexion et réessaie; rien de ce que tu as saisi n\'a été perdu.';

  @override
  String get accountErrorUnreachableDelete =>
      'Le serveur est injoignable, donc rien n\'a été supprimé. La suppression du compte nécessite une connexion.';

  @override
  String get accountErrorNameLength => 'Entre un nom de 1 à 80 caractères.';

  @override
  String get accountErrorCalorieGoal =>
      'Un objectif de calories est un nombre entier de 500 à 10 000, ou laissé vide.';

  @override
  String get accountErrorProteinGoal =>
      'Un objectif de protéines est un nombre entier de 10 à 500 grammes, ou laissé vide.';

  @override
  String get accountErrorWaterGoal =>
      'Un objectif d\'eau va de 100 mL à 10 L (environ 3,4 à 338 oz liq.), ou est laissé vide.';

  @override
  String get reminderNotificationTitle => 'Séance aujourd\'hui';

  @override
  String get reminderChannelName => 'Rappels de séance';

  @override
  String get reminderChannelDescription =>
      'Un rappel les jours où une séance est prévue';

  @override
  String get permissionAllowed => 'Autorisé';

  @override
  String get permissionNotAllowed => 'Non autorisé';

  @override
  String get permissionNotAskedOrNotAllowed =>
      'Pas encore demandé, ou non autorisé';

  @override
  String get permissionUnknown => 'Inconnu';

  @override
  String get permissionsSubtitle =>
      'Gérées par le téléphone, pas par les réglages de GoHard.';

  @override
  String get permissionLocation => 'Localisation';

  @override
  String get permissionLocationExplanation =>
      'Approximative, quand l\'application est ouverte : météo automatique dans Aujourd\'hui et courses GPS. Demandée quand tu utilises l\'une d\'elles.';

  @override
  String get permissionCamera => 'Appareil photo';

  @override
  String get permissionCameraExplanation =>
      'Lecture de codes-barres seulement. Demandé à ta première lecture; le lecteur l\'indique s\'il n\'est pas autorisé.';

  @override
  String get permissionNotifications => 'Notifications';

  @override
  String get permissionNotificationsExplanation =>
      'Rappels de séance seulement. Demandées quand tu les actives dans Profil.';

  @override
  String get permissionsFootnote =>
      'GoHard demande chacune seulement quand tu utilises la fonction qui en a besoin. Pour autoriser ou arrêter ce que tu as refusé ou autorisé plus tôt, utilise les Réglages du téléphone. Les préférences de l\'application comme Unités, Apparence et Fond d\'Aujourd\'hui sont dans Profil.';

  @override
  String get permissionsOpenSettings => 'Ouvrir les Réglages du téléphone';

  @override
  String get syncRemoved => 'Retiré';

  @override
  String syncFoodLine(String name, String amount, String meal, String date) {
    String _temp0 = intl.Intl.selectLogic(meal, {
      'breakfast': 'déjeuner',
      'lunch': 'dîner',
      'dinner': 'souper',
      'snack': 'collation',
      'other': '$meal',
    });
    return '$name · $amount · $_temp0 · $date';
  }

  @override
  String syncFoodLineCalories(
    String name,
    String amount,
    String meal,
    String date,
    String calories,
  ) {
    String _temp0 = intl.Intl.selectLogic(meal, {
      'breakfast': 'déjeuner',
      'lunch': 'dîner',
      'dinner': 'souper',
      'snack': 'collation',
      'other': '$meal',
    });
    return '$name · $amount · $_temp0 · $date · $calories kcal';
  }

  @override
  String syncWorkoutInProgress(String title, String date) {
    return '$title · $date · en cours';
  }

  @override
  String syncWorkoutFinished(String title, String date, String outcome) {
    String _temp0 = intl.Intl.selectLogic(outcome, {
      'full': 'complète',
      'partial': 'partielle',
      'other': '$outcome',
    });
    return '$title · $date · terminée ($_temp0)';
  }

  @override
  String get syncNoPrimaryPlan => 'Aucun programme principal';

  @override
  String get syncPrimaryPlanSet => 'Un programme principal est défini';

  @override
  String syncPlanLine(String title, String lifecycle) {
    String _temp0 = intl.Intl.selectLogic(lifecycle, {
      'draft': 'brouillon',
      'active': 'actif',
      'paused': 'en pause',
      'closed': 'terminé',
      'other': '$lifecycle',
    });
    return '$title · $_temp0';
  }

  @override
  String syncProfileLine(String name, String appearance, String unit) {
    String _temp0 = intl.Intl.selectLogic(appearance, {
      'light': 'clair',
      'dark': 'sombre',
      'system': 'système',
      'other': '$appearance',
    });
    return '$name · $_temp0 · $unit';
  }

  @override
  String syncGoalCalories(String value) {
    return 'objectif $value kcal';
  }

  @override
  String syncGoalProtein(String value) {
    return 'objectif $value g de protéines';
  }

  @override
  String syncGoalWater(String value) {
    return 'objectif $value mL d\'eau';
  }

  @override
  String get syncFoodFallback => 'Aliment';

  @override
  String get syncFavourite => 'favori';

  @override
  String syncRunLine(String date) {
    return 'Course · $date';
  }

  @override
  String syncWaterLine(String amount, String date) {
    return 'Eau · $amount · $date';
  }

  @override
  String syncWeeklyGoalsLine(String date, String workouts, String runs) {
    return 'Objectifs de la semaine du $date : $workouts · $runs';
  }

  @override
  String get syncNoWorkoutTarget => 'aucun objectif de séances';

  @override
  String syncWorkoutsTarget(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances',
      one: '1 séance',
      zero: '0 séance',
    );
    return '$_temp0';
  }

  @override
  String get syncNoRunWalkTarget => 'aucun objectif Course / Marche';

  @override
  String syncRunWalkTarget(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses ou marches',
      one: '1 course ou marche',
      zero: '0 course ou marche',
    );
    return '$_temp0';
  }

  @override
  String get syncNoIncrement => 'Aucun incrément de charge';

  @override
  String syncIncrement(String load) {
    return 'Incrément de charge $load';
  }

  @override
  String get syncKindSet => 'Série enregistrée';

  @override
  String get syncKindFood => 'Entrée d\'aliment';

  @override
  String get syncKindWorkout => 'Séance';

  @override
  String get syncKindContext => 'Changement de programme principal';

  @override
  String get syncKindPlan => 'Changement de programme';

  @override
  String get syncKindProfile => 'Profil';

  @override
  String get syncKindRun => 'Course';

  @override
  String get syncKindMetric => 'Mesure corporelle';

  @override
  String get syncKindProposal => 'Changement suggéré';

  @override
  String get syncKindSavedFood => 'Aliment enregistré';

  @override
  String get syncKindWater => 'Entrée d\'eau';

  @override
  String get syncKindWeeklyGoal => 'Objectifs de la semaine';

  @override
  String get syncKindIncrement => 'Incrément de charge';

  @override
  String get syncReasonRevisionConflict =>
      'Il a aussi été modifié ailleurs, donc les deux versions diffèrent.';

  @override
  String get syncReasonDeleted =>
      'Il a été retiré ailleurs après que tu l\'as modifié ici.';

  @override
  String get syncReasonOccasionNotEligible =>
      'Cette séance prévue a déjà été commencée, enregistrée ou sautée ailleurs.';

  @override
  String get syncReasonAlreadyFinished =>
      'Cette séance a déjà été terminée ailleurs.';

  @override
  String get syncReasonSetMismatch =>
      'Les séries de ton compte diffèrent de celles de ce téléphone.';

  @override
  String get syncReasonPlansChanged =>
      'Tes programmes ont changé ailleurs avant que ceci atteigne ton compte.';

  @override
  String get syncReasonNotFound => 'Il n\'existe plus dans ton compte.';

  @override
  String syncReasonOther(String code) {
    return 'Ton compte ne l\'a pas accepté ($code).';
  }

  @override
  String get syncReasonUnknownCode => 'raison inconnue';

  @override
  String get syncReviewTitle => 'Réviser les changements enregistrés';

  @override
  String get syncReviewIntro =>
      'Tout ce qui suit est enregistré sur ce téléphone. Chaque élément diffère de ton compte ou n\'a pas été accepté; il attend ta décision.';

  @override
  String get syncReviewEmptyTitle => 'Rien à réviser';

  @override
  String get syncReviewEmptyBody =>
      'Tous tes changements sont synchronisés ou en attente de synchronisation normale.';

  @override
  String get syncOnThisPhone => 'Sur ce téléphone';

  @override
  String get syncInYourAccount => 'Dans ton compte';

  @override
  String get syncKeepLocal => 'Garder la version de ce téléphone';

  @override
  String get syncKeptLocal =>
      'Ta version est gardée. Celle du compte est conservée comme autre version.';

  @override
  String get syncKeepManual => 'La garder comme séance manuelle';

  @override
  String get syncKeptManual =>
      'Gardée comme entraînement manuel. Chaque série enregistrée est conservée.';

  @override
  String get syncUseServer => 'Utiliser la version du compte';

  @override
  String get syncUsingServer =>
      'La version du compte est utilisée. Ta version est conservée comme autre version.';

  @override
  String get syncRemoveFromPhone => 'Le retirer de ce téléphone';

  @override
  String get syncDropChange => 'Abandonner mon changement';

  @override
  String get syncRemoveConfirmTitle => 'Le retirer de ce téléphone?';

  @override
  String get syncRemoveConfirmBody =>
      'Ton compte ne l\'a jamais accepté; le retirer ici le retire complètement.';

  @override
  String get syncRemoveConfirmBodyWorkout =>
      'Ton compte ne l\'a jamais acceptée; la retirer ici la retire complètement, y compris ses séries enregistrées.';

  @override
  String get syncDropConfirmTitle => 'Abandonner ce changement?';

  @override
  String get syncDropConfirmBody =>
      'La version de ton compte sera affichée de nouveau.';

  @override
  String get syncDiscardDone => 'C\'est fait.';

  @override
  String get meRemindersNotAllowed =>
      'Les notifications ne sont pas autorisées pour GoHard, donc les rappels restent désactivés. Tu peux les autoriser dans les réglages du téléphone.';

  @override
  String get mePrefNotSaved =>
      'Cette préférence n\'a pas pu être enregistrée sur ce téléphone.';

  @override
  String get meUnits => 'Unités';

  @override
  String get meUnitKilograms => 'Kilogrammes';

  @override
  String get meUnitPounds => 'Livres';

  @override
  String get meUnitsLoadNote =>
      'Change la façon d\'entrer et d\'afficher les charges. Ton entraînement enregistré est stocké en kilogrammes et n\'est jamais réécrit. Le temps est affiché en minutes et secondes.';

  @override
  String get meUnitBodyKg => 'Poids corporel en kilogrammes';

  @override
  String get meUnitBodyLb => 'Poids corporel en livres';

  @override
  String get meUnitBodyCm => 'Mesures en centimètres (cm)';

  @override
  String get meUnitBodyIn => 'Mesures en pouces (po)';

  @override
  String get meUnitsBodyNote =>
      'Pour Suivi corporel seulement : ton unité de charge reste la même. Stocké en kilogrammes et centimètres, donc changer ceci ne modifie jamais une mesure. Réglé sur ce téléphone pour ce compte.';

  @override
  String get meUnitsTemperature => 'Température';

  @override
  String get meUnitFahrenheit => 'Fahrenheit (°F)';

  @override
  String get meUnitCelsius => 'Celsius (°C)';

  @override
  String get meUnitsTemperatureNote =>
      'Pour la météo dans Aujourd\'hui. Réglé sur ce téléphone.';

  @override
  String get meUnitsWater => 'Eau';

  @override
  String get meUnitMillilitres => 'Millilitres (mL, L)';

  @override
  String get meUnitFluidOunces => 'Onces liquides US (oz liq.)';

  @override
  String get meUnitsWaterNote =>
      'Pour l\'eau que tu consignes. Stockée en millilitres, donc changer ceci ne modifie jamais une quantité. Les onces liquides sont un volume, pas un poids. Réglé sur ce téléphone.';

  @override
  String get meUnitsRunWalk => 'Course / Marche';

  @override
  String get meUnitKilometres => 'Kilomètres (min/km, km/h, m)';

  @override
  String get meUnitMiles => 'Milles (min/mi, mi/h, pi)';

  @override
  String get meUnitsRunWalkNote =>
      'Distance, allure, vitesse et dénivelé. Les parcours sont stockés en mètres, donc changer ceci ne modifie jamais un enregistrement. Réglé sur ce téléphone.';

  @override
  String get meSyncNeedsReview => 'À réviser';

  @override
  String meSyncNeedsReviewDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changements enregistrés sont à réviser. Rien n\'a été perdu. Touche pour réviser.',
      one: '1 changement enregistré est à réviser. Rien n\'a été perdu. Touche pour réviser.',
    );
    return '$_temp0';
  }

  @override
  String get meSyncNotSynced => 'Non synchronisé';

  @override
  String get meSyncUnreachableDetail =>
      'Synchronisation impossible pour l\'instant · touche pour réessayer';

  @override
  String meSyncUnreachableWaitingDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changements en attente de synchronisation, enregistrés sur ce téléphone.\nSynchronisation impossible pour l\'instant · touche pour réessayer',
      one: '1 changement en attente de synchronisation, enregistré sur ce téléphone.\nSynchronisation impossible pour l\'instant · touche pour réessayer',
    );
    return '$_temp0';
  }

  @override
  String get meSyncWaiting => 'En attente';

  @override
  String meSyncWaitingDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changements enregistrés sur ce téléphone, en attente de synchronisation',
      one: '1 changement enregistré sur ce téléphone, en attente de synchronisation',
    );
    return '$_temp0';
  }

  @override
  String get meSyncSaved => 'Enregistré';

  @override
  String get meSyncSavedDetail => 'Tout est enregistré dans ton compte';

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
    return '$version · commit $commit · contrat $contract\nServeur : $server';
  }

  @override
  String get meEditProfile => 'Modifier le profil';

  @override
  String get meProfileNotLoaded =>
      'Ton profil n\'est pas encore chargé sur ce téléphone.';

  @override
  String get meGroupPersonal => 'Personnel';

  @override
  String get meGroupActivity => 'Activité et suivi';

  @override
  String get meGroupPreferences => 'Préférences';

  @override
  String get meGroupAccount => 'Compte';

  @override
  String get meBodySubtitle => 'Poids, mesures et comparaisons';

  @override
  String get meGoals => 'Objectifs nutritionnels';

  @override
  String get meGoalsNoneSet => 'Aucun défini';

  @override
  String get meGoalsSet => 'Objectifs quotidiens que tu as fixés';

  @override
  String get meGoalsHelp => 'Aide sur les objectifs nutritionnels';

  @override
  String get meGoalsCoachSay =>
      'Ce sont tes cibles de suivi quotidiennes. Tu peux en laisser une vide.';

  @override
  String get meGoalsPanelTitle =>
      'Fixe tes propres cibles quotidiennes. Chacune peut rester vide.';

  @override
  String get meGoalsPanelBody =>
      'Elles se répètent chaque jour jusqu\'à ce que tu les changes. Aujourd\'hui et Nutrition montrent ta progression dès que tu en fixes une.';

  @override
  String get meSteps => 'Pas';

  @override
  String get meStepsOnSubtitle => 'Comptés avec ce téléphone';

  @override
  String get meStepsOffSubtitle =>
      'Désactivés · comptés avec ton téléphone une fois activés';

  @override
  String get meOn => 'Activé';

  @override
  String get meOff => 'Désactivé';

  @override
  String get meAppearance => 'Apparence';

  @override
  String get meAppearanceSubtitle => 'Fais de GoHard ton application.';

  @override
  String get meAppearanceHelp => 'Aide sur ces réglages';

  @override
  String get meAppearanceCoachSay =>
      'Choisis ton guide et quand j\'apparais. Mouvement et vibrations règle à quel point je bouge.';

  @override
  String get meAccentTitle => 'Couleur d\'accent';

  @override
  String get meAccentBody =>
      'Utilisée pour les boutons, les mises en évidence et les panneaux.';

  @override
  String get meAccentBlue => 'Bleu';

  @override
  String get meAccentGreen => 'Vert';

  @override
  String get meAccentPink => 'Rose';

  @override
  String meAccentSemantics(String accent) {
    return 'Accent $accent';
  }

  @override
  String get meModeTitle => 'Mode';

  @override
  String get meModeBody => 'Système suit l\'apparence de ton téléphone.';

  @override
  String get meModeLight => 'Clair';

  @override
  String get meModeDark => 'Sombre';

  @override
  String get meModeSystem => 'Système';

  @override
  String get meAppearancePreviewSemantics =>
      'Aperçu d\'Aujourd\'hui avec cette apparence';

  @override
  String get meAppearancePreview => 'Aperçu';

  @override
  String get meAppearancePreviewLine => 'Ton accent, ton mode.';

  @override
  String get meAppearancePreviewButton => 'Reprendre la séance';

  @override
  String get meCoachTitle => 'Coach';

  @override
  String get meCoachBody =>
      'Leon, un lion, ou Leona, une lionne. Le même coach dans les deux cas : seule l\'apparence change.';

  @override
  String meCoachChoiceSemantics(String name, String animal) {
    return '$name, $animal';
  }

  @override
  String get meCoachOnToday => 'Afficher le coach dans Aujourd\'hui';

  @override
  String meCoachOnTodayOn(String guide) {
    return '$guide à côté de ta salutation.';
  }

  @override
  String meCoachOnTodayOff(String guide) {
    return 'Désactivé. Demander à GoHard reste $guide, dans Entraînement.';
  }

  @override
  String get meCoachOnTabs =>
      'Afficher le coach dans Entraînement et Nutrition';

  @override
  String meCoachOnTabsOn(String guide) {
    return '$guide avec un court conseil sous le titre.';
  }

  @override
  String meCoachOnTabsOff(String guide) {
    return 'Désactivé. L\'aide reste à portée d\'un toucher sur l\'avatar de $guide.';
  }

  @override
  String get meCoachHints => 'Conseils du coach';

  @override
  String meCoachHintsOn(String guide) {
    return 'Un court conseil de $guide à côté de l\'aide de GoHard, une seule fois chacun.';
  }

  @override
  String get meCoachHintsOff =>
      'Désactivé. L\'aide reste là quand tu la demandes.';

  @override
  String get meCoachHintsReset => 'Afficher de nouveau les conseils du coach';

  @override
  String get meCoachHintsResetDone =>
      'Les conseils déjà vus peuvent s\'afficher de nouveau.';

  @override
  String get meTodayBackground => 'Fond d\'Aujourd\'hui';

  @override
  String get meMotionHaptics => 'Mouvement et vibrations';

  @override
  String get meMotionSubtitle =>
      'Comment GoHard bouge et vibre sur ce téléphone.';

  @override
  String get meMotionSection => 'Mouvement';

  @override
  String get meHapticsSection => 'Vibrations';

  @override
  String get meMotionReducedSummary => 'Mouvement réduit';

  @override
  String get meHapticsOffSummary => 'Vibrations désactivées';

  @override
  String get meMotionReducedHapticsOffSummary =>
      'Réduit · Vibrations désactivées';

  @override
  String get meMotionDevicePhoneReduces =>
      'Suit ton téléphone. Réduire les animations y est activé, donc les écrans et la progression changent sans mouvement.';

  @override
  String get meMotionDevicePhoneMoves =>
      'Suit le réglage Réduire les animations de ton téléphone. Il y est désactivé, donc de courtes transitions s\'affichent.';

  @override
  String get meMotionReducedExplanation =>
      'Les écrans, les panneaux et la progression changent sans mouvement, peu importe le réglage de ton téléphone.';

  @override
  String get meHapticsDeviceExplanation =>
      'Une légère vibration quand tu fais un choix ou confirmes une action, si ton téléphone permet les vibrations. Jamais pour la synchronisation ou la saisie.';

  @override
  String get meHapticsOffExplanation =>
      'GoHard ne fait pas vibrer ce téléphone.';

  @override
  String get mePrefsApplyNow =>
      'Les changements s\'appliquent immédiatement et sont mémorisés sur ce téléphone.';

  @override
  String get mePermissions => 'Autorisations du téléphone';

  @override
  String get mePermissionsSubtitle =>
      'Localisation, appareil photo et notifications';

  @override
  String get meReminders => 'Rappels de séance';

  @override
  String get meRemindersOnSubtitle =>
      'Les jours où une séance est prévue. Aucun pendant que ton programme est en pause.';

  @override
  String get meReminderTime => 'Heure du rappel';

  @override
  String get meReminderTimeSubtitle => 'Heure locale de ce téléphone';

  @override
  String get meSyncStatus => 'État de la synchronisation';

  @override
  String get meDeleteAccount => 'Supprimer le compte';

  @override
  String get meDeleteAccountSubtitle =>
      'Efface définitivement ton compte et tes données';

  @override
  String get meSignOut => 'Se déconnecter';

  @override
  String get meSignOutConfirmTitle => 'Se déconnecter?';

  @override
  String meSignOutConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tes séances, aliments et programmes restent enregistrés, y compris $count changements pas encore synchronisés. Ils restent privés à ton compte sur ce téléphone et continuent de se synchroniser quand tu te reconnectes.',
      one: 'Tes séances, aliments et programmes restent enregistrés, y compris 1 changement pas encore synchronisé. Ils restent privés à ton compte sur ce téléphone et continuent de se synchroniser quand tu te reconnectes.',
      zero: 'Tes séances, aliments et programmes restent enregistrés. Ils restent privés à ton compte sur ce téléphone et continuent de se synchroniser quand tu te reconnectes.',
    );
    return '$_temp0';
  }

  @override
  String get meSaveName => 'Enregistrer le nom';

  @override
  String get meNameNotSaved =>
      'Ton nom n\'a pas pu être enregistré sur ce téléphone. Ce que tu as saisi est toujours là.';

  @override
  String get meNameField => 'Nom affiché dans l\'application';

  @override
  String meSignedInAs(String email) {
    return 'Connecté en tant que $email';
  }

  @override
  String get meDeletePasswordMissing =>
      'Entre ton mot de passe pour confirmer.';

  @override
  String get meDeleteConfirmTitle => 'Supprimer ton compte?';

  @override
  String get meDeleteConfirmBody =>
      'Ton compte et toutes ses séances, aliments, programmes et mesures seront effacés définitivement. C\'est irréversible.';

  @override
  String get meDeleteConfirmAction => 'Tout supprimer';

  @override
  String get meDeleteButton => 'Supprimer mon compte';

  @override
  String get meDeleteKeep => 'Garder mon compte';

  @override
  String get meDeleteExplanation =>
      'Ceci efface définitivement ton compte et tout son contenu, sur le serveur et sur ce téléphone. Se déconnecter est différent : tout est gardé.';

  @override
  String meDeletePendingWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changements sur ce téléphone ne sont pas encore synchronisés et seront aussi effacés.',
      one: '1 changement sur ce téléphone n\'est pas encore synchronisé et sera aussi effacé.',
    );
    return '$_temp0';
  }

  @override
  String get meDeletePasswordField => 'Ton mot de passe';

  @override
  String get bodyTitle => 'Suivi corporel';

  @override
  String get bodyFieldWeight => 'Poids';

  @override
  String get bodyFieldWaist => 'Tour de taille';

  @override
  String get bodyFieldChest => 'Tour de poitrine';

  @override
  String get bodyFieldLeftUpperArm => 'Haut du bras gauche';

  @override
  String get bodyFieldRightUpperArm => 'Haut du bras droit';

  @override
  String get bodyFieldLeftThigh => 'Cuisse gauche';

  @override
  String get bodyFieldRightThigh => 'Cuisse droite';

  @override
  String get bodyFieldBodyFat => 'Masse grasse';

  @override
  String bodyFieldValue(String field, String value) {
    return '$field $value';
  }

  @override
  String get bodyUnitCm => 'cm';

  @override
  String get bodyUnitIn => 'po';

  @override
  String get bodyUnitPoints => 'pts';

  @override
  String get bodyUnitWeight => 'Poids';

  @override
  String get bodyUnitLength => 'Longueur';

  @override
  String get bodyErrorNotANumber => 'Entre un nombre, ou laisse vide.';

  @override
  String get bodyErrorWeightRange =>
      'Le poids est supérieur à 0 et d\'au plus 700 kg (1 543 lb).';

  @override
  String get bodyErrorLengthRange =>
      'Utilise une valeur supérieure à 0 et d\'au plus 500 cm (196,85 po).';

  @override
  String get bodyErrorFatRange => 'La masse grasse va de 0 à 100 %.';

  @override
  String get bodyErrorNothingEntered =>
      'Entre au moins une mesure pour enregistrer.';

  @override
  String bodyErrorFieldOutOfRange(String field) {
    return '$field : valeur hors limites.';
  }

  @override
  String get bodyErrorNoteTooLong => 'Une note compte au plus 200 caractères.';

  @override
  String get bodyErrorMeasurementsNeedServer =>
      'Le serveur de ton compte ne peut pas encore stocker ces mesures. Le poids et la masse grasse peuvent être enregistrés maintenant.';

  @override
  String get bodyErrorNeedsOneMeasurement =>
      'Une entrée doit avoir au moins une mesure. Pour la retirer, utilise Supprimer l\'entrée.';

  @override
  String get bodyErrorCorrectionNeedsServer =>
      'Corriger une entrée nécessite une mise à jour du serveur de ton compte. Tes changements sont toujours là.';

  @override
  String bodyRangeLabel(String range) {
    String _temp0 = intl.Intl.selectLogic(range, {
      'weeks4': '4 semaines',
      'weeks12': '12 semaines',
      'other': 'Tout',
    });
    return '$_temp0';
  }

  @override
  String bodyRangeWords(String range) {
    String _temp0 = intl.Intl.selectLogic(range, {
      'weeks4': 'au cours des 4 dernières semaines',
      'weeks12': 'au cours des 12 dernières semaines',
      'other': 'dans tout ton historique',
    });
    return '$_temp0';
  }

  @override
  String get bodyReadErrorTitle => 'Lecture impossible';

  @override
  String get bodyReadErrorBody =>
      'Tes mesures sur ce téléphone n\'ont pas pu être lues pour l\'instant. Rien n\'a été changé; réessaie.';

  @override
  String get bodySyncNeedsReview =>
      'À réviser dans Profil › État de la synchronisation';

  @override
  String get bodySyncWaiting =>
      'Enregistré sur ce téléphone · en attente de synchronisation';

  @override
  String bodyDayEntriesKnown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées ce jour-là, dans l\'ordre d\'enregistrement.',
      one: '1 entrée ce jour-là, dans l\'ordre d\'enregistrement.',
    );
    return '$_temp0';
  }

  @override
  String bodyDayEntriesUnknown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées ce jour-là. L\'ordre de prise n\'est pas connu.',
      one: '1 entrée ce jour-là. L\'ordre de prise n\'est pas connu.',
    );
    return '$_temp0';
  }

  @override
  String bodySavedAt(String time) {
    return 'Enregistrée à $time';
  }

  @override
  String bodySavedAtLower(String time) {
    return 'enregistrée à $time';
  }

  @override
  String bodyEntryNumber(int number) {
    return 'Entrée $number';
  }

  @override
  String get bodyHelp => 'Aide sur le suivi corporel';

  @override
  String get bodyCoachSay =>
      'Suis ce qui compte pour toi. Chaque mesure est facultative.';

  @override
  String get bodyHowToMeasure => 'Comment mesurer';

  @override
  String get bodyEmptyTitle => 'Rien d\'enregistré pour l\'instant';

  @override
  String get bodyEmptyBody =>
      'Consigne un poids ou une seule mesure quand ça t\'aide. Rien n\'est obligatoire.';

  @override
  String get bodyLogMeasurements => 'Consigner des mesures';

  @override
  String bodyPendingOldServer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changements enregistrés sur ce téléphone. Certains attendent que le serveur de ton compte prenne en charge les mesures corporelles.',
      one: '1 changement enregistré sur ce téléphone. Certains attendent que le serveur de ton compte prenne en charge les mesures corporelles.',
    );
    return '$_temp0';
  }

  @override
  String bodyPendingWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changements enregistrés sur ce téléphone · en attente de synchronisation',
      one: '1 changement enregistré sur ce téléphone · en attente de synchronisation',
    );
    return '$_temp0';
  }

  @override
  String get bodyAllMeasurements => 'Toutes les mesures';

  @override
  String get bodyLatestWeight => 'Dernier poids';

  @override
  String get bodyNotRecorded => 'Non enregistré';

  @override
  String get bodyNotRecordedLower => 'non enregistré';

  @override
  String get bodyDashNotRecorded => '— Non enregistré';

  @override
  String get bodyOtherBelow => 'Tes autres mesures sont plus bas.';

  @override
  String bodyAverageOfEntries(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moyenne de $count entrées le $date',
      one: 'Moyenne d\'une entrée le $date',
    );
    return '$_temp0';
  }

  @override
  String bodyRecordedOn(String date) {
    return 'Enregistré le $date';
  }

  @override
  String get bodySevenDayAverage => 'Moyenne sur 7 jours';

  @override
  String get bodyNotAvailable => 'Non disponible';

  @override
  String get bodyNotAvailableLower => 'non disponible';

  @override
  String get bodyNoWeightSevenDays =>
      'Aucun poids au cours des 7 derniers jours';

  @override
  String bodyRecordedDaysOfSeven(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours enregistrés sur 7',
      one: '1 jour enregistré sur 7',
    );
    return '$_temp0';
  }

  @override
  String bodyDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get bodyLog => 'Consigner';

  @override
  String get bodyCompareDates => 'Comparer des dates';

  @override
  String bodyOverTime(String field) {
    return '$field au fil du temps';
  }

  @override
  String get bodySeeAll => 'Tout voir';

  @override
  String get bodyChartNoWeight =>
      'Aucun poids enregistré pour l\'instant. Consigne-en un pour le suivre au fil du temps.';

  @override
  String bodyChartNone(String field) {
    return 'Aucune mesure de $field pour l\'instant.';
  }

  @override
  String bodyChartEmptyInRange(String field, String range) {
    return 'Aucune mesure de $field $range. Choisis une période plus longue.';
  }

  @override
  String get bodyChartLegendDaily =>
      'Points : chaque entrée · ligne : moyenne quotidienne';

  @override
  String get bodyChartLegendPoints =>
      'Chaque point est une entrée que tu as enregistrée';

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
      other: '$count entrées',
      one: '1 entrée',
    );
    return '$field $range : $_temp0. $readings.';
  }

  @override
  String bodyReading(String date, String value) {
    return '$date, $value';
  }

  @override
  String bodyOneDayInRange(String range) {
    return 'Un seul jour enregistré $range. Un changement en demande au moins deux.';
  }

  @override
  String bodyRangeChange(String change) {
    return 'Du premier au dernier jour de cette période : $change';
  }

  @override
  String get bodyLatestMeasurements => 'Dernières mesures';

  @override
  String get bodyLatestNone =>
      'Aucune mesure autre que le poids pour l\'instant. Consigne des mesures pour ajouter la taille, la poitrine, les bras ou les cuisses.';

  @override
  String get bodyMetricFatSubtitle => 'Masse grasse que tu as entrée, en %';

  @override
  String bodyMetricUnitSubtitle(String unit) {
    return 'En $unit';
  }

  @override
  String get bodyEntriesInRange => 'Entrées de cette période';

  @override
  String get bodyHistorySubtitle =>
      'Toutes les entrées, les plus récentes d\'abord';

  @override
  String get bodyHistoryEmptyBody =>
      'Tes entrées apparaîtront ici dès que tu en consigneras une.';

  @override
  String get bodyNoMeasurement => 'Aucune mesure';

  @override
  String bodyOneOfEntriesLower(int count) {
    return 'une de $count entrées, ordre inconnu';
  }

  @override
  String bodyOneOfEntriesDay(int count) {
    return 'Une de $count entrées ce jour-là, ordre inconnu';
  }

  @override
  String bodyQuotedNote(String note) {
    return '« $note »';
  }

  @override
  String get bodyConvertBlocked =>
      'Un champ contient du texte qui n\'est pas un nombre. Corrige-le ou vide-le, puis change l\'unité.';

  @override
  String get bodyDateMeasured => 'Date de la mesure';

  @override
  String get bodyFutureDate => 'Choisis aujourd\'hui ou une date antérieure.';

  @override
  String get bodyCheckFields =>
      'Vérifie les champs en évidence. Rien n\'a été enregistré.';

  @override
  String get bodySavedToast =>
      'Enregistré sur ce téléphone · synchronisé avec ton compte dès que possible';

  @override
  String get bodySaveFailed =>
      'Impossible d\'enregistrer sur ce téléphone. Tout ce que tu as saisi est toujours là.';

  @override
  String get bodyDeleteConfirmTitle => 'Supprimer cette entrée?';

  @override
  String bodyDeleteConfirmBody(String date) {
    return 'L\'entrée du $date sera retirée de tes mesures.';
  }

  @override
  String get bodyDeleteFailed =>
      'Impossible de retirer ceci sur ce téléphone. Réessaie.';

  @override
  String get bodyChooseMeasurements => 'Choisir les mesures';

  @override
  String get bodyChooseSubtitle => 'Masse grasse, une note ou moins de champs';

  @override
  String get bodyChooseExplanation =>
      'Choisis ce que ce formulaire affiche. Masquer un champ ne retire jamais rien de ce que tu as enregistré.';

  @override
  String get bodyNote => 'Note';

  @override
  String get bodyNoteOptional => 'Note (facultative)';

  @override
  String get bodyDiscardTitle => 'Abandonner tes changements?';

  @override
  String get bodyDiscardBody => 'Ce que tu as saisi n\'a pas été enregistré.';

  @override
  String get bodyDiscard => 'Abandonner';

  @override
  String get bodyKeepEditing => 'Continuer la modification';

  @override
  String get bodyEditEntry => 'Modifier l\'entrée';

  @override
  String get bodyEveryOptional => 'Chaque mesure est facultative.';

  @override
  String get bodyDoneTyping => 'Saisie terminée';

  @override
  String get bodySaveMeasurements => 'Enregistrer les mesures';

  @override
  String get bodySaveChanges => 'Enregistrer les changements';

  @override
  String get bodyAtLeastOne =>
      'Entre au moins une mesure pour enregistrer. Vide signifie non mesuré.';

  @override
  String get bodyDeleteEntry => 'Supprimer l\'entrée';

  @override
  String get bodyCompareFrom => 'Comparer à partir de';

  @override
  String get bodyCompareTo => 'Comparer avec';

  @override
  String get bodyCompareOnlySaved =>
      'Seuls les jours avec une entrée enregistrée peuvent être choisis.';

  @override
  String get bodyCompareSubtitle =>
      'Changements entre tes entrées enregistrées.';

  @override
  String get bodyCompareHelp => 'Aide pour comparer';

  @override
  String get bodyCompareCoachSay =>
      'Compare la même mesure à deux dates. Un tiret signifie qu\'elle n\'a pas été enregistrée ce jour-là.';

  @override
  String get bodyTwoDatesTitle => 'Deux dates nécessaires';

  @override
  String get bodyTwoDatesNone =>
      'Comparer nécessite des entrées sur deux jours différents. Tu n\'en as aucune pour l\'instant.';

  @override
  String bodyTwoDatesOne(String date) {
    return 'Comparer nécessite des entrées sur deux jours différents. Tu as des entrées le $date seulement.';
  }

  @override
  String get bodyCompareLost =>
      'Une entrée choisie n\'est plus disponible, donc celle par défaut est affichée.';

  @override
  String get bodyCompareChoose =>
      'Ces jours ont plus d\'une entrée et leur ordre n\'est pas connu. Choisis les entrées à comparer.';

  @override
  String get bodyCompareSame =>
      'Début et fin sont la même entrée. Choisis-en une autre.';

  @override
  String get bodyChoose => 'Choisir';

  @override
  String get bodyFrom => 'Du';

  @override
  String get bodyTo => 'Au';

  @override
  String bodyCompareWeightChange(String change) {
    return 'Changement  $change';
  }

  @override
  String get bodyCompareWeightNoChange =>
      'Changement  —  il faut un poids les deux jours';

  @override
  String get bodyMeasurements => 'Mesures';

  @override
  String get bodyChange => 'Changement';

  @override
  String bodyChangeValue(String change) {
    return 'Changement : $change';
  }

  @override
  String bodyDatedValue(String date, String value) {
    return '$date : $value';
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
    return '$field : $fromDate $fromValue, $toDate $toValue, changement $change';
  }

  @override
  String get bodyFatPointsNote =>
      'Le changement de masse grasse est en points de pourcentage.';

  @override
  String get bodyRecordedOnly =>
      'Valeurs enregistrées seulement. Un changement s\'affiche seulement si les deux entrées ont cette mesure.';

  @override
  String get bodyHowSubtitle =>
      'Mesure de la même façon chaque fois, pour que les entrées se comparent.';

  @override
  String get bodyHowTapeTitle => 'Toute mesure au ruban';

  @override
  String get bodyHowTapeBody =>
      'Utilise un ruban souple. Garde-le droit et ajusté, sans appuyer sur la peau, et lis-le au même endroit chaque fois.';

  @override
  String get bodyHowWaistBody =>
      'Trouve le haut de l\'os de la hanche sur le côté. Enroule le ruban autour de ta taille à ce niveau, parallèle au sol, et lis-le à la fin d\'une expiration normale.';

  @override
  String get bodyHowArmTitle => 'Haut du bras';

  @override
  String get bodyHowArmBody =>
      'Trouve le point milieu entre la pointe osseuse de l\'épaule et la pointe du coude, à l\'arrière du bras. Le bras détendu et pendant librement, enroule le ruban autour du bras à ce point. Contracter le muscle change la mesure. Mesure le bras gauche et le bras droit séparément.';

  @override
  String get bodyHowChestThighsTitle => 'Poitrine et cuisses';

  @override
  String get bodyHowChestThighsBody =>
      'GoHard n\'a pas de repère standard vérifié pour celles-ci. Choisis un endroit, note-le si ça aide, et mesure là chaque fois avec le même ajustement du ruban. Mesure la cuisse gauche et la cuisse droite séparément.';

  @override
  String get bodyHowWeightFatTitle => 'Poids et masse grasse';

  @override
  String get bodyHowWeightFatBody =>
      'Facultatif. Entre la masse grasse seulement si tu as une valeur provenant d\'une méthode fiable; GoHard ne l\'estime pas.';

  @override
  String get bodyHowSource =>
      'Source : Centers for Disease Control and Prevention, National Center for Health Statistics. NHANES Anthropometry Procedures Manual, janvier 2017 : 3.4.6 Upper Arm Length, 3.4.7 Arm Circumference, 3.4.8 Abdominal (Waist) Circumference.';

  @override
  String get bodyHowNotAdvice =>
      'Il s\'agit d\'une technique de mesure, pas d\'un conseil de santé. GoHard ne juge pas les mesures.';

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
    return 'du $start au $end';
  }

  @override
  String planDateRangeSameMonth(String month, String startDay, String endDay) {
    return '$startDay–$endDay $month';
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
  String get planWorkoutFallback => 'Séance';

  @override
  String get planDefaultTitle => 'Mon programme';

  @override
  String planCopyName(String name) {
    return '$name (copie)';
  }

  @override
  String get planModeFixed => 'Jours fixes';

  @override
  String get planModeRotating => 'Séquence en rotation';

  @override
  String planWeekN(int week) {
    return 'Semaine $week';
  }

  @override
  String planWeekNOfM(int week, int total) {
    return 'Semaine $week sur $total';
  }

  @override
  String planWeekLower(int week) {
    return 'semaine $week';
  }

  @override
  String planSessionN(int n) {
    return 'Séance $n';
  }

  @override
  String planSessionLower(int n) {
    return 'séance $n';
  }

  @override
  String planSessionStep(int n, int step, int total, int cycle) {
    return 'Séance $n · étape $step sur $total, cycle $cycle';
  }

  @override
  String planWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '$count semaine',
    );
    return '$_temp0';
  }

  @override
  String planWeeksPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '$count semaine',
    );
    return '$_temp0';
  }

  @override
  String planWorkoutsPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances',
      one: '$count séance',
    );
    return '$_temp0';
  }

  @override
  String planExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercices',
      one: '$count exercice',
    );
    return '$_temp0';
  }

  @override
  String planExercisesPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercices',
      one: '$count exercice',
    );
    return '$_temp0';
  }

  @override
  String planPlannedSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries prévues',
      one: '$count série prévue',
    );
    return '$_temp0';
  }

  @override
  String planSetsPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '$count série',
    );
    return '$_temp0';
  }

  @override
  String planSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '$count série',
    );
    return '$_temp0';
  }

  @override
  String planRepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count répétitions',
      one: '$count répétition',
    );
    return '$_temp0';
  }

  @override
  String planRxSetsTimes(int sets, String amount) {
    return '$sets × $amount';
  }

  @override
  String planRestMinutes(int minutes) {
    return '$minutes min de repos';
  }

  @override
  String planRestSeconds(int seconds) {
    return '$seconds s de repos';
  }

  @override
  String get planNoTarget => 'Aucune cible';

  @override
  String planTargetLoad(String load) {
    return 'Charge cible $load';
  }

  @override
  String planPlannedTime(int minutes) {
    return 'Durée prévue $minutes min';
  }

  @override
  String get planOngoing => 'Continu';

  @override
  String get planOngoingLower => 'continu';

  @override
  String planStartsOn(String date) {
    return 'commence le $date';
  }

  @override
  String planEndsOn(String date) {
    return 'se termine le $date';
  }

  @override
  String get planTodayLower => 'aujourd\'hui';

  @override
  String get planTodayLabel => 'Aujourd\'hui';

  @override
  String get planRestDayLower => 'jour de repos';

  @override
  String get planNext => 'Suivante';

  @override
  String get planSplitEvidenceNote =>
      'Les études qui comparent des répartitions au même volume hebdomadaire ont trouvé des gains de force et de muscle semblables : choisis la structure que tu pourras maintenir.';

  @override
  String planSuggestReasonFew(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Avec $days jours par semaine, les séances corps entier font travailler chaque groupe musculaire à chaque entraînement.',
      one:
          'Avec $days jour par semaine, les séances corps entier font travailler chaque groupe musculaire à chaque entraînement.',
    );
    return '$_temp0';
  }

  @override
  String get planSuggestReasonFour =>
      'Avec 4 jours, alterner le haut et le bas du corps fait travailler chaque moitié deux fois par semaine.';

  @override
  String get planSuggestReasonFive =>
      'Avec 5 jours, une journée haut du corps, une journée bas du corps, puis poussée, tirage et jambes font travailler chaque zone environ deux fois par semaine.';

  @override
  String planSuggestReasonMany(int days) {
    return 'Avec $days jours, répéter poussée, tirage et jambes fait travailler chaque zone deux fois par semaine.';
  }

  @override
  String planSuggestReasonSeven(int days) {
    return 'Avec $days jours, répéter poussée, tirage et jambes fait travailler chaque zone deux fois par semaine et laisse un jour de repos.';
  }

  @override
  String get planDirectionStrength => 'Devenir plus fort';

  @override
  String get planDirectionMuscle => 'Développer les muscles';

  @override
  String get planDirectionFatLoss => 'Perdre du gras';

  @override
  String get planDirectionGeneral => 'Forme générale';

  @override
  String planSetupPerWeek(String count) {
    return '$count par semaine';
  }

  @override
  String planSetupAbout(String minutes) {
    return 'environ $minutes min';
  }

  @override
  String get planReviewedPlan => 'Programme révisé';

  @override
  String get planOwnSplit => 'Ta propre répartition';

  @override
  String get planStarterSplit => 'Répartition de départ';

  @override
  String get builderEquipmentFullGym => 'Salle complète';

  @override
  String get builderEquipmentDumbbells => 'Haltères seulement';

  @override
  String get builderEquipmentBodyweight => 'Poids du corps seulement';

  @override
  String get builderExperienceNew => 'Débutant';

  @override
  String get builderExperienceComfortable => 'À l\'aise avec les bases';

  @override
  String get builderExperienceExperienced => 'Expérimenté';

  @override
  String planLifecycle(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'draft': 'brouillon',
      'active': 'actif',
      'paused': 'en pause',
      'closed': 'fermé',
      'other': '$state',
    });
    return '$_temp0';
  }

  @override
  String get planProvenanceManual => 'Séance libre · hors programme';

  @override
  String planProvenanceGone(String title) {
    return 'D\'un programme qui n\'est plus sur ce téléphone · $title';
  }

  @override
  String planProvenanceFrom(String plan, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'archived': 'De $plan (archivé)',
      'closed': 'De $plan (fermé)',
      'paused': 'De $plan (en pause)',
      'other': 'De $plan',
    });
    return '$_temp0';
  }

  @override
  String planSessionOfRotation(int n) {
    return 'séance $n de la rotation';
  }

  @override
  String get planErrTitle =>
      'Donne au programme un nom de 60 caractères au plus.';

  @override
  String get planErrDuration =>
      'Choisis une durée de 1 à 52 semaines. Seule une séquence en rotation peut durer sans fin.';

  @override
  String get planErrTimeBudget =>
      'Choisis une durée prévue de 10 à 240 minutes, ou aucune.';

  @override
  String get planErrWorkouts =>
      'Vérifie les séances : chacune doit avoir un nom, et les séries, répétitions, repos et charges doivent être dans les limites.';

  @override
  String get planErrSchedule =>
      'Vérifie l\'horaire : chaque jour ou étape doit avoir une séance, avec une séance par jour de la semaine.';

  @override
  String get planErrNotUsable =>
      'Ajoute au moins un exercice à chaque séance prévue avant d\'activer le programme.';

  @override
  String get planErrNewerApp =>
      'Ce programme a été créé avec une version plus récente de l\'appli. Mets l\'appli à jour pour le modifier.';

  @override
  String get planErrUnknownExercise =>
      'Un exercice de ce programme n\'est pas offert à ton compte.';

  @override
  String get planErrStartLocked =>
      'Un programme actif garde sa date de début. Duplique-le pour recommencer un autre jour.';

  @override
  String get planErrModeLocked =>
      'Un programme actif garde son type d\'horaire. Duplique-le pour passer des jours fixes à une rotation.';

  @override
  String get planErrNotMovable =>
      'Un programme en rotation n\'a pas de dates fixes. Saute la séance, ou fais-la à ton prochain entraînement.';

  @override
  String get planErrExerciseName =>
      'Donne à l\'exercice un nom de 80 caractères au plus.';

  @override
  String get planErrChangedSinceEdit =>
      'Ce programme a changé depuis que tu as commencé à le modifier. Recommence à partir du programme tel qu\'il est maintenant.';

  @override
  String get planErrNotActive =>
      'Ce programme est fermé. Duplique-le pour t\'entraîner avec lui de nouveau.';

  @override
  String get planErrTargetContext =>
      'Cet exercice ne fait plus partie de cette séance du programme : sa cible n\'a donc pas été changée. Révise plutôt le programme.';

  @override
  String get planErrTargetChanged =>
      'Cette cible a encore changé depuis, donc l\'ancienne n\'a pas été rétablie. Modifie-la plutôt.';

  @override
  String planErrUnknown(String code) {
    return 'Ce changement n\'a pas pu être appliqué ($code).';
  }

  @override
  String get planErrRecovery =>
      'Il ne reste alors aucun jour de récupération entre deux séances.';

  @override
  String get planErrNotEligible =>
      'Cette séance est déjà enregistrée, sautée ou en cours : elle ne peut pas être déplacée.';

  @override
  String get planErrStaleReview =>
      'L\'horaire a changé depuis ta révision. Révise-le de nouveau.';

  @override
  String get planErrWeekdayCount =>
      'Choisis exactement autant de jours que de séances par semaine.';

  @override
  String get planErrInvalidDate => 'Entre une vraie date du calendrier.';

  @override
  String get planErrNoLongerInPlan =>
      'Cette séance ne fait plus partie de ce programme.';

  @override
  String get planPrimaryExists =>
      'Un autre programme est déjà ton programme principal. Révise d\'abord le remplacement.';

  @override
  String get planLocalSaveFailed =>
      'Impossible d\'enregistrer sur ce téléphone. Rien n\'a changé.';

  @override
  String get trainSectionWorkouts => 'Séances';

  @override
  String get trainSectionPlan => 'Programme';

  @override
  String get trainSectionProgress => 'Progrès';

  @override
  String get trainAskStartingPlan => 'Commencer un programme';

  @override
  String get trainAskYourPlan => 'Ton programme';

  @override
  String get trainAskYourProgress => 'Tes progrès';

  @override
  String get trainAskYourTraining => 'Ton entraînement';

  @override
  String get planStartInProgressCoach =>
      'Ton programme en cours est enregistré sur ce téléphone. Reprends là où tu étais.';

  @override
  String get planStartInProgressTitle => 'Programme en cours';

  @override
  String get planStartInProgressBody =>
      'Enregistré sur ce téléphone. Rien n\'est prévu tant que tu ne le commences pas.';

  @override
  String get planStartContinue => 'Continuer mon programme';

  @override
  String get planStartDraftCoach =>
      'Ton programme est enregistré comme brouillon. Révise-le, puis commence-le quand tu es prêt.';

  @override
  String get planStartDraftTitle => 'Ton programme est prêt à réviser';

  @override
  String get planStartDraftBody =>
      'Un brouillon enregistré ne prévoit rien tant que tu ne le commences pas.';

  @override
  String get planStartReview => 'Réviser mon programme';

  @override
  String get planStartNewCoach =>
      'Créons ton programme d\'entraînement. Choisis une répartition connue ou crée la tienne.';

  @override
  String get planStartNewTitle => 'Pas encore de programme';

  @override
  String get planStartNewBody =>
      'Choisis une répartition connue ou crée la tienne. Rien n\'est prévu avant ta révision.';

  @override
  String get planStartCreate => 'Créer mon programme';

  @override
  String get trainCoachPlanPaused =>
      'Ton programme est en pause, donc rien ne compte comme manqué. Reprends-le ci-dessous quand tu es prêt.';

  @override
  String get trainCoachPlanWeek =>
      'Voici ton programme semaine par semaine. Touche une séance pour ses détails, ou pose-moi une question sur l\'horaire.';

  @override
  String get trainCoachWorkoutOpen =>
      'Une séance est encore ouverte. Reprends-la ci-dessous quand tu es prêt.';

  @override
  String get trainCoachWorkoutsPlan =>
      'Commence ta séance prévue à partir d\'Aujourd\'hui, ou enregistre ta propre séance ici.';

  @override
  String get trainCoachWorkoutsNoPlan =>
      'Enregistre ta propre séance ici. Un programme peut les prévoir pour toi.';

  @override
  String get trainScheduledToday => 'Prévu aujourd\'hui';

  @override
  String trainDueToday(String summary) {
    return 'Prévue aujourd\'hui · $summary';
  }

  @override
  String get trainOpenWorkouts => 'Séances ouvertes';

  @override
  String get trainStartManual => 'Commencer une séance libre';

  @override
  String get trainStartManualSubtitle =>
      'Entraîne-toi sans programme. Elle ne coche jamais une séance prévue.';

  @override
  String get trainRunWalk => 'Course / marche';

  @override
  String get trainRunWalkSubtitle =>
      'Enregistre une course ou une marche à l\'extérieur, avec son trajet';

  @override
  String get trainRunWalkHistory => 'Historique course / marche';

  @override
  String get trainRunWalkHistorySubtitle =>
      'Chaque course et marche, trajets et records personnels';

  @override
  String get trainRecentEmptyTitle =>
      'Aucune séance enregistrée pour l\'instant';

  @override
  String get trainRecentEmptyBody =>
      'Quand tu termines une séance, ce que tu as vraiment fait s\'affiche ici.';

  @override
  String get trainSavedForLater => 'Gardée pour plus tard';

  @override
  String get trainInProgress => 'En cours';

  @override
  String trainOpenStatusLine(String status, String date) {
    return '$status · commencée le $date';
  }

  @override
  String trainSetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries enregistrées',
      one: '$count série enregistrée',
    );
    return '$_temp0';
  }

  @override
  String get trainResume => 'Reprendre';

  @override
  String get trainDetails => 'Détails';

  @override
  String trainDetailsOf(String title) {
    return 'Détails de $title';
  }

  @override
  String get planNeedsReview =>
      'Un changement de programme enregistré sur ce téléphone diffère de ton compte. Révise-le à partir de l\'avis au bas de l\'écran.';

  @override
  String get planTrainWithoutPlan => 'S\'entraîner sans programme';

  @override
  String get planTrainWithoutPlanSaid =>
      'Commencer une séance libre sans programme';

  @override
  String get planSavedAndPast => 'Programmes enregistrés et passés';

  @override
  String planSavedDraftReady(String mode, String date) {
    return 'Brouillon · $mode · pas commencé · commencerait le $date';
  }

  @override
  String planSavedDraftEmpty(String mode) {
    return 'Brouillon · $mode · ajoute des exercices pour l\'utiliser';
  }

  @override
  String planSavedDraftOld(String date) {
    return 'Brouillon · pas commencé · commencerait le $date';
  }

  @override
  String get planSavedPaused => 'En pause · pas ton programme principal';

  @override
  String get planSavedActive => 'Actif · pas ton programme principal';

  @override
  String get planStoppedEarly => 'Arrêté plus tôt';

  @override
  String get planFinishedForNow => 'Terminé pour l\'instant';

  @override
  String planArchivedCount(int count) {
    return 'Programmes archivés ($count)';
  }

  @override
  String get planNotStarted => 'Pas commencé';

  @override
  String get planPaused => 'En pause';

  @override
  String planEnds(String date) {
    return 'Se termine le $date';
  }

  @override
  String get planOngoingNoEnd => 'Continu, sans date de fin';

  @override
  String planStarts(String date) {
    return 'Commence le $date';
  }

  @override
  String get planPausedLine =>
      'Programme en pause. Aucune nouvelle séance n\'est attendue, et rien ne compte comme manqué pendant la pause.';

  @override
  String get planResume => 'Reprendre le programme';

  @override
  String get planSuggestedChange => 'Changement suggéré à réviser';

  @override
  String get planManage => 'Gérer ce programme';

  @override
  String get planEdit => 'Modifier le programme';

  @override
  String get planEditSubtitle =>
      'Séances, exercices et horaire à partir de la date de ton choix. Les séances enregistrées ne changent jamais.';

  @override
  String get planPause => 'Mettre le programme en pause';

  @override
  String get planDuplicate => 'Dupliquer le programme';

  @override
  String get planDuplicateSubtitle =>
      'Un nouveau brouillon avec les mêmes séances et le même horaire. Ce programme reste tel quel.';

  @override
  String get planReplaceMovement =>
      'Remplacer un mouvement dans les séances restantes';

  @override
  String get planReviewBlockRow => 'Réviser ou terminer ce bloc';

  @override
  String get planCreateDifferent => 'Créer un autre programme';

  @override
  String get planCreateDifferentSubtitle =>
      'Le commencer demandera une confirmation avant de remplacer celui-ci.';

  @override
  String get planArchiveNote =>
      'Ton programme principal doit être mis en pause, terminé ou remplacé avant d\'être archivé. Les programmes enregistrés et passés s\'archivent depuis leur page.';

  @override
  String get planChooseWeek => 'Choisis une semaine';

  @override
  String get planThisWeek => 'Cette semaine';

  @override
  String planCompletedOf(int done, int total) {
    return '$done sur $total terminées';
  }

  @override
  String get planWeekRailLabel => 'Séances terminées cette semaine';

  @override
  String get planNoWorkoutsThisWeek =>
      'Aucune séance n\'est prévue cette semaine.';

  @override
  String get planNextInCycle => 'Prochaine du cycle';

  @override
  String get planProjected => 'Projetée';

  @override
  String get planProjectedLower => 'projetée';

  @override
  String get planYourCycle => 'Ton cycle';

  @override
  String planCycleN(int n) {
    return 'Cycle $n';
  }

  @override
  String get planRotationNoteEveryDay =>
      'Une rotation n\'a pas de dates fixes. La prochaine séance t\'attend jusqu\'à ce que tu la termines ou la sautes, et le cycle se poursuit d\'une semaine à l\'autre. Les jours à venir supposent que tu t\'entraînes tous les jours.';

  @override
  String planRotationNoteDays(String days) {
    return 'Une rotation n\'a pas de dates fixes. La prochaine séance t\'attend jusqu\'à ce que tu la termines ou la sautes, et le cycle se poursuit d\'une semaine à l\'autre. Les jours à venir suivent tes jours d\'entraînement ($days); les autres sont des jours de repos.';
  }

  @override
  String get planComingUp => 'À venir';

  @override
  String get planNothingLeft => 'Il ne reste rien dans ce programme.';

  @override
  String get planRecentSessions => 'Séances récentes';

  @override
  String planCycleStepSemantics(int step, int total, String name) {
    return 'Étape $step sur $total, $name';
  }

  @override
  String planCycleStepNextSemantics(int step, int total, String name) {
    return 'Étape $step sur $total, $name, la prochaine';
  }

  @override
  String planCycleNothingLeft(int cycle) {
    return 'Cycle $cycle · plus rien';
  }

  @override
  String planCycleLine(int cycle, int step, int total, String name) {
    return 'Cycle $cycle · étape $step sur $total · $name ensuite';
  }

  @override
  String planPassSemantics(String title, String week, int done, int total) {
    return '$title. $week. $done / $total séances terminées.';
  }

  @override
  String planPassSemanticsPercent(
    String title,
    String week,
    int done,
    int total,
    String percent,
  ) {
    return '$title. $week. $done / $total séances terminées, $percent.';
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
      other:
          '$title. $week. $count séances terminées cette semaine. $cycleLine.',
      one: '$title. $week. $count séance terminée cette semaine. $cycleLine.',
    );
    return '$_temp0';
  }

  @override
  String get planTrainingPlanOverline => 'Programme d\'entraînement';

  @override
  String get planWorkoutsCompleted => 'Séances terminées';

  @override
  String planSessionsThisWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Séances terminées cette semaine',
      one: 'Séance terminée cette semaine',
    );
    return '$_temp0';
  }

  @override
  String planMovedOriginally(String date) {
    return 'Déplacée · prévue le $date';
  }

  @override
  String get planWeekDone => 'Terminée';

  @override
  String get planWeekCurrent => 'En cours';

  @override
  String planWeekPartial(int done, int total) {
    return '$done sur $total';
  }

  @override
  String get planWeekMissed => 'Manquée';

  @override
  String get planWeekSkipped => 'Sautée';

  @override
  String get planWeekUpcoming => 'À venir';

  @override
  String get planWeekEmpty => 'Aucune séance';

  @override
  String get planThisWeekLower => 'cette semaine';

  @override
  String get planNoWorkoutsLower => 'aucune séance';

  @override
  String planWorkoutsCompletedOf(int done, int total) {
    return '$done séances terminées sur $total';
  }

  @override
  String planPauseTitle(String title) {
    return 'Mettre $title en pause?';
  }

  @override
  String get planPauseBody =>
      'Les séances futures ne sont plus attendues à partir d\'aujourd\'hui, et rien ne comptera comme manqué pendant la pause. Ton historique et tes séances restantes sont conservés.';

  @override
  String planPauseOpenWorkout(String workout) {
    return 'Ta séance ouverte « $workout » n\'est pas touchée : son chrono continue et tu peux encore la terminer.';
  }

  @override
  String get planPauseAction => 'Mettre ce programme en pause';

  @override
  String get planPausedToast => 'Programme en pause.';

  @override
  String planMoveHelp(String title) {
    return 'Déplacer $title au';
  }

  @override
  String get planMoveTitle => 'Déplacer cette séance?';

  @override
  String planMoveBody(
    String title,
    int week,
    String current,
    String proposed,
    String original,
    String end,
  ) {
    return 'Séance : $title (semaine $week)\nDate actuelle : $current\nDate proposée : $proposed\nPrévue au départ : $original\nFin du bloc : $end\n\nC\'est la même séance, dans la même semaine d\'entraînement. Aucune autre séance ne change, et l\'horaire répété reste tel quel.';
  }

  @override
  String get planMoveAction => 'Déplacer la séance';

  @override
  String get planMoveCancel => 'Garder les dates actuelles';

  @override
  String planMovedToast(String date) {
    return 'Déplacée au $date.';
  }

  @override
  String planSkipTitle(String title) {
    return 'Sauter $title?';
  }

  @override
  String planSkipBodyRotation(String title) {
    return '$title sera marquée Sautée aujourd\'hui et la rotation passe à la séance suivante. Celle-ci n\'est pas placée aujourd\'hui : elle arrive à ton prochain jour d\'entraînement, ou tu peux la commencer maintenant. Aucune séance, série ni crédit d\'achèvement n\'est créé.';
  }

  @override
  String planSkipBodyFixed(String date) {
    return 'La séance prévue le $date sera marquée Sautée. Aucune séance, série ni crédit d\'achèvement n\'est créé, et elle ne comptera pas comme entraînement.';
  }

  @override
  String get planSkipAction => 'Sauter cette séance';

  @override
  String get planSkipCancel => 'La garder';

  @override
  String get planSkippedToast => 'Marquée comme sautée.';

  @override
  String planVirtualWhen(String date) {
    return 'Prévue le $date. Une rotation n\'a pas de dates fixes : c\'est le moment où elle arrive si tu respectes tes jours d\'entraînement.';
  }

  @override
  String planDateOriginally(String date, String original) {
    return '$date · prévue le $original';
  }

  @override
  String get planResumeWorkout => 'Reprendre la séance';

  @override
  String get planViewRecorded => 'Voir ce qui a été enregistré';

  @override
  String get planUndoSkip => 'Annuler le saut';

  @override
  String get planUnskippedToast => 'N\'est plus sautée.';

  @override
  String get planSkippedStays =>
      'Sautée. La rotation est passée à la suite, donc elle reste sautée.';

  @override
  String get planPausedNoStart =>
      'Le programme est en pause. Reprends-le pour commencer ou déplacer ses séances.';

  @override
  String get planStartNowRotation => 'Commencer cette séance maintenant';

  @override
  String get planStartWorkout => 'Commencer la séance';

  @override
  String get planRestInstead => 'Me reposer aujourd\'hui plutôt';

  @override
  String planRestToast(String title) {
    return 'Jour de repos. Rien n\'a été sauté : $title t\'attend à ton prochain jour d\'entraînement.';
  }

  @override
  String get planRotationNoMove =>
      'Une rotation n\'a pas de dates à déplacer : cette séance t\'attend jusqu\'à ce que tu la fasses ou la sautes.';

  @override
  String planComesAfter(String title) {
    return 'Vient après $title. Une rotation suit l\'ordre : fais ou saute d\'abord la prochaine.';
  }

  @override
  String get planComesAfterEarlier =>
      'Vient après les séances qui la précèdent. Une rotation suit l\'ordre : fais ou saute d\'abord la prochaine.';

  @override
  String planMissedOn(String date) {
    return 'Manquée le $date. Déplace-la, saute-la ou fais-la maintenant. Elle n\'est jamais marquée terminée d\'elle-même.';
  }

  @override
  String get planStartNowMissed => 'Commencer maintenant';

  @override
  String get planStartEarly => 'Commencer cette séance plus tôt';

  @override
  String get planMoveDate => 'Déplacer à une autre date';

  @override
  String get planEditOnlyThis => 'Modifier cette séance seulement';

  @override
  String get planChangeSchedule => 'Changer l\'horaire';

  @override
  String get planStartDate => 'Date de début';

  @override
  String get planBlockLength => 'Durée du bloc';

  @override
  String planTrainingDaysChoose(int count) {
    return 'Jours d\'entraînement (choisis-en $count)';
  }

  @override
  String get planUpdateDraft => 'Mettre à jour le brouillon';

  @override
  String get planCancelKeepSchedule => 'Annuler et garder l\'horaire révisé';

  @override
  String get planUnreachableDraft =>
      'Impossible de joindre ton compte. Le brouillon n\'a pas changé.';

  @override
  String planFinishAndStartTitle(String title) {
    return 'Terminer $title et commencer ce programme?';
  }

  @override
  String planPauseAndStartTitle(String title) {
    return 'Mettre $title en pause et commencer ce programme?';
  }

  @override
  String planStartFinishBody(String current, String plan, String date) {
    return '« $current » sera fermé comme terminé pour l\'instant. « $plan » devient ton programme principal à partir du $date. Toutes les séances enregistrées sont conservées.';
  }

  @override
  String planStartPauseBody(String current, String plan, String date) {
    return '« $current » sera mis en pause, pas supprimé. Tu pourras le reprendre plus tard. « $plan » devient ton programme principal à partir du $date. Toutes les séances enregistrées sont conservées.';
  }

  @override
  String planOpenWorkoutStaysOpen(String workout) {
    return 'Ta séance ouverte « $workout » reste ouverte avec ses séries enregistrées; tu peux encore la terminer.';
  }

  @override
  String get planFinishAndStart => 'Terminer et commencer';

  @override
  String get planPauseAndStart => 'Mettre en pause et commencer';

  @override
  String planSavedStarts(String date) {
    return 'Programme enregistré. Il commence le $date.';
  }

  @override
  String get planStarted => 'Ton programme a commencé.';

  @override
  String get planDraftNeedsExercises =>
      'Brouillon — ajoute des exercices pour l\'utiliser. Chaque séance prévue doit avoir au moins un exercice avant que le programme puisse commencer.';

  @override
  String get planStartThis => 'Commencer ce programme';

  @override
  String get planFinishBlockStart => 'Terminer le bloc actuel et commencer';

  @override
  String get planReplaceCurrent => 'Remplacer mon programme actuel';

  @override
  String get planSaveForLater => 'Garder pour plus tard';

  @override
  String get planDraftNothingScheduled =>
      'Brouillon · rien n\'est encore prévu';

  @override
  String planCycleList(String names) {
    return 'Cycle : $names';
  }

  @override
  String get planAnyDayNext =>
      'N\'importe quel jour : la prochaine séance est là chaque fois que tu t\'entraînes.';

  @override
  String planTrainingDaysList(String days) {
    return 'Jours d\'entraînement : $days';
  }

  @override
  String planFirstWorkout(String value) {
    return 'Première séance : $value';
  }

  @override
  String get planChangeDates => 'Changer les dates, les jours ou la durée';

  @override
  String planFollowingFinish(String title) {
    return 'Tu suis « $title ». Commencer ce programme le terminera. Ta confirmation explicite est nécessaire; rien n\'est supprimé.';
  }

  @override
  String planFollowingPause(String title) {
    return 'Tu suis « $title ». Commencer ce programme le mettra en pause. Ta confirmation explicite est nécessaire; rien n\'est supprimé.';
  }

  @override
  String get planNextSessions => 'Prochaines séances';

  @override
  String get planFirstWeek => 'Première semaine';

  @override
  String get planRotationReviewNote =>
      'Une rotation n\'a pas de dates fixes. Voici les jours où la séquence tomberait à partir d\'aujourd\'hui; elle t\'attend si tu en manques un.';

  @override
  String get planNoExercisesYetDot => 'Aucun exercice pour l\'instant.';

  @override
  String get planRepeatOld =>
      'Les mêmes séances se répètent chaque semaine avec un jour de récupération entre elles. Les cibles sont des repères; c\'est ce que tu enregistres qui compte.';

  @override
  String get planRepeatRotation =>
      'La séquence se poursuit dans l\'ordre d\'une semaine à l\'autre; elle ne recommence jamais le lundi. Elle avance seulement quand tu termines ou sautes une séance. Les cibles sont des repères; c\'est ce que tu enregistres qui compte.';

  @override
  String get planRepeatFixed =>
      'Ces séances se répètent les mêmes jours chaque semaine. Les cibles sont des repères; c\'est ce que tu enregistres qui compte.';

  @override
  String planResumeTitle(String title) {
    return 'Reprendre $title';
  }

  @override
  String get planResumeAccept => 'Reprendre avec ces dates';

  @override
  String get planResumedToast => 'Programme repris.';

  @override
  String get planKeepPaused => 'Garder en pause';

  @override
  String get planNextWorkoutOn => 'Prochaine séance le';

  @override
  String get planResumeDateHelp => 'Date de reprise';

  @override
  String planResumeDisplaces(String title) {
    return 'Il devient ton programme principal et « $title » est mis en pause.';
  }

  @override
  String get planResumeNoChanges =>
      'Aucune date ne doit changer. Les séances restantes gardent leurs dates actuelles.';

  @override
  String get planResumeShifts =>
      'Chaque séance restante est décalée du même nombre de jours, en gardant son espacement. Les séances enregistrées, sautées et en cours gardent leurs dates.';

  @override
  String planBlockWouldEnd(String date) {
    return 'Le bloc se terminerait le $date.';
  }

  @override
  String planCloseOpenWorkout(String workout) {
    return 'Ta séance ouverte « $workout » peut encore être terminée ensuite; son résultat reste avec ce bloc.';
  }

  @override
  String get planBlockClosedToast => 'Bloc fermé. Ton historique est conservé.';

  @override
  String get planReviewBlock => 'Réviser ce bloc';

  @override
  String get planCountFinished => 'Terminées';

  @override
  String get planCountPartial => 'Partielles';

  @override
  String get planCountRemaining => 'À venir ou en cours';

  @override
  String get planCountsNote =>
      'Les totaux viennent de ce qui a vraiment été enregistré pour chaque séance prévue. Atteindre la date de fin ne veut pas dire à lui seul que l\'entraînement a eu lieu.';

  @override
  String get planBlockStoppedEarly => 'Ce bloc a été arrêté plus tôt.';

  @override
  String get planBlockFinished => 'Ce bloc a été terminé pour l\'instant.';

  @override
  String get planContinueGoal => 'Poursuivre cet objectif';

  @override
  String get planNextBlockStarts => 'Début du prochain bloc';

  @override
  String get planUnreachableNothingCreated =>
      'Impossible de joindre ton compte. Rien n\'a été créé.';

  @override
  String get planContinueNote =>
      'Crée un nouveau brouillon avec les mêmes réglages. Il ne commence pas avant que tu le révises et le commences.';

  @override
  String get planFinishForNow => 'Terminer pour l\'instant';

  @override
  String get planCloseBlockTitle => 'Fermer ce bloc?';

  @override
  String get planCloseBlockBody =>
      'Le bloc est fermé comme terminé pour l\'instant et ta place de programme principal est libérée. Cela ne veut pas dire que l\'objectif est atteint.';

  @override
  String get planCloseBlockAction => 'Fermer ce bloc';

  @override
  String get planStopEarly => 'Arrêter plus tôt';

  @override
  String get planStopTitle => 'Arrêter ce bloc plus tôt?';

  @override
  String planStopBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count séances prévues ne seront plus attendues. Le bloc est enregistré comme arrêté plus tôt, pas comme terminé.',
      one:
          '$count séance prévue ne sera plus attendue. Le bloc est enregistré comme arrêté plus tôt, pas comme terminé.',
    );
    return '$_temp0';
  }

  @override
  String get planStopAction => 'Arrêter ce bloc';

  @override
  String get planResumeAsPrimary => 'Reprendre comme programme principal';

  @override
  String get planDuplicateAsNew => 'Dupliquer en nouveau programme';

  @override
  String get planUnarchive => 'Sortir des archives';

  @override
  String get planArchiveHide => 'Archiver (masquer de cette liste)';

  @override
  String get planRestoredToast => 'Remis dans tes programmes.';

  @override
  String get planArchivedToast =>
      'Archivé. Son résultat et son historique sont inchangés.';

  @override
  String get planNotDone => 'Pas faite';

  @override
  String get planArchivedTitle => 'Programmes archivés';

  @override
  String get planArchivedNote =>
      'Archiver ne fait que masquer un programme. Son résultat et ses séances enregistrées sont inchangés.';

  @override
  String get planReplaceMovementTitle => 'Remplacer un mouvement';

  @override
  String get planShowChange => 'Montre-moi le changement';

  @override
  String get planUnreachableNothingChanged =>
      'Impossible de joindre ton compte. Rien n\'a été changé.';

  @override
  String get planProposalDeclinedUnchanged =>
      'Tu as déjà choisi de garder le programme actuel pour exactement ce changement.';

  @override
  String get planNothingToChange => 'Il n\'y a rien à changer pour ce choix.';

  @override
  String get planSubstitutionNote =>
      'Seules les séances restantes qui n\'ont pas été commencées sont touchées. Tu réviseras le changement exact avant qu\'il s\'applique.';

  @override
  String get planReplaceLabel => 'Remplacer';

  @override
  String get planNoMovement =>
      'Aucune séance restante n\'a de mouvement à remplacer.';

  @override
  String get planWith => 'Par';

  @override
  String get planChooseMovement => 'Choisis un mouvement';

  @override
  String get planReplaceWith => 'Remplacer par';

  @override
  String get planCustomNotInPlanChange =>
      'Choisis un mouvement dans la liste. Les mouvements personnalisés peuvent servir dans une séance, pas dans un changement de programme.';

  @override
  String get planChangeApplied => 'Changement appliqué aux séances révisées.';

  @override
  String get planKeptCurrent => 'Ton programme actuel est conservé.';

  @override
  String get planSuggestionStale =>
      'Cette suggestion ne correspond plus à ton programme ou à tes données : elle n\'a pas été appliquée. Rien n\'a changé.';

  @override
  String get planSuggestedChangeTitle => 'Changement suggéré';

  @override
  String get planAcceptChange => 'Accepter ce changement';

  @override
  String get planKeepCurrent => 'Garder le programme actuel';

  @override
  String get planDismissSuggestion => 'Ignorer cette suggestion';

  @override
  String get planProposalStaleLine =>
      'Ton programme ou tes séances enregistrées ont changé après cette suggestion : elle ne peut plus s\'appliquer telle que révisée. Redemande-la si tu la veux encore.';

  @override
  String get planAcceptedLine => 'Tu as accepté ce changement.';

  @override
  String get planDeclinedLine => 'Tu as gardé ton programme actuel.';

  @override
  String planAffects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Touche $count séances pas commencées',
      one: 'Touche $count séance pas commencée',
    );
    return '$_temp0';
  }

  @override
  String planProposalMove(String from, String to) {
    return 'Maintenant $from  →  proposée $to';
  }

  @override
  String planProposalNow(String from, String to) {
    return 'Maintenant : $from\nProposé : $to';
  }

  @override
  String get planProposalNote =>
      'Une suggestion ne change jamais les séances enregistrées ou en cours.';

  @override
  String get builderStepAvailability => 'Disponibilité';

  @override
  String get builderStepStructure => 'Structure';

  @override
  String get builderStepWorkouts => 'Séances';

  @override
  String get builderStepReview => 'Révision';

  @override
  String get builderStartOverTitle => 'Recommencer?';

  @override
  String get builderDiscardAction => 'Le supprimer';

  @override
  String get builderDiscardBody =>
      'Le programme en cours est supprimé de ce téléphone. Rien d\'autre ne change : aucun programme n\'a été créé à partir de lui.';

  @override
  String get builderCreatePlan => 'Créer un programme';

  @override
  String get builderUntitled => 'Programme sans nom';

  @override
  String builderStepSaved(int step, String name) {
    return 'Étape $step sur 4 · $name. Enregistré sur ce téléphone; rien n\'est encore actif.';
  }

  @override
  String get builderContinuePlan => 'Continuer ce programme';

  @override
  String get builderStartOver => 'Recommencer';

  @override
  String get builderStartOverSaid =>
      'Recommencer et supprimer ce programme en cours';

  @override
  String get builderBothWays =>
      'Les deux façons créent un programme bien à toi que tu peux changer en tout temps.';

  @override
  String get builderGuideMe => 'Guide-moi';

  @override
  String get builderGuideMeAbout =>
      'Aide-moi à choisir un programme de départ.';

  @override
  String get builderKnowWhat => 'Je sais ce que je veux';

  @override
  String get builderKnowWhatAbout => 'Choisir un modèle ou créer le mien.';

  @override
  String builderChoiceSemantics(String label, String about) {
    return '$label. $about';
  }

  @override
  String get builderFromTemplate => 'Partir d\'un modèle';

  @override
  String get builderFromTemplateSubtitle =>
      'Aperçois une répartition connue comme Haut / Bas ou Poussée / Tirage / Jambes, puis adapte-la.';

  @override
  String get builderBuildOwn => 'Créer le mien';

  @override
  String get builderBuildOwnSubtitle =>
      'Nomme tes séances, ajoute des exercices et organise ta semaine.';

  @override
  String get builderPlanChanged =>
      'Ce programme a changé depuis ta dernière modification, donc tu repars du programme tel qu\'il est maintenant.';

  @override
  String get builderContinueChangesTitle => 'Continuer tes changements?';

  @override
  String get builderContinueChanges => 'Continuer les changements';

  @override
  String get builderStartFromSaved => 'Partir du programme enregistré';

  @override
  String builderContinueChangesBody(String title) {
    return 'Tu modifiais « $title » sans enregistrer. Continue là où tu étais, ou recommence à partir du programme tel qu\'il est maintenant.';
  }

  @override
  String get builderReplaceInProgressTitle =>
      'Remplacer ton programme en cours?';

  @override
  String get builderReplaceIt => 'Le remplacer';

  @override
  String builderReplaceInProgressBody(String existing, String plan) {
    return '« $existing » n\'est pas terminé. Dupliquer « $plan » le remplace sur ce téléphone.';
  }

  @override
  String get builderSaveFailed =>
      'Le dernier changement n\'a pas pu être enregistré sur ce téléphone. Garde cet écran ouvert et réessaie.';

  @override
  String get builderHelpWeek => 'Aide pour ta semaine d\'entraînement';

  @override
  String get builderCoachWeek =>
      'Choisis les jours où tu peux t\'entraîner et ton équipement. L\'étape suivante suggère un point de départ selon ces réponses.';

  @override
  String get builderAskWeek => 'Ta semaine d\'entraînement';

  @override
  String get builderHelpSplit => 'Aide pour choisir une répartition';

  @override
  String get builderCoachSplit =>
      'Pas certain de la répartition qui convient à ta semaine? Comparons tes options.';

  @override
  String get builderAskSplit => 'Choisir une répartition';

  @override
  String get builderCompareSplits => 'Comparer les répartitions';

  @override
  String get builderHelpWorkouts => 'Aide pour ces séances';

  @override
  String get builderCoachWorkouts =>
      'Des questions sur les séries, les répétitions ou un mouvement? Le bouton d\'info à côté de chaque exercice ouvre le guide intégré.';

  @override
  String get builderChooseDay => 'Choisis au moins un jour.';

  @override
  String get builderChooseStarting =>
      'Choisis un programme de départ pour continuer.';

  @override
  String builderPauseActivateTitle(String title) {
    return 'Mettre $title en pause et activer ce programme?';
  }

  @override
  String get builderPauseActivate => 'Mettre en pause et activer';

  @override
  String builderPauseActivateBody(String current, String plan, String date) {
    return '« $current » sera mis en pause, pas supprimé. Son historique et ses séances enregistrées sont conservés, et tu pourras le reprendre plus tard. « $plan » devient ton programme à partir du $date.';
  }

  @override
  String builderOpenWorkoutStays(String workout) {
    return 'Ta séance ouverte « $workout » reste ouverte avec ses séries enregistrées.';
  }

  @override
  String builderActiveStarts(String title, String date) {
    return '« $title » est actif. Il commence le $date.';
  }

  @override
  String builderActive(String title) {
    return '« $title » est actif.';
  }

  @override
  String get builderDraftSaved =>
      'Brouillon enregistré sur ce téléphone. Rien n\'est encore actif.';

  @override
  String get builderChangesSaved => 'Changements enregistrés.';

  @override
  String builderChangesSavedFrom(String date) {
    return 'Changements enregistrés à partir du $date.';
  }

  @override
  String get builderBack => 'Retour';

  @override
  String get builderNext => 'Suivant';

  @override
  String get builderSaveChanges => 'Enregistrer les changements';

  @override
  String get builderActivate => 'Activer le programme';

  @override
  String get builderSaveDraft => 'Enregistrer le brouillon';

  @override
  String builderProgressSemantics(int step, String name) {
    return 'Étape $step sur 4 : $name';
  }

  @override
  String builderProgressOverline(int step, String name) {
    return 'Étape $step sur 4 · $name';
  }

  @override
  String builderDefaultWorkoutName(String letter) {
    return 'Séance $letter';
  }

  @override
  String get builderPrefsGuided =>
      'Réponds à ces questions et l\'étape suivante suggère un programme de départ, avec jusqu\'à deux options. Rien n\'est créé avant ton choix, et tu pourras tout changer plus tard.';

  @override
  String get builderPrefsIntro =>
      'Quelques réponses pour suggérer un point de départ. Tu pourras tout changer plus tard.';

  @override
  String get builderDaysAWeek => 'Jours par semaine';

  @override
  String builderDaysAWeekCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours par semaine',
      one: '$count jour par semaine',
    );
    return '$_temp0';
  }

  @override
  String get builderWhichDays => 'Quels jours';

  @override
  String get builderEquipment => 'Équipement';

  @override
  String get builderPlannedTime => 'Durée prévue par séance (facultatif)';

  @override
  String get builderNoLimit => 'Sans limite';

  @override
  String get builderPlannedTimeNote =>
      'Le temps que tu prévois y passer. C\'est ton choix, pas une durée calculée de la séance.';

  @override
  String get builderAddExperience =>
      'Ajouter ton expérience d\'entraînement (facultatif)';

  @override
  String get builderExperience => 'Expérience d\'entraînement (facultatif)';

  @override
  String get builderReplaceWorkoutsTitle => 'Remplacer tes séances?';

  @override
  String get builderReplaceThem => 'Les remplacer';

  @override
  String builderReplaceWorkoutsBody(String source, String now, String next) {
    return 'Les séances repartent de $source.\n\nMaintenant : $now\nAprès : $next\n\nLes changements faits aux exercices ne sont pas conservés.';
  }

  @override
  String get builderYourOwnNames => 'tes propres noms';

  @override
  String get builderUsingStarting =>
      'Ce programme de départ est utilisé. C\'est un brouillon : change ce que tu veux aux étapes suivantes.';

  @override
  String get builderUseStarting => 'Utiliser ce programme de départ';

  @override
  String builderAnswersChanged(String name) {
    return 'Tes réponses suggèrent maintenant $name. Tes séances modifiées restent telles quelles sauf si tu choisis Utiliser ce programme de départ ci-dessous.';
  }

  @override
  String get builderSuggestedStarting => 'Programme de départ suggéré';

  @override
  String get builderYourWeek => 'Ta semaine';

  @override
  String get builderWhySuggestion => 'Pourquoi cette suggestion?';

  @override
  String get builderOtherStartingPoints => 'Autres points de départ';

  @override
  String get builderAlsoFits => 'Convient aussi à tes jours';

  @override
  String get builderRest => 'Repos';

  @override
  String get builderRestSubtitle => 'Aucune séance ce jour-là';

  @override
  String get builderAddStep => 'Ajouter une étape';

  @override
  String get builderPlanLength => 'Durée du programme';

  @override
  String get builderWeeks => 'Semaines';

  @override
  String get builderWeeksHelper => 'De 1 à 52 semaines';

  @override
  String get builderWeeksError => 'Choisis de 1 à 52 semaines.';

  @override
  String get builderUseLength => 'Utiliser cette durée';

  @override
  String get builderTemplateCustomPreview =>
      'Nomme tes propres séances et choisis leurs jours.';

  @override
  String builderTemplateWeekly(int count, String names) {
    return 'Tes $count jours : $names';
  }

  @override
  String builderTemplateRotates(String names, int count) {
    return 'Alterne $names sur tes $count jours';
  }

  @override
  String builderSuggestedLine(String name, String reason) {
    return 'Suggéré : $name. $reason';
  }

  @override
  String builderTemplateSuggested(String name) {
    return '$name · Suggéré';
  }

  @override
  String get builderIncludeExercises => 'Inclure des exercices de départ';

  @override
  String get builderWithExercisesOn =>
      'Une routine de départ avec séries, répétitions et repos, sans charges. Change ce que tu veux à l\'étape suivante.';

  @override
  String get builderWithExercisesOff =>
      'Les séances commencent vides. Le programme reste un brouillon tant que chaque séance prévue n\'a pas d\'exercice.';

  @override
  String get builderYourWorkouts => 'Tes séances';

  @override
  String get builderNameOnce =>
      'Nomme une seule fois chaque séance différente. Une séance peut se répéter plusieurs jours.';

  @override
  String builderWorkoutN(int n) {
    return 'Séance $n';
  }

  @override
  String builderWorkoutNLower(int n) {
    return 'séance $n';
  }

  @override
  String get builderGiveName => 'Donne-lui un nom.';

  @override
  String builderRemoveNamed(String name) {
    return 'Retirer $name';
  }

  @override
  String builderRemoveTitle(String name) {
    return 'Retirer $name?';
  }

  @override
  String get builderRemoveBody =>
      'Ses exercices sont retirés avec elle, ainsi que chaque jour ou étape qui l\'utilisait.';

  @override
  String get builderAddAWorkout => 'Ajouter une séance';

  @override
  String get builderFixedNote =>
      'Une séance par jour de la semaine. Une séance peut servir plusieurs jours. Une séance manquée reste à son jour jusqu\'à ce que tu la déplaces ou la sautes.';

  @override
  String get builderTheCycle => 'Le cycle';

  @override
  String get builderCycleNote =>
      'Les séances suivent cet ordre et reprennent du début à la fin. L\'ordre se poursuit d\'une semaine à l\'autre; il ne recommence pas le lundi.';

  @override
  String builderMoveStepUp(int n) {
    return 'Monter l\'étape $n';
  }

  @override
  String builderMoveStepDown(int n) {
    return 'Descendre l\'étape $n';
  }

  @override
  String builderRemoveStep(int n) {
    return 'Retirer l\'étape $n';
  }

  @override
  String get builderTrainingDays => 'Jours d\'entraînement';

  @override
  String get builderTrainingDaysNote =>
      'La prochaine séance va au prochain de ces jours. Si aucun n\'est choisi, n\'importe quel jour peut être un jour d\'entraînement.';

  @override
  String get builderPlanName => 'Nom du programme';

  @override
  String get builderName => 'Nom';

  @override
  String get builderSchedule => 'Horaire';

  @override
  String get builderModeLocked =>
      'Un programme actif garde son type d\'horaire. Duplique-le pour changer.';

  @override
  String get builderFixedExplain =>
      'Jours fixes : chaque séance a son propre jour, et une séance manquée reste à son jour.';

  @override
  String get builderRotatingExplain =>
      'Séquence en rotation : un cycle ordonné qui se poursuit d\'une semaine à l\'autre et avance seulement quand tu termines ou sautes une séance.';

  @override
  String get builderStartAndLength => 'Début et durée';

  @override
  String get builderStarts => 'Commence';

  @override
  String get builderStartLocked => 'Un programme actif garde sa date de début.';

  @override
  String get builderPlanStartsHelp => 'Début du programme';

  @override
  String get builderOtherLength => 'Autre durée';

  @override
  String get builderRotationLength =>
      'Une rotation peut durer de 1 à 52 semaines, ou continuer sans fin.';

  @override
  String get builderFixedLength =>
      'Un programme à jours fixes a une fin : de 1 à 52 semaines.';

  @override
  String builderFromDate(String date) {
    return 'À partir du $date';
  }

  @override
  String get builderSecondWeek => 'Deuxième semaine';

  @override
  String builderReviewSummary(int count, String weeks, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count séances sur $weeks, la dernière le $date. La même semaine se répète jusque-là.',
      one:
          '$count séance sur $weeks, la dernière le $date. La même semaine se répète jusque-là.',
    );
    return '$_temp0';
  }

  @override
  String builderCycleThenAgain(String names) {
    return 'Cycle : $names, puis il recommence.';
  }

  @override
  String get builderAnyDayTraining =>
      'N\'importe quel jour peut être un jour d\'entraînement.';

  @override
  String builderTrainingDaysDot(String days) {
    return 'Jours d\'entraînement : $days.';
  }

  @override
  String get builderNextIfTrain =>
      'Prochaines séances si tu t\'entraînes chaque jour d\'entraînement';

  @override
  String get builderProjectionNote =>
      'Ces dates sont une projection. Un jour manqué ne saute pas de séance : la même t\'attend à ton prochain jour d\'entraînement.';

  @override
  String builderPlannedTimeLower(int minutes) {
    return 'durée prévue $minutes min';
  }

  @override
  String builderDraftMissing(String names) {
    return 'Brouillon — ajoute des exercices à $names avant de pouvoir activer ce programme.';
  }

  @override
  String builderFollowingActivate(String title) {
    return 'Tu suis « $title ». Activer ce programme le met en pause. Son historique et ses séances enregistrées sont conservés, et tu pourras le reprendre plus tard.';
  }

  @override
  String get builderChangesApplyFrom =>
      'Les changements s\'appliquent à partir du';

  @override
  String get builderEditKeeps =>
      'Les séances enregistrées ou sautées, et celle en cours, restent exactement telles quelles. Les séances antérieures et celles modifiées individuellement ne changent pas.';

  @override
  String get builderRebuilt =>
      'Ce programme n\'a pas commencé, il est donc refait avec ces changements.';

  @override
  String get builderNoExercises => 'Aucun exercice pour l\'instant';

  @override
  String get builderTargetsNote =>
      'Les cibles sont un point de départ, pas une prescription. C\'est ce que tu enregistres qui compte.';

  @override
  String builderUsageSteps(int count, String steps) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Étapes $steps',
      one: 'Étape $steps',
    );
    return '$_temp0';
  }

  @override
  String get builderRxSetsError => 'Séries : un nombre entier de 1 à 20.';

  @override
  String get builderRxRepsError => 'Répétitions : de 1 à 100.';

  @override
  String get builderRxRepsOrder =>
      'Le maximum de répétitions ne peut pas être inférieur au minimum.';

  @override
  String get builderRxTimeError => 'Temps : de 1 à 3600 secondes.';

  @override
  String get builderRxRestError => 'Repos : de 0 à 900 secondes (15 minutes).';

  @override
  String builderRxLoadError(String max) {
    return 'Une charge de 0 à $max, ou laisse vide.';
  }

  @override
  String get builderRxNotesError => 'Notes : 500 caractères au plus.';

  @override
  String get builderRxHelp =>
      'Aide sur les séries, les répétitions et cet exercice';

  @override
  String get builderRxSets => 'Séries';

  @override
  String get builderRxSeconds => 'Temps par série (secondes)';

  @override
  String get builderRxRepsMin => 'Répétitions, minimum';

  @override
  String get builderRxRepsMax => 'Répétitions, maximum';

  @override
  String get builderRxRepsHelper =>
      'Le même nombre deux fois donne une cible exacte.';

  @override
  String get builderRxRest => 'Repos entre les séries (secondes)';

  @override
  String builderRxLoad(String unit) {
    return 'Charge cible ($unit), facultatif';
  }

  @override
  String get builderRxLoadHelper =>
      'Une cible que tu te fixes. Ce n\'est pas ta dernière charge enregistrée, et l\'appli ne la remplit jamais.';

  @override
  String get builderRxNotes => 'Notes, facultatif';

  @override
  String get builderCoachExercise =>
      'Des questions sur les séries, les répétitions ou ce mouvement?';

  @override
  String get builderAboutExercise => 'À propos de cet exercice';

  @override
  String builderReplaceExercise(String name) {
    return 'Remplacer $name';
  }

  @override
  String get builderNoExercisesWarn =>
      'Aucun exercice pour l\'instant. Ajoutes-en au moins un pour que cette séance puisse être prévue.';

  @override
  String get builderEditRx =>
      'Modifier les séries, les répétitions et le repos';

  @override
  String builderAbout(String name) {
    return 'À propos de $name';
  }

  @override
  String builderMoveUp(String name) {
    return 'Monter $name';
  }

  @override
  String builderMoveDown(String name) {
    return 'Descendre $name';
  }

  @override
  String builderMoreFor(String name) {
    return 'Plus pour $name';
  }

  @override
  String get builderReplaceWithAnother => 'Remplacer par un autre exercice';

  @override
  String get builderAddExercise => 'Ajouter un exercice';

  @override
  String builderAddTo(String name) {
    return 'Ajouter à $name';
  }

  @override
  String get builderCopyWorkout => 'Copier une séance';

  @override
  String get builderCopyNote =>
      'La copie devient une nouvelle séance de ce programme avec les mêmes exercices. Rien ne la relie à sa source.';

  @override
  String get builderThisPlan => 'Ce programme';

  @override
  String get builderRecordedSection =>
      'Séances enregistrées (leurs exercices prévus)';

  @override
  String get builderCopied =>
      'Copiée. Choisis ses jours dans Structure pour la prévoir.';

  @override
  String get builderWorkoutsIntro =>
      'Touche un exercice pour changer ses séries, répétitions et repos. Les cibles sont un point de départ; c\'est ce que tu enregistres qui compte.';

  @override
  String get builderNotScheduled =>
      'Pas encore prévue. Choisis ses jours dans Structure.';

  @override
  String get builderRename => 'Renommer';

  @override
  String get builderDuplicate => 'Dupliquer';

  @override
  String get builderRenameWorkout => 'Renommer la séance';

  @override
  String builderDeleteTitle(String name) {
    return 'Supprimer $name?';
  }

  @override
  String get builderDeleteWorkout => 'Supprimer la séance';

  @override
  String get builderDeleteBody =>
      'Elle est retirée de ce programme et de chaque jour ou étape qui l\'utilise. Les séances déjà enregistrées gardent leur propre copie.';

  @override
  String get builderAddWorkout => 'Ajouter la séance';

  @override
  String get builderNewWorkout => 'Nouvelle séance';

  @override
  String get builderCopyFrom => 'Copier depuis…';

  @override
  String get builderGiveWorkoutName => 'Donne un nom à la séance.';

  @override
  String builderSavedOnly(String date) {
    return 'Enregistrée pour le $date seulement.';
  }

  @override
  String get builderThisWorkoutOnly => 'Cette séance seulement';

  @override
  String get builderSaveThisWorkout => 'Enregistrer cette séance';

  @override
  String builderOnlyThisChanges(String date, String plan) {
    return 'Seule la séance du $date change. Le reste de « $plan » reste tel quel, et les changements futurs au programme ne touchent pas celle-ci.';
  }

  @override
  String get builderWorkoutName => 'Nom de la séance';

  @override
  String runActivityTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche',
      'other': 'Course',
    });
    return '$_temp0';
  }

  @override
  String get runTitle => 'Course / Marche';

  @override
  String get runHistory => 'Historique';

  @override
  String get runHelpAvatar => 'Aide pour Course / Marche';

  @override
  String get runCoachReadyIntervals =>
      'Les intervalles sont réglés. Commence quand tu es prêt.';

  @override
  String get runCoachReady =>
      'Choisis tes réglages. Commence quand tu es prêt.';

  @override
  String get runHelpBody =>
      'Choisis Course ou Marche, puis Commencer. GoHard enregistre ton parcours même quand l\'écran est verrouillé ou qu\'une autre appli est ouverte, et le garde d\'abord sur ce téléphone. Mets en pause quand tu veux; Terminer te laisse vérifier avant d\'enregistrer. Les intervalles alternent course et marche dans une seule activité; avec Voix et alertes activées, j\'annonce chaque changement à voix haute.';

  @override
  String runStartButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Commencer la marche',
      'other': 'Commencer la course',
    });
    return '$_temp0';
  }

  @override
  String runStartIntervalsButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Commencer les intervalles de marche',
      'other': 'Commencer les intervalles de course',
    });
    return '$_temp0';
  }

  @override
  String get runStartNoGpsTitle => 'Commencer sans GPS?';

  @override
  String get runStartNoGpsBody =>
      'Le temps est enregistré, et tu pourras saisir une distance à la fin. Aucun parcours ni distance GPS n\'est enregistré.';

  @override
  String get runStartNoGpsAction => 'Chronomètre seulement';

  @override
  String runStartFailed(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'La marche n\'a pas pu commencer sur ce téléphone. Rien n\'a été enregistré.',
      'other': 'La course n\'a pas pu commencer sur ce téléphone. Rien n\'a été enregistré.',
    });
    return '$_temp0';
  }

  @override
  String get runStateOn => 'Activé';

  @override
  String get runStateOff => 'Désactivé';

  @override
  String runVoiceValueEvery(String interval) {
    return 'Activé · chaque $interval';
  }

  @override
  String get runMapNoPosition => 'Carte, pas encore de position';

  @override
  String get runMapHere => 'Carte montrant ta position actuelle';

  @override
  String get runMapTitle => 'Carte';

  @override
  String get runSimulatedGps => 'GPS simulé (version de test)';

  @override
  String get runSetupTitle => 'Tes réglages';

  @override
  String get runSetupIntervals => 'Intervalles';

  @override
  String get runSetupVoice => 'Voix et alertes';

  @override
  String get runSetupAutoPause => 'Pause automatique';

  @override
  String get runAutoPauseNotWithIntervals =>
      'Non utilisée avec les intervalles';

  @override
  String get runAutoPauseSubtitle =>
      'Met en pause quand tu t\'arrêtes un moment et reprend quand tu repars.';

  @override
  String get runAutoPauseIntervalsNote =>
      'Non utilisée avec les intervalles : marcher pour récupérer n\'est pas une pause. Ce choix s\'applique à tes courses et marches libres.';

  @override
  String runPlanShort(String run, String walk, int reps) {
    return 'Course $run · Marche $walk · × $reps';
  }

  @override
  String get runGpsChecking => 'Vérification du GPS…';

  @override
  String get runGpsCheckingDetail =>
      'Lecture des réglages de localisation de ce téléphone.';

  @override
  String get runGpsOff => 'La localisation est désactivée';

  @override
  String get runGpsOffDetail =>
      'Active la localisation pour enregistrer un parcours.';

  @override
  String get runGpsOpenSettings => 'Ouvrir les réglages';

  @override
  String get runGpsNotAllowed => 'Localisation pas encore autorisée';

  @override
  String get runGpsNotAllowedDetail =>
      'Autorise la localisation pendant l\'utilisation de GoHard pour enregistrer ton parcours.';

  @override
  String get runGpsAllow => 'Autoriser';

  @override
  String get runGpsBlocked => 'La localisation est bloquée pour GoHard';

  @override
  String get runGpsBlockedDetail =>
      'Autorise-la dans les Réglages, ou commence avec le chronomètre seulement.';

  @override
  String get runGpsOpenAppSettings => 'Ouvrir les réglages de l\'appli';

  @override
  String get runGpsApproximate => 'La position exacte est désactivée';

  @override
  String get runGpsApproximateDetail =>
      'Une position approximative ne peut pas mesurer un parcours.';

  @override
  String get runGpsAllowPrecise => 'Autoriser la position exacte';

  @override
  String get runGpsUnavailable => 'La localisation n\'est pas disponible';

  @override
  String get runGpsUnavailableDetail =>
      'Tu peux quand même commencer avec le chronomètre seulement.';

  @override
  String get runGpsWaiting => 'En attente du GPS…';

  @override
  String get runGpsWaitingDetail =>
      'Dehors, avec une vue dégagée du ciel, cela prend quelques secondes.';

  @override
  String get runGpsReady => 'GPS prêt';

  @override
  String get runGpsWeak => 'Signal GPS faible';

  @override
  String get runGpsSignalGood => 'Bon signal';

  @override
  String get runGpsSignalFair => 'Signal moyen';

  @override
  String get runGpsSignalWeak => 'Signal faible';

  @override
  String runGpsAccuracyDetail(String quality, String accuracy) {
    return '$quality · précision $accuracy';
  }

  @override
  String get runStatusPaused => 'En pause';

  @override
  String get runStatusAutoPaused => 'Pause automatique';

  @override
  String get runStatusInterrupted => 'Interrompue';

  @override
  String get runMapRouteSoFar => 'Parcours jusqu\'ici';

  @override
  String runMapRouteSoFarDistance(String distance) {
    return 'Parcours jusqu\'ici, $distance';
  }

  @override
  String get runFinish => 'Terminer';

  @override
  String get runResume => 'Reprendre';

  @override
  String get runPause => 'Pause';

  @override
  String runInterruptedLegacy(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Cette marche a commencé avant que les parcours soient gardés. Son temps et sa distance jusqu\'ici sont conservés; reprends pour enregistrer la suite avec un parcours.',
      'other': 'Cette course a commencé avant que les parcours soient gardés. Son temps et sa distance jusqu\'ici sont conservés; reprends pour enregistrer la suite avec un parcours.',
    });
    return '$_temp0';
  }

  @override
  String get runInterrupted =>
      'L\'enregistrement s\'est arrêté à la fermeture de GoHard. Le temps écoulé depuis n\'est pas compté. Reprends pour continuer, ou Termine pour l\'enregistrer.';

  @override
  String get runTimerOnlyNote =>
      'Chronomètre seulement : aucun parcours ni distance GPS n\'est enregistré. Tu pourras saisir une distance à la fin.';

  @override
  String get runNotSaving =>
      'Ce téléphone n\'enregistre pas l\'activité pour l\'instant. Garde GoHard ouvert; il continue d\'essayer.';

  @override
  String get runGpsStopped =>
      'Le GPS ne donne plus de position. Le chronomètre continue; la distance reprendra avec le GPS.';

  @override
  String get runVoiceToggleOn => 'Annonces vocales activées. Désactiver';

  @override
  String get runVoiceToggleOff => 'Annonces vocales désactivées. Activer';

  @override
  String runHelpRecording(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Aide pour enregistrer une marche',
      'other': 'Aide pour enregistrer une course',
    });
    return '$_temp0';
  }

  @override
  String get runViewStats => 'Stats';

  @override
  String get runSteps => 'Pas';

  @override
  String get runStepsPartly => 'Pas (en partie)';

  @override
  String get runStepsNotCounted => 'Pas non comptés';

  @override
  String get runStepsPartOfTime => 'Pas (une partie du temps)';

  @override
  String get runActiveTime => 'Temps actif';

  @override
  String runActiveTimeSaid(String duration) {
    return 'Temps actif $duration';
  }

  @override
  String runActiveTimePausedSaid(String duration) {
    return 'Temps actif $duration, en pause';
  }

  @override
  String runFigureSaid(String label, String value) {
    return '$label $value';
  }

  @override
  String runFigureSaidUnknown(String label) {
    return '$label inconnue';
  }

  @override
  String get runDistance => 'Distance';

  @override
  String get runAvgMovingPace => 'Allure moy. en mouvement';

  @override
  String get runChipTimerOnly => 'Chronomètre seul';

  @override
  String get runChipGpsOff => 'GPS désactivé';

  @override
  String get runChipGpsLost => 'GPS perdu';

  @override
  String get runChipWaiting => 'En attente du GPS';

  @override
  String runChipGps(String accuracy) {
    return 'GPS · $accuracy';
  }

  @override
  String runTitleMorning(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche du matin',
      'other': 'Course du matin',
    });
    return '$_temp0';
  }

  @override
  String runTitleAfternoon(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche de l\'après-midi',
      'other': 'Course de l\'après-midi',
    });
    return '$_temp0';
  }

  @override
  String runTitleEvening(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche du soir',
      'other': 'Course du soir',
    });
    return '$_temp0';
  }

  @override
  String runTitleNight(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche de nuit',
      'other': 'Course de nuit',
    });
    return '$_temp0';
  }

  @override
  String runSaveTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Enregistre ta marche',
      'other': 'Enregistre ta course',
    });
    return '$_temp0';
  }

  @override
  String runSaveButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Enregistrer la marche',
      'other': 'Enregistrer la course',
    });
    return '$_temp0';
  }

  @override
  String get runRecordedRoute => 'Parcours enregistré';

  @override
  String runNoRouteFor(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Aucun parcours GPS n\'a été enregistré pour cette marche.',
      'other': 'Aucun parcours GPS n\'a été enregistré pour cette course.',
    });
    return '$_temp0';
  }

  @override
  String get runRouteNotRecordedLine => 'Parcours non enregistré.';

  @override
  String get runRouteNotRecorded => 'Parcours non enregistré';

  @override
  String get runDistanceNotMeasured => 'Distance non mesurée';

  @override
  String get runMovingTime => 'Temps en mouvement';

  @override
  String runMovingTimeSaid(String duration) {
    return 'Temps en mouvement $duration';
  }

  @override
  String get runTitleField => 'Titre';

  @override
  String get runNotesOptional => 'Notes (facultatif)';

  @override
  String get runNotesField => 'Notes';

  @override
  String get runDistanceOptional => 'Distance (facultatif)';

  @override
  String get runCorrectDistance => 'Corriger la distance (facultatif)';

  @override
  String get runDistanceTypedHelper => 'Saisie, non mesurée par GPS.';

  @override
  String get runDistanceGpsKeptHelper =>
      'La mesure GPS est gardée à côté; le parcours ne change pas.';

  @override
  String runBlankKeepsGps(String distance) {
    return 'Vide, la mesure GPS est gardée ($distance).';
  }

  @override
  String get runResumeRecording => 'Reprendre l\'enregistrement';

  @override
  String runDiscardButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Supprimer la marche',
      'other': 'Supprimer la course',
    });
    return '$_temp0';
  }

  @override
  String runDiscardTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Supprimer cette marche?',
      'other': 'Supprimer cette course?',
    });
    return '$_temp0';
  }

  @override
  String runDiscardBody(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'La marche et son parcours sont supprimés de ce téléphone et de ton compte. C\'est irréversible.',
      'other': 'La course et son parcours sont supprimés de ce téléphone et de ton compte. C\'est irréversible.',
    });
    return '$_temp0';
  }

  @override
  String get runDistanceInvalid =>
      'Saisis la distance en chiffres, ou laisse le champ vide.';

  @override
  String get runTitleInvalid => 'Donne-lui un titre de 1 à 80 caractères.';

  @override
  String get runTitleRequired => 'Donne-lui un titre.';

  @override
  String get runSaveFailed =>
      'L\'enregistrement a échoué sur ce téléphone. Rien n\'a été perdu; réessaie Enregistrer.';

  @override
  String get runIntervalsIntro =>
      'Alterne course et marche. Marcher pour récupérer fait partie de la séance, ce n\'est pas une pause : c\'est une seule activité.';

  @override
  String get runIntervalsPresetNote =>
      'Point de départ : course 1 min, marche 1 min 30, 8 fois, comme la semaine 1 du programme Couch to 5K du NHS. Change ce que tu veux.';

  @override
  String get runIntervalsUsePreset => 'L\'utiliser';

  @override
  String get runIntervalWarmup => 'Marche d\'échauffement';

  @override
  String get runIntervalRun => 'Course';

  @override
  String get runIntervalWalk => 'Marche / récupération';

  @override
  String get runIntervalRepeats => 'Répétitions';

  @override
  String get runIntervalCooldown => 'Marche de retour au calme';

  @override
  String get runIntervalNone => 'Aucun';

  @override
  String get runIntervalNoneSaid => 'aucun';

  @override
  String runIntervalRepsValue(int count) {
    return '$count ×';
  }

  @override
  String runIntervalRepsSaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fois',
      one: '$count fois',
    );
    return '$_temp0';
  }

  @override
  String runIntervalLess(String label) {
    return 'Réduire : $label';
  }

  @override
  String runIntervalMore(String label) {
    return 'Augmenter : $label';
  }

  @override
  String runIntervalTotal(String time) {
    return 'Temps actif prévu $time';
  }

  @override
  String get runIntervalsUse => 'Utiliser ces intervalles';

  @override
  String get runIntervalsOff => 'Désactiver les intervalles';

  @override
  String runPlanWarmup(String time) {
    return '$time d\'échauffement';
  }

  @override
  String runPlanRepeats(int reps, String run, String walk) {
    return '$reps × course $run, marche $walk';
  }

  @override
  String runPlanCooldown(String time) {
    return '$time de retour au calme';
  }

  @override
  String get runPhaseWarmup => 'Échauffement';

  @override
  String get runPhaseRun => 'Course';

  @override
  String get runPhaseWalk => 'Marche';

  @override
  String get runPhaseCooldown => 'Retour au calme';

  @override
  String runSpokenSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secondes',
      one: '$count seconde',
    );
    return '$_temp0';
  }

  @override
  String runSpokenMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String runSpokenMinutesSeconds(String minutes, String seconds) {
    return '$minutes $seconds';
  }

  @override
  String runRoundOf(int round, int total) {
    return 'Tour $round sur $total';
  }

  @override
  String get runSkipPhase => 'Passer la phase';

  @override
  String runTimeLeft(String time) {
    return '$time restant';
  }

  @override
  String runNextPhase(String phase, String time) {
    return 'Ensuite : $phase $time';
  }

  @override
  String runNextPhaseSaid(String phase) {
    return 'Ensuite : $phase';
  }

  @override
  String get runIntervalsFinished => 'Intervalles terminés';

  @override
  String get runIntervalsStillRecording =>
      'L\'enregistrement continue. Poursuis librement, ou termine et vérifie.';

  @override
  String get runContinueFreely => 'Continuer librement';

  @override
  String get runFinishAndReview => 'Terminer et vérifier';

  @override
  String get runCueIntervalsDone =>
      'Intervalles terminés. Continue librement, ou termine et vérifie.';

  @override
  String get runCueIntervalsFinished => 'Intervalles terminés.';

  @override
  String runCueWarmup(String duration) {
    return 'Échauffement : marche pendant $duration.';
  }

  @override
  String runCueRun(String duration) {
    return 'Cours pendant $duration.';
  }

  @override
  String runCueFinalRun(String duration) {
    return 'Dernier tour. Cours pendant $duration.';
  }

  @override
  String runCueWalk(String duration) {
    return 'Marche et récupère pendant $duration.';
  }

  @override
  String runCueCooldown(String duration) {
    return 'Retour au calme : marche pendant $duration.';
  }

  @override
  String runCueDistanceDone(String distance) {
    return '$distance parcourus.';
  }

  @override
  String runCueActiveTime(String time) {
    return 'Temps actif $time.';
  }

  @override
  String runCuePace(String pace) {
    return 'Allure moy. en mouvement $pace.';
  }

  @override
  String runCueMinutesActive(int minutes) {
    return '$minutes min d\'activité.';
  }

  @override
  String runSaidKilometres(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kilomètres',
      one: '$count kilomètre',
    );
    return '$_temp0';
  }

  @override
  String runSaidMiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count milles',
      one: '$count mille',
    );
    return '$_temp0';
  }

  @override
  String runSaidKilometresDecimal(String value) {
    return '$value kilomètres';
  }

  @override
  String runSaidMilesDecimal(String value) {
    return '$value milles';
  }

  @override
  String runSaidActiveTime(String duration) {
    return 'Temps actif $duration.';
  }

  @override
  String runSaidPace(String unit, String duration) {
    String _temp0 = intl.Intl.selectLogic(unit, {
      'mi': 'Allure moyenne en mouvement $duration par mille.',
      'other': 'Allure moyenne en mouvement $duration par kilomètre.',
    });
    return '$_temp0';
  }

  @override
  String runSaidMinutesActive(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes d\'activité.',
      one: '$minutes minute d\'activité.',
    );
    return '$_temp0';
  }

  @override
  String runVoicePreviewLine(String name) {
    return 'Salut, je suis $name. Je te dirai quand courir, quand marcher et quelle distance tu as parcourue.';
  }

  @override
  String get runVoiceUpdates => 'Annonces vocales';

  @override
  String runVoiceUpdatesSubtitle(String guide, String name) {
    return '$name annonce à voix haute les changements d\'intervalle, les mises à jour et les records personnels, avec une voix installée sur ce téléphone. Rien n\'est envoyé.';
  }

  @override
  String get runVoiceUpdatesLabel => 'Mises à jour';

  @override
  String get runVoiceUpdatesNone => 'Aucune';

  @override
  String get runVoiceUpdatesDistance => 'Distance';

  @override
  String get runVoiceUpdatesTime => 'Temps';

  @override
  String get runVoiceUpdatesExplain =>
      'Chaque mise à jour annonce la distance, le temps actif et l\'allure moyenne en mouvement (temps en mouvement ÷ distance), seulement quand le GPS a assez mesuré.';

  @override
  String get runVoiceField => 'Voix';

  @override
  String get runVoiceMissing =>
      'La voix choisie avant n\'est pas installée ou demande une connexion : une voix de ce téléphone est utilisée.';

  @override
  String get runVoiceNoneForLanguage =>
      'Aucune voix en français fonctionnant hors ligne n\'est installée : rien n\'est dit à voix haute. Les annonces restent affichées à l\'écran et la vibration fonctionne toujours.';

  @override
  String get runVoiceOfflineOnly =>
      'Seules les voix qui fonctionnent sans connexion sont proposées.';

  @override
  String get runVoicePhoneDefault => 'La voix du téléphone';

  @override
  String get runVoicePreview => 'Écouter la voix';

  @override
  String get runVoiceVibrate => 'Vibrer aux changements d\'intervalle';

  @override
  String get runVoiceVibrateSubtitle =>
      'Aussi écran verrouillé sur Android. Sur iPhone, quand GoHard est ouvert.';

  @override
  String get runVoiceCountdown => 'Compte à rebours';

  @override
  String get runVoiceCountdownSubtitle =>
      'Un tic chaque seconde pendant les trois dernières secondes d\'une phase.';

  @override
  String get runVoiceFooter =>
      'Les changements d\'intervalle s\'affichent toujours à l\'écran. Ces choix sont gardés sur ce téléphone.';

  @override
  String get runPersonalBests => 'Records personnels';

  @override
  String get runBestNotSet => 'Pas encore établi';

  @override
  String get runBestLongestRun => 'Plus longue course';

  @override
  String get runBestLongestWalk => 'Plus longue marche';

  @override
  String get runBestFastest1kRun => 'Course la plus rapide sur 1 km';

  @override
  String get runBestFastest5kRun => 'Course la plus rapide sur 5 km';

  @override
  String get runBestFastest1kWalk => 'Marche la plus rapide sur 1 km';

  @override
  String get runBestsFootnote =>
      'D\'après les activités enregistrées dont le GPS a mesuré la distance. Un meilleur temps est le tronçon continu le plus rapide sur cette distance, chronométré du début à la fin; une pause ou une coupure GPS interrompt le tronçon. Les distances saisies ou corrigées ne comptent pas.';

  @override
  String runBestsUnchecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count activités antérieures ont été enregistrées avant que les meilleurs temps soient gardés et ne comptent que pour la distance, si elle a été mesurée.',
      one:
          '$count activité antérieure a été enregistrée avant que les meilleurs temps soient gardés et ne compte que pour la distance, si elle a été mesurée.',
    );
    return '$_temp0';
  }

  @override
  String get runBestsNoneYet =>
      'Aucun pour l\'instant : ils viennent des activités enregistrées mesurées par GPS';

  @override
  String runBestPill(String label) {
    return 'Record personnel · $label';
  }

  @override
  String runRecordLongest(String kind, String distance) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'ta plus longue marche jusqu\'ici, $distance',
      'other': 'ta plus longue course jusqu\'ici, $distance',
    });
    return '$_temp0';
  }

  @override
  String runRecordFastest(String kind, String benchmark, String time) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'ta marche la plus rapide sur $benchmark jusqu\'ici, $time',
      'other': 'ta course la plus rapide sur $benchmark jusqu\'ici, $time',
    });
    return '$_temp0';
  }

  @override
  String runRecordsTwo(String first, String second) {
    return '$first et $second';
  }

  @override
  String runRecordsThree(String first, String second, String third) {
    return '$first, $second et $third';
  }

  @override
  String runActivityWhen(String date, String year, String time) {
    return '$date $year · $time';
  }

  @override
  String get runExportGpx => 'Exporter en GPX';

  @override
  String get runDistanceNotRecorded => 'Distance non enregistrée';

  @override
  String get runDistanceTyped => 'Distance (saisie)';

  @override
  String get runDistanceCorrected => 'Distance (corrigée)';

  @override
  String get runTime => 'Temps';

  @override
  String runTimeSaid(String duration) {
    return 'Temps $duration';
  }

  @override
  String runElapsed(String time) {
    return 'Écoulé $time';
  }

  @override
  String get runElevationGainNotMeasured => 'Dénivelé positif non mesuré';

  @override
  String runElevationGain(String value) {
    return 'Dénivelé positif $value';
  }

  @override
  String get runTabOverview => 'Aperçu';

  @override
  String get runTabSplits => 'Tronçons';

  @override
  String get runTabCharts => 'Graphiques';

  @override
  String get runSyncPending =>
      'Enregistrée sur ce téléphone, en attente de synchronisation';

  @override
  String get runSyncReview => 'À vérifier dans Profil › Synchronisation';

  @override
  String get runSyncSaved => 'Enregistrée dans ton compte';

  @override
  String get runRouteSyncSaved => 'Parcours enregistré dans ton compte';

  @override
  String get runRouteSyncNone => 'Aucun parcours à synchroniser';

  @override
  String get runRouteSyncKept =>
      'Parcours gardé sur le téléphone qui l\'a enregistré';

  @override
  String get runRouteSyncAttention =>
      'L\'envoi du parcours demande ton attention';

  @override
  String get runRouteSyncWaiting =>
      'Parcours sur ce téléphone, en attente d\'envoi';

  @override
  String get runAvgSpeed => 'Vitesse moy.';

  @override
  String get runElevationLoss => 'Dénivelé négatif';

  @override
  String get runMeasuredByGps => 'Mesurée par GPS';

  @override
  String get runGpsPointsUsed => 'Points GPS utilisés';

  @override
  String runGpsPointsRejected(String points, int count) {
    return '$points ($count écartés car imprécis)';
  }

  @override
  String get runGaps => 'Coupures';

  @override
  String runGapsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tronçons sans GPS, non comptés',
      one: '$count tronçon sans GPS, non compté',
    );
    return '$_temp0';
  }

  @override
  String get runBeforeRoutes => 'Avant que les parcours soient gardés';

  @override
  String runBeforeRoutesValue(String distance) {
    return '$distance sans parcours';
  }

  @override
  String get runSummary => 'Résumé';

  @override
  String get runRoute => 'Parcours';

  @override
  String get runPartialRoute =>
      'Une partie de ce parcours n\'a pas été enregistrée. La distance et l\'allure couvrent seulement ce que le GPS a mesuré.';

  @override
  String runIntervalsRunsCompleted(int done, int total) {
    return 'Courses terminées : $done sur $total';
  }

  @override
  String runEndedEarly(String time) {
    return 'Terminée plus tôt (prévu $time)';
  }

  @override
  String get runNoSplits => 'Aucun tronçon : il n\'y a pas de distance GPS.';

  @override
  String get runSelectSplit => 'Choisis un tronçon pour le voir sur la carte.';

  @override
  String runSplitLast(int number, String distance) {
    return '$number · dernier $distance';
  }

  @override
  String get runPartialSplit => 'Tronçon partiel';

  @override
  String get runShownOnMap => 'Affiché sur la carte';

  @override
  String get runNoCharts =>
      'Aucun graphique : aucun parcours GPS n\'a été enregistré.';

  @override
  String get runChartPace => 'Allure';

  @override
  String runChartPaceNote(String step) {
    return 'Tous les $step; plus rapide, c\'est plus haut. Les coupures sont des pauses ou des pertes de GPS.';
  }

  @override
  String get runChartPaceTooShort =>
      'Trop peu de distance pour un graphique d\'allure.';

  @override
  String get runChartElevation => 'Altitude';

  @override
  String get runGainNotMeasured => 'Dénivelé non mesuré';

  @override
  String runGainShort(String value) {
    return '$value de dénivelé';
  }

  @override
  String get runNoAltitude =>
      'Ce téléphone n\'a pas fourni une altitude assez précise pour un graphique.';

  @override
  String runChartSaid(String from, String to, String distance) {
    return 'Graphique de $from à $to sur $distance';
  }

  @override
  String get runSaveChanges => 'Enregistrer les modifications';

  @override
  String get runEditSaveFailed =>
      'L\'enregistrement a échoué sur ce téléphone. Tes modifications sont toujours là.';

  @override
  String runDeleteTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Supprimer cette marche?',
      'other': 'Supprimer cette course?',
    });
    return '$_temp0';
  }

  @override
  String runDeleteBody(String kind, String date) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk':
          'La marche du $date et son parcours sont supprimés de ce téléphone et de ton compte.',
      'other':
          'La course du $date et son parcours sont supprimés de ce téléphone et de ton compte.',
    });
    return '$_temp0';
  }

  @override
  String runDeleteAction(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Supprimer la marche',
      'other': 'Supprimer la course',
    });
    return '$_temp0';
  }

  @override
  String get runDeleteFailed =>
      'La suppression a échoué sur ce téléphone. Rien n\'a changé.';

  @override
  String get runGpxFailed =>
      'Le fichier GPX n\'a pas pu être créé sur ce téléphone.';

  @override
  String get runNoRouteLegacy =>
      'Enregistrée avant que GoHard garde les parcours. Son temps et sa distance sont tels qu\'enregistrés.';

  @override
  String get runNoRouteManual =>
      'Chronométrée sans GPS; la distance a été saisie.';

  @override
  String runNoRoutePositions(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Aucune position GPS n\'a été enregistrée pour cette marche.',
      'other': 'Aucune position GPS n\'a été enregistrée pour cette course.',
    });
    return '$_temp0';
  }

  @override
  String get runFilterAll => 'Tout';

  @override
  String runInProgress(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche en cours',
      'other': 'Course en cours',
    });
    return '$_temp0';
  }

  @override
  String runStartedOn(String date) {
    return 'Commencée le $date';
  }

  @override
  String get runThisWeek => 'Cette semaine';

  @override
  String get runThisMonth => 'Ce mois-ci';

  @override
  String runHistoryEmpty(String filter) {
    String _temp0 = intl.Intl.selectLogic(filter, {
      'run': 'Aucune course pour l\'instant',
      'walk': 'Aucune marche pour l\'instant',
      'other': 'Aucune activité pour l\'instant',
    });
    return '$_temp0';
  }

  @override
  String runHistoryEmptyBody(String filter) {
    String _temp0 = intl.Intl.selectLogic(filter, {
      'run':
          'Tes courses enregistrées apparaissent ici, toutes sans exception.',
      'walk':
          'Tes marches enregistrées apparaissent ici, toutes sans exception.',
      'other': 'Tes courses et marches enregistrées apparaissent ici, toutes sans exception.',
    });
    return '$_temp0';
  }

  @override
  String get runStartOne => 'En commencer une';

  @override
  String runTotalsSaid(
    String label,
    int count,
    String distance,
    String duration,
  ) {
    return '$label : $count enregistrées, $distance, $duration d\'activité';
  }

  @override
  String runTotalsSaidPartial(
    String label,
    int count,
    String distance,
    String duration,
  ) {
    return '$label : $count enregistrées, $distance là où la distance est connue, $duration d\'activité';
  }

  @override
  String runTotalsLine(int count, String duration) {
    return '$count · $duration d\'activité';
  }

  @override
  String runNotificationTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'GoHard enregistre ta marche',
      'other': 'GoHard enregistre ta course',
    });
    return '$_temp0';
  }

  @override
  String runNotificationText(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Ouvre GoHard pour mettre en pause ou terminer. La position sert seulement à cette marche.',
      'other': 'Ouvre GoHard pour mettre en pause ou terminer. La position sert seulement à cette course.',
    });
    return '$_temp0';
  }

  @override
  String get runNotificationChannel => 'Enregistrement Course / Marche';

  @override
  String get runMapRoute => 'Carte du parcours';

  @override
  String get runMapFollowing => 'Suit ta position';

  @override
  String get runMapRecenter => 'Recentrer';

  @override
  String get runMapFit => 'Voir tout le parcours';

  @override
  String get runMapZoomIn => 'Zoom avant';

  @override
  String get runMapZoomOut => 'Zoom arrière';

  @override
  String get runMapNoTiles => 'Parcours tracé sans carte';

  @override
  String get runMapExpand => 'Agrandir la carte';

  @override
  String get stepsTitle => 'Pas';

  @override
  String get stepsCount => 'Compter les pas';

  @override
  String get stepsCountSubtitle =>
      'Avec le capteur de mouvement de ce téléphone : pendant une course ou une marche, et le total du jour. Marcher sans ton téléphone n\'est pas compté.';

  @override
  String get stepsMotionNotAllowed =>
      'L\'accès au mouvement n\'est pas encore autorisé.';

  @override
  String get stepsMotionBlocked =>
      'L\'accès au mouvement est désactivé pour GoHard. Active-le dans les réglages du téléphone.';

  @override
  String get stepsNoCounter =>
      'Ce téléphone n\'a pas de podomètre. Course / Marche enregistre tout le reste.';

  @override
  String get stepsAllow => 'Autoriser';

  @override
  String get stepsSettings => 'Réglages';

  @override
  String get stepsGoalLabel => 'Objectif de pas quotidien (facultatif)';

  @override
  String get stepsGoalHelper => 'Ton propre nombre. Laisse vide pour aucun.';

  @override
  String get stepsOnToday => 'Afficher les pas dans Aujourd\'hui';

  @override
  String get stepsOnTodaySubtitle =>
      'Seulement l\'affichage dans Aujourd\'hui. Le comptage et l\'accès ne changent pas.';

  @override
  String stepsFooter(String source) {
    return 'Le total du jour est lu depuis $source et reste sur ce téléphone : il n\'est jamais envoyé à ton compte. Les pas d\'une course ou d\'une marche sont enregistrés avec elle et se synchronisent avec ton compte. Les deux ne sont jamais additionnés.';
  }

  @override
  String get stepsOff => 'Pas désactivés';

  @override
  String get stepsOn => 'Pas activés';

  @override
  String get stepsChecking => 'Vérification…';

  @override
  String get stepsSimulated => 'Simulé (version de test)';

  @override
  String get stepsCounted => 'Comptés avec ce téléphone';

  @override
  String get stepsMotionNeeded => 'Accès au mouvement requis';

  @override
  String get stepsMotionOff => 'Accès au mouvement désactivé';

  @override
  String get stepsNotOnPhone => 'Pas sur ce téléphone';

  @override
  String get stepsEnable => 'Activer';

  @override
  String stepsPartOfTime(String steps) {
    return '$steps (une partie du temps)';
  }

  @override
  String get stepsNotCountedMotion =>
      'Non comptés : l\'accès au mouvement est désactivé';

  @override
  String get stepsNotCountedSensor => 'Non comptés : aucun capteur de pas';

  @override
  String get stepsNotCounted => 'Non comptés';

  @override
  String get stepsNotRecorded => 'Non enregistrés';

  @override
  String get stepsDailyUnavailableIos =>
      'Cet iPhone ne peut pas compter les pas.';

  @override
  String get stepsDailyUnavailableAndroid =>
      'Sur Android, les pas quotidiens viennent de Health Connect, qui n\'est pas disponible sur ce téléphone.';

  @override
  String get stepsSourceIphone => 'Cet iPhone';

  @override
  String get stepsSourceSimulated => 'Ce téléphone (simulé)';

  @override
  String get shellPassCardOverline => 'Programme d\'entraînement';

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
  String get shellUpdateTitle => 'Mets GoHard à jour pour continuer';

  @override
  String get shellUpdateBody =>
      'Cette version de l\'application est trop ancienne pour le serveur de ton compte; la synchronisation est donc arrêtée.';

  @override
  String get shellUpdateSavedHere =>
      'Tout ce que tu as enregistré sur ce téléphone est toujours là.';

  @override
  String shellUpdateSavedPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tout ce que tu as enregistré sur ce téléphone est toujours là, y compris $count modifications en attente de synchronisation. Elles seront synchronisées après la mise à jour.',
      one:
          'Tout ce que tu as enregistré sur ce téléphone est toujours là, y compris $count modification en attente de synchronisation. Elle sera synchronisée après la mise à jour.',
    );
    return '$_temp0';
  }

  @override
  String get shellUpdateCheckAgain => 'Vérifier de nouveau';

  @override
  String get shellConfigTitle => 'Non configurée';

  @override
  String get shellConfigBody =>
      'Cette version n\'a volontairement aucun serveur par défaut. Lance-la avec le script de développement pour qu\'elle sache quelle API utiliser.';

  @override
  String get shellCantSyncDetail =>
      'La dernière tentative pour joindre ton compte n\'a pas abouti. Ce peut être la connexion de ce téléphone ou le serveur.';

  @override
  String shellReviewBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count modifications enregistrées doivent être examinées. Rien n\'a été perdu. Touche pour les examiner.',
      one:
          '$count modification enregistrée doit être examinée. Rien n\'a été perdu. Touche pour l\'examiner.',
    );
    return '$_temp0';
  }

  @override
  String get authFillEveryField => 'Remplis tous les champs pour continuer.';

  @override
  String get authCreateAccountTitle => 'Créer un compte';

  @override
  String get authWelcomeBack => 'Bon retour';

  @override
  String get authRegisterLead =>
      'Sache quoi faire ensuite et garde une trace de ce que tu as vraiment fait.';

  @override
  String get authSignInLead => 'Connecte-toi pour reprendre là où tu en étais.';

  @override
  String get authTagline => 'Planifie.\nEnregistre.\nContinue.';

  @override
  String get authNoticeExpired =>
      'Ta connexion a expiré. Connecte-toi de nouveau pour continuer la synchronisation; tout ce qui est enregistré sur ce téléphone est toujours là.';

  @override
  String get authNoticeAccountDeleted =>
      'Ton compte et ses données ont été supprimés.';

  @override
  String get authNameLabel => 'Ton nom';

  @override
  String get authEmailLabel => 'Courriel';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authHidePassword => 'Masquer le mot de passe';

  @override
  String get authShowPassword => 'Afficher le mot de passe';

  @override
  String get authCreateAccountButton => 'Créer un compte';

  @override
  String get authSignInButton => 'Se connecter';

  @override
  String get authToggleToSignIn => 'J\'ai déjà un compte · Se connecter';

  @override
  String get authToggleToRegister => 'Nouveau sur GoHard? Créer un compte';

  @override
  String get setupCoachTitle => 'Choisis ton coach';

  @override
  String get setupCoachSubtitle =>
      'Leon ou Leona : la même aide dans les deux cas, seule l\'apparence change. Tu pourras changer ce choix plus tard dans Apparence.';

  @override
  String get setupNotNow => 'Pas maintenant';

  @override
  String setupCoachHello(String name) {
    return 'Je suis $name. Touche-moi sur n\'importe quel écran quand tu veux un coup de main.';
  }

  @override
  String get setupHi => 'Salut!';

  @override
  String setupHiName(String name) {
    return 'Salut $name!';
  }

  @override
  String get setupFeaturesTitle => 'Fonctions facultatives';

  @override
  String get setupFeaturesSubtitle =>
      'Active ce que tu veux maintenant, ou plus tard dans Profil. Le téléphone demande l\'accès seulement quand tu utilises une fonction qui en a besoin.';

  @override
  String get setupWeatherTitle => 'Météo dans Aujourd\'hui';

  @override
  String get setupWeatherSubtitle =>
      'Utilise ta position approximative, ou choisis une ville sans la partager.';

  @override
  String get setupRemindersTitle => 'Rappels d\'entraînement';

  @override
  String get setupRemindersSubtitle =>
      'Les jours où une séance est prévue. Les notifications sont demandées quand tu actives cette option.';

  @override
  String get setupBarcodeTitle => 'Lecture de codes-barres';

  @override
  String get setupBarcodeSubtitle =>
      'Prête dans Nutrition. L\'accès à la caméra est demandé la première fois que tu lis un code.';

  @override
  String get setupGpsTitle => 'Courses avec GPS';

  @override
  String get setupGpsSubtitle =>
      'Prêtes dans Aujourd\'hui. La position est demandée quand tu commences une course.';

  @override
  String get setupPermissionsFootnote =>
      'Tout ce que tu autorises ou refuses peut être changé plus tard dans les Réglages du téléphone; Profil › Autorisations du téléphone montre ce qui est autorisé maintenant.';

  @override
  String setupStep(int step, int total) {
    return 'Étape $step sur $total';
  }

  @override
  String todayGreetingNamed(String part, String name) {
    String _temp0 = intl.Intl.selectLogic(part, {
      'morning': 'Bonjour, $name!',
      'afternoon': 'Bon après-midi, $name!',
      'other': 'Bonsoir, $name!',
    });
    return '$_temp0';
  }

  @override
  String todayGreetingPlain(String part) {
    String _temp0 = intl.Intl.selectLogic(part, {
      'morning': 'Bonjour!',
      'afternoon': 'Bon après-midi!',
      'other': 'Bonsoir!',
    });
    return '$_temp0';
  }

  @override
  String get todayLineSaved => 'Ta séance est enregistrée. Beau travail.';

  @override
  String get todayLineResume => 'Ta séance est prête à reprendre.';

  @override
  String todayLineDue(String title) {
    return '$title est prévue aujourd\'hui.';
  }

  @override
  String get todayLineFinished => 'La séance d\'aujourd\'hui est terminée.';

  @override
  String get todayLinePartial => 'La séance d\'aujourd\'hui est enregistrée.';

  @override
  String get todayLineSkipped => 'La séance d\'aujourd\'hui est sautée.';

  @override
  String get todayLineRest => 'Jour de repos prévu aujourd\'hui.';

  @override
  String get todayLinePaused => 'Ton programme est en pause aujourd\'hui.';

  @override
  String get todayCoachStepsIntro =>
      'Tu veux suivre ton activité quotidienne? Active les pas ici.';

  @override
  String get todayCoachEnableSteps => 'Activer les pas';

  @override
  String get todayCoachNeedHand => 'Besoin d\'un coup de main aujourd\'hui?';

  @override
  String get todaySkyNeedsPermission => 'Position pas encore autorisée';

  @override
  String get todaySkyDenied => 'Position non autorisée';

  @override
  String get todaySkyServicesOff => 'La localisation est désactivée';

  @override
  String get todaySkyTimeout => 'Position non trouvée à temps';

  @override
  String get todaySkyOffline => 'Météo inaccessible';

  @override
  String get todaySkyUnavailable => 'Météo non disponible';

  @override
  String get todaySkyNoCity => 'Choisis une ville';

  @override
  String todaySkyWeather(String temperature, String condition) {
    return '$temperature · $condition';
  }

  @override
  String todaySkyScenic(String reason) {
    return 'Paysage · $reason';
  }

  @override
  String get todaySkyHint =>
      'Ouvre le réglage de l\'arrière-plan d\'Aujourd\'hui';

  @override
  String get todayCantSyncDetailNothingWaiting =>
      'La dernière tentative pour joindre ton compte n\'a pas abouti. Ce peut être la connexion de ce téléphone ou le serveur. Tu vois ce qui est enregistré sur ce téléphone. Rien n\'attend d\'être synchronisé.';

  @override
  String get todayCantSyncDetailWaiting =>
      'La dernière tentative pour joindre ton compte n\'a pas abouti. Ce peut être la connexion de ce téléphone ou le serveur. Tu vois ce qui est enregistré sur ce téléphone. Tes modifications sont gardées ici et se synchroniseront d\'elles-mêmes dès que le compte répondra.';

  @override
  String get todayTrainingError =>
      'Ton entraînement n\'a pas pu être lu sur ce téléphone. Tire vers le bas pour réessayer.';

  @override
  String get todayTrainingLoading => 'Chargement de ton entraînement…';

  @override
  String get todayStatusInProgress => 'En cours';

  @override
  String get todayStatusCompleted => 'Terminée';

  @override
  String get todayStatusPartly => 'Partiellement terminée';

  @override
  String get todayStatusSkipped => 'Sautée aujourd\'hui';

  @override
  String get todayStatusMissed => 'Manquée';

  @override
  String get todayStatusPaused => 'En pause';

  @override
  String get todayStatusDue => 'Prévue aujourd\'hui';

  @override
  String get todayStatusSavedForLater => 'Gardée pour plus tard';

  @override
  String get todayStatusRestDay => 'Jour de repos prévu';

  @override
  String get todayStatusPlanPaused => 'Programme en pause';

  @override
  String todayStatusStarts(String date) {
    return 'Commence le $date';
  }

  @override
  String get todayStatusBlockReview => 'Bloc prêt à examiner';

  @override
  String get todayStatusDraftReview => 'Ton programme est prêt à examiner';

  @override
  String get todayNextNone => 'Aucune autre séance n\'est prévue dans ce bloc.';

  @override
  String todayNextRotation(String title) {
    return 'Prochaine dans ta rotation : $title.';
  }

  @override
  String todayNextRotationDay(String title, String day) {
    return 'Prochaine dans ta rotation : $title · $day.';
  }

  @override
  String todayNext(String title, String day) {
    return 'Prochaine : $title · $day.';
  }

  @override
  String get todayDetailsLink => 'Détails';

  @override
  String get todayDetailsSaid => 'Détails de la séance';

  @override
  String get todayWorkoutLabel => 'Séance';

  @override
  String todayExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercices',
      one: '$count exercice',
    );
    return '$_temp0';
  }

  @override
  String todayPlannedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries prévues',
      one: '$count série prévue',
    );
    return '$_temp0';
  }

  @override
  String todayRotationStep(int position, int total) {
    return 'Étape $position sur $total';
  }

  @override
  String todaySessionNumber(int number) {
    return 'Séance $number';
  }

  @override
  String todayWeekNumber(int number) {
    return 'Semaine $number';
  }

  @override
  String todayMinutesPlanned(int minutes) {
    return '$minutes min prévues';
  }

  @override
  String todaySetsRingLabel(int counted, int planned) {
    return 'Séries enregistrées : $counted sur $planned prévues';
  }

  @override
  String todayOfSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sur $count séries',
      one: 'sur $count série',
    );
    return '$_temp0';
  }

  @override
  String get todayRecordedCaption => 'enregistré';

  @override
  String todaySetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries enregistrées',
      one: '$count série enregistrée',
    );
    return '$_temp0';
  }

  @override
  String get todayNoExercise => 'Aucun exercice ajouté pour l\'instant';

  @override
  String get todayResumeWorkout => 'Reprendre la séance';

  @override
  String get todayStartWorkout => 'Commencer la séance';

  @override
  String get todayResolvedSkipped =>
      'Sautée : rien n\'a été enregistré et elle ne compte pas comme entraînement.';

  @override
  String get todayResolvedFinished =>
      'Terminée : toutes les séries prévues sont enregistrées.';

  @override
  String get todayResolvedPartial =>
      'Terminée partiellement : une partie du travail prévu n\'a pas été enregistrée.';

  @override
  String get todayBlockLast => 'C\'était la dernière séance de ce bloc.';

  @override
  String get todayUnskipSaved => 'N\'est plus sautée.';

  @override
  String get todayUndoSkip => 'Annuler le saut';

  @override
  String get todayReviewBlock => 'Examiner ce bloc';

  @override
  String get todayTrainNow => 'Faire cette séance maintenant';

  @override
  String get todayViewPlan => 'Voir le programme';

  @override
  String todayAlsoToday(String status) {
    return 'Aussi aujourd\'hui · $status';
  }

  @override
  String todayMissedUnresolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances précédentes ne sont pas réglées',
      one: '$count séance précédente n\'est pas réglée',
    );
    return '$_temp0';
  }

  @override
  String get todayRestDayTitle => 'Jour de repos';

  @override
  String get todayRestChosen =>
      'Tu as choisi de te reposer aujourd\'hui. Rien n\'a été sauté et ta rotation t\'attend.';

  @override
  String todayRestMissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count séances précédentes ne sont pas réglées; déplace-les ou saute-les quand tu veux.',
      one:
          '$count séance précédente n\'est pas réglée; déplace-la ou saute-la quand tu veux.',
    );
    return '$_temp0';
  }

  @override
  String get todayResolveMissed => 'Régler l\'entraînement manqué';

  @override
  String get todayTrainToday => 'M\'entraîner aujourd\'hui';

  @override
  String get todayPausedText =>
      'Aucune séance n\'est attendue pendant que le programme est en pause, et rien n\'est compté comme manqué.';

  @override
  String get todayResumePlan => 'Reprendre le programme';

  @override
  String todayStartsLaterText(String date) {
    return 'Ton programme commence le $date. Rien n\'est prévu avant.';
  }

  @override
  String get todayBlockReviewText =>
      'Ce bloc est arrivé à sa fin ou n\'a plus rien à faire. Examine ce qui a vraiment été enregistré et choisis la suite.';

  @override
  String get todayDraftText =>
      'Cette ébauche n\'a pas commencé. Rien n\'est planifié tant que tu ne la commences pas.';

  @override
  String get todayReviewPlan => 'Examiner ton programme';

  @override
  String get todayNoPlanTitle => 'Aucun programme actif';

  @override
  String get todayNoPlanText =>
      'Pars d\'une répartition connue ou crée la tienne et examine-la avant de t\'engager, ou entraîne-toi simplement librement aujourd\'hui.';

  @override
  String get todayCreatePlan => 'Créer mon programme';

  @override
  String get todayStartManual => 'Commencer une séance libre';

  @override
  String todayParkedSubtitle(String date) {
    return 'Gardée pour plus tard · commencée le $date';
  }

  @override
  String get todayManualWorkout => 'Séance libre';

  @override
  String get todayPlannedWorkout => 'Séance planifiée';

  @override
  String todayPlannedWorkoutFrom(String date) {
    return 'Séance planifiée du $date';
  }

  @override
  String get todayUnderOneMinute => 'Moins de 1 min';

  @override
  String todayActivityPaused(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche en pause',
      'other': 'Course en pause',
    });
    return '$_temp0';
  }

  @override
  String todayActivityInterrupted(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche interrompue',
      'other': 'Course interrompue',
    });
    return '$_temp0';
  }

  @override
  String todayActivityNotSaved(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche pas encore enregistrée',
      'other': 'Course pas encore enregistrée',
    });
    return '$_temp0';
  }

  @override
  String todayActivityInProgress(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche en cours',
      'other': 'Course en cours',
    });
    return '$_temp0';
  }

  @override
  String todayActivityCompleted(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'Marche terminée',
      'other': 'Course terminée',
    });
    return '$_temp0';
  }

  @override
  String todayStartedOn(String date) {
    return 'Commencée le $date';
  }

  @override
  String get todayStartedToday => 'Commencée aujourd\'hui';

  @override
  String get todayCompletedWhen => 'aujourd\'hui';

  @override
  String get todayRunResume => 'Reprendre';

  @override
  String get todayRunStartNew => 'Nouvelle activité';

  @override
  String get todayRunStart => 'Commencer';

  @override
  String get todayNoRunWalk => 'Aucune course ni marche aujourd\'hui';

  @override
  String get todayRunWalkLabel => 'Course / Marche';

  @override
  String get todayStepsLabel => 'Pas';

  @override
  String get todayStepsTrack => 'Suis tes pas';

  @override
  String get todayStepsCountWithPhone => 'Compte-les avec ton téléphone.';

  @override
  String get todayStepsEnable => 'Activer';

  @override
  String get todayStepsReading => 'Lecture des pas';

  @override
  String todayStepsUpdated(String time) {
    return 'Mis à jour à $time';
  }

  @override
  String get todayStepsSetGoal => 'Fixer un objectif';

  @override
  String get todayStepsEditGoal => 'Modifier l\'objectif';

  @override
  String get todayStepsSetGoalSaid => 'Fixer un objectif de pas';

  @override
  String get todayStepsEditGoalSaid => 'Modifier l\'objectif de pas';

  @override
  String get todayStepsNone => 'Aucun pas enregistré aujourd\'hui';

  @override
  String get todayStepsBlocked =>
      'L\'accès est désactivé. Autorise-le dans les Réglages.';

  @override
  String get todayStepsAllowHint =>
      'Autorise l\'accès pour voir les pas d\'aujourd\'hui.';

  @override
  String get todayStepsSettings => 'Réglages';

  @override
  String get todayStepsAllow => 'Autoriser';

  @override
  String get todayStepsFailed => 'Impossible de lire les pas pour le moment.';

  @override
  String get todayStepsOffSaid =>
      'Pas. Suis tes pas : compte-les avec ton téléphone.';

  @override
  String todayStepsSaid(String value, String details) {
    return 'Pas aujourd\'hui : $value. $details';
  }

  @override
  String get todayStepsNotKnown => 'inconnu';

  @override
  String todayStepsOpens(String said) {
    return '$said Ouvre Pas.';
  }

  @override
  String todayStepsOfGoal(String goal) {
    return 'sur $goal';
  }

  @override
  String get todayStepsGoalLabel => 'Objectif de pas';

  @override
  String get todayStepsSimulated => 'Simulé (version de test)';

  @override
  String get todayNutritionLabel => 'Nutrition';

  @override
  String get todayFoodError =>
      'Les aliments d\'aujourd\'hui n\'ont pas pu être lus sur ce téléphone.';

  @override
  String get todayLoading => 'Chargement…';

  @override
  String get todayNoFood => 'Aucun aliment consigné aujourd\'hui';

  @override
  String todayDailyGoal(String goals) {
    return 'Ton objectif quotidien : $goals';
  }

  @override
  String get todayLogFood => 'Consigner un aliment';

  @override
  String get todayJournal => 'Journal';

  @override
  String get todayJournalSaid => 'Journal alimentaire';

  @override
  String get todayRecordedTodayOverline => 'Enregistré aujourd\'hui';

  @override
  String todaySetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '$count série',
    );
    return '$_temp0';
  }

  @override
  String weatherCondition(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'c0': 'Ciel dégagé',
      'c1': 'Généralement dégagé',
      'c2': 'Partiellement nuageux',
      'c3': 'Couvert',
      'c45': 'Brouillard',
      'c48': 'Brouillard givrant',
      'c51': 'Bruine légère',
      'c53': 'Bruine modérée',
      'c55': 'Bruine dense',
      'c56': 'Bruine verglaçante légère',
      'c57': 'Bruine verglaçante dense',
      'c61': 'Pluie faible',
      'c63': 'Pluie modérée',
      'c65': 'Forte pluie',
      'c66': 'Pluie verglaçante faible',
      'c67': 'Forte pluie verglaçante',
      'c71': 'Faibles chutes de neige',
      'c73': 'Chutes de neige modérées',
      'c75': 'Fortes chutes de neige',
      'c77': 'Neige en grains',
      'c80': 'Faibles averses de pluie',
      'c81': 'Averses de pluie modérées',
      'c82': 'Violentes averses de pluie',
      'c85': 'Faibles averses de neige',
      'c86': 'Fortes averses de neige',
      'c95': 'Orage',
      'c96': 'Orage avec faible grêle',
      'c97': 'Orage violent',
      'c99': 'Orage avec forte grêle',
      'other': 'Météo',
    });
    return '$_temp0';
  }

  @override
  String weatherFamily(String family) {
    String _temp0 = intl.Intl.selectLogic(family, {
      'clear': 'Dégagé',
      'partly': 'Partiellement nuageux',
      'cloudy': 'Couvert',
      'fog': 'Brouillard',
      'rain': 'Pluie',
      'snow': 'Neige',
      'storm': 'Orage',
      'other': 'Météo',
    });
    return '$_temp0';
  }

  @override
  String weatherTemperatureC(int degrees) {
    return '$degrees °C';
  }

  @override
  String weatherTemperatureF(int degrees) {
    return '$degrees °F';
  }

  @override
  String get weatherFallbackNoAnswer => 'Pas encore de météo';

  @override
  String get weatherFallbackOtherPlace => 'La météo est pour un autre endroit';

  @override
  String get weatherFallbackStale => 'La météo n\'est plus à jour';

  @override
  String get weatherFallbackAhead => 'L\'heure de la météo est en avance';

  @override
  String get weatherFallbackUnknownCode => 'Météo non reconnue';

  @override
  String get weatherFallbackNoArt => 'Aucune scène pour cette météo';

  @override
  String get weatherBackgroundScenic => 'Paysage';

  @override
  String get weatherBackgroundWeather => 'Météo';

  @override
  String get weatherBackgroundPlain => 'Uni';

  @override
  String get weatherSummaryAutomatic => 'Météo · Automatique';

  @override
  String weatherSummaryCity(String city) {
    return 'Météo · $city';
  }

  @override
  String get weatherBackgroundTitle => 'Arrière-plan d\'Aujourd\'hui';

  @override
  String get weatherBackgroundSubtitle =>
      'Seul le haut d\'Aujourd\'hui l\'utilise. Les changements s\'appliquent aussitôt.';

  @override
  String get weatherBackgroundScenicDetail =>
      'Une scène décorative au crépuscule. Fonctionne sans connexion.';

  @override
  String get weatherBackgroundWeatherDetail =>
      'Une scène selon la météo actuelle à l\'endroit choisi. Le crépuscule quand aucune n\'est disponible.';

  @override
  String get weatherBackgroundPlainDetail => 'La couleur unie de la page.';

  @override
  String get weatherLocationSection => 'Position';

  @override
  String get weatherAutomatic => 'Automatique';

  @override
  String get weatherAutomaticDetail =>
      'La position approximative de ce téléphone, à environ 10 km près';

  @override
  String get weatherSelectedCity => 'Ville choisie';

  @override
  String get weatherSearchForCity => 'Cherche une ville';

  @override
  String get weatherChangeCity => 'Changer de ville';

  @override
  String get weatherNowSection => 'Maintenant';

  @override
  String get weatherConsentTitle => 'Utiliser ta position approximative?';

  @override
  String get weatherConsentBody =>
      'GoHard utilise la position de ce téléphone seulement pour choisir une scène météo en haut d\'Aujourd\'hui. Elle est arrondie à environ 10 km avant de quitter le téléphone et n\'est pas conservée dans un historique. Tu peux plutôt choisir une ville.';

  @override
  String get weatherNotNow => 'Pas maintenant';

  @override
  String get weatherChooseCity => 'Choisis une ville';

  @override
  String get weatherIssueNeedsPermission =>
      'Automatique a besoin de l\'autorisation d\'utiliser la position approximative de ce téléphone.';

  @override
  String get weatherUseMyLocation => 'Utiliser ma position';

  @override
  String get weatherIssueDenied =>
      'La position n\'a pas été autorisée. Choisis une ville ou réessaie.';

  @override
  String get weatherIssueDeniedForever =>
      'La position est désactivée pour GoHard. Autorise-la dans les Réglages ou choisis une ville.';

  @override
  String get weatherOpenSettings => 'Ouvrir les Réglages';

  @override
  String get weatherIssueServicesOff =>
      'La localisation est désactivée sur ce téléphone. Active-la ou choisis une ville.';

  @override
  String get weatherLocationSettings => 'Réglages de localisation';

  @override
  String get weatherIssueTimeout =>
      'Ce téléphone n\'a pas trouvé sa position à temps. Le crépuscule s\'affiche en attendant.';

  @override
  String get weatherIssueNoCity => 'Choisis une ville pour voir sa météo.';

  @override
  String get weatherIssueUnreachable =>
      'La météo est inaccessible pour le moment. Le crépuscule s\'affiche en attendant.';

  @override
  String get weatherApproximateLocation => 'Ta position approximative';

  @override
  String weatherAsOf(String time) {
    return 'À $time';
  }

  @override
  String weatherAsOfPlace(String time, String place) {
    return 'À $time · $place';
  }

  @override
  String get weatherChecking => 'Vérification de la météo…';

  @override
  String get weatherNone =>
      'Aucune météo actuelle. La scène décorative du crépuscule s\'affiche.';

  @override
  String get weatherCreditMet =>
      'Données de MET Norway (api.met.no), CC BY 4.0 : creativecommons.org/licenses/by/4.0. Ses symboles météo sont convertis ici en codes OMM.';

  @override
  String get weatherCreditOpenMeteo =>
      'Données météo d\'Open-Meteo.com, CC BY 4.0 : creativecommons.org/licenses/by/4.0.';

  @override
  String get weatherCreditDefault =>
      'Données météo d\'Open-Meteo.com, ou de MET Norway quand il est surchargé (CC BY 4.0).';

  @override
  String get weatherModelData => 'Les conditions sont des données de modèle.';

  @override
  String get weatherIllustrative =>
      'Les scènes sont illustratives : ni une prévision ni une vue de ton emplacement.';

  @override
  String get weatherBasisTitle => 'Sur quoi repose la scène';

  @override
  String get weatherNoCityChosen => 'Aucune ville choisie';

  @override
  String get weatherAutomaticBasis =>
      'Automatique (ce téléphone, à environ 10 km près)';

  @override
  String get weatherBasisLastAttempt => 'Dernière tentative';

  @override
  String get weatherBasisScene => 'Scène';

  @override
  String weatherBasisSceneWeather(String key) {
    return '$key (météo)';
  }

  @override
  String weatherBasisSceneScenic(String reason) {
    return 'paysage · $reason';
  }

  @override
  String get weatherBasisCondition => 'Conditions';

  @override
  String get weatherBasisSource => 'Source';

  @override
  String get weatherBasisDayNight => 'Jour ou nuit là-bas';

  @override
  String get weatherDay => 'jour';

  @override
  String get weatherNight => 'nuit';

  @override
  String get weatherNotGiven => 'non indiqué';

  @override
  String get weatherBasisValid => 'Valide';

  @override
  String weatherValidAt(String time, String ago) {
    return '$time ($ago)';
  }

  @override
  String get weatherBasisTimezone => 'Fuseau horaire là-bas';

  @override
  String get weatherBasisFetched => 'Récupérée';

  @override
  String get weatherBasisKeptFor => 'Gardée pour';

  @override
  String get weatherKeptThisCity => 'cette ville';

  @override
  String get weatherKeptOther => 'un autre réglage de position';

  @override
  String get weatherJustNow => 'à l\'instant';

  @override
  String weatherMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
    );
    return '$_temp0';
  }

  @override
  String weatherHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count h',
    );
    return '$_temp0';
  }

  @override
  String get weatherTypeTwoLetters => 'Tape au moins deux lettres.';

  @override
  String get weatherSearching => 'Recherche…';

  @override
  String weatherNoPlaces(String query) {
    return 'Aucun lieu trouvé pour « $query ».';
  }

  @override
  String get weatherCitySearchFailed =>
      'Impossible de chercher des villes pour le moment.';

  @override
  String get weatherCityLabel => 'Ville';

  @override
  String get weatherSearchTooltip => 'Rechercher';

  @override
  String todayOccasionStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'inProgress': 'En cours',
      'finished': 'Terminée',
      'partial': 'Partielle',
      'skipped': 'Sautée',
      'missed': 'Manquée',
      'due': 'Prévue aujourd\'hui',
      'upcoming': 'Planifiée',
      'other': 'En pause',
    });
    return '$_temp0';
  }

  @override
  String get shellCantSyncLabel => 'Synchronisation impossible pour le moment';

  @override
  String shellWaitingToSync(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente de synchronisation',
      one: '$count modification en attente de synchronisation',
    );
    return '$_temp0';
  }

  @override
  String shellCantSyncWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Synchronisation impossible pour le moment · $count modifications en attente',
      one:
          'Synchronisation impossible pour le moment · $count modification en attente',
    );
    return '$_temp0';
  }

  @override
  String workoutTargetSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '$count série',
    );
    return '$_temp0';
  }

  @override
  String workoutTargetRepRange(String range) {
    return '$range répétitions';
  }

  @override
  String workoutTargetReps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count répétitions',
      one: '$count répétition',
    );
    return '$_temp0';
  }

  @override
  String get workoutNoTarget => 'Aucune cible';

  @override
  String get workoutOutcomeFull => 'Terminée';

  @override
  String get workoutOutcomePartial => 'Terminée en partie';

  @override
  String get workoutOutcomeNoData => 'Aucun entraînement consigné';

  @override
  String get workoutOutcomeManual => 'Enregistrée';

  @override
  String get workoutOutcomeOpen => 'En cours';

  @override
  String get workoutSetBodyweight => 'Poids du corps';

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
      'Entre la charge en chiffres (zéro ou plus), ou laisse le champ vide pour le poids du corps.';

  @override
  String get workoutInvalidLoadRange => 'Entre une charge de zéro ou plus.';

  @override
  String get workoutInvalidNothingDone =>
      'Entre les répétitions ou le temps réellement faits.';

  @override
  String get workoutInvalidOutOfRange => 'Cette valeur est hors limites.';

  @override
  String get workoutInvalidHasSets =>
      'Supprime d\'abord ses séries enregistrées.';

  @override
  String get workoutAllWorkoutsLink => 'Toutes les séances';

  @override
  String get workoutSelectSaveFailed =>
      'Le changement d\'exercice n\'a pas pu être enregistré sur ce téléphone. Tes séries et ta saisie sont inchangées; réessaie.';

  @override
  String get workoutUseLastConfirmTitle => 'Remplacer ce que tu as saisi?';

  @override
  String get workoutUseLastConfirmBody =>
      'La saisie de cette série affichera plutôt les valeurs de la dernière séance. Rien n\'est enregistré avant que tu touches Enregistrer la série.';

  @override
  String get workoutUseLastValues => 'Reprendre les dernières valeurs';

  @override
  String workoutUseLastValuesSemantic(String set) {
    return 'Reprendre les dernières valeurs : $set';
  }

  @override
  String get workoutUseLastKeepMine => 'Garder les miennes';

  @override
  String workoutSetSavedSnack(String set) {
    return 'Enregistrée sur ce téléphone : $set';
  }

  @override
  String get workoutUndo => 'Annuler';

  @override
  String get workoutSetNotSaved =>
      'Non enregistrée. Ta saisie est toujours là. Touche de nouveau pour réessayer.';

  @override
  String get workoutEditSetTitle => 'Modifier la série';

  @override
  String get workoutLoadLabel => 'Charge';

  @override
  String get workoutSecondsLabel => 'Secondes';

  @override
  String get workoutRepsLabel => 'Répétitions';

  @override
  String get workoutTimeLabel => 'Temps';

  @override
  String get workoutSecondsUnit => 's';

  @override
  String workoutFieldWithUnit(String label, String unit) {
    return '$label ($unit)';
  }

  @override
  String get workoutDeleteSet => 'Supprimer la série';

  @override
  String get workoutSetRemoved => 'Série supprimée.';

  @override
  String get workoutSetEditFailed =>
      'Cette modification n\'a pas pu être enregistrée sur ce téléphone. La série est inchangée.';

  @override
  String get workoutFinishNoDataTitle => 'Aucun entraînement consigné';

  @override
  String get workoutFinishTitle => 'Terminer la séance?';

  @override
  String get workoutFinishNoDataBodyPlanned =>
      'Aucune série n\'a été enregistrée. Tu peux la garder comme une séance sans entraînement : elle ne compte pas comme entraînement et la séance prévue reste disponible. Le temps écoulé seul n\'est pas de l\'entraînement.';

  @override
  String get workoutFinishNoDataBodyManual =>
      'Aucune série n\'a été enregistrée. Tu peux la garder comme une séance sans entraînement : elle ne compte pas comme entraînement. Le temps écoulé seul n\'est pas de l\'entraînement.';

  @override
  String workoutFinishSummary(int sets, int exercises) {
    String _temp0 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets séries enregistrées',
      one: '$sets série enregistrée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      exercises,
      locale: localeName,
      other: '$exercises exercices',
      one: '$exercises exercice',
    );
    return '$_temp0 pour $_temp1.';
  }

  @override
  String workoutFinishMissing(String names) {
    return 'Pas entièrement enregistrés : $names. Tu peux quand même terminer; la séance sera enregistrée comme partielle.';
  }

  @override
  String get workoutListSeparator => ', ';

  @override
  String get workoutKeepTraining => 'Continuer l\'entraînement';

  @override
  String get workoutSaveWithoutTraining => 'Enregistrer sans entraînement';

  @override
  String get workoutFinishButton => 'Terminer la séance';

  @override
  String get workoutFinishFailed =>
      'La séance n\'a pas pu être terminée sur ce téléphone. Rien n\'a changé. Réessaie.';

  @override
  String get workoutAddMovement => 'Ajouter un exercice';

  @override
  String workoutReplaceMovementTitle(String name) {
    return 'Remplacer $name';
  }

  @override
  String get workoutRemoveTitle => 'Supprimer cette séance?';

  @override
  String workoutRemoveOpenBody(String title) {
    return 'Cela supprime « $title » et toutes les séries enregistrées. C\'est la seule façon de supprimer une séance; elle n\'est jamais supprimée automatiquement.';
  }

  @override
  String get workoutRemoveAction => 'Supprimer la séance';

  @override
  String get workoutMissingTitle => 'Cette séance n\'est pas sur ce téléphone';

  @override
  String get workoutMissingBody =>
      'Elle a peut-être été supprimée. Rien d\'autre n\'a changé.';

  @override
  String get workoutHelpSemantic => 'Aide pour enregistrer cette séance';

  @override
  String get workoutHelpTitle => 'Enregistrer des séries';

  @override
  String get workoutHelpBody =>
      'Enregistre chaque série dès que tu la termines; la minuterie de repos démarre alors toute seule. Dernière séance montre ce que tu as vraiment fait, et Reprendre les dernières valeurs ne fait que remplir la saisie. Garder pour plus tard conserve tout.';

  @override
  String get workoutOptionsTooltip => 'Options de la séance';

  @override
  String get workoutReplaceThisMovement => 'Remplacer cet exercice';

  @override
  String get workoutRemoveThisMovement => 'Retirer cet exercice';

  @override
  String get workoutSaveForLater => 'Garder pour plus tard';

  @override
  String workoutTimeSemantic(String duration) {
    return 'Durée de la séance $duration';
  }

  @override
  String workoutTimePausedSemantic(String duration) {
    return 'Durée de la séance $duration, en pause';
  }

  @override
  String get workoutResume => 'Reprendre';

  @override
  String get workoutPause => 'Pause';

  @override
  String get workoutParkedStatus =>
      'Gardée pour plus tard. Tout ce qui est enregistré est conservé; reprends-la pour en enregistrer davantage.';

  @override
  String get workoutResumeWorkout => 'Reprendre la séance';

  @override
  String get workoutPausedStatus =>
      'Séance en pause. Le temps et le repos sont figés jusqu\'à ce que tu reprennes.';

  @override
  String get workoutNeedsReviewStatus =>
      'Enregistrée sur ce téléphone; cette séance doit être vérifiée avant de pouvoir être synchronisée. Consulte l\'avis de vérification au bas de l\'écran.';

  @override
  String workoutSetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries enregistrées',
      one: '$count série enregistrée',
    );
    return '$_temp0';
  }

  @override
  String workoutPlannedSetsRecorded(int counted, int planned) {
    return '$counted des $planned séries prévues enregistrées';
  }

  @override
  String get workoutPlannedSetsRail => 'Séries prévues enregistrées';

  @override
  String get workoutNoMovementsTitle => 'Aucun exercice pour l\'instant';

  @override
  String get workoutNoMovementsBody =>
      'Ajoute un exercice pour commencer à enregistrer des séries.';

  @override
  String workoutMovementPosition(int index, int total) {
    return 'Exercice $index sur $total';
  }

  @override
  String workoutMovementPositionExtra(int index, int total) {
    return 'Exercice $index sur $total · ajouté';
  }

  @override
  String workoutSubstitutedNote(String name) {
    return 'Enregistré comme $name, à la place de l\'exercice prévu.';
  }

  @override
  String get workoutAbout => 'À propos';

  @override
  String workoutAboutSemantic(String name) {
    return 'À propos de $name';
  }

  @override
  String get workoutTargetInWorkout => 'Cible dans cette séance';

  @override
  String get workoutRestEnded => 'Repos terminé';

  @override
  String get workoutRestOverline => 'Repos';

  @override
  String get workoutRestFromPrevious => 'Repos · de l\'exercice précédent';

  @override
  String workoutRestSemantic(String duration) {
    return 'Repos, $duration restantes';
  }

  @override
  String get workoutRestAdd30 => '+30 s';

  @override
  String get workoutRestDismiss => 'Fermer';

  @override
  String get workoutRestSkip => 'Passer le repos';

  @override
  String workoutNextSetOverline(int number) {
    return 'Série $number · pas encore enregistrée';
  }

  @override
  String get workoutTargetReachedLast =>
      'Nombre de séries cible enregistré. C\'est le dernier exercice : ajoute une autre série, ou termine la séance quand tu veux.';

  @override
  String get workoutTargetReached =>
      'Nombre de séries cible enregistré. Ajoute une autre série, ou passe à la suite quand tu veux.';

  @override
  String get workoutRecordSet => 'Enregistrer la série';

  @override
  String get workoutRecordAnotherSet => 'Enregistrer une autre série';

  @override
  String workoutNextExercise(String name) {
    return 'Exercice suivant · $name';
  }

  @override
  String get workoutRecordedSetsOverline => 'Séries enregistrées';

  @override
  String get workoutNoRecordedSets =>
      'Aucune pour l\'instant. Les cibles, la dernière séance et les suggestions ne sont pas des séries enregistrées.';

  @override
  String workoutSetRowTitle(int number, String set) {
    return '$number.  $set';
  }

  @override
  String get workoutSetNeedsReview => 'À vérifier';

  @override
  String get workoutSetPending =>
      'Enregistrée · sur ce téléphone, synchronisation en attente';

  @override
  String get workoutSetRecorded => 'Enregistrée';

  @override
  String get workoutAllMovementsOverline => 'Tous les exercices';

  @override
  String workoutMovementSetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries enregistrées',
      one: '$count série enregistrée',
    );
    return '$_temp0';
  }

  @override
  String workoutMovementSetsOfTarget(int count, int target) {
    return '$count séries sur $target enregistrées';
  }

  @override
  String workoutMovementCurrent(String status) {
    return '$status · en cours';
  }

  @override
  String get workoutHistoryLoading => 'Lecture de tes séances précédentes…';

  @override
  String get workoutHistoryUnavailable =>
      'Tes séances précédentes n\'ont pas pu être lues sur ce téléphone pour l\'instant.';

  @override
  String get workoutHistoryNoIdentity =>
      'Aucun historique : cet exercice n\'est lié à aucun exercice enregistré, donc rien n\'est associé par son nom.';

  @override
  String get workoutHistoryNone => 'Aucune séance précédente enregistrée.';

  @override
  String workoutCompareLastLabeled(String value) {
    return 'Dernière séance : $value';
  }

  @override
  String workoutCompareTodayLabeled(String value) {
    return 'Aujourd\'hui : $value';
  }

  @override
  String workoutCompareRecordedSemantic(String set) {
    return 'Enregistrée : $set';
  }

  @override
  String get workoutCompareNext => 'Suivante · pas encore enregistrée';

  @override
  String get workoutCompareNotYet => 'Pas encore enregistrée';

  @override
  String workoutCompareSetNumber(int number) {
    return 'Série $number';
  }

  @override
  String get workoutCompareSet => 'Série';

  @override
  String get workoutCompareToday => 'Aujourd\'hui';

  @override
  String get workoutLastTime => 'Dernière séance';

  @override
  String workoutLastTimeOn(String date) {
    return 'Dernière séance · $date';
  }

  @override
  String get workoutAllSessions => 'Toutes les séances';

  @override
  String get workoutAllSessionsSemantic => 'Toutes les séances précédentes';

  @override
  String get workoutHistorySheetCaption =>
      'Séances précédentes, de la plus récente à la plus ancienne : séances qui comptent comme entraînement, associées par cet exercice et sa place dans la séance.';

  @override
  String get workoutPreviewGoneTitle => 'Cette séance n\'est plus prévue';

  @override
  String get workoutPreviewGoneBody =>
      'Le programme a changé depuis son ouverture. Rien n\'a été commencé ni enregistré.';

  @override
  String workoutPreviewSession(int number) {
    return 'Séance $number';
  }

  @override
  String workoutPreviewWeek(int number) {
    return 'Semaine $number';
  }

  @override
  String workoutPreviewExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercices',
      one: '$count exercice',
    );
    return '$_temp0';
  }

  @override
  String workoutPreviewPlannedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries prévues',
      one: '$count série prévue',
    );
    return '$_temp0';
  }

  @override
  String get workoutPreviewToday => 'Aujourd\'hui';

  @override
  String workoutPreviewMinutesPlanned(int minutes) {
    return '$minutes min prévues';
  }

  @override
  String get workoutStart => 'Commencer la séance';

  @override
  String get workoutPreviewViewRecorded => 'Voir ce qui a été enregistré';

  @override
  String get workoutPreviewMoreOptions => 'Plus d\'options';

  @override
  String get workoutPreviewMoreOptionsSemantic =>
      'Déplacer, sauter ou modifier cette séance';

  @override
  String get workoutPreviewExercises => 'Exercices';

  @override
  String get workoutPreviewNoExercises =>
      'Aucun exercice n\'est prévu dans cette séance.';

  @override
  String workoutPreviewSeeAll(int count) {
    return 'Voir les $count exercices';
  }

  @override
  String get workoutPreviewPlanPaused =>
      'Le programme est en pause. Reprends-le pour commencer ses séances.';

  @override
  String get workoutPreviewSkipped =>
      'Sautée. Rien n\'a été enregistré pour elle.';

  @override
  String get workoutPreviewRotationOrder =>
      'Une rotation suit son ordre : celle-ci vient après les séances qui la précèdent.';

  @override
  String get workoutPreviewCannotStart =>
      'Cette séance ne peut pas être commencée maintenant. Plus d\'options montre ce qu\'il est possible d\'en faire.';

  @override
  String get workoutPreviewFooter =>
      'Dernière séance montre ce que tu as vraiment enregistré avant. Rien ici n\'est enregistré avant que tu commences.';

  @override
  String workoutPreviewTarget(String load) {
    return 'Cible $load';
  }

  @override
  String get workoutSetATarget => 'Fixer une cible';

  @override
  String get workoutReviewTarget => 'Revoir la cible';

  @override
  String workoutTargetForSemantic(String name) {
    return 'Cible pour $name';
  }

  @override
  String get workoutOutcomeFullExplain =>
      'Chaque exercice prévu a son nombre de séries cible enregistré.';

  @override
  String get workoutOutcomePartialExplain =>
      'Un vrai entraînement a été enregistré. Une partie du travail prévu ne l\'a pas été; c\'est indiqué plus bas.';

  @override
  String get workoutOutcomeNoDataExplainPlanned =>
      'Aucun entraînement n\'a été consigné : cela ne compte pas comme entraînement et la séance prévue est toujours disponible.';

  @override
  String get workoutOutcomeNoDataExplainManual =>
      'Aucun entraînement n\'a été consigné : cela ne compte pas comme entraînement.';

  @override
  String get workoutOutcomeManualExplain =>
      'Enregistrée comme entraînement libre. Elle ne coche aucune séance prévue.';

  @override
  String get workoutOutcomeOpenExplain =>
      'Cette séance est encore ouverte. Elle n\'est jamais terminée automatiquement.';

  @override
  String workoutRemoveRecordedBody(String title, String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ses $count séries enregistrées',
      one: 'sa série enregistrée',
    );
    return 'Cela supprime « $title » du $date et $_temp0 de ton historique.';
  }

  @override
  String workoutDateManual(String date) {
    return '$date · libre';
  }

  @override
  String get workoutSyncPending =>
      'Enregistré sur ce téléphone · synchronisation en attente';

  @override
  String get workoutDetailNeedsReview =>
      'Enregistrée sur ce téléphone; à vérifier avant de pouvoir être synchronisée.';

  @override
  String get workoutFactTime => 'Durée';

  @override
  String get workoutFactSets => 'Séries';

  @override
  String get workoutFactMovements => 'Exercices';

  @override
  String workoutPlannedTarget(String target) {
    return 'Prévu · $target';
  }

  @override
  String get workoutExerciseNotRecorded => 'Non enregistré.';

  @override
  String get workoutExerciseNoSets => 'Aucune série enregistrée.';

  @override
  String get workoutDetailEmptyTitle => 'Rien d\'enregistré';

  @override
  String get workoutDetailEmptyBody => 'Cette séance n\'a aucun exercice.';

  @override
  String get workoutHistoryTitle => 'Historique des séances';

  @override
  String get workoutHistoryEmptyTitle => 'Aucune séance pour l\'instant';

  @override
  String get workoutHistoryEmptyBody =>
      'Les séances que tu enregistres apparaîtront ici avec ce que tu as vraiment fait.';

  @override
  String workoutSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '$count série',
    );
    return '$_temp0';
  }

  @override
  String get workoutManualTag => 'libre';

  @override
  String workoutStillOpenTitle(String title) {
    return '$title est encore ouverte';
  }

  @override
  String get workoutStillOpenBody =>
      'Une seule séance peut être en cours à la fois. Reprends-la, ou garde-la pour plus tard. La garder pour plus tard conserve chaque série enregistrée et ne la termine jamais.';

  @override
  String get workoutStillOpenPark => 'La garder pour plus tard et continuer';

  @override
  String get workoutStillOpenResume => 'La reprendre';

  @override
  String get workoutStartFailed =>
      'La séance n\'a pas pu être commencée sur ce téléphone. Rien n\'a été enregistré. Réessaie.';

  @override
  String get workoutPickerTitle => 'Choisir un exercice';

  @override
  String get workoutPickerSearch => 'Rechercher des exercices';

  @override
  String get workoutPickerCatalogEmpty =>
      'La liste d\'exercices n\'a pas encore été téléchargée sur ce téléphone. Tu peux quand même créer ton propre exercice.';

  @override
  String get workoutPickerMuscle => 'Groupe musculaire';

  @override
  String get workoutPickerEquipment => 'Équipement';

  @override
  String get workoutPickerNoMatch =>
      'Aucun exercice ne correspond. Essaie un autre nom ou filtre, ou crée le tien.';

  @override
  String get workoutPickerTimedTag => 'chronométré';

  @override
  String get workoutPickerYourExercise => 'Ton exercice';

  @override
  String get workoutPickerCreate => 'Créer ton propre exercice';

  @override
  String workoutPickerCreateNamed(String name) {
    return 'Créer « $name » comme exercice personnel';
  }

  @override
  String get workoutPickerCreateSubtitle =>
      'Privé à ton compte. Il garde son propre historique.';

  @override
  String get workoutCustomTitle => 'Ton propre exercice';

  @override
  String get workoutSaveFailedRetry =>
      'Impossible de l\'enregistrer sur ce téléphone. Réessaie.';

  @override
  String get workoutCustomCaption =>
      'Tu es la seule personne à voir tes propres exercices. Les renommer plus tard ne change jamais ce que tu as déjà enregistré.';

  @override
  String get workoutCustomName => 'Nom';

  @override
  String get workoutCustomTimed => 'Chronométré';

  @override
  String get workoutCustomTimedHelp =>
      'Tenu ou fait pendant un temps, comme une planche, au lieu de répétitions comptées.';

  @override
  String get workoutCustomSave => 'Enregistrer l\'exercice';

  @override
  String get workoutManualTitle => 'Séance libre';

  @override
  String get workoutManualCaption =>
      'Entraîne-toi sans programme. C\'est enregistré comme un vrai entraînement et ne coche jamais une séance prévue.';

  @override
  String get workoutManualDefaultName => 'Séance';

  @override
  String get workoutManualMovements => 'Exercices';

  @override
  String get workoutManualNone =>
      'Aucun pour l\'instant. Tu peux aussi en ajouter après avoir commencé.';

  @override
  String workoutManualRemove(String name) {
    return 'Retirer $name';
  }

  @override
  String workoutProgressionDaysBoth(String date) {
    return 'les deux le $date';
  }

  @override
  String workoutProgressionDaysPair(String first, String second) {
    return '$first et $second';
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
    return 'Lors de tes deux dernières séances $workout ($days), tu as enregistré les $sets séries de $exercise à $target avec $top répétitions ou plus, le haut de ta fourchette de $range.';
  }

  @override
  String get workoutProgressionConfigureIncrement =>
      'Choisis l\'incrément de charge que ton équipement permet pour voir une prochaine cible.';

  @override
  String workoutProgressionIncrementTooLarge(String increment) {
    return 'Ton incrément de $increment dépasse 5 % de cette cible, donc GoHard ne le suggère pas automatiquement. Tu peux quand même revoir la cible toi-même.';
  }

  @override
  String workoutProgressionBelowTop(String workout, int top, String target) {
    return 'Une série d\'une de tes deux dernières séances $workout était sous $top répétitions à $target.';
  }

  @override
  String workoutProgressionSetsMissing(
    String workout,
    int sets,
    String exercise,
  ) {
    return 'Une de tes deux dernières séances $workout compte moins de $sets séries de $exercise enregistrées.';
  }

  @override
  String workoutProgressionExtraSets(
    String workout,
    int sets,
    String exercise,
  ) {
    return 'Une de tes deux dernières séances $workout compte plus de $sets séries de $exercise, et les échauffements ne sont pas indiqués, donc elles ne peuvent pas être comparées.';
  }

  @override
  String workoutProgressionLoadUnknown(String workout) {
    return 'Une série d\'une de tes deux dernières séances $workout n\'a pas de charge enregistrée.';
  }

  @override
  String workoutProgressionLoadDiffers(String workout, String target) {
    return 'Une de tes deux dernières séances $workout a utilisé une charge autre que $target.';
  }

  @override
  String workoutProgressionPartial(String workout) {
    return 'Une de tes deux dernières séances $workout a été enregistrée comme partielle.';
  }

  @override
  String workoutProgressionNotAsPlanned(String workout, String exercise) {
    return 'Une de tes deux dernières séances $workout n\'incluait pas $exercise comme prévu.';
  }

  @override
  String workoutProgressionStays(String target) {
    return 'La cible reste à $target.';
  }

  @override
  String workoutProgressionTargetChanged(String workout, String target) {
    return 'Ta cible a changé depuis ta dernière séance $workout. Deux séances à $target sont nécessaires avant d\'envisager une hausse.';
  }

  @override
  String workoutProgressionNeedTwo(String workout, String target, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrées',
      one: '$count enregistrée',
    );
    return 'Deux séances $workout à $target sont nécessaires avant d\'envisager une hausse; $_temp0 jusqu\'ici.';
  }

  @override
  String workoutProgressionNoLoadTarget(String workout) {
    return 'Cet exercice n\'a pas de charge cible dans $workout. Fixes-en une si tu veux que tes séances y soient comparées.';
  }

  @override
  String workoutProgressionNoRange(String workout) {
    return 'Cet exercice n\'a pas de nombre de séries ni de fourchette de répétitions dans $workout pour comparer.';
  }

  @override
  String get workoutProgressionTimed =>
      'Cet exercice est chronométré, donc GoHard ne calcule pas de charge pour lui. Tu peux fixer tes cibles toi-même.';

  @override
  String get workoutProgressionBodyweight =>
      'GoHard ne calcule pas de charge pour les exercices au poids du corps ou assistés. Tu peux fixer tes cibles toi-même.';

  @override
  String get workoutProgressionNoIdentity =>
      'Cet exercice n\'est lié à aucun exercice enregistré, donc ses séances ne sont pas comparées.';

  @override
  String get workoutNextTimeHeader => 'La prochaine fois';

  @override
  String get workoutNextTimeHelpLabel => 'À propos des prochaines cibles';

  @override
  String workoutNextTimeCoachIncrease(String exercise) {
    return 'Tu as atteint le haut de ta fourchette de répétitions lors de tes deux dernières séances comparables de $exercise. Tu peux revoir une prochaine cible facultative.';
  }

  @override
  String workoutNextTimeCoachIncrement(String exercise) {
    return 'Tu as atteint le haut de ta fourchette de répétitions lors de tes deux dernières séances comparables de $exercise. Indique-moi ton incrément de charge et je pourrai calculer une prochaine cible.';
  }

  @override
  String get workoutProgressionHowTitle => 'Comment fonctionne la progression';

  @override
  String workoutNextTimeRowReview(String change) {
    return '$change · Revoir';
  }

  @override
  String get workoutChooseIncrement => 'Choisis ton incrément de charge';

  @override
  String get workoutCurrentTarget => 'Cible actuelle';

  @override
  String get workoutProposed => 'Proposée';

  @override
  String get workoutReviewNextTarget => 'Revoir la prochaine cible';

  @override
  String get workoutKeepCurrentTarget => 'Garder la cible actuelle';

  @override
  String workoutKeptTarget(String load) {
    return '$load conservée. Rien n\'a changé dans ton programme.';
  }

  @override
  String get workoutSaveFailedNothingChanged =>
      'Impossible de l\'enregistrer sur ce téléphone. Rien n\'a changé; réessaie.';

  @override
  String get workoutNoNextTarget => 'Aucune prochaine charge cible';

  @override
  String workoutNextTargetValue(String load) {
    return 'Prochaine cible · $load';
  }

  @override
  String get workoutReviewSuggestion => 'Revoir la suggestion';

  @override
  String get workoutReview => 'Revoir';

  @override
  String workoutSetNextTargetSemantic(String name) {
    return 'Fixer une prochaine cible pour $name';
  }

  @override
  String workoutReviewNextTargetSemantic(String name) {
    return 'Revoir la prochaine cible pour $name';
  }

  @override
  String get workoutNextTargetTitle => 'Prochaine cible';

  @override
  String get workoutTargetLoadError =>
      'Entre une charge supérieure à zéro, ou laisse vide pour aucune charge cible.';

  @override
  String get workoutTargetRangeError =>
      'Utilise de 1 à 20 séries et une fourchette de 1 à 100 répétitions, le plus petit nombre en premier.';

  @override
  String get workoutTargetSaveFailed =>
      'Impossible de l\'enregistrer sur ce téléphone. Rien n\'a changé; réessaie.';

  @override
  String get workoutTargetRestored => 'Cible précédente rétablie.';

  @override
  String get workoutTargetGone =>
      'Cet exercice n\'est plus dans cette séance du programme, donc il n\'y a pas de prochaine cible à revoir. Rien n\'a été modifié.';

  @override
  String workoutTargetScope(String workout) {
    return 'S\'applique dès la prochaine fois que tu commences $workout, jusqu\'à ce que tu la changes. La séance d\'aujourd\'hui et les précédentes gardent ce qu\'elles ont enregistré.';
  }

  @override
  String workoutReviewCurrent(String load, String prescription) {
    return 'Cible actuelle : $load · $prescription';
  }

  @override
  String get workoutNoWeightTarget => 'aucune charge cible';

  @override
  String workoutTargetSaved(String scope) {
    return 'Prochaine cible enregistrée. $scope';
  }

  @override
  String get workoutEditNextTarget => 'Modifier la prochaine cible';

  @override
  String workoutRestorePrevious(String target) {
    return 'Rétablir la cible précédente ($target)';
  }

  @override
  String get workoutSaveNextTarget => 'Enregistrer la prochaine cible';

  @override
  String workoutUseLoadFromNext(String load) {
    return 'Utiliser $load dès la prochaine séance';
  }

  @override
  String get workoutYourLastSessions => 'Tes dernières séances';

  @override
  String workoutSessionLine(String date, String sets) {
    return '$date : $sets';
  }

  @override
  String get workoutNotRecordedLower => 'non enregistré';

  @override
  String workoutSuggestedLine(String proposed, String increment) {
    return 'Suggérée : $proposed, un incrément de $increment. Seule la charge est suggérée; les séries et répétitions ne changent que si tu les modifies.';
  }

  @override
  String get workoutWeightLabel => 'Charge';

  @override
  String workoutUseLastRecordedLoad(String load) {
    return 'Utiliser la dernière charge enregistrée ($load)';
  }

  @override
  String get workoutSetsLabel => 'Séries';

  @override
  String get workoutRepsFrom => 'Répétitions de';

  @override
  String get workoutRepsTo => 'Répétitions à';

  @override
  String get workoutRepsToShort => 'à';

  @override
  String workoutIncrementChange(String increment) {
    return 'Incrément de charge $increment · Changer';
  }

  @override
  String get workoutNoChangeToSave => 'Aucun changement à enregistrer';

  @override
  String get workoutIncrementTitle => 'Incrément de charge';

  @override
  String workoutIncrementRangeError(String max) {
    return 'Entre un incrément supérieur à zéro et d\'au plus $max.';
  }

  @override
  String workoutIncrementCaption(String exercise) {
    return 'L\'incrément que GoHard ajoute quand il suggère une cible plus lourde pour $exercise, et seulement à ce moment. Choisis la plus petite hausse que permettent tes disques, haltères ou appareil. Les gyms diffèrent, donc rien n\'est choisi pour toi.';
  }

  @override
  String get workoutIncrementConvention =>
      'GoHard garde une charge exactement comme tu l\'enregistres. Utilise la même convention que pour tes séries : si tu enregistres les haltères par main, entre l\'incrément par main; pour une barre, le changement total sur la barre.';

  @override
  String workoutIncrementSaved(String increment) {
    return 'Enregistré : $increment';
  }

  @override
  String workoutIncrementSavedPending(String increment) {
    return 'Enregistré : $increment · synchronisation en attente';
  }

  @override
  String get workoutIncrementAnother => 'Autre incrément';

  @override
  String get workoutIncrementLocalOnly =>
      'Enregistré sur ce téléphone. Le serveur de ton compte ne conserve pas encore les incréments; la synchronisation se fera une fois le serveur mis à jour.';

  @override
  String get workoutChooseStep => 'Choisis un incrément';

  @override
  String workoutSaveStep(String increment) {
    return 'Enregistrer $increment';
  }

  @override
  String get workoutIncrementRemove => 'Retirer cet incrément';

  @override
  String get workoutProgressionHelp1 =>
      'Une cible, c\'est ce que tu prévois de soulever. Dernière séance, c\'est ce que tu as enregistré avant. Aujourd\'hui montre seulement les séries que tu enregistres vraiment. Les suggestions n\'enregistrent jamais de série.';

  @override
  String get workoutProgressionHelp2 =>
      'GoHard regarde tes deux séances les plus récentes de la même séance du programme. Si les deux ont toutes les séries prévues d\'un exercice à sa charge cible, avec des répétitions au haut de sa fourchette, il suggère la cible plus un incrément de charge que tu as choisi.';

  @override
  String get workoutProgressionHelp3 =>
      'Il ne remonte jamais plus loin que ces deux séances, n\'ajoute jamais de séries, ne change pas les répétitions, ne remplace pas d\'exercices et ne baisse jamais une charge de lui-même. Les exercices chronométrés, au poids du corps et assistés gardent des cibles manuelles.';

  @override
  String get workoutProgressionHelp4 =>
      'Un incrément de plus de 5 % de la cible actuelle n\'est pas suggéré automatiquement; tu peux quand même fixer la cible toi-même. Cette limite est un choix de produit de GoHard, pas un seuil de sécurité.';

  @override
  String get workoutProgressionHelp5 =>
      'Les répétitions ne disent rien de l\'effort, de la technique, de la douleur ou de la récupération. Une suggestion est facultative : revois-la, modifie-la ou garde ta cible actuelle. Rien ne change avant que tu confirmes.';

  @override
  String get workoutProgressionHelpSources =>
      'Recommandations publiées : la prise de position de l\'ACSM de 2009 décrit une hausse de la charge d\'environ 2 à 10 % lorsque tu peux faire une ou deux répétitions de plus que ta cible lors de deux séances consécutives. La prise de position de l\'ACSM de 2026 recommande un entraînement en résistance progressif et note que la surcharge continue compte surtout pour les progrès à plus long terme. La règle de GoHard (le haut de ta fourchette lors de tes deux dernières séances, un incrément que tu as choisi, au plus 5 %) est son propre choix de produit; aucun de ces documents ne la teste ni ne la valide.';

  @override
  String progressCoachWorkoutsOfTarget(int count, int target) {
    return '$count séances sur $target enregistrées cette semaine.';
  }

  @override
  String progressCoachRunWalkOfTarget(int count, int target) {
    return '$count courses ou marches sur $target enregistrées cette semaine.';
  }

  @override
  String progressCoachSoFar(int workouts, int activities) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts séances',
      one: '$workouts séance',
    );
    String _temp1 = intl.Intl.pluralLogic(
      activities,
      locale: localeName,
      other: '$activities courses ou marches',
      one: '$activities course ou marche',
    );
    return 'Cette semaine jusqu\'ici : $_temp0 et $_temp1 enregistrées.';
  }

  @override
  String progressCoachSoFarSetGoals(int workouts, int activities) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts séances',
      one: '$workouts séance',
    );
    String _temp1 = intl.Intl.pluralLogic(
      activities,
      locale: localeName,
      other: '$activities courses ou marches',
      one: '$activities course ou marche',
    );
    return 'Cette semaine jusqu\'ici : $_temp0 et $_temp1 enregistrées. Fixe des objectifs hebdomadaires plus bas si tu veux une cible.';
  }

  @override
  String get progressCoachNothingYet =>
      'Rien d\'enregistré cette semaine pour l\'instant. Fixe des objectifs hebdomadaires plus bas si tu veux une cible.';

  @override
  String get progressCoachContextLabel => 'Ta progression';

  @override
  String get progressStrengthTrends => 'Tendances de force';

  @override
  String get progressSeeAll => 'Tout voir';

  @override
  String get progressSeeAllTrendsSemantic =>
      'Voir toutes les tendances des exercices';

  @override
  String get progressNoStableTrend =>
      'Aucun exercice à identité stable n\'a encore de séries enregistrées. Les exercices saisis en texte libre n\'ont pas de tendance.';

  @override
  String get progressNoTrainingTitle =>
      'Aucun entraînement enregistré pour l\'instant';

  @override
  String get progressNoTrainingBody =>
      'Les tendances viennent seulement des séances que tu enregistres vraiment. Il n\'y a rien à afficher d\'ici là.';

  @override
  String get progressStartManual => 'Commencer une séance libre';

  @override
  String get progressBodyLink => 'Progrès corporels';

  @override
  String get progressBodyLinkSemantic =>
      'Ouvrir Progrès corporels : poids et mensurations';

  @override
  String get progressPlanHeader => 'Est-ce que je suis mon programme?';

  @override
  String get progressNoPrimary =>
      'Tu n\'as pas de programme principal pour l\'instant. L\'entraînement libre compte quand même.';

  @override
  String get progressNothingDue =>
      'Aucune séance prévue n\'est encore arrivée à échéance.';

  @override
  String progressDueRecorded(int recorded, int due) {
    return '$recorded séances sur $due dues enregistrées';
  }

  @override
  String get progressDueRail => 'Séances dues enregistrées';

  @override
  String progressAdherenceBreakdown(
    int full,
    int partial,
    int skipped,
    int missed,
  ) {
    return '$full terminées · $partial partielles · $skipped sautées · $missed manquées';
  }

  @override
  String get progressPlansLink => 'Programmes';

  @override
  String get progressViewPlan => 'Voir ton programme';

  @override
  String get progressOpenPlanSemantic => 'Ouvrir Entraînement, Programme';

  @override
  String get progressGoalsSeparate =>
      'Les objectifs hebdomadaires sont distincts : ils ne planifient, ne déplacent et ne terminent jamais une séance prévue.';

  @override
  String get progressConsistencyHeader => 'Suis-je constant?';

  @override
  String progressConsistencyCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances',
      one: '$count séance',
    );
    return 'Jours avec entraînement enregistré dans chacune des 8 dernières semaines. $_temp0 au total.';
  }

  @override
  String progressConsistencySemantic(String days) {
    return 'Jours d\'entraînement par semaine, du plus ancien au plus récent : $days';
  }

  @override
  String get progressWorkoutsLabel => 'Séances';

  @override
  String get progressRunWalkLabel => 'Course / marche';

  @override
  String progressWorkoutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances',
      one: '$count séance',
    );
    return '$_temp0';
  }

  @override
  String progressRunWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses ou marches',
      one: '$count course ou marche',
    );
    return '$_temp0';
  }

  @override
  String progressRunCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses',
      one: '$count course',
    );
    return '$_temp0';
  }

  @override
  String progressWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count marches',
      one: '$count marche',
    );
    return '$_temp0';
  }

  @override
  String progressGoalSaidNoTarget(String what, String counted) {
    return '$what : $counted cette semaine, aucune cible.';
  }

  @override
  String progressGoalSaidTarget(String what, int count, int target) {
    return '$what : $count sur $target cette semaine.';
  }

  @override
  String get progressThisWeek => 'Cette semaine';

  @override
  String get progressWeeklyRhythm => 'Ton rythme de la semaine';

  @override
  String get progressEditGoals => 'Modifier les objectifs';

  @override
  String get progressSetGoals => 'Fixer des objectifs hebdomadaires';

  @override
  String get progressEditGoalsSemantic =>
      'Modifier les objectifs hebdomadaires';

  @override
  String get progressGoalsUnavailable =>
      'Les objectifs hebdomadaires ne sont pas encore offerts par le serveur de ton compte, donc aucun ne peut être enregistré. Tes totaux sont quand même affichés.';

  @override
  String get progressGoalsPending =>
      'Objectifs enregistrés sur ce téléphone · synchronisation en attente';

  @override
  String get progressGoalsReview =>
      'Les objectifs de cette semaine ont aussi été modifiés sur un autre appareil. Vérifie-les à partir de l\'avis au bas de l\'écran.';

  @override
  String progressCountRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrées',
      one: '$count enregistrée',
    );
    return '$_temp0';
  }

  @override
  String progressCountOfTarget(int count, int target) {
    return '$count sur $target';
  }

  @override
  String progressCountOfTargetReached(int count, int target) {
    return '$count sur $target · atteint';
  }

  @override
  String progressGoalRail(String label) {
    return 'Objectif $label';
  }

  @override
  String get progressGoalsTitle => 'Objectifs hebdomadaires';

  @override
  String get progressGoalsSaveFailed =>
      'Tes objectifs n\'ont pas pu être enregistrés sur ce téléphone. Rien n\'a changé.';

  @override
  String get progressGoalsCleared =>
      'Objectifs hebdomadaires retirés à partir de cette semaine.';

  @override
  String get progressGoalsSaved => 'Objectifs hebdomadaires enregistrés.';

  @override
  String progressGoalRangeError(int min, int max) {
    return 'Utilise un nombre entier de $min à $max, ou laisse vide.';
  }

  @override
  String progressGoalFieldHelper(int min, int max) {
    return 'De $min à $max par semaine, ou vide pour aucune cible';
  }

  @override
  String get progressGoalsHelper =>
      'Ce sont des cibles d\'activité hebdomadaires. Ton programme d\'entraînement reste le même.';

  @override
  String progressGoalsApply(String range) {
    return 'Ils s\'appliquent à partir de cette semaine ($range) jusqu\'à ce que tu les changes. Les semaines précédentes gardent leurs objectifs. Laisse un champ vide pour aucune cible.';
  }

  @override
  String get progressGoalWorkoutsField => 'Séances par semaine';

  @override
  String get progressGoalRunWalkField => 'Courses et marches par semaine';

  @override
  String get progressGoalsSave => 'Enregistrer les objectifs';

  @override
  String progressRecapLinkSemantic(String range) {
    return 'Bilan de la semaine dernière, $range';
  }

  @override
  String progressRecapLinkSemanticOlder(String range) {
    return 'Bilan de la semaine dernière, $range. Les semaines précédentes sont à l\'intérieur.';
  }

  @override
  String get progressRecapLinkTitle => 'Bilan de la semaine dernière';

  @override
  String progressRecapLinkOlder(String range) {
    return '$range · semaines précédentes à l\'intérieur';
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
      other: '$count séances affichées',
      one: '$count séance affichée',
    );
    return '$name. Dernier résultat enregistré : $value le $date. $metric. $_temp0.';
  }

  @override
  String progressLatestRecordedOn(String date) {
    return 'Dernier enregistrement · $date';
  }

  @override
  String get progressLatestRecorded => 'Dernier enregistrement';

  @override
  String progressRepsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count répétitions',
      one: '$count répétition',
    );
    return '$_temp0';
  }

  @override
  String progressMetricLoad(int reps) {
    return 'Charge de la meilleure série · $reps répétitions';
  }

  @override
  String get progressMetricReps =>
      'Plus de répétitions en une série · sans charge ajoutée';

  @override
  String get progressMetricDuration => 'Plus long temps enregistré';

  @override
  String get progressMetricNone => 'Aucune mesure comparable';

  @override
  String get progressNoChange => 'Aucun changement';

  @override
  String progressChangeReps(String signed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$signed répétitions',
      one: '$signed répétition',
    );
    return '$_temp0';
  }

  @override
  String get progressRange4Weeks => '4 semaines';

  @override
  String get progressRange12Weeks => '12 semaines';

  @override
  String get progressRangeAll => 'Tout';

  @override
  String progressRangeWords(String range) {
    String _temp0 = intl.Intl.selectLogic(range, {
      'weeks4': 'au cours des 4 dernières semaines',
      'weeks12': 'au cours des 12 dernières semaines',
      'other': 'dans tout ton historique',
    });
    return '$_temp0';
  }

  @override
  String progressNoSessionRange(String rangeWords) {
    return 'Aucune séance $rangeWords';
  }

  @override
  String get progressTrendsTitle => 'Tendances des exercices';

  @override
  String get progressTrendsSubtitle =>
      'Exercices que tu as enregistrés, les plus récents en premier';

  @override
  String get progressTrendsSearch => 'Rechercher tes exercices';

  @override
  String get progressTrendsEmptyTitle => 'Rien d\'enregistré pour l\'instant';

  @override
  String get progressTrendsEmptyBody =>
      'Un exercice apparaît ici dès qu\'une séance terminée en contient des séries enregistrées.';

  @override
  String get progressTrendsNoMatchTitle => 'Aucun résultat';

  @override
  String progressTrendsNoMatchBody(String query) {
    return 'Aucun de tes exercices enregistrés ne correspond à « $query ».';
  }

  @override
  String progressTrendRowSubtitle(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances',
      one: '$count séance',
    );
    return '$_temp0 · dernière le $date';
  }

  @override
  String get progressReadErrorTitle => 'Lecture impossible';

  @override
  String get progressReadErrorBody =>
      'Tes données sur ce téléphone n\'ont pas pu être lues pour l\'instant. Rien n\'a été modifié; réessaie.';

  @override
  String get progressNoRecordedSetsTitle => 'Aucune série enregistrée';

  @override
  String get progressNoRecordedSetsBody =>
      'Cet exercice n\'a plus de séries enregistrées dans une séance terminée.';

  @override
  String get progressNoRecordedSetsAnyMore =>
      'Cet exercice n\'a plus de séries enregistrées.';

  @override
  String get progressCompareSetsOf => 'Comparer les séries de';

  @override
  String get progressNothingComparable =>
      'Ces séries n\'ont ni répétitions avec charge, ni répétitions seules, ni temps enregistré, donc rien de comparable à afficher. Chaque séance enregistrée est listée plus bas.';

  @override
  String get progressRecordedOnly => 'Séances enregistrées seulement';

  @override
  String get progressFirstToLatest =>
      'de la première à la dernière, sur cette période';

  @override
  String progressEmptyRangeLoad(int reps, String rangeWords) {
    return 'Aucune séance avec une série de $reps répétitions $rangeWords. Choisis une période plus longue ou un autre nombre de répétitions.';
  }

  @override
  String progressEmptyRange(String rangeWords) {
    return 'Aucune séance $rangeWords. Choisis une période plus longue.';
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
      other: '$count séances',
      one: '$count séance',
    );
    return '$metric, $rangeWords : $_temp0. $points.';
  }

  @override
  String get progressOnePoint =>
      'Une seule séance comparable pour l\'instant. Un changement en demande au moins deux.';

  @override
  String get progressSessionsInRange => 'Séances de cette période';

  @override
  String progressRowsExplainLoad(int reps) {
    return 'Chaque ligne est la série la plus lourde de $reps répétitions de cette séance. Affichée au même nombre de répétitions.';
  }

  @override
  String get progressRowsExplain =>
      'Chaque ligne est la meilleure série de cette séance selon cette mesure.';

  @override
  String progressExcludedLoad(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count séries enregistrées sans répétitions et charge ne sont pas dans ce graphique.',
      one:
          '$count série enregistrée sans répétitions et charge n\'est pas dans ce graphique.',
    );
    return '$_temp0';
  }

  @override
  String progressExcludedReps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count séries enregistrées avec charge ou sans répétitions ne sont pas dans ce graphique.',
      one:
          '$count série enregistrée avec charge ou sans répétitions n\'est pas dans ce graphique.',
    );
    return '$_temp0';
  }

  @override
  String progressExcludedDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count séries enregistrées sans temps enregistré ne sont pas dans ce graphique.',
      one:
          '$count série enregistrée sans temps enregistré n\'est pas dans ce graphique.',
    );
    return '$_temp0';
  }

  @override
  String progressAllSessionsLink(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les $count séances et leurs séries',
      one: 'La séance et ses séries',
    );
    return '$_temp0';
  }

  @override
  String get progressSessionsTitle => 'Séances';

  @override
  String get progressAllSessionsSubtitle =>
      'Chaque séance enregistrée, la plus récente en premier';

  @override
  String get progressRecapTitle => 'Bilan de la semaine';

  @override
  String get progressPreviousWeek => 'Semaine précédente';

  @override
  String get progressNextWeek => 'Semaine suivante';

  @override
  String progressRecapLastWeek(String range) {
    return 'Semaine dernière · $range';
  }

  @override
  String progressRecapWeekOf(String range) {
    return 'Semaine du $range';
  }

  @override
  String progressRecapSemLastWeek(String range) {
    return 'Semaine dernière, $range.';
  }

  @override
  String progressRecapSemWeekOf(String range) {
    return 'Semaine du $range.';
  }

  @override
  String get progressRecapSemNoActivity =>
      'Aucune activité n\'a été enregistrée.';

  @override
  String progressRecapSemRecorded(String list) {
    return 'Enregistré : $list.';
  }

  @override
  String progressRecapSemDistance(String kind, String distance) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'Distance de marche',
      'running': 'Distance de course',
      'other': 'Distance course / marche',
    });
    return '$_temp0 : $distance.';
  }

  @override
  String progressRecapSemDistanceIncomplete(String kind, String distance) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'Distance de marche',
      'running': 'Distance de course',
      'other': 'Distance course / marche',
    });
    return '$_temp0 : $distance, certaines distances non enregistrées.';
  }

  @override
  String progressRecapSemActive(String duration) {
    return 'Temps actif : $duration.';
  }

  @override
  String get progressNotRecorded => 'non enregistré';

  @override
  String get progressRecapHeading => 'Ta semaine, enregistrée';

  @override
  String get progressRecapEmpty =>
      'Aucune activité n\'a été enregistrée cette semaine.';

  @override
  String progressRecapWorkoutsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Séances',
      one: 'Séance',
    );
    return '$_temp0';
  }

  @override
  String progressRecapWalks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Marches',
      one: 'Marche',
    );
    return '$_temp0';
  }

  @override
  String progressRecapRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Courses',
      one: 'Course',
    );
    return '$_temp0';
  }

  @override
  String get progressRecapRunsAndWalks => 'Courses et marches';

  @override
  String progressRecapDistanceLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'Distance de marche',
      'running': 'Distance de course',
      'other': 'Distance course / marche',
    });
    return '$_temp0';
  }

  @override
  String progressRecapTimeLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'Temps de marche',
      'running': 'Temps de course',
      'other': 'Temps course / marche',
    });
    return '$_temp0';
  }

  @override
  String progressRecapIncomplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count activités n\'avaient pas de distance enregistrée et ne sont pas dans le total.',
      one:
          '$count activité n\'avait pas de distance enregistrée et n\'est pas dans le total.',
    );
    return '$_temp0';
  }

  @override
  String get progressRecapTargets => 'Tes cibles de la semaine';

  @override
  String get progressRecapNoGoals =>
      'Aucun objectif n\'avait été fixé pour cette semaine.';

  @override
  String get progressRecapHighlight => 'Fait marquant en force';

  @override
  String progressRecapHighlightSubtitle(String dates, int reps) {
    return '$dates · enregistré à $reps répétitions';
  }

  @override
  String progressListJoin(String head, String last) {
    return '$head et $last';
  }

  @override
  String progressRecapCoachEmpty(String range) {
    return 'Aucune activité n\'a été enregistrée pendant la semaine du $range.';
  }

  @override
  String progressRecapCoach(String list, String range) {
    return 'Tu as enregistré $list pendant la semaine du $range.';
  }

  @override
  String get progressRecapSessions => 'Séances de cette semaine';

  @override
  String progressRecapNothingBetween(String start, String end) {
    return 'Rien n\'a été enregistré entre le $start et le $end.';
  }

  @override
  String progressTargetRowSemantic(String label, int count, int target) {
    return '$label : $count sur $target.';
  }

  @override
  String progressTargetRowSemanticReached(String label, int count, int target) {
    return '$label : $count sur $target, atteint.';
  }

  @override
  String get accountErrorPasswordTooLong =>
      'Ce mot de passe dépasse 256 caractères. Utilise-en un plus court.';

  @override
  String get accountErrorPasswordMismatch =>
      'Les deux nouveaux mots de passe ne sont pas identiques.';

  @override
  String get accountErrorCodeIncomplete => 'Entre les 8 chiffres du code.';

  @override
  String get accountErrorCodeInvalid =>
      'Ce code n\'est pas le bon. Vérifie le dernier courriel de GoHard ou demande un nouveau code.';

  @override
  String get accountErrorCodeExpired =>
      'Ce code a expiré. Demandes-en un nouveau.';

  @override
  String get accountErrorCodeAttempts =>
      'Trop d\'essais pour ce code. Demande un nouveau code.';

  @override
  String accountErrorCooldown(int seconds) {
    return 'Attends $seconds s avant de demander un autre code.';
  }

  @override
  String get accountEmailUnavailable =>
      'La récupération par courriel n\'est pas encore offerte. Ton compte et tes données sont en sécurité; réessaie plus tard.';

  @override
  String get accountErrorEmailBusy =>
      'GoHard envoie trop de courriels en ce moment. Réessaie dans quelques minutes.';

  @override
  String get accountErrorResetExpired =>
      'Cette réinitialisation a expiré ou a déjà servi. Demande un nouveau code pour recommencer.';

  @override
  String get accountErrorNotSupported =>
      'Le serveur de ton compte n\'offre pas encore cette fonction. Rien n\'a été modifié.';

  @override
  String get accountErrorUncertainReset =>
      'Impossible de confirmer le changement. Essaie de te connecter avec ton nouveau mot de passe; si ça ne fonctionne pas, demande un nouveau code.';

  @override
  String get accountErrorUncertainChange =>
      'Impossible de confirmer si ton mot de passe a changé. Rien n\'a été perdu sur ce téléphone. S\'il faut te reconnecter, essaie d\'abord le nouveau mot de passe.';

  @override
  String get codeFieldLabel => 'Code à 8 chiffres';

  @override
  String get codeFieldHelper =>
      'Dans le courriel que GoHard t\'a envoyé. Tu peux le coller.';

  @override
  String get codeResend => 'Renvoyer le code';

  @override
  String codeResendIn(int seconds) {
    return 'Renvoyer dans $seconds s';
  }

  @override
  String get codeDeliveryNote =>
      'Il peut prendre une minute à arriver. Vérifie aussi les indésirables.';

  @override
  String get newPasswordLabel => 'Nouveau mot de passe';

  @override
  String get newPasswordConfirmLabel => 'Confirme le nouveau mot de passe';

  @override
  String get currentPasswordLabel => 'Mot de passe actuel';

  @override
  String get passwordRule =>
      'Au moins 15 caractères. Quelques mots sans lien entre eux font très bien l\'affaire; tous les caractères sont permis.';

  @override
  String get authForgotPassword => 'Mot de passe oublié?';

  @override
  String get authNoticePasswordChanged =>
      'Ton mot de passe a été changé. Connecte-toi avec le nouveau; tout ce qui est sur ce téléphone est toujours là.';

  @override
  String get resetTitle => 'Réinitialiser le mot de passe';

  @override
  String get resetEmailLead =>
      'Entre l\'adresse courriel de ton compte. Si un compte l\'utilise, nous y enverrons un code de réinitialisation.';

  @override
  String get resetSendCode => 'Envoyer le code';

  @override
  String get resetCodeTitle => 'Entre le code';

  @override
  String resetCodeLead(String email) {
    return 'Si un compte utilise $email, nous y avons envoyé un code à 8 chiffres. Il est valide 10 minutes.';
  }

  @override
  String get resetUseAnotherEmail => 'Utiliser une autre adresse';

  @override
  String get resetPasswordTitle => 'Nouveau mot de passe';

  @override
  String get resetPasswordLead =>
      'Choisis ton nouveau mot de passe. Tous les appareils seront déconnectés.';

  @override
  String get resetSetPassword => 'Enregistrer le mot de passe';

  @override
  String get resetGoToSignIn => 'Aller à la connexion';

  @override
  String get changePasswordTitle => 'Changer le mot de passe';

  @override
  String get changePasswordLead =>
      'GoHard vérifie ton mot de passe actuel avant de changer quoi que ce soit.';

  @override
  String get changePasswordSignsOut =>
      'Le changer te déconnecte sur tous les appareils, celui-ci compris. Tes données restent sur ce téléphone et se synchronisent de nouveau à la connexion.';

  @override
  String get changePasswordButton => 'Changer le mot de passe';

  @override
  String get changePasswordConfirmTitle => 'Te déconnecter partout?';

  @override
  String get changePasswordConfirmBody =>
      'Après le changement, tu te reconnecteras avec le nouveau mot de passe, sur ce téléphone et tous les autres appareils.';

  @override
  String get changePasswordOffline =>
      'Changer ton mot de passe demande une connexion. Rien n\'est gardé pour plus tard.';

  @override
  String get verifyTitle => 'Confirmer le courriel';

  @override
  String verifyLead(String email) {
    return 'Nous enverrons un code à 8 chiffres à $email pour confirmer que c\'est bien ton adresse.';
  }

  @override
  String get verifySend => 'Envoyer le code';

  @override
  String get verifyConfirm => 'Confirmer';

  @override
  String get verifyLater => 'Plus tard';

  @override
  String get verifyVerified => 'Ton courriel est confirmé.';

  @override
  String get verifyDone => 'Courriel confirmé';

  @override
  String get meEmail => 'Courriel';

  @override
  String get meEmailVerified => 'Confirmé';

  @override
  String get meEmailNotVerified => 'Non confirmé';

  @override
  String get mePassword => 'Mot de passe';

  @override
  String get mePasswordSubtitle => 'Changer le mot de passe';

  @override
  String get accountErrorRegistrationUnavailable =>
      'Impossible de créer un compte pour le moment, car la confirmation par courriel n\'est pas offerte. Rien n\'a été créé; réessaie plus tard.';

  @override
  String get verifyGateTitle => 'Confirme ton courriel';

  @override
  String verifyGateLead(String email) {
    return 'Entre le code à 8 chiffres envoyé à $email.';
  }

  @override
  String get verifyGateWhy =>
      'La confirmation de ton courriel est nécessaire pour terminer la création de ton compte. Elle confirme que cette adresse est bien la tienne et ne change rien d\'autre.';

  @override
  String get verifyCheckAgain => 'Vérifier de nouveau';

  @override
  String get verifyGateSignOut => 'Me déconnecter ou utiliser un autre compte';

  @override
  String get verifyGateSignOutTitle => 'Te déconnecter?';

  @override
  String get verifyGateSignOutBody =>
      'Ce compte reste tel quel, en attente de confirmation. Reconnecte-toi quand tu veux pour le confirmer.';

  @override
  String get verifyScope =>
      'La confirmation prouve que cette adresse est la tienne. Elle ne change rien d\'autre.';

  @override
  String verifyGraceWhy(String date) {
    return 'Confirme-le d\'ici le $date pour continuer la synchronisation. Cela confirme que cette adresse est la tienne et ne change rien d\'autre.';
  }

  @override
  String get verifyPausedWhy =>
      'La synchronisation est en pause jusqu\'à la confirmation. Tout ce que tu enregistres reste sur ce téléphone et sera envoyé une fois confirmé.';

  @override
  String todayVerifyBy(String date) {
    return 'Confirme ton courriel d\'ici le $date pour continuer la synchronisation.';
  }

  @override
  String get todayVerifyPaused =>
      'Confirme ton courriel pour synchroniser de nouveau. Ce que tu enregistres reste sur ce téléphone.';

  @override
  String get todayVerifyAction => 'Confirmer';

  @override
  String meEmailVerifyBy(String date) {
    return 'À confirmer d\'ici le $date';
  }

  @override
  String get meEmailPaused =>
      'Synchronisation en pause jusqu\'à la confirmation';

  @override
  String get eatHistoryTrendsSubtitle =>
      'Revois tes apports par semaine ou par mois';

  @override
  String get eatHistoryTrendsSaid =>
      'Historique et tendances. Revois tes apports par semaine ou par mois';

  @override
  String get trainRecentWorkouts => 'Séances récentes';

  @override
  String get trainViewAllHistory => 'Voir tout l\'historique';

  @override
  String get trainViewAllHistorySaid => 'Voir tout l\'historique des séances';

  @override
  String get mealsLibraryTitle => 'Repas et recettes enregistrés';

  @override
  String get mealsFromAddFoodSubtitle =>
      'Plusieurs aliments d’un coup, quantités vérifiées d’abord';

  @override
  String mealsForContext(String meal, String date) {
    return 'Consigné dans : $meal · $date';
  }

  @override
  String get mealsTabMeals => 'Repas';

  @override
  String get mealsTabRecipes => 'Recettes';

  @override
  String get mealsNewMeal => 'Nouveau repas';

  @override
  String get mealsNewRecipe => 'Nouvelle recette';

  @override
  String get mealsEditMeal => 'Modifier le repas';

  @override
  String get mealsEditRecipe => 'Modifier la recette';

  @override
  String get mealsSearchHint => 'Chercher par nom';

  @override
  String mealsNoMatch(String query) {
    return 'Rien d’enregistré ne correspond à « $query ».';
  }

  @override
  String get mealsEmptyMealsTitle => 'Aucun repas enregistré';

  @override
  String get mealsEmptyMealsBody =>
      'Un repas enregistré garde plusieurs aliments avec leurs quantités habituelles, comme 2 œufs et 60 g d’avoine. Quand tu le consignes, tu peux d’abord changer les quantités.';

  @override
  String get mealsEmptyRecipesTitle => 'Aucune recette';

  @override
  String get mealsEmptyRecipesBody =>
      'Une recette est une fournée entière d’ingrédients et le nombre de portions qu’elle donne. Tu consignes la portion que tu as mangée.';

  @override
  String get mealsUntitled => 'Sans nom';

  @override
  String get mealsUnsavedDraft => 'Modifications non enregistrées';

  @override
  String mealsFoodsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aliments',
      one: '$count aliment',
    );
    return '$_temp0';
  }

  @override
  String mealsIngredientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ingrédients',
      one: '$count ingrédient',
    );
    return '$_temp0';
  }

  @override
  String mealsMakesServings(num count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'donne $value portions',
      one: 'donne $value portion',
    );
    return '$_temp0';
  }

  @override
  String mealsServingsAmount(num count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$value portions',
      one: '$value portion',
    );
    return '$_temp0';
  }

  @override
  String mealsPerServing(String value) {
    return '$value par portion';
  }

  @override
  String mealsMenuLabel(String name) {
    return 'Options pour $name';
  }

  @override
  String get mealsDuplicate => 'Dupliquer';

  @override
  String mealsCopyName(String name) {
    return '$name (copie)';
  }

  @override
  String mealsDeleteTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get mealsDeleteBody =>
      'Il est retiré des repas et recettes enregistrés. Ce que tu as déjà consigné reste exactement tel quel.';

  @override
  String get mealsDeleted => 'Supprimé. Ce que tu as consigné ne change pas.';

  @override
  String get mealsServerUnavailable =>
      'Le serveur de ton compte ne prend pas encore les repas et recettes enregistrés. Les brouillons restent sur ce téléphone; enregistrer et consigner attendent qu’il le fasse.';

  @override
  String get mealsHelpLabel => 'Aide sur les repas et recettes';

  @override
  String get mealsCoachLibrary =>
      'Un repas enregistré garde des aliments et leurs quantités habituelles. En le consignant, tu peux d’abord diviser, doubler ou changer chacune.';

  @override
  String get mealsCoachRecipe =>
      'Une recette divise une fournée entière en autant de portions que tu choisis.';

  @override
  String get eatHintMeals =>
      'Tu manges souvent ça? Enregistre le repas et ajuste les quantités la prochaine fois.';

  @override
  String get mealsSaved => 'Ton repas est dans Repas et recettes enregistrés.';

  @override
  String get mealsSavedRecipe =>
      'Ta recette est dans Repas et recettes enregistrés.';

  @override
  String get mealsSaveAsMeal => 'Enregistrer comme repas';

  @override
  String mealsSaveAsMealSaid(String meal) {
    return 'Enregistrer $meal comme repas';
  }

  @override
  String get mealsNameLabel => 'Nom';

  @override
  String get mealsFoodsHeading => 'Aliments';

  @override
  String get mealsIngredientsHeading => 'Ingrédients (fournée entière)';

  @override
  String get mealsAddFood => 'Ajouter un aliment';

  @override
  String get mealsAddIngredient => 'Ajouter un ingrédient';

  @override
  String mealsRemoveFood(String name) {
    return 'Retirer $name';
  }

  @override
  String get mealsServingsLabel => 'Portions que donne la fournée';

  @override
  String get mealsServingsHelper =>
      'Autant que tu la partages. Rien n’est deviné.';

  @override
  String get mealsWeightLabel => 'Poids de la fournée cuite (facultatif)';

  @override
  String get mealsWeightHelper =>
      'Pèse-la une fois prête pour consigner des portions en grammes. Le poids des ingrédients crus n’est jamais utilisé pour ça.';

  @override
  String get mealsTotalHeading => 'Repas entier';

  @override
  String get mealsBatchHeading => 'Fournée entière';

  @override
  String get mealsPerServingHeading => 'Une portion';

  @override
  String get mealsSomeMissing =>
      'Certains aliments n’ont pas de valeur pour un nutriment : les chiffres marqués « connu » sont des sommes de ce qui est connu, pas des totaux complets.';

  @override
  String get mealsSaveAsNew => 'Enregistrer comme nouveau';

  @override
  String get mealsDiscard => 'Abandonner les modifications';

  @override
  String get mealsDiscardTitle => 'Abandonner tes modifications?';

  @override
  String get mealsDiscardBody => 'La version enregistrée reste telle quelle.';

  @override
  String get mealsDiscardBodyNew =>
      'Ce repas non enregistré est retiré de ce téléphone.';

  @override
  String get mealsResumed =>
      'Tes modifications non enregistrées sont de retour.';

  @override
  String get mealsChangedElsewhereTitle => 'Modifié sur un autre appareil';

  @override
  String get mealsChangedElsewhereBody =>
      'Ceci a été modifié sur un autre appareil depuis que tu as commencé. Enregistrer ta version par-dessus?';

  @override
  String get mealsSaveMine => 'Garder la mienne';

  @override
  String get mealsDeletedElsewhere =>
      'Ceci a été supprimé sur un autre appareil. Utilise Enregistrer comme nouveau pour le garder.';

  @override
  String get mealsProblemNoName => 'Donne-lui un nom.';

  @override
  String get mealsProblemNameTooLong =>
      'Le nom est trop long (120 caractères au plus).';

  @override
  String get mealsProblemNoFoods => 'Ajoute au moins un aliment.';

  @override
  String get mealsProblemTooMany => '30 aliments au plus.';

  @override
  String get mealsProblemBadQuantity =>
      'Chaque quantité doit être supérieure à 0.';

  @override
  String get mealsProblemBadServings =>
      'Indique combien de portions donne la fournée (plus de 0, au plus 1 000).';

  @override
  String get mealsProblemBadWeight =>
      'Indique le poids final en grammes (plus de 0), ou laisse vide.';

  @override
  String get mealsProblemTooLarge =>
      'C’est trop gros pour être enregistré. Retire quelques aliments.';

  @override
  String get mealsProblemBadMultiplier =>
      'Indique un multiplicateur supérieur à 0, au plus 20.';

  @override
  String get mealsProblemBadPortion =>
      'Indique combien tu en as pris (plus de 0).';

  @override
  String get foodProblemTooLarge =>
      'Les détails de cet aliment sont trop gros pour être enregistrés.';

  @override
  String get mealsUseAmount => 'Utiliser cette quantité';

  @override
  String get mealsReviewNote =>
      'Vérifie les quantités. Rien n’est consigné avant que tu confirmes.';

  @override
  String get mealsAmountsHeading => 'Quantités cette fois';

  @override
  String get mealsMultiplierCustom => 'Autre…';

  @override
  String get mealsMultiplierTitle => 'Multiplier chaque quantité';

  @override
  String get mealsMultiplierLabel => 'Multiplicateur';

  @override
  String mealsMultiplierSaid(String value) {
    return '$value fois chaque quantité';
  }

  @override
  String get mealsLogMeal => 'Consigner le repas';

  @override
  String get mealsLogPortion => 'Consigner la portion';

  @override
  String mealsLogged(String meal) {
    return 'Consigné dans : $meal.';
  }

  @override
  String get mealsPortionChanged => 'Portion mise à jour.';

  @override
  String get mealsUpdateSaved => 'Mettre à jour le repas';

  @override
  String get mealsUpdateTitle => 'Mettre à jour le repas enregistré?';

  @override
  String mealsUpdateBody(String name) {
    return 'Les quantités affichées deviennent celles de $name, pour un repas. Rien n’est consigné, et ce que tu as consigné avant ne change pas.';
  }

  @override
  String get mealsUpdated => 'Repas mis à jour. Rien n’a été consigné.';

  @override
  String get mealsSaveAsNewTitle => 'Enregistrer comme nouveau repas';

  @override
  String mealsSaveAsNewBody(String name) {
    return 'Les quantités affichées sont enregistrées comme un nouveau repas. $name reste tel quel, et rien n’est consigné.';
  }

  @override
  String get mealsSavedNew =>
      'Enregistré comme nouveau repas. Rien n’a été consigné.';

  @override
  String get mealsPortionHeading => 'Combien tu en as pris';

  @override
  String get mealsPortionAmount => 'Quantité';

  @override
  String get mealsMeasureServings => 'Portions';

  @override
  String get mealsMeasureGrams => 'Grammes';

  @override
  String get mealsNoWeight =>
      'Pour consigner des grammes, ajoute le poids de la fournée cuite à la recette.';

  @override
  String mealsThisPortion(String amount) {
    return 'Cette portion : $amount';
  }

  @override
  String get mealsThisTimeIngredients =>
      'Ingrédients cette fois (fournée entière)';

  @override
  String get mealsThisTimeNote =>
      'Ce que tu changes ici vaut pour cette portion seulement. La recette enregistrée reste telle quelle.';

  @override
  String get mealsThisTimeChanged =>
      'Changé pour cette portion seulement. Pour changer la recette elle-même, utilise Modifier la recette.';

  @override
  String get mealsThisTimeTotal => 'Cette fois';

  @override
  String get eatOutTitle => 'Au restaurant';

  @override
  String get eatOutEntrySubtitle =>
      'Menus canadiens vérifiés : choisir ou améliorer une commande';

  @override
  String get eatOutPanelBody =>
      'Trouve une commande au restaurant qui respecte tes objectifs.';

  @override
  String get eatOutPanelAction => 'Choisir un restaurant';

  @override
  String get eatHintEatingOut =>
      'Tu manges au restaurant aujourd\'hui? Je peux t\'aider à choisir une commande ou à améliorer celle que tu veux.';

  @override
  String get eatHintEatingOutAction => 'Trouver une commande';

  @override
  String eatOutForContext(String meal, String date) {
    return 'Pour $meal · $date';
  }

  @override
  String eatOutChainContext(String chain, String meal, String date) {
    return '$chain · Canada · $meal · $date';
  }

  @override
  String get eatOutChooseChain => 'Choisis un restaurant';

  @override
  String eatOutChainCanada(String chain) {
    return '$chain · Canada';
  }

  @override
  String eatOutChainOptions(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options vérifiées',
      one: '1 option vérifiée',
    );
    return '$_temp0 · vérifié le $date';
  }

  @override
  String get eatOutChainUnavailable =>
      'Menu pas encore ajouté : aucune donnée vérifiée';

  @override
  String eatOutChainNotYet(String chain) {
    return 'Pas encore de menu $chain vérifié';
  }

  @override
  String get eatOutChainBlocked =>
      'GoHard propose seulement des articles dont les valeurs viennent des renseignements canadiens publiés par la chaîne. Les données officielles de cette chaîne n\'ont pas encore pu être lues : rien n\'est proposé plutôt qu\'une estimation. Tu peux quand même entrer ton propre aliment dans Ajouter un aliment.';

  @override
  String get eatOutChangeChain => 'Changer de restaurant';

  @override
  String get eatOutCoverageNote =>
      'Une sélection d\'articles standards, pas le menu complet. Les articles ne sont pas offerts partout. Les prix, la commande et la livraison ne font pas partie de GoHard.';

  @override
  String eatOutAskLabel(String guide) {
    return 'Demander à $guide pour le restaurant';
  }

  @override
  String get eatOutAskHint =>
      'Dis-moi ce que tu veux, p. ex. garder les rondelles, plus de protéines';

  @override
  String get eatOutAskUnavailable =>
      'Les demandes en mots ne sont pas offertes sur ce serveur. Les cibles, le menu et les suggestions fonctionnent sans elles.';

  @override
  String get eatOutAskInvalid =>
      'Cette demande n\'a pas pu être envoyée. Raccourcis-la (600 caractères au plus) et renvoie-la.';

  @override
  String get eatOutProblemLimit =>
      'Tu as beaucoup demandé aujourd\'hui. Les demandes en mots reviendront plus tard; les cibles et le menu fonctionnent toujours.';

  @override
  String get eatOutProblemBusy =>
      'L\'assistant est occupé en ce moment. Ta demande est gardée; réessaie dans un instant.';

  @override
  String get eatOutProblemUnreached =>
      'Ta demande n\'a pas pu être envoyée : la connexion de ce téléphone ou le serveur peut en être la cause. Elle est gardée, et le menu fonctionne hors ligne.';

  @override
  String get eatOutProblemUnavailable =>
      'L\'assistant n\'est pas disponible en ce moment. Ta demande est gardée; les cibles et le menu fonctionnent toujours.';

  @override
  String get eatOutStale =>
      'Ta commande ou tes cibles ont changé pendant que je lisais. Rien n\'a été modifié : renvoie la demande pour utiliser ce que tu as maintenant.';

  @override
  String get eatOutMenuChanged =>
      'Le menu a été mis à jour sur le serveur. Mets-le à jour ici avant de redemander.';

  @override
  String get eatOutUpdateMenu => 'Mettre le menu à jour';

  @override
  String eatOutSwitchTo(String chain) {
    return 'Passer à $chain';
  }

  @override
  String get eatOutCoachIntro =>
      'Tu manges au restaurant? Dis-moi où tu vas et ce que tu veux garder.';

  @override
  String eatOutCoachChain(String chain) {
    return 'Fixe une limite de calories ou une cible de protéines, ou dis-moi ce que tu veux chez $chain. Je te montrerai des commandes qui conviennent.';
  }

  @override
  String get eatOutCoachImprove =>
      'Tu veux changer quelque chose à ta commande? Dis-moi quoi garder et ce qui compte le plus.';

  @override
  String get eatOutCoachReading => 'Je lis ta demande…';

  @override
  String get eatOutCoachUnderstood =>
      'Voici ce que j\'ai compris : vérifie tes cibles plus bas et corrige ce qui ne va pas. Chaque nombre vient du menu vérifié.';

  @override
  String eatOutCoachUnknown(String names) {
    return 'Je ne trouve pas $names dans ce menu.';
  }

  @override
  String get eatOutCoachUnsupported =>
      'J\'ai seulement des menus vérifiés pour les restaurants de cette liste : je ne peux pas t\'aider pour celui-là.';

  @override
  String get eatOutCoachContradiction =>
      'Ta demande contient deux choses qui s\'excluent. Laquelle dois-je garder?';

  @override
  String get eatOutCoachClarify =>
      'Peux-tu préciser? Par exemple une limite de calories, ou l\'article et le format voulus.';

  @override
  String eatOutCoachAsks(String question) {
    return '$question';
  }

  @override
  String get eatOutYourTargets => 'Tes cibles';

  @override
  String get eatOutNoTargetsYet =>
      'Aucune pour l\'instant. Rien n\'est choisi à ta place.';

  @override
  String eatOutChipMax(String kcal) {
    return 'Jusqu\'à $kcal kcal';
  }

  @override
  String eatOutChipMin(String kcal) {
    return 'Au moins $kcal kcal';
  }

  @override
  String eatOutChipProtein(String grams) {
    return 'Au moins $grams g de protéines';
  }

  @override
  String eatOutChipKeep(String name, int count) {
    return 'Garder $name × $count';
  }

  @override
  String eatOutChipExclude(String name) {
    return 'Sans $name';
  }

  @override
  String eatOutChipPrefer(String kind) {
    return 'Préférer : $kind';
  }

  @override
  String eatOutChipAvoid(String kind) {
    return 'Éviter : $kind';
  }

  @override
  String eatOutRemoveTarget(String target) {
    return 'Retirer $target';
  }

  @override
  String get eatOutHelpChoose => 'Aide-moi à choisir';

  @override
  String eatOutYourOrder(int count) {
    return 'Ta commande ($count)';
  }

  @override
  String get eatOutNoTargetsTitle =>
      'À quoi la commande doit-elle correspondre?';

  @override
  String get eatOutNoTargetsBody =>
      'Fixe une limite de calories ou une cible de protéines, ou demande-moi avec tes mots. Tu peux aussi bâtir une commande toi-même.';

  @override
  String get eatOutSetTargets => 'Fixer des cibles';

  @override
  String eatOutSortedBy(String priority) {
    return 'Triées par : $priority';
  }

  @override
  String get eatOutPriorityProtein => 'le plus de protéines';

  @override
  String get eatOutPriorityCalories => 'le moins de calories';

  @override
  String get eatOutPriorityClosest => 'le plus près de ta limite de calories';

  @override
  String get eatOutNoneFits =>
      'Rien ne correspond à toutes tes cibles. Voici les plus proches, avec ce qui manque à chacune. Les articles gardés ou exclus ne sont jamais changés.';

  @override
  String get eatOutNothingPossible =>
      'Aucune commande ne peut être bâtie avec ces choix. Retire un article ou un type exclu.';

  @override
  String get eatOutContradiction =>
      'Le minimum dépasse le maximum, ou un article est à la fois gardé et exclu. Change l\'un des deux.';

  @override
  String eatOutLine(int count, String name) {
    return '$count × $name';
  }

  @override
  String eatOutProteinValue(String grams) {
    return '$grams g de protéines';
  }

  @override
  String get eatOutFits => 'Correspond à tes cibles.';

  @override
  String eatOutKeeps(String names) {
    return 'Garde $names.';
  }

  @override
  String eatOutMisses(String misses) {
    return 'Manque : $misses';
  }

  @override
  String eatOutMissOver(String kcal) {
    return '$kcal kcal au-dessus de ta limite';
  }

  @override
  String eatOutMissUnder(String kcal) {
    return '$kcal kcal sous ton minimum';
  }

  @override
  String eatOutMissProtein(String grams) {
    return 'il manque $grams g de protéines';
  }

  @override
  String eatOutVersusOrder(String kcal, String protein) {
    return 'Par rapport à ta commande : $kcal kcal, $protein g de protéines';
  }

  @override
  String get eatOutUseOrder => 'Prendre cette commande';

  @override
  String get eatOutUseInstead => 'Remplacer ma commande';

  @override
  String get eatOutOrderEmptyTitle => 'Aucun article pour l\'instant';

  @override
  String get eatOutOrderEmptyBody =>
      'Ajoute des articles du menu ou choisis une suggestion. Rien n\'est consigné avant ta révision.';

  @override
  String get eatOutAddFromMenu => 'Ajouter du menu';

  @override
  String eatOutMenuTitle(String chain) {
    return 'Menu $chain · Canada';
  }

  @override
  String get eatOutMenuFilter => 'Filtrer le menu';

  @override
  String eatOutAddItem(String name) {
    return 'Ajouter $name';
  }

  @override
  String eatOutInOrder(int count) {
    return '$count dans la commande';
  }

  @override
  String eatOutEach(String kcal) {
    return '$kcal kcal chacun';
  }

  @override
  String eatOutLess(String name) {
    return 'Un de moins : $name';
  }

  @override
  String eatOutMore(String name) {
    return 'Un de plus : $name';
  }

  @override
  String eatOutCountSaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String eatOutNoLongerListed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles ne sont plus au menu.',
      one: '1 article n\'est plus au menu.',
    );
    return '$_temp0';
  }

  @override
  String get eatOutRemoveThem => 'Retirer';

  @override
  String get eatOutOrderTotal => 'Total de la commande';

  @override
  String eatOutSodium(String mg) {
    return 'Sodium $mg mg';
  }

  @override
  String get eatOutReview => 'Réviser et consigner';

  @override
  String eatOutOrderName(String chain) {
    return 'Commande $chain';
  }

  @override
  String eatOutSourceLine(String source, String published, String checked) {
    return 'Source : $source. Publication : $published. Vérifié le $checked.';
  }

  @override
  String get eatOutNotStated => 'non indiquée';

  @override
  String get eatOutCustomNote =>
      'Seuls les articles et formats listés sont calculés. Un changement comme sans sauce ou extra fromage n\'a pas de valeurs vérifiées : il ne peut pas être calculé de façon fiable.';

  @override
  String get eatOutOwnEstimate => 'Consigner plutôt ta propre estimation';

  @override
  String get eatOutTargetsTitle => 'Cibles pour cette commande';

  @override
  String get eatOutTargetsNote =>
      'Pour ce repas seulement, pas tes objectifs quotidiens. Laisse vide ce que tu veux.';

  @override
  String get eatOutTargetMax => 'Calories maximum';

  @override
  String get eatOutTargetMin => 'Calories minimum';

  @override
  String get eatOutTargetProtein => 'Protéines minimum';

  @override
  String get eatOutSortLabel =>
      'Quand plusieurs commandes conviennent, montrer d\'abord';

  @override
  String get eatOutSortAutomatic => 'Automatique (selon tes cibles)';

  @override
  String get eatOutApplyTargets => 'Utiliser ces cibles';

  @override
  String get eatOutTargetsInvalid =>
      'Utilise des nombres entiers : calories de 100 à 4 000 (minimum dès 0), protéines de 1 à 300 g.';

  @override
  String get eatOutKindSandwich => 'sandwich';

  @override
  String get eatOutKindWrap => 'wrap';

  @override
  String get eatOutKindSalad => 'salade';

  @override
  String get eatOutKindBowl => 'bol';

  @override
  String get eatOutKindBreakfast => 'déjeuner';

  @override
  String get eatOutKindPizza => 'pizza';

  @override
  String get eatOutKindChicken => 'poulet';

  @override
  String get eatOutKindSide => 'accompagnement';

  @override
  String get eatOutKindDessert => 'dessert';

  @override
  String get eatOutKindDrink => 'boisson';

  @override
  String eatOutChainOfficial(String chain) {
    return 'Renseignements nutritionnels publiés par $chain Canada';
  }

  @override
  String eatOutPublished(String date) {
    return 'publié $date';
  }

  @override
  String eatOutChecked(String date) {
    return 'vérifié $date';
  }

  @override
  String eatOutBuildNote(String note) {
    return 'Préparation standard : $note';
  }

  @override
  String get eatOutSodiumLabel => 'Sodium';

  @override
  String get eatOutFibreLabel => 'Fibres';

  @override
  String get eatOutSatFatLabel => 'Gras saturés';

  @override
  String get dcTitle => 'Aide pour aujourd\'hui';

  @override
  String dcAboutDay(String date) {
    return 'À propos du $date';
  }

  @override
  String get dcEarlierDay => 'C\'est un jour passé, pas aujourd\'hui.';

  @override
  String get dcPrivacy =>
      'Quand tu écris une demande, tes mots et les noms de tes repas, recettes et aliments enregistrés sont envoyés pour la lire. Ton journal, tes objectifs et tes chiffres ne sont pas envoyés : chaque chiffre est calculé sur ce téléphone.';

  @override
  String get dcIntro =>
      'Je peux résumer ta journée, montrer ce qu\'il y a dans ton journal et te suggérer des portions parmi tes repas, recettes et aliments enregistrés. Chaque chiffre vient de tes propres données, et rien n\'est consigné avant que tu choisisses Consigner.';

  @override
  String get dcInputHint =>
      'Pose une question sur ta journée ou l\'alimentation';

  @override
  String get dcNoAi =>
      'Les demandes écrites ne sont pas offertes sur ce serveur. Les demandes suggérées ci-dessus fonctionnent toujours.';

  @override
  String get dcWaiting => 'Je lis ta demande…';

  @override
  String get dcStillWorks =>
      'Ton journal, tes repas enregistrés et les demandes suggérées fonctionnent toujours.';

  @override
  String get dcAiRead =>
      'Demande lue par l\'IA · chiffres tirés de tes données';

  @override
  String get dcBuiltIn => 'Intégré · à partir de tes données';

  @override
  String dcBasisToday(String date) {
    return 'Aujourd\'hui, $date : ton plan et ton journal sur ce téléphone';
  }

  @override
  String dcBasisDay(String date) {
    return '$date : ton journal sur ce téléphone';
  }

  @override
  String dcSwitchedToToday(String date) {
    return 'Je passe à aujourd\'hui, $date.';
  }

  @override
  String get dcStale => 'Tes données ont changé depuis cette réponse.';

  @override
  String get dcRecalculate => 'Recalculer';

  @override
  String get dcStaleReview =>
      'Ceci a changé depuis la suggestion. Recalcule-la d\'abord.';

  @override
  String get dcTrainingLoading =>
      'L\'entraînement d\'aujourd\'hui est encore en chargement.';

  @override
  String get dcTrainingNoPlan => 'Aucun plan d\'entraînement n\'est actif.';

  @override
  String get dcTrainingNothingDefinite =>
      'Rien de précis n\'est prévu pour l\'entraînement aujourd\'hui.';

  @override
  String dcWorkoutsRecorded(String count) {
    return 'Entraînements terminés aujourd\'hui : $count.';
  }

  @override
  String get dcNoWorkoutRecorded =>
      'Aucun entraînement n\'est enregistré aujourd\'hui.';

  @override
  String get dcRunOpen => 'Une course ou une marche est en cours.';

  @override
  String get dcJournalLoading =>
      'Le journal de ce jour est encore en chargement.';

  @override
  String get dcJournalEmpty =>
      'Rien n\'est encore inscrit au journal pour ce jour. Cela veut seulement dire que rien n\'a été consigné.';

  @override
  String dcJournalLine(String count, String kcal, String protein) {
    return 'Aliments au journal : $count · $kcal · $protein';
  }

  @override
  String get dcLoggedOnly =>
      'C\'est ce qui a été consigné, ce qui n\'est peut-être pas tout ce qui a été mangé.';

  @override
  String get dcTodayChoice => 'Que veux-tu regarder?';

  @override
  String get dcPending =>
      'Certains changements sur ce téléphone n\'ont pas encore atteint ton compte. J\'utilise ce qui est sur ce téléphone; un élément enregistré seulement ici ne peut pas être trouvé par son nom avant la synchronisation.';

  @override
  String dcProteinKnown(String value) {
    return '$value g de protéines connus';
  }

  @override
  String get dcProteinUnknown => 'Protéines inconnues';

  @override
  String dcTimesSaved(String value) {
    return '$value× les quantités enregistrées';
  }

  @override
  String get dcGoalProteinNotSet =>
      'Tu n\'as pas fixé d\'objectif quotidien de protéines. Tu peux en fixer un dans Manger, ou me dire ce que tu veux pour ce repas.';

  @override
  String get dcGoalCaloriesNotSet =>
      'Tu n\'as pas fixé d\'objectif quotidien de calories. Tu peux en fixer un dans Manger, ou me dire ce que tu veux pour ce repas.';

  @override
  String dcGoalProteinNone(String goal) {
    return 'Aucune protéine n\'est encore consignée aujourd\'hui. Ton objectif est de $goal g.';
  }

  @override
  String dcGoalProteinPartial(String known, String goal) {
    return 'Au moins $known g de protéines sont connus jusqu\'ici pour ton objectif de $goal g. Certains aliments n\'ont pas de valeur de protéines, alors l\'écart exact n\'est pas connu.';
  }

  @override
  String dcGoalProteinReached(String logged, String goal) {
    return '$logged g de protéines sont consignés; ton objectif est de $goal g.';
  }

  @override
  String dcGoalProteinLeft(String logged, String goal, String left) {
    return '$logged g de ton objectif de $goal g de protéines sont consignés : il reste $left g.';
  }

  @override
  String dcGoalKcalNone(String goal) {
    return 'Aucune calorie n\'est encore consignée aujourd\'hui. Ton objectif est de $goal kcal.';
  }

  @override
  String dcGoalKcalPartial(String known, String goal) {
    return 'Au moins $known kcal sont connues jusqu\'ici pour ton objectif de $goal kcal. Certains aliments n\'ont pas de valeur de calories, alors l\'écart exact n\'est pas connu.';
  }

  @override
  String dcGoalKcalReached(String logged, String goal) {
    return '$logged kcal sont consignées; ton objectif est de $goal kcal.';
  }

  @override
  String dcGoalKcalLeft(String logged, String goal, String left) {
    return '$logged de ton objectif de $goal kcal sont consignées : il reste $left kcal.';
  }

  @override
  String get dcGoalNotMealSize =>
      'Un objectif quotidien n\'est pas la taille d\'un repas : choisis ce qui convient à ce repas.';

  @override
  String get dcFromSaved =>
      'Parmi tes repas, recettes et aliments enregistrés :';

  @override
  String get dcNoItems =>
      'Tu n\'as encore aucun repas, recette ou aliment favori enregistré, alors je n\'ai rien de toi à suggérer. Trouve un aliment dans Ajouter un aliment, ou essaie Manger au restaurant.';

  @override
  String get dcNoProteinKnown =>
      'Aucun de tes éléments enregistrés n\'a de valeur connue pour cela.';

  @override
  String dcUnderKcal(String kcal) {
    return 'au plus $kcal kcal';
  }

  @override
  String dcAtLeastProtein(String g) {
    return 'au moins $g g de protéines';
  }

  @override
  String get dcAnd => ' et ';

  @override
  String dcFitsHeading(String targets) {
    return 'Ceux-ci respectent $targets :';
  }

  @override
  String dcNothingFits(String targets) {
    return 'Rien de ce qui est enregistré ne respecte $targets. Les plus proches, avec ce qui manque à chacun :';
  }

  @override
  String dcNothingKnownFits(String targets) {
    return 'Je ne peux pas vérifier $targets : tes éléments enregistrés n\'ont pas ces valeurs connues.';
  }

  @override
  String get dcUnknownLeftOut =>
      'Les éléments dont une valeur est inconnue pour ces cibles ont été écartés.';

  @override
  String get dcChangeWhich => 'Quelle cible veux-tu changer?';

  @override
  String dcMisses(String misses) {
    return 'Manque : $misses';
  }

  @override
  String dcMissOverKcal(String kcal) {
    return '$kcal kcal de trop';
  }

  @override
  String dcMissUnderProtein(String g) {
    return '$g g de protéines en moins';
  }

  @override
  String dcAddsProtein(String adds, String total, String goal) {
    return 'Ajoute $adds g de protéines : $total g sur $goal g consignés ensuite.';
  }

  @override
  String dcAddsKcal(String adds, String total, String goal) {
    return 'Ajoute $adds kcal : $total sur $goal kcal consignées ensuite.';
  }

  @override
  String get dcChoose => 'J\'en ai trouvé plus d\'un. Lequel veux-tu dire?';

  @override
  String get dcThatItem => 'cet élément';

  @override
  String dcNotFound(String names) {
    return 'Je n\'ai pas trouvé $names dans tes repas, recettes ou aliments enregistrés. Trouve-le dans Ajouter un aliment, ou enregistre-le comme repas.';
  }

  @override
  String get dcNeedItem =>
      'De quel repas, recette ou aliment enregistré parles-tu?';

  @override
  String get dcSmallest =>
      'C\'est la plus petite portion pratique que je peux suggérer pour ceci.';

  @override
  String get dcLargest =>
      'C\'est la plus grande portion pratique que je peux suggérer pour ceci.';

  @override
  String get dcCantGrams =>
      'Ceci ne peut pas se mesurer en grammes : son poids une fois prêt n\'est pas connu. Utilise des portions, ou pèse la recette entière.';

  @override
  String get dcCantMeasure =>
      'Cette quantité ne correspond pas à la façon dont ceci se mesure. Essaie des portions ou un multiplicateur.';

  @override
  String dcMoreProtein(String more, String diff, String less) {
    return '$more a $diff g de protéines de plus que $less.';
  }

  @override
  String dcMoreKcal(String more, String diff, String less) {
    return '$more a $diff kcal de plus que $less.';
  }

  @override
  String get dcSameProtein => 'Ils ont la même quantité de protéines.';

  @override
  String get dcSameKcal => 'Ils ont les mêmes calories.';

  @override
  String get dcCompareUnknown =>
      'Certaines valeurs sont inconnues pour l\'un d\'eux, alors je ne peux pas les comparer.';

  @override
  String get dcTraining =>
      'Les questions sur tes entraînements et ton plan vont à Demande à GoHard, l\'assistant d\'entraînement.';

  @override
  String get dcRestaurant =>
      'Les commandes au restaurant sont dans Manger au restaurant, avec des menus vérifiés.';

  @override
  String get dcClarify =>
      'Peux-tu préciser un peu? Par exemple quel repas enregistré, ou une limite de calories pour ce repas.';

  @override
  String get dcUnsupported =>
      'Je peux t\'aider avec le plan et les données d\'aujourd\'hui, et avec l\'alimentation à partir de tes repas, recettes et aliments enregistrés. Je ne peux pas aider avec des questions médicales ou de santé.';

  @override
  String get dcActionReview => 'Vérifier la portion';

  @override
  String get dcActionWorkout => 'Voir l\'entraînement';

  @override
  String get dcActionJournal => 'Ouvrir le journal';

  @override
  String get dcActionGoals => 'Modifier les objectifs';

  @override
  String get dcActionAddFood => 'Trouver un aliment';

  @override
  String get dcActionTraining => 'Poser une question sur l\'entraînement';

  @override
  String get dcActionChooseMeal => 'Choisir un repas';

  @override
  String get dcChipToday => 'Aide-moi pour aujourd\'hui';

  @override
  String get dcChipRecorded => 'Qu\'est-ce que j\'ai consigné aujourd\'hui?';

  @override
  String get dcChipProtein => 'Aide-moi à atteindre mon objectif de protéines';

  @override
  String get dcChipSaved =>
      'Que pourrais-je prendre parmi mes repas enregistrés?';

  @override
  String get dcChipSmaller => 'Une portion plus petite';

  @override
  String dcOpenWith(String guide) {
    return 'Aide pour aujourd\'hui : ouvrir la conversation avec $guide';
  }

  @override
  String get dcProblemLimit =>
      'Tu as posé beaucoup de questions aujourd\'hui. Les demandes écrites fonctionneront de nouveau plus tard; les demandes suggérées fonctionnent toujours.';

  @override
  String get dcProblemBusy =>
      'La lecture des demandes est occupée en ce moment. Réessaie dans un instant.';

  @override
  String get dcProblemUnreached =>
      'Ta demande n\'a pas pu être envoyée. Cela peut venir de la connexion de ce téléphone ou du serveur.';

  @override
  String get dcProblemInterrupted =>
      'Cette demande n\'a pas eu de réponse avant la fermeture de l\'application. Réessaie pour la poser de nouveau.';

  @override
  String get dcProblemUnavailable =>
      'La lecture des demandes écrites n\'est pas offerte en ce moment. Ta demande est conservée.';

  @override
  String habitUsualName(String meal) {
    return '$meal (habituel)';
  }

  @override
  String habitSay(String meal) {
    return 'Ton « $meal » habituel? Révise-le ou choisis autre chose.';
  }

  @override
  String habitSaySaved(String meal, String name) {
    return 'Ton « $meal » habituel : $name? Révise-le ou choisis autre chose.';
  }

  @override
  String habitWhy(String meal, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Consigné dans « $meal » $count jours récemment.',
      one: 'Consigné dans « $meal » $count jour récemment.',
    );
    return '$_temp0';
  }

  @override
  String get habitReview => 'Réviser le repas habituel';

  @override
  String get habitOther => 'Choisir autre chose';

  @override
  String get habitNotToday => 'Pas aujourd’hui';

  @override
  String get habitSettingTitle => 'Suggestions de repas';

  @override
  String get habitSettingBody =>
      'GoHard peut remarquer les repas que tu consignes souvent et te les proposer dans Manger : « Ton déjeuner habituel? » C’est toujours toi qui choisis : rien n’est consigné, modifié ni planifié à ta place. Le calcul se fait sur ce téléphone, à partir de ton propre journal, et rien n’est envoyé.';

  @override
  String habitSettingRules(int minDays, int windowDays) {
    return 'Une suggestion demande les mêmes aliments, consignés au même repas, au moins $minDays jours différents dans les $windowDays derniers jours. Les aliments tapés à la main ne comptent pas, et une vieille habitude cesse d’être suggérée d’elle-même.';
  }

  @override
  String get habitSettingSwitch => 'Suggérer mes repas habituels';

  @override
  String get habitSettingOffNote =>
      'Désactiver ceci garde chaque entrée du journal et chaque repas enregistré.';

  @override
  String get habitIntro =>
      'Je peux remarquer les repas que tu consignes souvent et te les suggérer ici. C’est toujours toi qui choisis, et rien n’est consigné à ta place. On l’active?';

  @override
  String get habitTurnOn => 'Activer';

  @override
  String get habitNotNow => 'Pas maintenant';

  @override
  String get mealsLogThisTime => 'Consigner cette fois';

  @override
  String get mealsSaveVariation => 'Enregistrer comme variante';

  @override
  String get mealsSaveVariationTitle => 'Enregistrer comme variante';

  @override
  String mealsVariationName(String name) {
    return '$name (variante)';
  }

  @override
  String get mealsSaveAsMealBody =>
      'Les aliments et quantités affichés deviennent un repas enregistré. Rien n’est consigné.';

  @override
  String get mealsReviewActionsNote =>
      'Consigner cette fois enregistre seulement ces quantités; le repas enregistré reste tel quel. Mettre à jour le repas le modifie pour la prochaine fois. Rien de ce qui est déjà consigné ne change.';

  @override
  String get dcIngredientMealOnly =>
      'Je peux changer un aliment dans un repas enregistré. Pour une recette ou un aliment, change la quantité dans sa révision.';

  @override
  String dcIngredientWhich(String meal) {
    return 'Quel aliment dans $meal?';
  }

  @override
  String dcIngredientNotFound(String words, String meal) {
    return 'Je n’ai pas trouvé « $words » dans $meal. Le voici tel qu’enregistré; tu peux changer n’importe quel aliment dans la révision.';
  }

  @override
  String dcIngredientNeedAmount(String food) {
    return 'Combien de $food cette fois? Dis-le en grammes ou en portions, ou change-le dans la révision.';
  }

  @override
  String dcIngredientCantGrams(String food) {
    return '$food n’a pas de poids dans ce repas, donc les grammes ne peuvent pas servir. Utilise son unité dans la révision.';
  }

  @override
  String dcIngredientCantMeasure(String food) {
    return '$food ne peut pas se mesurer ainsi. Change sa quantité dans la révision.';
  }

  @override
  String dcIngredientLine(String meal, String amount, String food) {
    return '$meal avec $amount de $food cette fois. Ton repas enregistré reste tel quel, sauf si tu le mets à jour.';
  }

  @override
  String dcIngredientAmount(String food, String amount) {
    return '$food : $amount cette fois';
  }

  @override
  String get reminderPrivateTitle => 'Rappel GoHard';

  @override
  String get reminderPrivateBody => 'Ouvre GoHard pour le voir.';

  @override
  String reminderMealBody(String meal) {
    return 'C’est le moment de consigner ton « $meal ».';
  }

  @override
  String get reminderDoseBody => 'Touche pour confirmer dans GoHard.';

  @override
  String get reminderTaken => 'Pris';

  @override
  String get reminderSnooze => 'Plus tard';

  @override
  String get reminderSkip => 'Sauter';

  @override
  String get reminderMealChannelName => 'Rappels de repas';

  @override
  String get reminderMealChannelDescription =>
      'Rappels pour consigner un repas, aux heures que tu as choisies';

  @override
  String get reminderDoseChannelName =>
      'Rappels de médicaments et de suppléments';

  @override
  String get reminderDoseChannelDescription =>
      'Tes propres rappels de médicaments et de suppléments';

  @override
  String get reminderCategoryMeal => 'Repas';

  @override
  String get reminderCategoryMedication => 'Médicament';

  @override
  String get reminderCategorySupplement => 'Supplément';

  @override
  String get reminderEveryDay => 'Tous les jours';

  @override
  String get reminderWeekdays => 'Du lundi au vendredi';

  @override
  String get reminderNotAllowed =>
      'Enregistré. Les notifications ne sont pas autorisées pour GoHard, donc il ne peut pas encore s’afficher. Tu peux les autoriser dans les réglages du téléphone.';

  @override
  String get remindersTitle => 'Rappels';

  @override
  String get remindersSubtitle =>
      'Les notifications que tu configures. Rien n’est planifié tant que tu n’en ajoutes pas.';

  @override
  String meRemindersPageSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activés',
      one: '$count activé',
      zero: 'Aucun activé',
    );
    return '$_temp0';
  }

  @override
  String get reminderDenied =>
      'Les notifications de GoHard sont désactivées dans les réglages du téléphone, donc ces rappels ne peuvent pas s’afficher.';

  @override
  String get reminderTodayHeading => 'Aujourd’hui';

  @override
  String get reminderWorkoutHeading => 'Entraînements';

  @override
  String get reminderOwnHeading => 'Repas, médicaments et suppléments';

  @override
  String get reminderNone => 'Aucun pour l’instant.';

  @override
  String get reminderPaused => 'En pause';

  @override
  String get reminderAdd => 'Ajouter un rappel';

  @override
  String reminderThrough(String date) {
    return 'Planifiés jusqu’au $date. Ouvrir GoHard planifie les jours suivants.';
  }

  @override
  String get reminderPolicy =>
      'Les heures sont locales : un rappel réglé à 8 h arrive à 8 h où que soit le téléphone, et suit l’heure avancée. Un jour où cette heure n’existe pas, il arrive juste après le changement; quand elle se produit deux fois, il arrive une seule fois. GoHard planifie les 7 prochains jours chaque fois qu’il est ouvert. Le téléphone décide du moment exact, donc un rappel peut arriver un peu en retard. Un rappel de repas n’est pas envoyé une fois ce repas consigné sur ce téléphone ce jour-là. Les rappels et les réponses sont gardés sur ce téléphone, pour ce compte seulement : ils ne sont pas enregistrés dans ton compte ni envoyés à une IA.';

  @override
  String get reminderUnconfirmed => 'Non confirmé';

  @override
  String get reminderStatusTaken => 'Pris';

  @override
  String get reminderStatusSkipped => 'Sauté';

  @override
  String get reminderStatusSnoozed => 'Remis à plus tard';

  @override
  String reminderOccurrence(String date, String time) {
    return '$date à $time';
  }

  @override
  String reminderSnoozeFor(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Plus tard ($minutes minutes)',
      one: 'Plus tard ($minutes minute)',
    );
    return '$_temp0';
  }

  @override
  String reminderMealDefaultName(String meal) {
    return 'Consigner « $meal »';
  }

  @override
  String get reminderProblemName =>
      'Donne un nom au rappel (60 caractères au plus).';

  @override
  String get reminderProblemTime => 'Choisis une heure.';

  @override
  String get reminderProblemDays => 'Choisis au moins un jour.';

  @override
  String get reminderSaved => 'Rappel enregistré.';

  @override
  String reminderDeleteTitle(String name) {
    return 'Supprimer $name?';
  }

  @override
  String get reminderDeleteBody =>
      'Ses notifications sont annulées. Les réponses déjà données restent sur ce téléphone.';

  @override
  String get reminderNewTitle => 'Nouveau rappel';

  @override
  String get reminderEditTitle => 'Modifier le rappel';

  @override
  String get reminderNameLabel => 'Nom';

  @override
  String get reminderDoseNameLabel => 'Nom, comme tu veux le voir';

  @override
  String reminderSuggestedTime(String meal, String time) {
    return 'Tu consignes souvent « $meal » vers $time. Utiliser cette heure?';
  }

  @override
  String reminderUseTime(String time) {
    return 'Utiliser $time';
  }

  @override
  String get reminderOwnTime => 'Choisir mon heure';

  @override
  String get reminderTimeLabel => 'Heure';

  @override
  String get reminderDaysLabel => 'Jours';

  @override
  String get reminderInstructionsLabel => 'Instructions (facultatif)';

  @override
  String get reminderInstructionsHelp =>
      'Tes propres mots, par exemple ce que dit ton prescripteur ou l’étiquette. GoHard ne suggère jamais de dose ni d’horaire.';

  @override
  String get reminderPrivateLabel =>
      'Masquer les détails sur l’écran verrouillé';

  @override
  String get reminderPrivateHelp =>
      'La notification dit seulement « Rappel GoHard ».';

  @override
  String get reminderOnLabel => 'Activé';

  @override
  String get reminderMealNote =>
      'Si ce repas est déjà consigné sur ce téléphone ce jour-là, le rappel n’est pas envoyé.';

  @override
  String get reminderDoseNote =>
      'Un rappel sert seulement à te rappeler et à confirmer; ce n’est pas un avis médical. Si tu ne réponds pas, il reste Non confirmé.';

  @override
  String reminderSuggestSay(String meal, String time) {
    return 'Tu consignes souvent « $meal » vers $time. Veux-tu un rappel pour le consigner?';
  }

  @override
  String get reminderAddThis => 'Ajouter un rappel';

  @override
  String get eatMealReminders => 'Rappels de repas';
}

/// The translations for French, as used in Canada (`fr_CA`).
class AppLocalizationsFrCa extends AppLocalizationsFr {
  AppLocalizationsFrCa() : super('fr_CA');
}
