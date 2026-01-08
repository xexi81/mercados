import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/widgets/headquarter_selection_dialog.dart';
import 'package:industrial_app/widgets/parking_fleet_card.dart';
import 'package:industrial_app/data/fleet/fleet_repository.dart';
import 'package:industrial_app/data/fleet/fleet_model.dart';
import 'package:industrial_app/data/experience/experience_service.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'dart:async';

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({super.key});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  List<FleetModel> _fleetConfigs = [];
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final fleets = await FleetRepository.loadFleets();
    if (mounted) {
      setState(() {
        _fleetConfigs = fleets;
        _isDataLoaded = true;
      });
      _checkHeadquarter();
    }
  }

  Future<void> _checkHeadquarter() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final headquarter = data?['headquarter'];

        if (headquarter == null || (headquarter as String).isEmpty) {
          _showSelectionDialog();
        }
      }
    } catch (e) {
      debugPrint('Error checking headquarter: $e');
    }
  }

  void _showSelectionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const HeadquarterSelectionDialog(),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Sede configurada correctamente!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (!_isDataLoaded) {
      return const Scaffold(
        appBar: CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          final int experience = userData?['experience'] ?? 0;
          final int level = ExperienceService.getLevelFromExperience(
            experience,
          );

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('fleet')
                .doc(user.uid)
                .snapshots(),
            builder: (context, fleetSnapshot) {
              Map<String, dynamic> fleetMap = {};
              if (fleetSnapshot.hasData && fleetSnapshot.data!.exists) {
                fleetMap =
                    fleetSnapshot.data!.data() as Map<String, dynamic>? ?? {};
              }

              // The user said: "partiremos de la colección fleet de firestore para el documento con id igual al id del usuario"
              // "esta pantalla siempre tendrá 20 cards"
              return GridView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 80, // Added significant bottom padding
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  crossAxisSpacing: 0,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.0,
                ),
                itemCount: 20,
                itemBuilder: (context, index) {
                  final fleetId = index + 1;
                  final config = _fleetConfigs.firstWhere(
                    (f) => f.fleetId == fleetId,
                    orElse: () => FleetModel(
                      fleetId: fleetId,
                      name: 'Unknown',
                      requiredLevel: 999,
                      unlockCost: _fleetConfigs.first.unlockCost, // Fallback
                      unlockedByDefault: false,
                    ),
                  );

                  // Firestore data might use string keys
                  final Map<String, dynamic>? cardData =
                      fleetMap['$fleetId'] ?? fleetMap[fleetId.toString()];

                  return ParkingFleetCard(
                    fleetId: fleetId,
                    fleetConfig: config,
                    firestoreData: cardData,
                    userLevel: level,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
