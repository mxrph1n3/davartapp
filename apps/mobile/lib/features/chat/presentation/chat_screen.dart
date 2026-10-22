import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_notifier.dart';

const _weekdaysRu = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final chatsAsync = ref.watch(chatsListProvider);
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;

    return TabPage(
      child: !isAuthenticated
          ? const LoginRequiredView(
              title: 'Войдите по номеру',
              subtitle: 'Чтобы писать в поддержку и видеть переписку по проекту',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title: 'Мессенджер',
                  actions: [
                    HeaderIconButton(
                      icon: CupertinoIcons.square_pencil,
                      onPressed: () => context.push(
                        newChatPathForRole(ref.read(authProvider).user?.role),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: chatsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => ErrorState(
                      message: 'Не удалось загрузить чаты',
                      onRetry: () => ref.invalidate(chatsListProvider),
                    ),
                    data: (chats) {
                      final sorted = [...chats]..sort((a, b) {
                          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
                          return b.updatedAt.compareTo(a.updatedAt);
                        });

                      return RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(chatsListProvider.notifier).refreshSilently();
                          await ref.read(unreadTotalProvider.notifier).refresh();
                        },
                        child: sorted.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 80),
                                  EmptyState(
                                    icon: Icons.chat_bubble_outline,
                                    title: 'Чатов пока нет',
                                    subtitle:
                                        'Нажмите ✎ сверху — чат с контактом или приглашение по SMS',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: sorted.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  indent: 76,
                                  color: colors.divider,
                                ),
                                itemBuilder: (context, index) {
                                  final chat = sorted[index];
                                  return Dismissible(
                                    key: ValueKey(chat.id),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (_) =>
                                        _confirmDeleteChat(context, chat),
                                    onDismissed: (_) {
                                      ref
                                          .read(chatsListProvider.notifier)
                                          .deleteChat(chat.id)
                                          .catchError((_) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Не удалось удалить чат',
                                            ),
                                          ),
                                        );
                                      });
                                    },
                                    background: Container(
                                      color: colors.error,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: _TelegramChatTile(
                                      chat: chat,
                                      onTap: () => _openChat(context, chat),
                                      onLongPress: () =>
                                          _showChatMenu(context, ref, chat),
                                    ),
                                  );
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<bool> _confirmDeleteChat(BuildContext context, ChatSummary chat) async {
    if (chat.type == 'support') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чат поддержки нельзя удалить')),
      );
      return false;
    }
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Удалить чат?'),
        content: Text(
          '«${chat.title}» пропадёт из списка и больше не появится.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _showChatMenu(
    BuildContext context,
    WidgetRef ref,
    ChatSummary chat,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  chat.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                title: Text(chat.pinned ? 'Открепить' : 'Закрепить'),
                onTap: () => Navigator.pop(context, 'pin'),
              ),
              ListTile(
                leading: Icon(
                  chat.muted
                      ? Icons.notifications_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: Text(chat.muted ? 'Включить звук' : 'Выключить звук'),
                onTap: () => Navigator.pop(context, 'mute'),
              ),
              if (chat.type != 'support')
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: AppColors.of(context).error,
                  ),
                  title: const Text('Удалить'),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;
    try {
      if (action == 'pin') {
        await ref
            .read(chatRepositoryProvider)
            .setPinned(chat.id, pinned: !chat.pinned);
      } else if (action == 'mute') {
        await ref
            .read(chatRepositoryProvider)
            .setMuted(chat.id, muted: !chat.muted);
      } else if (action == 'delete') {
        final ok = await _confirmDeleteChat(context, chat);
        if (!ok || !context.mounted) return;
        await ref.read(chatsListProvider.notifier).deleteChat(chat.id);
        return;
      }
      await ref.read(chatsListProvider.notifier).refreshSilently();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить чат')),
      );
    }
  }

  void _openChat(BuildContext context, ChatSummary chat) {
    final params = <String, String>{
      'title': chat.title,
      if (chat.clientId != null) 'clientId': chat.clientId!,
      if (chat.projectId != null) 'projectId': chat.projectId!,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    context.push('${AppRoutes.chatDetail(chat.id)}?$query');
  }
}

class _TelegramChatTile extends StatelessWidget {
  const _TelegramChatTile({
    required this.chat,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatSummary chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final preview = chat.lastMessage?.preview ?? 'Нет сообщений';
    final timeLabel = chat.lastMessage != null
        ? _formatChatTime(chat.lastMessage!.createdAt)
        : '';
    final hasUnread = chat.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: 10,
        ),
        child: Row(
          children: [
            AppAvatar(label: chat.title, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                chat.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                              ),
                            ),
                            if (chat.muted) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 14,
                                color: colors.textSecondary,
                              ),
                            ],
                            if (chat.pinned) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: colors.textSecondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: hasUnread
                                  ? colors.accent
                                  : colors.textSecondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: hasUnread
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                  ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            chat.unreadCount > 99
                                ? '99+'
                                : '${chat.unreadCount}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.textOnAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
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

String _formatChatTime(DateTime raw) {
  final local = raw.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (diff == 1) return 'вчера';
  if (diff < 7) return _weekdaysRu[local.weekday - 1];
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yy = (local.year % 100).toString().padLeft(2, '0');
  return '$dd.$mm.$yy';
}
