import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/containers/container_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';

class ContainerInformationScreen extends StatefulWidget {
  final int containerId;
  final int fleetId;

  const ContainerInformationScreen({
    super.key,
    required this.containerId,
    required this.fleetId,
  });

  @override
  State<ContainerInformationScreen> createState() =>
      _ContainerInformationScreenState();
}

class _ContainerInformationScreenState
    extends State<ContainerInformationScreen> {
  bool _isLoading = true;
  ContainerModel? _container;
  bool _isAtHeadquarter = false;
  int _capacityUpgradeLevel = 0;

  @override
  void initState() {
    super.initState();
    _loadContainerData();
  }

  Future<void> _loadContainerData() async {
    try {
      // Load container data from JSON
      final String jsonString = await rootBundle.loadString(
        'assets/data/container.json',
      );
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final List<dynamic> containersJson = jsonMap['containers'];

      final containerData = containersJson.firstWhere(
        (container) => container['containerId'] == widget.containerId,
        orElse: () => null,
      );

      if (containerData != null) {
        _container = ContainerModel.fromJson(containerData);
      }

      // Check if fleet is at headquarter
      _isAtHeadquarter = await _isFleetAtHeadquarter();

      // Load capacity upgrade level from fleet data
      await _loadCapacityUpgradeLevel();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading container data: $e');
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
      final truckLoad = fleetSlot['truckLoad'];
      final bool isLoadEmpty =
          truckLoad == null ||
          truckLoad == 0 ||
          truckLoad == '' ||
          (truckLoad is List && truckLoad.isEmpty) ||
          (truckLoad is Map && truckLoad.isEmpty);

      if (status == 'en destino' && isLoadEmpty) {
        if (currentLocation is String) {
          return currentLocation == hqId;
        } else if (currentLocation is Map) {
          final double fleetLat = (currentLocation['latitude'] as num)
              .toDouble();
          final double fleetLng = (currentLocation['longitude'] as num)
              .toDouble();

          final locations = await LocationsRepository.loadLocations();
          final matchingLocations = locations.where(
            (l) =>
                (l.latitude - fleetLat).abs() < 0.0001 &&
                (l.longitude - fleetLng).abs() < 0.0001,
          );
          if (matchingLocations.isNotEmpty) {
            final currentLoc = matchingLocations.first;
            return currentLoc.id.toString() == hqId;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking headquarters status: $e');
      return false;
    }
  }

  Future<void> _loadCapacityUpgradeLevel() async {
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
        _capacityUpgradeLevel =
            (fleetSlot['containerCapacityUpgrade'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading capacity upgrade level: $e');
    }
  }

  Future<void> _upgradeCapacity() async {
    // Check max level
    if (_capacityUpgradeLevel >= 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Nivel máximo alcanzado!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nextLevel = _capacityUpgradeLevel + 1;
    final cost = 1000000; // 1M per level
    final capacityBonus = nextLevel * 10; // 10m3 per level

    final bool? purchased = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'MEJORA DE CAPACIDAD',
        description:
            'Mejorar a Nivel $nextLevel\n\n'
            'Aumento de capacidad: +${capacityBonus.toStringAsFixed(0)} m³',
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

            // Update container capacity upgrade level
            final fleetData = fleetSnapshot.data()!;
            final slots = List<Map<String, dynamic>>.from(
              fleetData['slots'] ?? [],
            );

            final slotIndex = slots.indexWhere(
              (slot) => slot['fleetId'] == widget.fleetId,
            );
            if (slotIndex != -1) {
              slots[slotIndex]['containerCapacityUpgrade'] = nextLevel;
              transaction.update(fleetDocRef, {'slots': slots});
            }
          });
        },
      ),
    );

    if (purchased == true && mounted) {
      setState(() {
        _capacityUpgradeLevel = nextLevel;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Capacidad mejorada a Nivel $nextLevel!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _sellContainer() async {
    final sellPrice = _container!.sellValue;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'VENTA DE CONTENEDOR',
        description:
            '¿Estás seguro de que quieres vender ${_container!.name} por $sellPrice monedas?',
        price: sellPrice,
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

            final userData = userSnapshot.data()!;
            final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;

            final fleetData = fleetSnapshot.data()!;
            final slots = List<Map<String, dynamic>>.from(
              fleetData['slots'] ?? [],
            );

            final slotIndex = slots.indexWhere(
              (slot) => slot['fleetId'] == widget.fleetId,
            );
            if (slotIndex != -1) {
              slots[slotIndex]['containerId'] = null;
              transaction.update(fleetDocRef, {'slots': slots});
              transaction.update(userDocRef, {
                'dinero': currentMoney + sellPrice,
              });
            }
          });
        },
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _container == null
          ? const Center(
              child: Text(
                'Contenedor no encontrado',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Container Name
                  Text(
                    _container!.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Container Image
                  SizedBox(
                    width: 200,
                    height: 120,
                    child: Image.asset(
                      'assets/images/containers/${widget.containerId}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.inventory,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Container Characteristics
                  _buildCharacteristicsCard(),

                  const SizedBox(height: 20),

                  // Capacity Upgrade Card
                  _buildCapacityUpgradeCard(),

                  const SizedBox(height: 30),

                  // Sell Button (only if at headquarter)
                  if (_isAtHeadquarter) _buildSellButton(),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildCharacteristicsCard() {
    final totalCapacity = _container!.capacityM3 + (_capacityUpgradeLevel * 10);

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
            'CARACTERÍSTICAS DEL CONTENEDOR',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          _buildCharacteristicRow(
            'Capacidad Total',
            '${totalCapacity.toStringAsFixed(1)} m³',
            Icons.inventory,
          ),

          const SizedBox(height: 12),

          _buildCharacteristicRow(
            'Tipo de Contenedor',
            _container!.type.displayName,
            Icons.category,
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

  Widget _buildCapacityUpgradeCard() {
    final currentBonus = _capacityUpgradeLevel * 10;
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
              Icon(Icons.upgrade, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Text(
                'MEJORA DE CAPACIDAD',
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
            label: 'LVL $_capacityUpgradeLevel',
            width: 120,
            height: 40,
            gradientTop: Colors.green[400]!,
            gradientBottom: Colors.green[700]!,
            borderColor: Colors.green[600]!,
            onPressed: _upgradeCapacity,
          ),

          const SizedBox(height: 12),

          Text(
            'Capacidad extra: +${currentBonus.toStringAsFixed(0)} m³',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSellButton() {
    return IndustrialButton(
      label: 'VENDER CONTENEDOR',
      width: double.infinity,
      height: 55,
      gradientTop: Colors.red[400]!,
      gradientBottom: Colors.red[800]!,
      borderColor: Colors.red[600]!,
      onPressed: _sellContainer,
    );
  }
}
