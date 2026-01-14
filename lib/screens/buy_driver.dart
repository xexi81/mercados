import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/data/drivers/driver_model.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';

class BuyDriverScreen extends StatefulWidget {
  final int fleetId;
  const BuyDriverScreen({super.key, required this.fleetId}); // Added fleetId

  @override
  State<BuyDriverScreen> createState() => _BuyDriverScreenState();
}

class _BuyDriverScreenState extends State<BuyDriverScreen> {
  late Future<List<DriverModel>> _driversFuture;

  @override
  void initState() {
    super.initState();
    _driversFuture = _loadDrivers();
  }

  Future<List<DriverModel>> _loadDrivers() async {
    final String jsonStr = await rootBundle.loadString(
      'assets/data/drivers.json',
    );
    final Map<String, dynamic> data = json.decode(jsonStr);
    final List driversJson = data['drivers'] as List;
    return driversJson.map((e) => DriverModel.fromJson(e)).toList();
  }

  Future<void> _handlePurchase(DriverModel driver) async {
    final bool? purchased = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'COMPRAR CONDUCTOR',
        description: '¿Estás seguro de que deseas contratar al ${driver.name}?',
        price: driver.hireCost.amount,
        priceType: driver.hireCost.type,
        onConfirm: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) throw Exception('Usuario no identificado');

          final userDocRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid);
          final fleetDocRef = FirebaseFirestore.instance
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
            final cost = driver.hireCost.amount;
            final isMoney = driver.hireCost.type == UnlockCostType.money;

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

            // Clone the map and update driverId
            Map<String, dynamic> updatedSlot = Map<String, dynamic>.from(
              slots[slotIndex],
            );
            updatedSlot['driverId'] = driver.driverId;

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
          content: Text('Contratado: ${driver.name}'),
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
      body: FutureBuilder<List<DriverModel>>(
        future: _driversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No hay conductores disponibles',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          final drivers = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return _DriverCard(
                driver: driver,
                onTap: () => _handlePurchase(driver),
              );
            },
          );
        },
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final DriverModel driver;
  final VoidCallback? onTap;

  const _DriverCard({required this.driver, this.onTap});

  @override
  Widget build(BuildContext context) {
    const double borderRadiusValue = 24;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.8, // Taller to fit new stats layout
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
                      // Title
                      Expanded(
                        flex: 75,
                        child: Text(
                          driver.name,
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
                              _formatPrice(driver.hireCost.amount),
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
                              driver.hireCost.type == UnlockCostType.money
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
                  bottom:
                      12, // More space for content as there are no pills at bottom
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      // Col 1: Driver Image (33%)
                      Expanded(
                        flex: 33,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.asset(
                            'assets/images/drivers/${driver.driverId}.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      // Col 2: All Stats Centered
                      Expanded(
                        flex: 65,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatRow(
                              context,
                              'assets/images/trucks/velocidad.png',
                              '+${driver.bonuses.speedBonusPercent}%',
                              'Bonificación de Velocidad',
                              'Aumenta la velocidad media de la flota en este porcentaje.',
                            ),
                            const SizedBox(height: 1),
                            _buildStatRow(
                              context,
                              'assets/images/trucks/fuel_100km.png',
                              '-${driver.bonuses.fuelConsumptionReductionPercent}%',
                              'Reducción de Consumo',
                              'Porcentaje de reducción en el consumo de combustible.',
                            ),
                            const SizedBox(height: 1),
                            _buildStatRow(
                              context,
                              'assets/images/trucks/accident_rist.png',
                              '-${driver.bonuses.accidentRiskReductionPercent}%',
                              'Reducción de Accidentes',
                              'Porcentaje de reducción en la probabilidad de accidentes.',
                            ),
                          ],
                        ),
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

  String _formatPrice(num amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
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
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            iconPath,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.info_outline, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}
