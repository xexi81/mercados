import 'package:flutter/material.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class DriverInformationScreen extends StatelessWidget {
  final int driverId;
  final int fleetId;

  const DriverInformationScreen({
    super.key,
    required this.driverId,
    required this.fleetId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: Colors.black,
      body: Container(
        alignment: Alignment.center,
        child: const Text(
          'Driver Information - To Be Implemented',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
