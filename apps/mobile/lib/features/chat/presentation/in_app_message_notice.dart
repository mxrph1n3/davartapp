import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_service.dart';
import '../../../core/router/app_router.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../profile/presentation/notification_prefs_notifier.dart';
import '../data/chat_models.dart';
import '../data/chat_socket_service.dart';
import 'chat_notifier.dart';

/// Shows the iOS system banner when a chat message arrives
/// and that thread is not already on screen.
class InAppMessageNotice extends ConsumerStatefulWidget {
  const InAppMessageNotice({super.key});

  @override
  ConsumerState<InAppMessageNotice> createState() => _InAppMessageNoticeState();
}

class _InAppMessageNoticeState extends ConsumerState<InAppMessageNotice> {
  String? _lastMessageId;
  // Kept from initState: `ref` can no longer be read inside dispose.
  ChatSocketService? _socket;

  @override
  void initState() {
    super.initState();
    final socket = ref.read(chatSocketServiceProvider);
    socket.addMessageListener(_onSocketMessage);
    _socket = socket;
  }

  @override
  void dispose() {
    _socket?.removeMessageListener(_onSocketMessage);
    super.dispose();
  }

  void _onSocketMessage(ChatMessage message) {
    final me = ref.read(authProvider).user?.id;
    if (me != null && (message.isMine || message.sender.id == me)) return;
    final text = message.content?.trim();
    final body = (text != null && text.isNotEmpty)
        ? text
        : switch (message.type) {
            'image' => 'Фото',
            'voice' => 'Голосовое сообщение',
            'file' => message.attachmentName ?? 'Файл',
            'product' => 'Товар',
            _ => 'Новое сообщение',
          };
    final name = message.sender.name.trim();
    _present(
      chatId: message.chatId,
      title: name.isEmpty ? 'Новое сообщение' : name,
      body: body,
      messageId: message.id,
    );
  }

  void _onChats(AsyncValue<List<ChatSummary>>? previous, AsyncValue<List<ChatSummary>> next) {
    final before = previous?.value;
    final after = next.value;
    if (before == null || after == null) return;

    final previousById = {for (final chat in before) chat.id: chat};
    for (final chat in after) {
      final last = chat.lastMessage;
      if (chat.muted) continue;
      if (last == null || chat.unreadCount <= 0) continue;
      final old = previousById[chat.id];
      if (old != null && old.lastMessage?.id == last.id) continue;
      if (old != null && chat.unreadCount <= old.unreadCount) continue;
      final sender = last.senderName.trim();
      _present(
        chatId: chat.id,
        title: sender.isEmpty ? chat.title : sender,
        body: last.preview,
        messageId: last.id,
      );
    }
  }

  void _present({
    required String chatId,
    required String title,
    required String body,
    required String messageId,
  }) {
    if (!mounted || messageId == _lastMessageId) return;
    final prefs = ref.read(notificationPrefsProvider).valueOrNull;
    if (prefs != null && !prefs.messages) return;
    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (inForeground && _isViewingChat(chatId)) return;
    if (_isMuted(chatId)) return;

    _lastMessageId = messageId;
    unawaited(
      ref.read(pushServiceProvider).showChatBanner(
            messageId: messageId,
            title: title,
            body: body,
            chatId: chatId,
          ),
    );
  }

  bool _isMuted(String chatId) {
    final chats = ref.read(chatsListProvider).valueOrNull;
    if (chats == null) return false;
    for (final chat in chats) {
      if (chat.id == chatId && chat.muted) return true;
    }
    return false;
  }

  bool _isViewingChat(String chatId) {
    try {
      final path = ref.read(routerProvider).state.uri.path;
      return path == '/chat/$chatId' || path.startsWith('/chat/$chatId/');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatsListProvider, _onChats);
    return const SizedBox.shrink();
  }
}
