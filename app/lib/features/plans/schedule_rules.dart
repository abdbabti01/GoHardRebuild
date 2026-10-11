import '../../core/clock.dart';

/// Pure calendar-date rules, mirrored from the API's `ScheduleRules` and checked against the same fixture.
class ScheduleOccasion {
  const ScheduleOccasion({required this.id, required this.originalDate, required this.scheduledDate, required this.weekNumber,
      this.isSkipped = false, this.isRecorded = false, this.isOpen = false});
  final String id, originalDate, scheduledDate;
  final int weekNumber;
  final bool isSkipped, isRecorded, isOpen;

  /// Only pending occasions may be moved, skipped or shifted by a resume.
  bool get isEligible => !isSkipped && !isRecorded && !isOpen;

  ScheduleOccasion movedTo(String date) => ScheduleOccasion(id: id, originalDate: originalDate, scheduledDate: date, weekNumber: weekNumber,
      isSkipped: isSkipped, isRecorded: isRecorded, isOpen: isOpen);
}

class ScheduleChange {
  const ScheduleChange(this.occasionId, this.from, this.to);
  final String occasionId, from, to;
  Map<String, dynamic> toJson() => {'occasionId': occasionId, 'from': from, 'to': to};
}

class ScheduleValidation {
  const ScheduleValidation(this.errors, this.projected, this.changed, this.blockEnd);
  final List<String> errors;
  final List<ScheduleOccasion> projected, changed;
  final String? blockEnd;
  bool get isValid => errors.isEmpty;
}

abstract final class ScheduleRules {
  static const duplicateOccasion = 'DUPLICATE_OCCASION', occasionNotFound = 'OCCASION_NOT_FOUND', occasionNotEligible = 'OCCASION_NOT_ELIGIBLE',
      staleReview = 'STALE_REVIEW', recoveryCollision = 'RECOVERY_COLLISION', invalidWeekdayCount = 'INVALID_WEEKDAY_COUNT', invalidDate = 'INVALID_DATE';

  static final _shape = RegExp('^[0-9]{4}-[0-9]{2}-[0-9]{2}\$');

  static bool isDayKey(String s) => _shape.hasMatch(s) && dayKeyOf(parseDayKey(s)) == s; // rejects 2026-02-30

  static ScheduleValidation validate(List<ScheduleOccasion> all, List<ScheduleChange> changes, int minimumRecoveryDays) {
    final errors = <String>[];
    final projected = {for (final o in all) o.id: o};
    final changedIds = <String>[];
    for (final c in changes) {
      final o = projected[c.occasionId];
      if (changedIds.contains(c.occasionId)) {
        errors.add(duplicateOccasion);
      } else if (o == null) {
        errors.add(occasionNotFound);
      } else if (!isDayKey(c.to)) {
        errors.add(invalidDate);
      } else if (!o.isEligible) {
        errors.add(occasionNotEligible);
      } else if (o.scheduledDate != c.from) {
        errors.add(staleReview);
      } else {
        changedIds.add(c.occasionId);
        projected[c.occasionId] = o.movedTo(c.to);
      }
    }
    // Spacing is only judged for occasions this change touches; retained history is never re-litigated.
    for (final id in changedIds) {
      final moved = projected[id]!;
      final collides = projected.values.any((o) => o.id != id && !o.isSkipped && daysBetween(o.scheduledDate, moved.scheduledDate).abs() <= minimumRecoveryDays);
      if (collides) errors.add(recoveryCollision);
    }
    final list = [for (final o in all) projected[o.id]!];
    final end = list.isEmpty ? null : list.map((o) => o.scheduledDate).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    return ScheduleValidation(errors, list, [for (final id in changedIds) projected[id]!], end);
  }

  /// Dates for a new block: each chosen ISO weekday (1 = Monday) on or after the start, repeated every seven days.
  static ({List<String> errors, List<String> dates}) generate(String start, List<int> weekdays, int sessionsPerWeek, int blockWeeks, int minimumRecoveryDays) {
    final distinct = weekdays.toSet();
    if (distinct.length != weekdays.length || distinct.length != sessionsPerWeek || distinct.isEmpty) return (errors: [invalidWeekdayCount], dates: <String>[]);
    final startWeekday = parseDayKey(start).weekday;
    final first = [for (final d in distinct) addDays(start, (d - startWeekday + 7) % 7)]..sort();
    for (var i = 0; i < first.length && first.length > 1; i++) {
      final next = i + 1 < first.length ? first[i + 1] : addDays(first[0], 7);
      if (daysBetween(first[i], next) <= minimumRecoveryDays) return (errors: [recoveryCollision], dates: <String>[]);
    }
    return (errors: <String>[], dates: [for (var w = 0; w < blockWeeks; w++) for (final d in first) addDays(d, 7 * w)]);
  }

  static String describe(String code) => switch (code) {
        recoveryCollision => 'That leaves no recovery day between two workouts.',
        occasionNotEligible => 'That workout is already recorded, skipped or in progress, so it cannot move.',
        staleReview => 'The schedule changed since you reviewed it. Review it again.',
        invalidWeekdayCount => 'Choose exactly as many days as workouts per week.',
        invalidDate => 'Enter a real calendar date.',
        duplicateOccasion || occasionNotFound => 'That workout is no longer part of this plan.',
        _ => 'That change could not be applied ($code).',
      };
}
