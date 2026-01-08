import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/screens/user_config_screen.dart';

import 'package:industrial_app/data/experience/experience_service.dart';

class CustomGameAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool isMainScreen;

  const CustomGameAppBar({Key? key, this.isMainScreen = false})
    : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(100);

  @override
  State<CustomGameAppBar> createState() => _CustomGameAppBarState();
}

class _CustomGameAppBarState extends State<CustomGameAppBar> {
  @override
  void initState() {
    super.initState();
    ExperienceService.loadExperienceData();
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return AppBar(
        title: const Text('Mapa de la Ciudad'),
        backgroundColor: AppColors.surface,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Default values
        int dinero = 0;
        int gemas = 0;
        int experience = 0;
        String? photoUrl = currentUser.photoURL;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            dinero = data['dinero'] ?? 0;
            gemas = data['gemas'] ?? 0;
            experience = data['experience'] ?? 0;
            photoUrl = data['foto_url'] ?? currentUser.photoURL;
          }
        }

        int level = 1;
        try {
          level = ExperienceService.getLevelFromExperience(experience);
        } catch (e) {
          debugPrint('Error calculating level: $e');
        }

        return AppBar(
          toolbarHeight: 100,
          backgroundColor: AppColors.surface,
          elevation: 0,
          leadingWidth: widget.isMainScreen ? 120 : 150,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isMainScreen)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                GestureDetector(
                  onTap: () {
                    if (widget.isMainScreen) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserConfigScreen(),
                        ),
                      );
                    }
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        backgroundColor: AppColors.primary,
                        child: photoUrl == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 28),

                        child: Text(
                          '$level',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Money display
                  _CurrencyDisplay(
                    imagePath: 'assets/images/billete.png',
                    amount: dinero,
                    color: const Color(0xFFFFD700),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -15),
                    child: _CurrencyDisplay(
                      imagePath: 'assets/images/gemas.png',
                      amount: gemas,
                      color: const Color(0xFF00D9FF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CurrencyDisplay extends StatelessWidget {
  final String imagePath;
  final int amount;
  final Color color;

  const _CurrencyDisplay({
    required this.imagePath,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(imagePath, width: 50, height: 50, fit: BoxFit.contain),
        const SizedBox(width: 12),
        Text(
          NumberFormat('#,###').format(amount),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
