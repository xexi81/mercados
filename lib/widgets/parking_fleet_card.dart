import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/fleet/fleet_model.dart';
import 'package:industrial_app/data/locations/location_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/data/locations/distance_calculator.dart';

import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/data/fleet/fleet_status.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/data/fleet/fleet_service.dart';
import 'package:industrial_app/data/fleet_level/fleet_level.dart';
import 'package:industrial_app/services/fleet_simulation_service.dart';

import 'package:industrial_app/screens/buy_truck.dart';
import 'package:industrial_app/screens/buy_driver.dart';
import 'package:industrial_app/screens/buy_container.dart';
import 'package:industrial_app/screens/container_information.dart';

import 'package:industrial_app/screens/route.dart';
import 'package:industrial_app/screens/load_manager.dart';
import 'package:industrial_app/screens/truck_information.dart';
import 'package:industrial_app/screens/driver_information.dart';

class ParkingFleetCard extends StatelessWidget {
  final int fleetId;
  final FleetModel? fleetConfig;
  final Map<String, dynamic>? firestoreData;
  final int userLevel;
  final double? hqLatitude;
  final double? hqLongitude;
  final List<LocationModel>? locations;

  final String? locationName;

  const ParkingFleetCard({
    super.key,
    required this.fleetId,
    this.fleetConfig,
    this.firestoreData,
    required this.userLevel,
    this.hqLatitude,
    this.hqLongitude,
    this.locations,
    this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    // If we have data in Firestore, it's occupied (to be refined later)
    final bool isOccupied = firestoreData != null && firestoreData!.isNotEmpty;

    // Check if it's at headquarters
    bool isAtHQ = false;
    bool isAtMarket = false;
    if (isOccupied && hqLatitude != null && hqLongitude != null) {
      final currentLocation = firestoreData!['currentLocation'];
      final status = firestoreData!['status'];
      if (currentLocation != null && status == 'en destino') {
        final double fleetLat = (currentLocation['latitude'] as num).toDouble();
        final double fleetLng = (currentLocation['longitude'] as num)
            .toDouble();

        // Check if at headquarters
        if (fleetLat == hqLatitude && fleetLng == hqLongitude) {
          isAtHQ = true;
        } else {
          // Check if at market
          if (locations != null) {
            for (final location in locations!) {
              if (location.hasMarket) {
                if (fleetLat == location.latitude &&
                    fleetLng == location.longitude) {
                  isAtMarket = true;
                  break;
                }
              }
            }
          }
        }
      }
    }

    // Check if it's unlocked by level
    final int requiredLevel = fleetConfig?.requiredLevel ?? 0;
    final bool isLocked = userLevel < requiredLevel;

    const double radius = 12.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          radius - 2,
        ), // Adjust for border width
        child: Stack(
          children: [
            // Background Image logic
            if (isOccupied)
              if (firestoreData!['status'] == 'averiado')
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.4,
                    child: Image.asset(
                      'assets/images/parking/parking_accident.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else if (firestoreData!['status'] == 'en marcha')
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.4,
                    child: Image.asset(
                      'assets/images/parking/parking_onroad.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else if (isAtHQ)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.4,
                    child: Image.asset(
                      'assets/images/parking/parking_sede.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else if (isAtMarket)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.4,
                    child: Image.asset(
                      'assets/images/parking/parking_market.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                const SizedBox.shrink() // Empty background for other locations
            else
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.4,
                  child: Image.asset(
                    isLocked
                        ? 'assets/images/parking/no_available.png'
                        : 'assets/images/parking/no_info.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.9),
                  ),
                ),
              ),

            if (isLocked) _buildLockedContent(context, requiredLevel),
            if (isOccupied) _buildOccupiedContent(context, isAtHQ, isAtMarket),
            if (!isLocked && !isOccupied) _buildAvailableContent(context),

            // Fleet ID and Level indicators
          ],
        ),
      ),
    );
  }

  Widget _buildLockedContent(BuildContext context, int level) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5), // Same darkened background
        ),
        child: Text(
          'LVL $level',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildOccupiedContent(
    BuildContext context,
    bool isAtHQ,
    bool isAtMarket,
  ) {
    // Show content if occupied, regardless of location (isAtHQ logic logic handled separately for bg)
    // But we need to check status for specific buttons
    final status = firestoreData?['status'];
    final truckId = firestoreData?['truckId'];
    final driverId = firestoreData?['driverId'];
    final containerId = firestoreData?['containerId'];

    // Action buttons show when NOT 'en destino' AND NOT 'en marcha' OR when 'en destino' but all components are assigned
    final bool showActionButtons =
        (status != 'en destino' && status != 'en marcha') ||
        (status == 'en destino' &&
            truckId != null &&
            truckId.toString().trim().isNotEmpty &&
            driverId != null &&
            driverId.toString().trim().isNotEmpty &&
            containerId != null &&
            containerId.toString().trim().isNotEmpty);

    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;

              // Medidas relativas: cada fila ocupa ~26% del alto
              final double itemH = h * 0.26;
              final double itemW = itemH * (85 / 48);
              final double gap = h * 0.04; // Espacio entre filas (4%)

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.03, // 3% de padding lateral
                  vertical: h * 0.02, // 2% de padding vertical
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLevelButton(context, itemW, itemH),
                    SizedBox(height: gap),
                    _buildMiniCards(context, itemW, itemH),
                    SizedBox(height: gap),
                    // Show route progress if en marcha, otherwise show route/load buttons
                    if (status == 'en marcha')
                      _buildRouteProgressInline(context)
                    else if (status == 'averiado')
                      _buildRestartButton(context, itemW, itemH)
                    else if (showActionButtons)
                      Row(
                        children: [
                          _buildBottomButton(
                            context: context,
                            assetPath: 'assets/images/parking/route.png',
                            width: itemW,
                            height: itemH,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      RouteScreen(fleetId: fleetId),
                                ),
                              );
                            },
                          ),
                          SizedBox(width: w * 0.02),
                          _buildBottomButton(
                            context: context,
                            assetPath: 'assets/images/parking/load.png',
                            width: itemW,
                            height: itemH,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      LoadManagerScreen(fleetId: fleetId),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              );
            },
          ),
        ),
        // Display location name if provided and status is 'en destino'
        if (locationName != null && status == 'en destino')
          Positioned(
            top: 6,
            right: 10,
            child: Text(
              locationName!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black.withOpacity(0.8),
                  ),
                ],
              ),
            ),
          ),
        // Display estimated time when status is 'en marcha'
        if (status == 'en marcha') _buildEstimatedTimeTopRight(context),
        // Display fleet status
        _buildFleetStatusTopCenter(context),
      ],
    );
  }

  Widget _buildLevelButton(BuildContext context, double width, double height) {
    return GestureDetector(
      onTap: () => _handleFleetLevelUpgrade(context),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(height * 0.15),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'LVL ${firestoreData?['fleetLevel'] ?? 0}',
            style: TextStyle(
              color: Colors.white,
              fontSize: height * 0.3,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleFleetLevelUpgrade(BuildContext context) async {
    final currentLevel = (firestoreData?['fleetLevel'] as int?) ?? 0;
    final nextLevel = currentLevel + 1;

    try {
      // Obtener información del siguiente nivel
      final nextLevelData = await FleetLevelRepository.getFleetLevel(nextLevel);
      if (nextLevelData == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Has alcanzado el nivel máximo'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final upgradeCost = nextLevelData.coste;

      if (context.mounted) {
        final bool? success = await showDialog<bool>(
          context: context,
          builder: (context) => GenericPurchaseDialog(
            title: 'MEJORAR FLOTA',
            description:
                '¿Deseas mejorar la flota al nivel $nextLevel?\n\nAumento de capacidad: +100%',
            price: upgradeCost,
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

              await FirebaseFirestore.instance.runTransaction((
                transaction,
              ) async {
                final userSnapshot = await transaction.get(userDocRef);
                final fleetSnapshot = await transaction.get(fleetDocRef);

                if (!userSnapshot.exists)
                  throw Exception('Usuario no encontrado');
                if (!fleetSnapshot.exists)
                  throw Exception('Datos de flota no encontrados');

                // Verificar fondos
                final userData = userSnapshot.data()!;
                final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;

                if (currentMoney < upgradeCost) {
                  throw Exception('Dinero insuficiente');
                }

                // Actualizar dinero
                transaction.update(userDocRef, {
                  'dinero': currentMoney - upgradeCost,
                });

                // Actualizar nivel de flota
                final fleetData = fleetSnapshot.data()!;
                List<dynamic> slots = List.from(fleetData['slots'] ?? []);

                final slotIndex = slots.indexWhere(
                  (s) => s['fleetId'] == fleetId,
                );
                if (slotIndex != -1) {
                  Map<String, dynamic> updatedSlot = Map<String, dynamic>.from(
                    slots[slotIndex],
                  );
                  updatedSlot['fleetLevel'] = nextLevel;
                  slots[slotIndex] = updatedSlot;

                  transaction.update(fleetDocRef, {'slots': slots});
                }
              });
            },
          ),
        );

        if (success == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Flota mejorada al nivel $nextLevel'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBottomButton({
    required BuildContext context,
    String? assetPath,
    Widget? child,
    required double width,
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(height * 0.15),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height * 0.12),
          child: child ?? Image.asset(assetPath!, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildRestartButton(
    BuildContext context,
    double width,
    double height,
  ) {
    return _buildBottomButton(
      context: context,
      child: Icon(Icons.play_arrow, color: Colors.white, size: height * 0.6),
      width: width,
      height: height,
      onTap: () => _showRestartDialog(context),
    );
  }

  Future<int?> _getTruckSellValue(int truckId) async {
    final trucksJson = await rootBundle.loadString('assets/data/trucks.json');
    final trucksData = json.decode(trucksJson);
    final truckJson = (trucksData['trucks'] as List).firstWhere(
      (t) => t['truckId'] == truckId,
      orElse: () => null,
    );
    return truckJson?['sellValue'] as int?;
  }

  Future<void> _showRestartDialog(BuildContext context) async {
    final truckId = firestoreData?['truckId'];
    if (truckId == null) return;

    final truckSellValue = await _getTruckSellValue(truckId);
    if (truckSellValue == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fleetDocRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('fleet_users')
        .doc(user.uid);

    int cost = 0;
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final fleetSnapshot = await transaction.get(fleetDocRef);
      if (!fleetSnapshot.exists) return;

      final fleetData = fleetSnapshot.data()!;
      final slots = List<Map<String, dynamic>>.from(fleetData['slots'] ?? []);
      final slotIndex = slots.indexWhere((s) => s['fleetId'] == fleetId);
      if (slotIndex == -1) return;

      final slot = slots[slotIndex];
      final existingCost = slot['accidentCost'] as int? ?? 0;

      if (existingCost > 0) {
        cost = existingCost;
      } else {
        final random = Random();
        cost = (truckSellValue * random.nextDouble() * 0.2).round();
        slots[slotIndex]['accidentCost'] = cost;
        transaction.update(fleetDocRef, {'slots': slots});
      }
    });

    if (cost == 0) return; // Something went wrong

    // Assume load data is in firestoreData
    final loadAmount = firestoreData?['loadAmount'] as int? ?? 0;
    final loadType = firestoreData?['loadType'] as String? ?? 'STANDARD';

    final random = Random();
    final lossPercent = loadType == 'GEMS'
        ? random.nextDouble()
        : random.nextDouble() * 0.2;
    final lossAmount = (loadAmount * lossPercent).round();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'REINICIAR FLOTA',
        description:
            '¿Deseas reiniciar la flota averiada?\n\nCosto de reparación: $cost\nPérdida de carga: $lossAmount ${loadType == 'GEMS' ? 'gemas' : 'unidades'}',
        price: cost,
        priceType: UnlockCostType.money,
        onConfirm: () async => _restartFleet(cost, lossAmount, loadType),
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Flota reiniciada')));
    }
  }

  Future<void> _restartFleet(int cost, int lossAmount, String loadType) async {
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
      if (!fleetSnapshot.exists) throw Exception('Flota no encontrada');

      final userData = userSnapshot.data()!;
      final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;
      if (currentMoney < cost) throw Exception('Dinero insuficiente');

      final fleetData = fleetSnapshot.data()!;
      final slots = List<Map<String, dynamic>>.from(fleetData['slots'] ?? []);
      final slotIndex = slots.indexWhere((s) => s['fleetId'] == fleetId);
      if (slotIndex == -1) throw Exception('Slot no encontrado');

      final slot = slots[slotIndex];
      final currentLoadAmount = slot['loadAmount'] as int? ?? 0;

      // Deduct money
      transaction.update(userDocRef, {'dinero': currentMoney - cost});

      // Update load
      final newLoadAmount = max(0, currentLoadAmount - lossAmount);
      slots[slotIndex]['loadAmount'] = newLoadAmount;
      slots[slotIndex]['status'] = FleetStatus.enMarcha.value;
      slots[slotIndex]['accidentCost'] = 0;

      transaction.update(fleetDocRef, {'slots': slots});
    });
  }

  Widget _buildMiniCards(BuildContext context, double width, double height) {
    final truckId = firestoreData?['truckId'];
    final driverId = firestoreData?['driverId'];
    final containerId = firestoreData?['containerId'];

    final bool noTruck = truckId == null || truckId.toString().isEmpty;
    final bool noDriver = driverId == null || driverId.toString().isEmpty;
    final bool noContainer =
        containerId == null || containerId.toString().isEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildMiniCard(
          width: width,
          height: height,
          assetPath: noTruck
              ? 'assets/images/parking/no_truck.png'
              : 'assets/images/trucks/$truckId.png',
          showOverlay: noTruck,
          onTap: () {
            if (truckId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TruckInformationScreen(
                    truckId: truckId!,
                    fleetId: fleetId,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BuyTruckScreen(fleetId: fleetId),
                ),
              );
            }
          },
        ),
        SizedBox(width: width * 0.1),
        _buildMiniCard(
          width: width,
          height: height,
          assetPath: noDriver
              ? 'assets/images/parking/no_driver.png'
              : 'assets/images/drivers/$driverId.png',
          showOverlay: noDriver,
          onTap: () {
            if (driverId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverInformationScreen(
                    driverId: driverId!,
                    fleetId: fleetId,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BuyDriverScreen(fleetId: fleetId),
                ),
              );
            }
          },
        ),
        SizedBox(width: width * 0.1),
        _buildMiniCard(
          width: width,
          height: height,
          assetPath: noContainer
              ? 'assets/images/parking/no_container.png'
              : 'assets/images/containers/$containerId.png',
          showOverlay: noContainer,
          onTap: () {
            if (noContainer) {
              // Verificar si hay camión asignado antes de permitir compra de contenedor
              if (noTruck) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Debes asignar un camión antes de comprar un contenedor',
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              // Si hay camión, ir a buy_container
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BuyContainerScreen(fleetId: fleetId),
                ),
              );
            } else {
              // Si hay contenedor, ir a container_information
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContainerInformationScreen(
                    containerId: containerId,
                    fleetId: fleetId,
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildMiniCard({
    required double width,
    required double height,
    required String assetPath,
    required bool showOverlay,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(height * 0.12),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height * 0.1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(assetPath, fit: BoxFit.cover),
              if (showOverlay)
                Center(
                  child: Image.asset(
                    'assets/images/parking/mas.png',
                    width: width * 1.4,
                    height: width * 1.4,
                    fit: BoxFit.contain,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableContent(BuildContext context) {
    final cost = fleetConfig?.unlockCost;
    final bool isFree = cost?.type == UnlockCostType.free;

    // Determine the icon and amount based on type
    final String currencyIcon = (isFree || cost?.type == UnlockCostType.money)
        ? 'assets/images/billete.png'
        : 'assets/images/gemas.png';
    final String amount = isFree ? '0' : '${cost?.amount ?? 0}';

    return InkWell(
      onTap: () async {
        if (fleetConfig != null) {
          final bool? success = await showDialog<bool>(
            context: context,
            builder: (context) => GenericPurchaseDialog(
              title: 'COMPRA DE FLOTA',
              description:
                  '¿Estás seguro de que deseas desbloquear este slot para tu flota?',
              price: fleetConfig!.unlockCost.amount,
              priceType: fleetConfig!.unlockCost.type,
              onConfirm: () => FleetService.purchaseFleet(fleetConfig!),
            ),
          );

          if (success == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Flota desbloqueada con éxito!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      },
      child: Stack(
        children: [
          // Large centered pay icon
          Center(
            child: Image.asset(
              'assets/images/parking/pagar.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),

          // Top-right cost indicator
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5), // Darkened background
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    amount,
                    style: const TextStyle(
                      color: Colors.white, // White text as requested
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Image.asset(
                    currencyIcon,
                    width: 24, // Slightly larger
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteProgressInline(BuildContext context) {
    final destinyLocation = firestoreData?['destinyLocation'];
    final startTime = firestoreData?['startTime'] as int?;
    final totalTimeSeconds = firestoreData?['totalTimeSeconds'] as double?;
    final currentLocation = firestoreData?['currentLocation'];

    if (destinyLocation == null ||
        startTime == null ||
        totalTimeSeconds == null ||
        currentLocation == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = (now - startTime) / 1000;
    final progress = (elapsedSeconds / totalTimeSeconds).clamp(0.0, 1.0);

    // Si ha completado, marcar como completado
    if (progress >= 1.0 && firestoreData?['status'] == 'en marcha') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FleetSimulationService().completeTrip(fleetId.toString());
      });
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoadManagerScreen(fleetId: fleetId),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
        ),
        child: Column(
          children: [
            // Progress bar
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade800,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Content
            FutureBuilder<String?>(
              future: _getDestinationCityName(destinyLocation),
              builder: (context, snapshot) {
                final cityName = snapshot.data ?? 'Destino desconocido';
                final progressPercent =
                    '${(progress * 100).toStringAsFixed(1)}%';

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Destino:',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white70,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            cityName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Progreso:',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white70,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimatedTimeTopRight(BuildContext context) {
    final startTime = firestoreData?['startTime'] as int?;
    final totalTimeSeconds =
        firestoreData?['totalTimeSeconds'] as double? ?? 0.0;

    if (startTime == null || totalTimeSeconds <= 0)
      return const SizedBox.shrink();

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = (now - startTime) / 1000;
    final remainingTimeSeconds = totalTimeSeconds - elapsedSeconds;

    if (remainingTimeSeconds <= 0) return const SizedBox.shrink();

    final timeInHours = remainingTimeSeconds / 3600;

    String timeText;
    if (timeInHours >= 1) {
      final hours = timeInHours.floor();
      final minutes = ((timeInHours - hours) * 60).round();
      timeText = '${hours}h ${minutes}m';
    } else {
      final minutes = (timeInHours * 60).round();
      timeText = '${minutes}m';
    }

    return Positioned(
      top: 6,
      right: 10,
      child: Text(
        timeText,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 2,
              color: Colors.black.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFleetStatusTopCenter(BuildContext context) {
    final status = firestoreData?['status'];
    String statusText;
    if (status == 'averiado') {
      statusText = 'Accidentada';
    } else if (status == 'en destino') {
      statusText = 'En destino';
    } else if (status == 'en marcha') {
      statusText = 'En ruta';
    } else {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 6,
      left: 0,
      right: 0,
      child: Text(
        statusText,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 2,
              color: Colors.black.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getDestinationCityName(
    Map<String, dynamic> destinyLocation,
  ) async {
    try {
      final double lat = (destinyLocation['latitude'] as num).toDouble();
      final double lng = (destinyLocation['longitude'] as num).toDouble();

      final locations = await LocationsRepository.loadLocations();
      final location = locations.firstWhere(
        (l) => l.latitude == lat && l.longitude == lng,
        orElse: () => throw Exception('Location not found'),
      );

      return location.city;
    } catch (e) {
      return null;
    }
  }
}
