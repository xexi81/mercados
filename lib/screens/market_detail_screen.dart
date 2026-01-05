import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:industrial_app/data/locations/location_model.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/screens/product_detail_screen.dart';

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
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final groupedMaterials = _groupMaterialsByCategory();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        actions: currentUser != null
            ? [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(currentUser.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    var dinero = 0;
                    var gemas = 0;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null) {
                        dinero = data['dinero'] ?? 0;
                        gemas = data['gemas'] ?? 0;
                      }
                    }

                    return Row(
                      children: [
                        _buildResourceBadge(
                          Icons.attach_money,
                          const Color(0xFFFFD700),
                          dinero,
                        ),
                        _buildResourceBadge(
                          Icons.diamond,
                          const Color(0xFF00D9FF),
                          gemas,
                        ),
                      ],
                    );
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Market Name Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.8),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Text(
              'MERCADO ${widget.location.city.toUpperCase()}',
              style: GoogleFonts.orbitron(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Theme.of(context).primaryColor,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
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
                              return MaterialCard(
                                material: materials[materialIndex],
                                marketData:
                                    widget
                                        .firestoreMaterials[materials[materialIndex]
                                        .id
                                        .toString()] ??
                                    {},
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

  Widget _buildResourceBadge(IconData icon, Color color, int amount) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            NumberFormat('#,###').format(amount),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
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

  const MaterialCard({
    Key? key,
    required this.material,
    required this.marketData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProductDetailScreen(material: material, marketData: marketData),
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
