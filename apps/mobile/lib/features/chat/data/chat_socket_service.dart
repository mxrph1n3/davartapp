import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/constants/api_config.dart';
import '../../auth/data/token_storage.dart';
import 'chat_models.dart';

typedef MessageHandler = void Function(ChatMessage message);
typedef UnreadHandler = void Function(int total);
typedef TypingHandler = void Function(
  String chatId,
  String userId,
  String preview,
);

final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  final service = ChatSocketService(ref.watch(tokenStorageProvider));
  ref.onDispose(service.dispose);
  return service;
});

class ChatSocketService {
  ChatSocketService(this._tokenStorage);

  final TokenStorage _tokenStorage;
  io.Socket? _socket;

  final _messageListeners = <MessageHandler>[];
  final _unreadListeners = <UnreadHandler>[];
  final _chatsInvalidateListeners = <void Function()>[];
  final _typingListeners = <TypingHandler>[];

  void addMessageListener(MessageHandler handler) {
    _messageListeners.add(handler);
  }

  void removeMessageListener(MessageHandler handler) {
    _messageListeners.remove(handler);
  }

  void addUnreadListener(UnreadHandler handler) {
    _unreadListeners.add(handler);
  }

  void removeUnreadListener(UnreadHandler handler) {
    _unreadListeners.remove(handler);
  }

  void addChatsInvalidateListener(void Function() handler) {
    _chatsInvalidateListeners.add(handler);
  }

  void removeChatsInvalidateListener(void Function() handler) {
    _chatsInvalidateListeners.remove(handler);
  }

  void addTypingListener(TypingHandler handler) {
    _typingListeners.add(handler);
  }

  void removeTypingListener(TypingHandler handler) {
    _typingListeners.remove(handler);
  }

  Future<void> connect({bool force = false}) async {
    if (!force && _socket?.connected == true) return;

    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      disconnect();
      return;
    }

    _socket?.dispose();
    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setPath('/ws')
          .setAuth({'token': token})
          .enableAutoConnect()
          .disableForceNew()
          .build(),
    );

    _socket!
      ..on('message:new', (data) {
        if (data is! Map) return;
        final message =
            ChatMessage.fromJson(Map<String, dynamic>.from(data));
        for (final listener in List<MessageHandler>.from(_messageListeners)) {
          listener(message);
        }
      })
      ..on('unread:update', (data) {
        if (data is! Map || data['total'] is! int) return;
        final total = data['total'] as int;
        for (final listener in List<UnreadHandler>.from(_unreadListeners)) {
          listener(total);
        }
      })
      ..on('chats:invalidate', (_) {
        for (final listener
            in List<void Function()>.from(_chatsInvalidateListeners)) {
          listener();
        }
      })
      ..on('typing', (data) {
        if (data is! Map ||
            data['chatId'] is! String ||
            data['userId'] is! String) {
          return;
        }
        final chatId = data['chatId'] as String;
        final userId = data['userId'] as String;
        final preview = data['preview'] as String? ?? '';
        for (final listener in List<TypingHandler>.from(_typingListeners)) {
          listener(chatId, userId, preview);
        }
      });
  }

  void joinChat(String chatId) {
    _socket?.emit('join', chatId);
  }

  void leaveChat(String chatId) {
    _socket?.emit('leave', chatId);
  }

  void sendTyping(String chatId, {String preview = ''}) {
    _socket?.emit('typing', {'chatId': chatId, 'preview': preview});
  }

  void sendRead(String chatId) {
    _socket?.emit('read', {'chatId': chatId});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    _messageListeners.clear();
    _unreadListeners.clear();
    _chatsInvalidateListeners.clear();
    _typingListeners.clear();
    disconnect();
  }
}
