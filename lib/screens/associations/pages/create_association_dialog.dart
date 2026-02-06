import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/data/associations/association_service.dart';
import 'package:industrial_app/data/associations/association_repository.dart';
import 'package:industrial_app/widgets/industrial_button.dart';

class CreateAssociationDialog extends StatefulWidget {
  const CreateAssociationDialog({super.key});

  @override
  State<CreateAssociationDialog> createState() =>
      _CreateAssociationDialogState();
}

class _CreateAssociationDialogState extends State<CreateAssociationDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedLanguage = 'es';
  bool _isLoading = false;
  String _costText = 'Cargando...';

  static const Map<String, String> languages = {
    'es': '🇪🇸 Español',
    'en': '🇬🇧 English',
    'fr': '🇫🇷 Français',
    'de': '🇩🇪 Deutsch',
    'it': '🇮🇹 Italiano',
    'pt': '🇵🇹 Português',
  };

  @override
  void initState() {
    super.initState();
    _loadCost();
  }

  Future<void> _loadCost() async {
    final level1 = await AssociationRepository.getLevelByNumber(1);
    if (level1 != null) {
      final costText = level1.upgradeCost.gems > 0
          ? '${level1.upgradeCost.money}€ + ${level1.upgradeCost.gems}💎'
          : '${level1.upgradeCost.money}€';
      setState(() => _costText = costText);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createAssociation() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final association = await AssociationService.createAssociation(
        name: _nameController.text,
        language: _selectedLanguage,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
      );

      if (!mounted) return;

      if (association != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Asociación creada exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al crear la asociación'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.purpleAccent, width: 2),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Text(
                'CREAR ASOCIACIÓN',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Nombre
              Text(
                'Nombre de la Asociación',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                enabled: !_isLoading,
                maxLength: 50,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ej: Mercados Pro',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.purpleAccent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.purpleAccent.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Idioma
              Text(
                'Idioma Principal',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _selectedLanguage,
                isExpanded: true,
                dropdownColor: const Color(0xFF0F172A),
                style: GoogleFonts.inter(color: Colors.white),
                items: languages.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedLanguage = value);
                        }
                      },
              ),
              const SizedBox(height: 16),

              // Descripción
              Text(
                'Descripción (Opcional)',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                enabled: !_isLoading,
                maxLength: 200,
                maxLines: 3,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cuéntanos sobre tu asociación...',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.purpleAccent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.purpleAccent.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Costo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Costo de Creación',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _costText,
                      style: GoogleFonts.inter(
                        color: Colors.greenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: IndustrialButton(
                      label: 'Cancelar',
                      width: double.infinity,
                      height: 48,
                      fontSize: 14,
                      gradientTop: Colors.grey[600]!,
                      gradientBottom: Colors.grey[800]!,
                      borderColor: Colors.grey[700]!,
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IndustrialButton(
                      label: 'Crear',
                      width: double.infinity,
                      height: 48,
                      fontSize: 14,
                      gradientTop: Colors.green[400]!,
                      gradientBottom: Colors.green[700]!,
                      borderColor: Colors.green[600]!,
                      onPressed: _isLoading ? null : _createAssociation,
                    ),
                  ),
                ],
              ),

              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
