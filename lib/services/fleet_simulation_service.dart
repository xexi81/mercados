import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:industrial_app/data/experience/experience_service.dart';
import 'package:industrial_app/data/trucks/truck_model.dart';
import 'package:industrial_app/data/drivers/driver_model.dart';

class FleetSimulationService {
  static final FleetSimulationService _instance =
      FleetSimulationService._internal();
  factory FleetSimulationService() => _instance;
  FleetSimulationService._internal();

  // Cache para los modelos de truck y driver
  late List<TruckModel> _trucks;
  late List<DriverModel> _drivers;
  bool _dataLoaded = false;

  /// Carga los datos de trucks y drivers desde los archivos JSON
  Future<void> _loadData() async {
    if (_dataLoaded) return;

    try {
      // Cargar trucks
      final String trucksJsonStr = await rootBundle.loadString(
        'assets/data/trucks.json',
      );
      final Map<String, dynamic> trucksData = json.decode(trucksJsonStr);
      final List trucksJson = trucksData['trucks'] as List;
      _trucks = trucksJson
          .map((e) => TruckModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cargar drivers
      final String driversJsonStr = await rootBundle.loadString(
        'assets/data/drivers.json',
      );
      final Map<String, dynamic> driversData = json.decode(driversJsonStr);
      final List driversJson = driversData['drivers'] as List;
      _drivers = driversJson
          .map((e) => DriverModel.fromJson(e as Map<String, dynamic>))
          .toList();

      _dataLoaded = true;
    } catch (e) {
      debugPrint('Error loading truck/driver data: $e');
    }
  }

  /// Obtiene un truck por su ID
  TruckModel? _getTruckById(int truckId) {
    try {
      return _trucks.firstWhere((t) => t.truckId == truckId);
    } catch (_) {
      return null;
    }
  }

  /// Obtiene un driver por su ID
  DriverModel? _getDriverById(int driverId) {
    try {
      return _drivers.firstWhere((d) => d.driverId == driverId);
    } catch (_) {
      return null;
    }
  }

  /// Calcula la probabilidad de accidente según la fórmula:
  /// accidentChance = truckSkills.accidentRiskPercent - driverSkills.accidentRiskReductionPercent - (driverAccidentReduction * 0.1)
  double _calculateAccidentChance({
    required double truckAccidentRiskPercent,
    required double driverAccidentRiskReductionPercent,
    required double driverAccidentReduction,
  }) {
    return truckAccidentRiskPercent -
        driverAccidentRiskReductionPercent -
        (driverAccidentReduction * 0.1);
  }

  /// Determina si hay un accidente basado en la probabilidad calculada
  bool _hasAccident(double accidentChance) {
    final random = Random().nextInt(101); // 0 a 100 inclusive
    return accidentChance > random;
  }

  /// Inicia la simulación guardando datos iniciales (sin Timer)
  void startSimulation(
    String fleetId,
    double totalDistanceKm,
    double speedKmh,
  ) {
    final totalTimeSeconds =
        (totalDistanceKm / speedKmh) * 3600; // Tiempo total en segundos
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // Guardar en Firestore
    _updateFirestore(fleetId, {
      'startTime': startTime,
      'totalDistanceKm': totalDistanceKm,
      'speedKmh': speedKmh,
      'totalTimeSeconds': totalTimeSeconds,
      'status': 'en marcha',
    });
  }

  /// Actualiza Firestore en el slot correspondiente
  Future<void> _updateFirestore(
    String fleetId,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('fleet_users')
        .doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final fleetData = snapshot.data()!;
      final List<dynamic> slots = List.from(fleetData['slots'] ?? []);

      // Encontrar el slot con el fleetId
      final slotIndex = slots.indexWhere(
        (slot) => slot['fleetId'] == int.parse(fleetId),
      );
      if (slotIndex == -1) return;

      // Actualizar el slot con los nuevos datos
      slots[slotIndex] = {...slots[slotIndex], ...data};

      // Guardar de vuelta
      transaction.update(docRef, {'slots': slots});
    });
  }

  /// Completa el trayecto: evalúa accidente o destino
  Future<void> completeTrip(String fleetId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Cargar datos de trucks y drivers
    await _loadData();

    final docRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('fleet_users')
        .doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final fleetData = snapshot.data()!;
      final List<dynamic> slots = List.from(fleetData['slots'] ?? []);

      // Encontrar el slot con el fleetId
      final slotIndex = slots.indexWhere(
        (slot) => slot['fleetId'] == int.parse(fleetId),
      );
      if (slotIndex == -1) return;

      final slot = slots[slotIndex];
      final totalDistanceKm = slot['totalDistanceKm'] as double? ?? 0;

      // Obtener IDs de truck y driver
      final truckId = slot['truckId'] as int?;
      final driverId = slot['driverId'] as int?;
      final driverAccidentReduction =
          (slot['driverAccidentReduction'] as num?)?.toDouble() ?? 0;

      // Obtener modelos de truck y driver
      final truck = truckId != null ? _getTruckById(truckId) : null;
      final driver = driverId != null ? _getDriverById(driverId) : null;

      // Calcular probabilidad de accidente
      bool hasAccident = false;
      if (truck != null && driver != null) {
        final accidentChance = _calculateAccidentChance(
          truckAccidentRiskPercent: truck.accidentRiskPercent,
          driverAccidentRiskReductionPercent:
              driver.bonuses.accidentRiskReductionPercent,
          driverAccidentReduction: driverAccidentReduction,
        );
        hasAccident = _hasAccident(accidentChance);
      }

      // Determinar el nuevo status
      final newStatus = hasAccident ? 'averiado' : 'en destino';

      // Sumar XP (asumiendo contract fulfilled)
      final xpGained = ExperienceService.calculateContractFulfilledXp(
        totalDistanceKm,
        1,
      ); // Ajustar grade si necesario

      // Actualizar el slot: status, ubicación y limpiar datos de simulación
      slots[slotIndex] = {
        ...slot,
        'status': newStatus,
        'currentLocation': slot['destinyLocation'],
        // Limpiar datos de simulación
        'startTime': null,
        'totalDistanceKm': null,
        'speedKmh': null,
        'totalTimeSeconds': null,
      };

      // Guardar slots
      transaction.update(docRef, {'slots': slots});

      // Sumar XP al usuario
      // transaction.update(userRef, {'experience': FieldValue.increment(xpGained)});
    });

    // TODO: Mover carga al destino si es necesario
  }
}
