import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/screens/user_config_screen.dart';

class CustomGameAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomGameAppBar({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

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
        String? photoUrl = currentUser.photoURL;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            dinero = data['dinero'] ?? 0;
            gemas = data['gemas'] ?? 0;
            photoUrl = data['foto_url'] ?? currentUser.photoURL;
          }
        }

        return AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserConfigScreen(),
                  ),
                );
              },
              child: CircleAvatar(
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                backgroundColor: AppColors.primary,
                child: photoUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ),
          ),
          actions: [
            // Money display
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.attach_money,
                    color: Color(0xFFFFD700), // Gold color
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    NumberFormat('#,###').format(dinero),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            // Gems display
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.diamond,
                    color: Color(0xFF00D9FF), // Cyan/diamond color
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    NumberFormat('#,###').format(gemas),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
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
