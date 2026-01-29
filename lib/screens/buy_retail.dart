import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/data/retail/retail_repository.dart';
import 'package:industrial_app/data/retail/retail_building_model.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';

class BuyRetailScreen extends StatefulWidget {
  final int slotId;

  const BuyRetailScreen({super.key, required this.slotId});

  @override
  State<BuyRetailScreen> createState() => _BuyRetailScreenState();
}

class _BuyRetailScreenState extends State<BuyRetailScreen> {
  List<RetailBuilding> _retailBuildings = [];
  Map<int, MaterialModel> _materials = {};
  bool _isDataLoaded = false;
  final Map<String, bool> _expandedStates =
      {}; // Track expanded state for each building

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final retailBuildings = await RetailRepository.loadRetailBuildings();
      final materials = await MaterialsRepository.loadMaterials();

      if (mounted) {
        setState(() {
          _retailBuildings = retailBuildings;
          _materials = {for (var m in materials) m.id: m};
          _isDataLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading buy retail data: $e');
      if (mounted) {
        setState(() {
          _isDataLoaded = true; // Set to true even on error to show the UI
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
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
          bottom: 100, // Increased bottom margin for Android navigation bar
        ),
        itemCount: _retailBuildings.length,
        itemBuilder: (context, index) {
          final building = _retailBuildings[index];
          return _buildRetailBuildingCard(building);
        },
      ),
    );
  }

  Widget _buildRetailBuildingCard(RetailBuilding building) {
    final isExpanded = _expandedStates[building.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          // Header section with background image
          Stack(
            children: [
              // Background image
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  image: DecorationImage(
                    image: AssetImage(
                      'assets/images/retail/${building.id}.png',
                    ),
                    fit: BoxFit.cover,
                    opacity: 0.7,
                  ),
                ),
              ),
              // Dark overlay for better text readability
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  color: Colors.black.withAlpha(100),
                ),
              ),
              // Price in top right
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/billete.png',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${building.purchaseCost}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Building name centered
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  building.name,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha(150),
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          // Content section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Buy button
                IndustrialButton(
                  label: 'COMPRAR',
                  onPressed: () => _handleBuildingPurchase(building),
                  gradientTop: Colors.green[400]!,
                  gradientBottom: Colors.green[700]!,
                  borderColor: Colors.green[800]!,
                  width: double.infinity,
                  height: 45,
                  fontSize: 16,
                ),
                const SizedBox(height: 16),
                // Expandable products section
                InkWell(
                  onTap: () {
                    setState(() {
                      _expandedStates[building.id] = !isExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withAlpha(100),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Productos disponibles (${building.items.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                // Expanded items list
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  _buildItemsList(building),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(RetailBuilding building) {
    return Column(
      children: building.items.map((itemId) {
        final material = _materials[itemId];
        if (material == null) {
          return ListTile(
            title: Text(
              'Material ID: $itemId (no encontrado)',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          );
        }

        final salesPerHour = building.salesPerHour * (5 - material.grade);

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(50),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Material image
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withAlpha(100),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.asset(
                    material.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[700],
                        child: const Icon(
                          Icons.inventory,
                          color: Colors.white,
                          size: 16,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Material name and sales info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Grado ${material.grade}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Sales per hour
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${salesPerHour.toStringAsFixed(1)}/h',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'ventas',
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleBuildingPurchase(RetailBuilding building) async {
    final bool? success = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'COMPRAR EDIFICIO RETAIL',
        description: '¿Estás seguro de que deseas comprar ${building.name}?',
        price: building.purchaseCost,
        priceType: UnlockCostType.money,
        onConfirm: () => _purchaseBuilding(building),
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${building.name} comprado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(); // Return to retail screen
    }
  }

  Future<void> _purchaseBuilding(RetailBuilding building) async {
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

        // 3. Check balance
        if (dinero < building.purchaseCost) {
          throw Exception('No tienes suficiente dinero');
        }

        // 4. Find the slot to update
        final List<dynamic> existingSlots = retailSnapshot.exists
            ? (retailSnapshot.data()?['slots'] as List<dynamic>? ?? [])
            : [];

        final slotIndex = existingSlots.indexWhere(
          (slot) => slot['slotId'] == widget.slotId,
        );

        if (slotIndex == -1) {
          throw Exception('Slot no encontrado');
        }

        // 5. Execute writes
        transaction.update(userDocRef, {
          'dinero': dinero - building.purchaseCost,
        });

        // Update the slot with buildingId
        final updatedSlots = List<dynamic>.from(existingSlots);
        updatedSlots[slotIndex] = {
          ...updatedSlots[slotIndex] as Map<String, dynamic>,
          'buildingId': building.id,
          'status': 'en espera',
          'level': 1,
        };

        if (!retailSnapshot.exists) {
          transaction.set(retailDocRef, {'slots': updatedSlots});
        } else {
          transaction.update(retailDocRef, {'slots': updatedSlots});
        }
      });
    } catch (e, stackTrace) {
      debugPrint('ERROR: Failed to purchase retail building: $e');
      debugPrint('ERROR: Stack trace: $stackTrace');
      rethrow;
    }
  }
}
