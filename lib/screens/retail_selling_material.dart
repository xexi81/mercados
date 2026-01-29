import 'package:flutter/material.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';

class RetailSellingMaterialScreen extends StatelessWidget {
  const RetailSellingMaterialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: Center(
        child: Text(
          'Retail Selling Material Screen',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
