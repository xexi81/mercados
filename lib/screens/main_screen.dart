import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_config_screen.dart';
import 'building_screen.dart';
import '../widgets/isometric_building.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  void _navigateToBuilding(BuildContext context, BuildingData building) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuildingScreen(
          buildingName: building.name,
          buildingIcon: building.icon,
          buildingColor: building.color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Fondo del mapa (cielo y suelo)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF87CEEB), // Cielo azul claro
                  Color(0xFF5BA3D9), // Cielo más oscuro
                  Color(0xFF4A7C4E), // Césped
                  Color(0xFF3D6B40), // Césped más oscuro
                ],
                stops: [0.0, 0.3, 0.5, 1.0],
              ),
            ),
          ),

          // Nubes decorativas
          Positioned(
            top: 40,
            left: 30,
            child: _buildCloud(60),
          ),
          Positioned(
            top: 60,
            right: 50,
            child: _buildCloud(80),
          ),
          Positioned(
            top: 100,
            left: 150,
            child: _buildCloud(50),
          ),

          // Calles (fondo gris)
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height),
            painter: StreetPainter(),
          ),

          // Grid de edificios
          SafeArea(
            child: Column(
              children: [
                // Header con usuario
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Foto de usuario (va a configuración)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const UserConfigScreen()),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
                            backgroundColor: theme.colorScheme.primary,
                            child: photoUrl == null
                                ? const Icon(Icons.person,
                                    color: Colors.white, size: 28)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Nombre y monedas
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'Jugador',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.monetization_on,
                                    color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '10,000',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Icono de configuración
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const UserConfigScreen()),
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.settings,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Área de edificios scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Column(
                      children: [
                        // Fila 1: Datos Usuario, Mercados, Almacenes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IsometricBuilding(
                              data: GameBuildings.buildings[0], // Datos Usuario
                              onTap: () => _navigateToBuilding(
                                  context, GameBuildings.buildings[0]),
                            ),
                            IsometricBuilding(
                              data: GameBuildings.buildings[1], // Mercados
                              onTap: () => _navigateToBuilding(
                                  context, GameBuildings.buildings[1]),
                            ),
                            IsometricBuilding(
                              data: GameBuildings.buildings[2], // Almacenes
                              onTap: () => _navigateToBuilding(
                                  context, GameBuildings.buildings[2]),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Fila 2: Fábricas (grande en el centro)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IsometricBuilding(
                              data: GameBuildings.buildings[5], // Personal
                              onTap: () => _navigateToBuilding(
                                  context, GameBuildings.buildings[5]),
                            ),
                            const SizedBox(width: 20),
                            IsometricBuilding(
                              data: GameBuildings.buildings[3], // Fábricas
                              onTap: () => _navigateToBuilding(
                                  context, GameBuildings.buildings[3]),
                            ),
                            const SizedBox(width: 20),
                            IsometricBuilding(
                              data: GameBuildings.buildings[7], // Asociación
                              onTap: () => _navigateToBuilding(
                                  context, GameBuildings.buildings[7]),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Fila 3: Parking y Tienda
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IsometricBuilding(
                              data: GameBuildings.buildings[4], // Parking
                              onTap: () => _navigateToBuilding(
                                  context, GameBuildings.buildings[4]),
                            ),
                            IsometricBuilding(
                              data: GameBuildings.buildings[6], // Tienda
                              onTap: () => _navigateToBuilding(
                                  context, GameBuildings.buildings[6]),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloud(double width) {
    return Container(
      width: width,
      height: width * 0.4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(width * 0.3),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }
}

/// Painter para dibujar las calles del mapa
class StreetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final streetPaint = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Calle horizontal superior
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.35, size.width, 40),
      streetPaint,
    );

    // Líneas de la calle horizontal superior
    for (double x = 20; x < size.width; x += 40) {
      canvas.drawLine(
        Offset(x, size.height * 0.35 + 20),
        Offset(x + 20, size.height * 0.35 + 20),
        linePaint,
      );
    }

    // Calle horizontal inferior
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.65, size.width, 40),
      streetPaint,
    );

    // Líneas de la calle horizontal inferior
    for (double x = 20; x < size.width; x += 40) {
      canvas.drawLine(
        Offset(x, size.height * 0.65 + 20),
        Offset(x + 20, size.height * 0.65 + 20),
        linePaint,
      );
    }

    // Calle vertical izquierda
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.25 - 20, size.height * 0.35, 40,
          size.height * 0.3 + 40),
      streetPaint,
    );

    // Calle vertical derecha
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.75 - 20, size.height * 0.35, 40,
          size.height * 0.3 + 40),
      streetPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
