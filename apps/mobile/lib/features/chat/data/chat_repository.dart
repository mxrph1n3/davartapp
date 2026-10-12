import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'chat_errors.dart';
import 'chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(dioProvider));
});

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<List<ChatSummary>> getChats() async {
    final response = await _dio.get('/chats');
    return (response.data as List<dynamic>)
        .map((item) => ChatSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadTotal() async {
    final response = await _dio.get('/chats/unread-total');
    return response.data['total'] as int? ?? 0;
  }

  Future<MessagesPage> getMessages(String chatId, {int page = 1}) async {
    final response = await _dio.get(
      '/chats/$chatId/messages',
      queryParameters: {'page': page},
    );
    return MessagesPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChatMessage> sendMessage({
    required String chatId,
    required String type,
    String? content,
    String? attachmentKey,
    String? attachmentName,
    String? attachmentMime,
    String? productId,
    String? replyToId,
  }) async {
    final response = await _dio.post(
      '/chats/$chatId/messages',
      data: {
        'type': type,
        if (content != null) 'content': content,
        if (attachmentKey != null) 'attachmentKey': attachmentKey,
        if (attachmentName != null) 'attachmentName': attachmentName,
        if (attachmentMime != null) 'attachmentMime': attachmentMime,
        if (productId != null) 'productId': productId,
        if (replyToId != null) 'replyToId': replyToId,
      },
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markRead(String chatId) async {
    await _dio.post('/chats/$chatId/read');
  }

  Future<Map<String, dynamic>> createAttachmentUploadUrl({
    required String fileName,
    required String contentType,
    int? size,
  }) async {
    final response = await _dio.post(
      '/chats/attachments/upload-url',
      data: {
        'fileName': fileName,
        'contentType': contentType,
        if (size != null) 'size': size,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Upload via API proxy — phone never talks to MinIO directly.
  Future<Map<String, dynamic>> uploadAttachmentBytes({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final response = await _dio.post(
      '/chats/attachments/upload',
      data: formData,
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  @Deprecated('Use uploadAttachmentBytes — direct S3 PUT fails on device')
  Future<void> uploadAttachment({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await Dio().put(
          uploadUrl,
          data: bytes,
          options: Options(
            headers: {'Content-Type': contentType},
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (response.statusCode != null && response.statusCode! < 400) {
          return;
        }
        lastError = ChatSendException('Не удалось загрузить файл в хранилище');
      } on DioException catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw lastError ?? ChatSendException('Не удалось загрузить файл');
  }

  Future<ChatMessage> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    final response = await _dio.post(
      '/chats/$chatId/messages/$messageId/reactions',
      data: {'emoji': emoji},
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChatMessage> pinMessage({
    required String chatId,
    required String messageId,
    required bool pinned,
  }) async {
    final response = await _dio.post(
      '/chats/$chatId/messages/$messageId/${pinned ? 'pin' : 'unpin'}',
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChatMessage> forwardMessage({
    required String chatId,
    required String messageId,
    required String targetChatId,
  }) async {
    final response = await _dio.post(
      '/chats/$chatId/messages/$messageId/forward',
      data: {'targetChatId': targetChatId},
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChatMessage?> getPinnedMessage(String chatId) async {
    final response = await _dio.get('/chats/$chatId/pinned');
    if (response.data == null) return null;
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> seedDemo() async {
    await _dio.post('/chats/seed-demo');
  }

  Future<ChatSummary> getProjectChat(String projectId) async {
    final response = await _dio.get('/chats/project/$projectId');
    return ChatSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ChatContact>> getContacts({String? q}) async {
    final response = await _dio.get(
      '/chats/contacts',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    final items = response.data['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map(
          (item) => ChatContact.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((contact) => contact.id.isNotEmpty)
        .toList();
  }

  Future<ChatSummary> createPersonalChat(String userId) async {
    final response = await _dio.post(
      '/chats/personal',
      data: {'userId': userId},
    );
    return ChatSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// Invite by phone: creates user if needed, opens personal chat, sends SMS.
  Future<ChatSummary> inviteByPhone({
    required String phone,
    String? name,
  }) async {
    final response = await _dio.post(
      '/chats/invite',
      data: {
        'phone': phone,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    );
    return ChatSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// Which of [phones] already have a DAVart account (for address-book matching).
  Future<Map<String, ChatContact>> matchPhones(List<String> phones) async {
    if (phones.isEmpty) return {};
    final response = await _dio.post(
      '/chats/match-phones',
      data: {'phones': phones},
    );
    final matches = response.data['matches'] as List<dynamic>? ?? [];
    final map = <String, ChatContact>{};
    for (final item in matches) {
      final contact = ChatContact.fromJson(item as Map<String, dynamic>);
      if (contact.phone != null && contact.phone!.isNotEmpty) {
        map[contact.phone!] = contact;
        final digits = contact.phone!.replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 10) {
          map[digits.substring(digits.length - 10)] = contact;
        }
      }
      // Also index by id-less keys already covered; keep id lookup unused here.
    }
    return map;
  }

  Future<void> deleteChat(String chatId) async {
    await _dio.delete('/chats/$chatId');
  }

  Future<ChatDetails> getChat(String chatId) async {
    final response = await _dio.get('/chats/$chatId');
    return ChatDetails.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChatDetails> addSupportParticipant({
    required String chatId,
    required String userId,
  }) async {
    final response = await _dio.post(
      '/chats/$chatId/participants',
      data: {'userId': userId},
    );
    return ChatDetails.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ChatArchiveItem>> getArchive(
    String chatId, {
    required String kind,
  }) async {
    final response = await _dio.get(
      '/chats/$chatId/archive',
      queryParameters: {'kind': kind},
    );
    final items = response.data['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => ChatArchiveItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
