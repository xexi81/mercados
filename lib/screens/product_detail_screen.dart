import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/widgets/industrial_button.dart';

class ProductDetailScreen extends StatelessWidget {
  final MaterialModel material;
  final Map<String, dynamic> marketData; // To store price, stock, etc.

  const ProductDetailScreen({
    Key? key,
    required this.material,
    required this.marketData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine colors based on design
    final backgroundColor = const Color(0xFF121212);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      material.name.toUpperCase(),
                      style: GoogleFonts.orbitron(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

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
                          bottom: BorderSide(
                            color: Color(0xFF37474F),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        material.category.toUpperCase(),
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
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
                          fontSize: 16,
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
                            "Disponible",
                            "${NumberFormat('#,###').format(marketData['stock'] ?? 0)} Unidades",
                            Colors.blue[200]!,
                          ),
                          const Divider(color: Colors.white10, height: 24),
                          _buildStatRow(
                            Icons.monetization_on_outlined,
                            "Precio Actual",
                            "\$ ${NumberFormat('#,###').format(marketData['price'] ?? material.basePrice)}",
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
                                  fontSize: 18,
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  // Component Icon/Image
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    // Need to fetch material name/image from ID.
                                    // For now using generic placeholder as we don't have the full list passed down to look it up easily
                                    // unless we pass the full material list or a lookup function.
                                    // Assuming simple placeholder for now.
                                    child: const Icon(
                                      Icons.extension,
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      "Material ID: ${component.materialId}", // Placeholder name
                                      style: GoogleFonts.orbitron(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "${component.quantity}",
                                    style: GoogleFonts.orbitron(
                                      fontSize: 18,
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
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: IndustrialButton(
                  label: "COMPRAR",
                  gradientTop: const Color(0xFF4CAF50),
                  gradientBottom: const Color(0xFF2E7D32),
                  borderColor: const Color(0xFF81C784), // Lighter Green
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: IndustrialButton(
                  label: "VENDER",
                  gradientTop: const Color(0xFFE53935),
                  gradientBottom: const Color(0xFFB71C1C),
                  borderColor: const Color(0xFFEF5350), // Lighter Red
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(width: 16),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
