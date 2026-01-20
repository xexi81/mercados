import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/locations/location_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/widgets/industrial_button.dart';

class LoadManagerScreen extends StatefulWidget {
  final int fleetId;
  const LoadManagerScreen({super.key, required this.fleetId});

  @override
  State<LoadManagerScreen> createState() => _LoadManagerScreenState();
}

class _LoadManagerScreenState extends State<LoadManagerScreen> {
  Map<String, dynamic>? fleetData;
  Map<String, dynamic>? truckSkills;
  Map<String, dynamic>? containerSkills;
  int fleetLevel = 1;
  Map<String, dynamic>? truckLoad;
  Map<String, dynamic>? currentLocation;
  bool isLoading = true;

  // Market data from Firestore
  Map<String, dynamic> firestoreMaterials = {};

  // Market purchase variables
  bool isAtMarket = false;
  List<String> materialCategories = [];
  String? selectedCategory;
  List<Map<String, dynamic>> availableMaterials = [];
  Map<String, dynamic>? selectedMaterial;
  int purchaseQuantity = 1;
  double totalPrice = 0.0;
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );

  @override
  void initState() {
    super.initState();
    _loadFleetData();
  }

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadFleetData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Load market data from Firestore first
      await _loadMarketData();

      final fleetDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('fleet_users')
          .doc(user.uid)
          .get();

      if (fleetDoc.exists) {
        final data = fleetDoc.data()!;
        final slots = List<Map<String, dynamic>>.from(data['slots'] ?? []);
        final slot = slots.firstWhere(
          (s) => s['fleetId'] == widget.fleetId,
          orElse: () => <String, dynamic>{},
        );

        if (slot.isNotEmpty) {
          setState(() {
            fleetData = slot;
            truckLoad = slot['truckLoad'] as Map<String, dynamic>?;
            currentLocation = slot['currentLocation'] as Map<String, dynamic>?;
            fleetLevel = slot['fleetLevel'] as int? ?? 1;
            truckSkills = slot['truckSkills'] as Map<String, dynamic>?;
            containerSkills = slot['containerSkills'] as Map<String, dynamic>?;
            isLoading = false;
          });

          // Check if at market and load material categories
          await _checkMarketStatus();
          if (isAtMarket) {
            await _loadMaterialCategories();
          }
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMarketData() async {
    try {
      final materialsSnapshot = await FirebaseFirestore.instance
          .collection('materials')
          .get();
      final firestoreData = <String, dynamic>{};
      for (var doc in materialsSnapshot.docs) {
        if (doc.id == 'global') {
          final data = doc.data();
          for (var value in data.values) {
            if (value is List) {
              for (var item in value) {
                if (item is Map && item.containsKey('materialId')) {
                  firestoreData[item['materialId'].toString()] = item;
                }
              }
            }
          }
        } else {
          firestoreData[doc.id] = doc.data();
        }
      }
      setState(() {
        firestoreMaterials = firestoreData;
      });
    } catch (e) {
      // Ignore errors, will use default values
    }
  }

  double _calculateMaxCapacity() {
    if (containerSkills == null) return 0;
    final baseCapacity =
        (containerSkills!['capacityM3'] as num?)?.toDouble() ?? 0;
    final capacityUpgrade =
        (fleetData?['containerCapacityUpgrade'] as num?)?.toInt() ?? 0;
    return (baseCapacity + (capacityUpgrade * 10)) * fleetLevel;
  }

  double _calculateCurrentLoad() {
    if (truckLoad == null) return 0;
    double totalM3 = 0;
    truckLoad!.forEach((materialId, data) {
      final units = (data['units'] as num?)?.toDouble() ?? 0;
      final m3PerUnit = (data['m3PerUnit'] as num?)?.toDouble() ?? 0;
      totalM3 += units * m3PerUnit;
    });
    return totalM3;
  }

  Future<String> _getLocationName() async {
    if (currentLocation == null) return 'Ubicación desconocida';
    try {
      final lat = (currentLocation!['latitude'] as num).toDouble();
      final lng = (currentLocation!['longitude'] as num).toDouble();
      final locations = await LocationsRepository.loadLocations();
      final location = locations.firstWhere(
        (l) => l.latitude == lat && l.longitude == lng,
        orElse: () => LocationModel(
          id: -1,
          city: 'Desconocido',
          latitude: lat,
          longitude: lng,
          countryIso: 'XX',
          hasMarket: false,
        ),
      );
      return location.city;
    } catch (e) {
      return 'Ubicación desconocida';
    }
  }

  Future<void> _checkMarketStatus() async {
    if (currentLocation == null) return;
    try {
      final lat = (currentLocation!['latitude'] as num).toDouble();
      final lng = (currentLocation!['longitude'] as num).toDouble();
      final locations = await LocationsRepository.loadLocations();
      final location = locations.firstWhere(
        (l) => l.latitude == lat && l.longitude == lng,
        orElse: () => LocationModel(
          id: -1,
          city: 'Desconocido',
          latitude: lat,
          longitude: lng,
          countryIso: 'XX',
          hasMarket: false,
        ),
      );
      setState(() {
        isAtMarket = location.hasMarket;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadMaterialCategories() async {
    try {
      final materialsJson = await rootBundle.loadString(
        'assets/data/materials.json',
      );
      final materialsData = json.decode(materialsJson);
      final materials = materialsData['materials'] as List;
      final categories = <String>{};
      for (final material in materials) {
        categories.add(material['category'] as String);
      }
      setState(() {
        materialCategories = categories.toList()..sort();
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadMaterialsForCategory(String category) async {
    if (!isAtMarket) return;
    try {
      final materialsJson = await rootBundle.loadString(
        'assets/data/materials.json',
      );
      final materialsData = json.decode(materialsJson);
      final materials = materialsData['materials'] as List;

      // Get current location's marketIndex
      final lat = (currentLocation!['latitude'] as num).toDouble();
      final lng = (currentLocation!['longitude'] as num).toDouble();
      final locations = await LocationsRepository.loadLocations();
      final location = locations.firstWhere(
        (l) => l.latitude == lat && l.longitude == lng,
        orElse: () => LocationModel(
          id: -1,
          city: 'Desconocido',
          latitude: lat,
          longitude: lng,
          countryIso: 'XX',
          hasMarket: false,
        ),
      );

      final marketIndex = location.marketIndex ?? 0;

      // Filter materials by category
      final filteredMaterials = materials
          .where((m) => m['category'] == category)
          .map((m) {
            // Find market data for current marketIndex from Firestore
            final materialId = m['id'].toString();
            final firestoreData = firestoreMaterials[materialId];
            final markets = (firestoreData?['markets'] as List<dynamic>?) ?? [];
            final marketData = markets.firstWhere(
              (market) => market['marketIndex'] == marketIndex,
              orElse: () => {
                'marketIndex': marketIndex,
                'priceMultiplier': 1.0,
                'stockBase': 1000,
                'stockCurrent': 500,
              },
            );

            return {
              ...m,
              'priceMultiplier': marketData['priceMultiplier'] ?? 1.0,
              'stockBase': marketData['stockBase'] ?? 1000,
              'stockCurrent': marketData['stockCurrent'] ?? 500,
            };
          })
          .toList();

      setState(() {
        availableMaterials = filteredMaterials
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        selectedMaterial = null;
        purchaseQuantity = 1;
        totalPrice = 0.0;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  double _calculateUnitPrice(Map<String, dynamic> material, int unitIndex) {
    final basePrice = (material['basePrice'] as num).toDouble();
    final priceMultiplier = (material['priceMultiplier'] as num).toDouble();
    final stockBase = (material['stockBase'] as num).toDouble();
    final stockCurrent = (material['stockCurrent'] as num).toDouble();

    // Modifier decreases as stock decreases
    final modifier = 100 - ((stockBase / (stockCurrent - unitIndex)) * 100);
    final clampedModifier = modifier.clamp(
      0.1,
      2.0,
    ); // Prevent negative or too high prices

    return basePrice * priceMultiplier * clampedModifier;
  }

  double _calculateTotalPrice(Map<String, dynamic> material, int quantity) {
    double total = 0.0;
    for (int i = 0; i < quantity; i++) {
      total += _calculateUnitPrice(material, i);
    }
    return total;
  }

  Future<void> _purchaseMaterial() async {
    if (selectedMaterial == null || purchaseQuantity <= 0) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final totalCost = _calculateTotalPrice(selectedMaterial!, purchaseQuantity);

    // Check if user has enough money and capacity
    final userDocRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid);
    final fleetDocRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('fleet_users')
        .doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocRef);
        final fleetSnapshot = await transaction.get(fleetDocRef);

        if (!userSnapshot.exists || !fleetSnapshot.exists) {
          throw Exception('Datos no encontrados');
        }

        final userData = userSnapshot.data()!;
        final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;

        if (currentMoney < totalCost) {
          throw Exception('Dinero insuficiente');
        }

        // Check capacity
        final fleetData = fleetSnapshot.data()!;
        final slots = List<Map<String, dynamic>>.from(fleetData['slots'] ?? []);
        final slotIndex = slots.indexWhere(
          (s) => s['fleetId'] == widget.fleetId,
        );
        if (slotIndex == -1) {
          throw Exception('Flota no encontrada');
        }

        final slot = slots[slotIndex];
        final currentTruckLoad =
            slot['truckLoad'] as Map<String, dynamic>? ?? {};
        final materialId = selectedMaterial!['id'].toString();

        // Calculate new load
        final existingUnits =
            (currentTruckLoad[materialId]?['units'] as num?)?.toInt() ?? 0;
        final newUnits = existingUnits + purchaseQuantity;
        final m3PerUnit = (selectedMaterial!['unitVolumeM3'] as num).toDouble();

        // Check capacity
        double totalLoad = 0.0;
        currentTruckLoad.forEach((id, data) {
          if (id != materialId) {
            final units = (data['units'] as num?)?.toDouble() ?? 0;
            final m3 = (data['m3PerUnit'] as num?)?.toDouble() ?? 0;
            totalLoad += units * m3;
          }
        });
        totalLoad += newUnits * m3PerUnit;

        final maxCapacity = _calculateMaxCapacity();
        if (totalLoad > maxCapacity) {
          throw Exception('Capacidad insuficiente en el contenedor');
        }

        // Update money
        transaction.update(userDocRef, {
          'dinero': currentMoney - totalCost.toInt(),
        });

        // Update truck load
        final updatedTruckLoad = Map<String, dynamic>.from(currentTruckLoad);
        updatedTruckLoad[materialId] = {
          'units': newUnits,
          'm3PerUnit': m3PerUnit,
        };

        slots[slotIndex]['truckLoad'] = updatedTruckLoad;
        transaction.update(fleetDocRef, {'slots': slots});
      });

      // Refresh data
      await _loadFleetData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Compra realizada exitosamente')),
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

  List<Widget> _buildMaterialContent() {
    if (selectedCategory != null && availableMaterials.isNotEmpty) {
      return [
        SizedBox(
          height: 300, // Fixed height for scrollable list
          child: selectedMaterial == null
              // Show materials list when no material is selected
              ? ListView.builder(
                  itemCount: availableMaterials.length,
                  itemBuilder: (context, index) {
                    final material = availableMaterials[index];
                    final materialId = material['id'].toString();
                    final name = material['name'] as String;
                    final iconPath = 'assets/images/materials/$materialId.png';
                    final stockCurrent = material['stockCurrent'] as int;
                    final unitPrice = _calculateUnitPrice(material, 0);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedMaterial = material;
                            purchaseQuantity = 1;
                            totalPrice = _calculateTotalPrice(material, 1);
                            quantityController.text = '1';
                          });
                        },
                        child: Row(
                          children: [
                            Image.asset(
                              iconPath,
                              width: 40,
                              height: 40,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Stock: $stockCurrent',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Precio unitario: ${unitPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              // Show selected material details when material is selected
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/materials/${selectedMaterial!['id']}.png',
                              width: 60,
                              height: 60,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey,
                                    child: const Icon(
                                      Icons.inventory,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedMaterial!['name'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Stock disponible: ${selectedMaterial!['stockCurrent']}',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Precio base: ${(selectedMaterial!['basePrice'] as num).toDouble().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Precio unitario: ${_calculateUnitPrice(selectedMaterial!, 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Purchase controls
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Cantidad:',
                                  style: TextStyle(color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                    controller: quantityController,
                                    onChanged: (value) {
                                      final qty = int.tryParse(value) ?? 1;
                                      setState(() {
                                        purchaseQuantity = qty.clamp(1, 999);
                                        totalPrice = _calculateTotalPrice(
                                          selectedMaterial!,
                                          purchaseQuantity,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Total: ${totalPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: IndustrialButton(
                                    label: 'Cancelar',
                                    onPressed: () {
                                      setState(() {
                                        selectedMaterial = null;
                                        purchaseQuantity = 1;
                                        totalPrice = 0.0;
                                        quantityController.text = '1';
                                      });
                                    },
                                    gradientTop: const Color(0xFF757575),
                                    gradientBottom: const Color(0xFF424242),
                                    borderColor: const Color(0xFF212121),
                                    height: 50,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: IndustrialButton(
                                    label: 'Comprar',
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => GenericPurchaseDialog(
                                          title: 'COMPRAR MATERIAL',
                                          description:
                                              '¿Confirmar compra de $purchaseQuantity unidades de ${selectedMaterial!['name']}?',
                                          price: totalPrice.toInt(),
                                          priceType: UnlockCostType.money,
                                          onConfirm: () async => true,
                                        ),
                                      );

                                      if (confirmed == true) {
                                        await _purchaseMaterial();
                                      }
                                    },
                                    gradientTop: const Color(0xFF4CAF50),
                                    gradientBottom: const Color(0xFF2E7D32),
                                    borderColor: const Color(0xFF1B5E20),
                                    height: 50,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ];
    } else if (selectedCategory != null) {
      return [
        Center(
          child: Text(
            'No hay materiales disponibles en esta categoría',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ];
    } else {
      return [];
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

    final maxCapacity = _calculateMaxCapacity();
    final currentLoad = _calculateCurrentLoad();
    final loadPercentage = maxCapacity > 0
        ? (currentLoad / maxCapacity).clamp(0.0, 1.0)
        : 0.0;

    final purchaseSection = isAtMarket
        ? [
            const SizedBox(height: 20),
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
                    'Compra de Materiales',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    dropdownColor: AppColors.surface,
                    style: TextStyle(color: Colors.white),
                    items: materialCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                        selectedMaterial = null;
                        purchaseQuantity = 1;
                        totalPrice = 0.0;
                        quantityController.text = '1';
                      });
                      if (value != null) {
                        _loadMaterialsForCategory(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Materials list or selected material details
                  ..._buildMaterialContent(),
                ],
              ),
            ),
          ]
        : [];

    final currentLoadSection = (truckLoad != null && truckLoad!.isNotEmpty)
        ? [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
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
                      'Carga Actual',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200, // Fixed height for scrollable list
                      child: ListView.builder(
                        itemCount: truckLoad!.length,
                        itemBuilder: (context, index) {
                          final materialId = truckLoad!.keys.elementAt(index);
                          final data =
                              truckLoad![materialId] as Map<String, dynamic>;
                          final units = data['units'] as int? ?? 0;
                          final m3PerUnit =
                              (data['m3PerUnit'] as num?)?.toDouble() ?? 0;
                          final totalM3 = units * m3PerUnit;

                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _getMaterialInfo(materialId),
                            builder: (context, snapshot) {
                              final materialInfo = snapshot.data;
                              final iconPath =
                                  materialInfo?['icon'] as String? ??
                                  'assets/images/materials/default.png';
                              final name =
                                  materialInfo?['name'] as String? ??
                                  'Material $materialId';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      iconPath,
                                      width: 40,
                                      height: 40,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
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
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '$units unidades',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
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
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]
        : [];

    return Scaffold(
      appBar: CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: Padding(
        padding: const EdgeInsets.only(
          top: 16.0,
          left: 16.0,
          right: 16.0,
          bottom: 64.0, // Extra padding for bottom navigation bar
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: FutureBuilder<String>(
                  future: _getLocationName(),
                  builder: (context, snapshot) {
                    final locationName = snapshot.data ?? 'Cargando...';
                    return Text(
                      'Gestión de Carga - $locationName',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Capacity display - full width
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
                      'Capacidad del Contenedor',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                  ],
                ),
              ),
              // Current load display - only show if there's load
              ...currentLoadSection,
              // Material purchase section - only show if at market
              ...purchaseSection,
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getMaterialInfo(String materialId) async {
    try {
      final materialsJson = await rootBundle.loadString(
        'assets/data/materials.json',
      );
      final materialsData = json.decode(materialsJson);
      final materials = materialsData['materials'] as List;
      return materials.firstWhere(
        (m) => m['materialId'].toString() == materialId,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }
}
