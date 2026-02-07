import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/industrial_button.dart';

class AssociationDescriptionDialog extends StatefulWidget {
  final String initialDescription;
  final bool canEdit;
  final Function(String) onSave;

  const AssociationDescriptionDialog({
    super.key,
    required this.initialDescription,
    required this.canEdit,
    required this.onSave,
  });

  @override
  State<AssociationDescriptionDialog> createState() =>
      _AssociationDescriptionDialogState();
}

class _AssociationDescriptionDialogState
    extends State<AssociationDescriptionDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              'DESCRIPCIÓN',
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              maxLines: 6,
              maxLength: 500,
              readOnly: !widget.canEdit,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Describe tu asociación...',
                hintStyle: GoogleFonts.inter(color: Colors.white38),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                counterStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: IndustrialButton(
                    label: 'CERRAR',
                    height: 50,
                    gradientTop: Colors.grey[600]!,
                    gradientBottom: Colors.grey[800]!,
                    borderColor: Colors.grey[400]!,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                if (widget.canEdit) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: IndustrialButton(
                      label: 'GUARDAR',
                      height: 50,
                      gradientTop: Colors.green[400]!,
                      gradientBottom: Colors.green[700]!,
                      borderColor: Colors.green[200]!,
                      onPressed: () {
                        widget.onSave(_controller.text);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
