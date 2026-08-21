import 'package:flutter/material.dart';

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.title,
    this.projectId,
    this.clientId,
    required this.unreadCount,
    required this.updatedAt,
    this.lastMessage,
  });

  final String id;
  final String type;
  final String typeLabel;
  final String title;
  final String? projectId;
  final String? clientId;
  final int unreadCount;
  final DateTime updatedAt;
  final ChatLastMessage? lastMessage;

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    return ChatSummary(
      id: json['id'] as String,
      type: json['type'] as String,
      typeLabel: json['typeLabel'] as String,
      title: json['title'] as String,
      projectId: json['projectId'] as String?,
      clientId: json['clientId'] as String?,
      unreadCount: json['unreadCount'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastMessage: json['lastMessage'] != null
          ? ChatLastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ChatLastMessage {
  const ChatLastMessage({
    required this.id,
    required this.type,
    required this.preview,
    required this.senderName,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String preview;
  final String senderName;
  final DateTime createdAt;

  factory ChatLastMessage.fromJson(Map<String, dynamic> json) {
    return ChatLastMessage(
      id: json['id'] as String,
      type: json['type'] as String,
      preview: json['preview'] as String,
      senderName: json['senderName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.type,
    this.content,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
    this.product,
    required this.sender,
    required this.isMine,
    required this.createdAt,
    this.isPending = false,
    this.isFailed = false,
  });

  final String id;
  final String chatId;
  final String type;
  final String? content;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;
  final ChatProductPreview? product;
  final ChatSender sender;
  final bool isMine;
  final DateTime createdAt;
  final bool isPending;
  final bool isFailed;

  ChatMessage copyWith({
    bool? isPending,
    bool? isFailed,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      type: type,
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentMime: attachmentMime,
      product: product,
      sender: sender,
      isMine: isMine,
      createdAt: createdAt,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  factory ChatMessage.pending({
    required String chatId,
    required String type,
    required ChatSender sender,
    String? content,
    String? attachmentName,
  }) {
    return ChatMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      type: type,
      content: content,
      attachmentName: attachmentName,
      sender: sender,
      isMine: true,
      createdAt: DateTime.now(),
      isPending: true,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      chatId: json['chatId'] as String,
      type: json['type'] as String,
      content: json['content'] as String?,
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentName: json['attachmentName'] as String?,
      attachmentMime: json['attachmentMime'] as String?,
      product: json['product'] != null
          ? ChatProductPreview.fromJson(json['product'] as Map<String, dynamic>)
          : null,
      sender: ChatSender.fromJson(json['sender'] as Map<String, dynamic>),
      isMine: json['isMine'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ChatSender {
  const ChatSender({required this.id, required this.name});

  final String id;
  final String name;

  factory ChatSender.fromJson(Map<String, dynamic> json) {
    return ChatSender(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class ChatProductPreview {
  const ChatProductPreview({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.slug,
  });

  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final String slug;

  factory ChatProductPreview.fromJson(Map<String, dynamic> json) {
    return ChatProductPreview(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
      slug: json['slug'] as String,
    );
  }
}

class ChatDetails {
  const ChatDetails({
    required this.id,
    required this.type,
    required this.title,
    this.projectId,
    this.projectName,
    this.clientId,
    required this.participants,
  });

  final String id;
  final String type;
  final String title;
  final String? projectId;
  final String? projectName;
  final String? clientId;
  final List<ChatParticipant> participants;

  bool get isProject => type == 'project' && projectId != null;

  factory ChatDetails.fromJson(Map<String, dynamic> json) {
    return ChatDetails(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      projectId: json['projectId'] as String?,
      projectName: json['projectName'] as String?,
      clientId: json['clientId'] as String?,
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((item) => ChatParticipant.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  final String id;
  final String name;
  final String phone;
  final String role;

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String? ?? 'client',
    );
  }
}

class ChatArchiveItem {
  const ChatArchiveItem({
    required this.id,
    required this.type,
    this.content,
    this.attachmentUrl,
    this.attachmentName,
    required this.urls,
    required this.senderName,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String? content;
  final String? attachmentUrl;
  final String? attachmentName;
  final List<String> urls;
  final String senderName;
  final DateTime createdAt;

  factory ChatArchiveItem.fromJson(Map<String, dynamic> json) {
    return ChatArchiveItem(
      id: json['id'] as String,
      type: json['type'] as String,
      content: json['content'] as String?,
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentName: json['attachmentName'] as String?,
      urls: (json['urls'] as List<dynamic>? ?? [])
          .map((item) => item as String)
          .toList(),
      senderName: json['senderName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class MessagesPage {
  const MessagesPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<ChatMessage> items;
  final int page;
  final int limit;
  final int total;

  factory MessagesPage.fromJson(Map<String, dynamic> json) {
    return MessagesPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
    );
  }
}

IconData chatTypeIcon(String type) {
  return switch (type) {
    'project' => Icons.folder_outlined,
    'support' => Icons.support_agent,
    'personal' => Icons.person_outline,
    _ => Icons.chat_bubble_outline,
  };
}
