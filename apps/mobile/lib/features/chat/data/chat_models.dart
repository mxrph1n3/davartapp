import 'package:flutter/material.dart';

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _asDate(Object? value) {
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}

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
    this.pinned = false,
    this.muted = false,
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
  final bool pinned;
  final bool muted;
  final ChatLastMessage? lastMessage;

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return ChatSummary(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'personal',
      typeLabel: json['typeLabel'] as String? ?? '',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Чат',
      projectId: json['projectId'] as String?,
      clientId: json['clientId'] as String?,
      unreadCount: _asInt(json['unreadCount']),
      updatedAt: _asDate(json['updatedAt']),
      pinned: json['pinned'] as bool? ?? false,
      muted: json['muted'] as bool? ?? false,
      lastMessage: last is Map<String, dynamic>
          ? ChatLastMessage.fromJson(last)
          : last is Map
              ? ChatLastMessage.fromJson(
                  last.map((key, value) => MapEntry(key.toString(), value)),
                )
              : null,
    );
  }
}

class ChatContact {
  const ChatContact({
    required this.id,
    required this.name,
    this.phone,
    required this.role,
    required this.roleLabel,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? phone;
  final String role;
  final String roleLabel;
  final String? avatarUrl;

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final phone = json['phone'];
    return ChatContact(
      id: id is String ? id : '',
      name: name is String && name.trim().isNotEmpty ? name.trim() : 'Участник',
      phone: phone is String && phone.isNotEmpty ? phone : null,
      role: json['role'] as String? ?? '',
      roleLabel: json['roleLabel'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
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
      type: json['type'] as String? ?? 'text',
      preview: json['preview'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      createdAt: _asDate(json['createdAt']),
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
    this.replyTo,
    this.reactions = const [],
    this.isPinned = false,
    required this.sender,
    required this.isMine,
    required this.createdAt,
    this.isRead = false,
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
  final ChatReplyPreview? replyTo;
  final List<ChatReaction> reactions;
  final bool isPinned;
  final ChatSender sender;
  final bool isMine;
  final DateTime createdAt;
  final bool isRead;
  final bool isPending;
  final bool isFailed;

  ChatMessage copyWith({
    bool? isPending,
    bool? isFailed,
    bool? isMine,
    bool? isPinned,
    bool? isRead,
    List<ChatReaction>? reactions,
    ChatReplyPreview? replyTo,
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
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
      isPinned: isPinned ?? this.isPinned,
      sender: sender,
      isMine: isMine ?? this.isMine,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
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
    ChatReplyPreview? replyTo,
  }) {
    return ChatMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      type: type,
      content: content,
      attachmentName: attachmentName,
      replyTo: replyTo,
      sender: sender,
      isMine: true,
      createdAt: DateTime.now(),
      isPending: true,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), item));
      }
      return null;
    }

    DateTime parseDate(Object? value) {
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
      }
      if (value is String && value.isNotEmpty) return DateTime.parse(value);
      return DateTime.now();
    }

    final senderMap = asMap(json['sender']) ?? const {'id': '', 'name': ''};
    final productMap = asMap(json['product']);
    final replyMap = asMap(json['replyTo']);

    String text(Object? value, [String fallback = '']) {
      if (value is String && value.isNotEmpty) return value;
      return fallback;
    }

    return ChatMessage(
      id: text(json['id']),
      chatId: text(json['chatId']),
      type: text(json['type'], 'text'),
      content: json['content'] as String?,
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentName: json['attachmentName'] as String?,
      attachmentMime: json['attachmentMime'] as String?,
      product: productMap != null
          ? ChatProductPreview.fromJson(productMap)
          : null,
      replyTo: replyMap != null ? ChatReplyPreview.fromJson(replyMap) : null,
      reactions: (json['reactions'] as List<dynamic>? ?? [])
          .map((item) {
            final map = asMap(item);
            if (map == null) return null;
            return ChatReaction.fromJson(map);
          })
          .whereType<ChatReaction>()
          .toList(),
      isPinned: json['isPinned'] as bool? ?? false,
      sender: ChatSender.fromJson(senderMap),
      isMine: json['isMine'] as bool? ?? false,
      isRead: json['read'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']),
    );
  }
}

class ChatReplyPreview {
  const ChatReplyPreview({
    required this.id,
    required this.type,
    this.content,
    this.attachmentName,
    required this.senderName,
  });

  final String id;
  final String type;
  final String? content;
  final String? attachmentName;
  final String senderName;

  String get preview {
    if (content != null && content!.trim().isNotEmpty) return content!.trim();
    if (attachmentName != null && attachmentName!.isNotEmpty) {
      return attachmentName!;
    }
    return switch (type) {
      'image' => 'Фото',
      'voice' => 'Голосовое сообщение',
      'file' => 'Файл',
      'product' => 'Товар',
      _ => 'Сообщение',
    };
  }

  factory ChatReplyPreview.fromJson(Map<String, dynamic> json) {
    return ChatReplyPreview(
      id: json['id'] as String,
      type: json['type'] as String,
      content: json['content'] as String?,
      attachmentName: json['attachmentName'] as String?,
      senderName: json['senderName'] as String? ?? '',
    );
  }

  factory ChatReplyPreview.fromMessage(ChatMessage message) {
    return ChatReplyPreview(
      id: message.id,
      type: message.type,
      content: message.content,
      attachmentName: message.attachmentName,
      senderName: message.sender.name,
    );
  }
}

class ChatReaction {
  const ChatReaction({
    required this.emoji,
    required this.count,
    required this.mine,
  });

  final String emoji;
  final int count;
  final bool mine;

  factory ChatReaction.fromJson(Map<String, dynamic> json) {
    return ChatReaction(
      emoji: json['emoji'] as String,
      count: json['count'] as int? ?? 1,
      mine: json['mine'] as bool? ?? false,
    );
  }
}

class ChatSender {
  const ChatSender({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;

  factory ChatSender.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    return ChatSender(
      id: json['id'] is String ? json['id'] as String : '',
      name: name is String && name.trim().isNotEmpty ? name : 'Участник',
      avatarUrl: json['avatarUrl'] as String?,
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
    this.peerPhone,
    this.peerName,
    this.alias,
    this.pinned = false,
    this.muted = false,
    required this.participants,
  });

  final String id;
  final String type;
  final String title;
  final String? projectId;
  final String? projectName;
  final String? clientId;
  final String? peerPhone;
  final String? peerName;
  final String? alias;
  final bool pinned;
  final bool muted;
  final List<ChatParticipant> participants;

  bool get isProject => type == 'project' && projectId != null;

  bool get isSupport => type == 'support';

  factory ChatDetails.fromJson(Map<String, dynamic> json) {
    return ChatDetails(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      projectId: json['projectId'] as String?,
      projectName: json['projectName'] as String?,
      clientId: json['clientId'] as String?,
      peerPhone: json['peerPhone'] as String?,
      peerName: json['peerName'] as String?,
      alias: json['alias'] as String?,
      pinned: json['pinned'] as bool? ?? false,
      muted: json['muted'] as bool? ?? false,
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
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final String? avatarUrl;

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String? ?? 'client',
      avatarUrl: json['avatarUrl'] as String?,
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
    required this.hasMore,
  });

  final List<ChatMessage> items;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  factory MessagesPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>)
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
    final total = json['total'] as int? ?? items.length;
    return MessagesPage(
      items: items,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? items.length,
      total: total,
      hasMore: json['hasMore'] as bool? ?? items.length < total,
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
