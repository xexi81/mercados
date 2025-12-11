import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 👈 IMPORTANTE

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Icono de la app (PNG, esto está bien)
                Center(
                  child: Image.asset(
                    'assets/images/ejemplo2.png',
                    width: 144,
                    height: 144,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 32),

                // Título
                Text(
                  'SUPPLY CHAIN',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'TYCOON',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 8,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Subtítulo
                Text(
                  'Simula toda la cadena productiva',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Botón Google
                _AuthButton(
                  text: 'Continuar con Google',
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF111827),
                  iconAsset: 'assets/images/google.svg',
                  isSvg: true, // 👈 IMPORTANTE
                ),
                const SizedBox(height: 16),

                // Botón Apple
                _AuthButton(
                  text: 'Continuar con Apple',
                  backgroundColor: const Color(0xFF020617),
                  foregroundColor: Colors.white,
                  iconAsset: 'assets/images/apple.svg',
                  isSvg: true,
                ),
                const SizedBox(height: 16),

                // Botón Facebook
                _AuthButton(
                  text: 'Continuar con Facebook',
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  iconAsset: 'assets/images/facebook.svg',
                  isSvg: true,
                ),

                const Spacer(flex: 3),

                // Términos / Privacidad
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Términos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Privacidad',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón reutilizable de autenticación
class _AuthButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;
  final String iconAsset;
  final bool isSvg;

  const _AuthButton({
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconAsset,
    this.isSvg = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget icon = isSvg
        ? SvgPicture.asset(iconAsset, width: 48, height: 48)
        : Image.asset(iconAsset, width: 48, height: 48, fit: BoxFit.contain);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // TODO: integrar con tu lógica de autenticación
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
