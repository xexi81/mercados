import 'package:flutter/material.dart';

class RetailScreen extends StatelessWidget {
  const RetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retail')),
      body: const Center(child: Text('Pantalla de Datos de Retail')),
    );
  }
}
