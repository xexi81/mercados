import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_colors.dart';
import 'screens/splash_screen.dart';

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
          primary: AppColors.primary, // Azul industrial
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.secondary, // Verde éxito
          onSecondary: AppColors.onSecondary,
          error: AppColors.error, // Rojo
          onError: AppColors.onError,
          surface: AppColors.surface, // Fondo oscuro
          onSurface: AppColors.onSurface,
        ),
        scaffoldBackgroundColor: AppColors.surface, // Fondo oscuro
        cardColor: AppColors.card, // Fondo de tarjetas (Gris claro)
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
      home: SplashScreen(),
    );
  }
}
