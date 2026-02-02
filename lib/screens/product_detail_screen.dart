import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:industrial_app/data/materials/material_model.dart';
import 'package:industrial_app/data/materials/container_type.dart';
import 'package:industrial_app/data/locations/location_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/data/retail/retail_building_model.dart';
import 'package:industrial_app/data/retail/retail_repository.dart';
import 'package:industrial_app/data/factories/factory_model.dart';
import 'package:industrial_app/data/factories/factory_repository.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';

class ProductDetailScreen extends StatefulWidget {
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
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isLoading = true;
  List<LocationModel> _allLocations = [];
  List<FactoryModel> _producingFactories = [];
  List<RetailBuilding> _sellingBuildings = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final locations = await LocationsRepository.loadLocationsWithMarkets();
      final factories = await FactoryRepository.loadFactories();
      final retailBuildings = await RetailRepository.loadRetailBuildings();

      // Filter factories that produce this material
      final relevantFactories = factories.where((f) {
        return f.productionTiers.any(
          (tier) => tier.products.any(
            (product) => product.materialId == widget.material.id,
          ),
        );
      }).toList();

      // Filter retail buildings that sell this exact material
      final relevantRetail = retailBuildings
          .where((b) => b.items.contains(widget.material.id))
          .toList();

      if (mounted) {
        setState(() {
          _allLocations = locations;
          _producingFactories = relevantFactories;
          _sellingBuildings = relevantRetail;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading detail data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;
    final backgroundColor = const Color(0xFF121212);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CustomGameAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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

                        // Material Name Bar
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            border: Border(
                              top: BorderSide(
                                color: Color(0xFF334155),
                                width: 1,
                              ),
                              bottom: BorderSide(
                                color: Color(0xFF334155),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Text(
                            material.name.toUpperCase(),
                            style: GoogleFonts.orbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
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

                        // PRECIOS SECTION
                        _buildSectionHeader("Mercado y Precios"),
                        _buildMarketPricesSection(),

                        // LOGISTICS SECTION
                        _buildSectionHeader("Logística y Almacenaje"),
                        _buildLogisticsSection(),

                        // COMPOSITION SECTION
                        _buildSectionHeader("Composición"),
                        _buildCompositionSection(),

                        // PRODUCTION SECTION
                        if (_producingFactories.isNotEmpty) ...[
                          _buildSectionHeader("Producción Industrial"),
                          _buildProductionSection(),
                        ],

                        // RETAIL SECTION
                        if (_sellingBuildings.isNotEmpty) ...[
                          _buildSectionHeader("Venta al Por Menor"),
                          _buildRetailSection(),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      color: const Color(0xFF0F172A),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.orbitron(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF38BDF8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMarketPricesSection() {
    final material = widget.material;
    final marketData = widget.marketData;
    final isGlobal = marketData.containsKey('markets');
    final marketsList = isGlobal
        ? (marketData['markets'] as List<dynamic>)
        : [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Precio Base:",
                style: GoogleFonts.inter(color: Colors.white70),
              ),
              Text(
                "\$ ${NumberFormat('#,###').format(material.basePrice)}",
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (isGlobal && marketsList.isNotEmpty) ...[
            const Divider(color: Colors.white10, height: 24),
            ...marketsList.map((m) {
              final index = marketsList.indexOf(m);
              final location = _allLocations.firstWhere(
                (loc) => loc.marketIndex == index,
                orElse: () => LocationModel(
                  id: 0,
                  city: "Unknown",
                  latitude: 0,
                  longitude: 0,
                  countryIso: "",
                  hasMarket: true,
                ),
              );
              final price =
                  material.basePrice *
                  ((m['priceMultiplier'] as num?)?.toDouble() ?? 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        location.city,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      "Stock: ${m['stockCurrent']}",
                      style: GoogleFonts.inter(
                        color: Colors.blue[200],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "\$ ${NumberFormat('#,###').format(price.round())}",
                      style: GoogleFonts.orbitron(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ] else if (!isGlobal) ...[
            const Divider(color: Colors.white10, height: 24),
            _buildStatRow(
              Icons.inventory_2_outlined,
              "${NumberFormat('#,###').format(marketData['stockCurrent'] ?? 0)} Unidades",
              Colors.blue[200]!,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              Icons.monetization_on_outlined,
              "\$ ${NumberFormat('#,###').format(((marketData['priceMultiplier'] as num?)?.toDouble() ?? 1.0) * material.basePrice)}",
              const Color(0xFFFFD700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogisticsSection() {
    final material = widget.material;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Volumen unitario: ${material.unitVolumeM3} m³",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ContainerType.values.map((type) {
                final isAllowed = material.allowedContainers.contains(type);
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.grey[800]!, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(
                                'assets/images/containers/${_getContainerImageAsset(type)}.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(6),
                                bottomRight: Radius.circular(6),
                              ),
                            ),
                            child: Text(
                              _getShortContainerName(type),
                              style: GoogleFonts.orbitron(
                                fontSize: 8,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      if (!isAllowed)
                        Center(
                          child: Image.asset(
                            'assets/images/containers/cruz_roja.png',
                            width: 40,
                            height: 40,
                            opacity: const AlwaysStoppedAnimation(0.8),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getContainerImageAsset(ContainerType type) {
    switch (type) {
      case ContainerType.bulkSolid:
        return 'bulkSolid';
      case ContainerType.bulkLiquid:
        return 'bulkLiquid';
      case ContainerType.refrigerated:
        return 'refrigerated';
      case ContainerType.standard:
        return 'standard';
      case ContainerType.heavy:
        return 'heavy';
      case ContainerType.hazardous:
        return 'hazardous';
    }
  }

  String _getShortContainerName(ContainerType type) {
    switch (type) {
      case ContainerType.bulkSolid:
        return 'SÓLIDO';
      case ContainerType.bulkLiquid:
        return 'LÍQUIDO';
      case ContainerType.refrigerated:
        return 'REFRI';
      case ContainerType.standard:
        return 'ESTÁNDAR';
      case ContainerType.heavy:
        return 'PESADO';
      case ContainerType.hazardous:
        return 'QUÍMICO';
    }
  }

  Widget _buildCompositionSection() {
    final material = widget.material;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "GRADO: ",
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              Text(
                "${material.grade}",
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          if (material.components.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(color: Colors.white10),
            ),
            ...material.components
                .map(
                  (comp) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/materials/${comp.materialId}.png',
                          width: 24,
                          height: 24,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.extension,
                            size: 24,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.materialNames[comp.materialId.toString()] ??
                                "Material ${comp.materialId}",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          "x${comp.quantity}",
                          style: GoogleFonts.orbitron(
                            color: const Color(0xFFFFD700),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              "Material base / Recurso natural",
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _producingFactories.map((f) {
          int productionTime = 0;
          for (var tier in f.productionTiers) {
            for (var product in tier.products) {
              if (product.materialId == widget.material.id) {
                productionTime = product.productionTimeSeconds;
                break;
              }
            }
            if (productionTime > 0) break;
          }

          final speedPerHour = productionTime > 0
              ? (3600 / productionTime).toStringAsFixed(1)
              : "0.0";

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.factory, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    f.name.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  "$speedPerHour u/h",
                  style: GoogleFonts.inter(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRetailSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _sellingBuildings
            .map(
              (b) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        b.name.toUpperCase(),
                        style: GoogleFonts.orbitron(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      "${b.salesPerHour} u/h",
                      style: GoogleFonts.inter(
                        color: Colors.blue[200],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(width: 12),
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
