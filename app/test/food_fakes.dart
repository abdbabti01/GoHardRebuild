import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/me/account_repository.dart';
import 'package:gohard_rebuild/features/nutrition/barcode_scan_screen.dart';
import 'package:gohard_rebuild/features/nutrition/food_discovery.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';

/// Stand-ins for the screens' collaborators in widget tests: they record what the screens asked for. The real
/// repositories are exercised against the real database in food_test.dart. None of this ships in the app.

const _receipt = Receipt('op', 'pending');

class RecordingJournal implements FoodRepository {
  final saved = <FoodDraft>[];
  final removed = <FoodEntry>[];

  /// While set, a save stays in flight, as a slow disk would keep it.
  Completer<void>? hold;

  @override
  Future<Receipt> save(FoodDraft d) async {
    FoodRepository.validate(d);
    await hold?.future;
    saved.add(d);
    return _receipt;
  }

  @override
  Future<Receipt> remove(FoodEntry e) async {
    removed.add(e);
    return _receipt;
  }

  @override
  Future<void> keepLocal(String conflictOperationId, FoodEntry local) async {}
}

class RecordingSavedFoods implements SavedFoodRepository {
  final mine = <({String name, Map<String, double?> values, FoodItem? from, double? quantity, String? amount})>[];
  final favourited = <FoodItem>[];
  final unfavourited = <SavedFood>[];

  @override
  Future<Receipt> saveMine({String? id, required String name, required Map<String, double?> values, FoodItem? from, double? quantity, String? unitId, String? amount, bool isFavourite = false}) async {
    mine.add((name: name, values: values, from: from, quantity: quantity, amount: amount));
    return _receipt;
  }

  @override
  Future<Receipt> favourite(FoodItem item, {SavedFood? existing}) async {
    favourited.add(item);
    return _receipt;
  }

  @override
  Future<Receipt> unfavourite(SavedFood food) async {
    unfavourited.add(food);
    return _receipt;
  }

  @override
  Future<Receipt> remove(SavedFood food) async => _receipt;
}

class ScriptedDiscovery implements FoodDiscovery {
  ScriptedDiscovery({this.results = const [], this.products = const {}, this.searchProblem, this.barcodeProblem});
  final List<FoodItem> results;
  final Map<String, FoodItem> products;
  final LookupProblem? searchProblem, barcodeProblem;
  final searches = <String>[], barcodes = <String>[];

  @override
  Future<List<FoodItem>> search(String query) async {
    searches.add(query);
    if (searchProblem != null) throw LookupFailure(searchProblem!);
    return results;
  }

  @override
  Future<FoodItem> barcode(String raw) async {
    barcodes.add(raw);
    if (barcodeProblem != null) throw LookupFailure(barcodeProblem!);
    return products[raw] ?? (throw const LookupFailure(LookupProblem.notFound));
  }

  @override
  Future<List<({FoodItem item, DateTime at})>> cached() async => const [];

  @override
  Future<void> remember(List<FoodItem> items) async {}
}

class RecordingProfiles implements ProfileRepository {
  final goals = <(int?, int?)>[];

  @override
  Future<Receipt> setGoals(Profile current, {required int? calorieGoal, required int? proteinGoal}) async {
    ProfileRepository.validateGoals(calorieGoal, proteinGoal);
    goals.add((calorieGoal, proteinGoal));
    return _receipt;
  }

  @override
  Future<Receipt> update(Profile current, {String? displayName, String? appearance, String? loadUnit, bool? remindersEnabled, String? reminderLocalTime, Json? goals}) async => _receipt;
}

/// A camera that "sees" the given codes as soon as it is shown, or reports that it cannot be used.
class FakeCamera extends StatefulWidget {
  const FakeCamera({super.key, required this.onCode, required this.onUnavailable, this.codes = const [], this.refused});
  final ValueChanged<String> onCode;
  final ValueChanged<bool> onUnavailable;
  final List<String> codes;
  final bool? refused;
  @override
  State<FakeCamera> createState() => _FakeCameraState();
}

class _FakeCameraState extends State<FakeCamera> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.refused != null) widget.onUnavailable(widget.refused!);
      widget.codes.forEach(widget.onCode);
    });
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Color(0xFF30343A), child: Center(child: Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 48)));
}

/// Every collaborator of the food screens, recorded.
class FoodFakes {
  FoodFakes({ScriptedDiscovery? discovery, this.codes = const [], this.cameraRefused}) : discovery = discovery ?? ScriptedDiscovery();
  final journal = RecordingJournal();
  final savedFoods = RecordingSavedFoods();
  final profiles = RecordingProfiles();
  final ScriptedDiscovery discovery;
  final List<String> codes;
  final bool? cameraRefused;

  List<Override> get overrides => [
        foodRepositoryProvider.overrideWithValue(journal),
        savedFoodRepositoryProvider.overrideWithValue(savedFoods),
        profileRepositoryProvider.overrideWithValue(profiles),
        foodDiscoveryProvider.overrideWithValue(discovery),
        scannerCameraProvider.overrideWithValue(({required onCode, required onUnavailable}) => FakeCamera(onCode: onCode, onUnavailable: onUnavailable, codes: codes, refused: cameraRefused)),
      ];
}

// ---------------------------------------------------------------------------- food fixtures

FoodItem chickenRaw() => FoodItem({
      'source': 'usda', 'sourceId': '171077', 'name': 'Chicken, breast, meat only, raw', 'description': 'SR Legacy · Poultry Products', 'basis': '100g',
      'nutrients': {'calories': 120, 'protein': 22.5, 'carbs': 0, 'fat': 2.62}, 'servings': [],
    });

FoodItem riceCooked() => FoodItem({
      'source': 'usda', 'sourceId': '2708402', 'name': 'Rice, cooked, NFS', 'description': 'Survey (FNDDS) · Rice', 'basis': '100g',
      'nutrients': {'calories': 129, 'protein': 2.67, 'carbs': 27.99, 'fat': 0.28}, 'servings': [{'label': '1 cup, cooked', 'grams': 158, 'milliliters': null}],
    });

FoodItem hazelnutSpread() => FoodItem({
      'source': 'off', 'sourceId': '3017620422003', 'barcode': '3017620422003', 'name': 'Nutella', 'brand': 'Nutella, Ferrero', 'description': '400 g e', 'basis': '100g',
      'nutrients': {'calories': 539, 'protein': 6.3, 'carbs': 57.5, 'fat': 30.9}, 'servings': [{'label': '15 g', 'grams': 15, 'milliliters': null}],
    });

/// A product whose label states only energy: the other three are unknown, not zero.
FoodItem sparseDrink() => FoodItem({
      'source': 'off', 'sourceId': '5449000000996', 'barcode': '5449000000996', 'name': 'Cola', 'brand': 'Example Drinks', 'description': '330 ml', 'basis': '100ml',
      'nutrients': {'calories': 42, 'protein': null, 'carbs': null, 'fat': null}, 'servings': [{'label': '1 can (330 ml)', 'grams': null, 'milliliters': 330}],
    });

Json savedFood(String id, FoodItem item, {bool favourite = false}) => {'id': id, 'item': item.j, 'isFavourite': favourite, 'revision': 1, 'isDeleted': false};

FoodItem ownOats() => FoodItem({
      'source': 'user', 'sourceId': 's-oats', 'name': 'Overnight oats', 'basis': 'serving', 'nutrients': {'calories': 420, 'protein': 24, 'carbs': 52, 'fat': null},
      'servings': [{'label': '1 jar', 'grams': null, 'milliliters': null}],
    });
