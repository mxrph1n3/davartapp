import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../data/chat_errors.dart';
import '../data/chat_models.dart';
import '../data/chat_pending_upload.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_service.dart';

/// Stays alive while the user is logged in and refreshes without a spinner,
/// so a new DM shows up even if a socket frame was missed.
final chatsListProvider =
    AsyncNotifierProvider<ChatsListNotifier, List<ChatSummary>>(
  ChatsListNotifier.new,
);

class ChatsListNotifier extends AsyncNotifier<List<ChatSummary>> {
  Timer? _poll;
  var _reloadInFlight = false;

  @override
  Future<List<ChatSummary>> build() async {
    _poll?.cancel();
    if (!ref.watch(authProvider).isAuthenticated) return [];

    final socket = ref.watch(chatSocketServiceProvider);

    void onLiveEvent() {
      unawaited(refreshSilently());
    }

    void onUnread(int _) => onLiveEvent();

    void onMessage(ChatMessage _) => onLiveEvent();

    socket.addChatsInvalidateListener(onLiveEvent);
    socket.addUnreadListener(onUnread);
    socket.addMessageListener(onMessage);

    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(refreshSilently());
    });

    ref.onDispose(() {
      _poll?.cancel();
      socket.removeChatsInvalidateListener(onLiveEvent);
      socket.removeUnreadListener(onUnread);
      socket.removeMessageListener(onMessage);
    });

    unawaited(socket.connect());
    return ref.read(chatRepositoryProvider).getChats();
  }

  Future<void> deleteChat(String chatId) async {
    final previous = state.value ?? const <ChatSummary>[];
    state = AsyncData(previous.where((chat) => chat.id != chatId).toList());
    try {
      await ref.read(chatRepositoryProvider).deleteChat(chatId);
    } catch (error) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Pull the list from the API without replacing the current rows with a loader.
  Future<void> refreshSilently() async {
    if (!ref.read(authProvider).isAuthenticated) return;
    if (_reloadInFlight) return;
    _reloadInFlight = true;
    try {
      final chats = await ref.read(chatRepositoryProvider).getChats();
      state = AsyncData(chats);
      final socket = ref.read(chatSocketServiceProvider);
      if (!socket.isConnected) {
        await socket.connect(force: true);
      }
    } catch (_) {
      // Keep the list already on screen.
    } finally {
      _reloadInFlight = false;
    }
  }
}

final unreadTotalProvider =
    AsyncNotifierProvider<UnreadTotalNotifier, int>(UnreadTotalNotifier.new);

class UnreadTotalNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    if (!ref.watch(authProvider).isAuthenticated) return 0;

    final socket = ref.watch(chatSocketServiceProvider);

    void onUnread(int total) {
      state = AsyncData(total);
      unawaited(ref.read(chatsListProvider.notifier).refreshSilently());
    }

    socket.addUnreadListener(onUnread);
    ref.onDispose(() => socket.removeUnreadListener(onUnread));

    await socket.connect();
    return ref.watch(chatRepositoryProvider).getUnreadTotal();
  }

  Future<void> refresh() async {
    if (!ref.read(authProvider).isAuthenticated) {
      state = const AsyncData(0);
      return;
    }
    state = const AsyncLoading();
    state = AsyncData(await ref.read(chatRepositoryProvider).getUnreadTotal());
  }
}

final chatMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, ChatMessagesState, String>(
  ChatMessagesNotifier.new,
);

class ChatMessagesState {
  const ChatMessagesState({
    required this.messages,
    this.hasMore = false,
    this.loadingOlder = false,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final bool loadingOlder;

  ChatMessagesState copyWith({
    List<ChatMessage>? messages,
    bool? hasMore,
    bool? loadingOlder,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      loadingOlder: loadingOlder ?? this.loadingOlder,
    );
  }
}

final chatSendingProvider =
    NotifierProvider.autoDispose.family<ChatSendingNotifier, bool, String>(
  ChatSendingNotifier.new,
);

class ChatSendingNotifier extends AutoDisposeFamilyNotifier<bool, String> {
  @override
  bool build(String arg) => false;

  void setSending(bool value) => state = value;
}

final chatFailedUploadsProvider = NotifierProvider.autoDispose
    .family<ChatFailedUploadsNotifier, Map<String, PendingUploadPayload>, String>(
  ChatFailedUploadsNotifier.new,
);

class ChatFailedUploadsNotifier
    extends AutoDisposeFamilyNotifier<Map<String, PendingUploadPayload>, String> {
  @override
  Map<String, PendingUploadPayload> build(String arg) => {};

  void store(PendingUploadPayload payload) {
    state = {...state, payload.messageId: payload};
  }

  void remove(String messageId) {
    final next = Map<String, PendingUploadPayload>.from(state);
    next.remove(messageId);
    state = next;
  }
}

class ChatMessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<ChatMessagesState, String> {
  var _page = 1;
  var _total = 0;

  @override
  Future<ChatMessagesState> build(String chatId) async {
    final socket = ref.watch(chatSocketServiceProvider);
    // Messages must not wait on the socket. A slow handshake was holding
    // the thread behind a spinner for up to 12 seconds.
    unawaited(socket.connect());
    socket.joinChat(chatId);

    void onMessage(ChatMessage message) {
      message = _owned(message);
      if (message.chatId != chatId) {
        // Same person can be open under another chat id. Pull the thread now.
        unawaited(refreshLatest());
        return;
      }
      final current = state.value?.messages ?? [];
      if (current.any((item) => item.id == message.id)) {
        final next = current
            .map((item) {
              if (item.id == message.id) return message;
              if (message.isPinned && item.isPinned) {
                return item.copyWith(isPinned: false);
              }
              return item;
            })
            .toList();
        state = AsyncData(
          (state.value ?? const ChatMessagesState(messages: [])).copyWith(
            messages: next,
          ),
        );
        return;
      }
      _total += 1;
      state = AsyncData(
        (state.value ?? const ChatMessagesState(messages: [])).copyWith(
          messages: [...current, message],
          hasMore: current.length + 1 < _total,
        ),
      );
      if (!message.isMine) {
        unawaited(ref.read(chatRepositoryProvider).markRead(chatId));
        unawaited(ref.read(unreadTotalProvider.notifier).refresh());
      }
      unawaited(ref.read(chatsListProvider.notifier).refreshSilently());
    }

    void onReconnect() {
      unawaited(refreshLatest());
    }

    void onRead(List<String> chatIds, DateTime readAt) {
      if (!chatIds.contains(chatId)) return;
      final current = state.value;
      if (current == null) return;
      final next = current.messages
          .map((item) {
            if (!item.isMine || item.isRead || item.isPending) return item;
            if (item.createdAt.toUtc().isAfter(readAt.toUtc())) return item;
            return item.copyWith(isRead: true);
          })
          .toList();
      state = AsyncData(current.copyWith(messages: next));
    }

    void onInvalidate() {
      unawaited(refreshLatest());
    }

    socket.addMessageListener(onMessage);
    socket.addReadListener(onRead);
    socket.addChatsInvalidateListener(onInvalidate);
    socket.addReconnectListener(onReconnect);

    // Socket delivers new messages. This only fills gaps.
    final poll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!socket.isConnected) {
        unawaited(socket.connect(force: true));
      }
      socket.joinChat(chatId);
      unawaited(refreshLatest());
    });

    ref.onDispose(() {
      poll.cancel();
      socket.removeMessageListener(onMessage);
      socket.removeReadListener(onRead);
      socket.removeChatsInvalidateListener(onInvalidate);
      socket.removeReconnectListener(onReconnect);
      socket.leaveChat(chatId);
    });

    final page = await ref.read(chatRepositoryProvider).getMessages(chatId);
    _page = page.page;
    _total = page.total;
    unawaited(ref.read(chatRepositoryProvider).markRead(chatId));
    unawaited(ref.read(unreadTotalProvider.notifier).refresh());
    socket.sendRead(chatId);
    return ChatMessagesState(
      messages: page.items.map(_owned).toList(),
      hasMore: page.hasMore,
    );
  }

  /// Pull newest page and merge — used after reconnect / background resume.
  Future<void> refreshLatest() async {
    try {
      final page = await ref.read(chatRepositoryProvider).getMessages(arg);
      _total = page.total;
      final current = state.value?.messages ?? [];
      final byId = <String, ChatMessage>{
        for (final m in current) m.id: m,
      };
      for (final m in page.items.map(_owned)) {
        byId[m.id] = m;
      }
      final merged = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final hadOlder = current.length > page.items.length;
      state = AsyncData(
        (state.value ?? const ChatMessagesState(messages: [])).copyWith(
          messages: merged,
          hasMore: hadOlder ? (state.value?.hasMore ?? false) : page.hasMore,
        ),
      );
    } catch (_) {
      // Keep current state on transient network errors.
    }
  }

  ChatMessage _owned(ChatMessage message) {
    final id = ref.read(authProvider).user?.id;
    if (id == null) return message;
    return message.copyWith(isMine: message.sender.id == id);
  }

  Future<void> loadOlder() async {
    final current = state.value;
    if (current == null || current.loadingOlder || !current.hasMore) return;

    state = AsyncData(current.copyWith(loadingOlder: true));
    try {
      final nextPage = _page + 1;
      final page = await ref.read(chatRepositoryProvider).getMessages(
            arg,
            page: nextPage,
          );
      _page = page.page;
      _total = page.total;
      final existingIds = current.messages.map((m) => m.id).toSet();
      final older = page.items
          .where((item) => !existingIds.contains(item.id))
          .toList();
      final merged = [...older, ...current.messages];
      state = AsyncData(
        ChatMessagesState(
          messages: merged,
          hasMore: page.hasMore,
          loadingOlder: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingOlder: false));
    }
  }

  Future<void> sendText(String text, {String? replyToId}) async {
    final sending = ref.read(chatSendingProvider(arg));
    if (sending) return;

    ref.read(chatSendingProvider(arg).notifier).setSending(true);
    try {
      final message = await ref.read(chatRepositoryProvider).sendMessage(
            chatId: arg,
            type: 'text',
            content: text,
            replyToId: replyToId,
          );
      _appendMessage(message);
    } catch (error) {
      await refreshLatest();
      final mine = ref.read(authProvider).user?.id;
      final arrived = state.value?.messages.any(
            (item) =>
                item.sender.id == mine &&
                item.content == text &&
                !item.isPending &&
                DateTime.now().difference(item.createdAt).inSeconds < 20,
          ) ??
          false;
      if (!arrived) {
        throw ChatSendException(chatErrorMessage(error));
      }
    } finally {
      ref.read(chatSendingProvider(arg).notifier).setSending(false);
    }
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final message = await ref.read(chatRepositoryProvider).toggleReaction(
          chatId: arg,
          messageId: messageId,
          emoji: emoji,
        );
    _replaceMessage(messageId, message);
  }

  Future<void> setPinned(String messageId, {required bool pinned}) async {
    final message = await ref.read(chatRepositoryProvider).pinMessage(
          chatId: arg,
          messageId: messageId,
          pinned: pinned,
        );
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages: [
          for (final item in current.messages)
            item.id == message.id
                ? _owned(message)
                : (pinned ? item.copyWith(isPinned: false) : item),
        ],
      ),
    );
  }

  Future<void> forwardMessage({
    required String messageId,
    required String targetChatId,
  }) async {
    await ref.read(chatRepositoryProvider).forwardMessage(
          chatId: arg,
          messageId: messageId,
          targetChatId: targetChatId,
        );
  }

  Future<void> sendAttachment({
    required String type,
    required String fileName,
    required String contentType,
    required List<int> bytes,
    String? content,
  }) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      throw ChatSendException('Нужно войти в аккаунт');
    }

    final pending = ChatMessage.pending(
      chatId: arg,
      type: type,
      sender: ChatSender(id: user.id, name: user.name ?? 'Вы'),
      content: content,
      attachmentName: fileName,
    );
    _appendMessage(pending);
    ref.read(chatSendingProvider(arg).notifier).setSending(true);

    try {
      final upload =
          await ref.read(chatRepositoryProvider).uploadAttachmentBytes(
                fileName: fileName,
                contentType: contentType,
                bytes: bytes,
              );

      final message = await ref.read(chatRepositoryProvider).sendMessage(
            chatId: arg,
            type: type,
            content: content,
            attachmentKey: upload['attachmentKey'] as String,
            attachmentName: fileName,
            attachmentMime: contentType,
          );
      _replaceMessage(pending.id, message);
      ref.read(chatFailedUploadsProvider(arg).notifier).remove(pending.id);
    } catch (error) {
      _markFailed(pending.id);
      ref.read(chatFailedUploadsProvider(arg).notifier).store(
            PendingUploadPayload(
              messageId: pending.id,
              type: type,
              fileName: fileName,
              contentType: contentType,
              bytes: bytes,
              content: content,
            ),
          );
      throw ChatSendException(chatErrorMessage(error));
    } finally {
      ref.read(chatSendingProvider(arg).notifier).setSending(false);
    }
  }

  Future<void> retryFailedUpload(String messageId) async {
    final payload = ref.read(chatFailedUploadsProvider(arg))[messageId];
    if (payload == null) return;

    _removeMessage(messageId);
    ref.read(chatFailedUploadsProvider(arg).notifier).remove(messageId);
    await sendAttachment(
      type: payload.type,
      fileName: payload.fileName,
      contentType: payload.contentType,
      bytes: payload.bytes,
      content: payload.content,
    );
  }

  Future<void> sendProduct(String productId) async {
    ref.read(chatSendingProvider(arg).notifier).setSending(true);
    try {
      final message = await ref.read(chatRepositoryProvider).sendMessage(
            chatId: arg,
            type: 'product',
            productId: productId,
          );
      _appendMessage(message);
    } catch (error) {
      throw ChatSendException(chatErrorMessage(error));
    } finally {
      ref.read(chatSendingProvider(arg).notifier).setSending(false);
    }
  }

  void _replaceMessage(String pendingId, ChatMessage message) {
    message = _owned(message);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages: [
          ...current.messages.where((item) => item.id != pendingId),
          message,
        ],
      ),
    );
  }

  void _markFailed(String messageId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages: current.messages
            .map(
              (item) => item.id == messageId
                  ? item.copyWith(isPending: false, isFailed: true)
                  : item,
            )
            .toList(),
      ),
    );
  }

  void _removeMessage(String messageId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages:
            current.messages.where((item) => item.id != messageId).toList(),
      ),
    );
  }

  void _appendMessage(ChatMessage message) {
    final current = state.value ?? const ChatMessagesState(messages: []);
    if (current.messages.any((item) => item.id == message.id)) return;
    _total += 1;
    final messages = [...current.messages, message];
    state = AsyncData(
      current.copyWith(
        messages: messages,
        hasMore: messages.length < _total,
      ),
    );
  }
}
