import 'dart:convert';
import 'package:flutter/services.dart';
import 'fleet_level_model.dart';

class FleetLevelRepository {
  static Future<List<FleetLevelModel>> loadFleetLevels() async {
    final String jsonStr = await rootBundle.loadString(
      'assets/data/fleet_level.json',
    );
    final List<dynamic> jsonList = json.decode(jsonStr);
    return jsonList.map((json) => FleetLevelModel.fromJson(json)).toList();
  }

  /// Obtiene el modelo de nivel específico por número de nivel
  static Future<FleetLevelModel?> getFleetLevel(int nivel) async {
    final levels = await loadFleetLevels();
    try {
      return levels.firstWhere((level) => level.nivel == nivel);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene el coste de mejora a un nivel específico
  static Future<int?> getUpgradeCost(int nivel) async {
    final level = await getFleetLevel(nivel);
    return level?.coste;
  }

  /// Obtiene el bonus de capacidad de un nivel específico
  static Future<int?> getCapacityBonus(int nivel) async {
    final level = await getFleetLevel(nivel);
    return level?.capacidadBonus;
  }

  /// Obtiene todos los niveles hasta un máximo especificado
  static Future<List<FleetLevelModel>> getFleetLevelsUpTo(int maxNivel) async {
    final levels = await loadFleetLevels();
    return levels.where((level) => level.nivel <= maxNivel).toList();
  }

  /// Obtiene el costo total acumulado para llegar a un nivel específico
  static Future<int> getTotalCostToLevel(int targetNivel) async {
    final levels = await getFleetLevelsUpTo(targetNivel);
    return levels.fold<int>(0, (sum, level) => sum + level.coste);
  }
}
