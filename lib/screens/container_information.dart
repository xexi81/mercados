import 'package:flutter/material.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class ContainerInformationScreen extends StatelessWidget {
  const ContainerInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomGameAppBar(),
      backgroundColor: Colors.black,
      body: SizedBox.shrink(),
    );
  }
}
