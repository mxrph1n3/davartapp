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
    .family<ChatMessagesNotifier, List<ChatMessage>, String>(
  ChatMessagesNotifier.new,
);

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
    extends AutoDisposeFamilyAsyncNotifier<List<ChatMessage>, String> {
  @override
  Future<List<ChatMessage>> build(String chatId) async {
    final socket = ref.watch(chatSocketServiceProvider);
    await socket.connect();
    socket.joinChat(chatId);

    void onMessage(ChatMessage message) {
      if (message.chatId != chatId) return;
      final current = state.value ?? [];
      if (current.any((item) => item.id == message.id)) return;
      state = AsyncData([...current, message]);
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
    await ref.read(chatRepositoryProvider).markRead(chatId);
    ref.read(unreadTotalProvider.notifier).refresh();
    socket.sendRead(chatId);
    return page.items;
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
    final current = state.value ?? [];
    state = AsyncData([
      ...current.where((item) => item.id != pendingId),
      message,
    ]);
  }

  void _markFailed(String messageId) {
    final current = state.value ?? [];
    state = AsyncData(
      current
          .map(
            (item) => item.id == messageId
                ? item.copyWith(isPending: false, isFailed: true)
                : item,
          )
          .toList(),
    );
  }

  void _removeMessage(String messageId) {
    final current = state.value ?? [];
    state = AsyncData(current.where((item) => item.id != messageId).toList());
  }

  void _appendMessage(ChatMessage message) {
    final current = state.value ?? [];
    if (current.any((item) => item.id == message.id)) return;
    state = AsyncData([...current, message]);
  }
}
