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
        .map((item) => ChatContact.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatSummary> createPersonalChat(String userId) async {
    final response = await _dio.post(
      '/chats/personal',
      data: {'userId': userId},
    );
    return ChatSummary.fromJson(response.data as Map<String, dynamic>);
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
