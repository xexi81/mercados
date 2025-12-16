import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class UserConfigScreen extends StatefulWidget {
  const UserConfigScreen({super.key});

  @override
  State<UserConfigScreen> createState() => _UserConfigScreenState();
}

class _UserConfigScreenState extends State<UserConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers para los campos editables
  final _nicknameController = TextEditingController();
  final _empresaController = TextEditingController();
  
  // Preferencias
  bool _notificacionesActivas = true;
  bool _sonidosActivos = true;
  String _idiomaSeleccionado = 'Español';
  
  bool _isLoading = true;
  User? _user;

  final List<String> _idiomas = ['Español', 'English', 'Français', 'Deutsch'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _empresaController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    _user = FirebaseAuth.instance.currentUser;
    
    if (_user != null) {
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_user!.uid)
            .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          setState(() {
            _nicknameController.text = data['nickname'] ?? '';
            _empresaController.text = data['empresa'] ?? '';
            _notificacionesActivas = data['notificaciones'] ?? true;
            _sonidosActivos = data['sonidos'] ?? true;
            _idiomaSeleccionado = data['idioma'] ?? 'Español';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint('Error cargando datos del usuario: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUserConfig() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_user!.uid)
          .update({
        'nickname': _nicknameController.text.trim(),
        'empresa': _empresaController.text.trim(),
        'notificaciones': _notificacionesActivas,
        'sonidos': _sonidosActivos,
        'idioma': _idiomaSeleccionado,
        'fecha_modificacion': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Configuración guardada correctamente'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Configuración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveUserConfig,
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto de perfil y datos básicos
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _user?.photoURL != null
                                ? NetworkImage(_user!.photoURL!)
                                : null,
                            backgroundColor: colorScheme.primary,
                            child: _user?.photoURL == null
                                ? const Icon(Icons.person, size: 50, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _user?.displayName ?? 'Usuario',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?.email ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Sección: Perfil del jugador
                    Text(
                      'PERFIL DEL JUGADOR',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nickname
                    TextFormField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        labelText: 'Nickname',
                        hintText: 'Tu nombre en el juego',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),

                    const SizedBox(height: 16),

                    // Empresa
                    TextFormField(
                      controller: _empresaController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de tu empresa',
                        hintText: 'Ej: Acme Industries',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),

                    const SizedBox(height: 32),

                    // Sección: Preferencias
                    Text(
                      'PREFERENCIAS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Idioma
                    DropdownButtonFormField<String>(
                      value: _idiomaSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Idioma',
                        prefixIcon: const Icon(Icons.language),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                      items: _idiomas.map((idioma) {
                        return DropdownMenuItem(
                          value: idioma,
                          child: Text(idioma),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _idiomaSeleccionado = value!);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Notificaciones
                    SwitchListTile(
                      title: const Text('Notificaciones'),
                      subtitle: const Text('Recibir alertas del juego'),
                      secondary: const Icon(Icons.notifications),
                      value: _notificacionesActivas,
                      onChanged: (value) {
                        setState(() => _notificacionesActivas = value);
                      },
                      activeColor: colorScheme.secondary,
                      tileColor: colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Sonidos
                    SwitchListTile(
                      title: const Text('Sonidos'),
                      subtitle: const Text('Efectos de sonido en el juego'),
                      secondary: const Icon(Icons.volume_up),
                      value: _sonidosActivos,
                      onChanged: (value) {
                        setState(() => _sonidosActivos = value);
                      },
                      activeColor: colorScheme.secondary,
                      tileColor: colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveUserConfig,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar Configuración'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botón Cerrar Sesión
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar Sesión'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
