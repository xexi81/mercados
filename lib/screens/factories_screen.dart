import 'package:flutter/material.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class FactoriesScreen extends StatelessWidget {
  const FactoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      body: const Center(child: Text('Pantalla de Fábricas')),
    );
  }
}
