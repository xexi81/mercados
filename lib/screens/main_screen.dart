import 'package:flutter/material.dart';
import 'package:industrial_app/screens/association_screen.dart';
import 'package:industrial_app/screens/parking_screen.dart';
import 'package:industrial_app/screens/user_data_screen.dart';
import 'package:industrial_app/screens/warehouses_screen.dart';
import 'markets_screen.dart';
import 'shop_screen.dart';
import 'factories_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de la Ciudad'),
        backgroundColor: Colors.blue,
      ),
      body: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(0),
        panEnabled: true,
        scaleEnabled: true,
        minScale: 0.5,
        maxScale: 4.0,
        constrained: false,
        child: Container(
          width: 1340,
          height: 900,
          child: Stack(
            children: [
              // Imagen del mapa
              Image.asset(
                'assets/images/city_map.png',
                fit: BoxFit.contain,
                width: 1340,
                height: 900,
              ),
              // Mercados
              Positioned(
                left: 720,
                top: 80,
                child: ClickableBuilding(
                  width: 180,
                  height: 140,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MarketsScreen(),
                      ),
                    );
                  },
                ),
              ),
              // Tienda in game
              Positioned(
                left: 950,
                top: 280,
                child: ClickableBuilding(
                  width: 160,
                  height: 130,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ShopScreen(),
                      ),
                    );
                  },
                ),
              ),
              // Fábricas
              Positioned(
                left: 340,
                top: 320,
                child: ClickableBuilding(
                  width: 200,
                  height: 180,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FactoriesScreen(),
                      ),
                    );
                  },
                ),
              ),
              // Parking camiones
              Positioned(
                left: 280,
                top: 100,
                child: ClickableBuilding(
                  width: 350,
                  height: 150,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ParkingScreen(),
                      ),
                    );
                  },
                ),
              ),
              // Warehouses
              Positioned(
                left: 500,
                top: 250,
                child: ClickableBuilding(
                  width: 250,
                  height: 150,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WarehousesScreen(),
                      ),
                    );
                  },
                ),
              ),
              // User info
              Positioned(
                left: 980,
                top: 100,
                child: ClickableBuilding(
                  width: 100,
                  height: 80,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserDataScreen(),
                      ),
                    );
                  },
                ),
              ),
              // Asociación
              Positioned(
                left: 390,
                top: 500,
                child: ClickableBuilding(
                  width: 200,
                  height: 170,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AssociationScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget reutilizable para edificios clicables con animación
class ClickableBuilding extends StatefulWidget {
  final double width;
  final double height;
  final VoidCallback onTap;

  const ClickableBuilding({
    Key? key,
    required this.width,
    required this.height,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ClickableBuilding> createState() => _ClickableBuildingState();
}

class _ClickableBuildingState extends State<ClickableBuilding>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _controller.forward(from: 0);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.onTap();
    });
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: _isPressed
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                // Descomenta la siguiente línea para ver el área clicable durante desarrollo
                // border: Border.all(color: Colors.red, width: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}
