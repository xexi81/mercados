import 'package:flutter/material.dart';

/// Edificio personalizado: Mercado con toldo y detalles
class MarketBuildingWidget extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback onTap;
  const MarketBuildingWidget({
    super.key,
    this.width = 110,
    this.height = 100,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height + 30,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Cuerpo del mercado
            Positioned(
              bottom: 0,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(4, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 18,
                      width: width * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.store,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Toldo
            Positioned(
              top: 0,
              child: Container(
                width: width * 0.95,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFFBBF24)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) {
                    return Container(
                      width: (width * 0.95) / 6 - 2,
                      height: 32,
                      decoration: BoxDecoration(
                        color: i % 2 == 0
                            ? Colors.white
                            : const Color(0xFFEA580C),
                        borderRadius: i == 0
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(12),
                              )
                            : i == 5
                            ? const BorderRadius.only(
                                topRight: Radius.circular(12),
                              )
                            : BorderRadius.zero,
                      ),
                    );
                  }),
                ),
              ),
            ),
            // Nombre
            Positioned(
              bottom: -24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Mercado',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
