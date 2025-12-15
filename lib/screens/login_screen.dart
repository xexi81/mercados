import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    // In v6, simple signInSilently works for persisting session
    GoogleSignIn()
        .signInSilently()
        .then((user) {
          if (user != null) {
            debugPrint('Sign in silently success: ${user.email}');
            _handleFirebaseLogin(user);
          }
        })
        .catchError((e) {
          debugPrint('Sign in silently failed: $e');
        });
  }

  Future<void> _handleFirebaseLogin(GoogleSignInAccount googleUser) async {
    debugPrint('_handleFirebaseLogin called for ${googleUser.email}');
    try {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      debugPrint('Got googleAuth. idToken: ${googleAuth.idToken != null}');

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth
            .accessToken, // AccessToken is often needed/available in v6
      );

      // Sign in to Firebase
      debugPrint('Signing in to Firebase...');
      await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('Firebase sign in successful');

      if (mounted) {
        debugPrint('Navigating to MainScreen...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        debugPrint('Widget not mounted, skipping navigation');
      }
    } catch (e) {
      debugPrint('Error in _handleFirebaseLogin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en Firebase Auth: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _triggerAuth() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Iniciando Google Sign-In (Popup)...')),
    );

    try {
      // PROPER v6 METHOD: signIn() works on Web as a Popup!
      final googleUser = await GoogleSignIn().signIn();

      if (googleUser != null) {
        debugPrint('User signed in: ${googleUser.email}');
        await _handleFirebaseLogin(googleUser);
      } else {
        debugPrint('Sign in aborted by user (null result)');
      }
    } catch (e) {
      debugPrint('Auth Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de autenticación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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

                // Icono de la app
                Center(
                  child: Image.asset(
                    'assets/images/ejemplo2.png',
                    width: 228,
                    height: 228,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 32),

                // Título
                Text(
                  'SUPPLY CHAIN',
                  style: theme.textTheme.titleMedium?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'TYCOON',
                  style: theme.textTheme.titleMedium?.copyWith(
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

                // Button: Standard Flutter Button for ALL platforms now
                _AuthButton(
                  text: 'Continuar con Google',
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF111827),
                  iconAsset: 'assets/images/google.svg',
                  isSvg: true,
                  onPressed: _triggerAuth,
                ),

                const SizedBox(height: 16),

                // Botón Apple
                _AuthButton(
                  text: 'Continuar con Apple',
                  backgroundColor: const Color(0xFF020617),
                  foregroundColor: Colors.white,
                  iconAsset: 'assets/images/apple.svg',
                  isSvg: true,
                  onPressed: () {},
                ),
                const SizedBox(height: 16),

                // Botón Facebook
                _AuthButton(
                  text: 'Continuar con Facebook',
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  iconAsset: 'assets/images/facebook.svg',
                  isSvg: true,
                  onPressed: () {},
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
  final VoidCallback onPressed;

  const _AuthButton({
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconAsset,
    required this.onPressed,
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
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Row(
          children: [
            SizedBox(width: 48, height: 48, child: Center(child: icon)),
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
