import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/industrial_button.dart';
import 'package:industrial_app/widgets/associations/association_mini_card.dart';

class MemberPermissionsDialog extends StatefulWidget {
  final Map<String, bool> currentPermissions;
  final bool canEdit;
  final bool isCreator;
  final String userName;
  final Function(Map<String, bool>) onPermissionsChanged;
  final VoidCallback onKick;

  const MemberPermissionsDialog({
    super.key,
    required this.currentPermissions,
    required this.canEdit,
    required this.isCreator,
    required this.userName,
    required this.onPermissionsChanged,
    required this.onKick,
  });

  @override
  State<MemberPermissionsDialog> createState() =>
      _MemberPermissionsDialogState();
}

class _MemberPermissionsDialogState extends State<MemberPermissionsDialog> {
  late Map<String, bool> _permissions;

  final Map<String, String> _permissionLabels = {
    'invite': 'Invitar',
    'kick': 'Echar',
    'edit_info': 'Editar Info',
    'manage_ranks': 'Rangos',
    'donation_manager': 'Donaciones',
    'contracts': 'Contratos',
  };

  @override
  void initState() {
    super.initState();
    _permissions = Map<String, bool>.from(widget.currentPermissions);
  }

  void _togglePermission(String key) {
    if (!widget.canEdit) return;
    setState(() {
      _permissions[key] = !(_permissions[key] ?? false);
    });
    widget.onPermissionsChanged(_permissions);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PERMISOS',
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userName,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _permissionLabels.entries.map((entry) {
                final bool isActive = _permissions[entry.key] ?? false;
                return AssociationMiniCard(
                  label: entry.value,
                  icon: Icon(
                    _getIconForPermission(entry.key),
                    color: isActive ? Colors.greenAccent : Colors.redAccent,
                    size: 28,
                  ),
                  onTap: () => _togglePermission(entry.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            if (widget.isCreator) ...[
              IndustrialButton(
                label: 'ECHAR AL MIEMBRO',
                height: 45,
                gradientTop: Colors.red[400]!,
                gradientBottom: Colors.red[800]!,
                borderColor: Colors.red[200]!,
                onPressed: widget.onKick,
              ),
              const SizedBox(height: 16),
            ],
            IndustrialButton(
              label: 'CERRAR',
              height: 45,
              gradientTop: Colors.grey[600]!,
              gradientBottom: Colors.grey[800]!,
              borderColor: Colors.grey[400]!,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForPermission(String key) {
    switch (key) {
      case 'invite':
        return Icons.person_add;
      case 'kick':
        return Icons.person_remove;
      case 'edit_info':
        return Icons.edit;
      case 'manage_ranks':
        return Icons.military_tech;
      case 'donation_manager':
        return Icons.volunteer_activism;
      case 'contracts':
        return Icons.assignment;
      default:
        return Icons.lock;
    }
  }
}
