import '../../data/models.dart';
import '../../data/sync.dart';

/// Food form input that cannot be saved. The draft stays on screen.
class InvalidFood implements Exception {
  const InvalidFood(this.message);
  final String message;
}

/// One consumed food being added or edited. `dayKey` is pinned when the form opens, so midnight passing
/// while it is open never moves the entry to another day.
class FoodDraft {
  FoodDraft({this.id, required this.dayKey, this.meal = 'Breakfast', this.name = '', this.amount = '', this.calories, this.protein, this.carbs, this.fat});
  factory FoodDraft.edit(FoodEntry e) => FoodDraft(id: e.id, dayKey: e.dayKey, meal: e.meal, name: e.name, amount: e.amountDescription,
      calories: e.calories, protein: e.protein, carbs: e.carbs, fat: e.fat);
  final String? id;
  String dayKey, meal, name, amount;

  /// Null = left blank = unknown. Zero = the user entered zero. These are never interchangeable.
  double? calories, protein, carbs, fat;
}

/// The owner's consumed-food journal, saved locally first. Today and Eat both read these same records.
class FoodRepository {
  FoodRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  static void validate(FoodDraft d) {
    if (d.name.trim().isEmpty) throw const InvalidFood('Enter what you ate.');
    if (d.amount.trim().isEmpty) throw const InvalidFood('Enter how much, in your own words.');
    if (d.name.trim().length > 120 || d.amount.trim().length > 80) throw const InvalidFood('That text is too long.');
    if (!meals.contains(d.meal)) throw const InvalidFood('Choose a meal.');
    for (final v in [d.calories, d.protein, d.carbs, d.fat]) {
      if (v != null && (!v.isFinite || v < 0 || v > 100000)) throw const InvalidFood('Nutrition values must be zero or more.');
    }
  }

  /// Saves a new entry or one edited entry. Blank nutrients are sent as null, never as zero.
  Future<Receipt> save(FoodDraft d) {
    validate(d);
    final macros = {'calories': d.calories, 'protein': d.protein, 'carbs': d.carbs, 'fat': d.fat};
    final id = d.id ?? SyncEngine.newId();
    final fields = {'dayKey': d.dayKey, 'meal': d.meal, 'name': d.name.trim(), 'amountDescription': d.amount.trim(), 'macros': macros};
    final body = <String, dynamic>{
      'id': id, ...fields, 'isDeleted': false,
      'provenance': {for (final e in macros.entries) e.key: e.value == null ? 'unknown' : 'entered'},
    };
    final write = [LocalWrite(Kinds.food, id, body, dayKey: d.dayKey)];
    return d.id == null
        ? _sync.submit(_owner, kind: 'food.create', path: '/food-entries', targetKind: Kinds.food, targetId: id, writes: write, payload: {'entryId': id, ...fields})
        : _sync.submit(_owner, kind: 'food.update', method: 'PUT', path: '/food-entries/$id', targetKind: Kinds.food, targetId: id, writes: write,
            payload: {'expectedRevision': {r'$rev': [Kinds.food, id]}, ...fields});
  }

  /// Removes exactly this entry. Other entries, including others in the same meal, are untouched.
  Future<Receipt> remove(FoodEntry e) => _sync.submit(_owner, kind: 'food.delete', path: '/food-entries/${e.id}/delete', targetKind: Kinds.food, targetId: e.id,
      writes: [LocalWrite(Kinds.food, e.id, copyJson(e.j)..['isDeleted'] = true, dayKey: e.dayKey)],
      payload: {'expectedRevision': {r'$rev': [Kinds.food, e.id]}});

  /// Conflict choice "keep mine" for a food entry edited on two devices.
  Future<void> keepLocal(String conflictOperationId, FoodEntry local) => _sync.resolveKeepLocal(_owner, conflictOperationId,
      kind: local.isDeleted ? 'food.delete' : 'food.update', method: local.isDeleted ? 'POST' : 'PUT',
      path: local.isDeleted ? '/food-entries/${local.id}/delete' : '/food-entries/${local.id}',
      payload: {
        'expectedRevision': {r'$rev': [Kinds.food, local.id]},
        if (!local.isDeleted) ...{'dayKey': local.dayKey, 'meal': local.meal, 'name': local.name, 'amountDescription': local.amountDescription, 'macros': local.macros},
      });
}
