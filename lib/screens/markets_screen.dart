import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/data/locations/location_model.dart';
import 'package:industrial_app/data/locations/location_repository.dart';
import 'package:industrial_app/screens/market_detail_screen.dart';

import 'package:industrial_app/widgets/custom_game_appbar.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  List<LocationModel> _marketLocations = [];
  Map<String, dynamic> _firestoreMaterials = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  Future<void> _loadMarkets() async {
    try {
      final locations = await LocationsRepository.loadLocationsWithMarkets();

      // Load Firestore materials data
      final materialsSnapshot = await FirebaseFirestore.instance
          .collection('materials')
          .get();
      final firestoreData = <String, dynamic>{};
      for (var doc in materialsSnapshot.docs) {
        if (doc.id == 'global') {
          // Parse global document containing array of materials
          final data = doc.data();
          // Find the list field (could be 'materiales', 'items', etc.)
          for (var value in data.values) {
            if (value is List) {
              for (var item in value) {
                if (item is Map && item.containsKey('materialId')) {
                  // Map each material by its ID
                  firestoreData[item['materialId'].toString()] = item;
                }
              }
            }
          }
        } else {
          // Standard document structure fallback
          firestoreData[doc.id] = doc.data();
        }
      }

      setState(() {
        _marketLocations = locations;
        _firestoreMaterials = firestoreData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando mercados: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _marketLocations.isEmpty
                ? Center(
                    child: Text(
                      'No hay mercados disponibles',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: _marketLocations.length,
                    itemBuilder: (context, index) {
                      final location = _marketLocations[index];
                      return MarketCard(
                        location: location,
                        firestoreMaterials: _firestoreMaterials,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MarketCard extends StatefulWidget {
  final LocationModel location;
  final Map<String, dynamic> firestoreMaterials;

  const MarketCard({
    Key? key,
    required this.location,
    required this.firestoreMaterials,
  }) : super(key: key);

  @override
  State<MarketCard> createState() => _MarketCardState();
}

class _MarketCardState extends State<MarketCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketDetailScreen(
          location: widget.location,
          firestoreMaterials: widget.firestoreMaterials,
        ),
      ),
    );
  }

  void _handleTapCancel() {
    _controller.reverse();
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
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[700]!, width: 2),
                color: Colors.black, // Background for the card
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // City Image
                  Expanded(
                    child: Image.asset(
                      widget.location.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.location_city,
                            size: 64,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  // Footer with City Name
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF1E293B,
                      ), // Dark blue-grey background
                      border: Border(
                        top: BorderSide(color: Colors.grey[700]!, width: 2),
                      ),
                    ),
                    child: Text(
                      widget.location.city,
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
