import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/data/retail/retail_repository.dart';
import 'package:industrial_app/data/retail/retail_slot_model.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/data/experience/experience_service.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/data/retail/retail_building_model.dart';
import 'package:industrial_app/screens/retail_selling_material.dart';
import 'package:industrial_app/screens/buy_retail.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/widgets/celebration_dialog.dart';

class RetailScreen extends StatefulWidget {
  const RetailScreen({super.key});

  @override
  State<RetailScreen> createState() => _RetailScreenState();
}

class _RetailScreenState extends State<RetailScreen> {
  List<RetailSlot> _retailSlots = [];
  Map<int, MaterialModel> _materials = {};
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final retailSlots = await RetailRepository.loadRetailSlots();
      await RetailRepository.loadRetailBuildings();
      final materials = await MaterialsRepository.loadMaterials();
      if (mounted) {
        setState(() {
          _retailSlots = retailSlots;
          _materials = {for (var m in materials) m.id: m};
          _isDataLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading retail data: $e');
      if (mounted) {
        setState(() {
          _isDataLoaded = true; // Set to true even on error to show the UI
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isDataLoaded) {
      return Scaffold(
        appBar: const CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final int experience = userData?['experience'] ?? 0;
        final int level = ExperienceService.getLevelFromExperience(experience);

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .collection('retail_users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, retailSnapshot) {
            Map<String, dynamic> retailMap = {};
            if (retailSnapshot.hasData && retailSnapshot.data!.exists) {
              retailMap =
                  retailSnapshot.data?.data() as Map<String, dynamic>? ?? {};
            }

            final List<dynamic> slots = retailMap['slots'] ?? [];

            return Scaffold(
              appBar: const CustomGameAppBar(),
              backgroundColor: AppColors.surface,
              body: GridView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 80,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  crossAxisSpacing: 0,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.0,
                ),
                itemCount: _retailSlots.length,
                itemBuilder: (context, index) {
                  final retailSlot = _retailSlots[index];
                  final Map<String, dynamic>? cardData =
                      slots.firstWhere(
                            (s) => s['slotId'] == retailSlot.slotId,
                            orElse: () => null,
                          )
                          as Map<String, dynamic>?;

                  return _buildRetailSlotCard(
                    retailSlot: retailSlot,
                    firestoreData: cardData,
                    userLevel: level,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRetailSlotCard({
    required RetailSlot retailSlot,
    required Map<String, dynamic>? firestoreData,
    required int userLevel,
  }) {
    // Check if it's occupied (has data in Firestore)
    final bool isOccupied = firestoreData != null && firestoreData.isNotEmpty;

    // Check if it's locked by level
    final bool isLocked = userLevel < retailSlot.requiredLevel;

    const double radius = 12.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2),
        child: Stack(
          children: [
            // Background Image logic
            if (!isOccupied)
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
              )
            else if (isOccupied && firestoreData != null)
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.4,
                  child: Image.asset(
                    'assets/images/retail/${firestoreData['buildingId']}.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.7),
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.grey[800]);
                    },
                  ),
                ),
              ),

            if (isLocked) _buildLockedContent(retailSlot.requiredLevel),
            if (isOccupied)
              _buildOccupiedSlotContent(retailSlot, firestoreData),
            if (!isLocked && !isOccupied) _buildPurchaseSlotContent(retailSlot),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedContent(int requiredLevel) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withAlpha(128)),
        child: Text(
          'LVL $requiredLevel',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildOccupiedSlotContent(
    RetailSlot retailSlot,
    Map<String, dynamic> data,
  ) {
    // Check if slot has a building
    final buildingId = data['buildingId'] as String?;
    final status = data['status'] as String? ?? 'operativo';
    final level = data['level'] as int? ?? 1;

    if (buildingId == null) {
      return InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BuyRetailScreen(slotId: retailSlot.slotId),
            ),
          );
        },
        child: const Center(
          child: Text(
            'Slot vacío - Construir edificio',
            style: TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Get the retail building data
    final retailBuilding = RetailRepository.getRetailBuildingById(buildingId);
    if (retailBuilding == null) {
      return const Center(
        child: Text(
          'Error: Edificio no encontrado',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      );
    }

    return Stack(
      children: [
        // Status text centered at top
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Price at top right (only when selling or sold)
        if ((status == 'vendiendo' || status == 'vendido') &&
            data['sellingMaterial'] != null)
          Positioned(
            top: 8,
            right: 8,
            child: Builder(
              builder: (context) {
                final sellingMaterial =
                    data['sellingMaterial'] as Map<String, dynamic>;
                final materialId = sellingMaterial['materialId'] as int?;
                final quantity = sellingMaterial['quantity'] as int? ?? 0;
                final material = _materials[materialId];
                final sellPrice = (material?.basePrice ?? 0) * 2;
                final totalRevenue = quantity * sellPrice;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/billete.png',
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalRevenue',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        // Level card at top left
        Positioned(
          top: 8,
          left: 8,
          child: InkWell(
            onTap: () => _handleLevelUpgrade(retailSlot, retailBuilding, level),
            child: Container(
              width: 60,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(30 * 0.12),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30 * 0.1),
                child: Center(
                  child: Text(
                    'LVL $level',
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
        ),

        // Center card for "en espera" status
        if (status == 'en espera')
          Positioned(
            top: 50,
            bottom: 50,
            left: 20,
            right: 120,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        RetailSellingMaterialScreen(slotId: retailSlot.slotId),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha(100),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/parking/mas.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

        // Center card for "vendiendo" status
        if (status == 'vendiendo')
          Positioned(
            top: 50,
            bottom: 50,
            left: 20,
            right: 20,
            child: _buildSellingCard(data),
          ),

        // Collect benefits button for "vendido" status
        if (status == 'vendido')
          Positioned(
            top: 50,
            bottom: 50,
            left: 20,
            right: 20,
            child: Center(
              child: IndustrialButton(
                label: 'RECOGER BENEFICIOS',
                onPressed: () => _handleCollectBenefits(retailSlot, data),
                gradientTop: Colors.green[400]!,
                gradientBottom: Colors.green[700]!,
                borderColor: Colors.green[800]!,
                width: 160,
                height: 40,
                fontSize: 12,
              ),
            ),
          ),

        // Sell building button for "en espera" status
        if (status == 'en espera')
          Positioned(
            bottom: 8,
            right: 8,
            child: IndustrialButton(
              label: 'VENDER',
              onPressed: () =>
                  _handleSellBuilding(retailSlot, retailBuilding, level),
              gradientTop: Colors.red[400]!,
              gradientBottom: Colors.red[700]!,
              borderColor: Colors.red[800]!,
              width: 80,
              height: 35,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Future<void> _handleLevelUpgrade(
    RetailSlot retailSlot,
    RetailBuilding retailBuilding,
    int currentLevel,
  ) async {
    final nextLevel = currentLevel + 1;
    final upgradeCost = nextLevel * retailBuilding.purchaseCost;

    final bool? success = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'MEJORAR EDIFICIO',
        description: '¿Mejorar ${retailBuilding.name} al nivel $nextLevel?',
        price: upgradeCost,
        priceType: UnlockCostType.money,
        onConfirm: () =>
            _upgradeBuildingLevel(retailSlot, retailBuilding, nextLevel),
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Edificio mejorado al nivel $nextLevel!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleSellBuilding(
    RetailSlot retailSlot,
    RetailBuilding retailBuilding,
    int currentLevel,
  ) async {
    final sellPrice = (currentLevel * retailBuilding.purchaseCost * 0.1)
        .round();

    final bool? success = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'VENDER EDIFICIO',
        description:
            '¿Vender ${retailBuilding.name} (Nivel $currentLevel) por $sellPrice?',
        price: sellPrice,
        priceType: UnlockCostType.money,
        onConfirm: () => _sellBuilding(retailSlot, sellPrice),
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Edificio vendido!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _upgradeBuildingLevel(
    RetailSlot retailSlot,
    RetailBuilding retailBuilding,
    int newLevel,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final upgradeCost = newLevel * retailBuilding.purchaseCost;

      final userDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid);
      final retailDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('retail_users')
          .doc(user.uid);

      return FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocRef);
        final retailSnapshot = await transaction.get(retailDocRef);

        if (!userSnapshot.exists) {
          throw Exception('Documento de usuario no encontrado');
        }

        final userData = userSnapshot.data() as Map<String, dynamic>;
        final int dinero = userData['dinero'] ?? 0;

        if (dinero < upgradeCost) {
          throw Exception('No tienes suficiente dinero');
        }

        final List<dynamic> existingSlots = retailSnapshot.exists
            ? (retailSnapshot.data()?['slots'] as List<dynamic>? ?? [])
            : [];

        final slotIndex = existingSlots.indexWhere(
          (slot) => slot['slotId'] == retailSlot.slotId,
        );

        if (slotIndex == -1) {
          throw Exception('Slot no encontrado');
        }

        transaction.update(userDocRef, {'dinero': dinero - upgradeCost});

        final updatedSlots = List<dynamic>.from(existingSlots);
        updatedSlots[slotIndex] = {
          ...updatedSlots[slotIndex] as Map<String, dynamic>,
          'level': newLevel,
        };

        if (!retailSnapshot.exists) {
          transaction.set(retailDocRef, {'slots': updatedSlots});
        } else {
          transaction.update(retailDocRef, {'slots': updatedSlots});
        }
      });
    } catch (e, stackTrace) {
      debugPrint('ERROR: Failed to upgrade building level: $e');
      debugPrint('ERROR: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _sellBuilding(RetailSlot retailSlot, int sellPrice) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid);
      final retailDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('retail_users')
          .doc(user.uid);

      return FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocRef);
        final retailSnapshot = await transaction.get(retailDocRef);

        if (!userSnapshot.exists) {
          throw Exception('Documento de usuario no encontrado');
        }

        final List<dynamic> existingSlots = retailSnapshot.exists
            ? (retailSnapshot.data()?['slots'] as List<dynamic>? ?? [])
            : [];

        final slotIndex = existingSlots.indexWhere(
          (slot) => slot['slotId'] == retailSlot.slotId,
        );

        if (slotIndex == -1) {
          throw Exception('Slot no encontrado');
        }

        final userData = userSnapshot.data() as Map<String, dynamic>;
        final int dinero = userData['dinero'] ?? 0;

        transaction.update(userDocRef, {'dinero': dinero + sellPrice});

        final updatedSlots = List<dynamic>.from(existingSlots);
        updatedSlots[slotIndex] = {
          ...updatedSlots[slotIndex] as Map<String, dynamic>,
          'buildingId': null,
          'status': null,
          'level': 0,
        };

        if (!retailSnapshot.exists) {
          transaction.set(retailDocRef, {'slots': updatedSlots});
        } else {
          transaction.update(retailDocRef, {'slots': updatedSlots});
        }
      });
    } catch (e, stackTrace) {
      debugPrint('ERROR: Failed to sell building: $e');
      debugPrint('ERROR: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _handleCollectBenefits(
    RetailSlot retailSlot,
    Map<String, dynamic> data,
  ) async {
    final sellingMaterial = data['sellingMaterial'] as Map<String, dynamic>?;
    if (sellingMaterial == null) return;

    final materialId = sellingMaterial['materialId'] as int?;
    final quantity = sellingMaterial['quantity'] as int? ?? 0;
    final material = _materials[materialId];
    if (material == null) return;

    final moneyEarned = (quantity * material.basePrice * 2).toInt();
    final experienceEarned =
        (quantity *
                material.unitVolumeM3 *
                ExperienceService.getRetailSaleXpPerM3(material.grade))
            .toInt();

    final bool? success = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'RECOGER BENEFICIOS',
        description: '¿Recoger \$${moneyEarned} y ${experienceEarned} XP?',
        price: moneyEarned,
        priceType: UnlockCostType.money,
        onConfirm: () =>
            _collectBenefits(retailSlot, moneyEarned, experienceEarned),
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Beneficios recogidos!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _collectBenefits(
    RetailSlot retailSlot,
    int moneyEarned,
    int experienceEarned,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid);

      // Calcular nivel antes de la transacción
      final userSnapshotBefore = await userDocRef.get();
      final currentExperience =
          (userSnapshotBefore.data()?['experience'] as int?) ?? 0;
      final oldLevel = ExperienceService.getLevelFromExperience(
        currentExperience,
      );

      final retailDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('retail_users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocRef);
        final retailSnapshot = await transaction.get(retailDocRef);

        if (!userSnapshot.exists) {
          throw Exception('Documento de usuario no encontrado');
        }

        final userData = userSnapshot.data() as Map<String, dynamic>;
        final int currentMoney = userData['dinero'] ?? 0;
        final int currentExperienceTx = userData['experience'] ?? 0;

        final List<dynamic> existingSlots = retailSnapshot.exists
            ? (retailSnapshot.data()?['slots'] as List<dynamic>? ?? [])
            : [];

        final slotIndex = existingSlots.indexWhere(
          (slot) => slot['slotId'] == retailSlot.slotId,
        );

        if (slotIndex == -1) {
          throw Exception('Slot no encontrado');
        }

        final updatedSlot = Map<String, dynamic>.from(
          existingSlots[slotIndex] as Map<String, dynamic>,
        );
        updatedSlot.remove('sellingMaterial');
        updatedSlot['status'] = 'en espera';

        final updatedSlots = List<dynamic>.from(existingSlots);
        updatedSlots[slotIndex] = updatedSlot;

        transaction.update(userDocRef, {
          'dinero': currentMoney + moneyEarned,
          'experience': currentExperienceTx + experienceEarned,
        });

        if (!retailSnapshot.exists) {
          transaction.set(retailDocRef, {'slots': updatedSlots});
        } else {
          transaction.update(retailDocRef, {'slots': updatedSlots});
        }
      });

      // Comprobar subida de nivel
      final newExperience = currentExperience + experienceEarned;
      final newLevel = ExperienceService.getLevelFromExperience(newExperience);
      if (newLevel > oldLevel && mounted) {
        showDialog(
          context: context,
          builder: (context) =>
              CelebrationDialog(bodyText: '¡Nivel $newLevel alcanzado!'),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR: Failed to collect benefits: $e');
      debugPrint('ERROR: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Widget _buildPurchaseSlotContent(RetailSlot retailSlot) {
    return InkWell(
      onTap: () => _handleRetailPurchase(retailSlot),
      child: const Center(
        child: SizedBox(
          width: 120,
          height: 120,
          child: Image(
            image: AssetImage('assets/images/parking/pagar.png'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Future<void> _handleRetailPurchase(RetailSlot retailSlot) async {
    final bool? success = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'COMPRA DE RETAIL',
        description: '¿Estás seguro de que deseas comprar este slot retail?',
        price: retailSlot.cost.money > 0
            ? retailSlot.cost.money
            : retailSlot.cost.gems,
        priceType: retailSlot.cost.money > 0
            ? UnlockCostType.money
            : UnlockCostType.gems,
        onConfirm: () => _purchaseRetailSlot(retailSlot),
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Slot retail comprado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _purchaseRetailSlot(RetailSlot retailSlot) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid);
      final retailDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('retail_users')
          .doc(user.uid);

      return FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Perform all reads first
        final userSnapshot = await transaction.get(userDocRef);
        final retailSnapshot = await transaction.get(retailDocRef);

        // 2. Validate user and balance
        if (!userSnapshot.exists) {
          throw Exception('Documento de usuario no encontrado');
        }

        final userData = userSnapshot.data() as Map<String, dynamic>;
        final int dinero = userData['dinero'] ?? 0;
        final int gemas = userData['gemas'] ?? 0;

        // 3. Check if slot is already purchased
        final List<dynamic> existingSlots = retailSnapshot.exists
            ? (retailSnapshot.data()?['slots'] as List<dynamic>? ?? [])
            : [];
        final bool slotAlreadyExists = existingSlots.any(
          (slot) => slot['slotId'] == retailSlot.slotId,
        );

        if (slotAlreadyExists) {
          throw Exception('Este slot ya está comprado');
        }

        // 4. Check balance
        if (retailSlot.cost.money > 0) {
          if (dinero < retailSlot.cost.money) {
            throw Exception('No tienes suficiente dinero');
          }
        } else if (retailSlot.cost.gems > 0) {
          if (gemas < retailSlot.cost.gems) {
            throw Exception('No tienes suficientes gemas');
          }
        }

        // 5. Execute writes
        if (retailSlot.cost.money > 0) {
          transaction.update(userDocRef, {
            'dinero': dinero - retailSlot.cost.money,
          });
        } else if (retailSlot.cost.gems > 0) {
          transaction.update(userDocRef, {
            'gemas': gemas - retailSlot.cost.gems,
          });
        }

        // Create new retail slot
        final newSlot = {'slotId': retailSlot.slotId, 'buildingId': null};

        if (!retailSnapshot.exists) {
          transaction.set(retailDocRef, {
            'slots': [newSlot],
          });
        } else {
          transaction.update(retailDocRef, {
            'slots': FieldValue.arrayUnion([newSlot]),
          });
        }
      });
    } catch (e, stackTrace) {
      debugPrint('ERROR: Failed to purchase retail slot: $e');
      debugPrint('ERROR: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Widget _buildSellingCard(Map<String, dynamic> data) {
    final sellingMaterial = data['sellingMaterial'] as Map<String, dynamic>?;
    if (sellingMaterial == null) return const SizedBox.shrink();

    final materialId = sellingMaterial['materialId'] as int?;
    final quantity = sellingMaterial['quantity'] as int? ?? 0;
    final sellRate = sellingMaterial['sellRate'] as double? ?? 0.0;
    final startTime = sellingMaterial['startTime'] as Timestamp?;

    final material = _materials[materialId];
    if (material == null) return const SizedBox.shrink();

    // Calculate current sold based on time elapsed
    int sold = 0;
    if (startTime != null) {
      final now = Timestamp.now();
      final elapsedMs =
          now.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch;
      final elapsedHours = elapsedMs / (1000 * 60 * 60);
      sold = (elapsedHours * sellRate).floor().clamp(0, quantity);
    }

    final sellPrice = material.basePrice * 2;
    final totalRevenue = quantity * sellPrice;
    final remainingQuantity = quantity - sold;
    final remainingHours = remainingQuantity / sellRate;
    final progress = quantity > 0 ? sold / quantity : 0.0;

    if (progress >= 1.0) {
      // Sale completed - change status to "vendido" automatically
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markSaleAsCompleted(data);
      });

      // Show completed sale card
      return InkWell(
        onTap: () => _showCollectSaleDialog(data, totalRevenue, material),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(100), width: 2),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'VENTA COMPLETADA',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresos: \$${totalRevenue}',
                style: const TextStyle(color: Colors.yellow, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Toca para recoger',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        // Material icon on the left
        Container(
          width: 32, // Reduced from 40 to 32
          height: 32, // Reduced from 40 to 32
          padding: const EdgeInsets.all(2), // Add padding for border visibility
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Image.asset(
            'assets/images/materials/${material.id}.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[800],
                child: const Icon(Icons.image, color: Colors.white, size: 16),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Content on the right
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name only (price moved to top)
              Text(
                material.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Progress bar (20% larger, aligned with material name start)
              SizedBox(
                width: 144, // 120 * 1.2 = 144px (20% larger)
                height: 4, // Increased from 3 to 4 for better visibility
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[700],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
              const SizedBox(height: 2),
              // Sold/total and time below
              SizedBox(
                width: 144, // Match progress bar width
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sold}/${quantity}',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                    const SizedBox(height: 1),
                    // Remaining time below the sold/total
                    if (remainingHours > 0.1)
                      Text(
                        remainingHours >= 1
                            ? '${remainingHours.toStringAsFixed(1)}h restantes'
                            : '${(remainingHours * 60).round()}min restantes',
                        style: TextStyle(color: Colors.grey[400], fontSize: 8),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _markSaleAsCompleted(Map<String, dynamic> data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final retailDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('retail_users')
          .doc(user.uid);

      final retailSnapshot = await retailDocRef.get();
      if (!retailSnapshot.exists) return;

      final retailData = retailSnapshot.data()!;
      final slots = List<Map<String, dynamic>>.from(retailData['slots'] ?? []);

      final slotIndex = slots.indexWhere((s) => s['slotId'] == data['slotId']);
      if (slotIndex != -1 && slots[slotIndex]['status'] == 'vendiendo') {
        slots[slotIndex]['status'] = 'vendido';
        await retailDocRef.update({'slots': slots});
      }
    } catch (e) {
      debugPrint('Error marking sale as completed: $e');
    }
  }

  Future<void> _showCollectSaleDialog(
    Map<String, dynamic> data,
    int totalRevenue,
    MaterialModel material,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'RECOGER VENTA',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Recoger \$${totalRevenue} de la venta?',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Se añadirá experiencia por la venta.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RECOGER', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _collectSale(data, totalRevenue, material);
    }
  }

  Future<double> _calculateRetailSaleExperience(
    MaterialModel material,
    int quantitySold,
  ) async {
    try {
      // Load experience rules
      final experienceData = json.decode(
        await rootBundle.loadString('assets/data/experience_account.json'),
      );

      final retailSaleRules =
          experienceData['experienceRules']['retailSale']['baseXpPerM3'];
      final grade = material.grade.toString();

      if (retailSaleRules.containsKey(grade)) {
        final xpPerM3 = retailSaleRules[grade] as num;
        // Assume 1 unit = 1 m³ for simplicity, adjust if needed
        return quantitySold * xpPerM3.toDouble();
      }

      return 0.0;
    } catch (e) {
      debugPrint('Error calculating retail sale experience: $e');
      return 0.0;
    }
  }

  Future<void> _collectSale(
    Map<String, dynamic> data,
    int expectedRevenue,
    MaterialModel material,
  ) async {
    int actualRevenue = 0;
    int actuallySold = 0;
    double experienceGained = 0.0;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid);

      // Calcular nivel antes de la transacción
      final userSnapshotBefore = await userDocRef.get();
      final currentExperience =
          (userSnapshotBefore.data()?['experience'] as int?) ?? 0;
      final oldLevel = ExperienceService.getLevelFromExperience(
        currentExperience,
      );

      final retailDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('retail_users')
          .doc(user.uid);
      final warehouseDocRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('warehouse_users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocRef);
        final retailSnapshot = await transaction.get(retailDocRef);
        final warehouseSnapshot = await transaction.get(warehouseDocRef);

        if (!userSnapshot.exists ||
            !retailSnapshot.exists ||
            !warehouseSnapshot.exists)
          return;

        final userData = userSnapshot.data()!;
        final retailData = retailSnapshot.data()!;
        final warehouseData = warehouseSnapshot.data()!;

        final currentMoney = userData['money'] as int? ?? 0;
        final slots = List<Map<String, dynamic>>.from(
          retailData['slots'] ?? [],
        );

        // Initialize warehouse slots
        final warehouseSlots = List<Map<String, dynamic>>.from(
          warehouseData['slots'] ?? [],
        );

        final slotIndex = slots.indexWhere(
          (s) => s['slotId'] == data['slotId'],
        );
        if (slotIndex != -1) {
          final sellingMaterial =
              slots[slotIndex]['sellingMaterial'] as Map<String, dynamic>?;
          if (sellingMaterial != null) {
            final materialId = sellingMaterial['materialId'] as int?;
            final quantity = sellingMaterial['quantity'] as int? ?? 0;
            final startTime = sellingMaterial['startTime'] as Timestamp?;
            final sellRate = sellingMaterial['sellRate'] as double? ?? 0.0;

            // Calculate how much was actually sold
            int actuallySold =
                quantity; // Default to full quantity for completed sales
            if (startTime != null) {
              final now = Timestamp.now();
              final elapsedMs =
                  now.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch;
              final elapsedHours = elapsedMs / (1000 * 60 * 60);
              actuallySold = (elapsedHours * sellRate).floor().clamp(
                0,
                quantity,
              );
            }

            // Stock was already subtracted when sale started, no need to subtract more
            // But if not everything was sold, we should return the unsold stock to warehouse
            int unsoldQuantity = quantity - actuallySold;
            if (unsoldQuantity > 0) {
              // Return unsold stock to warehouse
              for (var slot in warehouseSlots) {
                if (unsoldQuantity <= 0) break;

                final storage = Map<String, dynamic>.from(
                  slot['storage'] as Map? ?? {},
                );
                final materialIdStr = materialId.toString();

                if (storage.containsKey(materialIdStr)) {
                  final currentUnits =
                      (storage[materialIdStr]['units'] as num?)?.toInt() ?? 0;
                  storage[materialIdStr]['units'] =
                      currentUnits + unsoldQuantity;
                  slot['storage'] = storage;
                  unsoldQuantity = 0; // All returned to first available slot
                  break;
                }
              }
            }

            // Calculate revenue based on actually sold amount
            final material = _materials[materialId];
            final sellPrice = (material?.basePrice ?? 0) * 2;
            actualRevenue = actuallySold * sellPrice;
          }

          slots[slotIndex]['status'] = 'en espera';
          slots[slotIndex].remove('sellingMaterial');
        }

        transaction.update(userDocRef, {'money': currentMoney + actualRevenue});
        transaction.update(retailDocRef, {'slots': slots});
        if (warehouseData['slots'] != null) {
          transaction.update(warehouseDocRef, {'slots': warehouseSlots});
        }

        // Add experience for retail sale
        experienceGained = await _calculateRetailSaleExperience(
          material,
          actuallySold,
        );
        final currentExperience = userData['experience'] as num? ?? 0;
        transaction.update(userDocRef, {
          'experience': currentExperience + experienceGained,
        });
      });

      // Comprobar subida de nivel
      final newExperience = currentExperience + experienceGained.toInt();
      final newLevel = ExperienceService.getLevelFromExperience(newExperience);
      if (newLevel > oldLevel && mounted) {
        showDialog(
          context: context,
          builder: (context) =>
              CelebrationDialog(bodyText: '¡Nivel $newLevel alcanzado!'),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Recogidos \$${actualRevenue} y +${experienceGained.toStringAsFixed(1)} XP!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error collecting sale: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al recoger la venta'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
