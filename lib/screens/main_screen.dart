import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/data/warehouse/warehouse_model.dart';
import 'package:industrial_app/data/warehouse/warehouse_repository.dart';
import 'package:industrial_app/screens/association_screen.dart';
import 'package:industrial_app/screens/contracts_screen.dart';
import 'package:industrial_app/screens/parking_screen.dart';
import 'package:industrial_app/screens/retail_screen.dart';
import 'package:industrial_app/screens/user_data_screen.dart';
import 'package:industrial_app/screens/warehouses_screen.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'shop_screen.dart';
import 'factories_screen.dart';
import 'materials_screen.dart'; // Add this

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late TransformationController _transformationController;

  // Warehouse configuration for capacity calculation
  List<WarehouseModel> _warehouseConfigs = [];

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _initWarehouseData();

    // Set initial scale to 0.7 (more zoomed out)
    // The matrix is set after the first frame to ensure proper initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final Matrix4 matrix = Matrix4.identity()..scale(0.7);
      _transformationController.value = matrix;
    });
  }

  Future<void> _initWarehouseData() async {
    try {
      final warehouses = await WarehouseRepository.loadWarehouses();
      if (mounted) {
        setState(() {
          _warehouseConfigs = warehouses;
        });
      }
    } catch (e) {
      debugPrint('Error loading warehouse data for main screen: $e');
    }
  }

  bool _isWarehouseFull(Map<String, dynamic> slot) {
    if (_warehouseConfigs.isEmpty) return false;

    final int warehouseId = slot['warehouseId'];
    final int level = slot['level'] ?? 1;

    // 1. Calculate Total Capacity (Base + Upgrades)
    // Using shared logic from WarehouseRepository to match WarehouseManagerScreen
    final warehouse = _warehouseConfigs.firstWhere(
      (w) => w.id == warehouseId,
      orElse: () => _warehouseConfigs.first,
    );

    final double totalCapacity = WarehouseRepository.calculateRealCapacity(
      warehouse,
      level,
    );

    // 2. Calculate Current Volume
    final storage = slot['storage'] as Map<String, dynamic>? ?? {};
    if (storage.isEmpty) return false;

    final double currentVolume = WarehouseRepository.calculateCurrentLoad(
      storage,
    );

    // Check with tolerance
    return currentVolume >= (totalCapacity - 0.1);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(isMainScreen: true),
      body: InteractiveViewer(
        transformationController: _transformationController,
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
                left: 718,
                top: 83,
                child: ClickableBuilding(
                  width: 190, // Aumentado de 180
                  height: 150, // Aumentado de 100
                  label: 'Materiales',
                  imageAsset: 'assets/images/market-building.png',
                  enableDarken: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MaterialsScreen(),
                      ),
                    );
                  },
                ),
              ),
              // Tienda in game
              Positioned(
                left: 948,
                top: 271,
                child: ClickableBuilding(
                  width: 180,
                  height: 140,
                  label: 'Tienda',
                  imageAsset: 'assets/images/compras-building.png',
                  enableDarken: false,
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
                left: 305,
                top: 280,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('factories_users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    bool hasWaiting = false;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data.containsKey('slots')) {
                        final slots = data['slots'] as List<dynamic>;
                        hasWaiting = slots.any(
                          (slot) => slot['status'] == 'en espera',
                        );
                      }
                    }

                    return ClickableBuilding(
                      width: 260,
                      height: 180,
                      label: 'Fábrica',
                      imageAsset: 'assets/images/fabrica-building.png',
                      enableDarken: false,
                      showNotification: hasWaiting,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FactoriesScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Contratos
              Positioned(
                left: 695,
                top: 540,
                child: ClickableBuilding(
                  width: 260,
                  height: 180,
                  label: 'Contratos',
                  imageAsset: 'assets/images/contratos-building.png',
                  enableDarken: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContractsScreen(),
                      ),
                    );
                  },
                ),
              ),
              // Retail
              Positioned(
                left: 760,
                top: 360,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('retail_users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    bool hasWaiting = false;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data.containsKey('slots')) {
                        final slots = data['slots'] as List<dynamic>;
                        hasWaiting = slots.any(
                          (slot) => slot['status'] == 'en espera',
                        );
                      }
                    }

                    return ClickableBuilding(
                      width: 210,
                      height: 130,
                      label: 'Retail',
                      imageAsset: 'assets/images/retail-building.png',
                      enableDarken: false,
                      showNotification: hasWaiting,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RetailScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Parking camiones
              Positioned(
                left: 286,
                top: 120,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('fleet_users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    bool hasArrived = false;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data.containsKey('slots')) {
                        final slots = data['slots'] as List<dynamic>;
                        hasArrived = slots.any(
                          (slot) => slot['status'] == 'en destino',
                        );
                      }
                    }

                    return ClickableBuilding(
                      width: 350,
                      height: 100,
                      label: 'Muelles',
                      imageAsset: 'assets/images/parking-building.png',
                      enableDarken: false,
                      showNotification: hasArrived,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ParkingScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Warehouses
              Positioned(
                left: 500,
                top: 250,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('warehouse_users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    bool isFull = false;

                    // Only check if we have config data loaded
                    if (_warehouseConfigs.isNotEmpty &&
                        snapshot.hasData &&
                        snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data.containsKey('slots')) {
                        final slots = data['slots'] as List<dynamic>;

                        // Check if ANY occupied warehouse is full
                        isFull = slots.any(
                          (slot) =>
                              _isWarehouseFull(slot as Map<String, dynamic>),
                        );
                      }
                    }

                    return ClickableBuilding(
                      width: 250,
                      height: 120,
                      label: 'Almacén',
                      imageAsset: 'assets/images/almacen-building.png',
                      enableDarken: false,
                      showNotification: isFull,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WarehousesScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // User info
              Positioned(
                left: 974,
                top: 103,
                child: ClickableBuilding(
                  width: 100,
                  height: 70,
                  label: 'Oficina',
                  imageAsset: 'assets/images/usuario-building.png',
                  enableDarken: false,
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
                  height: 130,
                  label: 'Asociación',
                  imageAsset: 'assets/images/asociacion-building.png',
                  enableDarken: false,
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
  final String label;
  final String? imageAsset;
  final bool enableDarken;
  final bool showNotification;
  final VoidCallback? onTap; // Made optional

  const ClickableBuilding({
    Key? key,
    required this.width,
    required this.height,
    required this.label,
    this.imageAsset,
    this.enableDarken = true,
    this.showNotification = false,
    this.onTap,
  }) : super(key: key);

  @override
  State<ClickableBuilding> createState() => _ClickableBuildingState();
}

class _ClickableBuildingState extends State<ClickableBuilding>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  bool _isPressed = false;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
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

    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
          begin: Colors.transparent,
          end: Colors.black.withOpacity(0.5), // Darken effect
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: Colors.black.withOpacity(0.5),
          end: Colors.transparent,
        ),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _blinkController.dispose();
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
      widget.onTap?.call();
    });
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  Widget _buildBuildingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: widget.imageAsset != null
                  ? Container(
                      width: widget.width,
                      height: widget.height,
                      child: Stack(
                        children: [
                          Image.asset(
                            widget.imageAsset!,
                            fit: BoxFit.contain,
                            width: widget.width,
                            height: widget.height,
                          ),
                          // Dark overlay for animation
                          if (widget.enableDarken)
                            Container(
                              decoration: BoxDecoration(
                                color: _colorAnimation.value,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Container(
                      width: widget.width,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: _isPressed
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
            );
          },
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                widget.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.showNotification)
                Positioned(
                  top: -8,
                  left: -12,
                  child: FadeTransition(
                    opacity: _blinkAnimation,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: _buildBuildingContent(),
    );
  }
}
