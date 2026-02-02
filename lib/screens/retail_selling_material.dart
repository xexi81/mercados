import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/data/retail/retail_repository.dart';
import 'package:industrial_app/data/retail/retail_building_model.dart';
import 'package:industrial_app/data/materials/material_model.dart'
    as material_model;
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/widgets/confirmation_dialog.dart';

class RetailSellingMaterialScreen extends StatefulWidget {
  final int slotId;

  const RetailSellingMaterialScreen({super.key, required this.slotId});

  @override
  State<RetailSellingMaterialScreen> createState() =>
      _RetailSellingMaterialScreenState();
}

class _RetailSellingMaterialScreenState
    extends State<RetailSellingMaterialScreen> {
  RetailBuilding? _retailBuilding;
  Map<int, material_model.MaterialModel> _materials = {};
  Map<int, int> _warehouseStock = {};
  Map<int, double> _warehouseAvgPrice = {};
  bool _isDataLoaded = false;
  final Map<int, double> _selectedQuantities = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load retail buildings first
      await RetailRepository.loadRetailBuildings();

      // Load retail building for this slot
      final retailDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('retail_users')
          .doc(user.uid)
          .get();

      if (retailDoc.exists) {
        final slots = retailDoc.data()?['slots'] as List<dynamic>? ?? [];
        final slotData =
            slots.firstWhere(
                  (s) => s['slotId'] == widget.slotId,
                  orElse: () => null,
                )
                as Map<String, dynamic>?;

        if (slotData != null) {
          final buildingId = slotData['buildingId'] as String?;
          final level = slotData['level'] as int? ?? 1;
          _retailBuilding = RetailRepository.getRetailBuildingById(buildingId!);
          if (_retailBuilding != null) {
            // Adjust salesPerHour by level
            _retailBuilding = RetailBuilding(
              id: _retailBuilding!.id,
              name: _retailBuilding!.name,
              purchaseCost: _retailBuilding!.purchaseCost,
              salesPerHour: _retailBuilding!.salesPerHour * level,
              items: _retailBuilding!.items,
            );
            debugPrint(
              'RetailSellingMaterial: Building loaded: ${_retailBuilding!.name}, items: ${_retailBuilding!.items}',
            );
          } else {
            debugPrint(
              'RetailSellingMaterial: Building not found for id: $buildingId',
            );
          }
        } else {
          debugPrint(
            'RetailSellingMaterial: Slot data not found for slotId: ${widget.slotId}',
          );
        }
      }

      // Load materials
      final materials = await MaterialsRepository.loadMaterials();
      _materials = {for (var m in materials) m.id: m};

      // Load warehouse stock
      final warehouseDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('warehouse_users')
          .doc(user.uid)
          .get();

      debugPrint(
        'RetailSellingMaterial: Warehouse doc exists: ${warehouseDoc.exists}',
      );
      debugPrint('RetailSellingMaterial: Warehouse doc id: ${warehouseDoc.id}');

      if (warehouseDoc.exists) {
        final warehouseData = warehouseDoc.data();
        debugPrint('RetailSellingMaterial: Warehouse data: $warehouseData');
        if (warehouseData != null) {
          debugPrint(
            'RetailSellingMaterial: Warehouse data keys: ${warehouseData.keys}',
          );
          // Read stock from slots instead of global materials field
          final slots = List<Map<String, dynamic>>.from(
            warehouseData['slots'] ?? [],
          );
          debugPrint('RetailSellingMaterial: Warehouse slots: $slots');

          // Calculate weighted average price
          final Map<int, double> totalValue = {};
          final Map<int, int> totalUnits = {};

          for (var slot in slots) {
            final storage = Map<String, dynamic>.from(
              slot['storage'] as Map? ?? {},
            );

            storage.forEach((materialIdStr, data) {
              final materialId = int.tryParse(materialIdStr);

              // Helper for safe parsing
              double safeParseDouble(dynamic value) {
                if (value == null) return 0.0;
                if (value is num) return value.toDouble();
                if (value is String) return double.tryParse(value) ?? 0.0;
                return 0.0;
              }

              final units = (data['units'] as num?)?.toInt() ?? 0;
              final avgPrice = safeParseDouble(data['averagePrice']);

              if (materialId != null && units > 0) {
                // Update stock
                _warehouseStock[materialId] =
                    (_warehouseStock[materialId] ?? 0) + units;

                // Accumulate value for average price
                totalValue[materialId] =
                    (totalValue[materialId] ?? 0.0) + (units * avgPrice);
                totalUnits[materialId] = (totalUnits[materialId] ?? 0) + units;
              }
            });
          }

          // Compute final average
          totalUnits.forEach((id, units) {
            if (units > 0) {
              _warehouseAvgPrice[id] = (totalValue[id] ?? 0.0) / units;
            }
          });

          debugPrint(
            'RetailSellingMaterial: Final warehouse stock: $_warehouseStock',
          );
        } else {
          debugPrint('RetailSellingMaterial: Warehouse data is null');
        }
      } else {
        debugPrint('RetailSellingMaterial: Warehouse doc does not exist');
      }

      debugPrint('RetailSellingMaterial: Warehouse stock: $_warehouseStock');

      // Initialize selected quantities
      if (_retailBuilding != null) {
        for (var materialId in _retailBuilding!.items) {
          final stock = _warehouseStock[materialId] ?? 0;
          debugPrint(
            'RetailSellingMaterial: Material $materialId has stock: $stock',
          );
          if (stock > 0) {
            _selectedQuantities[materialId] = stock.toDouble();
          }
        }
      }

      if (mounted) {
        setState(() {
          _isDataLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading retail selling material data: $e');
      if (mounted) {
        setState(() {
          _isDataLoaded = true;
        });
      }
    }
  }

  List<int> _getSellableMaterials() {
    if (_retailBuilding == null) {
      debugPrint('RetailSellingMaterial: _retailBuilding is null');
      return [];
    }
    final allMaterials = List<int>.from(_retailBuilding!.items);

    // Sort logic: Materials with stock > 0 come first
    allMaterials.sort((a, b) {
      final stockA = _warehouseStock[a] ?? 0;
      final stockB = _warehouseStock[b] ?? 0;

      // If A has stock and B doesn't, A comes first
      if (stockA > 0 && stockB <= 0) return -1;

      // If B has stock and A doesn't, B comes first
      if (stockB > 0 && stockA <= 0) return 1;

      // Otherwise keep original order (by ID)
      return a.compareTo(b);
    });

    debugPrint('RetailSellingMaterial: Sorted materials: $allMaterials');
    return allMaterials;
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

    if (_retailBuilding == null) {
      return const Scaffold(
        appBar: CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: Center(child: Text('Error: Edificio no encontrado')),
      );
    }

    final sellableMaterials = _getSellableMaterials();

    if (sellableMaterials.isEmpty) {
      return const Scaffold(
        appBar: CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: Center(child: Text('Este edificio no puede vender materiales')),
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
        itemCount: sellableMaterials.length,
        itemBuilder: (context, index) {
          final materialId = sellableMaterials[index];
          final material = _materials[materialId];
          if (material == null) return const SizedBox.shrink();

          final stock = _warehouseStock[materialId] ?? 0;
          final avgPrice = _warehouseAvgPrice[materialId] ?? 0.0;
          final selectedQuantity = _selectedQuantities[materialId] ?? 0.0;
          final sellRate =
              _retailBuilding!.salesPerHour; // Already adjusted by level
          final sellPrice = material.basePrice * 2;

          debugPrint(
            'RetailSellingMaterial: Building material card for ${material.name} (ID: $materialId), stock: $stock',
          );

          return _buildMaterialCard(
            material: material,
            stock: stock,
            selectedQuantity: selectedQuantity,
            sellRate: sellRate,
            sellPrice: sellPrice,
            onQuantityChanged: (value) {
              setState(() {
                _selectedQuantities[materialId] = value;
              });
            },
            onStartSelling: () => _handleStartSelling(
              material,
              selectedQuantity.toInt(),
              sellRate,
            ),
            averagePrice: avgPrice,
          );
        },
      ),
    );
  }

  Widget _buildMaterialCard({
    required material_model.MaterialModel material,
    required int stock,
    required double selectedQuantity,
    required double sellRate,
    required int sellPrice,
    required ValueChanged<double> onQuantityChanged,
    required VoidCallback onStartSelling,
    required double averagePrice,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Material info
          Row(
            children: [
              // Material image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    7,
                  ), // Slightly less than container radius
                  child: Image.asset(
                    'assets/images/materials/${material.id}.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Material details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Stock: $stock',
                      style: TextStyle(
                        color: stock > 0 ? Colors.grey[400] : Colors.red,
                        fontSize: 12,
                        fontWeight: stock > 0
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Venta/hora: ${sellRate.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                    Text(
                      'Precio venta: \$$sellPrice',
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Precio promedio: \$${averagePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (stock > 0) ...[
            // Quantity slider
            Builder(
              builder: (context) {
                final totalHours = selectedQuantity / sellRate;
                final hours = totalHours.floor();
                final minutes = ((totalHours - hours) * 60).round();
                String timeString;
                if (hours > 0) {
                  timeString = '${hours}h ${minutes}m';
                } else {
                  timeString = '${minutes}m';
                }

                return Text(
                  'Cantidad a vender: ${selectedQuantity.toInt()} ($timeString)',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                );
              },
            ),
            Slider(
              value: selectedQuantity,
              min: 1,
              max: stock.toDouble(),
              divisions: stock > 1 ? stock - 1 : 1,
              onChanged: onQuantityChanged,
              activeColor: Colors.green,
              inactiveColor: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            // Start selling button
            IndustrialButton(
              label: 'COMENZAR A VENDER',
              onPressed: onStartSelling,
              gradientTop: Colors.green[400]!,
              gradientBottom: Colors.green[700]!,
              borderColor: Colors.green[800]!,
              width: double.infinity,
              height: 40,
            ),
          ] else ...[
            // No stock message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(100), width: 1),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'No hay stock disponible',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleStartSelling(
    material_model.MaterialModel material,
    int quantity,
    double sellRate,
  ) async {
    final hoursNeeded = quantity / sellRate;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'CONFIRMAR VENTA',
        message:
            '¿Comenzar a vender $quantity unidades de ${material.name}?\n\n'
            'Tiempo estimado: ${hoursNeeded.toStringAsFixed(1)} horas',
      ),
    );

    if (confirm == true) {
      await _startSelling(material, quantity, sellRate);
      if (mounted) {
        Navigator.of(context).pop(); // Return to retail screen
      }
    }
  }

  Future<void> _startSelling(
    material_model.MaterialModel material,
    int quantity,
    double sellRate,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('StartSelling: User: ${user?.uid}');
      if (user == null) {
        debugPrint('StartSelling: User is null');
        return;
      }

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

      debugPrint('StartSelling: Starting simple update approach');

      // Read current data first
      final retailDoc = await retailDocRef.get();
      if (!retailDoc.exists) {
        debugPrint('StartSelling: Retail document does not exist');
        throw Exception('Retail data not found');
      }

      final warehouseDoc = await warehouseDocRef.get();
      if (!warehouseDoc.exists) {
        debugPrint('StartSelling: Warehouse document does not exist');
        throw Exception('Warehouse data not found');
      }

      final retailData = retailDoc.data()!;
      final warehouseData = warehouseDoc.data()!;
      debugPrint('StartSelling: Current retail data: $retailData');
      debugPrint('StartSelling: Current warehouse data: $warehouseData');

      // Check if there's enough stock in warehouse
      final warehouseSlots = List<Map<String, dynamic>>.from(
        warehouseData['slots'] ?? [],
      );
      int availableStock = 0;
      for (var slot in warehouseSlots) {
        final storage = Map<String, dynamic>.from(slot['storage'] ?? {});
        final materialStock = storage[material.id.toString()];
        if (materialStock != null) {
          availableStock += (materialStock['units'] as num?)?.toInt() ?? 0;
        }
      }

      debugPrint(
        'StartSelling: Available stock for material ${material.id}: $availableStock',
      );
      if (availableStock < quantity) {
        debugPrint('StartSelling: Not enough stock');
        throw Exception('No hay suficiente stock en el almacén');
      }

      // Update warehouse stock - subtract the quantity
      int remainingToSubtract = quantity;
      for (var slot in warehouseSlots) {
        if (remainingToSubtract <= 0) break;

        final storage = Map<String, dynamic>.from(slot['storage'] ?? {});
        final materialIdStr = material.id.toString();

        if (storage.containsKey(materialIdStr)) {
          final currentUnits =
              (storage[materialIdStr]['units'] as num?)?.toInt() ?? 0;
          final subtractAmount = remainingToSubtract.clamp(0, currentUnits);

          if (subtractAmount > 0) {
            final newUnits = currentUnits - subtractAmount;
            if (newUnits > 0) {
              storage[materialIdStr]['units'] = newUnits;
            } else {
              storage.remove(materialIdStr);
            }
            slot['storage'] = storage;
            remainingToSubtract -= subtractAmount;
            debugPrint(
              'StartSelling: Subtracted $subtractAmount from warehouse slot, remaining: $remainingToSubtract',
            );
          }
        }
      }

      // Update slots (now also update warehouse stock)
      final slots = List<Map<String, dynamic>>.from(retailData['slots'] ?? []);
      debugPrint('StartSelling: Current slots count: ${slots.length}');
      final slotIndex = slots.indexWhere((s) => s['slotId'] == widget.slotId);
      debugPrint('StartSelling: Slot index for ${widget.slotId}: $slotIndex');

      if (slotIndex == -1) {
        debugPrint('StartSelling: Slot not found');
        throw Exception('Slot not found');
      }

      // Check if slot is already selling
      if (slots[slotIndex]['status'] == 'vendiendo') {
        debugPrint('StartSelling: Slot is already selling');
        throw Exception('Este slot ya está vendiendo');
      }

      slots[slotIndex]['status'] = 'vendiendo';
      slots[slotIndex]['sellingMaterial'] = {
        'materialId': material.id,
        'quantity': quantity,
        'sellRate': sellRate,
        'sold': 0,
        'startTime': Timestamp.now(),
      };

      debugPrint('StartSelling: Updated slots: $slots');

      // Update both retail and warehouse
      debugPrint('StartSelling: Attempting updates');
      await retailDocRef.update({'slots': slots});
      await warehouseDocRef.update({'slots': warehouseSlots});
      debugPrint('StartSelling: Updates completed successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Venta iniciada!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting sale: $e');
      debugPrint('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        debugPrint('Firebase error code: ${e.code}');
        debugPrint('Firebase error message: ${e.message}');
        debugPrint('Firebase error plugin: ${e.plugin}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar la venta: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
