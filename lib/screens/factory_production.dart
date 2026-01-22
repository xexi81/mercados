import 'package:flutter/material.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class FactoryProductionScreen extends StatefulWidget {
  final int slotId;
  final int factoryId;

  const FactoryProductionScreen({
    Key? key,
    required this.slotId,
    required this.factoryId,
  }) : super(key: key);

  @override
  State<FactoryProductionScreen> createState() =>
      _FactoryProductionScreenState();
}

class _FactoryProductionScreenState extends State<FactoryProductionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Producción de Fábrica',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text('Slot ID: ${widget.slotId}'),
            Text('Factory ID: ${widget.factoryId}'),
          ],
        ),
      ),
    );
  }
}
