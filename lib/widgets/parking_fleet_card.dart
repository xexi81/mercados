import 'package:flutter/material.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/fleet/fleet_model.dart';

import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/widgets/fleet_purchase_dialog.dart';

class ParkingFleetCard extends StatelessWidget {
  final int fleetId;
  final FleetModel? fleetConfig;
  final Map<String, dynamic>? firestoreData;
  final int userLevel;
  final double? hqLatitude;
  final double? hqLongitude;

  const ParkingFleetCard({
    super.key,
    required this.fleetId,
    this.fleetConfig,
    this.firestoreData,
    required this.userLevel,
    this.hqLatitude,
    this.hqLongitude,
  });

  @override
  Widget build(BuildContext context) {
    // If we have data in Firestore, it's occupied (to be refined later)
    final bool isOccupied = firestoreData != null && firestoreData!.isNotEmpty;

    // Check if it's at headquarters
    bool isAtHQ = false;
    if (isOccupied && hqLatitude != null && hqLongitude != null) {
      final location = firestoreData!['location'];
      if (location != null) {
        final double fleetLat = (location['latitude'] as num).toDouble();
        final double fleetLng = (location['longitude'] as num).toDouble();
        // Use a small epsilon for double comparison if needed,
        // but since they come from the same source, direct match should work.
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
            if (isOccupied) _buildOccupiedContent(context),
            if (!isLocked && !isOccupied) _buildAvailableContent(context),

            // Fleet ID indicator (optional, but helpful for debugging/clarity)
            Positioned(
              top: 4,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#$fleetId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
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

  Widget _buildOccupiedContent(BuildContext context) {
    return const SizedBox.shrink();
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
      onTap: () {
        if (fleetConfig != null) {
          showDialog(
            context: context,
            builder: (context) => FleetPurchaseDialog(fleet: fleetConfig!),
          );
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
