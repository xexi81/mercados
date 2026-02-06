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
                    // Banner de asociación
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.withOpacity(0.3),
                            Colors.blue.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purpleAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nivel ${_association!.level}',
                                style: GoogleFonts.orbitron(
                                  color: Colors.amber,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '👥 ${_members.length}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _association!.name,
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_association!.description != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _association!.description!,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
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
                                    '${_association!.moneyPool.toStringAsFixed(0)}€',
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
                                    '${_association!.gemsPool.toStringAsFixed(0)}',
                                    style: GoogleFonts.orbitron(
                                      color: Colors.cyanAccent,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '⭐',
                                    style: GoogleFonts.inter(fontSize: 24),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_association!.experiencePool}',
                                    style: GoogleFonts.orbitron(
                                      color: Colors.yellowAccent,
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
