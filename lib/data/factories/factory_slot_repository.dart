import 'dart:convert';
import 'package:flutter/services.dart';
import 'factory_slot_model.dart';

class FactorySlotRepository {
  static List<FactorySlotModel>? _cachedSlots;

  static Future<List<FactorySlotModel>> loadFactorySlots() async {
    if (_cachedSlots != null) {
      return _cachedSlots!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/factories_slots.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> slotsJson =
          jsonData['factory_slots'] as List<dynamic>;

      _cachedSlots = slotsJson
          .map((s) => FactorySlotModel.fromJson(s as Map<String, dynamic>))
          .toList();

      return _cachedSlots!;
    } catch (e) {
      throw Exception('Error loading factory slots data: $e');
    }
  }

  static Future<FactorySlotModel?> getSlotById(int slotId) async {
    final slots = await loadFactorySlots();
    try {
      return slots.firstWhere((s) => s.slotId == slotId);
    } catch (e) {
      return null;
    }
  }

  static void clearCache() {
    _cachedSlots = null;
  }
}
