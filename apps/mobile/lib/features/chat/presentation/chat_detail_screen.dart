import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds/chat_bubble.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../commerce/presentation/project_picker_sheet.dart';
import '../../staff/presentation/working_client_provider.dart';
import '../data/chat_errors.dart';
import '../data/chat_models.dart';
import '../data/chat_voice_recorder.dart';
import '../data/chat_socket_service.dart';
import '../data/open_remote_attachment.dart';
import 'chat_notifier.dart';
import 'product_picker_sheet.dart';
import 'voice_message_player.dart';

final _timeFormat = DateFormat('dd.MM.yyyy HH:mm');

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

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _voiceRecorder = ChatVoiceRecorder();
  var _isRecording = false;
  var _recordSeconds = 0;
  var _recordCancelled = false;
  var _recordBars = <double>[];
  Timer? _recordTicker;
  Timer? _typingEmitTimer;
  Timer? _typingClearTimer;
  var _peerTypingPreview = '';
  var _isPeerTyping = false;
  TypingHandler? _typingHandler;
  ChatSocketService? _socket;
  double? _scrollExtentBeforeOlder;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
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
    _typingHandler ??= (chatId, userId, preview) {
      if (chatId != widget.chatId) return;
      final myId = ref.read(authProvider).user?.id;
      if (myId != null && userId == myId) return;
      setState(() {
        _isPeerTyping = true;
        _peerTypingPreview = preview;
      });
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isPeerTyping = false;
            _peerTypingPreview = '';
          });
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
    if (_scrollController.position.pixels > 64) return;
    final thread = ref.read(chatMessagesProvider(widget.chatId)).value;
    if (thread == null || !thread.hasMore || thread.loadingOlder) return;
    _scrollExtentBeforeOlder = _scrollController.position.maxScrollExtent;
    ref.read(chatMessagesProvider(widget.chatId).notifier).loadOlder();
  }

  @override
  void dispose() {
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
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
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
      if (prepended) {
        final oldMax = _scrollExtentBeforeOlder;
        _scrollExtentBeforeOlder = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || oldMax == null) return;
          final delta = _scrollController.position.maxScrollExtent - oldMax;
          _scrollController.jumpTo(_scrollController.position.pixels + delta);
        });
        return;
      }
      final isNewAtEnd = prevMessages.isEmpty ||
          (nextMessages.isNotEmpty &&
              prevMessages.last.id != nextMessages.last.id);
      if (isNewAtEnd) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => context.push(
            chatInfoPathForRole(
              ref.read(authProvider).user?.role,
              widget.chatId,
            ),
          ),
          behavior: HitTestBehavior.opaque,
          child: Text(widget.title ?? 'Чат'),
        ),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(
            context,
            chatPathForRole(ref.watch(authProvider).user?.role),
          ),
        ),
        actions: [
          if (isStaff && (clientId != null || widget.projectId != null)) ...[
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
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Не удалось загрузить сообщения')),
              data: (thread) {
                final messages = thread.messages;
                if (messages.isEmpty) {
                  return const Center(child: Text('Напишите первое сообщение'));
                }

                final extra = thread.hasMore || thread.loadingOlder ? 1 : 0;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + extra,
                  itemBuilder: (context, index) {
                    if (extra == 1 && index == 0) {
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
                                    _scrollExtentBeforeOlder =
                                        _scrollController.hasClients
                                            ? _scrollController
                                                .position.maxScrollExtent
                                            : null;
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
                    final message = messages[index - extra];
                    return _MessageBubble(
                      message: message,
                      chatId: widget.chatId,
                    );
                  },
                );
              },
            ),
          ),
          if (_isPeerTyping)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _peerTypingPreview.isEmpty
                      ? 'Печатает…'
                      : 'Печатает: $_peerTypingPreview',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.of(context).textSecondary,
                      ),
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
    );
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
    _controller.clear();
    try {
      await ref.read(chatMessagesProvider(widget.chatId).notifier).sendText(text);
    } catch (error) {
      _controller.text = text;
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

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    required this.chatId,
  });

  final ChatMessage message;
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return Opacity(
      opacity: message.isPending ? 0.55 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ChatBubble(
            isMine: message.isMine,
            time: message.isPending || message.isFailed
                ? null
                : _timeFormat.format(message.createdAt),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!message.isMine)
                  Text(
                    message.sender.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                  ),
                _MessageContent(message: message),
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
          if (message.isPending)
            Positioned(
              right: message.isMine ? 12 : null,
              left: message.isMine ? null : 12,
              bottom: 8,
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (message.isFailed)
            Positioned(
              right: message.isMine ? 8 : null,
              left: message.isMine ? null : 8,
              top: -4,
              child: Icon(
                Icons.error_outline,
                size: 18,
                color: colors.error,
              ),
            ),
        ],
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
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.attachmentUrl!,
            height: 180,
            fit: BoxFit.cover,
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
              Flexible(child: Text(message.attachmentName ?? 'Файл')),
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
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

