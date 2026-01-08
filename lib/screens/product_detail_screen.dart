import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class ProductDetailScreen extends StatelessWidget {
  final MaterialModel material;
  final Map<String, dynamic> marketData; // To store price, stock, etc.
  final Map<String, String> materialNames;

  const ProductDetailScreen({
    Key? key,
    required this.material,
    required this.marketData,
    this.materialNames = const {},
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine colors based on design
    final backgroundColor = const Color(0xFF121212);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CustomGameAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Image
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          material.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 64,
                                color: Colors.white54,
                              ),
                            );
                          },
                        ),
                        // Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Material Title Bar
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF263238),
                      border: Border(
                        top: BorderSide(color: Color(0xFF37474F), width: 1),
                        bottom: BorderSide(color: Color(0xFF37474F), width: 1),
                      ),
                    ),
                    child: Text(
                      material.category.toUpperCase(),
                      style: GoogleFonts.orbitron(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          const Shadow(
                            blurRadius: 4,
                            color: Colors.black,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Description
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      material.description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Divider
                  const Divider(
                    color: Colors.grey,
                    thickness: 0.5,
                    indent: 40,
                    endIndent: 40,
                  ),
                  const SizedBox(height: 10),

                  // Market Stats
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF263238),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFF37474F)),
                    ),
                    child: Column(
                      children: [
                        _buildStatRow(
                          Icons.inventory_2_outlined,
                          "${NumberFormat('#,###').format(marketData['stockCurrent'] ?? 0)} Unidades",
                          Colors.blue[200]!,
                        ),
                        const Divider(color: Colors.white10, height: 24),
                        _buildStatRow(
                          Icons.monetization_on_outlined,
                          "\$ ${NumberFormat('#,###').format(((marketData['priceMultiplier'] as num?)?.toDouble() ?? 1.0) * material.basePrice)}",
                          const Color(0xFFFFD700),
                        ),
                      ],
                    ),
                  ),

                  // Composition Section
                  if (material.components.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.only(left: 16),
                      child: Stack(
                        children: [
                          // Ribbon Shape (Simplified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFF263238),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                            child: Text(
                              "Composición",
                              style: GoogleFonts.orbitron(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF263238),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF37474F)),
                      ),
                      child: Column(
                        children: material.components.map((component) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                // Component Icon/Image
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.asset(
                                      'assets/images/materials/${component.materialId}.png',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.extension,
                                              color: Colors.white70,
                                              size: 18,
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    materialNames[component.materialId
                                            .toString()] ??
                                        "Material ID: ${component.materialId}",
                                    style: GoogleFonts.orbitron(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Text(
                                  "${component.quantity}",
                                  style: GoogleFonts.orbitron(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFFD700),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 80), // Spec for buttons
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
        const SizedBox(width: 28), // Balance icon width for perfect centering
      ],
    );
  }
}
