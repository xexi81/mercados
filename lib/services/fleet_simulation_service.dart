import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/data/experience/experience_service.dart';

class FleetSimulationService {
  static final FleetSimulationService _instance =
      FleetSimulationService._internal();
  factory FleetSimulationService() => _instance;
  FleetSimulationService._internal();

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

  /// Completa el trayecto: mover carga, sumar XP, etc.
  Future<void> completeTrip(String fleetId) async {
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

      final slot = slots[slotIndex];
      final totalDistanceKm = slot['totalDistanceKm'] as double? ?? 0;

      // Sumar XP (asumiendo contract fulfilled)
      final xpGained = ExperienceService.calculateContractFulfilledXp(
        totalDistanceKm,
        1,
      ); // Ajustar grade si necesario

      // Actualizar el slot: status, ubicación y limpiar datos de simulación
      slots[slotIndex] = {
        ...slot,
        'status': 'en destino',
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
