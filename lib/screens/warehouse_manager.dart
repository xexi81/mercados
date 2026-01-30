import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/warehouse/warehouse_repository.dart';
import 'package:industrial_app/data/warehouse/warehouse_model.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';

class WarehouseManagerScreen extends StatefulWidget {
  final int warehouseId;

  const WarehouseManagerScreen({super.key, required this.warehouseId});

  @override
  State<WarehouseManagerScreen> createState() => _WarehouseManagerScreenState();
}

class _WarehouseManagerScreenState extends State<WarehouseManagerScreen> {
  WarehouseModel? warehouseConfig;
  Map<String, dynamic>? warehouseData;
  bool isLoading = true;
  Map<String, double> sellAmounts = {};

  @override
  void initState() {
    super.initState();
    _loadWarehouseData();
  }

  Future<void> _loadWarehouseData() async {
    try {
      final config = await WarehouseRepository.getWarehouseById(
        widget.warehouseId,
      );

      if (mounted) {
        setState(() {
          warehouseConfig = config;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  double _calculateMaxCapacity(int level) {
    if (warehouseConfig == null) return 0.0;
    return warehouseConfig!.capacityM3 + (level * 100);
  }

  double _calculateCurrentLoad(Map<String, dynamic> storage) {
    double totalM3 = 0;
    storage.forEach((materialId, data) {
      final units = (data['units'] as num?)?.toDouble() ?? 0;
      final m3PerUnit = (data['m3PerUnit'] as num?)?.toDouble() ?? 0;
      totalM3 += units * m3PerUnit;
    });
    return totalM3;
  }

  Future<Map<String, dynamic>?> _getMaterialInfo(String materialId) async {
    try {
      final materialsJson = await rootBundle.loadString(
        'assets/data/materials.json',
      );
      final materialsData = json.decode(materialsJson);
      final materials = materialsData['materials'] as List;
      return materials.firstWhere(
        (m) => m['id'].toString() == materialId,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  String _getContainerDisplayName(String code) {
    switch (code) {
      case 'BULK_SOLID':
        return 'Granel sólido';
      case 'BULK_LIQUID':
        return 'Granel líquido';
      case 'REFRIGERATED':
        return 'Refrigerado';
      case 'STANDARD':
        return 'Contenedor estándar';
      case 'HEAVY':
        return 'Carga pesada';
      case 'HAZARDOUS':
        return 'Peligroso';
      default:
        return code;
    }
  }

  Future<void> _sellMaterial(
    String materialId,
    Map<String, dynamic>? materialInfo,
    int availableUnits,
  ) async {
    final unitsToSell = (sellAmounts[materialId] ?? 0).toInt();
    if (unitsToSell <= 0) return;

    // Get base price from material info (10% of base price)
    final basePrice = (materialInfo?['basePrice'] as num?)?.toDouble() ?? 0;
    final sellPricePerUnit = basePrice * 0.1;
    final totalSellPrice = sellPricePerUnit * unitsToSell;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GenericPurchaseDialog(
        title: 'Vender Material',
        description:
            '¿Deseas vender $unitsToSell unidades de ${materialInfo?['name'] ?? materialId}?\n\nPrecio de venta: ${sellPricePerUnit.toStringAsFixed(2)} por unidad (10% del precio base)\n\nTotal a recibir: \$${totalSellPrice.toStringAsFixed(2)}',
        price: totalSellPrice.toInt(),
        priceType: UnlockCostType.money,
        onConfirm: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) throw Exception('Usuario no autenticado');

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            // Read warehouse and user data
            final warehouseRef = FirebaseFirestore.instance
                .collection('usuarios')
                .doc(user.uid)
                .collection('warehouse_users')
                .doc(user.uid);

            final userRef = FirebaseFirestore.instance
                .collection('usuarios')
                .doc(user.uid);

            final warehouseSnapshot = await transaction.get(warehouseRef);
            final userSnapshot = await transaction.get(userRef);

            if (!warehouseSnapshot.exists || !userSnapshot.exists) return;

            // Update warehouse storage
            final warehouseData = warehouseSnapshot.data()!;
            final slots = List<Map<String, dynamic>>.from(
              warehouseData['slots'] ?? [],
            );

            final slotIndex = slots.indexWhere(
              (s) => s['warehouseId'] == widget.warehouseId,
            );
            if (slotIndex == -1) return;

            final storage = Map<String, dynamic>.from(
              slots[slotIndex]['storage'] as Map<String, dynamic>? ?? {},
            );

            if (!storage.containsKey(materialId)) return;

            final currentUnits =
                (storage[materialId]['units'] as num?)?.toInt() ?? 0;

            if (currentUnits <= unitsToSell) {
              storage.remove(materialId);
            } else {
              storage[materialId] = {
                'units': currentUnits - unitsToSell,
                'm3PerUnit': storage[materialId]['m3PerUnit'],
                'averagePrice': storage[materialId]['averagePrice'],
              };
            }

            slots[slotIndex]['storage'] = storage;

            // Update user money
            final userData = userSnapshot.data()!;
            final currentMoney = (userData['dinero'] as num?)?.toDouble() ?? 0;
            final newMoney = currentMoney + totalSellPrice;

            // Write updates
            transaction.update(warehouseRef, {'slots': slots});
            transaction.update(userRef, {'dinero': newMoney});
          });

          // Reset slider
          setState(() {
            sellAmounts[materialId] = 0;
          });
        },
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vendiste $unitsToSell unidades por \$${totalSellPrice.toStringAsFixed(2)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        appBar: CustomGameAppBar(),
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (isLoading) {
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
          .collection('warehouse_users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            appBar: CustomGameAppBar(),
            backgroundColor: AppColors.surface,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final slots = List<Map<String, dynamic>>.from(data?['slots'] ?? []);

        final warehouseSlot = slots.firstWhere(
          (s) => s['warehouseId'] == widget.warehouseId,
          orElse: () => <String, dynamic>{},
        );

        if (warehouseSlot.isEmpty) {
          return Scaffold(
            appBar: const CustomGameAppBar(),
            backgroundColor: AppColors.surface,
            body: Center(
              child: Text(
                'Almacén no encontrado',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final int warehouseLevel =
            (warehouseSlot['level'] as int?) ??
            (warehouseSlot['warehouseLevel'] as int?) ??
            0;
        final Map<String, dynamic> storage =
            warehouseSlot['storage'] as Map<String, dynamic>? ?? {};
        final double maxCapacity = _calculateMaxCapacity(warehouseLevel);
        final double currentLoad = _calculateCurrentLoad(storage);
        final double loadPercentage = maxCapacity > 0
            ? (currentLoad / maxCapacity).clamp(0.0, 1.0)
            : 0.0;

        return Scaffold(
          appBar: const CustomGameAppBar(),
          backgroundColor: AppColors.surface,
          body: Padding(
            padding: const EdgeInsets.only(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              bottom: 64.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Gestión de Almacén',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Capacity display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Capacidad del Almacén',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Máxima: ${maxCapacity.toStringAsFixed(1)} m³',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Actual: ${currentLoad.toStringAsFixed(1)} m³',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        // Progress bar
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: loadPercentage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: loadPercentage > 0.9
                                    ? Colors.red
                                    : Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(loadPercentage * 100).toStringAsFixed(1)}% lleno',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nivel: $warehouseLevel',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Grado de materiales: ${warehouseConfig?.grade ?? 1}',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stored materials section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(15, 23, 42, 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromRGBO(255, 255, 255, 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Materiales Almacenados',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        if (storage.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No hay materiales almacenados',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: storage.length,
                            itemBuilder: (context, index) {
                              final materialId = storage.keys.elementAt(index);
                              final data =
                                  storage[materialId] as Map<String, dynamic>;
                              final units =
                                  (data['units'] as num?)?.toInt() ?? 0;
                              final m3PerUnit =
                                  (data['m3PerUnit'] as num?)?.toDouble() ?? 0;
                              final averagePrice =
                                  (data['averagePrice'] as num?)?.toDouble() ??
                                  0.0;
                              final totalM3 = units * m3PerUnit;

                              return FutureBuilder<Map<String, dynamic>?>(
                                future: _getMaterialInfo(materialId),
                                builder: (context, snapshot) {
                                  final materialInfo = snapshot.data;
                                  final iconPath = materialInfo != null
                                      ? 'assets/images/materials/${materialInfo['id']}.png'
                                      : 'assets/images/materials/default.png';
                                  final name =
                                      materialInfo?['name'] as String? ??
                                      'Material $materialId';

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: const Color.fromRGBO(0, 0, 0, 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Image.asset(
                                              iconPath,
                                              width: 40,
                                              height: 40,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Container(
                                                    width: 40,
                                                    height: 40,
                                                    color: Colors.grey,
                                                    child: const Icon(
                                                      Icons.inventory,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    '$units unidades',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (materialInfo != null &&
                                                      (materialInfo['allowedContainers']
                                                                  as List?)
                                                              ?.isNotEmpty ==
                                                          true)
                                                    Text(
                                                      'Contenedores: ${(materialInfo['allowedContainers'] as List).map((code) => _getContainerDisplayName(code)).join(', ')}',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  if (averagePrice > 0)
                                                    Text(
                                                      'Precio medio: ${averagePrice.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        color: Colors.white60,
                                                        fontSize: 11,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '${totalM3.toStringAsFixed(2)} m³',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Vender: ${(sellAmounts[materialId] ?? 0).toInt()} unidades',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Slider(
                                                    value:
                                                        sellAmounts[materialId] ??
                                                        0,
                                                    min: 0,
                                                    max: units.toDouble(),
                                                    divisions: units > 0
                                                        ? units
                                                        : null,
                                                    activeColor:
                                                        AppColors.primary,
                                                    inactiveColor:
                                                        Colors.white24,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        sellAmounts[materialId] =
                                                            value;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        IndustrialButton(
                                          label: 'Vender Material',
                                          onPressed:
                                              (sellAmounts[materialId] ?? 0) > 0
                                              ? () => _sellMaterial(
                                                  materialId,
                                                  materialInfo,
                                                  units,
                                                )
                                              : null,
                                          gradientTop: const Color(0xFFFF9800),
                                          gradientBottom: const Color(
                                            0xFFF57C00,
                                          ),
                                          borderColor: const Color(0xFFE65100),
                                          width: double.infinity,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                      ],
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
}
