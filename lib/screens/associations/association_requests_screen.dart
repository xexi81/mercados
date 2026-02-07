import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/data/associations/association_repository.dart';
import 'package:industrial_app/data/associations/association_request_model.dart';
import 'package:industrial_app/data/experience/experience_service.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/confirmation_dialog.dart';

class AssociationRequestsScreen extends StatefulWidget {
  final String associationId;

  const AssociationRequestsScreen({super.key, required this.associationId});

  @override
  State<AssociationRequestsScreen> createState() =>
      _AssociationRequestsScreenState();
}

class _AssociationRequestsScreenState extends State<AssociationRequestsScreen> {
  List<AssociationRequestModel> _requests = [];
  Map<String, Map<String, dynamic>> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final requests = await AssociationRepository.getPendingRequests(
        widget.associationId,
      );
      final Map<String, Map<String, dynamic>> userData = {};

      for (var req in requests) {
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(req.userId)
            .get();
        if (userDoc.exists) {
          userData[req.userId] = userDoc.data()!;
        }
      }

      if (mounted) {
        setState(() {
          _requests = requests;
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRequest(
    AssociationRequestModel request,
    bool accept,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: accept ? 'ACEPTAR SOLICITUD' : 'RECHAZAR SOLICITUD',
        message:
            '¿Estás seguro de que deseas ${accept ? 'aceptar' : 'rechazar'} a este usuario?',
      ),
    );

    if (confirmed == true) {
      try {
        if (accept) {
          await AssociationRepository.acceptRequest(
            requestId: request.id,
            userId: request.userId,
            associationId: widget.associationId,
            resolvedBy: null, // Should pass current user ID ideally
          );
        } else {
          await AssociationRepository.rejectRequest(
            requestId: request.id,
            resolvedBy: null,
          );
        }
        _loadRequests();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'SOLICITUDES',
          style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(
              child: Text(
                'No hay solicitudes pendientes',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final user = _userData[req.userId] ?? {};
                final String nickname =
                    user['nickname'] ??
                    user['empresa'] ??
                    user['nombre'] ??
                    'Usuario';
                final String photoUrl = user['foto_url'] ?? '';
                final int experience =
                    (user['experience'] as num?)?.toInt() ?? 0;
                final int level = ExperienceService.getLevelFromExperience(
                  experience,
                );
                final String company = user['empresa'] ?? 'Sin empresa';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            backgroundColor: AppColors.primary,
                            child: photoUrl.isEmpty
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nickname,
                                  style: GoogleFonts.orbitron(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  company,
                                  style: GoogleFonts.inter(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Nivel $level',
                                  style: GoogleFonts.inter(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${req.requestedAt.day}/${req.requestedAt.month}/${req.requestedAt.year}',
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: IndustrialButton(
                              label: 'RECHAZAR',
                              height: 40,
                              gradientTop: Colors.red[400]!,
                              gradientBottom: Colors.red[800]!,
                              borderColor: Colors.red[200]!,
                              onPressed: () => _handleRequest(req, false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: IndustrialButton(
                              label: 'ACEPTAR',
                              height: 40,
                              gradientTop: Colors.green[400]!,
                              gradientBottom: Colors.green[700]!,
                              borderColor: Colors.green[200]!,
                              onPressed: () => _handleRequest(req, true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
