import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/data/trucks/truck_model.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/data/materials/container_type.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';

class BuyTruckScreen extends StatefulWidget {
  final int fleetId;
  const BuyTruckScreen({super.key, required this.fleetId});

  @override
  State<BuyTruckScreen> createState() => _BuyTruckScreenState();
}

class _BuyTruckScreenState extends State<BuyTruckScreen> {
  late Future<List<TruckModel>> _trucksFuture;

  @override
  void initState() {
    super.initState();
    _trucksFuture = _loadTrucks();
  }

  Future<List<TruckModel>> _loadTrucks() async {
    final String jsonStr = await rootBundle.loadString(
      'assets/data/trucks.json',
    );
    final Map<String, dynamic> data = json.decode(jsonStr);
    final List trucksJson = data['trucks'] as List;
    return trucksJson.map((e) => TruckModel.fromJson(e)).toList();
  }

  Map<String, dynamic> _createTruckSkills(TruckModel truck) {
    return {
      'maxSpeedKmh': truck.maxSpeedKmh,
      'accidentRiskPercent': truck.accidentRiskPercent,
    };
  }

  Future<void> _handlePurchase(TruckModel truck) async {
    final bool? purchased = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'COMPRA DE CAMIÓN',
        description:
            '¿Estás seguro de que deseas comprar el camión ${truck.name}?',
        price: truck.purchaseCost.amount,
        priceType: truck.purchaseCost.type,
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

            // 2. Process User Funds
            final userData = userSnapshot.data()!;
            final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;
            final currentGems = (userData['gemas'] as num?)?.toInt() ?? 0;
            final cost = truck.purchaseCost.amount;
            final isMoney = truck.purchaseCost.type == UnlockCostType.money;

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

            // 3. Process Fleet Slots
            final fleetData = fleetSnapshot.data()!;
            List<dynamic> slots = List.from(fleetData['slots'] ?? []);

            // Find the index of the slot to update
            final slotIndex = slots.indexWhere(
              (s) => s['fleetId'] == widget.fleetId,
            );

            if (slotIndex == -1) {
              throw Exception(
                'Slot de flota no encontrado (ID: ${widget.fleetId})',
              );
            }

            // Clone the map and update truckId and truckSkills
            Map<String, dynamic> updatedSlot = Map<String, dynamic>.from(
              slots[slotIndex],
            );
            updatedSlot['truckId'] = truck.truckId;
            updatedSlot['truckSkills'] = _createTruckSkills(truck);

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
          content: Text('Comprado: ${truck.name}'),
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
      body: FutureBuilder<List<TruckModel>>(
        future: _trucksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No hay camiones disponibles',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          final trucks = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: trucks.length,
            itemBuilder: (context, index) {
              final truck = trucks[index];
              return _TruckCard(
                truck: truck,
                onTap: () => _handlePurchase(truck),
              );
            },
          );
        },
      ),
    );
  }
}

class _TruckCard extends StatelessWidget {
  final TruckModel truck;
  final VoidCallback? onTap;

  const _TruckCard({required this.truck, this.onTap});

  @override
  Widget build(BuildContext context) {
    const containerTypes = [
      ContainerType.bulkSolid,
      ContainerType.bulkLiquid,
      ContainerType.refrigerated,
      ContainerType.standard,
      ContainerType.heavy,
      ContainerType.hazardous,
    ];

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
                // 2. Title and Price on Top Row
                Positioned(
                  top: 8,
                  left: 17, // Align with bottom row
                  right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title (75% space, aligned left)
                      Expanded(
                        flex: 75,
                        child: Text(
                          truck.name,
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
                      // Price (25% space, aligned right, precise style)
                      Expanded(
                        flex: 25,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatPrice(truck.purchaseCost.amount),
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
                              truck.purchaseCost.type == UnlockCostType.money
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

                // 3. Central Content (3 Columns)
                Positioned(
                  top: 36, // Below title
                  bottom: 40, // Above containers
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      // Col 1: Truck Image (33%)
                      Expanded(
                        flex: 33,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.asset(
                            'assets/images/trucks/${truck.truckId}.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.local_shipping,
                                    size: 40, // Smaller icon for error
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      // Col 2: Speed & Risk
                      Expanded(
                        flex: 67,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatRow(
                              context,
                              'assets/images/trucks/velocidad.png',
                              '${truck.maxSpeedKmh} km/h',
                              'Velocidad Máxima',
                              'Velocidad punta del vehículo en km/h.',
                            ),
                            const SizedBox(height: 2),
                            _buildStatRow(
                              context,
                              'assets/images/trucks/accident_rist.png',
                              '${truck.accidentRiskPercent}%',
                              'Riesgo de Accidente',
                              'Probabilidad de sufrir percances en ruta.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. Container Type MiniCards (Bottom Left)
                Positioned(
                  left: 14,
                  // right: 3, // Removed 'right' anchor to avoid stretching across stats
                  bottom: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(
                      6,
                      (i) => Padding(
                        padding: EdgeInsets.only(right: i < 5 ? 5 : 0),
                        child: _TruckMiniCard(
                          imagePath:
                              'assets/images/containers/${containerTypes[i].name}.png',
                          showCross: !truck.allowedContainers.contains(
                            containerTypes[i],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(num amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      // Format as 12k, 120k, but maybe user prefers 12.000?
      // Keeping it short for space.
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toString();
  }

  Widget _buildStatRow(
    BuildContext context,
    String iconPath,
    String value,
    String title,
    String description,
  ) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Text(
              description,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Image.asset(iconPath, width: 22, height: 22, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

class _TruckMiniCard extends StatelessWidget {
  final String imagePath;
  final bool showCross;
  const _TruckMiniCard({required this.imagePath, this.showCross = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(),
            ),
            if (showCross)
              Image.asset(
                'assets/images/containers/cruz_roja.png',
                fit: BoxFit.contain,
              ),
          ],
        ),
      ),
    );
  }
}
