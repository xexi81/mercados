import 'package:industrial_app/data/experience/experience_service.dart';
import 'package:industrial_app/widgets/level_up_dialog.dart';
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
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/confirmation_dialog.dart';
import 'package:industrial_app/widgets/error_dialog.dart';

class ProductionQueueScreen extends StatefulWidget {
  final int slotId;
  final int factoryId;
  final int queueSlot;

  const ProductionQueueScreen({
    Key? key,
    required this.slotId,
    required this.factoryId,
    required this.queueSlot,
  }) : super(key: key);

  @override
  State<ProductionQueueScreen> createState() => _ProductionQueueScreenState();
}

class _ProductionQueueScreenState extends State<ProductionQueueScreen> {
  FactoryModel? factory;
  List<MaterialModel> allMaterials = [];
  List<MaterialModel> availableMaterials = [];
  Set<int> unlockedGrades = {}; // Grados desbloqueados en almacén
  Map<int, double> productionQuantities = {};
  Map<int, int> warehouseStock = {};
  int currentTier = 1;
  bool isLoading = true;
  String factoryStatus = 'en espera';

  @override
  void initState() {
    super.initState();
    _loadData();
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
      debugPrint('Error loading production queue data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWarehouseStock() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final warehouseDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('warehouse_users')
          .doc(user.uid)
          .get();

      if (warehouseDoc.exists) {
        final data = warehouseDoc.data()!;
        final slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);

        Map<int, int> stock = {};
        // Leer el nivel del almacén
        final int warehouseLevel = (data['level'] as int?) ?? 1;
        // Desbloquear todos los grados desde 1 hasta warehouseLevel
        Set<int> grades = {for (var i = 1; i <= warehouseLevel; i++) i};

        for (var slot in slots) {
          final storage = Map<String, dynamic>.from(
            slot['storage'] as Map? ?? {},
          );

          storage.forEach((materialIdStr, data) {
            final units = (data['units'] as num?)?.toInt() ?? 0;
            final materialId = int.tryParse(materialIdStr) ?? 0;
            if (materialId > 0 && units > 0) {
              stock[materialId] = (stock[materialId] ?? 0) + units;
            }
          });
        }

        if (mounted) {
          setState(() {
            warehouseStock = stock;
            unlockedGrades = grades;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading warehouse stock: $e');
    }
  }

  void _filterAvailableMaterials() {
    if (factory == null) return;

    final materialIds = <int>{};

    for (var tierData in factory!.productionTiers) {
      if (tierData.tier <= currentTier) {
        materialIds.addAll(tierData.products.map((p) => p.materialId));
      }
    }

    if (materialIds.isEmpty) {
      availableMaterials = [];
      return;
    }

    // Solo mostrar si el grado está desbloqueado
    availableMaterials = allMaterials
        .where(
          (m) => materialIds.contains(m.id) && unlockedGrades.contains(m.grade),
        )
        .toList();
  }

  int _getMaxProducibleUnits(MaterialModel material) {
    if (material.components.isEmpty) {
      return _getMax24HourProduction(material);
    }

    int maxByStock = double.maxFinite.toInt();
    for (var component in material.components) {
      final stock = warehouseStock[component.materialId] ?? 0;
      final maxFromThisComponent = stock ~/ component.quantity;
      if (maxFromThisComponent < maxByStock) {
        maxByStock = maxFromThisComponent;
      }
    }

    final max24h = _getMax24HourProduction(material);
    return maxByStock < max24h ? maxByStock : max24h;
  }

  int _getMax24HourProduction(MaterialModel material) {
    for (var tierData in factory!.productionTiers) {
      if (tierData.tier <= currentTier) {
        final product = tierData.products
            .where((p) => p.materialId == material.id)
            .firstOrNull;
        if (product != null) {
          const secondsIn24Hours = 86400;
          return secondsIn24Hours ~/ product.productionTimeSeconds;
        }
      }
    }
    return 0;
  }

  Future<void> _addToQueue(MaterialModel material, int quantity) async {
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
                title: 'Cola Bloqueada',
                description:
                    'No puedes añadir a la cola mientras haya materiales almacenados. Por favor, recoge los materiales del almacén de la fábrica primero.',
              ),
            );
          }
          return;
        }
      }
    }

    // Calculate components needed
    Map<int, int> componentsNeeded = {};
    for (var component in material.components) {
      componentsNeeded[component.materialId] = component.quantity * quantity;
    }

    // Get production time info
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
    if (componentsNeeded.isNotEmpty) {
      materialsText =
          '\n\nMateriales necesarios (se deducirán al iniciar esta cola):\n\n';
      for (var entry in componentsNeeded.entries) {
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
          title: 'Añadir a Cola ${widget.queueSlot}',
          message:
              'Vas a añadir a la cola:\n$quantity unidades de ${material.name}\n\n⏱️ Tiempo estimado: $timeText$materialsText',
        ),
      );

      if (confirmed != true) return;

      // Add to production queue
      try {
        final factoriesRef = FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('factories_users')
            .doc(user.uid);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final factoriesSnapshot = await transaction.get(factoriesRef);

          if (!factoriesSnapshot.exists) {
            throw Exception('Datos de fábrica no encontrados');
          }

          final factoriesData = factoriesSnapshot.data()!;
          final factorySlots = List<Map<String, dynamic>>.from(
            factoriesData['slots'] ?? [],
          );

          final slotIndex = factorySlots.indexWhere(
            (s) => s['slotId'] == widget.slotId,
          );

          if (slotIndex != -1) {
            final queueKey = 'queue${widget.queueSlot}';

            // Convert componentsNeeded keys to strings for Firestore
            final componentsNeededForFirestore = <String, int>{};
            componentsNeeded.forEach((key, value) {
              componentsNeededForFirestore[key.toString()] = value;
            });

            // Ensure productionQueue is a Map, not a List
            if (factorySlots[slotIndex]['productionQueue'] is! Map) {
              factorySlots[slotIndex]['productionQueue'] = <String, dynamic>{};
            }

            // Prepare queue data
            final productionQueue = Map<String, dynamic>.from(
              factorySlots[slotIndex]['productionQueue'] ?? {},
            );
            productionQueue[queueKey] = {
              'materialId': material.id,
              'quantityPerHour': productionPerHour,
              'targetQuantity': quantity,
              'componentsNeeded': componentsNeededForFirestore,
            };
            factorySlots[slotIndex]['productionQueue'] = productionQueue;
          }

          transaction.update(factoriesRef, {'slots': factorySlots});
        });
        // Añadir experiencia al usuario y mostrar dialog si sube de nivel
        final totalVolume = quantity * material.unitVolumeM3;
        final xpToAdd = ExperienceService.calculateProduceXp(
          totalVolume,
          material.grade,
        );
        final userRef = FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid);
        final userSnapshot = await userRef.get();
        final currentXp = (userSnapshot.data()?['experience'] as int?) ?? 0;
        final oldLevel = ExperienceService.getLevelFromExperience(currentXp);
        final newXp = currentXp + xpToAdd;
        final newLevel = ExperienceService.getLevelFromExperience(newXp);
        await userRef.update({'experience': newXp});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Material añadido a la cola con éxito!'),
              backgroundColor: Colors.green,
            ),
          );
          if (newLevel > oldLevel) {
            showDialog(
              context: context,
              builder: (context) => LevelUpDialog(level: newLevel),
            );
          }
          Navigator.pop(context);
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

    if (factoryStatus == 'en espera') {
      return Scaffold(
        appBar: const CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'La fábrica está en espera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Debes iniciar la producción en la primera minicard antes de poder añadir materiales a la cola',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: availableMaterials.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Esta fábrica en Tier $currentTier no tiene productos disponibles para fabricar',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
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
    final canProduce = maxProducible > 0;
    final currentQuantity = productionQuantities[material.id] ?? 0.0;

    // Get production rate per hour
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
              'Máximo fabricable: $maxProducible unidades',
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
                      activeColor: Colors.blue,
                      inactiveColor: Colors.blue.withOpacity(0.3),
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
                label: 'Añadir a cola',
                onPressed: currentQuantity > 0
                    ? () => _addToQueue(material, currentQuantity.round())
                    : null,
                gradientTop: const Color(0xFF2196F3),
                gradientBottom: const Color(0xFF1565C0),
                borderColor: const Color(0xFF0D47A1),
                width: double.infinity,
                height: 50,
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'No hay suficientes materiales en el almacén para fabricar este producto',
                style: TextStyle(
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
