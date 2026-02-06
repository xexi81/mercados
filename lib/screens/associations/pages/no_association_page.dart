import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/screens/associations/pages/search_associations_page.dart';
import 'package:industrial_app/screens/associations/pages/create_association_dialog.dart';
import 'package:industrial_app/data/associations/association_repository.dart';

class NoAssociationPage extends StatefulWidget {
  const NoAssociationPage({super.key});

  @override
  State<NoAssociationPage> createState() => _NoAssociationPageState();
}

class _NoAssociationPageState extends State<NoAssociationPage> {
  String _costText = 'Cargando...';

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

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateAssociationDialog(),
    ).then((_) {
      // Recargar si fue creada
      Navigator.pop(context, true);
    });
  }

  void _goToSearch(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SearchAssociationsPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Icono grande
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple.withOpacity(0.1),
                    border: Border.all(color: Colors.purpleAccent, width: 2),
                  ),
                  child: const Icon(
                    Icons.groups_outlined,
                    size: 64,
                    color: Colors.purpleAccent,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Texto principal
              Text(
                'NO TIENES ASOCIACIÓN',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Descripción
              Text(
                'Únete a una comunidad de transportistas o crea la tuya propia',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Botón crear asociación
              IndustrialButton(
                label: '+ CREAR ASOCIACIÓN',
                width: double.infinity,
                height: 60,
                fontSize: 16,
                gradientTop: Colors.green[400]!,
                gradientBottom: Colors.green[700]!,
                borderColor: Colors.green[600]!,
                onPressed: () => _showCreateDialog(context),
              ),
              const SizedBox(height: 16),

              // Descripción de costo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  'Costo: $_costText',
                  style: GoogleFonts.inter(
                    color: Colors.greenAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Divisor
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white30)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'O',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white30)),
                ],
              ),
              const SizedBox(height: 32),

              // Botón buscar asociaciones
              IndustrialButton(
                label: '🔍 BUSCAR ASOCIACIONES',
                width: double.infinity,
                height: 60,
                fontSize: 16,
                gradientTop: Colors.blueAccent,
                gradientBottom: Colors.blue[700]!,
                borderColor: Colors.blue[600]!,
                onPressed: () => _goToSearch(context),
              ),
              const SizedBox(height: 16),

              // Descripción
              Text(
                'Explora asociaciones existentes y solicita unirte',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 100,
              ), // Margen inferior para barra de Android
            ],
          ),
        ),
      ),
    );
  }
}
