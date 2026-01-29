import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'retail_building_model.dart';
import 'retail_slot_model.dart';

class RetailRepository {
  static List<RetailBuilding>? _retailBuildings;
  static List<RetailSlot>? _retailSlots;

  static Future<List<RetailBuilding>> loadRetailBuildings() async {
    if (_retailBuildings != null) {
      return _retailBuildings!;
    }

    try {
      final retailJson = await rootBundle.loadString('assets/data/retail.json');
      final retailData = json.decode(retailJson);
      final retailBuildings = retailData['retailBuildings'] as List;
      _retailBuildings = retailBuildings
          .map((building) => RetailBuilding.fromJson(building))
          .toList();
      return _retailBuildings!;
    } catch (e) {
      throw Exception('Error loading retail buildings: $e');
    }
  }

  static Future<List<RetailSlot>> loadRetailSlots() async {
    if (_retailSlots != null) {
      return _retailSlots!;
    }

    try {
      final retailSlotJson = await rootBundle.loadString(
        'assets/data/retail_slot.json',
      );
      debugPrint(
        'DEBUG: Loaded retail_slot.json: ${retailSlotJson.length} characters',
      );
      final retailSlotData = json.decode(retailSlotJson);
      final retailSlots = retailSlotData['retail_slots'] as List;
      _retailSlots = retailSlots
          .map((slot) => RetailSlot.fromJson(slot))
          .toList();
      debugPrint('DEBUG: Parsed ${retailSlots.length} retail slots');
      return _retailSlots!;
    } catch (e) {
      debugPrint('Error loading retail slots: $e');
      throw Exception('Error loading retail slots: $e');
    }
  }

  static RetailBuilding? getRetailBuildingById(String id) {
    if (_retailBuildings == null) {
      return null;
    }
    return _retailBuildings!.firstWhere(
      (building) => building.id == id,
      orElse: () => throw Exception('Retail building with id $id not found'),
    );
  }

  static RetailSlot? getRetailSlotById(int slotId) {
    if (_retailSlots == null) {
      return null;
    }
    return _retailSlots!.firstWhere(
      (slot) => slot.slotId == slotId,
      orElse: () => throw Exception('Retail slot with id $slotId not found'),
    );
  }
}
