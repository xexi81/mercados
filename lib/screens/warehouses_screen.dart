import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/warehouse/warehouse_model.dart';
import 'package:industrial_app/data/warehouse/warehouse_repository.dart';
import 'package:industrial_app/data/experience/experience_service.dart';
import 'package:industrial_app/widgets/warehouse_card.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List<WarehouseModel> _warehouseConfigs = [];
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final warehouses = await WarehouseRepository.loadWarehouses();
      if (mounted) {
        setState(() {
          _warehouseConfigs = warehouses;
          _isDataLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading warehouses data: $e');
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
              .collection('warehouse_users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, warehouseSnapshot) {
            List<dynamic> slots = [];
            if (warehouseSnapshot.hasData && warehouseSnapshot.data!.exists) {
              final warehouseData =
                  warehouseSnapshot.data?.data() as Map<String, dynamic>? ?? {};
              slots = warehouseData['slots'] ?? [];
            }

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
                  childAspectRatio: 2.0,
                ),
                itemCount: 5, // 5 warehouse slots
                itemBuilder: (context, index) {
                  final warehouseId = index + 1;
                  final config = _warehouseConfigs.firstWhere(
                    (w) => w.id == warehouseId,
                    orElse: () => WarehouseModel(
                      id: warehouseId,
                      name: 'Unknown',
                      grade: 1,
                      requiredLevel: 999,
                      unlockCost: UnlockCost(type: 'money', amount: 0),
                      capacityM3: 0,
                    ),
                  );

                  final Map<String, dynamic>? cardData =
                      slots.firstWhere(
                            (s) => s['warehouseId'] == warehouseId,
                            orElse: () => null,
                          )
                          as Map<String, dynamic>?;

                  return WarehouseCard(
                    warehouseId: warehouseId,
                    warehouseConfig: config,
                    firestoreData: cardData,
                    userLevel: level,
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
