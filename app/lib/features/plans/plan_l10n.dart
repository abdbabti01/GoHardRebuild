import '../../core/catalog_names.dart';
import '../../core/language.dart';
import '../../core/search_fold.dart';
import 'plan_rules.dart';
import 'schedule_rules.dart';

/// The words for a plan or schedule rule code (PlanRules / ScheduleRules / the account's plan errors).
String planErrorText(AppLocalizations l, String code) => switch (code) {
      ScheduleRules.recoveryCollision => l.planErrRecovery,
      ScheduleRules.occasionNotEligible => l.planErrNotEligible,
      ScheduleRules.staleReview => l.planErrStaleReview,
      ScheduleRules.invalidWeekdayCount => l.planErrWeekdayCount,
      ScheduleRules.invalidDate => l.planErrInvalidDate,
      ScheduleRules.duplicateOccasion || ScheduleRules.occasionNotFound => l.planErrNoLongerInPlan,
      PlanRules.titleInvalid => l.planErrTitle,
      PlanRules.durationInvalid => l.planErrDuration,
      PlanRules.timeBudgetInvalid => l.planErrTimeBudget,
      PlanRules.workoutsInvalid => l.planErrWorkouts,
      PlanRules.scheduleInvalid => l.planErrSchedule,
      PlanRules.notUsable => l.planErrNotUsable,
      'PLAN_NEEDS_NEWER_APP' => l.planErrNewerApp,
      'UNKNOWN_EXERCISE' => l.planErrUnknownExercise,
      'START_LOCKED' => l.planErrStartLocked,
      'MODE_LOCKED' => l.planErrModeLocked,
      'OCCASION_NOT_MOVABLE' => l.planErrNotMovable,
      'EXERCISE_NAME_INVALID' => l.planErrExerciseName,
      'PLAN_CHANGED_SINCE_EDIT' => l.planErrChangedSinceEdit,
      'PLAN_NOT_ACTIVE' => l.planErrNotActive,
      'TARGET_CONTEXT_CHANGED' => l.planErrTargetContext,
      'TARGET_CHANGED_SINCE' => l.planErrTargetChanged,
      'PRIMARY_EXISTS' => l.planPrimaryExists,
      _ => l.planErrUnknown(code),
    };

/// Why a starting split is suggested for [days] training days ([suggestTemplate]).
String suggestionReason(AppLocalizations l, int days) => switch (days) {
      <= 3 => l.planSuggestReasonFew(days),
      4 => l.planSuggestReasonFour,
      5 => l.planSuggestReasonFive,
      7 => l.planSuggestReasonSeven(days),
      _ => l.planSuggestReasonMany(days),
    };

String equipmentLabel(AppLocalizations l, String key) => switch (key) {
      'full_gym' => l.builderEquipmentFullGym,
      'dumbbells' => l.builderEquipmentDumbbells,
      'bodyweight' => l.builderEquipmentBodyweight,
      _ => key,
    };

String experienceLabel(AppLocalizations l, String key) => switch (key) {
      'new' => l.builderExperienceNew,
      'comfortable' => l.builderExperienceComfortable,
      'experienced' => l.builderExperienceExperienced,
      _ => key,
    };

String scheduleModeLabel(AppLocalizations l, String mode) => mode == 'rotating' ? l.planModeRotating : l.planModeFixed;

/// Does an exercise match a search? The folded query against the folded shown or stored name and, for a catalog
/// exercise, every name and alias it has in any language, so "développé couché", "ضغط الصدر" and "bench press" find
/// the same exercise. A custom exercise matches by its own name. Matching only: identity and order are untouched.
bool exerciseMatches(ExerciseNames names, String query, {required String name, String? catalogKey, String extra = ''}) {
  final q = foldForSearch(query.trim());
  if (q.isEmpty) return true;
  if (foldForSearch('$name $extra').contains(q)) return true;
  return catalogKey != null && names.searchTerms(catalogKey).any((t) => t.contains(q));
}
