import 'package:flutter/material.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:industrial_app/widgets/industrial_button.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;

  const ConfirmationDialog({
    Key? key,
    required this.title,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white, width: 2),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: IndustrialButton(
                label: 'Cancelar',
                onPressed: () => Navigator.pop(context, false),
                gradientTop: Colors.grey[700]!,
                gradientBottom: Colors.grey[900]!,
                borderColor: Colors.grey[800]!,
                height: 45,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: IndustrialButton(
                label: 'Aceptar',
                onPressed: () => Navigator.pop(context, true),
                gradientTop: const Color(0xFF4CAF50),
                gradientBottom: const Color(0xFF2E7D32),
                borderColor: const Color(0xFF1B5E20),
                height: 45,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
