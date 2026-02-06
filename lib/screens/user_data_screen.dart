import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:industrial_app/services/supabase_service.dart';
import 'package:industrial_app/screens/chat_screen.dart';
import 'package:industrial_app/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class UserDataScreen extends StatefulWidget {
  const UserDataScreen({super.key});

  @override
  State<UserDataScreen> createState() => _UserDataScreenState();
}

class _UserDataScreenState extends State<UserDataScreen> {
  bool _isLoading = false;

  Future<void> _enterGlobalChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No hay usuario autenticado')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Asegurar que el usuario existe en Supabase
      await SupabaseService.ensureUserExists(user);

      // 2. Obtener/Crear el chat global
      const languageCode = 'es';
      final chatId = await SupabaseService.getOrCreateChatId(
        'global',
        languageCode,
        'Chat Global (Español)',
      );

      if (!mounted) return;

      // 3. Navegar
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(chatId: chatId, chatName: 'Chat Global (ES)'),
        ),
      );
    } catch (e) {
      debugPrint('Error entrando al chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de Usuario')),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono de chat global con botón
                  GestureDetector(
                    onTap: _isLoading ? null : _enterGlobalChat,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.public_rounded,
                        size: 64,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chat Global',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Accede al chat público con todos los transportistas',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 16,
                      textBaseline: TextBaseline.alphabetic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Más datos de usuario pueden agregarse aquí en el futuro
                  const Text(
                    'Más información próximamente...',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      backgroundColor: AppColors.surface,
    );
  }
}
