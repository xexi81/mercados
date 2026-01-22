import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/data/factories/factory_slot_model.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/screens/buy_factory.dart';

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

              // Factory info for unlocked slots with factory
              if (isUnlocked && hasFactory)
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
