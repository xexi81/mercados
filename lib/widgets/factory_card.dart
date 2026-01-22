import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/data/factories/factory_slot_model.dart';
import 'package:industrial_app/data/factories/factory_status.dart';
import 'package:industrial_app/data/factories/factory_model.dart';
import 'package:industrial_app/data/factories/factory_repository.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/screens/buy_factory.dart';
import 'package:industrial_app/screens/factory_production.dart';

class FactoryCard extends StatelessWidget {
  final int slotId;
  final FactorySlotModel slotConfig;
  final Map<String, dynamic>? firestoreData;
  final int userLevel;

  const FactoryCard({
    Key? key,
    required this.slotId,
    required this.slotConfig,
    required this.firestoreData,
    required this.userLevel,
  }) : super(key: key);

  bool get isUnlocked => firestoreData != null;
  bool get canUnlock => userLevel >= slotConfig.requiredLevel;
  bool get isLocked => !isUnlocked && !canUnlock;

  Future<void> _handleTierUpgrade(BuildContext context) async {
    try {
      final currentTier = (firestoreData?['currentTier'] as int?) ?? 1;
      final nextTier = currentTier + 1;

      // Load factory data to get tier information
      final factoryId = firestoreData?['factoryId'] as int?;
      if (factoryId == null) return;

      final factory = await FactoryRepository.getFactoryById(factoryId);
      if (factory == null) return;

      // Find next tier
      final nextTierData = factory.productionTiers
          .where((t) => t.tier == nextTier)
          .firstOrNull;

      if (nextTierData == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Has alcanzado el tier máximo'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final upgradeCost = nextTierData.unlockPrice;

      if (context.mounted) {
        final bool? success = await showDialog<bool>(
          context: context,
          builder: (context) => GenericPurchaseDialog(
            title: 'MEJORAR TIER',
            description:
                '¿Deseas mejorar al tier $nextTier?\n\nGrado máximo: ${nextTierData.maxGrade}',
            price: upgradeCost,
            priceType: UnlockCostType.money,
            onConfirm: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) throw Exception('Usuario no identificado');

              final userDocRef = FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid);
              final factoriesDocRef = FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid)
                  .collection('factories_users')
                  .doc(user.uid);

              await FirebaseFirestore.instance.runTransaction((
                transaction,
              ) async {
                final userSnapshot = await transaction.get(userDocRef);
                final factoriesSnapshot = await transaction.get(
                  factoriesDocRef,
                );

                if (!userSnapshot.exists)
                  throw Exception('Usuario no encontrado');
                if (!factoriesSnapshot.exists)
                  throw Exception('Datos de fábrica no encontrados');

                // Verify funds
                final userData = userSnapshot.data()!;
                final currentMoney =
                    (userData['dinero'] as num?)?.toDouble() ?? 0;

                if (currentMoney < upgradeCost) {
                  throw Exception('Dinero insuficiente');
                }

                // Update money
                transaction.update(userDocRef, {
                  'dinero': currentMoney - upgradeCost,
                });

                // Update factory tier
                final factoriesData = factoriesSnapshot.data()!;
                List<dynamic> slots = List.from(factoriesData['slots'] ?? []);

                final slotIndex = slots.indexWhere(
                  (s) => s['slotId'] == slotId,
                );
                if (slotIndex != -1) {
                  Map<String, dynamic> updatedSlot = Map<String, dynamic>.from(
                    slots[slotIndex],
                  );
                  updatedSlot['currentTier'] = nextTier;

                  // Add to unlocked tiers list
                  List<dynamic> unlockedTiers = List.from(
                    updatedSlot['unlockedTiers'] ?? [],
                  );
                  if (!unlockedTiers.contains(nextTier)) {
                    unlockedTiers.add(nextTier);
                  }
                  updatedSlot['unlockedTiers'] = unlockedTiers;

                  slots[slotIndex] = updatedSlot;

                  transaction.update(factoriesDocRef, {'slots': slots});
                }
              });
            },
          ),
        );

        if (success == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tier mejorado a $nextTier'),
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

  Future<void> _unlockSlot(BuildContext context) async {
    final cost = slotConfig.cost;
    final bool isMoneyPurchase = cost.money > 0;
    final int price = isMoneyPurchase ? cost.money : cost.gems;
    final UnlockCostType priceType = isMoneyPurchase
        ? UnlockCostType.money
        : UnlockCostType.gems;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'Desbloquear Slot de Fábrica',
        description:
            '¿Deseas desbloquear el slot de fábrica ${slotConfig.slotId}?\n\nRequisito de nivel: ${slotConfig.requiredLevel}',
        price: price,
        priceType: priceType,
        onConfirm: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) throw Exception('Usuario no autenticado');

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            // Read user and factories documents
            final userRef = FirebaseFirestore.instance
                .collection('usuarios')
                .doc(user.uid);

            final factoriesRef = FirebaseFirestore.instance
                .collection('usuarios')
                .doc(user.uid)
                .collection('factories_users')
                .doc(user.uid);

            final userSnapshot = await transaction.get(userRef);
            final factoriesSnapshot = await transaction.get(factoriesRef);

            if (!userSnapshot.exists) {
              throw Exception('Usuario no encontrado');
            }

            // Verify user has enough money/gems
            final userData = userSnapshot.data()!;
            final currentMoney = (userData['dinero'] as num?)?.toDouble() ?? 0;
            final currentGems = (userData['gemas'] as num?)?.toInt() ?? 0;

            if (isMoneyPurchase) {
              if (currentMoney < cost.money) {
                throw Exception('Dinero insuficiente');
              }
            } else {
              if (currentGems < cost.gems) {
                throw Exception('Gemas insuficientes');
              }
            }

            // Get current slots or create empty array
            List<Map<String, dynamic>> slots = [];
            if (factoriesSnapshot.exists) {
              final factoriesData = factoriesSnapshot.data()!;
              slots = List<Map<String, dynamic>>.from(
                factoriesData['slots'] ?? [],
              );
            }

            // Add new slot
            slots.add({
              'slotId': slotConfig.slotId,
              'factoryId': null,
              'currentTier': 0,
              'unlockedTiers': [],
              'productionQueue': [],
            });

            // Update documents
            if (factoriesSnapshot.exists) {
              transaction.update(factoriesRef, {'slots': slots});
            } else {
              transaction.set(factoriesRef, {'slots': slots});
            }

            if (isMoneyPurchase) {
              transaction.update(userRef, {
                'dinero': currentMoney - cost.money,
              });
            } else {
              transaction.update(userRef, {'gemas': currentGems - cost.gems});
            }
          });
        },
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Slot de fábrica desbloqueado!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const double radius = 12.0;
    final int? factoryId = firestoreData?['factoryId'];
    final bool hasFactory = factoryId != null;

    return GestureDetector(
      onTap: canUnlock && !isUnlocked ? () => _unlockSlot(context) : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 2),
          child: Stack(
            children: [
              // Background Image
              if (isUnlocked && hasFactory)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.4,
                    child: Image.asset(
                      'assets/images/factories/$factoryId.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else if (!isUnlocked)
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

              // Pay icon overlay for unlockable slots
              if (canUnlock && !isUnlocked)
                Center(
                  child: Image.asset(
                    'assets/images/parking/pagar.png',
                    width: 80,
                    height: 80,
                  ),
                ),

              // Level requirement for locked slots
              if (isLocked)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Text(
                      'LVL ${slotConfig.requiredLevel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

              // Buy button for unlocked slots without factory
              if (isUnlocked && !hasFactory)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: IndustrialButton(
                      label: 'Comprar',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BuyFactoryScreen(slotId: slotId),
                          ),
                        );
                      },
                      gradientTop: const Color(0xFF4CAF50),
                      gradientBottom: const Color(0xFF2E7D32),
                      borderColor: const Color(0xFF1B5E20),
                      width: double.infinity,
                      height: 50,
                    ),
                  ),
                ),

              // Factory status for unlocked slots with factory
              if (isUnlocked && hasFactory && firestoreData!['status'] != null)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      firestoreData!['status'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),

              // Top-left level minicard for "en espera" status
              if (isUnlocked &&
                  hasFactory &&
                  firestoreData!['status'] == 'en espera')
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => _handleTierUpgrade(context),
                    child: Container(
                      width: 60,
                      height: 35,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
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
                          'LVL ${firestoreData!['currentTier'] ?? 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Central minicard for "en espera" status
              if (isUnlocked &&
                  hasFactory &&
                  firestoreData!['status'] == 'en espera')
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FactoryProductionScreen(
                            slotId: slotId,
                            factoryId: factoryId!,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.factory,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

              // Factory info for unlocked slots with factory (NOT "en espera")
              if (isUnlocked &&
                  hasFactory &&
                  firestoreData!['status'] != 'en espera')
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Fábrica activa',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (firestoreData!['currentTier'] != null &&
                            firestoreData!['currentTier'] > 0)
                          Text(
                            'Nivel: ${firestoreData!['currentTier']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
