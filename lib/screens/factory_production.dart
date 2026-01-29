import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/factories/factory_repository.dart';
import 'package:industrial_app/data/factories/factory_model.dart';
import 'package:industrial_app/data/factories/factory_product_model.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/data/warehouse/warehouse_repository.dart';
import 'package:industrial_app/data/warehouse/warehouse_model.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/confirmation_dialog.dart';
import 'package:industrial_app/widgets/error_dialog.dart';

class FactoryProductionScreen extends StatefulWidget {
  final int slotId;
  final int factoryId;

  const FactoryProductionScreen({
    super.key,
    required this.slotId,
    required this.factoryId,
  });

  @override
  State<FactoryProductionScreen> createState() =>
      _FactoryProductionScreenState();
}

class _FactoryProductionScreenState extends State<FactoryProductionScreen> {
  FactoryModel? factory;
  List<MaterialModel> allMaterials = [];
  List<MaterialModel> availableMaterials = [];
  Set<int> unlockedGrades = {}; // Grados desbloqueados en almacén
  Map<int, double> productionQuantities = {};
  Map<int, int> warehouseStock = {};
  Set<int> availableWarehouseGrades = {}; // Grados de warehouse disponibles
  int currentTier = 1;
  String factoryStatus = 'en espera';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _filterAvailableMaterials() {
    if (factory == null) return;
    final List<MaterialModel> filtered = [];
    for (var tierData in factory!.productionTiers) {
      if (tierData.tier <= currentTier) {
        for (var product in tierData.products) {
          final material = allMaterials.firstWhere(
            (m) => m.id == product.materialId,
            orElse: () => MaterialModel(
              id: -1,
              name: '',
              category: '',
              description: '',
              grade: 1,
              components: const [],
              basePrice: 0,
              unitVolumeM3: 0.0,
              allowedContainers: const [],
            ),
          );
          if (material.id != -1 && !filtered.contains(material)) {
            filtered.add(material);
          }
        }
      }
    }
    setState(() {
      availableMaterials = filtered;
    });
  }

  Future<void> _loadWarehouseStock() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final warehouseDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('warehouse_users')
        .doc(user.uid)
        .get();
    if (!warehouseDoc.exists) return;
    final data = warehouseDoc.data()!;
    final slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);
    final Map<int, int> stock = {};
    for (var slot in slots) {
      final storage = Map<String, dynamic>.from(slot['storage'] ?? {});
      storage.forEach((key, value) {
        final int id = int.tryParse(key) ?? -1;
        if (id != -1) {
          final units = (value['units'] as num?)?.toInt() ?? 0;
          stock[id] = (stock[id] ?? 0) + units;
        }
      });
    }
    setState(() {
      warehouseStock = stock;
    });
  }

  Future<void> _loadAvailableWarehouseGrades() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final warehouseDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('warehouse_users')
          .doc(user.uid)
          .get();

      if (!warehouseDoc.exists) return;

      final data = warehouseDoc.data()!;
      final slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);

      // Cargar configuraciones de warehouses una sola vez
      final warehouseConfigs = await WarehouseRepository.loadWarehouses();

      // Extraer todos los grados disponibles
      final Set<int> grades = {};
      for (var slot in slots) {
        final warehouseId = slot['warehouseId'] as int?;
        if (warehouseId != null) {
          final config = warehouseConfigs.firstWhere(
            (w) => w.id == warehouseId,
            orElse: () => WarehouseModel(
              id: -1,
              name: '',
              grade: -1,
              requiredLevel: 999,
              unlockCost: UnlockCost(type: 'money', amount: 0),
              capacityM3: 0,
            ),
          );
          if (config.grade > 0) {
            grades.add(config.grade);
          }
        }
      }

      setState(() {
        availableWarehouseGrades = grades;
      });
    } catch (e) {
      debugPrint('Error loading available warehouse grades: $e');
    }
  }

  int _getMaxProducibleUnits(MaterialModel material) {
    if (material.components.isEmpty) {
      // Para materiales básicos, calcular producción máxima en 24 horas
      FactoryProductModel? product;
      for (var tierData in factory!.productionTiers) {
        if (tierData.tier <= currentTier) {
          product = tierData.products
              .where((p) => p.materialId == material.id)
              .firstOrNull;
          if (product != null) break;
        }
      }
      if (product != null) {
        // 86400 segundos = 24 horas
        return 86400 ~/ product.productionTimeSeconds;
      }
      return 0; // Si no se encuentra el producto, no se puede fabricar
    }

    // Para materiales con componentes, calcular basado en stock disponible
    int maxUnits = double.maxFinite.toInt();
    for (var component in material.components) {
      final stock = warehouseStock[component.materialId] ?? 0;
      final possible = stock ~/ component.quantity;
      if (possible < maxUnits) maxUnits = possible;
    }
    return maxUnits > 0 ? maxUnits : 0;
  }

  Future<void> _loadData() async {
    try {
      final factoryData = await FactoryRepository.getFactoryById(
        widget.factoryId,
      );
      final materials = await MaterialsRepository.loadMaterials();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final factoriesDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('factories_users')
            .doc(user.uid)
            .get();
        if (factoriesDoc.exists) {
          final data = factoriesDoc.data()!;
          final slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);
          final slot = slots.firstWhere(
            (s) => s['slotId'] == widget.slotId,
            orElse: () => {},
          );
          currentTier = (slot['currentTier'] as int?) ?? 1;
          factoryStatus = (slot['status'] as String?) ?? 'en espera';
        }
        await _loadWarehouseStock();

        // Cargar grados disponibles de warehouse una sola vez
        await _loadAvailableWarehouseGrades();
      }
      if (mounted) {
        setState(() {
          factory = factoryData;
          allMaterials = materials;
          _filterAvailableMaterials();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading factory production data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getFactoriesDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('factories_users')
        .doc(user.uid)
        .get();
  }

  Future<void> _startProduction(MaterialModel material, int quantity) async {
    if (quantity <= 0) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Verificar si hay materiales en storedMaterials
    final factoriesRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('factories_users')
        .doc(user.uid);

    final factoriesSnapshot = await factoriesRef.get();
    if (factoriesSnapshot.exists) {
      final factoriesData = factoriesSnapshot.data()!;
      final factorySlots = List<Map<String, dynamic>>.from(
        factoriesData['slots'] ?? [],
      );

      final slot = factorySlots.firstWhere(
        (s) => s['slotId'] == widget.slotId,
        orElse: () => <String, dynamic>{},
      );

      if (slot.isNotEmpty) {
        final storedMaterials = slot['storedMaterials'];
        if (storedMaterials != null &&
            storedMaterials is List &&
            storedMaterials.isNotEmpty) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => const ErrorDialog(
                title: 'Producción Bloqueada',
                description:
                    'No puedes iniciar una nueva producción mientras haya materiales almacenados. Por favor, recoge los materiales del almacén de la fábrica primero.',
              ),
            );
          }
          return;
        }
      }
    }

    // Calculate components to remove
    Map<int, int> componentsToRemove = {};
    for (var component in material.components) {
      componentsToRemove[component.materialId] = component.quantity * quantity;
    }

    // Get production time info - search in all tiers up to current tier
    FactoryProductModel? product;
    for (var tierData in factory!.productionTiers) {
      if (tierData.tier <= currentTier) {
        product = tierData.products
            .where((p) => p.materialId == material.id)
            .firstOrNull;
        if (product != null) break;
      }
    }

    if (product == null) return;

    final productionPerHour = 3600 / product.productionTimeSeconds;

    // Calculate total production time
    final totalProductionSeconds = product.productionTimeSeconds * quantity;
    final hours = totalProductionSeconds ~/ 3600;
    final minutes = (totalProductionSeconds % 3600) ~/ 60;
    final seconds = totalProductionSeconds % 60;

    String timeText = '';
    if (hours > 0) {
      timeText += '${hours}h ';
    }
    if (minutes > 0) {
      timeText += '${minutes}m ';
    }
    if (seconds > 0 || timeText.isEmpty) {
      timeText += '${seconds}s';
    }

    // Build materials list for dialog
    String materialsText = '';
    if (componentsToRemove.isNotEmpty) {
      materialsText = '\n\nMateriales a consumir (no recuperables):\n\n';
      for (var entry in componentsToRemove.entries) {
        final componentMaterial = allMaterials
            .where((m) => m.id == entry.key)
            .firstOrNull;
        materialsText +=
            '• ${componentMaterial?.name ?? 'Material ${entry.key}'}: ${entry.value} unidades\n';
      }
    }

    // Show confirmation dialog
    if (mounted) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ConfirmationDialog(
          title: 'Iniciar Producción',
          message:
              'Vas a fabricar $quantity unidades de ${material.name}\n\n⏱️ Tiempo estimado: $timeText$materialsText',
        ),
      );

      if (confirmed != true) return;

      // Start production
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final warehouseRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .collection('warehouse_users')
              .doc(user.uid);

          final factoriesRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .collection('factories_users')
              .doc(user.uid);

          final warehouseSnapshot = await transaction.get(warehouseRef);
          final factoriesSnapshot = await transaction.get(factoriesRef);

          if (!warehouseSnapshot.exists || !factoriesSnapshot.exists) {
            throw Exception('Datos no encontrados');
          }

          // Remove components from warehouse
          if (componentsToRemove.isNotEmpty) {
            final warehouseData = warehouseSnapshot.data()!;
            final warehouseSlots = List<Map<String, dynamic>>.from(
              warehouseData['slots'] ?? [],
            );

            for (var entry in componentsToRemove.entries) {
              int remainingToRemove = entry.value;
              final materialId = entry.key.toString();

              for (
                int i = 0;
                i < warehouseSlots.length && remainingToRemove > 0;
                i++
              ) {
                final storage = Map<String, dynamic>.from(
                  warehouseSlots[i]['storage'] as Map? ?? {},
                );

                if (storage.containsKey(materialId)) {
                  final units =
                      (storage[materialId]['units'] as num?)?.toInt() ?? 0;
                  if (units <= remainingToRemove) {
                    remainingToRemove -= units;
                    storage.remove(materialId);
                  } else {
                    storage[materialId] = {'units': units - remainingToRemove};
                    remainingToRemove = 0;
                  }
                  warehouseSlots[i]['storage'] = storage;
                }
              }
            }

            transaction.update(warehouseRef, {'slots': warehouseSlots});
          }

          // Update factory status and add current production
          final factoriesData = factoriesSnapshot.data()!;
          final factorySlots = List<Map<String, dynamic>>.from(
            factoriesData['slots'] ?? [],
          );

          final slotIndex = factorySlots.indexWhere(
            (s) => s['slotId'] == widget.slotId,
          );

          if (slotIndex != -1) {
            factorySlots[slotIndex]['status'] = 'fabricando';
            factorySlots[slotIndex]['currentProduction'] = {
              'materialId': material.id,
              'quantityPerHour': productionPerHour,
              'targetQuantity': quantity,
              'producedQuantity': 0,
              'startTime': Timestamp.now(),
            };
          }

          transaction.update(factoriesRef, {'slots': factorySlots});
        });

        // Volver a la pantalla anterior después de iniciar producción exitosamente
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error starting production: $e');
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => const ErrorDialog(
              title: 'Error',
              description:
                  'No se pudo iniciar la producción. Inténtalo de nuevo.',
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (factoryStatus != 'en espera') {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _getFactoriesDoc(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: CustomGameAppBar(),
              backgroundColor: AppColors.surface,
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              appBar: CustomGameAppBar(),
              backgroundColor: AppColors.surface,
              body: const Center(
                child: Text(
                  'No hay producción activa.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }
          final data = snapshot.data!.data()!;
          final slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);
          final slot = slots.firstWhere(
            (s) => s['slotId'] == widget.slotId,
            orElse: () => {},
          );
          final Map<String, dynamic>? currentProduction =
              slot['currentProduction'] as Map<String, dynamic>?;
          if (currentProduction == null) {
            return Scaffold(
              appBar: CustomGameAppBar(),
              backgroundColor: AppColors.surface,
              body: const Center(
                child: Text(
                  'No hay producción activa.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }
          final int materialId = currentProduction['materialId'] ?? 0;
          final int targetQuantity = currentProduction['targetQuantity'] ?? 0;
          final int producedQuantity =
              currentProduction['producedQuantity'] ?? 0;
          final double quantityPerHour =
              (currentProduction['quantityPerHour'] as num?)?.toDouble() ?? 0.0;
          final MaterialModel? material = allMaterials.isNotEmpty
              ? allMaterials.firstWhere(
                  (m) => m.id == materialId,
                  orElse: () => MaterialModel(
                    id: -1,
                    name: '',
                    category: '',
                    description: '',
                    grade: 1,
                    components: const [],
                    basePrice: 0,
                    unitVolumeM3: 0.0,
                    allowedContainers: const [],
                  ),
                )
              : null;
          final double progress = targetQuantity > 0
              ? producedQuantity / targetQuantity
              : 0.0;
          return Scaffold(
            appBar: CustomGameAppBar(),
            backgroundColor: AppColors.surface,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (material != null) ...[
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            material.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey,
                                  child: const Icon(
                                    Icons.inventory,
                                    color: Colors.white,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        material.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        material.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Cantidad fabricando: $producedQuantity / $targetQuantity',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      color: Colors.green,
                      minHeight: 12,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Velocidad de producción: ${quantityPerHour.toStringAsFixed(2)} unidades/hora',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: availableMaterials.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 80),
                    SizedBox(height: 24),
                    Text(
                      'Esta fábrica en Tier $currentTier no tiene productos disponibles para fabricar',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Mejora el tier para desbloquear nuevos productos',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 80,
              ),
              itemCount: availableMaterials.length,
              itemBuilder: (context, index) {
                final material = availableMaterials[index];
                return _buildMaterialCard(material);
              },
            ),
    );
  }

  Widget _buildMaterialCard(MaterialModel material) {
    final maxProducible = _getMaxProducibleUnits(material);
    final hasEnoughMaterials = maxProducible > 0;
    final hasWarehouseGrade = availableWarehouseGrades.contains(material.grade);
    final canProduce = hasEnoughMaterials && hasWarehouseGrade;
    final currentQuantity = productionQuantities[material.id] ?? 0.0;

    // Get production rate per hour - search in all tiers up to current tier
    FactoryProductModel? product;
    for (var tierData in factory!.productionTiers) {
      if (tierData.tier <= currentTier) {
        product = tierData.products
            .where((p) => p.materialId == material.id)
            .firstOrNull;
        if (product != null) break;
      }
    }
    final productionPerHour = product != null
        ? (3600 / product.productionTimeSeconds).toStringAsFixed(2)
        : '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with image and name
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
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
                        child: const Icon(Icons.inventory, color: Colors.white),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Grado ${material.grade} - ${material.category}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contenedores: ${material.allowedContainers.map((c) => c.displayName).join(', ')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⚡ $productionPerHour unidades/hora',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Components required
            if (material.components.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Materiales requeridos:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...material.components.map((component) {
                final componentMaterial = allMaterials
                    .where((m) => m.id == component.materialId)
                    .firstOrNull;
                final stock = warehouseStock[component.materialId] ?? 0;
                final hasEnough = stock >= component.quantity;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: hasEnough ? Colors.green : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.asset(
                            'assets/images/materials/${component.materialId}.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${componentMaterial?.name ?? 'Material ${component.materialId}'}: ${component.quantity} por unidad',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        'Stock: $stock',
                        style: TextStyle(
                          color: hasEnough ? Colors.green : Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Production info
            const SizedBox(height: 16),
            Text(
              'Máximo fabricable: ${hasWarehouseGrade ? maxProducible : 0} unidades',
              style: TextStyle(
                color: canProduce ? Colors.green : Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Slider and button (only if can produce)
            if (canProduce) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: currentQuantity,
                      min: 0,
                      max: maxProducible.toDouble(),
                      divisions: maxProducible > 0 ? maxProducible : 1,
                      label: currentQuantity.round().toString(),
                      activeColor: Colors.green,
                      inactiveColor: Colors.green.withValues(alpha: 0.3),
                      onChanged: (value) {
                        setState(() {
                          productionQuantities[material.id] = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currentQuantity.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              IndustrialButton(
                label: 'Iniciar fabricación',
                onPressed: currentQuantity > 0
                    ? () => _startProduction(material, currentQuantity.round())
                    : null,
                gradientTop: const Color(0xFF4CAF50),
                gradientBottom: const Color(0xFF2E7D32),
                borderColor: const Color(0xFF1B5E20),
                width: double.infinity,
                height: 50,
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                !hasWarehouseGrade
                    ? 'Se requiere un almacén de grado ${material.grade} para fabricar este material'
                    : 'No hay suficientes materiales en el almacén para fabricar este producto',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
