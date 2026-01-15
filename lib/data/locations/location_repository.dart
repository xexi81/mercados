import 'dart:convert';
import 'package:flutter/services.dart';
import 'location_model.dart';

class LocationsRepository {
  static Future<List<LocationModel>> loadLocations() async {
    final String jsonString = await rootBundle.loadString(
      'assets/data/locations.json',
    );

    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

    final List<dynamic> locationsJson = jsonMap['locations'];

    return locationsJson.map((json) => LocationModel.fromJson(json)).toList();
  }

  static Future<List<LocationModel>> loadLocationsWithMarkets() async {
    final locations = await loadLocations();
    return locations.where((location) => location.hasMarket).toList();
  }

  static Future<List<LocationModel>> loadLocationsByCountry(
    String countryIso,
  ) async {
    final locations = await loadLocations();
    return locations
        .where((location) => location.countryIso == countryIso)
        .toList();
  }

  static Future<List<LocationModel>> loadHeadquarterLocationsByCountry(
    String countryIso,
  ) async {
    final locations = await loadLocations();
    return locations
        .where(
          (location) =>
              location.countryIso == countryIso && location.hasMarket == false,
        )
        .toList();
  }
}
