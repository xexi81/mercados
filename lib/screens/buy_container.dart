import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/containers/container_model.dart';
import 'package:industrial_app/data/trucks/truck_model.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';

class BuyContainerScreen extends StatefulWidget {
  final int fleetId;
  const BuyContainerScreen({super.key, required this.fleetId});

  @override
  State<BuyContainerScreen> createState() => _BuyContainerScreenState();
}

class _BuyContainerScreenState extends State<BuyContainerScreen> {
  late Future<List<ContainerModel>> _containersFuture;

  @override
  void initState() {
    super.initState();
    _containersFuture = _loadContainers();
  }

  Future<List<ContainerModel>> _loadContainers() async {
    final String jsonStr = await rootBundle.loadString(
      'assets/data/container.json',
    );
    final Map<String, dynamic> data = json.decode(jsonStr);
    final List containersJson = data['containers'] as List;
    return containersJson.map((e) => ContainerModel.fromJson(e)).toList();
  }

  Future<List<TruckModel>> _loadTrucks() async {
    final String jsonStr = await rootBundle.loadString(
      'assets/data/trucks.json',
    );
    final Map<String, dynamic> data = json.decode(jsonStr);
    final List trucksJson = data['trucks'] as List;
    return trucksJson.map((e) => TruckModel.fromJson(e)).toList();
  }

  Map<String, dynamic> _createContainerSkills(ContainerModel container) {
    return {
      'capacityM3': container.capacityM3,
      'loadingSpeedPercent': container.bonuses.loadingSpeedPercent,
      'damageRiskReductionPercent':
          container.bonuses.damageRiskReductionPercent,
    };
  }

  Future<TruckModel?> _getTruckById(int truckId) async {
    final trucks = await _loadTrucks();
    try {
      return trucks.firstWhere((truck) => truck.truckId == truckId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _handlePurchase(ContainerModel container) async {
    final bool? purchased = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'COMPRAR CONTENEDOR',
        description:
            '¿Estás seguro de que deseas comprar el contenedor ${container.name}?',
        price: container.purchaseCost.amount,
        priceType: container.purchaseCost.type,
        onConfirm: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) throw Exception('Usuario no identificado');

          final userDocRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid);
          final fleetDocRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .collection('fleet_users')
              .doc(user.uid);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            // 1. Read all needed docs first
            final userSnapshot = await transaction.get(userDocRef);
            final fleetSnapshot = await transaction.get(fleetDocRef);

            if (!userSnapshot.exists) throw Exception('Usuario no encontrado');
            if (!fleetSnapshot.exists)
              throw Exception('Datos de flota no encontrados');

            // 2. Validate fleet slot has truck assigned
            final fleetData = fleetSnapshot.data()!;
            List<dynamic> slots = List.from(fleetData['slots'] ?? []);

            final slotIndex = slots.indexWhere(
              (s) => s['fleetId'] == widget.fleetId,
            );

            if (slotIndex == -1) {
              throw Exception(
                'Slot de flota no encontrado (ID: ${widget.fleetId})',
              );
            }

            final currentSlot = slots[slotIndex];
            final truckId = currentSlot['truckId'];

            if (truckId == null || truckId.toString().trim().isEmpty) {
              throw Exception(
                'Debes asignar un camión antes de comprar un contenedor',
              );
            }

            // 3. Validate container type is allowed by truck
            final truck = await _getTruckById(truckId);
            if (truck == null) {
              throw Exception('Camión no encontrado');
            }

            if (!truck.allowedContainers.contains(container.type)) {
              throw Exception(
                'Este contenedor no es compatible con el camión ${truck.name}',
              );
            }

            // 4. Process User Funds
            final userData = userSnapshot.data()!;
            final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;
            final currentGems = (userData['gemas'] as num?)?.toInt() ?? 0;
            final cost = container.purchaseCost.amount;
            final isMoney = container.purchaseCost.type == UnlockCostType.money;

            if (isMoney) {
              if (currentMoney < cost) {
                throw Exception('Dinero insuficiente');
              }
              transaction.update(userDocRef, {'dinero': currentMoney - cost});
            } else {
              if (currentGems < cost) {
                throw Exception('Gemas insuficientes');
              }
              transaction.update(userDocRef, {'gemas': currentGems - cost});
            }

            // 5. Process Fleet Slots
            // Clone the map and update containerId and containerSkills
            Map<String, dynamic> updatedSlot = Map<String, dynamic>.from(
              slots[slotIndex],
            );
            updatedSlot['containerId'] = container.containerId;
            updatedSlot['containerSkills'] = _createContainerSkills(container);

            slots[slotIndex] = updatedSlot;

            transaction.update(fleetDocRef, {'slots': slots});
          });
        },
      ),
    );

    if (purchased == true && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comprado: ${container.name}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<ContainerModel>>(
        future: _containersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No hay contenedores disponibles',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          final containers = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: containers.length,
            itemBuilder: (context, index) {
              final container = containers[index];
              return _ContainerCard(
                container: container,
                onTap: () => _handlePurchase(container),
              );
            },
          );
        },
      ),
    );
  }
}

class _ContainerCard extends StatelessWidget {
  final ContainerModel container;
  final VoidCallback? onTap;

  const _ContainerCard({required this.container, this.onTap});

  String _formatPrice(num amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    const double borderRadiusValue = 24;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 2.2,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadiusValue),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadiusValue - 2),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      top: 18,
                      bottom: 18,
                    ),
                    child: Image.asset(
                      'assets/images/containers/${container.containerId}.png',
                      fit: BoxFit.contain,
                      height: double.infinity,
                      width: null,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.inventory,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                // Title and Price on Top Row
                Positioned(
                  top: 8,
                  left: 17,
                  right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Expanded(
                        flex: 75,
                        child: Text(
                          container.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Price
                      Expanded(
                        flex: 25,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatPrice(container.purchaseCost.amount),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(1, 1),
                                        blurRadius: 2,
                                        color: Colors.black.withOpacity(0.8),
                                      ),
                                    ],
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Image.asset(
                              container.purchaseCost.type ==
                                      UnlockCostType.money
                                  ? 'assets/images/billete.png'
                                  : 'assets/images/gemas.png',
                              width: 18,
                              height: 18,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _CharacteristicCard(
                        icon: Icons.inventory,
                        value: '${container.capacityM3} m³',
                        label: 'Capacidad',
                        description:
                            'Capacidad máxima de carga del contenedor en metros cúbicos.',
                      ),
                      const SizedBox(height: 8),
                      _CharacteristicCard(
                        icon: Icons.speed,
                        value: '${container.bonuses.loadingSpeedPercent}%',
                        label: 'Velocidad de carga',
                        description:
                            'Modificador de velocidad de carga y descarga. Valores positivos aumentan la velocidad.',
                      ),
                      const SizedBox(height: 8),
                      _CharacteristicCard(
                        icon: Icons.security,
                        value:
                            '${container.bonuses.damageRiskReductionPercent}%',
                        label: 'Reducción daño',
                        description:
                            'Porcentaje de reducción del riesgo de daño durante el transporte.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacteristicCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String description;

  const _CharacteristicCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(label, style: const TextStyle(color: Colors.white)),
            content: Text(
              description,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
