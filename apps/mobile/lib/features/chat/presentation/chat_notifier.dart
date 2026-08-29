import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../data/chat_errors.dart';
import '../data/chat_models.dart';
import '../data/chat_pending_upload.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_service.dart';

final chatsListProvider = FutureProvider.autoDispose<List<ChatSummary>>((ref) {
  if (!ref.watch(authProvider).isAuthenticated) return [];
  return ref.watch(chatRepositoryProvider).getChats();
});

final unreadTotalProvider =
    AsyncNotifierProvider<UnreadTotalNotifier, int>(UnreadTotalNotifier.new);

class UnreadTotalNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    if (!ref.watch(authProvider).isAuthenticated) return 0;

    final socket = ref.watch(chatSocketServiceProvider);

    void onUnread(int total) {
      state = AsyncData(total);
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
    await socket.connect();
    socket.joinChat(chatId);

    void onMessage(ChatMessage message) {
      message = _owned(message);
      if (message.chatId != chatId) return;
      final current = state.value?.messages ?? [];
      if (current.any((item) => item.id == message.id)) return;
      _total += 1;
      state = AsyncData(
        (state.value ?? const ChatMessagesState(messages: [])).copyWith(
          messages: [...current, message],
          hasMore: current.length + 1 < _total,
        ),
      );
      if (!message.isMine) {
        ref.read(chatRepositoryProvider).markRead(chatId);
        ref.read(unreadTotalProvider.notifier).refresh();
      }
    }

    socket.addMessageListener(onMessage);
    ref.onDispose(() {
      socket.removeMessageListener(onMessage);
      socket.leaveChat(chatId);
    });

    final page = await ref.watch(chatRepositoryProvider).getMessages(chatId);
    _page = page.page;
    _total = page.total;
    await ref.read(chatRepositoryProvider).markRead(chatId);
    ref.read(unreadTotalProvider.notifier).refresh();
    socket.sendRead(chatId);
    return ChatMessagesState(
      messages: page.items.map(_owned).toList(),
      hasMore: page.items.length < page.total,
    );
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
          hasMore: merged.length < _total,
          loadingOlder: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingOlder: false));
    }
  }

  Future<void> sendText(String text) async {
    final sending = ref.read(chatSendingProvider(arg));
    if (sending) return;

    ref.read(chatSendingProvider(arg).notifier).setSending(true);
    try {
      final message = await ref.read(chatRepositoryProvider).sendMessage(
            chatId: arg,
            type: 'text',
            content: text,
          );
      _appendMessage(message);
    } catch (error) {
      throw ChatSendException(chatErrorMessage(error));
    } finally {
      ref.read(chatSendingProvider(arg).notifier).setSending(false);
    }
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
          await ref.read(chatRepositoryProvider).createAttachmentUploadUrl(
                fileName: fileName,
                contentType: contentType,
                size: bytes.length,
              );

      await ref.read(chatRepositoryProvider).uploadAttachment(
            uploadUrl: upload['uploadUrl'] as String,
            bytes: bytes,
            contentType: contentType,
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
