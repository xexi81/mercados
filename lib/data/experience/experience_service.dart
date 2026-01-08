import 'dart:convert';
import 'package:flutter/services.dart';
import 'experience_level_model.dart';

class ExperienceService {
  static List<ExperienceLevelModel>? _levels;

  /// Carga los niveles de experiencia desde el archivo JSON si no están ya cargados.
  static Future<void> loadExperienceData() async {
    if (_levels != null) return;

    final String response = await rootBundle.loadString(
      'assets/data/experience.json',
    );
    final data = json.decode(response);
    final List<dynamic> levelsJson = data['experienceLevels'];

    _levels = levelsJson
        .map((json) => ExperienceLevelModel.fromJson(json))
        .toList();

    // Asegurarnos de que estén ordenados por nivel (aunque ya deberían estarlo)
    _levels!.sort((a, b) => a.level.compareTo(b.level));
  }

  /// Calcula el nivel actual basado en la experiencia total.
  /// Devuelve el nivel más alto cuya experiencia requerida es menor o igual a la actual.
  static int getLevelFromExperience(int currentExperience) {
    if (_levels == null) {
      throw Exception(
        'Experience data not loaded. Call ExperienceService.loadExperienceData() first.',
      );
    }

    if (currentExperience < 0) return 1;

    // Búsqueda binaria para encontrar el nivel
    int low = 0;
    int high = _levels!.length - 1;
    int resultLevel = 1;

    while (low <= high) {
      int mid = low + (high - low) ~/ 2;
      if (_levels![mid].requiredExperience <= currentExperience) {
        resultLevel = _levels![mid].level;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return resultLevel;
  }

  /// Devuelve el siguiente nivel y la experiencia necesaria para alcanzarlo.
  /// Si es el nivel máximo, devuelve null.
  static ExperienceLevelModel? getNextLevelInfo(int currentLevel) {
    if (_levels == null) {
      throw Exception('Experience data not loaded.');
    }

    if (currentLevel >= _levels!.length) {
      return null;
    }

    return _levels![currentLevel]; // El índice es currentLevel porque level 1 está en índice 0
  }
}
