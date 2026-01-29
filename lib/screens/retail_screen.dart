import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';

class RetailScreen extends StatefulWidget {
  const RetailScreen({super.key});

  @override
  State<RetailScreen> createState() => _RetailScreenState();
}

class _RetailScreenState extends State<RetailScreen> {
  List<RetailSlot> _retailSlots = [];
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
      if (mounted) {
        setState(() {
          _retailSlots = retailSlots;
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
                    builder: (context) => const RetailSellingMaterialScreen(),
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
}
