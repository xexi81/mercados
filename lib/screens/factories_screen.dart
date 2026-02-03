import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/factories/factory_slot_repository.dart';
import 'package:industrial_app/data/factories/factory_slot_model.dart';
import 'package:industrial_app/data/factories/factory_repository.dart';
import 'package:industrial_app/data/experience/experience_service.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/widgets/factory_card.dart';

class FactoriesScreen extends StatefulWidget {
  const FactoriesScreen({super.key});

  @override
  State<FactoriesScreen> createState() => _FactoriesScreenState();
}

class _FactoriesScreenState extends State<FactoriesScreen> {
  List<FactorySlotModel> _factorySlots = [];
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  /// Convierte startTime de Timestamp o int a millisegundos (int)
  int? _getStartTimeMs(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return null;
  }

  Future<void> _processCompletedProductions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final materials = await MaterialsRepository.loadMaterials();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final factoriesRef = FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('factories_users')
            .doc(user.uid);

        final factoriesSnapshot = await transaction.get(factoriesRef);
        if (!factoriesSnapshot.exists) return;

        final factoriesData = factoriesSnapshot.data()!;
        final factorySlots = List<Map<String, dynamic>>.from(
          factoriesData['slots'] ?? [],
        );

        bool needsUpdate = false;

        // Procesar cada slot de fábrica
        for (int slotIndex = 0; slotIndex < factorySlots.length; slotIndex++) {
          try {
            final slot = Map<String, dynamic>.from(factorySlots[slotIndex]);
            final currentProduction =
                slot['currentProduction'] is Map<String, dynamic>
                ? slot['currentProduction'] as Map<String, dynamic>
                : null;

            // Manejar productionQueue que puede ser Map o null
            final productionQueueRaw = slot['productionQueue'];
            final Map<String, dynamic> productionQueue =
                (productionQueueRaw is Map<String, dynamic>)
                ? productionQueueRaw
                : {};

            // Verificar si hay producción completada
            if (currentProduction != null) {
              final int? startTime = _getStartTimeMs(
                currentProduction['startTime'],
              );
              final double totalProductionSeconds =
                  (currentProduction['totalProductionSeconds'] as num?)
                      ?.toDouble() ??
                  0.0;

              if (startTime != null && totalProductionSeconds > 0) {
                final now = DateTime.now().millisecondsSinceEpoch;
                final elapsedSeconds = (now - startTime) / 1000;

                // Si la producción actual se completó
                if (elapsedSeconds >= totalProductionSeconds) {
                  final targetQuantity =
                      currentProduction['targetQuantity'] as int? ?? 0;
                  final materialId =
                      currentProduction['materialId'] as int? ?? 0;

                  // Calcular averagePrice del material producido
                  double averagePrice = 0.0;

                  // Obtener el material producido
                  final producedMaterial = materials
                      .where((m) => m.id == materialId)
                      .firstOrNull;

                  if (producedMaterial != null) {
                    if (producedMaterial.grade == 1) {
                      // Si es grado 1, el averagePrice es basePrice * 0.5
                      averagePrice = producedMaterial.basePrice * 0.5;
                    } else {
                      // Si no es grado 1, calcular como suma de componentes
                      double totalComponentCost = 0.0;
                      for (var component in producedMaterial.components) {
                        // Obtener el precio del componente desde materials
                        final componentMaterial = materials
                            .where((m) => m.id == component.materialId)
                            .firstOrNull;
                        final componentPrice =
                            componentMaterial?.basePrice ?? 0.0;
                        final componentCost =
                            component.quantity *
                            targetQuantity *
                            componentPrice;
                        totalComponentCost += componentCost;
                      }

                      if (targetQuantity > 0) {
                        averagePrice = totalComponentCost / targetQuantity;
                      }
                    }
                  }

                  // Mover producción completada a storedMaterials
                  List<dynamic> storedMaterials = List.from(
                    slot['storedMaterials'] ?? [],
                  );
                  storedMaterials.add({
                    'materialId': materialId,
                    'quantity': targetQuantity,
                    'averagePrice': averagePrice,
                  });

                  slot['storedMaterials'] = storedMaterials;

                  // Buscar la siguiente cola y moverla a currentProduction
                  bool foundNextQueue = false;
                  for (int i = 1; i <= 4; i++) {
                    final queueKey = 'queue$i';
                    if (productionQueue.containsKey(queueKey) &&
                        productionQueue[queueKey] != null) {
                      final queueData = productionQueue[queueKey];
                      final newMaterialId = queueData['materialId'] as int?;
                      final targetQty = queueData['targetQuantity'] as int?;

                      if (newMaterialId != null && targetQty != null) {
                        // Mover esta cola a currentProduction
                        slot['currentProduction'] = {
                          'materialId': newMaterialId,
                          'targetQuantity': targetQty,
                          'startTime': DateTime.now().millisecondsSinceEpoch,
                          'totalProductionSeconds':
                              queueData['totalProductionSeconds'] ?? 0,
                        };

                        // Eliminar esta cola y desplazar las siguientes
                        productionQueue.remove(queueKey);
                        for (int j = i + 1; j <= 4; j++) {
                          final nextQueueKey = 'queue$j';
                          final prevQueueKey = 'queue${j - 1}';
                          if (productionQueue.containsKey(nextQueueKey)) {
                            productionQueue[prevQueueKey] =
                                productionQueue[nextQueueKey];
                            productionQueue.remove(nextQueueKey);
                          }
                        }

                        slot['productionQueue'] = productionQueue;
                        slot['status'] = 'fabricando';
                        foundNextQueue = true;
                        break;
                      }
                    }
                  }

                  // Si no hay más colas, establecer estado a 'en espera'
                  if (!foundNextQueue) {
                    slot['currentProduction'] = null;
                    slot['status'] = 'en espera';
                  }

                  needsUpdate = true;
                }
              }
            }

            factorySlots[slotIndex] = slot;
          } catch (slotError) {
            debugPrint('Error processing slot at index $slotIndex: $slotError');
            continue;
          }
        }

        if (needsUpdate) {
          transaction.update(factoriesRef, {'slots': factorySlots});
        }
      });
    } catch (e) {
      debugPrint('Error processing completed productions: $e');
    }
  }

  Future<void> _initData() async {
    try {
      // Procesar producciones completadas primero
      await _processCompletedProductions();

      // Cargar factories en el cache
      await FactoryRepository.loadFactories();

      final slots = await FactorySlotRepository.loadFactorySlots();
      if (mounted) {
        setState(() {
          _factorySlots = slots;
          _isDataLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading factory slots: $e');
      if (mounted) {
        setState(() {
          _isDataLoaded = true;
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
      return const Scaffold(
        appBar: CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            appBar: CustomGameAppBar(),
            backgroundColor: AppColors.surface,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final int experience = userData?['experience'] ?? 0;
        final int level = ExperienceService.getLevelFromExperience(experience);

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .collection('factories_users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, factoriesSnapshot) {
            Map<String, dynamic> factoriesMap = {};
            if (factoriesSnapshot.hasData && factoriesSnapshot.data!.exists) {
              factoriesMap =
                  factoriesSnapshot.data?.data() as Map<String, dynamic>? ?? {};
            }

            final List<dynamic> slots = factoriesMap['slots'] ?? [];

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
                  childAspectRatio: 1.8,
                ),
                itemCount: _factorySlots.length,
                itemBuilder: (context, index) {
                  final slotConfig = _factorySlots[index];
                  final slotId = slotConfig.slotId;

                  final Map<String, dynamic>? cardData =
                      slots.firstWhere(
                            (s) => s['slotId'] == slotId,
                            orElse: () => null,
                          )
                          as Map<String, dynamic>?;

                  // Obtener nombre de la fábrica si existe
                  String? factoryName;
                  final int? factoryId = cardData?['factoryId'] as int?;
                  if (factoryId != null) {
                    // Buscar el factory model de forma síncrona usando el cache si está disponible
                    try {
                      final factory = FactoryRepository.getFactoryByIdSync(
                        factoryId,
                      );
                      factoryName = factory?.name;
                    } catch (e) {
                      debugPrint('Error getting factory name: $e');
                    }
                  }

                  return FactoryCard(
                    slotId: slotId,
                    slotConfig: slotConfig,
                    firestoreData: cardData,
                    userLevel: level,
                    factoryName: factoryName,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
