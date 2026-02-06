import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/data/associations/association_repository.dart';
import 'package:industrial_app/data/associations/association_model.dart';
import 'package:industrial_app/data/associations/association_member_model.dart';

class AssociationDetailsPage extends StatefulWidget {
  final String userId;

  const AssociationDetailsPage({super.key, required this.userId});

  @override
  State<AssociationDetailsPage> createState() => _AssociationDetailsPageState();
}

class _AssociationDetailsPageState extends State<AssociationDetailsPage> {
  AssociationModel? _association;
  List<AssociationMemberModel> _members = [];
  bool _isLoading = true;

  Future<void> _showDescriptionDialog() async {
    final controller = TextEditingController(
      text: _association?.description ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Descripción de la Asociación',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Descripción...',
            hintStyle: GoogleFonts.inter(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.purpleAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  String _getLanguageEmoji(String languageCode) {
    const languageFlags = {
      'es': '🇪🇸',
      'en': '🇬🇧',
      'fr': '🇫🇷',
      'de': '🇩🇪',
      'it': '🇮🇹',
      'pt': '🇵🇹',
    };
    return languageFlags[languageCode] ?? '🌐';
  }

  double _getExperienceProgress() {
    if (_association == null) return 0;

    final currentLevel = _association!.level;
    final nextLevelRequirement = _association!.experiencePool;

    // Obtener experiencia requerida para el siguiente nivel
    // Por ahora usamos un valor calculado, en el futuro lo obtendremos del JSON
    final experienceForNextLevel = (currentLevel * 10000).toDouble();

    if (experienceForNextLevel <= 0) return 0;
    return (nextLevelRequirement / experienceForNextLevel).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Obtener asociación del usuario
      final assoc = await AssociationRepository.getUserAssociation(
        widget.userId,
      );

      if (assoc != null) {
        // Obtener miembros
        final members = await AssociationRepository.getAssociationMembers(
          assoc.id,
        );

        setState(() {
          _association = assoc;
          _members = members;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error loading association data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _association == null
          ? Center(
              child: Text(
                'Asociación no encontrada',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Encabezado: Nombre + Bandera de idioma
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _association!.name,
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        Text(
                          _getLanguageEmoji(_association!.language),
                          style: const TextStyle(fontSize: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nivel y Progress bar de experiencia
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'NIVEL ${_association!.level}',
                            style: GoogleFonts.orbitron(
                              color: Colors.amber,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _getExperienceProgress(),
                              minHeight: 8,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.amber.withOpacity(0.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Experiencia: ${_association!.experiencePool.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón para ver/editar descripción
                    ElevatedButton.icon(
                      onPressed: _showDescriptionDialog,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Ver Descripción'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent.withOpacity(0.3),
                        foregroundColor: Colors.purpleAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.purpleAccent.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bolsa de recursos
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BOLSA DE RECURSOS',
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '💰',
                                    style: GoogleFonts.inter(fontSize: 24),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _association!.moneyPool.toStringAsFixed(0),
                                    style: GoogleFonts.orbitron(
                                      color: Colors.greenAccent,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '💎',
                                    style: GoogleFonts.inter(fontSize: 24),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _association!.gemsPool.toStringAsFixed(0),
                                    style: GoogleFonts.orbitron(
                                      color: Colors.cyanAccent,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Miembros
                    Text(
                      'MIEMBROS (${_members.length})',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Usuario ${member.userId.substring(0, 8)}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: member.role == AssociationRole.creator
                                      ? Colors.amber.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  member.role.name.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color:
                                        member.role == AssociationRole.creator
                                        ? Colors.amber
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
