import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/data/associations/association_model.dart';
import 'package:industrial_app/data/associations/association_repository.dart';
import 'package:industrial_app/widgets/industrial_button.dart';

class AssociationCard extends StatefulWidget {
  final AssociationModel association;

  const AssociationCard({super.key, required this.association});

  @override
  State<AssociationCard> createState() => _AssociationCardState();
}

class _AssociationCardState extends State<AssociationCard> {
  bool _isLoading = false;
  int _memberCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMemberCount();
  }

  Future<void> _loadMemberCount() async {
    try {
      final members = await AssociationRepository.getAssociationMembers(
        widget.association.id,
      );
      setState(() => _memberCount = members.length);
    } catch (e) {
      debugPrint('Error loading member count: $e');
    }
  }

  Future<void> _requestToJoin() async {
    setState(() => _isLoading = true);
    try {
      await AssociationRepository.createRequest(
        associationId: widget.association.id,
        userId: 'user_id', // This should come from FirebaseAuth
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Solicitud enviada!'),
            backgroundColor: Colors.green,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Nivel y Nombre
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nivel badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Text(
                    'Lvl ${widget.association.level}',
                    style: GoogleFonts.orbitron(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nombre
                Expanded(
                  child: Text(
                    widget.association.name,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Descripción
            if (widget.association.description != null) ...[
              Text(
                widget.association.description!,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],

            // Estadísticas
            Row(
              children: [
                // Miembros
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '👥 Miembros',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_memberCount/∞',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Dinero en bolsa
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💰 Bolsa',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.association.moneyPool.toStringAsFixed(0)}€',
                          style: GoogleFonts.orbitron(
                            color: Colors.greenAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Botón solicitar
            IndustrialButton(
              label: 'SOLICITAR UNIRSE',
              width: double.infinity,
              height: 44,
              fontSize: 14,
              gradientTop: Colors.blueAccent,
              gradientBottom: Colors.blue[700]!,
              borderColor: Colors.blue[600]!,
              onPressed: _isLoading ? null : _requestToJoin,
            ),
          ],
        ),
      ),
    );
  }
}
