import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/locations/location_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/data/locations/distance_calculator.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/data/fleet/fleet_status.dart';
import 'package:industrial_app/services/fleet_simulation_service.dart';

class RouteScreen extends StatefulWidget {
  final int fleetId;

  const RouteScreen({super.key, required this.fleetId});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  LocationModel? _currentLocation;
  LocationModel? _headquarterLocation;
  List<LocationModel> _marketLocations = [];
  LocationModel? _selectedMarketDestination;
  bool _isLoading = true;
  Map<String, dynamic>? _fleetData;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get user's current location from fleet data
      final fleetDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('fleet_users')
          .doc(user.uid)
          .get();

      if (fleetDoc.exists) {
        _fleetData = fleetDoc.data();
      }

      // Get user's headquarter
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final String? hqId = userData?['headquarter_id']?.toString();

      // Load all locations
      final locations = await LocationsRepository.loadLocations();

      // Find headquarter location
      if (hqId != null) {
        try {
          _headquarterLocation = locations.firstWhere(
            (l) => l.id.toString() == hqId,
          );
        } catch (_) {}
      }

      // Find current location from fleet data
      if (_fleetData != null) {
        final slots = _fleetData!['slots'] as List<dynamic>? ?? [];
        if (slots.isNotEmpty) {
          // Find the slot that matches the fleetId
          final targetSlot =
              slots.firstWhere(
                    (s) => s['fleetId'] == widget.fleetId,
                    orElse: () => null,
                  )
                  as Map<String, dynamic>?;

          final currentLoc =
              targetSlot?['currentLocation'] as Map<String, dynamic>?;

          if (currentLoc != null) {
            final double lat = (currentLoc['latitude'] as num).toDouble();
            final double lng = (currentLoc['longitude'] as num).toDouble();

            try {
              _currentLocation = locations.firstWhere(
                (l) => l.latitude == lat && l.longitude == lng,
              );
            } catch (_) {
              // Location not found, create dummy
              _currentLocation = LocationModel(
                id: 0,
                city: 'Unknown',
                latitude: lat,
                longitude: lng,
                countryIso: '',
                hasMarket: false,
              );
            }
          }
        }
      }

      // Load market locations (exclude current location)
      _marketLocations = await LocationsRepository.loadLocationsWithMarkets();
      if (_currentLocation != null) {
        _marketLocations.removeWhere((l) => l.id == _currentLocation!.id);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading location data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isAtHeadquarter {
    if (_currentLocation == null || _headquarterLocation == null) return false;
    return _currentLocation!.latitude == _headquarterLocation!.latitude &&
        _currentLocation!.longitude == _headquarterLocation!.longitude;
  }

  String get _currentLocationImagePath {
    if (_currentLocation == null) return 'assets/images/dummy.png';
    if (_isAtHeadquarter) return 'assets/images/sede.png';
    if (_currentLocation!.hasMarket) return 'assets/images/market.png';
    return 'assets/images/dummy.png';
  }

  Future<void> _initiateRoute(LocationModel destination) async {
    if (_currentLocation == null || _fleetData == null) return;

    final double distance = DistanceCalculator.calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      destination.latitude,
      destination.longitude,
    );

    final double fuelCost = distance * 0.1;
    final int roundedCost = fuelCost.ceil();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'INICIAR RUTA',
        description:
            'Origen: ${_currentLocation!.city}\n'
            'Destino: ${destination.city}\n'
            'Distancia: ${distance.toStringAsFixed(1)} km',
        price: roundedCost,
        priceType: UnlockCostType.money,
        onConfirm: () async {
          await _updateFleetRoute(destination, distance, roundedCost);
        },
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(); // Return to previous screen
    }
  }

  Future<void> _updateFleetRoute(
    LocationModel destination,
    double distance,
    int cost,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _fleetData == null)
      throw Exception('Usuario no identificado');

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

      if (!userSnapshot.exists) throw Exception('Usuario no encontrado');

      final userData = userSnapshot.data()!;
      final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;

      if (currentMoney < cost) {
        throw Exception('Dinero insuficiente para el viaje');
      }

      // Update user money
      transaction.update(userDocRef, {'dinero': currentMoney - cost});

      // Update fleet route
      final updatedSlots = List<Map<String, dynamic>>.from(
        _fleetData!['slots'] ?? [],
      );
      if (updatedSlots.isNotEmpty) {
        // Find the slot that matches the current fleetId
        final slotIndex = updatedSlots.indexWhere(
          (s) => s['fleetId'] == widget.fleetId,
        );

        if (slotIndex != -1) {
          updatedSlots[slotIndex]['destinyLocation'] = {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          };
          updatedSlots[slotIndex]['currentLocation'] = {
            'latitude': _currentLocation!.latitude,
            'longitude': _currentLocation!.longitude,
          };
          updatedSlots[slotIndex]['distanceRemaining'] = distance;
          updatedSlots[slotIndex]['status'] = FleetStatus.enMarcha.value;
        }
      }

      transaction.update(fleetDocRef, {
        'slots': updatedSlots,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      });
    });

    // Calculate speed
    double speedKmh = 0.0;
    if (_fleetData != null) {
      final slots = _fleetData!['slots'] as List<dynamic>? ?? [];
      final slot =
          slots.firstWhere(
                (s) => s['fleetId'] == widget.fleetId,
                orElse: () => null,
              )
              as Map<String, dynamic>?;

      if (slot != null) {
        final truckSkills = slot['truckSkills'] as Map<String, dynamic>?;
        final driverSkills = slot['driverSkills'] as Map<String, dynamic>?;
        final truckSpeed = slot['truckSpeed'] as int? ?? 0;

        final baseSpeed =
            (truckSkills?['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0;
        final driverBonus =
            (driverSkills?['speedBonusPercent'] as num?)?.toDouble() ?? 0.0;

        // velocidad = base * (1 + truckSpeed/100) * (1 + driverBonus/100)
        speedKmh = baseSpeed * (1 + truckSpeed / 100) * (1 + driverBonus / 100);
      }
    }

    // Start simulation
    FleetSimulationService().startSimulation(
      widget.fleetId.toString(),
      distance,
      speedKmh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 100, // Espacio extra para la barra inferior del móvil
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentLocationSection(),
                  const SizedBox(height: 24),
                  _buildDestinationsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentLocationSection() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        image: DecorationImage(
          image: AssetImage(_currentLocationImagePath),
          fit: BoxFit.cover,
          onError: (error, stackTrace) {},
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'UBICACIÓN ACTUAL',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _currentLocation?.city ?? 'Ubicación desconocida',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESTINO',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),

        // Headquarters option (if not currently there)
        if (!_isAtHeadquarter && _headquarterLocation != null)
          _buildDestinationCard(
            title: 'Sede',
            location: _headquarterLocation!,
            imagePath: 'assets/images/sede.png',
            onTap: () => _initiateRoute(_headquarterLocation!),
          ),

        const SizedBox(height: 16),

        // Markets option
        _buildMarketDestinationCard(),

        const SizedBox(height: 16),

        // Contracts (placeholder)
        _buildContractsPlaceholder(),
      ],
    );
  }

  Widget _buildDestinationCard({
    required String title,
    required LocationModel location,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        image: DecorationImage(
          image: AssetImage('assets/images/sede.png'),
          fit: BoxFit.cover,
          onError: (error, stackTrace) {
            debugPrint('Error loading background image: $error');
          },
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.4),
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                location.city,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            IndustrialButton(
              label: 'INICIAR RUTA',
              width: double.infinity,
              height: 50,
              gradientTop: Colors.green[400]!,
              gradientBottom: Colors.green[900]!,
              borderColor: Colors.green[700]!,
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketDestinationCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        image: const DecorationImage(
          image: AssetImage('assets/images/routes/market.png'),
          fit: BoxFit.cover,
          onError: null,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.4),
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Mercados',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonFormField<LocationModel>(
                value: _selectedMarketDestination,
                hint: const Text(
                  'Seleccionar mercado',
                  style: TextStyle(color: Colors.white70),
                ),
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                items: _marketLocations
                    .map(
                      (location) => DropdownMenuItem(
                        value: location,
                        child: Text(
                          location.city,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMarketDestination = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            IndustrialButton(
              label: 'INICIAR RUTA',
              width: double.infinity,
              height: 50,
              gradientTop: _selectedMarketDestination != null
                  ? Colors.green[400]!
                  : Colors.grey[400]!,
              gradientBottom: _selectedMarketDestination != null
                  ? Colors.green[900]!
                  : Colors.grey[700]!,
              borderColor: _selectedMarketDestination != null
                  ? Colors.green[700]!
                  : Colors.grey[600]!,
              onPressed: _selectedMarketDestination != null
                  ? () => _initiateRoute(_selectedMarketDestination!)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.assignment,
            color: Colors.white.withOpacity(0.5),
            size: 50,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contratos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Próximamente...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
