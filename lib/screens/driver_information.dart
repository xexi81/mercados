import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/drivers/driver_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';

class DriverInformationScreen extends StatefulWidget {
  final int driverId;
  final int fleetId;

  const DriverInformationScreen({
    super.key,
    required this.driverId,
    required this.fleetId,
  });

  @override
  State<DriverInformationScreen> createState() =>
      _DriverInformationScreenState();
}

class _DriverInformationScreenState extends State<DriverInformationScreen> {
  bool _isLoading = true;
  DriverModel? _driver;
  bool _isAtHeadquarter = false;
  int _accidentReductionLevel = 0;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    try {
      // Load driver data from JSON
      final String jsonString = await rootBundle.loadString(
        'assets/data/drivers.json',
      );
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final List<dynamic> driversJson = jsonMap['drivers'];

      final driverData = driversJson.firstWhere(
        (driver) => driver['driverId'] == widget.driverId,
        orElse: () => null,
      );

      if (driverData != null) {
        _driver = DriverModel.fromJson(driverData);
      }

      // Check if fleet is at headquarter
      _isAtHeadquarter = await _isFleetAtHeadquarter();

      // Load accident reduction level from fleet data
      await _loadAccidentReductionLevel();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading driver data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _isFleetAtHeadquarter() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Get user's headquarter_id
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final String? hqId = userData?['headquarter_id']?.toString();

      if (hqId == null) return false;

      // Get headquarter coordinates from locations
      final locations = await LocationsRepository.loadLocations();
      final headquarter = locations.firstWhere(
        (l) => l.id.toString() == hqId,
        orElse: () => throw Exception('Headquarter location not found'),
      );

      // Get fleet current location and status
      final fleetDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('fleet_users')
          .doc(user.uid)
          .get();

      if (!fleetDoc.exists) return false;

      final fleetData = fleetDoc.data()!;
      final slots = fleetData['slots'] as List<dynamic>? ?? [];

      // Find the specific fleet slot
      final fleetSlot = slots.firstWhere(
        (slot) => slot['fleetId'] == widget.fleetId,
        orElse: () => null,
      );

      if (fleetSlot == null) return false;

      final currentLocation = fleetSlot['currentLocation'];
      final status = fleetSlot['status'];

      // Check if at headquarters
      if (currentLocation != null && status == 'en destino') {
        final double fleetLat = (currentLocation['latitude'] as num).toDouble();
        final double fleetLng = (currentLocation['longitude'] as num)
            .toDouble();

        return fleetLat == headquarter.latitude &&
            fleetLng == headquarter.longitude;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking headquarters status: $e');
      return false;
    }
  }

  Future<void> _loadAccidentReductionLevel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final fleetDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('fleet_users')
          .doc(user.uid)
          .get();

      if (!fleetDoc.exists) return;

      final fleetData = fleetDoc.data()!;
      final slots = fleetData['slots'] as List<dynamic>? ?? [];

      final fleetSlot = slots.firstWhere(
        (slot) => slot['fleetId'] == widget.fleetId,
        orElse: () => null,
      );

      if (fleetSlot != null) {
        _accidentReductionLevel =
            (fleetSlot['driverAccidentReduction'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading accident reduction level: $e');
    }
  }

  Future<void> _upgradeAccidentReduction() async {
    // Check max level
    if (_accidentReductionLevel >= 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Nivel máximo alcanzado!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nextLevel = _accidentReductionLevel + 1;
    final cost = 1000000; // 1M per level
    final reductionBonus = nextLevel * 0.1; // 0.1% per level

    final bool? purchased = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'MEJORA ANTI-ACCIDENTES',
        description:
            'Mejorar a Nivel $nextLevel\n\n'
            'Reducción de riesgo: ${reductionBonus.toStringAsFixed(1)}%',
        price: cost,
        priceType: UnlockCostType.money,
        onConfirm: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) throw Exception('Usuario no identificado');

          final userDocRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid);
          final fleetDocRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .collection('fleet_users')
              .doc(user.uid);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final userSnapshot = await transaction.get(userDocRef);
            final fleetSnapshot = await transaction.get(fleetDocRef);

            if (!userSnapshot.exists) throw Exception('Usuario no encontrado');
            if (!fleetSnapshot.exists)
              throw Exception('Datos de flota no encontrados');

            // Check funds
            final userData = userSnapshot.data()!;
            final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;

            if (currentMoney < cost) {
              throw Exception('Dinero insuficiente');
            }

            // Update money
            transaction.update(userDocRef, {'dinero': currentMoney - cost});

            // Update driver accident reduction level
            final fleetData = fleetSnapshot.data()!;
            final slots = List<Map<String, dynamic>>.from(
              fleetData['slots'] ?? [],
            );

            final slotIndex = slots.indexWhere(
              (slot) => slot['fleetId'] == widget.fleetId,
            );
            if (slotIndex != -1) {
              slots[slotIndex]['driverAccidentReduction'] = nextLevel;
              transaction.update(fleetDocRef, {'slots': slots});
            }
          });
        },
      ),
    );

    if (purchased == true && mounted) {
      setState(() {
        _accidentReductionLevel = nextLevel;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Mejora anti-accidentes a Nivel $nextLevel!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _sellDriver() {
    // Placeholder for sell driver functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Despedir Conductor'),
        content: Text(
          'Funcionalidad de despido por implementar.\n'
          'El conductor ${_driver?.name ?? "Desconocido"} será despedido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _driver == null
          ? const Center(
              child: Text(
                'Conductor no encontrado',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Driver Name
                  Text(
                    _driver!.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Driver Image
                  SizedBox(
                    width: 200,
                    height: 120,
                    child: Image.asset(
                      'assets/images/drivers/${widget.driverId}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.person,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Driver Characteristics
                  _buildCharacteristicsCard(),

                  const SizedBox(height: 20),

                  // Accident Reduction Upgrade Card
                  _buildAccidentReductionUpgradeCard(),

                  const SizedBox(height: 30),

                  // Fire Button (only if at headquarter)
                  if (_isAtHeadquarter) _buildFireButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildCharacteristicsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CARACTERÍSTICAS DEL CONDUCTOR',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          _buildCharacteristicRow(
            'Bonificación de Velocidad',
            '${_driver!.bonuses.speedBonusPercent}%',
            Icons.speed,
          ),

          const SizedBox(height: 12),

          _buildCharacteristicRow(
            'Reducción Riesgo Accidente',
            '${_driver!.bonuses.accidentRiskReductionPercent}%',
            Icons.shield,
          ),
        ],
      ),
    );
  }

  Widget _buildCharacteristicRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAccidentReductionUpgradeCard() {
    final currentReduction = _accidentReductionLevel * 0.1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Text(
                'MEJORA ANTI-ACCIDENTES',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          IndustrialButton(
            label: 'LVL $_accidentReductionLevel',
            width: 120,
            height: 40,
            gradientTop: Colors.green[400]!,
            gradientBottom: Colors.green[700]!,
            borderColor: Colors.green[600]!,
            onPressed: _upgradeAccidentReduction,
          ),

          const SizedBox(height: 12),

          Text(
            'Reducción actual: ${currentReduction.toStringAsFixed(1)}%',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFireButton() {
    return IndustrialButton(
      label: 'DESPEDIR CONDUCTOR',
      width: double.infinity,
      height: 55,
      gradientTop: Colors.red[400]!,
      gradientBottom: Colors.red[800]!,
      borderColor: Colors.red[600]!,
      onPressed: _sellDriver,
    );
  }
}
