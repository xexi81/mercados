import 'dart:convert';
import 'package:flutter/services.dart';
import 'production_queue_prices.dart';

class ProductionQueuePricesRepository {
  static ProductionQueuePrices? _cachedPrices;

  static Future<ProductionQueuePrices> loadPrices() async {
    if (_cachedPrices != null) {
      return _cachedPrices!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/factories/production_queue_prices.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final Map<String, dynamic> pricesJson =
          jsonData['productionQueuePrices'] as Map<String, dynamic>;

      _cachedPrices = ProductionQueuePrices.fromJson(pricesJson);

      return _cachedPrices!;
    } catch (e) {
      throw Exception('Error loading production queue prices data: $e');
    }
  }

  static void clearCache() {
    _cachedPrices = null;
  }
}
