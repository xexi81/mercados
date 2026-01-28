import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_game_appbar.dart';
import '../theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    try {
      await SupabaseService.sendMessage(widget.chatId, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error enviando mensaje: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomGameAppBar(title: widget.chatName),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay mensajes aún.\n¡Sé el primero en escribir!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final userId = msg['user_id'] as String;
                    final isMe = userId == _currentUserId;
                    final content = msg['content'] as String;
                    final createdAt = DateTime.parse(
                      msg['created_at'],
                    ).toLocal();
                    final timeStr = DateFormat('HH:mm').format(createdAt);

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // Nombre de usuario (solo si no soy yo)
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  bottom: 2,
                                ),
                                child: _UserDisplayName(userId: userId),
                              ),

                            // Burbuja de mensaje
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors
                                          .primary // Azul oscuro (Mío)
                                    : const Color(
                                        0xFFE0F2FE,
                                      ), // Azul muy claro (Recibido)
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                  bottomRight: isMe
                                      ? Radius.zero
                                      : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    content,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : const Color(
                                              0xFF0C4A6E,
                                            ), // Azul muy oscuro
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color:
                                          (isMe
                                                  ? Colors.white
                                                  : const Color(0xFF0C4A6E))
                                              .withOpacity(0.6),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.surface,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                // Texto azul oscuro para contraste sobre fondo blanco
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.8)),
                  filled: true,
                  fillColor: Colors.white, // Fondo blanco total
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _sendMessage,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              mini: true,
              child: const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget helper para mostrar el nombre del usuario cargado asíncronamente
class _UserDisplayName extends StatelessWidget {
  final String userId;

  const _UserDisplayName({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseService.getUserProfile(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 20,
            height: 10,
          ); // Placeholder invisible o shimmer
        }

        final username = snapshot.data?['username'] ?? 'Usuario';

        return Text(
          username,
          style: const TextStyle(
            color: Colors.white70, // Nombre sobre el fondo oscuro de la app
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }
}
