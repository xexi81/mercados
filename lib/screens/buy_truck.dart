import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:industrial_app/data/trucks/truck_model.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class BuyTruckScreen extends StatefulWidget {
  const BuyTruckScreen({super.key});

  @override
  State<BuyTruckScreen> createState() => _BuyTruckScreenState();
}

class _BuyTruckScreenState extends State<BuyTruckScreen> {
  late Future<List<TruckModel>> _trucksFuture;

  @override
  void initState() {
    super.initState();
    _trucksFuture = _loadTrucks();
  }

  Future<List<TruckModel>> _loadTrucks() async {
    final String jsonStr = await rootBundle.loadString(
      'assets/data/trucks.json',
    );
    final Map<String, dynamic> data = json.decode(jsonStr);
    final List trucksJson = data['trucks'] as List;
    return trucksJson.map((e) => TruckModel.fromJson(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<TruckModel>>(
        future: _trucksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No hay camiones disponibles',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          final trucks = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: trucks.length,
            itemBuilder: (context, index) {
              final truck = trucks[index];
              return _TruckCard(truck: truck);
            },
          );
        },
      ),
    );
  }
}

class _TruckCard extends StatelessWidget {
  final TruckModel truck;
  const _TruckCard({required this.truck});

  @override
  Widget build(BuildContext context) {
    const double borderRadiusValue = 24;
    return AspectRatio(
      aspectRatio: 2.2,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadiusValue - 2),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 18, bottom: 18),
                  child: Image.asset(
                    'assets/images/trucks/${truck.truckId}.png',
                    fit: BoxFit.contain,
                    height: double.infinity,
                    width: null,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.local_shipping,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    truck.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 3,
                bottom: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(
                    6,
                    (i) => Padding(
                      padding: EdgeInsets.only(right: i < 5 ? 5 : 0),
                      child: _TruckMiniCard(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TruckMiniCard extends StatelessWidget {
  const _TruckMiniCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(), // Vacío por ahora
      ),
    );
  }
}
