import 'package:flutter/material.dart';

/// Modelo de datos para cada edificio del mapa
class BuildingData {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final Color roofColor;
  final double width;
  final double height;

  const BuildingData({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.roofColor,
    this.width = 100,
    this.height = 120,
  });
}

/// Widget que representa un edificio isométrico clicable
class IsometricBuilding extends StatefulWidget {
  final BuildingData data;
  final VoidCallback onTap;

  const IsometricBuilding({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  State<IsometricBuilding> createState() => _IsometricBuildingState();
}

class _IsometricBuildingState extends State<IsometricBuilding>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _bounceAnimation = Tween<double>(begin: 0, end: -15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _controller.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _controller.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edificio
            Container(
              width: widget.data.width,
              height: widget.data.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.data.color,
                    widget.data.color.withOpacity(0.7),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Techo
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: widget.data.roofColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  // Ventanas
                  Positioned.fill(
                    top: 25,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        physics: const NeverScrollableScrollPhysics(),
                        children: List.generate(4, (index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.shade100,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: widget.data.color.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  // Icono central
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.data.icon,
                        size: 28,
                        color: widget.data.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Base / Entrada
            Container(
              width: widget.data.width + 10,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
            // Nombre del edificio
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.data.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de edificios del juego
class GameBuildings {
  static const List<BuildingData> buildings = [
    BuildingData(
      id: 'user_data',
      name: 'Datos Usuario',
      icon: Icons.person,
      color: Color(0xFF1E3A8A),
      roofColor: Color(0xFF3B82F6),
    ),
    BuildingData(
      id: 'markets',
      name: 'Mercados',
      icon: Icons.store,
      color: Color(0xFFEA580C),
      roofColor: Color(0xFFFBBF24),
      width: 110,
      height: 100,
    ),
    BuildingData(
      id: 'warehouses',
      name: 'Almacenes',
      icon: Icons.inventory_2,
      color: Color(0xFF6B7280),
      roofColor: Color(0xFF9CA3AF),
      width: 120,
      height: 90,
    ),
    BuildingData(
      id: 'factories',
      name: 'Fábricas',
      icon: Icons.factory,
      color: Color(0xFFDC2626),
      roofColor: Color(0xFFB91C1C),
      width: 130,
      height: 140,
    ),
    BuildingData(
      id: 'parking',
      name: 'Parking',
      icon: Icons.local_shipping,
      color: Color(0xFF8B5CF6),
      roofColor: Color(0xFFA78BFA),
      width: 140,
      height: 85,
    ),
    BuildingData(
      id: 'hiring',
      name: 'Personal',
      icon: Icons.groups,
      color: Color(0xFF16A34A),
      roofColor: Color(0xFF22C55E),
    ),
    BuildingData(
      id: 'shop',
      name: 'Tienda',
      icon: Icons.shopping_cart,
      color: Color(0xFF7C3AED),
      roofColor: Color(0xFFA855F7),
      width: 90,
      height: 130,
    ),
    BuildingData(
      id: 'association',
      name: 'Asociación',
      icon: Icons.account_balance,
      color: Color(0xFFF5F5DC),
      roofColor: Color(0xFFE5E5BE),
      width: 110,
      height: 110,
    ),
  ];
}
