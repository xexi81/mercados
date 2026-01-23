import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IndustrialButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color gradientTop;
  final Color gradientBottom;
  final Color borderColor;
  final double? width;
  final double? height;
  final double fontSize;

  const IndustrialButton({
    Key? key,
    required this.label,
    required this.onPressed,
    required this.gradientTop,
    required this.gradientBottom,
    required this.borderColor,
    this.width,
    this.height,
    this.fontSize = 18,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientTop, gradientBottom],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
