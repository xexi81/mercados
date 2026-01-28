import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  /// Asegura que el usuario de Firebase exista en la tabla users de Supabase
  static Future<void> ensureUserExists(auth.User firebaseUser) async {
    final user = client
        .from('users')
        .select()
        .eq('id', firebaseUser.uid)
        .maybeSingle();
    final existingUser = await user;

    if (existingUser == null) {
      await client.from('users').insert({
        'id': firebaseUser.uid,
        'email': firebaseUser.email,
        'username': firebaseUser.displayName ?? 'Usuario',
        'avatar_url': firebaseUser.photoURL,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Obtiene o crea un chat ID basado en el tipo y referencia (ej: 'global', 'es')
  static Future<String> getOrCreateChatId(
    String type,
    String referenceId,
    String name,
  ) async {
    try {
      final response = await client
          .from('chats')
          .select()
          .eq('type', type)
          .eq('reference_id', referenceId)
          .maybeSingle();

      if (response != null) {
        return response['id'] as String;
      }

      // Si no existe, lo creamos
      final newChat = await client
          .from('chats')
          .insert({'type': type, 'reference_id': referenceId, 'name': name})
          .select()
          .single();

      return newChat['id'] as String;
    } catch (e) {
      throw Exception('Error al obtener el chat: $e');
    }
  }

  /// Envía un mensaje
  static Future<void> sendMessage(String chatId, String message) async {
    final user = auth.FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');

    await client.from('messages').insert({
      'chat_id': chatId,
      'user_id': user.uid,
      'content': message,
    });
  }

  /// Stream de mensajes para un chat específico
  static Stream<List<Map<String, dynamic>>> getMessagesStream(String chatId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .map((maps) => maps); // Los mapas ya vienen listos
  }
}
