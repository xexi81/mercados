import 'package:flutter/material.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class TruckInformationScreen extends StatelessWidget {
  final int truckId;
  final int fleetId;

  const TruckInformationScreen({
    super.key,
    required this.truckId,
    required this.fleetId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor:
          Colors.black, // Assuming black background like other screens
      body: Container(
        alignment: Alignment.center,
        child: const Text(
          'Truck Information - To Be Implemented',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
