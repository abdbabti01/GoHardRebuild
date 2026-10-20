import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_fold.dart';

/// French and Arabic names for the shared exercise catalog, its categories and equipment, keyed by the stable
/// catalog key (`assets/data/exercise-names.l10n.json`, docs/LOCALIZATION.md › Exercise names). Display and search
/// only: catalog keys, stored names, recorded sets and prescriptions are never rewritten.
class ExerciseNames {
  const ExerciseNames._(this._exercises, this._categories, this._equipment);
  static const empty = ExerciseNames._({}, {}, {});

  factory ExerciseNames.parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    Map<String, Map<String, dynamic>> m(String k) => {for (final e in ((j[k] as Map?) ?? const {}).entries) e.key as String: (e.value as Map).cast<String, dynamic>()};
    return ExerciseNames._(m('exercises'), m('categories'), m('equipment'));
  }

  static Future<ExerciseNames> load() async {
    try {
      return ExerciseNames.parse(await rootBundle.loadString('assets/data/exercise-names.l10n.json'));
    } on Object {
      return empty; // a missing file only means English names
    }
  }

  final Map<String, Map<String, dynamic>> _exercises, _categories, _equipment;

  static String? _lang(Locale l) => switch (l.languageCode) { 'fr' => 'fr', 'ar' => 'ar', _ => null };

  /// The name to show for an exercise. A catalog exercise whose stored name is still the catalog's own English name
  /// (an unchanged built-in label) is shown in [locale]; anything else — a renamed, custom or historical name, or
  /// no catalog key — is the stored wording, unchanged.
  String name(String? catalogKey, String stored, Locale locale) {
    final e = _exercises[catalogKey];
    final lang = _lang(locale);
    if (e == null || lang == null || e['en'] != stored) return stored;
    return (e[lang] as String?) ?? stored;
  }

  /// A catalog name in [locale] by key alone (the catalog itself, a template's exercise).
  String nameOf(String catalogKey, String english, Locale locale) => name(catalogKey, english, locale);

  String category(String english, Locale locale) => _label(_categories, english, locale);
  String equipment(String english, Locale locale) => _label(_equipment, english, locale);

  String _label(Map<String, Map<String, dynamic>> m, String english, Locale locale) {
    final lang = _lang(locale);
    return lang == null ? english : (m[english]?[lang] as String?) ?? english;
  }

  /// Folded words a search can match for one catalog exercise, in every language: the English name, the French and
  /// Arabic names and their aliases. So "développé couché", "ضغط الصدر" and "bench press" find the same exercise.
  List<String> searchTerms(String catalogKey) {
    final e = _exercises[catalogKey];
    if (e == null) return const [];
    final aliases = (e['aliases'] as Map?) ?? const {};
    return [
      for (final v in [e['en'], e['fr'], e['ar'], for (final list in aliases.values) ...(list as List)])
        if (v is String && v.isNotEmpty) foldForSearch(v),
    ];
  }
}

/// Overridden at startup with the bundled names (main.dart). Left alone (most tests), every name is the stored one.
final exerciseNamesProvider = Provider<ExerciseNames>((_) => ExerciseNames.empty);
