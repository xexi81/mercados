import 'package:industrial_app/widgets/celebration_dialog.dart';
import 'package:flutter/material.dart';

import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:industrial_app/data/experience/experience_service.dart';

import 'package:industrial_app/widgets/custom_game_appbar.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      body: Center(
        child: IndustrialButton(
          width: MediaQuery.of(context).size.width * 0.5,
          height: MediaQuery.of(context).size.height * 0.08,
          label: 'Contratar',
          gradientTop: const Color(0xFFB8E354),
          gradientBottom: const Color(0xFF4A7515),
          borderColor: const Color(0xFF7BA82B),
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) return;
            final userDoc = await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(user.uid)
                .get();
            final experience = (userDoc.data()?['experience'] ?? 0) as int;
            await ExperienceService.loadExperienceData();
            final level = ExperienceService.getLevelFromExperience(experience);
            showDialog(
              context: context,
              builder: (context) =>
                  CelebrationDialog(bodyText: '¡Nivel $level alcanzado!'),
            );
          },
        ),
      ),
    );
  }
}
