import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/factories/factory_repository.dart';
import 'package:industrial_app/data/factories/factory_model.dart';
import 'package:industrial_app/data/factories/production_tier_model.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';

class BuyFactoryScreen extends StatefulWidget {
  final int slotId;

  const BuyFactoryScreen({Key? key, required this.slotId}) : super(key: key);

  @override
  State<BuyFactoryScreen> createState() => _BuyFactoryScreenState();
}

class _BuyFactoryScreenState extends State<BuyFactoryScreen> {
  List<FactoryModel> _factories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFactories();
  }

  Future<void> _loadFactories() async {
    try {
      final factories = await FactoryRepository.loadFactories();
      if (mounted) {
        setState(() {
          _factories = factories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading factories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchaseFactory(FactoryModel factory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'Comprar Fábrica',
        description:
            '¿Deseas comprar ${factory.name}?\n\nPrecio: \$${factory.basePurchasePrice}',
        price: factory.basePurchasePrice,
        priceType: UnlockCostType.money,
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

            if (!userSnapshot.exists || !factoriesSnapshot.exists) {
              throw Exception('Datos no encontrados');
            }

            // Verify user has enough money
            final userData = userSnapshot.data()!;
            final currentMoney = (userData['dinero'] as num?)?.toDouble() ?? 0;

            if (currentMoney < factory.basePurchasePrice) {
              throw Exception('Dinero insuficiente');
            }

            // Get current slots and update the specific slot
            final factoriesData = factoriesSnapshot.data()!;
            final slots = List<Map<String, dynamic>>.from(
              factoriesData['slots'] ?? [],
            );

            final slotIndex = slots.indexWhere(
              (s) => s['slotId'] == widget.slotId,
            );

            if (slotIndex == -1) {
              throw Exception('Slot no encontrado');
            }

            // Update the slot with factory information
            slots[slotIndex] = {
              'slotId': widget.slotId,
              'factoryId': factory.id,
              'currentTier': 1,
              'unlockedTiers': [1],
              'productionQueue': [],
            };

            // Update documents
            transaction.update(factoriesRef, {'slots': slots});
            transaction.update(userRef, {
              'dinero': currentMoney - factory.basePurchasePrice,
            });
          });
        },
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Fábrica comprada con éxito!')),
      );
      Navigator.pop(context);
    }
  }

  Future<Map<String, dynamic>?> _getMaterialInfo(int materialId) async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/materials.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> materials = jsonData['materials'];

      return materials.firstWhere(
        (m) => m['id'] == materialId,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  void _showTierProductsDialog(ProductionTierModel tier) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
        title: Text(
          'Nivel ${tier.tier} - Productos',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tier.products.length,
            itemBuilder: (context, index) {
              final product = tier.products[index];
              final productionPerHour = (3600 / product.productionTimeSeconds)
                  .toStringAsFixed(1);

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getMaterialInfo(product.materialId),
                builder: (context, snapshot) {
                  final materialInfo = snapshot.data;
                  final iconPath = materialInfo != null
                      ? 'assets/images/materials/${materialInfo['id']}.png'
                      : 'assets/images/materials/default.png';
                  final name =
                      materialInfo?['name'] as String? ??
                      'Material ${product.materialId}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(0, 0, 0, 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          iconPath,
                          width: 40,
                          height: 40,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey,
                                child: const Icon(
                                  Icons.inventory,
                                  color: Colors.white,
                                ),
                              ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Producción: $productionPerHour/hora',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: ListView.builder(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 80,
        ),
        itemCount: _factories.length,
        itemBuilder: (context, index) {
          final factory = _factories[index];
          return SizedBox(
            height: 200,
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Background image
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/factories/${factory.id}.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Semi-transparent overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Price with icon - top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/billete.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${factory.basePurchasePrice}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Title - below price
                  Positioned(
                    top: 35,
                    left: 12,
                    child: Text(
                      factory.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Mini cards in center
                  Positioned(
                    top: 70,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(5, (i) {
                        final tierNumber = i + 1;
                        ProductionTierModel? tier;
                        try {
                          tier = factory.productionTiers.firstWhere(
                            (t) => t.tier == tierNumber,
                          );
                        } catch (e) {
                          tier = null;
                        }
                        final hasTier = tier != null;

                        if (!hasTier) {
                          return const Expanded(child: SizedBox());
                        }

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _showTierProductsDialog(tier!),
                            child: Container(
                              margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$tierNumber',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Button - centered bottom
                  Positioned(
                    bottom: 16,
                    left: 60,
                    right: 60,
                    child: IndustrialButton(
                      label: 'Comprar',
                      onPressed: () => _purchaseFactory(factory),
                      gradientTop: const Color(0xFF4CAF50),
                      gradientBottom: const Color(0xFF2E7D32),
                      borderColor: const Color(0xFF1B5E20),
                      width: double.infinity,
                      height: 40,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
