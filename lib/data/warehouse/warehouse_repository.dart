import 'dart:convert';
import 'package:flutter/services.dart';
import 'warehouse_model.dart';
import 'warehouse_level_model.dart';

class WarehouseRepository {
  static List<WarehouseModel>? _cachedWarehouses;
  static List<WarehouseLevelModel>? _cachedLevels;

  /// Load all warehouse types from JSON
  static Future<List<WarehouseModel>> loadWarehouses() async {
    if (_cachedWarehouses != null) {
      return _cachedWarehouses!;
    }

    final String response = await rootBundle.loadString(
      'assets/data/warehouse.json',
    );
    final data = json.decode(response);
    final List<dynamic> warehousesJson = data['warehouses'];

    _cachedWarehouses = warehousesJson
        .map((json) => WarehouseModel.fromJson(json))
        .toList();

    return _cachedWarehouses!;
  }

  /// Load all warehouse level progressions from JSON
  static Future<List<WarehouseLevelModel>> loadWarehouseLevels() async {
    if (_cachedLevels != null) {
      return _cachedLevels!;
    }

    final String response = await rootBundle.loadString(
      'assets/data/warehouse_level.json',
    );
    final data = json.decode(response);
    final List<dynamic> levelsJson = data['warehouse_level_progression'];

    _cachedLevels = levelsJson
        .map((json) => WarehouseLevelModel.fromJson(json))
        .toList();

    return _cachedLevels!;
  }

  /// Get a specific warehouse by ID
  static Future<WarehouseModel?> getWarehouseById(int id) async {
    final warehouses = await loadWarehouses();
    try {
      return warehouses.firstWhere((w) => w.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get warehouses available at a specific user level
  static Future<List<WarehouseModel>> getAvailableWarehouses(
    int userLevel,
  ) async {
    final warehouses = await loadWarehouses();
    return warehouses.where((w) => w.requiredLevel <= userLevel).toList();
  }

  /// Get all warehouses sorted by grade
  static Future<List<WarehouseModel>> getWarehousesByGrade() async {
    final warehouses = await loadWarehouses();
    final sorted = List<WarehouseModel>.from(warehouses);
    sorted.sort((a, b) => a.grade.compareTo(b.grade));
    return sorted;
  }

  /// Get warehouse level info for a specific level
  static Future<WarehouseLevelModel?> getWarehouseLevelInfo(int level) async {
    final levels = await loadWarehouseLevels();
    try {
      return levels.firstWhere((l) => l.level == level);
    } catch (e) {
      return null;
    }
  }

  /// Calculate total capacity for a warehouse with upgrades
  static Future<double> calculateTotalCapacity(
    int warehouseId,
    int upgradeLevel,
  ) async {
    final warehouse = await getWarehouseById(warehouseId);
    if (warehouse == null) return 0.0;

    double totalCapacity = warehouse.capacityM3;

    // Add capacity from each upgrade level
    for (int level = 1; level <= upgradeLevel; level++) {
      final levelInfo = await getWarehouseLevelInfo(level);
      if (levelInfo != null) {
        totalCapacity += levelInfo.capacityIncreaseM3;
      }
    }

    return totalCapacity;
  }

  /// Calculate total upgrade cost from level 1 to target level
  static Future<int> calculateTotalUpgradeCost(
    int fromLevel,
    int toLevel,
  ) async {
    if (fromLevel >= toLevel) return 0;

    final levels = await loadWarehouseLevels();
    int totalCost = 0;

    for (int level = fromLevel + 1; level <= toLevel; level++) {
      final levelInfo = levels.firstWhere(
        (l) => l.level == level,
        orElse: () => WarehouseLevelModel(
          level: level,
          capacityIncreaseM3: 0,
          currency: 'money',
          cost: 0,
        ),
      );
      totalCost += levelInfo.cost;
    }

    return totalCost;
  }

  /// Calculate capacity based on simple formula (Base + Level * 100)
  /// Config matches logic in WarehouseManagerScreen
  static double calculateRealCapacity(WarehouseModel warehouse, int level) {
    return warehouse.capacityM3 + (level * 100);
  }

  /// Calculate current load from detailed storage map
  static double calculateCurrentLoad(Map<String, dynamic> storage) {
    double totalM3 = 0;
    storage.forEach((materialId, data) {
      final units = (data['units'] as num?)?.toDouble() ?? 0;
      final m3PerUnit = (data['m3PerUnit'] as num?)?.toDouble() ?? 0;
      totalM3 += units * m3PerUnit;
    });
    return totalM3;
  }

  /// Clear cache (useful for testing or when data changes)
  static void clearCache() {
    _cachedWarehouses = null;
    _cachedLevels = null;
  }
}
