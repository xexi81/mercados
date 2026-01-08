import 'dart:convert';
import 'package:flutter/services.dart';
import 'country_model.dart';

class CountryRepository {
  Future<List<CountryModel>> loadCountries() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/countries.json',
      );
      final data = await json.decode(response);
      final List<dynamic> countriesJson = data['countries'];

      return countriesJson.map((json) => CountryModel.fromJson(json)).toList();
    } catch (e) {
      print('Error loading countries: $e');
      return [];
    }
  }

  Future<CountryModel?> getCountryByCode(String code) async {
    final countries = await loadCountries();
    try {
      return countries.firstWhere((country) => country.code == code);
    } catch (e) {
      return null;
    }
  }
}
