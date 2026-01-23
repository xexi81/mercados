import 'package:flutter/material.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart';

class ProductionQueueScreen extends StatefulWidget {
  final int slotId;
  final int factoryId;
  final int queueSlot;

  const ProductionQueueScreen({
    Key? key,
    required this.slotId,
    required this.factoryId,
    required this.queueSlot,
  }) : super(key: key);

  @override
  State<ProductionQueueScreen> createState() => _ProductionQueueScreenState();
}

class _ProductionQueueScreenState extends State<ProductionQueueScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Cola de Producción ${widget.queueSlot}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Slot ID: ${widget.slotId}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Factory ID: ${widget.factoryId}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Queue Slot: ${widget.queueSlot}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            const Text(
              'Aquí podrás programar los materiales a fabricar',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
