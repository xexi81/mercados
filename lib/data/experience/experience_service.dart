import 'dart:convert';
import 'package:flutter/services.dart';
import 'experience_level_model.dart';
import 'experience_account_model.dart';

class ExperienceService {
  /// Calcula la experiencia a sumar por producción (mover m3 al almacén).
  static int calculateProduceXp(double volumeM3, int grade) {
    if (_accountRules == null) return 0;
    final baseXp = _accountRules!.produceXpPerM3[grade.toString()] ?? 0.0;
    return (volumeM3 * baseXp).round();
  }

  static List<ExperienceLevelModel>? _levels;
  static ExperienceAccountModel? _accountRules;

  /// Carga los datos de niveles y reglas de experiencia desde los archivos JSON.
  static Future<void> loadExperienceData() async {
    if (_levels != null && _accountRules != null) return;

    // Cargar niveles
    if (_levels == null) {
      final String levelsResponse = await rootBundle.loadString(
        'assets/data/experience.json',
      );
      final levelsData = json.decode(levelsResponse);
      final List<dynamic> levelsJson = levelsData['experienceLevels'];
      _levels = levelsJson
          .map((json) => ExperienceLevelModel.fromJson(json))
          .toList();
      _levels!.sort((a, b) => a.level.compareTo(b.level));
    }

    // Cargar reglas de cuenta
    if (_accountRules == null) {
      final String rulesResponse = await rootBundle.loadString(
        'assets/data/experience_account.json',
      );
      final rulesData = json.decode(rulesResponse);
      _accountRules = ExperienceAccountModel.fromJson(rulesData);
    }
  }

  /// Calcula la experiencia a sumar por una compra.
  static int calculatePurchaseXp(double volumeM3, int grade) {
    if (_accountRules == null) return 0;
    final baseXp = _accountRules!.purchaseXpPerM3[grade.toString()] ?? 0.0;
    return (volumeM3 * baseXp).round();
  }

  /// Calcula la experiencia a sumar por una venta (normal o retail).
  static int calculateSaleXp(
    double volumeM3,
    int grade, {
    bool isRetail = false,
  }) {
    if (_accountRules == null) return 0;
    final map = isRetail
        ? _accountRules!.retailSaleXpPerM3
        : _accountRules!.saleXpPerM3;
    final baseXp = map[grade.toString()] ?? 0.0;
    return (volumeM3 * baseXp).round();
  }

  /// Calcula la experiencia a sumar por completar un contrato.
  static int calculateContractFulfilledXp(
    double volumeM3,
    int grade, {
    bool onTime = false,
    bool perfectCondition = false,
  }) {
    if (_accountRules == null) return 0;

    final baseXpPerM3 =
        _accountRules!.contractFulfilledXpPerM3[grade.toString()] ?? 0.0;
    double totalXp = volumeM3 * baseXpPerM3;

    if (onTime) {
      totalXp += (totalXp * _accountRules!.onTimeBonusPercent / 100);
    }
    if (perfectCondition) {
      totalXp += (totalXp * _accountRules!.perfectConditionBonusPercent / 100);
    }

    return totalXp.round();
  }

  /// Calcula la penalización de experiencia por fallar un contrato.
  static int calculateContractFailedPenalty(int potentialGainXp) {
    if (_accountRules == null) return 0;

    int penalty = _accountRules!.flatXpLoss;
    penalty += (potentialGainXp * _accountRules!.xpPenaltyPercent / 100)
        .round();

    return penalty;
  }

  /// Devuelve el porcentaje de bonus por completar a tiempo un contrato.
  static int getOnTimeBonusPercent() {
    if (_accountRules == null) return 10; // Default if rules not loaded
    return _accountRules!.onTimeBonusPercent;
  }

  /// Devuelve el XP base por m³ para venta retail por grado.
  static double getRetailSaleXpPerM3(int grade) {
    if (_accountRules == null) return 0.0;
    return _accountRules!.retailSaleXpPerM3[grade.toString()] ?? 0.0;
  }

  /// Calcula el nivel actual basado en la experiencia total.
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
