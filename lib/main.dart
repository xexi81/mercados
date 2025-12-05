import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Industrial App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF1E3A8A), // Azul industrial
          onPrimary: Colors.white,
          secondary: Color(0xFF16A34A), // Verde éxito
          onSecondary: Colors.white,
          error: Color(0xFFDC2626), // Rojo
          onError: Colors.white,
          surface: Color(0xFF0F172A), // Fondo oscuro
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Fondo oscuro
        cardColor: const Color(0xFFF1F5F9), // Fondo de tarjetas (Gris claro)
        
        // Custom colors can be accessed via extensions or just used directly in widgets,
        // but defining the main ones here helps.
        // Advertencias: #EA580C (Orange)
        // Acentos técnicos: #7C3AED (Purple)

        textTheme: TextTheme(
          displayLarge: GoogleFonts.orbitron(),
          displayMedium: GoogleFonts.orbitron(),
          displaySmall: GoogleFonts.orbitron(),
          headlineLarge: GoogleFonts.orbitron(),
          headlineMedium: GoogleFonts.orbitron(),
          headlineSmall: GoogleFonts.orbitron(),
          titleLarge: GoogleFonts.orbitron(),
          titleMedium: GoogleFonts.orbitron(),
          titleSmall: GoogleFonts.orbitron(),
          
          bodyLarge: GoogleFonts.inter(),
          bodyMedium: GoogleFonts.inter(),
          bodySmall: GoogleFonts.inter(),
          labelLarge: GoogleFonts.inter(),
          labelMedium: GoogleFonts.inter(),
          labelSmall: GoogleFonts.inter(),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/ejemplo2.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            // Optional Loading Text or Indicator
            Text(
              'INICIANDO SISTEMAaaaa...',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF7C3AED), // Acento técnico (Morado) for visibility
                fontSize: 18,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Color(0xFF16A34A), // Verde éxito
            ),
          ],
        ),
      ),
    );
  }
}
