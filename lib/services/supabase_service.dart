import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;
  static final Map<String, Map<String, dynamic>> _userCache = {};

  /// Asegura que el usuario de Firebase exista en la tabla users de Supabase,
  /// sincronizando el nombre desde Firestore.
  static Future<void> ensureUserExists(auth.User firebaseUser) async {
    // 1. Obtener el nombre más reciente de Firestore
    String username = firebaseUser.displayName ?? 'Usuario';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(firebaseUser.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['nombre'] != null && data['nombre'].toString().isNotEmpty) {
          username = data['nombre'];
        }
      }
    } catch (e) {
      debugPrint('Error leyendo Firestore: $e');
    }

    // 2. Insertar o Actualizar en Supabase
    try {
      await client.from('users').upsert({
        'id': firebaseUser.uid,
        'email': firebaseUser.email,
        'username': username,
        'avatar_url': firebaseUser.photoURL,
        // created_at se genera auto en insert, no lo tocamos
      });

      // Actualizamos caché local también si es necesario
      _userCache[firebaseUser.uid] = {
        'username': username,
        'avatar_url': firebaseUser.photoURL,
      };
    } catch (e) {
      debugPrint('Error upsert users: $e');
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
        .map((maps) => maps);
  }

  /// Método helper para obtener datos de un usuario por ID (con caché simple)
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final response = await client
          .from('users')
          .select('username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        _userCache[userId] = response;
      }
      return response;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }
}
