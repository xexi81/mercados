import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/data/associations/association_repository.dart';
import 'package:industrial_app/data/associations/association_model.dart';
import 'package:industrial_app/screens/associations/widgets/association_card.dart';

class SearchAssociationsPage extends StatefulWidget {
  const SearchAssociationsPage({super.key});

  @override
  State<SearchAssociationsPage> createState() => _SearchAssociationsPageState();
}

class _SearchAssociationsPageState extends State<SearchAssociationsPage> {
  String _selectedLanguage = 'es';
  List<AssociationModel> _associations = [];
  bool _isLoading = true;

  static const Map<String, String> languages = {
    'es': '🇪🇸',
    'en': '🇬🇧',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'it': '🇮🇹',
    'pt': '🇵🇹',
  };

  @override
  void initState() {
    super.initState();
    _loadAssociations();
  }

  Future<void> _loadAssociations() async {
    setState(() => _isLoading = true);
    try {
      final assocs = await AssociationRepository.searchAssociations(
        language: _selectedLanguage,
      );
      setState(() {
        _associations = assocs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading associations: $e');
      setState(() => _isLoading = false);
    }
  }

  void _changeLanguage(String lang) {
    setState(() => _selectedLanguage = lang);
    _loadAssociations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Header con filtros de idioma
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUSCAR ASOCIACIONES',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Filtrar por idioma:',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: languages.entries.map((entry) {
                      final isSelected = entry.key == _selectedLanguage;
                      return GestureDetector(
                        onTap: () => _changeLanguage(entry.key),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            entry.value,
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Lista de asociaciones
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _associations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.white30),
                        const SizedBox(height: 16),
                        Text(
                          'No hay asociaciones disponibles',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _associations.length,
                    itemBuilder: (context, index) {
                      final assoc = _associations[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AssociationCard(association: assoc),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
