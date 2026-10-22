import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/push/push_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds/app_avatar.dart';
import '../../../core/widgets/ds/chat_bubble.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../commerce/presentation/project_picker_sheet.dart';
import '../../staff/presentation/working_client_provider.dart';
import '../data/chat_errors.dart';
import '../data/chat_models.dart';
import '../data/chat_voice_recorder.dart';
import '../data/chat_socket_service.dart';
import '../data/open_remote_attachment.dart';
import 'chat_info_screen.dart';
import 'chat_notifier.dart';
import 'chat_image_viewer.dart';
import 'product_picker_sheet.dart';
import 'voice_message_player.dart';

String _clock(DateTime raw) {
  final local = raw.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _dayChip(DateTime raw) {
  final local = raw.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final label = '${local.day} ${months[local.month - 1]}';
  if (local.year == now.year) return label;
  return '$label ${local.year}';
}

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    this.title,
    this.clientId,
    this.projectId,
  });

  final String chatId;
  final String? title;
  final String? clientId;
  final String? projectId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _voiceRecorder = ChatVoiceRecorder();
  var _isRecording = false;
  var _recordSeconds = 0;
  var _recordCancelled = false;
  var _recordBars = <double>[];
  var _searchOpen = false;
  var _searchQuery = '';
  Timer? _recordTicker;
  Timer? _typingEmitTimer;
  Timer? _typingClearTimer;
  var _isPeerTyping = false;
  TypingHandler? _typingHandler;
  ChatSocketService? _socket;
  ChatMessage? _replyTo;
  PushService? _push;

  bool get _nearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels < 140;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _push = ref.read(pushServiceProvider);
      unawaited(_push!.setActiveChat(widget.chatId));
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      if (mounted) setState(() => _searchQuery = _searchController.text.trim());
    });
    Future<void>.delayed(Duration.zero, _syncWorkingClient);
    _scrollController.addListener(_onScroll);
    _voiceRecorder.onPeaks = (peaks) {
      if (mounted) setState(() => _recordBars = List<double>.from(peaks));
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindTypingListener());
  }

  void _bindTypingListener() {
    _socket ??= ref.read(chatSocketServiceProvider);
    _typingHandler ??= (chatId, userId, _) {
      if (chatId != widget.chatId) return;
      final myId = ref.read(authProvider).user?.id;
      if (myId != null && userId == myId) return;
      setState(() => _isPeerTyping = true);
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isPeerTyping = false);
        }
      });
    };
    _socket!.addTypingListener(_typingHandler!);
  }

  void _emitTyping() {
    _typingEmitTimer?.cancel();
    _typingEmitTimer = Timer(const Duration(milliseconds: 350), () {
      final ChatSocketService socket =
          _socket ?? ref.read(chatSocketServiceProvider);
      _socket = socket;
      socket.sendTyping(
        widget.chatId,
        preview: _controller.text.trim(),
      );
    });
  }

  void _syncWorkingClient() {
    final clientId = widget.clientId;
    if (clientId == null) return;
    final isStaff = ref.read(authProvider).user?.isStaff == true;
    if (!isStaff) return;

    final title = widget.title?.trim();
    ref.read(workingClientProvider.notifier).state = WorkingClient(
      id: clientId,
      displayName: (title != null && title.isNotEmpty) ? title : clientId,
      phone: '',
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels > 80) return;
    final thread = ref.read(chatMessagesProvider(widget.chatId)).value;
    if (thread == null || !thread.hasMore || thread.loadingOlder) return;
    ref.read(chatMessagesProvider(widget.chatId).notifier).loadOlder();
  }

  @override
  void dispose() {
    unawaited(_push?.clearActiveChat(widget.chatId));
    WidgetsBinding.instance.removeObserver(this);
    _recordTicker?.cancel();
    _typingEmitTimer?.cancel();
    _typingClearTimer?.cancel();
    final handler = _typingHandler;
    final socket = _socket;
    if (handler != null && socket != null) {
      socket.removeTypingListener(handler);
    }
    unawaited(_voiceRecorder.dispose());
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final socket = ref.read(chatSocketServiceProvider);
    unawaited(socket.connect(force: true));
    socket.joinChat(widget.chatId);
    unawaited(
      ref.read(chatMessagesProvider(widget.chatId).notifier).refreshLatest(),
    );
    unawaited(ref.read(chatsListProvider.notifier).refreshSilently());
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final inset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    if (inset <= 0 || !_nearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (_scrollController.offset < 1) return;
      _scrollController.jumpTo(0);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final isSending = ref.watch(chatSendingProvider(widget.chatId));
    final user = ref.watch(authProvider).user;
    final isStaff = user?.isStaff == true;
    final canSeeClients = user?.canSeeClients == true;
    final clientId = widget.clientId;

    ref.listen(chatMessagesProvider(widget.chatId), (previous, next) {
      final prevMessages = previous?.value?.messages ?? const <ChatMessage>[];
      final thread = next.value;
      if (thread == null) return;
      final nextMessages = thread.messages;
      final prepended = prevMessages.isNotEmpty &&
          nextMessages.length > prevMessages.length &&
          prevMessages.last.id == nextMessages.last.id;
      if (prepended) return;
      final isNewAtEnd = prevMessages.isEmpty ||
          (nextMessages.isNotEmpty &&
              prevMessages.last.id != nextMessages.last.id);
      if (isNewAtEnd && _nearBottom) _scrollToBottom();
    });

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    final colors = AppColors.of(context);

    final thread = Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        titleSpacing: 0,
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleMedium,
              )
            : GestureDetector(
                onTap: _openChatProfile,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    AppAvatar(label: widget.title ?? 'Чат', size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title ?? 'Чат',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            _isPeerTyping ? 'печатает…' : 'сведения о чате',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.of(context).textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_searchOpen) {
              setState(() {
                _searchOpen = false;
                _searchController.clear();
                _searchQuery = '';
              });
              return;
            }
            popOrGo(
              context,
              chatPathForRole(ref.watch(authProvider).user?.role),
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: _searchOpen ? 'Закрыть поиск' : 'Поиск',
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          if (!_searchOpen)
            IconButton(
              tooltip: 'Написать или пригласить',
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () => context.push(
                newChatPathForRole(ref.read(authProvider).user?.role),
              ),
            ),
          if (!_searchOpen &&
              isStaff &&
              (clientId != null || widget.projectId != null)) ...[
            IconButton(
              tooltip: 'Корзина проекта',
              icon: const Icon(Icons.shopping_bag_outlined),
              onPressed: () async {
                _syncWorkingClient();
                final projectId = widget.projectId ??
                    await ensureActiveProject(
                      context,
                      ref,
                      staffClientId: clientId,
                    );
                if (projectId != null && context.mounted) {
                  context.push(AppRoutes.staffProjectCart(projectId));
                }
              },
            ),
            if (canSeeClients && clientId != null)
              IconButton(
                tooltip: 'Профиль клиента',
                icon: const Icon(Icons.person_outline),
                onPressed: () {
                  _syncWorkingClient();
                  context.push(AppRoutes.staffClientProfile(clientId));
                },
              ),
          ],
        ],
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorState(
                message: 'Не удалось загрузить сообщения',
                onRetry: () =>
                    ref.invalidate(chatMessagesProvider(widget.chatId)),
              ),
              data: (thread) {
                final allMessages = thread.messages;
                if (allMessages.isEmpty) {
                  return const Center(child: Text('Напишите первое сообщение'));
                }

                final q = _searchQuery.toLowerCase();
                final messages = q.isEmpty
                    ? allMessages
                    : allMessages.where((m) {
                        final text = (m.content ?? '').toLowerCase();
                        final name = m.sender.name.toLowerCase();
                        final file = (m.attachmentName ?? '').toLowerCase();
                        return text.contains(q) ||
                            name.contains(q) ||
                            file.contains(q);
                      }).toList();

                if (q.isNotEmpty && messages.isEmpty) {
                  return const Center(child: Text('Ничего не найдено'));
                }

                final others = <String>{
                  for (final item in messages)
                    if (!item.isMine) item.sender.id,
                };
                final chatType = ref
                    .watch(chatDetailsProvider(widget.chatId))
                    .asData
                    ?.value
                    .type;
                final showNames = chatType == 'group' || others.length > 1;
                final entries = <Object>[];
                DateTime? lastDay;
                for (final item in messages) {
                  final local = item.createdAt.toLocal();
                  final day = DateTime(local.year, local.month, local.day);
                  if (lastDay != day) {
                    entries.add(day);
                    lastDay = day;
                  }
                  entries.add(item);
                }

                ChatMessage? pinned;
                for (final item in allMessages) {
                  if (item.isPinned) {
                    pinned = item;
                    break;
                  }
                }
                final extra = q.isEmpty && (thread.hasMore || thread.loadingOlder)
                    ? 1
                    : 0;
                final newestFirst = entries.reversed.toList();
                return Column(
                  children: [
                    if (pinned != null && q.isEmpty)
                      Material(
                        color: AppColors.of(context).surfaceMuted,
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.push_pin, size: 18),
                          title: Text(
                            pinned.sender.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            pinned.content?.trim().isNotEmpty == true
                                ? pinned.content!
                                : (pinned.attachmentName ?? 'Сообщение'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              ref
                                  .read(
                                    chatMessagesProvider(widget.chatId)
                                        .notifier,
                                  )
                                  .setPinned(pinned!.id, pinned: false);
                            },
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  itemCount: newestFirst.length + extra,
                  itemBuilder: (context, index) {
                    if (extra == 1 && index == newestFirst.length) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: thread.loadingOlder
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : TextButton(
                                  onPressed: () {
                                    ref
                                        .read(
                                          chatMessagesProvider(widget.chatId)
                                              .notifier,
                                        )
                                        .loadOlder();
                                  },
                                  child: const Text('Загрузить раньше'),
                                ),
                        ),
                      );
                    }
                    final entry = newestFirst[index];
                    if (entry is DateTime) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.of(context).surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _dayChip(entry),
                              style: TextStyle(
                                color: AppColors.of(context).textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final message = entry as ChatMessage;
                    final below = index > 0 ? newestFirst[index - 1] : null;
                    final above = index + 1 < newestFirst.length
                        ? newestFirst[index + 1]
                        : null;
                    final showTail = below is! ChatMessage ||
                        below.sender.id != message.sender.id ||
                        below.isMine != message.isMine;
                    final showSender = showNames &&
                        !message.isMine &&
                        (above is! ChatMessage ||
                            above.sender.id != message.sender.id);
                    return _GlassMessageEnter(
                      play: message.isPending ||
                          DateTime.now().difference(message.createdAt).inSeconds <
                              4,
                      child: _MessageBubble(
                      message: message,
                      chatId: widget.chatId,
                      showTail: showTail,
                      showSender: showSender,
                      onLongPress: () => _showMessageActions(message),
                    ),
                    );
                  },
                ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_replyTo != null)
            Material(
              color: AppColors.of(context).surfaceMuted,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.reply, size: 18),
                title: Text(
                  _replyTo!.sender.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  ChatReplyPreview.fromMessage(_replyTo!).preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _replyTo = null),
                ),
              ),
            ),
          ChatInputBar(
            controller: _controller,
            onSend: _sendText,
            onAttach: _showAttachMenu,
            hasText: _controller.text.trim().isNotEmpty,
            isRecording: _isRecording,
            recordSeconds: _recordSeconds,
            recordBars: _recordBars,
            onRecordStart: _startVoice,
            onRecordStop: _stopVoiceAndSend,
            onRecordCancel: _cancelVoice,
            isSending: isSending,
            onTyping: (_) => _emitTyping(),
          ),
        ],
      ),
      ),
    );

    return thread;
  }

  Future<void> _openChatProfile() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ChatInfoScreen(
          chatId: widget.chatId,
          onClose: ([value]) {
            if (!mounted) return;
            Navigator.of(context).pop(value);
          },
        ),
      ),
    );
    if (!mounted || result != 'search') return;
    setState(() => _searchOpen = true);
  }

  void _showSendError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(chatErrorMessage(error))),
    );
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (ref.read(chatSendingProvider(widget.chatId))) return;
    final replyToId = _replyTo?.id;
    _controller.clear();
    setState(() => _replyTo = null);
    try {
      await ref.read(chatMessagesProvider(widget.chatId).notifier).sendText(
            text,
            replyToId: replyToId,
          );
    } catch (error) {
      _controller.text = text;
      _showSendError(error);
    }
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    if (message.isPending || message.isFailed) return;
    const reactions = ['👍', '❤️', '😂', '🔥', '👀', '😆', '😮'];
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final emoji in reactions)
                      InkWell(
                        onTap: () => Navigator.pop(context, 'react:$emoji'),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Ответить'),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Скопировать'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
              ListTile(
                leading: const Icon(Icons.shortcut),
                title: const Text('Переслать'),
                onTap: () => Navigator.pop(context, 'forward'),
              ),
              ListTile(
                leading: Icon(
                  message.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                title: Text(message.isPinned ? 'Открепить' : 'Закрепить'),
                onTap: () => Navigator.pop(
                  context,
                  message.isPinned ? 'unpin' : 'pin',
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    final notifier = ref.read(chatMessagesProvider(widget.chatId).notifier);

    if (action.startsWith('react:')) {
      final emoji = action.substring('react:'.length);
      try {
        await notifier.toggleReaction(message.id, emoji);
      } catch (error) {
        _showSendError(error);
      }
      return;
    }

    switch (action) {
      case 'reply':
        setState(() => _replyTo = message);
        return;
      case 'copy':
        final text = message.content?.trim() ?? '';
        if (text.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Скопировано')),
        );
        return;
      case 'pin':
      case 'unpin':
        try {
          await notifier.setPinned(message.id, pinned: action == 'pin');
        } catch (error) {
          _showSendError(error);
        }
        return;
      case 'forward':
        await _forwardMessage(message);
        return;
    }
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    final chats = await ref.read(chatsListProvider.future);
    if (!mounted) return;
    final targetId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Переслать в чат')),
              for (final chat in chats.where((item) => item.id != widget.chatId))
                ListTile(
                  title: Text(chat.title),
                  subtitle: Text(chat.typeLabel),
                  onTap: () => Navigator.pop(context, chat.id),
                ),
            ],
          ),
        );
      },
    );
    if (targetId == null || !mounted) return;
    try {
      await ref.read(chatMessagesProvider(widget.chatId).notifier).forwardMessage(
            messageId: message.id,
            targetChatId: targetId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщение переслано')),
      );
    } catch (error) {
      _showSendError(error);
    }
  }

  Future<void> _showAttachMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Файл'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.storefront),
              title: const Text('Товар'),
              onTap: () => Navigator.pop(context, 'product'),
            ),
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Голосовое'),
              onTap: () => Navigator.pop(context, 'voice'),
            ),
          ],
        ),
      ),
    );

    switch (action) {
      case 'gallery':
        await _pickImage(ImageSource.gallery);
      case 'camera':
        await _pickImage(ImageSource.camera);
      case 'file':
        await _pickFile();
      case 'product':
        await _pickProduct();
      case 'voice':
        await _startVoice();
    }
  }

  Future<void> _startVoice() async {
    if (_isRecording) return;
    _recordCancelled = false;
    try {
      final allowed = await _voiceRecorder.start();
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужен доступ к микрофону')),
        );
        return;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().contains('MissingPluginException')
                ? 'Перезапустите приложение полностью, чтобы включить микрофон'
                : 'Не удалось начать запись',
          ),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    _recordTicker?.cancel();
    _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds += 1);
    });
    if (mounted) {
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _recordBars = [];
      });
    }
  }

  Future<void> _stopVoiceAndSend() async {
    if (!_isRecording) return;
    _recordTicker?.cancel();
    setState(() {
      _isRecording = false;
      _recordBars = [];
    });
    if (_recordCancelled) return;

    try {
      final take = await _voiceRecorder.stop();
      if (take == null) return;

      await _sendAttachment(
        type: 'voice',
        fileName: take.fileName,
        contentType: 'audio/mp4',
        bytes: take.bytes,
        content: take.content,
      );
    } catch (error) {
      _showSendError(error);
    }
  }

  Future<void> _cancelVoice() async {
    if (!_isRecording) return;
    _recordCancelled = true;
    _recordTicker?.cancel();
    setState(() {
      _isRecording = false;
      _recordBars = [];
    });
    try {
      await _voiceRecorder.cancel();
    } catch (_) {}
  }

  Future<void> _sendAttachment({
    required String type,
    required String fileName,
    required String contentType,
    required List<int> bytes,
    String? content,
  }) async {
    try {
      await ref.read(chatMessagesProvider(widget.chatId).notifier).sendAttachment(
            type: type,
            fileName: fileName,
            contentType: contentType,
            bytes: bytes,
            content: content,
          );
    } catch (error) {
      _showSendError(error);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(source: source);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final contentType = _mimeForFile(image.name, image.mimeType);
    await _sendAttachment(
      type: 'image',
      fileName: image.name,
      contentType: contentType,
      bytes: bytes,
    );
  }

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(label: 'files');
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final contentType = _mimeForFile(file.name, file.mimeType);
    await _sendAttachment(
      type: contentType.startsWith('image/') ? 'image' : 'file',
      fileName: file.name,
      contentType: contentType,
      bytes: bytes,
    );
  }

  Future<void> _pickProduct() async {
    final productId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ProductPickerSheet(),
    );

    if (productId == null) return;
    try {
      await ref
          .read(chatMessagesProvider(widget.chatId).notifier)
          .sendProduct(productId);
    } catch (error) {
      _showSendError(error);
    }
  }
}

class _GlassMessageEnter extends StatefulWidget {
  const _GlassMessageEnter({required this.play, required this.child});

  final bool play;
  final Widget child;

  @override
  State<_GlassMessageEnter> createState() => _GlassMessageEnterState();
}

class _GlassMessageEnterState extends State<_GlassMessageEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  @override
  void initState() {
    super.initState();
    if (widget.play) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    required this.chatId,
    this.showTail = true,
    this.showSender = false,
    this.onLongPress,
  });

  final ChatMessage message;
  final String chatId;
  final bool showTail;
  final bool showSender;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return Opacity(
      opacity: message.isPending ? 0.55 : 1,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ChatBubble(
              isMine: message.isMine,
              showTail: showTail,
              pending: message.isPending,
              read: message.isRead,
              failed: message.isFailed,
              onFailedTap: message.isFailed
                  ? () {
                      ref
                          .read(chatMessagesProvider(chatId).notifier)
                          .retryFailedUpload(message.id);
                    }
                  : null,
              time: message.isPending || message.isFailed
                  ? null
                  : _clock(message.createdAt),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSender)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        message.sender.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                      ),
                    ),
                  if (message.replyTo != null) ...[
                      Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.textPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(color: colors.accent, width: 2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyTo!.senderName,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            message.replyTo!.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                  _MessageContent(message: message),
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final reaction in message.reactions)
                          InkWell(
                            onTap: () {
                              ref
                                  .read(chatMessagesProvider(chatId).notifier)
                                  .toggleReaction(message.id, reaction.emoji);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey('${reaction.emoji}-${reaction.count}'),
                              tween: Tween(begin: 0.86, end: 1),
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              builder: (context, scale, child) => Transform.scale(
                                scale: scale,
                                child: child,
                              ),
                              child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: reaction.mine
                                    ? colors.accent.withValues(alpha: 0.25)
                                    : colors.textPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${reaction.emoji} ${reaction.count}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (message.isFailed)
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(chatMessagesProvider(chatId).notifier)
                              .retryFailedUpload(message.id);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(chatErrorMessage(error))),
                            );
                          }
                        }
                      },
                      child: const Text('Повторить отправку'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageContent extends ConsumerWidget {
  const _MessageContent({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (message.type) {
      case 'text':
        return Text(message.content ?? '');
      case 'image':
        if (message.isPending) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_outlined, size: 20),
              const SizedBox(width: 8),
              Text(message.attachmentName ?? 'Фото'),
            ],
          );
        }
        if (message.attachmentUrl == null) {
          return const Text('Изображение');
        }
        return GestureDetector(
          onTap: () => ChatImageViewer.open(
            context,
            url: message.attachmentUrl!,
            title: message.attachmentName,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              message.attachmentUrl!,
              width: 220,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 220,
                height: 180,
                alignment: Alignment.center,
                color: Colors.black12,
                child: const Text('Не удалось загрузить фото'),
              ),
            ),
          ),
        );
      case 'file':
        return InkWell(
          onTap: () async {
            final url = message.attachmentUrl;
            if (url == null) return;
            try {
              await openRemoteAttachment(
                url: url,
                fileName: message.attachmentName,
              );
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Не удалось открыть файл')),
              );
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 20),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(message.attachmentName ?? 'Файл'),
              ),
            ],
          ),
        );
      case 'product':
        final product = message.product;
        if (product == null) return const Text('Товар');
        return InkWell(
          onTap: () => context.push(
            productPathForRole(
              ref.read(authProvider).user?.role,
              product.id,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(product.imageUrl!, width: 48, height: 48, fit: BoxFit.cover),
                ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${product.price.toStringAsFixed(0)} ₽'),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'voice':
        if (message.isPending) {
          return VoiceMessagePlayer(
            url: '',
            content: message.content,
            isMine: message.isMine,
          );
        }
        if (message.attachmentUrl == null) {
          return const Text('Голосовое сообщение');
        }
        return VoiceMessagePlayer(
          url: message.attachmentUrl!,
          content: message.content,
          isMine: message.isMine,
        );
      default:
        return Text(message.content ?? '');
    }
  }
}

String _mimeForFile(String fileName, String? mimeType) {
  if (mimeType != null && mimeType.isNotEmpty && mimeType != 'application/octet-stream') {
    return mimeType;
  }

  final ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'gif' => 'image/gif',
    'pdf' => 'application/pdf',
    'zip' => 'application/zip',
    'dwg' => 'image/vnd.dwg',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'mp4' => 'video/mp4',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'mp3' => 'audio/mpeg',
    _ => mimeType ?? 'application/octet-stream',
  };
}

