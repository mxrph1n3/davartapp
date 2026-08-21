import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_notifier.dart';

final _timeFormat = DateFormat('dd.MM HH:mm');

enum _ChatTab { all, projects }

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  var _tab = _ChatTab.all;

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsListProvider);
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;

    return TabPage(
      child: !isAuthenticated
          ? const LoginRequiredView(
              title: 'Войдите по номеру',
              subtitle: 'Чтобы писать в поддержку и видеть переписку по проекту',
            )
          : chatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить чаты',
          onRetry: () => ref.invalidate(chatsListProvider),
        ),
        data: (chats) {
          final allChats =
              chats.where((chat) => chat.type != 'project').toList();
          final projectChats =
              chats.where((chat) => chat.type == 'project').toList();
          final visible = _tab == _ChatTab.all ? allChats : projectChats;
          final allUnread = allChats.fold<int>(0, (sum, c) => sum + c.unreadCount);
          final projectUnread =
              projectChats.fold<int>(0, (sum, c) => sum + c.unreadCount);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(chatsListProvider);
              await ref.read(unreadTotalProvider.notifier).refresh();
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                const ScreenHeader(title: 'Чаты'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    CategoryChip(
                      label: allUnread > 0 ? 'Все · $allUnread' : 'Все',
                      selected: _tab == _ChatTab.all,
                      onSelected: (_) => setState(() => _tab = _ChatTab.all),
                    ),
                    const SizedBox(width: 8),
                    CategoryChip(
                      label: projectUnread > 0
                          ? 'Проекты · $projectUnread'
                          : 'Проекты',
                      selected: _tab == _ChatTab.projects,
                      onSelected: (_) =>
                          setState(() => _tab = _ChatTab.projects),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (chats.isEmpty)
                  EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Чатов пока нет',
                    subtitle: 'Напишите в поддержку или загрузите демо',
                    actionLabel: 'Загрузить демо',
                    onAction: () async {
                      await ref.read(chatRepositoryProvider).seedDemo();
                      ref.invalidate(chatsListProvider);
                      ref.read(unreadTotalProvider.notifier).refresh();
                    },
                  )
                else if (visible.isEmpty)
                  EmptyState(
                    icon: _tab == _ChatTab.projects
                        ? Icons.folder_outlined
                        : Icons.chat_bubble_outline,
                    title: _tab == _ChatTab.projects
                        ? 'Проектных чатов нет'
                        : 'Личных чатов нет',
                    subtitle: _tab == _ChatTab.projects
                        ? 'Они появятся, когда откроется проект'
                        : 'Поддержка и личные переписки будут здесь',
                  )
                else
                  ...visible.map(
                    (chat) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ChatListItem(
                        chat: chat,
                        onTap: () => _openChat(chat),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openChat(ChatSummary chat) {
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

class _ChatListItem extends StatelessWidget {
  const _ChatListItem({required this.chat, required this.onTap});

  final ChatSummary chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          AppAvatar(label: chat.title, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (chat.lastMessage != null)
                      Text(
                        _timeFormat.format(chat.lastMessage!.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.lastMessage?.preview ?? 'Нет сообщений',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (chat.unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${chat.unreadCount}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
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
    );
  }
}
