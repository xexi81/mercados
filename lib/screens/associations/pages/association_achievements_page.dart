import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class AssociationAchievementsPage extends StatelessWidget {
  const AssociationAchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              'LOGROS DE ASOCIACIÓN',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Próximamente',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
