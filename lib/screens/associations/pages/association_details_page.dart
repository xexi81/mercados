import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/data/associations/association_repository.dart';
import 'package:industrial_app/services/supabase_service.dart';
import 'package:industrial_app/data/associations/association_model.dart';
import 'package:industrial_app/data/associations/association_member_model.dart';
import 'package:industrial_app/data/associations/association_level_model.dart';
import 'package:industrial_app/widgets/associations/association_mini_card.dart';
import 'package:industrial_app/widgets/associations/association_description_dialog.dart';
import 'package:industrial_app/widgets/associations/member_permissions_dialog.dart';
import 'package:industrial_app/screens/associations/association_requests_screen.dart';
import 'package:industrial_app/screens/associations/association_donation_screen.dart';
import 'package:industrial_app/data/experience/experience_service.dart';
import 'package:industrial_app/widgets/confirmation_dialog.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:intl/intl.dart';

class AssociationDetailsPage extends StatefulWidget {
  final String userId;

  const AssociationDetailsPage({super.key, required this.userId});

  @override
  State<AssociationDetailsPage> createState() => _AssociationDetailsPageState();
}

class _AssociationDetailsPageState extends State<AssociationDetailsPage> {
  AssociationModel? _association;
  List<AssociationMemberModel> _members = [];
  Map<String, Map<String, dynamic>> _memberUserData = {};
  AssociationMemberModel? _currentUserMember;
  AssociationLevelModel? _nextLevelData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final assoc = await AssociationRepository.getUserAssociation(
        widget.userId,
      );

      if (assoc != null) {
        final members = await AssociationRepository.getAssociationMembers(
          assoc.id,
        );
        final Map<String, Map<String, dynamic>> memberData = {};

        for (var member in members) {
          final userDoc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(member.userId)
              .get();
          if (userDoc.exists) {
            memberData[member.userId] = userDoc.data()!;
          }
        }

        final nextLevel = await AssociationRepository.getLevelByNumber(
          assoc.level,
        );

        if (mounted) {
          setState(() {
            _association = assoc;
            _members = members;
            _memberUserData = memberData;
            _currentUserMember = members.firstWhere(
              (m) => m.userId == widget.userId,
            );
            _nextLevelData = nextLevel;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error loading association data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getLanguageEmoji(String languageCode) {
    const languageFlags = {
      'es': '🇪🇸',
      'en': '🇺🇸',
      'pt': '🇵🇹',
      'fr': '🇫🇷',
    };
    return languageFlags[languageCode] ?? '🌐';
  }

  double _getExperienceProgress(AssociationLevelModel? currentLevelData) {
    if (_association == null || currentLevelData == null) return 0;
    final double required = currentLevelData.requiredExperience.toDouble();
    if (required <= 0) return 1.0;
    return (_association!.experiencePool / required).clamp(0.0, 1.0);
  }

  bool _canLevelUp(AssociationLevelModel? currentLevelData) {
    if (_association == null || currentLevelData == null) return false;
    final bool hasXP =
        _association!.experiencePool >= currentLevelData.requiredExperience;
    final bool hasMoney =
        _association!.moneyPool >= currentLevelData.upgradeCost.money;
    final bool hasGems =
        _association!.gemsPool >= currentLevelData.upgradeCost.gems;
    return hasXP && hasMoney && hasGems;
  }

  Future<void> _handleLevelUp() async {
    if (_association == null || _nextLevelData == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'SUBIR DE NIVEL',
        message:
            '¿Deseas subir la asociación al nivel ${_association!.level + 1}?\nCoste: ${NumberFormat('#,###').format(_nextLevelData!.upgradeCost.money)} monedas y ${NumberFormat('#,###').format(_nextLevelData!.upgradeCost.gems)} gemas.',
      ),
    );

    if (confirmed == true) {
      try {
        await AssociationRepository.upgradeAssociationLevel(
          associationId: _association!.id,
          newLevel: _association!.level + 1,
        );
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showDescriptionDialog() async {
    final bool canEdit =
        _currentUserMember?.role == AssociationRole.creator ||
        (_currentUserMember?.permissions['edit_info'] ?? false);

    showDialog(
      context: context,
      builder: (context) => AssociationDescriptionDialog(
        initialDescription: _association?.description ?? '',
        canEdit: canEdit,
        onSave: (newDesc) async {
          if (_association == null) return;
          final updated = _association!.copyWith(description: newDesc);
          await AssociationRepository.updateAssociation(updated);
          _loadData();
        },
      ),
    );
  }

  Future<void> _showMemberOptions(AssociationMemberModel member) async {
    final Map<String, dynamic> userData = _memberUserData[member.userId] ?? {};
    final String nickname =
        userData['nickname'] ??
        userData['empresa'] ??
        userData['nombre'] ??
        'Usuario';

    final bool canManage =
        _currentUserMember?.role == AssociationRole.creator ||
        (_currentUserMember?.permissions['manage_ranks'] ?? false);

    showDialog(
      context: context,
      builder: (context) => MemberPermissionsDialog(
        userName: nickname,
        currentPermissions: member.permissions,
        canEdit: canManage && member.role != AssociationRole.creator,
        isCreator:
            _currentUserMember?.role == AssociationRole.creator &&
            member.userId != widget.userId,
        onPermissionsChanged: (newPerms) async {
          await AssociationRepository.client
              .from('association_members')
              .update({'permissions': newPerms})
              .eq('id', member.id);
          _loadData();
        },
        onKick: () async {
          final bool? confirmKick = await showDialog<bool>(
            context: context,
            builder: (context) => ConfirmationDialog(
              title: 'ECHAR MIEMBRO',
              message:
                  '¿Estás seguro de que deseas echar a $nickname de la asociación?',
            ),
          );
          if (confirmKick == true) {
            await AssociationRepository.kickMember(memberId: member.id);
            if (mounted) Navigator.pop(context);
            _loadData();
          }
        },
      ),
    );
  }

  Future<void> _handleLeaveOrDelete() async {
    if (_association == null || _currentUserMember == null) return;
    final bool isCreator = _currentUserMember!.role == AssociationRole.creator;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: isCreator ? 'ELIMINAR ASOCIACIÓN' : 'ABANDONAR ASOCIACIÓN',
        message: isCreator
            ? 'Esta acción es irreversible y se eliminará toda la asociación. ¿Continuar?'
            : '¿Estás seguro de que deseas abandonar esta asociación?',
      ),
    );

    if (confirmed == true) {
      try {
        if (isCreator) {
          await AssociationRepository.deleteAssociation(_association!.id);
        } else {
          await AssociationRepository.leaveAssociation(
            memberId: _currentUserMember!.id,
          );
        }
        if (mounted) Navigator.pop(context);
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
      appBar: const CustomGameAppBar(),
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _association == null
          ? const Center(
              child: Text(
                'Asociación no encontrada',
                style: TextStyle(color: Colors.white),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Encabezado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _association!.name,
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _getLanguageEmoji(_association!.language),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nivel
                    _buildLevelSection(),
                    const SizedBox(height: 24),

                    // Menu Minicards
                    _buildMiniCardsMenu(),
                    const SizedBox(height: 32),

                    // Bolsa de recursos (Donar)
                    _buildResourcesSection(),
                    const SizedBox(height: 32),

                    // Miembros
                    _buildMembersSection(),
                    const SizedBox(height: 40),

                    // Botón Abandonar/Eliminar
                    IndustrialButton(
                      label: _currentUserMember?.role == AssociationRole.creator
                          ? 'ELIMINAR ASOCIACIÓN'
                          : 'ABANDONAR ASOCIACIÓN',
                      height: 50,
                      gradientTop: Colors.red[700]!,
                      gradientBottom: Colors.black,
                      borderColor: Colors.red[900]!,
                      onPressed: _handleLeaveOrDelete,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLevelSection() {
    final bool canUpgrade = _canLevelUp(_nextLevelData);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canUpgrade ? Colors.amber : Colors.amber.withOpacity(0.3),
          width: canUpgrade ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NIVEL ${_association!.level}',
                style: GoogleFonts.orbitron(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (canUpgrade)
                GestureDetector(
                  onTap: _handleLevelUp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '¡SUBIR!',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _getExperienceProgress(_nextLevelData),
              minHeight: 10,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(Colors.amber.withOpacity(0.8)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'XP: ${NumberFormat('#,###').format(_association!.experiencePool)} / ${NumberFormat('#,###').format(_nextLevelData?.requiredExperience ?? 0)}',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCardsMenu() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          AssociationMiniCard(
            label: 'Descripción',
            icon: const Icon(
              Icons.description,
              color: Colors.purpleAccent,
              size: 30,
            ),
            onTap: _showDescriptionDialog,
          ),
          const SizedBox(width: 16),
          AssociationMiniCard(
            label: 'Solicitudes',
            icon: const Icon(
              Icons.person_add,
              color: Colors.blueAccent,
              size: 30,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AssociationRequestsScreen(associationId: _association!.id),
              ),
            ),
          ),
          const SizedBox(width: 16),
          AssociationMiniCard(
            label: 'Chat',
            icon: const Icon(Icons.chat, color: Colors.greenAccent, size: 30),
            onTap: () {}, // Futuro
          ),
          const SizedBox(width: 16),
          AssociationMiniCard(
            label: 'Logros',
            icon: const Icon(
              Icons.emoji_events,
              color: Colors.amberAccent,
              size: 30,
            ),
            onTap: () {}, // Futuro
          ),
          const SizedBox(width: 16),
          AssociationMiniCard(
            label: 'Contratos',
            icon: const Icon(
              Icons.handshake,
              color: Colors.orangeAccent,
              size: 30,
            ),
            onTap: () {}, // Futuro
          ),
        ],
      ),
    );
  }

  Widget _buildResourcesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildResourceItem(
                'assets/images/billete.png',
                _association!.moneyPool,
              ),
              _buildResourceItem(
                'assets/images/gemas.png',
                _association!.gemsPool,
              ),
            ],
          ),
          const SizedBox(height: 16),
          IndustrialButton(
            label: 'DONAR',
            height: 45,
            gradientTop: Colors.green[400]!,
            gradientBottom: Colors.green[700]!,
            borderColor: Colors.green[200]!,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AssociationDonationScreen(associationId: _association!.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceItem(String asset, double value) {
    return Row(
      children: [
        Image.asset(asset, width: 35, height: 35),
        const SizedBox(width: 8),
        Text(
          NumberFormat.compact().format(value),
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MIEMBROS (${_members.length})',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final member = _members[index];
            final userData = _memberUserData[member.userId] ?? {};
            final String nickname =
                userData['nickname'] ??
                userData['empresa'] ??
                userData['nombre'] ??
                'Usuario';
            final String photoUrl = userData['foto_url'] ?? '';
            final int experience =
                (userData['experience'] as num?)?.toInt() ?? 0;
            final int level = ExperienceService.getLevelFromExperience(
              experience,
            );

            return GestureDetector(
              onTap: () => _showMemberOptions(member),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      backgroundColor: AppColors.primary,
                      child: photoUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nickname,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            member.role.name.toUpperCase(),
                            style: TextStyle(
                              color: member.role == AssociationRole.creator
                                  ? Colors.amber
                                  : Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LVL $level',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
