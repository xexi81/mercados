import 'package:industrial_app/widgets/celebration_dialog.dart';
import 'package:industrial_app/data/experience/experience_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/data/materials/material_model.dart';

import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/confirmation_dialog.dart';

class ManageFactoryStockScreen extends StatefulWidget {
  final int slotId;
  final int factoryId;

  const ManageFactoryStockScreen({
    Key? key,
    required this.slotId,
    required this.factoryId,
  }) : super(key: key);

  @override
  State<ManageFactoryStockScreen> createState() =>
      _ManageFactoryStockScreenState();
}

class _ManageFactoryStockScreenState extends State<ManageFactoryStockScreen> {
  List<MaterialModel> allMaterials = [];
  Map<int, double> selectedQuantities = {}; // materialId -> quantity to move
  Map<int, Map<String, dynamic>> capacitiesByGrade =
      {}; // grade -> {capacity, used}
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      allMaterials = await MaterialsRepository.loadMaterials();
      // Precalculate capacities for all grades
      for (var grade = 1; grade <= 5; grade++) {
        capacitiesByGrade[grade] = await _calculateWarehouseCapacity(grade);
      }
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _calculateWarehouseCapacity(int grade) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'capacity': 0.0, 'used': 0.0};

    print('[DEBUG] Calculando capacidad para grade: $grade');
    try {
      // Get warehouse level and grade from Firestore
      // Removed unused userDoc variable

      // warehouseLevel: nivel del slot de almacén (para sumar 100 * level)
      // Ya se obtiene abajo como 'level'

      // Get warehouse grade (level) from warehouse_users (for this grade)
      final warehousesUsersDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('warehouse_users')
          .doc(user.uid)
          .get();

      int level = 1;
      if (warehousesUsersDoc.exists) {
        final slots = List<Map<String, dynamic>>.from(
          warehousesUsersDoc.data()?['slots'] ?? [],
        );
        final warehouseSlot = slots.firstWhere(
          (s) => s['warehouseId'] == grade,
          orElse: () => <String, dynamic>{},
        );
        if (warehouseSlot.isNotEmpty) {
          level = (warehouseSlot['warehouseLevel'] as int?) ?? 1;
        }
      }
      print('[DEBUG] warehouseSlot level: $level');

      // Load warehouse base capacity from JSON (by grade)
      final warehousesData = await rootBundle.loadString(
        'assets/data/warehouse.json',
      );
      final Map<String, dynamic> warehousesJson = jsonDecode(warehousesData);
      final List<dynamic> warehouses = warehousesJson['warehouses'];

      double baseCapacity = 0;
      for (var warehouse in warehouses) {
        if (warehouse['grade'] == grade) {
          baseCapacity = (warehouse['capacity_m3'] as num).toDouble();
          break;
        }
      }
      print('[DEBUG] baseCapacity (grade $grade): $baseCapacity');

      // Calculate total capacity: base + (100 * level)
      final totalCapacity = baseCapacity + (100 * level);
      print('[DEBUG] totalCapacity: $totalCapacity');

      // Calculate used capacity for this grade
      double usedCapacity = 0;
      if (warehousesUsersDoc.exists) {
        final slots = List<Map<String, dynamic>>.from(
          warehousesUsersDoc.data()?['slots'] ?? [],
        );
        final warehouseSlot = slots.firstWhere(
          (s) => s['warehouseId'] == grade,
          orElse: () => <String, dynamic>{},
        );
        if (warehouseSlot.isNotEmpty) {
          final storage = Map<String, dynamic>.from(
            warehouseSlot['storage'] as Map? ?? {},
          );
          storage.forEach((materialIdStr, data) {
            final units = (data['units'] as num?)?.toDouble() ?? 0;
            final m3PerUnit = (data['m3PerUnit'] as num?)?.toDouble() ?? 0;
            usedCapacity += units * m3PerUnit;
            print(
              '[DEBUG] materialId: $materialIdStr, units: $units, m3PerUnit: $m3PerUnit, subtotal: ${units * m3PerUnit}',
            );
          });
        }
      }
      print('[DEBUG] usedCapacity: $usedCapacity');

      return {'capacity': totalCapacity, 'used': usedCapacity};
    } catch (e) {
      print('Error calculating warehouse capacity: $e');
      return {'capacity': 0.0, 'used': 0.0};
    }
  }

  Future<void> _moveToWarehouse(MaterialModel material, int quantity) async {
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una cantidad mayor a 0'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check warehouse capacity
    final capacityData =
        capacitiesByGrade[material.grade] ?? {'capacity': 0.0, 'used': 0.0};
    final totalCapacity = capacityData['capacity'] as double;
    final usedCapacity = capacityData['used'] as double;
    final availableCapacity = totalCapacity - usedCapacity;
    final requiredCapacity = quantity * material.unitVolumeM3;

    if (requiredCapacity > availableCapacity) {
      final maxQuantity = (availableCapacity / material.unitVolumeM3).floor();
      if (maxQuantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No hay espacio suficiente en el almacén de grado ${material.grade}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Adjust quantity to maximum possible
      quantity = maxQuantity;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cantidad ajustada al máximo posible: $quantity unidades',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // Build confirmation message
    String message =
        '¿Mover ${quantity} unidades de ${material.name} al almacén?';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          ConfirmationDialog(title: 'Confirmar acción', message: message),
    );

    if (confirmed == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        int newLevel = 0;
        int oldLevel = 0;
        int xpToAdd = 0;
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Referencia al usuario
          final userRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid);

          // Referencia a la subcolección warehouse_users
          final warehouseUserRef = userRef
              .collection('warehouse_users')
              .doc(user.uid);

          // PRIMERO: todas las lecturas
          final warehouseUserSnap = await transaction.get(warehouseUserRef);
          final userSnapshot = await transaction.get(userRef);
          // Leer factories_users
          final factoriesUserRef = userRef
              .collection('factories_users')
              .doc(user.uid);
          final factoriesUserSnap = await transaction.get(factoriesUserRef);

          // Procesar datos de warehouse
          Map<String, dynamic> warehouseUserData = warehouseUserSnap.exists
              ? Map<String, dynamic>.from(warehouseUserSnap.data() as Map)
              : {'slots': []};

          List slots = warehouseUserData['slots'] ?? [];
          Map<String, dynamic>? slot = slots
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (s) => s != null && s['warehouseId'] == material.grade,
                orElse: () => null,
              );
          if (slot == null) {
            slot = {
              'warehouseId': material.grade,
              'warehouseLevel': 1,
              'storage': <String, dynamic>{},
            };
            slots.add(slot);
          }

          // Actualizar el stock en el almacén
          final storage =
              (slot['storage'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          final materialIdStr = material.id.toString();
          final prevUnits = (storage[materialIdStr]?['units'] ?? 0) as int;
          final m3PerUnit = material.unitVolumeM3;
          storage[materialIdStr] = {
            'units': prevUnits + quantity,
            'm3PerUnit': m3PerUnit,
          };
          slot['storage'] = storage;
          warehouseUserData['slots'] = slots;
          transaction.set(warehouseUserRef, warehouseUserData);

          // RESTAR stock en factories_users
          if (factoriesUserSnap.exists) {
            Map<String, dynamic> factoriesUserData = Map<String, dynamic>.from(
              factoriesUserSnap.data() as Map,
            );
            List<dynamic> factorySlots = factoriesUserData['slots'] ?? [];
            // Buscar el slot correspondiente
            var factorySlot = factorySlots.firstWhere(
              (s) => s['slotId'] == widget.slotId,
              orElse: () => null,
            );
            if (factorySlot != null) {
              List<dynamic> storedMaterials =
                  factorySlot['storedMaterials'] ?? [];
              int index = storedMaterials.indexWhere(
                (m) => m['id'] == material.id,
              );
              if (index != -1) {
                var storedMaterial = storedMaterials[index];
                int currentQty = storedMaterial['quantity'] ?? 0;
                int newQty = currentQty - quantity;
                if (newQty <= 0) {
                  // Eliminar el material si la cantidad es 0 o menor
                  storedMaterials.removeAt(index);
                } else {
                  storedMaterial['quantity'] = newQty;
                  storedMaterials[index] = storedMaterial;
                }
              }
              factorySlot['storedMaterials'] = storedMaterials;
            }
            factoriesUserData['slots'] = factorySlots;
            transaction.set(factoriesUserRef, factoriesUserData);
          }

          // Añadir experiencia al usuario y comprobar subida de nivel
          final totalVolume = quantity * material.unitVolumeM3;
          xpToAdd = ExperienceService.calculateProduceXp(
            totalVolume,
            material.grade,
          );
          final currentXp = (userSnapshot.data()?['experience'] as int?) ?? 0;
          oldLevel = ExperienceService.getLevelFromExperience(currentXp);
          final newXp = currentXp + xpToAdd;
          newLevel = ExperienceService.getLevelFromExperience(newXp);
          transaction.update(userRef, {'experience': newXp});
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${quantity} unidades de ${material.name} movidas al almacén',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Reset selected quantity for this material y recalc capacity
          selectedQuantities[material.id] = 0;
          capacitiesByGrade[material.grade] = await _calculateWarehouseCapacity(
            material.grade,
          );
          setState(() {});

          // Mostrar dialogo de subida de nivel si corresponde
          if (newLevel > oldLevel) {
            showDialog(
              context: context,
              builder: (context) =>
                  CelebrationDialog(bodyText: '¡Nivel $newLevel alcanzado!'),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        appBar: CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('factories_users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'No se encontraron datos',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final factoriesData = snapshot.data!.data() as Map<String, dynamic>?;
          final List<dynamic> slots = factoriesData?['slots'] ?? [];

          final slot = slots.firstWhere(
            (s) => s['slotId'] == widget.slotId,
            orElse: () => null,
          );

          if (slot == null) {
            return const Center(
              child: Text(
                'Slot no encontrado',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final storedMaterials = slot['storedMaterials'];

          if (storedMaterials == null ||
              storedMaterials is! List ||
              storedMaterials.isEmpty) {
            return const Center(
              child: Text(
                'No hay materiales almacenados en la fábrica',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: storedMaterials.length,
                    itemBuilder: (context, index) {
                      final storedMaterial = storedMaterials[index];
                      final materialId = storedMaterial['id'] as int;
                      final quantity = storedMaterial['quantity'] as int;

                      final material = allMaterials.firstWhere(
                        (m) => m.id == materialId,
                        orElse: () => MaterialModel(
                          id: materialId,
                          name: 'Material $materialId',
                          grade: 1,
                          category: 'Desconocido',
                          components: [],
                          basePrice: 0,
                          unitVolumeM3: 1.0,
                        ),
                      );

                      return _buildMaterialCard(material, quantity);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMaterialCard(MaterialModel material, int availableQuantity) {
    // Initialize selected quantity if not set - do this once without calling setState
    selectedQuantities.putIfAbsent(material.id, () => 0);

    final capacityData = capacitiesByGrade[material.grade];
    if (capacityData == null) {
      return const CircularProgressIndicator();
    }

    final capacity = capacityData['capacity'] as double;
    final used = capacityData['used'] as double;
    final available = capacity - used;
    final maxUnits = (available / material.unitVolumeM3).floor();
    final maxToMove = maxUnits < availableQuantity
        ? maxUnits
        : availableQuantity;

    final isWarehouseFull = maxToMove <= 0;
    final currentValue = selectedQuantities[material.id]?.toInt() ?? 0;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      material.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey,
                        child: const Icon(
                          Icons.inventory,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
                        'Cantidad disponible: $availableQuantity',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Capacidad almacén (Grado ${material.grade}): ${used.toStringAsFixed(1)}/${capacity.toStringAsFixed(1)} m³',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (isWarehouseFull)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(50),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withAlpha(100)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Almacén lleno - No se puede mover stock',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Text(
              'Cantidad a mover: $currentValue / $maxToMove',
              style: TextStyle(
                color: isWarehouseFull ? Colors.grey : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Slider(
              value: currentValue.toDouble(),
              min: 0,
              max: maxToMove.toDouble(),
              divisions: maxToMove > 0 ? maxToMove : 1,
              label: currentValue.toString(),
              onChanged: isWarehouseFull
                  ? null
                  : (value) {
                      setState(() {
                        selectedQuantities[material.id] = value;
                      });
                    },
              activeColor: isWarehouseFull ? Colors.grey : Colors.green,
              inactiveColor: Colors.grey[600],
            ),
            const SizedBox(height: 12),
            IndustrialButton(
              label: isWarehouseFull ? 'ALMACÉN LLENO' : 'Mover al Almacén',
              onPressed: isWarehouseFull
                  ? null
                  : () {
                      final quantityToMove =
                          selectedQuantities[material.id]?.toInt() ?? 0;
                      _moveToWarehouse(material, quantityToMove);
                    },
              gradientTop: isWarehouseFull
                  ? Colors.grey[600]!
                  : const Color(0xFF4CAF50),
              gradientBottom: isWarehouseFull
                  ? Colors.grey[800]!
                  : const Color(0xFF2E7D32),
              borderColor: isWarehouseFull
                  ? Colors.grey[700]!
                  : const Color(0xFF1B5E20),
              width: double.infinity,
              height: 45,
            ),
          ],
        ),
      ),
    );
  }
}
