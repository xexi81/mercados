import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/factories/factory_slot_repository.dart';
import 'package:industrial_app/data/factories/factory_slot_model.dart';
import 'package:industrial_app/data/experience/experience_service.dart';
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

  Future<void> _initData() async {
    try {
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
                  childAspectRatio: 2.0,
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

                  return FactoryCard(
                    slotId: slotId,
                    slotConfig: slotConfig,
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
