import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:industrial_app/screens/chat_screen.dart';
import 'package:industrial_app/services/supabase_service.dart'; // Ajusta si la ruta es diferente
import 'package:industrial_app/widgets/custom_game_appbar.dart';
import 'package:industrial_app/theme/app_colors.dart'; // Ajusta imports según estructura

class AssociationScreen extends StatefulWidget {
  const AssociationScreen({super.key});

  @override
  State<AssociationScreen> createState() => _AssociationScreenState();
}

class _AssociationScreenState extends State<AssociationScreen> {
  bool _isLoading = false;

  /// Maneja la entrada al chat global
  Future<void> _enterGlobalChat() async {
    final user = auth.FirebaseAuth.instance.currentUser;
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

      // 2. Obtener/Crear el chat global (Por ahora hardcodeado a 'es')
      // En el futuro, esto podría venir de un Provider de idioma
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

  /// Placeholder para asociaciones
  void _enterAssociations() {
    // Aquí iría la lógica para listar asociaciones o chats de grupos
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcionalidad de Asociaciones próximamente'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGameAppBar(),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Comunidad',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Opción 1: Chat Global
                _MenuCard(
                  title: 'Chat Global',
                  subtitle: 'Conecta con jugadores de tu idioma',
                  icon: Icons.public,
                  color: Colors.blueAccent,
                  onTap: _enterGlobalChat,
                ),

                const SizedBox(height: 20),

                // Opción 2: Asociaciones (Grupos)
                _MenuCard(
                  title: 'Asociaciones',
                  subtitle: 'Únete a un gremio de transporte',
                  icon: Icons.groups,
                  color: Colors.purpleAccent,
                  onTap: _enterAssociations,
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.onSurface.withOpacity(0.3),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
