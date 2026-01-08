import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/data/locations/location_model.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/screens/product_detail_screen.dart';

import 'package:industrial_app/widgets/custom_game_appbar.dart';

class MarketDetailScreen extends StatefulWidget {
  final LocationModel location;
  final Map<String, dynamic> firestoreMaterials;

  const MarketDetailScreen({
    Key? key,
    required this.location,
    required this.firestoreMaterials,
  }) : super(key: key);

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  List<MaterialModel> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await MaterialsRepository.loadMaterials();
      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading materials: $e')));
      }
    }
  }

  Map<String, List<MaterialModel>> _groupMaterialsByCategory() {
    final grouped = <String, List<MaterialModel>>{};
    for (var material in _materials) {
      if (!grouped.containsKey(material.category)) {
        grouped[material.category] = [];
      }
      grouped[material.category]!.add(material);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedMaterials = _groupMaterialsByCategory();

    return Scaffold(
      appBar: const CustomGameAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: groupedMaterials.length,
                    itemBuilder: (context, index) {
                      final category = groupedMaterials.keys.elementAt(index);
                      final materials = groupedMaterials[category]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              category.toUpperCase(),
                              style: GoogleFonts.orbitron(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.8,
                                ),
                            itemCount: materials.length,
                            itemBuilder: (context, materialIndex) {
                              final material = materials[materialIndex];
                              final rawData = widget
                                  .firestoreMaterials[material.id.toString()];
                              Map<String, dynamic> specificMarketData = {};

                              if (rawData != null &&
                                  widget.location.marketIndex != null) {
                                final index = widget.location.marketIndex!;

                                // Check if 'markets' is a list and has enough elements
                                if (rawData['markets'] is List &&
                                    (rawData['markets'] as List).length >
                                        index) {
                                  final marketEntry = rawData['markets'][index];
                                  if (marketEntry is Map) {
                                    specificMarketData['stockCurrent'] =
                                        marketEntry['stockCurrent'];
                                    specificMarketData['priceMultiplier'] =
                                        marketEntry['priceMultiplier'];
                                  }
                                }
                              }

                              return MaterialCard(
                                material: material,
                                marketData: specificMarketData,
                                materialNames: Map.fromEntries(
                                  _materials.map(
                                    (m) => MapEntry(m.id.toString(), m.name),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MaterialCard extends StatelessWidget {
  final MaterialModel material;
  final Map<String, dynamic> marketData;
  final Map<String, String> materialNames;

  const MaterialCard({
    Key? key,
    required this.material,
    required this.marketData,
    required this.materialNames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              material: material,
              marketData: marketData,
              materialNames: materialNames,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[700]!, width: 2),
          color: Colors.black,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[900],
                child: Image.asset(
                  material.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.inventory_2,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              height:
                  40, // Fixed height for consistency (approx 2 lines + padding)
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border(
                  top: BorderSide(color: Colors.grey[700]!, width: 2),
                ),
              ),
              child: Center(
                child: Text(
                  material.name,
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
