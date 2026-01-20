import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/trucks/truck_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/data/materials/container_type.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';

class TruckInformationScreen extends StatefulWidget {
  final int truckId;
  final int fleetId;

  const TruckInformationScreen({
    super.key,
    required this.truckId,
    required this.fleetId,
  });

  @override
  State<TruckInformationScreen> createState() => _TruckInformationScreenState();
}

class _TruckInformationScreenState extends State<TruckInformationScreen> {
  bool _isLoading = true;
  TruckModel? _truck;
  bool _isAtHeadquarter = false;
  int _speedLevel = 0;

  @override
  void initState() {
    super.initState();
    _loadTruckData();
  }

  Future<void> _loadTruckData() async {
    try {
      // Load truck data from JSON
      final String jsonString = await rootBundle.loadString(
        'assets/data/trucks.json',
      );
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final List<dynamic> trucksJson = jsonMap['trucks'];

      final truckData = trucksJson.firstWhere(
        (truck) => truck['truckId'] == widget.truckId,
        orElse: () => null,
      );

      if (truckData != null) {
        _truck = TruckModel.fromJson(truckData);
      }

      // Check if fleet is at headquarter
      _isAtHeadquarter = await _isFleetAtHeadquarter();

      // Load speed level from fleet data
      await _loadSpeedLevel();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading truck data: $e');
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

  Future<void> _loadSpeedLevel() async {
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
        _speedLevel = (fleetSlot['truckSpeed'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading speed level: $e');
    }
  }

  Future<void> _upgradeSpeed() async {
    // Check max level
    if (_speedLevel >= 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Nivel máximo alcanzado!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nextLevel = _speedLevel + 1;
    final cost = nextLevel * 1000000; // 1M per level

    final bool? purchased = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'MEJORA DE VELOCIDAD',
        description:
            'Mejorar a Nivel $nextLevel\n\n'
            'Incremento de velocidad máxima: +1%',
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

            // Update truck speed level
            final fleetData = fleetSnapshot.data()!;
            final slots = List<Map<String, dynamic>>.from(
              fleetData['slots'] ?? [],
            );

            final slotIndex = slots.indexWhere(
              (slot) => slot['fleetId'] == widget.fleetId,
            );
            if (slotIndex != -1) {
              slots[slotIndex]['truckSpeed'] = nextLevel;
              transaction.update(fleetDocRef, {'slots': slots});
            }
          });
        },
      ),
    );

    if (purchased == true && mounted) {
      setState(() {
        _speedLevel = nextLevel;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Velocidad mejorada a Nivel $nextLevel!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _sellTruck() async {
    final sellPrice = _truck!.sellValue;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'VENTA DE CAMIÓN',
        description:
            '¿Estás seguro de que quieres vender ${_truck!.name} por $sellPrice monedas?',
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
              slots[slotIndex]['truckId'] = null;
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
          : _truck == null
          ? const Center(
              child: Text(
                'Camión no encontrado',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Truck Name
                  Text(
                    _truck!.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Truck Image
                  SizedBox(
                    width: 200,
                    height: 120,
                    child: Image.asset(
                      'assets/images/trucks/${widget.truckId}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Truck Characteristics
                  _buildCharacteristicsCard(),

                  const SizedBox(height: 20),

                  // Speed Upgrade Level Card
                  _buildSpeedUpgradeCard(),

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
            'CARACTERÍSTICAS DEL CAMIÓN',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          _buildCharacteristicRow(
            'Velocidad Máxima',
            '${_truck!.maxSpeedKmh} km/h',
            Icons.speed,
          ),

          const SizedBox(height: 12),

          _buildCharacteristicRow(
            'Riesgo de Accidente',
            '${_truck!.accidentRiskPercent}%',
            Icons.warning,
          ),

          const SizedBox(height: 16),

          // Container type compatibility minicards
          _buildContainerCompatibility(),
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

  Widget _buildSpeedUpgradeCard() {
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
              Icon(Icons.speed, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Text(
                'MEJORA DE VELOCIDAD',
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
            label: 'LVL $_speedLevel',
            width: 120,
            height: 40,
            gradientTop: Colors.green[400]!,
            gradientBottom: Colors.green[700]!,
            borderColor: Colors.green[600]!,
            onPressed: _upgradeSpeed,
          ),

          const SizedBox(height: 12),

          Text(
            'Nivel actual de mejora de velocidad',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContainerCompatibility() {
    const containerTypes = [
      ContainerType.bulkSolid,
      ContainerType.bulkLiquid,
      ContainerType.refrigerated,
      ContainerType.standard,
      ContainerType.heavy,
      ContainerType.hazardous,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        containerTypes.length,
        (i) => _TruckMiniCard(
          imagePath: 'assets/images/containers/${containerTypes[i].name}.png',
          showCross: !_truck!.allowedContainers.contains(containerTypes[i]),
          containerType: containerTypes[i],
        ),
      ),
    );
  }

  Widget _buildSellButton() {
    return IndustrialButton(
      label: 'VENDER CAMIÓN',
      width: double.infinity,
      height: 55,
      gradientTop: Colors.red[400]!,
      gradientBottom: Colors.red[800]!,
      borderColor: Colors.red[600]!,
      onPressed: _sellTruck,
    );
  }
}

class _TruckMiniCard extends StatelessWidget {
  final String imagePath;
  final bool showCross;
  final ContainerType containerType;

  const _TruckMiniCard({
    required this.imagePath,
    this.showCross = false,
    required this.containerType,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Container image
                  SizedBox(
                    width: 80,
                    height: 60,
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.inventory_2,
                          color: Colors.white54,
                          size: 30,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Container name
                  Text(
                    containerType.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    _getContainerDescription(containerType),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Compatibility status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: showCross
                          ? Colors.red.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: showCross ? Colors.red : Colors.green,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          showCross ? Icons.close : Icons.check,
                          color: showCross ? Colors.red : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          showCross ? 'NO COMPATIBLE' : 'COMPATIBLE',
                          style: TextStyle(
                            color: showCross ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.12,
        height: MediaQuery.of(context).size.width * 0.08,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[800],
                  child: Icon(
                    Icons.inventory_2,
                    color: Colors.white54,
                    size: 16,
                  ),
                ),
              ),
              if (showCross)
                Image.asset(
                  'assets/images/containers/cruz_roja.png',
                  fit: BoxFit.contain,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getContainerDescription(ContainerType type) {
    switch (type) {
      case ContainerType.bulkSolid:
        return 'Diseñado para transportar materiales sólidos a granel como cereales, minerales y productos granulados.';
      case ContainerType.bulkLiquid:
        return 'Especializado en el transporte de líquidos como petróleo, productos químicos y fluidos industriales.';
      case ContainerType.refrigerated:
        return 'Equipado con sistemas de refrigeración para mantener productos perecederos a temperatura controlada.';
      case ContainerType.standard:
        return 'Contenedor versátil para carga general, productos manufacturados y mercancías empaquetadas.';
      case ContainerType.heavy:
        return 'Reforzado para transportar cargas pesadas como maquinaria, equipos industriales y materiales densos.';
      case ContainerType.hazardous:
        return 'Certificado para el transporte seguro de materiales peligrosos con sistemas de contención especializados.';
    }
  }
}
