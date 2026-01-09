import 'package:flutter/material.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';

class LoadManagerScreen extends StatelessWidget {
  const LoadManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: Center(
        child: Text(
          'LOAD MANAGER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
