import 'package:flutter/material.dart';

class FactoriesScreen extends StatelessWidget {
  const FactoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fábricas')),
      body: const Center(child: Text('Pantalla de Fábricas')),
    );
  }
}
