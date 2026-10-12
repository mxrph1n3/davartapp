import 'package:dio/dio.dart';

class ChatSendException implements Exception {
  ChatSendException(this.message);

  final String message;

  @override
  String toString() => message;
}

String chatErrorMessage(Object error) {
  if (error is ChatSendException) return error.message;
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final raw = data['message'];
      final message = raw is String
          ? raw
          : raw is List
              ? raw.map((item) => item.toString()).join('\n')
              : null;
      if (message != null && message.isNotEmpty) {
        if (message.contains('File storage is not available')) {
          return 'Файловое хранилище недоступно. Запустите MinIO и API';
        }
        if (message.contains('File is too large')) {
          return 'Файл слишком большой (максимум 50 МБ)';
        }
        if (message.contains('file type is not allowed')) {
          return 'Этот тип файла не поддерживается';
        }
        return message;
      }
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Нет связи с сервером';
    }
  }
  return 'Не удалось отправить сообщение';
}
