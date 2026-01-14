import 'package:flutter/material.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/fleet/fleet_model.dart';

import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/data/fleet/fleet_service.dart';

import 'package:industrial_app/screens/buy_truck.dart';
import 'package:industrial_app/screens/buy_driver.dart';
import 'package:industrial_app/screens/buy_container.dart';
import 'package:industrial_app/screens/fleet_level.dart';
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

  final String? locationName;

  const ParkingFleetCard({
    super.key,
    required this.fleetId,
    this.fleetConfig,
    this.firestoreData,
    required this.userLevel,
    this.hqLatitude,
    this.hqLongitude,
    this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    // If we have data in Firestore, it's occupied (to be refined later)
    final bool isOccupied = firestoreData != null && firestoreData!.isNotEmpty;

    // Check if it's at headquarters
    bool isAtHQ = false;
    if (isOccupied && hqLatitude != null && hqLongitude != null) {
      final currentLocation = firestoreData!['currentLocation'];
      final status = firestoreData!['status'];
      if (currentLocation != null && status == 'en destino') {
        final double fleetLat = (currentLocation['latitude'] as num).toDouble();
        final double fleetLng = (currentLocation['longitude'] as num)
            .toDouble();
        if (fleetLat == hqLatitude && fleetLng == hqLongitude) {
          isAtHQ = true;
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
              if (isAtHQ)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.4,
                    child: Image.asset(
                      'assets/images/parking/parking_sede.png',
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
            if (isOccupied) _buildOccupiedContent(context, isAtHQ),
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

  Widget _buildOccupiedContent(BuildContext context, bool isAtHQ) {
    // Show content if occupied, regardless of location (isAtHQ logic logic handled separately for bg)
    // But we need to check status for specific buttons
    final status = firestoreData?['status'];
    final bool showActionButtons = status != 'en destino';

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
                    // Only show Route/Load buttons if NOT 'en destino'
                    if (showActionButtons)
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
                                  builder: (context) => const RouteScreen(),
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
                                      const LoadManagerScreen(),
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
        if (locationName != null && !showActionButtons)
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
      ],
    );
  }

  Widget _buildLevelButton(BuildContext context, double width, double height) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FleetLevelScreen()),
        );
      },
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

  Widget _buildBottomButton({
    required BuildContext context,
    required String assetPath,
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
          child: Image.asset(assetPath, fit: BoxFit.cover),
        ),
      ),
    );
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BuyContainerScreen(),
              ),
            );
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
}
