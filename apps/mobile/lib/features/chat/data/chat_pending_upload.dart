class PendingUploadPayload {
  const PendingUploadPayload({
    required this.messageId,
    required this.type,
    required this.fileName,
    required this.contentType,
    required this.bytes,
    this.content,
  });

  final String messageId;
  final String type;
  final String fileName;
  final String contentType;
  final List<int> bytes;
  final String? content;
}
