import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/data/fleet/fleet_model.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';

class FleetService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> purchaseFleet(FleetModel fleet) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final userDocRef = _firestore.collection('usuarios').doc(user.uid);
    final fleetDocRef = _firestore
        .collection('usuarios')
        .doc(user.uid)
        .collection('fleet_users')
        .doc(user.uid);

    return _firestore.runTransaction((transaction) async {
      // 1. Perform all reads first (Firestore transactions requirement)
      final userSnapshot = await transaction.get(userDocRef);
      final fleetSnapshot = await transaction.get(fleetDocRef);

      // 2. Validate user and balance
      if (!userSnapshot.exists) {
        throw Exception('Documento de usuario no encontrado');
      }

      final userData = userSnapshot.data() as Map<String, dynamic>;
      final int dinero = userData['dinero'] ?? 0;
      final int gemas = userData['gemas'] ?? 0;

      final cost = fleet.unlockCost;
      final bool isFree = cost.type == UnlockCostType.free;

      // 3. Execute writes
      if (!isFree) {
        if (cost.type == UnlockCostType.money) {
          if (dinero < cost.amount) {
            throw Exception('No tienes suficiente dinero');
          }
          transaction.update(userDocRef, {'dinero': dinero - cost.amount});
        } else if (cost.type == UnlockCostType.gems) {
          if (gemas < cost.amount) {
            throw Exception('No tienes suficientes gemas');
          }
          transaction.update(userDocRef, {'gemas': gemas - cost.amount});
        }
      }

      final String? headquarterId = userData['headquarter_id']?.toString();
      Map<String, double>? locationData;

      if (headquarterId != null) {
        try {
          // Fetch location data from locations.json
          final String locationsJsonString = await rootBundle.loadString(
            'assets/data/locations.json',
          );
          final Map<String, dynamic> locationsData = json.decode(
            locationsJsonString,
          );
          final List<dynamic> locations = locationsData['locations'];

          final hq = locations.firstWhere(
            (l) => l['id'].toString() == headquarterId,
            orElse: () => null,
          );

          if (hq != null) {
            locationData = {
              'latitude': (hq['latitude'] as num).toDouble(),
              'longitude': (hq['longitude'] as num).toDouble(),
            };
          }
        } catch (e) {
          debugPrint('Error loading location data: $e');
        }
      }

      final newSlot = {
        'fleetId': fleet.fleetId,
        'truckId': null,
        'driverId': null,
        'containerId': null,
        'fleetLevel': 0,
        'quantity': 0,
        'truckSkills': {},
        'driverSkills': {},
        'containerSkills': {},
        'truckLoad': {},
        'currentLocation': locationData ?? {'latitude': 0.0, 'longitude': 0.0},
        'destinyLocation': {'latitude': 0.0, 'longitude': 0.0},
        'status': 'en destino',
      };

      if (!fleetSnapshot.exists) {
        transaction.set(fleetDocRef, {
          'slots': [newSlot],
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(fleetDocRef, {
          'slots': FieldValue.arrayUnion([newSlot]),
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
