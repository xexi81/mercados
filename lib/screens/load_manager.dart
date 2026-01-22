import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/locations/location_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/widgets/material_purchase_controls.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/generic_purchase_dialog.dart';
import 'package:industrial_app/data/fleet/unlock_cost_type.dart';
import 'package:industrial_app/data/experience/experience_service.dart';

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
  String? fleetStatus; // Fleet status: 'en marcha', 'en destino', etc.
  bool isLoading = true;
  bool allowsMultipleProducts = true;
  double userMoney = 0.0;

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
    _initializeData();
  }

  Future<void> _initializeData() async {
    await ExperienceService.loadExperienceData();
    await _loadFleetData();
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

      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
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
          // Get allowsMultipleProducts
          final containerId = slot['containerId'] as int?;
          if (containerId != null) {
            allowsMultipleProducts = await _getAllowsMultipleProducts(
              containerId,
            );
          }

          // Get user money
          final userData = userDoc.data();
          userMoney = (userData?['dinero'] as num?)?.toDouble() ?? 0.0;
          print('DEBUG: User money loaded from Firebase = $userMoney');

          setState(() {
            fleetData = slot;
            truckLoad = slot['truckLoad'] as Map<String, dynamic>?;
            currentLocation = slot['currentLocation'] as Map<String, dynamic>?;
            fleetLevel = slot['fleetLevel'] as int? ?? 1;
            fleetStatus = slot['status'] as String?; // Load fleet status
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

  int _calculateMaxQuantity(Map<String, dynamic> material) {
    final maxCapacity = _calculateMaxCapacity();
    final currentLoad = _calculateCurrentLoad();
    final remainingCapacity = maxCapacity - currentLoad;
    final unitVolumeM3 = (material['unitVolumeM3'] as num?)?.toDouble() ?? 0;
    if (unitVolumeM3 <= 0) return 0;
    final maxQty = (remainingCapacity / unitVolumeM3).floor();
    return maxQty.clamp(0, 999);
  }

  int _calculateMaxAffordableQuantity(Map<String, dynamic> material) {
    final unitPrice = _calculateUnitPrice(material, 0);
    print(
      'DEBUG _calculateMaxAffordableQuantity: material=${material['name']}, stockCurrent=${material['stockCurrent']}, unitPrice=$unitPrice, userMoney=$userMoney',
    );
    if (unitPrice <= 0) return 0;
    final maxQty = (userMoney / unitPrice).floor();
    return maxQty.clamp(0, 999);
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

      // Get container type
      final containerType = await _getContainerType();

      // Filter materials by container compatibility
      final compatibleMaterials = materials
          .where(
            (m) =>
                containerType == null ||
                (m['allowedContainers'] as List).contains(containerType),
          )
          .toList();

      // Collect categories from compatible materials
      final categories = <String>{};
      for (final material in compatibleMaterials) {
        categories.add(material['category'] as String);
      }

      setState(() {
        materialCategories = categories.toList()..sort();
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<String?> _getContainerType() async {
    final containerId = fleetData?['containerId'] as int?;
    if (containerId == null) return null;
    try {
      final containersJson = await rootBundle.loadString(
        'assets/data/container.json',
      );
      final containersData = json.decode(containersJson);
      final containers = containersData['containers'] as List;
      final container = containers.firstWhere(
        (c) => c['containerId'] == containerId,
        orElse: () => null,
      );
      if (container != null) {
        return container['type'] as String;
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  Future<bool> _getAllowsMultipleProducts(int containerId) async {
    try {
      final containersJson = await rootBundle.loadString(
        'assets/data/container.json',
      );
      final containersData = json.decode(containersJson);
      final containers = containersData['containers'] as List;
      final container = containers.firstWhere(
        (c) => c['containerId'] == containerId,
        orElse: () => null,
      );
      if (container != null) {
        return container['allowsMultipleProducts'] as bool? ?? true;
      }
    } catch (e) {
      // Ignore
    }
    return true;
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

      // Get container type
      final containerType = await _getContainerType();

      // Filter materials by category and container compatibility
      var filteredMaterials = materials
          .where(
            (m) =>
                m['category'] == category &&
                (containerType == null ||
                    (m['allowedContainers'] as List).contains(containerType)),
          )
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

      // If container doesn't allow multiple products and there's already load, only allow the loaded material
      if (!allowsMultipleProducts &&
          truckLoad != null &&
          truckLoad!.isNotEmpty) {
        final loadedMaterialIds = truckLoad!.keys.toSet();
        filteredMaterials = filteredMaterials
            .where((m) => loadedMaterialIds.contains(m['id'].toString()))
            .toList();
      }

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
    final stockCurrent = (material['stockCurrent'] as num).toDouble();

    // If no stock available, return 0
    if (stockCurrent <= unitIndex) return 0;

    // Price = basePrice * priceMultiplier
    return basePrice * priceMultiplier;
  }

  double _calculateTotalPrice(Map<String, dynamic> material, int quantity) {
    double total = 0.0;
    for (int i = 0; i < quantity; i++) {
      total += _calculateUnitPrice(material, i);
    }
    return total;
  }

  Future<double> _calculateSellPrice(String materialId) async {
    try {
      // Get material base price from assets
      final materialsJson = await rootBundle.loadString(
        'assets/data/materials.json',
      );
      final materialsData = json.decode(materialsJson);
      final materials = materialsData['materials'] as List;
      final material = materials.firstWhere(
        (m) => m['id'].toString() == materialId,
        orElse: () => null,
      );

      if (material == null) return 0.0;

      final basePrice = (material['basePrice'] as num).toDouble();

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

      // Get priceMultiplier from Firestore
      final firestoreData = firestoreMaterials[materialId];
      final markets = (firestoreData?['markets'] as List<dynamic>?) ?? [];
      final marketData = markets.firstWhere(
        (market) => market['marketIndex'] == marketIndex,
        orElse: () => {'marketIndex': marketIndex, 'priceMultiplier': 1.0},
      );

      final priceMultiplier = (marketData['priceMultiplier'] as num).toDouble();

      // Sell price = basePrice * (priceMultiplier - 0.1)
      return basePrice * (priceMultiplier - 0.1);
    } catch (e) {
      print('Error calculating sell price: $e');
      return 0.0;
    }
  }

  Future<void> _sellMaterial(String materialId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
        // ALL READS FIRST
        final userSnapshot = await transaction.get(userDocRef);
        final fleetSnapshot = await transaction.get(fleetDocRef);

        if (!userSnapshot.exists || !fleetSnapshot.exists) {
          throw Exception('Datos no encontrados');
        }

        final userData = userSnapshot.data()!;
        final currentMoney = (userData['dinero'] as num?)?.toInt() ?? 0;

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

        if (!currentTruckLoad.containsKey(materialId)) {
          throw Exception('Material no encontrado en la carga');
        }

        final materialData =
            currentTruckLoad[materialId] as Map<String, dynamic>;
        final units = materialData['units'] as int;
        final m3PerUnit =
            (materialData['m3PerUnit'] as num?)?.toDouble() ?? 0.0;
        final averagePrice =
            (materialData['averagePrice'] as num?)?.toDouble() ?? 0.0;

        // Get material info to calculate experience
        final materialInfo = await _getMaterialInfo(materialId);
        final materialGrade = materialInfo?['grade'] as int? ?? 1;
        final totalVolume = units * m3PerUnit;

        // Calculate sell price
        final sellPrice = await _calculateSellPrice(materialId);
        final totalSellPrice = (sellPrice * units).toInt();

        // Calculate experience gained from this sale
        final xpGained = ExperienceService.calculateSaleXp(
          totalVolume,
          materialGrade,
        );

        // ALL WRITES AFTER ALL READS
        // Get current experience
        final currentExperience =
            (userData['experience'] as num?)?.toInt() ?? 0;

        // Update money and experience
        transaction.update(userDocRef, {
          'dinero': currentMoney + totalSellPrice,
          'experience': currentExperience + xpGained,
        });

        // Remove material from truck load
        final updatedTruckLoad = Map<String, dynamic>.from(currentTruckLoad);
        updatedTruckLoad.remove(materialId);

        slots[slotIndex]['truckLoad'] = updatedTruckLoad;
        transaction.update(fleetDocRef, {'slots': slots});
      });

      // Refresh data
      await _loadFleetData();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Venta realizada exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
        // ALL READS MUST BE DONE FIRST
        final userSnapshot = await transaction.get(userDocRef);
        final fleetSnapshot = await transaction.get(fleetDocRef);

        // Read material document for stock update
        final materialId = selectedMaterial!['id'].toString();
        final materialDocRef = FirebaseFirestore.instance
            .collection('materials')
            .doc(materialId);
        final materialSnapshot = await transaction.get(materialDocRef);

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

        // ALL WRITES MUST BE DONE AFTER ALL READS
        // Calculate experience gained from this purchase
        final materialGrade = selectedMaterial!['grade'] as int? ?? 1;
        final totalVolume = purchaseQuantity * m3PerUnit;
        final xpGained = ExperienceService.calculatePurchaseXp(
          totalVolume,
          materialGrade,
        );

        // Get current experience
        final currentExperience =
            (userData['experience'] as num?)?.toInt() ?? 0;

        // Update money and experience
        transaction.update(userDocRef, {
          'dinero': currentMoney - totalCost.toInt(),
          'experience': currentExperience + xpGained,
        });

        // Calculate average price for the material
        final currentUnitPrice = totalCost / purchaseQuantity;
        final existingAveragePrice =
            (currentTruckLoad[materialId]?['averagePrice'] as num?)
                ?.toDouble() ??
            0.0;

        double newAveragePrice;
        if (existingUnits == 0) {
          // First purchase of this material
          newAveragePrice = currentUnitPrice;
        } else {
          // Calculate weighted average: (oldPrice * oldUnits + newPrice * newUnits) / totalUnits
          newAveragePrice =
              (existingAveragePrice * existingUnits +
                  currentUnitPrice * purchaseQuantity) /
              newUnits;
        }

        // Update truck load
        final updatedTruckLoad = Map<String, dynamic>.from(currentTruckLoad);
        updatedTruckLoad[materialId] = {
          'units': newUnits,
          'm3PerUnit': m3PerUnit,
          'averagePrice': newAveragePrice,
        };

        slots[slotIndex]['truckLoad'] = updatedTruckLoad;
        transaction.update(fleetDocRef, {'slots': slots});

        // Update stockCurrent in materials collection
        if (materialSnapshot.exists) {
          final materialData = materialSnapshot.data()!;
          final markets = List<Map<String, dynamic>>.from(
            materialData['markets'] ?? [],
          );

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

          // Find and update the market with the current marketIndex
          final marketIndexInList = markets.indexWhere(
            (market) => market['marketIndex'] == marketIndex,
          );

          if (marketIndexInList != -1) {
            final currentStock =
                markets[marketIndexInList]['stockCurrent'] as int;
            markets[marketIndexInList]['stockCurrent'] =
                currentStock - purchaseQuantity;

            transaction.update(materialDocRef, {'markets': markets});
          }
        }
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
      if (selectedMaterial == null) {
        // Lista de materiales
        return [
          SizedBox(
            height: 300,
            child: ListView.builder(
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
                    color: const Color.fromRGBO(0, 0, 0, 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.1),
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
            ),
          ),
        ];
      } else {
        // Vista de material seleccionado y controles de compra
        return [
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
                  errorBuilder: (context, error, stackTrace) => Container(
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
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        'Volumen unitario: ${(selectedMaterial!['unitVolumeM3'] as num).toString()} m³',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        'Precio unitario: ${_calculateUnitPrice(selectedMaterial!, 0).toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          MaterialPurchaseControls(
            selectedMaterial: selectedMaterial!,
            userMoney: userMoney,
            quantityController: quantityController,
            onCancel: () {
              setState(() {
                selectedMaterial = null;
                purchaseQuantity = 1;
                totalPrice = _calculateTotalPrice(selectedMaterial!, 1);
                quantityController.text = '1';
              });
            },
            onPurchase: (qty) async {
              setState(() {
                purchaseQuantity = qty;
                totalPrice = _calculateTotalPrice(selectedMaterial!, qty);
              });
              await _purchaseMaterial();
              setState(() {
                purchaseQuantity = 1;
                totalPrice = _calculateTotalPrice(selectedMaterial!, 1);
                quantityController.text = '1';
              });
            },
            onPurchaseMax: (qty) async {
              setState(() {
                purchaseQuantity = qty;
                totalPrice = _calculateTotalPrice(selectedMaterial!, qty);
                quantityController.text = qty.toString();
              });
              await _purchaseMaterial();
              setState(() {
                purchaseQuantity = 1;
                totalPrice = _calculateTotalPrice(selectedMaterial!, 1);
                quantityController.text = '1';
              });
            },
            calculateMaxQuantity: _calculateMaxQuantity,
            calculateMaxAffordableQuantity: _calculateMaxAffordableQuantity,
            calculateTotalPrice: _calculateTotalPrice,
          ),
        ];
      }
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

    // Determine if we should show purchase/sale options based on status
    final bool showMarketFeatures =
        fleetStatus == 'en destino' || fleetStatus == null;
    final bool canPurchase =
        isAtMarket && loadPercentage < 1.0 && showMarketFeatures;
    List<Widget>? purchaseSection;
    if (canPurchase) {
      purchaseSection = [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(15, 23, 42, 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.3)),
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
                      color: const Color.fromRGBO(255, 255, 255, 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
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
      ];
    } else {
      purchaseSection = [];
    }

    List<Widget> currentLoadSection;
    if (truckLoad != null && truckLoad!.isNotEmpty) {
      currentLoadSection = [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(15, 23, 42, 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.3)),
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: truckLoad!.length,
                itemBuilder: (context, index) {
                  final materialId = truckLoad!.keys.elementAt(index);
                  final data = truckLoad![materialId] as Map<String, dynamic>;
                  final units = data['units'] as int? ?? 0;
                  final m3PerUnit =
                      (data['m3PerUnit'] as num?)?.toDouble() ?? 0;
                  final averagePrice =
                      (data['averagePrice'] as num?)?.toDouble() ?? 0.0;
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
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(0, 0, 0, 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                                    '$units unidades',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (averagePrice > 0)
                                    Text(
                                      'Precio medio: ${averagePrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
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
            ],
          ),
        ),
      ];
    } else {
      currentLoadSection = [];
    }

    // Sell materials section
    List<Widget> sellSection;
    if (isAtMarket &&
        truckLoad != null &&
        truckLoad!.isNotEmpty &&
        showMarketFeatures) {
      sellSection = [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(15, 23, 42, 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Venta de Materiales',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: truckLoad!.length,
                itemBuilder: (context, index) {
                  final materialId = truckLoad!.keys.elementAt(index);
                  final data = truckLoad![materialId] as Map<String, dynamic>;
                  final units = data['units'] as int? ?? 0;
                  final m3PerUnit =
                      (data['m3PerUnit'] as num?)?.toDouble() ?? 0;
                  final averagePrice =
                      (data['averagePrice'] as num?)?.toDouble() ?? 0.0;
                  final totalM3 = units * m3PerUnit;

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getMaterialInfo(materialId),
                    builder: (context, materialSnapshot) {
                      final materialInfo = materialSnapshot.data;
                      final iconPath = materialInfo != null
                          ? 'assets/images/materials/${materialInfo['id']}.png'
                          : 'assets/images/materials/default.png';
                      final name =
                          materialInfo?['name'] as String? ??
                          'Material $materialId';

                      return FutureBuilder<double>(
                        future: _calculateSellPrice(materialId),
                        builder: (context, priceSnapshot) {
                          final sellPricePerUnit = priceSnapshot.data ?? 0.0;
                          final totalSellPrice = sellPricePerUnit * units;

                          return Container(
                            padding: const EdgeInsets.all(12),
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
                                            '$units unidades • ${totalM3.toStringAsFixed(2)} m³',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (averagePrice > 0)
                                            Text(
                                              'Precio medio compra: ${averagePrice.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Precio de venta',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      '${totalSellPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Precio unitario venta: ${sellPricePerUnit.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: SizedBox(
                                    width: 120,
                                    child: IndustrialButton(
                                      label: 'Vender',
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) =>
                                              GenericPurchaseDialog(
                                                title: 'VENDER MATERIAL',
                                                description:
                                                    '¿Confirmar venta de $units unidades de $name?',
                                                price: totalSellPrice.toInt(),
                                                priceType: UnlockCostType.money,
                                                onConfirm: () async => true,
                                              ),
                                        );
                                        if (confirmed == true) {
                                          await _sellMaterial(materialId);
                                        }
                                      },
                                      gradientTop: const Color(0xFFFF9800),
                                      gradientBottom: const Color(0xFFF57C00),
                                      borderColor: const Color(0xFFE65100),
                                      height: 40,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ];
    } else {
      sellSection = [];
    }

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
              if (currentLoadSection.isNotEmpty &&
                  (purchaseSection.isNotEmpty || sellSection.isNotEmpty))
                const SizedBox(height: 20),
              // Material sell section - only show if at market and has load
              ...sellSection,
              if (sellSection.isNotEmpty && purchaseSection.isNotEmpty)
                const SizedBox(height: 20),
              // Add spacing before purchase section if no other sections above it
              if (currentLoadSection.isEmpty &&
                  sellSection.isEmpty &&
                  purchaseSection.isNotEmpty)
                const SizedBox(height: 20),
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
        (m) => m['id'].toString() == materialId,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }
}
