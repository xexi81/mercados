import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IndustrialButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color gradientTop;
  final Color gradientBottom;
  final Color borderColor;

  const IndustrialButton({
    Key? key,
    required this.label,
    required this.onPressed,
    required this.gradientTop,
    required this.gradientBottom,
    required this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50, // Updated height as per spec (48-52)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero, // Square shape
          border: Border.all(
            color: borderColor,
            width:
                2, // Slightly wider to make the lighter color visible? User said "unos pixels".
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4), // Updated shadow
              offset: const Offset(0, 3),
              blurRadius: 8,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [gradientTop, gradientBottom],
          ),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.bold, // Bold
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
