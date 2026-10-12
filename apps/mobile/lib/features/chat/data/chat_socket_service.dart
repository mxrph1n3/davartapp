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
  Future<void>? _connecting;

  final _messageListeners = <MessageHandler>[];
  final _unreadListeners = <UnreadHandler>[];
  final _chatsInvalidateListeners = <void Function()>[];
  final _typingListeners = <TypingHandler>[];
  final _reconnectListeners = <void Function()>[];
  final _joinedChats = <String>{};

  bool get isConnected => _socket?.connected == true;

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

  void addReconnectListener(void Function() handler) {
    _reconnectListeners.add(handler);
  }

  void removeReconnectListener(void Function() handler) {
    _reconnectListeners.remove(handler);
  }

  Future<void> connect({bool force = false}) async {
    if (!force && _socket?.connected == true) return;
    if (!force && _connecting != null) return _connecting!;

    final future = _connectInternal(force: force);
    _connecting = future;
    try {
      await future;
    } finally {
      if (identical(_connecting, future)) {
        _connecting = null;
      }
    }
  }

  Future<void> _connectInternal({required bool force}) async {
    if (!force && _socket?.connected == true) return;

    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      disconnect();
      return;
    }

    // Only tear down an existing socket when forcing reconnect or replacing a dead one.
    if (force || _socket != null) {
      _socket?.dispose();
      _socket = null;
    }

    final connected = Completer<void>();
    final socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setPath('/ws')
          .setTransports(['polling', 'websocket'])
          .setAuth({'token': token})
          // Query keeps the handshake authenticated if the auth packet is dropped.
          .setQuery({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .build(),
    );
    _socket = socket;

    void rejoinAndNotify() {
      for (final chatId in List<String>.from(_joinedChats)) {
        socket.emit('join', chatId);
      }
      for (final listener in List<void Function()>.from(_reconnectListeners)) {
        listener();
      }
    }

    socket
      ..onConnect((_) {
        rejoinAndNotify();
        if (!connected.isCompleted) connected.complete();
      })
      ..onReconnect((_) => rejoinAndNotify())
      ..onConnectError((error) {
        if (!connected.isCompleted) {
          connected.completeError(
            StateError('Socket connect failed: $error'),
          );
        }
      })
      ..on('message:new', (data) {
        final json = _asStringKeyMap(data);
        if (json == null) {
          for (final listener
              in List<void Function()>.from(_chatsInvalidateListeners)) {
            listener();
          }
          return;
        }
        try {
          final message = ChatMessage.fromJson(json);
          for (final listener in List<MessageHandler>.from(_messageListeners)) {
            listener(message);
          }
          // Always refresh chat list when any message arrives — even if no
          // thread screen is open (autoDispose list listeners may be gone).
          for (final listener
              in List<void Function()>.from(_chatsInvalidateListeners)) {
            listener();
          }
        } catch (_) {
          // Bad payload must not kill the socket event loop.
          for (final listener
              in List<void Function()>.from(_chatsInvalidateListeners)) {
            listener();
          }
        }
      })
      ..on('unread:update', (data) {
        final json = _asStringKeyMap(data);
        if (json == null) return;
        final total = json['total'];
        final count = total is int
            ? total
            : total is num
                ? total.toInt()
                : int.tryParse(total?.toString() ?? '');
        if (count == null) return;
        for (final listener in List<UnreadHandler>.from(_unreadListeners)) {
          listener(count);
        }
      })
      ..on('chats:invalidate', (_) {
        for (final listener
            in List<void Function()>.from(_chatsInvalidateListeners)) {
          listener();
        }
      })
      ..on('typing', (data) {
        final json = _asStringKeyMap(data);
        if (json == null) return;
        final chatId = json['chatId'];
        final userId = json['userId'];
        if (chatId is! String || userId is! String) return;
        final preview = json['preview'] as String? ?? '';
        for (final listener in List<TypingHandler>.from(_typingListeners)) {
          listener(chatId, userId, preview);
        }
      });

    try {
      await connected.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      // Keep socket for auto-reconnect; callers can still join later.
    }
  }

  void joinChat(String chatId) {
    _joinedChats.add(chatId);
    if (_socket?.connected == true) {
      _socket?.emit('join', chatId);
    }
  }

  void leaveChat(String chatId) {
    _joinedChats.remove(chatId);
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
    _reconnectListeners.clear();
    _joinedChats.clear();
    disconnect();
  }
}

Map<String, dynamic>? _asStringKeyMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, dynamic item) {
    final k = key.toString();
    if (item is Map) {
      return MapEntry(k, _asStringKeyMap(item));
    }
    if (item is List) {
      return MapEntry(
        k,
        item.map((e) => e is Map ? _asStringKeyMap(e) : e).toList(),
      );
    }
    return MapEntry(k, item);
  });
}
