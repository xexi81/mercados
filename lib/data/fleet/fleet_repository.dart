import 'dart:convert';
import 'package:flutter/services.dart';
import 'fleet_model.dart';

class FleetRepository {
  static List<FleetModel>? _fleets;

  static Future<List<FleetModel>> loadFleets() async {
    if (_fleets != null) return _fleets!;

    try {
      final String response = await rootBundle.loadString(
        'assets/data/fleet.json',
      );
      final data = await json.decode(response);
      final List<dynamic> fleetsJson = data['fleets'];

      _fleets = fleetsJson.map((json) => FleetModel.fromJson(json)).toList();
      return _fleets!;
    } catch (e) {
      print('Error loading fleets: $e');
      return [];
    }
  }

  static Future<FleetModel?> getFleetById(int fleetId) async {
    final fleets = await loadFleets();
    return fleets.firstWhere(
      (f) => f.fleetId == fleetId,
      orElse: () => throw Exception('Fleet not found'),
    );
  }
}
