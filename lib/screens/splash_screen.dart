import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/frases_iniciales.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final String frase;

  @override
  void initState() {
    super.initState();
    frase = FrasesIniciales().generarFraseRandom();

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;

      // Verificar si hay un usuario logueado en Firebase
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Usuario logueado, ir directamente a MainScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        // No hay usuario logueado, ir a LoginScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/ejemplo2.png', width: 200, height: 200),
            const SizedBox(height: 40),
            Text(
              frase,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

