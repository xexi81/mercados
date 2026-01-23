import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/confirmation_dialog.dart';

class QueueManagementScreen extends StatefulWidget {
  final int slotId;
  final int factoryId;

  const QueueManagementScreen({
    Key? key,
    required this.slotId,
    required this.factoryId,
  }) : super(key: key);

  @override
  State<QueueManagementScreen> createState() => _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen> {
  List<MaterialModel> allMaterials = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await MaterialsRepository.loadMaterials();
      if (mounted) {
        setState(() {
          allMaterials = materials;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading materials: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteQueue(int queueNumber) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Eliminar Cola',
        message:
            '¿Estás seguro de que deseas eliminar la cola $queueNumber?\n\nLas colas siguientes avanzarán automáticamente.',
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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
          final productionQueueData =
              factorySlots[slotIndex]['productionQueue'];

          if (productionQueueData is Map<String, dynamic>) {
            final productionQueue = Map<String, dynamic>.from(
              productionQueueData,
            );

            // Remove current queue
            final currentQueueKey = 'queue$queueNumber';
            productionQueue.remove(currentQueueKey);

            // Shift remaining queues forward
            for (int i = queueNumber + 1; i <= 4; i++) {
              final nextQueueKey = 'queue$i';
              if (productionQueue.containsKey(nextQueueKey)) {
                final prevQueueKey = 'queue${i - 1}';
                productionQueue[prevQueueKey] = productionQueue[nextQueueKey];
                productionQueue.remove(nextQueueKey);
              }
            }

            factorySlots[slotIndex]['productionQueue'] = productionQueue;
          }
        }

        transaction.update(factoriesRef, {'slots': factorySlots});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cola eliminada con éxito'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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

          final productionQueueData = slot['productionQueue'];

          if (productionQueueData is! Map<String, dynamic>) {
            return Center(
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
                    const Text(
                      'No hay colas de producción configuradas',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Build list of queue cards for queues 1-4
          final List<Widget> queueCards = [];
          for (int i = 1; i <= 4; i++) {
            final queueKey = 'queue$i';
            final queueData = productionQueueData[queueKey];

            if (queueData != null) {
              queueCards.add(_buildQueueCard(i, queueData));
              queueCards.add(const SizedBox(height: 16));
            }
          }

          if (queueCards.isEmpty) {
            return Center(
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
                    const Text(
                      'No hay colas de producción activas',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: queueCards),
          );
        },
      ),
    );
  }

  Widget _buildQueueCard(int queueNumber, Map<String, dynamic> queueData) {
    // Get material info
    final materialId = queueData['materialId'];
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

    final targetQuantity = queueData['targetQuantity'] ?? 0;
    final quantityPerHour =
        (queueData['quantityPerHour'] as num?)?.toDouble() ?? 0.0;
    final componentsNeeded =
        queueData['componentsNeeded'] as Map<String, dynamic>? ?? {};

    return Card(
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
            // Title
            Text(
              'Cola $queueNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Material image and info
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
                          fontSize: 20,
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
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Production info
            _buildInfoRow('📦 Cantidad objetivo:', '$targetQuantity unidades'),
            const SizedBox(height: 12),
            _buildInfoRow(
              '⚡ Producción:',
              '${quantityPerHour.toStringAsFixed(2)} unidades/hora',
            ),

            // Components needed
            if (componentsNeeded.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Materiales necesarios:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...componentsNeeded.entries.map((entry) {
                final componentMaterialId = int.tryParse(entry.key) ?? 0;
                final componentMaterial = allMaterials.firstWhere(
                  (m) => m.id == componentMaterialId,
                  orElse: () => MaterialModel(
                    id: componentMaterialId,
                    name: 'Material $componentMaterialId',
                    grade: 1,
                    category: 'Desconocido',
                    components: [],
                    basePrice: 0,
                    unitVolumeM3: 1.0,
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.asset(
                            componentMaterial.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${componentMaterial.name}: ${entry.value} unidades',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 32),

            // Delete button
            IndustrialButton(
              label: 'Eliminar cola',
              onPressed: () => _deleteQueue(queueNumber),
              gradientTop: const Color(0xFFE53935),
              gradientBottom: const Color(0xFFB71C1C),
              borderColor: const Color(0xFF8B0000),
              width: double.infinity,
              height: 50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
