import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/data/materials/materials_repository.dart';
import 'package:industrial_app/screens/product_detail_screen.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  List<MaterialModel> _allMaterials = [];
  List<MaterialModel> _filteredMaterials = [];
  Map<String, dynamic> _firestoreMaterials = {};
  List<String> _categories = [];
  String _selectedCategory = 'TODOS';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. Load static materials configuration
      final materials = await MaterialsRepository.loadMaterials();

      // 2. Load Firestore materials collection (global doc or individual docs)
      final materialsSnapshot = await FirebaseFirestore.instance
          .collection('materials')
          .get();

      final firestoreData = <String, dynamic>{};
      for (var doc in materialsSnapshot.docs) {
        if (doc.id == 'global') {
          final data = doc.data();
          for (var value in data.values) {
            if (value is List) {
              for (var item in value) {
                if (item is Map && item.containsKey('materialId')) {
                  firestoreData[item['materialId'].toString()] = item;
                }
              }
            }
          }
        } else {
          firestoreData[doc.id] = doc.data();
        }
      }

      // Extract unique categories
      final categories = materials.map((m) => m.category).toSet().toList();
      categories.sort();
      categories.insert(0, 'TODOS');

      if (mounted) {
        setState(() {
          _allMaterials = materials;
          _filteredMaterials = materials;
          _firestoreMaterials = firestoreData;
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading materials data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterByCategory(String? category) {
    if (category == null) return;
    setState(() {
      _selectedCategory = category;
      if (category == 'TODOS') {
        _filteredMaterials = _allMaterials;
      } else {
        _filteredMaterials = _allMaterials
            .where((m) => m.category == category)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Category Selector
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                        ),
                        isExpanded: true,
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: _filterByCategory,
                      ),
                    ),
                  ),
                ),

                // Materials Grid
                Expanded(
                  child: _filteredMaterials.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay materiales en esta categoría',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: _filteredMaterials.length,
                          itemBuilder: (context, index) {
                            final material = _filteredMaterials[index];
                            final firestoreData =
                                _firestoreMaterials[material.id.toString()] ??
                                {};

                            return MaterialCard(
                              material: material,
                              firestoreData: firestoreData,
                              materialNames: Map.fromEntries(
                                _allMaterials.map(
                                  (m) => MapEntry(m.id.toString(), m.name),
                                ),
                              ),
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
  final Map<String, dynamic> firestoreData;
  final Map<String, String> materialNames;

  const MaterialCard({
    Key? key,
    required this.material,
    required this.firestoreData,
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
              marketData: firestoreData, // Passing the global data doc
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
              height: 40,
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
