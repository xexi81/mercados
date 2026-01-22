import 'dart:convert';
import 'package:flutter/services.dart';
import 'factory_model.dart';

class FactoryRepository {
  static List<FactoryModel>? _cachedFactories;

  static Future<List<FactoryModel>> loadFactories() async {
    if (_cachedFactories != null) {
      return _cachedFactories!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/factories.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> factoriesJson =
          jsonData['factories'] as List<dynamic>;

      _cachedFactories = factoriesJson
          .map((f) => FactoryModel.fromJson(f as Map<String, dynamic>))
          .toList();

      return _cachedFactories!;
    } catch (e) {
      throw Exception('Error loading factories data: $e');
    }
  }

  static Future<FactoryModel?> getFactoryById(int id) async {
    final factories = await loadFactories();
    try {
      return factories.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }

  static void clearCache() {
    _cachedFactories = null;
  }
}
