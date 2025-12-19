import 'package:flutter/material.dart';

class ParkingScreen extends StatelessWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parking de Camiones')),
      body: const Center(child: Text('Pantalla de Parking de Camiones')),
    );
  }
}
