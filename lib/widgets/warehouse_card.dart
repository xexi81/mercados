import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/warehouse/warehouse_model.dart';
import 'package:industrial_app/data/warehouse/warehouse_repository.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/screens/warehouse_manager.dart';

class WarehouseCard extends StatelessWidget {
  final int warehouseId;
  final WarehouseModel warehouseConfig;
  final Map<String, dynamic>? firestoreData;
  final int userLevel;

  const WarehouseCard({
    super.key,
    required this.warehouseId,
    required this.warehouseConfig,
    this.firestoreData,
    required this.userLevel,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = userLevel < warehouseConfig.requiredLevel;
    final isOwned = firestoreData != null;
    final requiredLevel = warehouseConfig.requiredLevel;

    const double radius = 12.0;

    return GestureDetector(
      onTap: !isLocked && !isOwned ? () => _handlePurchase(context) : null,
      child: Container(
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
              // Background image based on state
              if (isOwned)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.2,
                    child: Image.asset(
                      'assets/images/warehouses/$warehouseId.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
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

              // Content based on state
              if (isLocked)
                _buildLockedContent(context, requiredLevel)
              else if (!isOwned)
                _buildAvailableContent(context)
              else
                _buildOwnedContent(context),
            ],
          ),
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
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
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

  Widget _buildAvailableContent(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/parking/pagar.png',
        width: 160,
        height: 160,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildOwnedContent(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;

          final double itemH = h * 0.26;
          final double itemW = itemH * (85 / 48);

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.03,
              vertical: h * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Warehouse name at top
                Text(
                  warehouseConfig.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
                // Mini cards centered
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildLevelCard(context, itemW, itemH),
                    SizedBox(width: w * 0.02),
                    _buildManageCard(context, itemW, itemH),
                  ],
                ),
                // Empty space to balance
                const SizedBox.shrink(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, double width, double height) {
    final currentLevel = (firestoreData?['level'] as int?) ?? (firestoreData?['warehouseLevel'] as int?) ?? 0;

    return GestureDetector(
      onTap: () => _handleWarehouseLevelUpgrade(context),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
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
            'LVL $currentLevel',
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

  Widget _buildManageCard(BuildContext context, double width, double height) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                WarehouseManagerScreen(warehouseId: warehouseId),
          ),
        );
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
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
          child: Image.asset(
            'assets/images/parking/load.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Future<void> _handleWarehouseLevelUpgrade(BuildContext context) async {
    final currentLevel = (firestoreData?['level'] as int?) ?? (firestoreData?['warehouseLevel'] as int?) ?? 0;
    final nextLevel = currentLevel + 1;

    try {
      final nextLevelData = await WarehouseRepository.getWarehouseLevelInfo(
        nextLevel,
      );
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

      final upgradeCost = nextLevelData.cost;
      final capacityIncrease = nextLevelData.capacityIncreaseM3;

      if (context.mounted) {
        final bool? success = await showDialog<bool>(
          context: context,
          builder: (context) => GenericPurchaseDialog(
            title: 'MEJORAR ALMACÉN',
            description:
                '¿Deseas mejorar el almacén al nivel $nextLevel?\n\nAumento de capacidad: +${capacityIncrease.toInt()} m³',
            price: upgradeCost,
            priceType: nextLevelData.currency == 'money'
                ? UnlockCostType.money
                : UnlockCostType.gems,
            onConfirm: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) throw Exception('Usuario no identificado');

              final userDocRef = FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid);
              final warehouseDocRef = FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid)
                  .collection('warehouse_users')
                  .doc(user.uid);

              await FirebaseFirestore.instance.runTransaction((
                transaction,
              ) async {
                final userSnapshot = await transaction.get(userDocRef);
                final warehouseSnapshot = await transaction.get(
                  warehouseDocRef,
                );

                if (!userSnapshot.exists || !warehouseSnapshot.exists) {
                  throw Exception('Datos no encontrados');
                }

                final userData = userSnapshot.data()!;
                final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;
                final currentGems = (userData['gemas'] as num?)?.toInt() ?? 0;

                if (nextLevelData.currency == 'money') {
                  if (currentMoney < upgradeCost) {
                    throw Exception('Dinero insuficiente');
                  }
                } else {
                  if (currentGems < upgradeCost) {
                    throw Exception('Gemas insuficientes');
                  }
                }

                final warehouseData = warehouseSnapshot.data()!;
                final slots = List<Map<String, dynamic>>.from(
                  warehouseData['slots'] ?? [],
                );
                final slotIndex = slots.indexWhere(
                  (s) => s['warehouseId'] == warehouseId,
                );

                if (slotIndex == -1) {
                  throw Exception('Almacén no encontrado');
                }

                // Update currency
                if (nextLevelData.currency == 'money') {
                  transaction.update(userDocRef, {
                    'dinero': currentMoney - upgradeCost,
                  });
                } else {
                  transaction.update(userDocRef, {
                    'gemas': currentGems - upgradeCost,
                  });
                }

                // Update warehouse level
                slots[slotIndex]['level'] = nextLevel;
                transaction.update(warehouseDocRef, {'slots': slots});
              });
            },
          ),
        );

        if (success == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Almacén mejorado al nivel $nextLevel'),
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

  Future<void> _handlePurchase(BuildContext context) async {
    final bool? success = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'COMPRAR ALMACÉN',
        description:
            '¿Deseas comprar ${warehouseConfig.name}?\n\nCapacidad: ${warehouseConfig.capacityM3.toInt()} m³',
        price: warehouseConfig.unlockCost.amount,
        priceType: warehouseConfig.unlockCost.type == 'money'
            ? UnlockCostType.money
            : UnlockCostType.gems,
        onConfirm: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) throw Exception('Usuario no identificado');

          final userDocRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid);
          final warehouseDocRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .collection('warehouse_users')
              .doc(user.uid);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            // READ FIRST
            final userSnapshot = await transaction.get(userDocRef);
            final warehouseSnapshot = await transaction.get(warehouseDocRef);

            if (!userSnapshot.exists) {
              throw Exception('Usuario no encontrado');
            }

            final userData = userSnapshot.data()!;
            final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;
            final currentGems = (userData['gemas'] as num?)?.toInt() ?? 0;

            // Check if user has enough currency
            if (warehouseConfig.unlockCost.type == 'money') {
              if (currentMoney < warehouseConfig.unlockCost.amount) {
                throw Exception('Dinero insuficiente');
              }
            } else {
              if (currentGems < warehouseConfig.unlockCost.amount) {
                throw Exception('Gemas insuficientes');
              }
            }

            // Get current slots or create empty array
            List<dynamic> slots = [];
            if (warehouseSnapshot.exists) {
              final warehouseData = warehouseSnapshot.data()!;
              slots = List.from(warehouseData['slots'] ?? []);
            }

            // Check if already purchased
            final exists = slots.any((s) => s['warehouseId'] == warehouseId);
            if (exists) {
              throw Exception('Este almacén ya ha sido comprado');
            }

            // Add new warehouse slot
            slots.add({
              'warehouseId': warehouseId,
              'level': 1,
              'storage': {}, // Empty storage for now
            });

            // WRITE AFTER ALL READS
            // Update user currency
            if (warehouseConfig.unlockCost.type == 'money') {
              transaction.update(userDocRef, {
                'dinero': currentMoney - warehouseConfig.unlockCost.amount,
              });
            } else {
              transaction.update(userDocRef, {
                'gemas': currentGems - warehouseConfig.unlockCost.amount,
              });
            }

            // Update warehouse_users document
            if (warehouseSnapshot.exists) {
              transaction.update(warehouseDocRef, {'slots': slots});
            } else {
              transaction.set(warehouseDocRef, {'slots': slots});
            }
          });
        },
      ),
    );

    if (success == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Almacén comprado exitosamente!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
