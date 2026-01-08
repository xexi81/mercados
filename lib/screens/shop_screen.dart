import 'package:flutter/material.dart';
import 'package:industrial_app/widgets/industrial_button.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tienda')),
      body: Center(
        child: IndustrialButton(
          width: MediaQuery.of(context).size.width * 0.5,
          height: MediaQuery.of(context).size.height * 0.08,
          label: 'Contratar',
          gradientTop: const Color(0xFFB8E354), // Verde muy claro arriba
          gradientBottom: const Color(0xFF4A7515), // Verde muy oscuro abajo
          borderColor: const Color(0xFF7BA82B),
          onPressed: () {
            // Acción al presionar
            print('Botón presionado');
          },
        ),
      ),
    );
  }
}
