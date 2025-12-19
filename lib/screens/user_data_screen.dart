import 'package:flutter/material.dart';

class UserDataScreen extends StatelessWidget {
  const UserDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de Usuario')),
      body: const Center(child: Text('Pantalla de Datos de Usuario')),
    );
  }
}
