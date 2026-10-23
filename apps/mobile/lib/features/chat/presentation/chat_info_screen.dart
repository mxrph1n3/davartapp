import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/ru_phone_input_formatter.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/top_notice.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/data/auth_repository.dart' show UserRole;
import '../../auth/presentation/auth_notifier.dart';
import '../../commerce/presentation/active_project_provider.dart';
import '../../projects/data/project_summary.dart';
import '../../projects/data/projects_repository.dart';
import '../../projects/presentation/projects_notifier.dart';
import '../../staff/data/staff_repository.dart';
import '../../staff/presentation/working_client_provider.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import '../data/open_remote_attachment.dart';
import 'chat_image_viewer.dart';
import 'chat_notifier.dart';
import 'voice_message_player.dart';

final chatDetailsProvider =
    FutureProvider.autoDispose.family<ChatDetails, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).getChat(chatId);
});

final chatArchiveProvider = FutureProvider.autoDispose
    .family<List<ChatArchiveItem>, ({String chatId, String kind})>((ref, args) {
  return ref.watch(chatRepositoryProvider).getArchive(
        args.chatId,
        kind: args.kind,
      );
});

class ChatInfoScreen extends ConsumerStatefulWidget {
  const ChatInfoScreen({super.key, required this.chatId, this.onClose});

  final String chatId;

  /// Closes the profile without touching the navigator. A route push locks
  /// the chat screen because go_router reuses the `/chat/:id` page key.
  final void Function([String? result])? onClose;

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(chatDetailsProvider(widget.chatId));
    final opened = detailsAsync.asData?.value;
    final telegram = opened?.type == 'personal' || opened?.type == 'group';

    return Scaffold(
      appBar: AppBar(
        title: Text(telegram ? '' : (opened?.isProject == true ? 'Проект' : 'Чат')),
        actions: [
          if (telegram)
            TextButton(
              onPressed: opened == null ? null : () => _rename(opened),
              child: const Text('Изм.'),
            ),
        ],
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => _close(),
        ),
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить чат',
          onRetry: () => ref.invalidate(chatDetailsProvider(widget.chatId)),
        ),
        data: (chat) {
          final isStaff = ref.watch(authProvider).user?.isStaff == true;
          final projectId = chat.projectId;
          final projectAsync = projectId != null
              ? ref.watch(projectDetailProvider(projectId))
              : null;
          final summary = projectAsync?.asData?.value != null
              ? projectBriefSummary(projectAsync!.asData!.value)
              : null;

          // Like Telegram: media right under the info, the tabs stick to the top on scroll.
          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                sliver: SliverList.list(
                  children: [
                    if (chat.type == 'personal' || chat.type == 'group')
                      _TelegramProfile(
                        chat: chat,
                        avatarUrl: chat.type == 'personal'
                            ? chat.participants
                                .where((p) => p.id != ref.watch(authProvider).user?.id)
                                .map((p) => p.avatarUrl)
                                .firstOrNull
                            : null,
                        onMessage: () => _close('message'),
                        onSound: () => _toggleMute(chat),
                        onSearch: () => _close('search'),
                        onMore: () => _more(chat),
                      )
                    else ...[
                      Text(
                        chat.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary ??
                            (chat.type == 'project' ? 'Проектный чат' : 'Чат'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (chat.type == 'group') ...[
                      const SizedBox(height: AppSpacing.lg),
                      _GroupMembers(
                        chat: chat,
                        onAdd: () => _addGroupMembers(chat),
                        onRemove: (p) => _removeGroupMember(chat, p),
                      ),
                    ],
                    if (chat.isProject) ...[
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'Корзина проекта',
                        onPressed: () => _openCart(chat),
                      ),
                    ],
                    if (isStaff &&
                        chat.type != 'personal' &&
                        chat.type != 'group') ...[
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Участники',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (chat.isProject)
                            IconButton(
                              tooltip: 'Пригласить по телефону',
                              onPressed: () => _invite(chat),
                              icon: const Icon(Icons.person_add_outlined),
                            ),
                          if (chat.isSupport &&
                              ref.watch(authProvider).user?.canSeeClients ==
                                  true)
                            IconButton(
                              tooltip: 'Добавить дизайнера или замерщика',
                              onPressed: () => _addSupportStaff(chat),
                              icon: const Icon(Icons.person_add_outlined),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (chat.participants.isEmpty)
                        Text(
                          'Участников пока нет',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        ...chat.participants.map(
                          (p) => ListItem(
                            title: p.name,
                            subtitle: ref
                                            .watch(authProvider)
                                            .user
                                            ?.canSeeClients ==
                                        true &&
                                    p.phone.isNotEmpty
                                ? p.phone
                                : _chatRoleLabel(p.role),
                            leading: AppAvatar(label: p.name, imageUrl: p.avatarUrl, size: 40),
                            showChevron: ref
                                    .watch(authProvider)
                                    .user
                                    ?.canAssignRoles ==
                                true,
                            onTap: ref
                                        .watch(authProvider)
                                        .user
                                        ?.canAssignRoles ==
                                    true
                                ? () => _onParticipantTap(p)
                                : null,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabsHeader(
                  color: AppColors.of(context).background,
                  tabBar: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    // Tab labels line up with the text above (each tab adds 16 of its own).
                    padding: const EdgeInsets.only(left: AppSpacing.screenPadding - 16),
                    // Brand yellow on white is unreadable: black in the light theme.
                    labelColor: AppColors.of(context).accentText,
                    indicatorColor: AppColors.of(context).accentText,
                    unselectedLabelColor: AppColors.of(context).textSecondary,
                    dividerColor: AppColors.of(context).border,
                    tabs: const [
                      Tab(text: 'Медиа'),
                      Tab(text: 'Файлы'),
                      Tab(text: 'Голосовые'),
                      Tab(text: 'Ссылки'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _ArchiveList(chatId: widget.chatId, kind: 'media'),
                _ArchiveList(chatId: widget.chatId, kind: 'files'),
                _ArchiveList(chatId: widget.chatId, kind: 'voice'),
                _ArchiveList(chatId: widget.chatId, kind: 'links'),
              ],
            ),
          );
        },
      ),
    );
  }

  void _close([String? result]) {
    final close = widget.onClose;
    if (close != null) {
      close(result);
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
      return;
    }
    popOrGo(
      context,
      chatPathForRole(ref.read(authProvider).user?.role),
    );
  }

  Future<void> _rename(ChatDetails chat) async {
    final controller = TextEditingController(text: chat.title);
    final value = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return AlertDialog(
          title: Text(chat.type == 'group' ? 'Название группы' : 'Имя в чате'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
    if (value == null || value.isEmpty || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).updateChat(
            chat.id,
            title: chat.type == 'group' ? value : null,
            alias: chat.type == 'personal' ? value : null,
          );
      ref.invalidate(chatDetailsProvider(widget.chatId));
      ref.invalidate(chatsListProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось переименовать')),
      );
    }
  }

  Future<void> _toggleMute(ChatDetails chat) async {
    try {
      await ref.read(chatRepositoryProvider).setMuted(
            chat.id,
            muted: !chat.muted,
          );
      ref.invalidate(chatDetailsProvider(widget.chatId));
      ref.invalidate(chatsListProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить звук')),
      );
    }
  }

  Future<void> _addGroupMembers(ChatDetails chat) async {
    final inChat = {for (final p in chat.participants) p.id};
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _MemberPicker(exclude: inChat),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).addGroupMembers(chat.id, picked);
      ref.invalidate(chatDetailsProvider(chat.id));
      if (mounted) showTopNotice(context, picked.length == 1 ? 'Участник добавлен' : 'Участники добавлены');
    } catch (_) {
      if (mounted) showTopNotice(context, 'Не удалось добавить');
    }
  }

  Future<void> _removeGroupMember(ChatDetails chat, ChatParticipant member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить из группы?'),
        content: Text('${member.name} больше не будет видеть сообщения этой группы.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).removeGroupMember(chat.id, member.id);
      ref.invalidate(chatDetailsProvider(chat.id));
    } catch (_) {
      if (mounted) showTopNotice(context, 'Не удалось удалить участника');
    }
  }

  Future<void> _more(ChatDetails chat) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chat.type == 'group')
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Выйти из группы'),
                  onTap: () => Navigator.pop(context, 'leave'),
                ),
              if (chat.type != 'support')
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: AppColors.of(context).error,
                  ),
                  title: const Text('Удалить чат'),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
            ],
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'leave') {
        await ref.read(chatRepositoryProvider).leaveGroup(chat.id);
      } else if (action == 'delete') {
        await ref.read(chatsListProvider.notifier).deleteChat(chat.id);
      }
      if (!mounted) return;
      final router = GoRouter.of(context);
      final path = chatPathForRole(ref.read(authProvider).user?.role);
      widget.onClose?.call();
      router.go(path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить чат')),
      );
    }
  }

  Future<void> _onParticipantTap(ChatParticipant person) async {
    final roles = <UserRole>{UserRole.fromJson(person.role)};
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(person.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    if (person.phone.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Позвонить'),
                        subtitle: Text(person.phone),
                        onTap: () => launchUrl(Uri.parse('tel:${person.phone}')),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Роли'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final role in UserRole.values)
                          FilterChip(
                            label: Text(adminRoleLabel(role)),
                            selected: roles.contains(role),
                            showCheckmark: true,
                            checkmarkColor: AppColors.of(context).textOnAccent,
                            selectedColor: AppColors.of(context).accent,
                            labelStyle: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: roles.contains(role)
                                      ? AppColors.of(context).textOnAccent
                                      : AppColors.of(context).textPrimary,
                                ),
                            onSelected: (selected) {
                              setModal(() {
                                if (selected) {
                                  roles.add(role);
                                  if (role != UserRole.client) {
                                    roles.remove(UserRole.client);
                                  }
                                } else {
                                  roles.remove(role);
                                  if (roles.isEmpty) roles.add(UserRole.client);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: 'Сохранить роли',
                      onPressed: () async {
                        await ref.read(adminRepositoryProvider).setRoles(
                              userId: person.id,
                              roles: roles.toList(),
                            );
                        if (context.mounted) Navigator.pop(context);
                        ref.invalidate(chatDetailsProvider(widget.chatId));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCart(ChatDetails chat) async {
    final projectId = chat.projectId;
    if (projectId == null) return;

    final isStaff = ref.read(authProvider).user?.isStaff == true;
    ref.read(activeProjectProvider.notifier).state = ActiveProject(
      id: projectId,
      name: chat.projectName ?? chat.title,
      ownerClientId: chat.clientId,
    );

    if (isStaff) {
      if (chat.clientId != null) {
        ref.read(workingClientProvider.notifier).state = WorkingClient(
          id: chat.clientId!,
          displayName: chat.title,
          phone: '',
        );
      }
      if (mounted) context.push(AppRoutes.staffProjectCart(projectId));
      return;
    }

    if (mounted) context.go(AppRoutes.cart);
  }

  Future<void> _invite(ChatDetails chat) async {
    final projectId = chat.projectId;
    if (projectId == null) return;

    final phoneController = TextEditingController(text: '+7');
    final nameController = TextEditingController();
    var relation = 'relative';
    final result = await showDialog<({String phone, String name, String relation})>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Добавить участника'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        const RuPhoneInputFormatter(),
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        hintText: '+7XXXXXXXXXX',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        hintText: 'Как зовут',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Кем приходится',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final choice in const [
                          ('partner', 'Супруг'),
                          ('child', 'Ребёнок'),
                          ('parent', 'Родитель'),
                          ('relative', 'Родственник'),
                          ('other', 'Другой'),
                        ])
                          ChoiceChip(
                            label: Text(choice.$2),
                            selected: relation == choice.$1,
                            onSelected: (_) =>
                                setLocal(() => relation = choice.$1),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    final phone = phoneController.text.trim();
                    final name = nameController.text.trim();
                    if (phone.isEmpty || name.isEmpty) return;
                    Navigator.of(ctx).pop((
                      phone: phone,
                      name: name,
                      relation: relation,
                    ));
                  },
                  child: const Text('Добавить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    const relationLabels = {
      'partner': 'Супруг',
      'child': 'Ребёнок',
      'parent': 'Родитель',
      'relative': 'Родственник',
      'other': 'Другой',
    };

    try {
      await ref.read(projectsRepositoryProvider).inviteMember(
            projectId: projectId,
            phone: result.phone,
            name: result.name,
            relation: relationLabels[result.relation] ?? result.relation,
          );
      ref.invalidate(chatDetailsProvider(widget.chatId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Участник добавлен')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось добавить участника')),
        );
      }
    }
  }

  Future<void> _addSupportStaff(ChatDetails chat) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Добавить дизайнера'),
                onTap: () => Navigator.pop(ctx, 'designer'),
              ),
              ListTile(
                leading: const Icon(Icons.straighten_outlined),
                title: const Text('Добавить замерщика'),
                onTap: () => Navigator.pop(ctx, 'surveyor'),
              ),
            ],
          ),
        );
      },
    );
    if (role == null || !mounted) return;

    List<StaffRosterMember> roster;
    try {
      roster = await ref.read(staffRepositoryProvider).listRoster(role: role);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить список')),
      );
      return;
    }

    if (!mounted) return;
    if (roster.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            role == 'surveyor'
                ? 'Замерщиков пока нет'
                : 'Дизайнеров пока нет',
          ),
        ),
      );
      return;
    }

    final already = chat.participants.map((p) => p.id).toSet();
    final pick = await showModalBottomSheet<StaffRosterMember>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  role == 'surveyor' ? 'Замерщики' : 'Дизайнеры',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final member in roster)
                ListTile(
                  leading: AppAvatar(label: member.name, size: 36),
                  title: Text(member.name),
                  subtitle: already.contains(member.id)
                      ? const Text('Уже в чате')
                      : (member.phone.isNotEmpty ? Text(member.phone) : null),
                  enabled: !already.contains(member.id),
                  onTap: already.contains(member.id)
                      ? null
                      : () => Navigator.pop(ctx, member),
                ),
            ],
          ),
        );
      },
    );
    if (pick == null) return;

    try {
      await ref.read(chatRepositoryProvider).addSupportParticipant(
            chatId: chat.id,
            userId: pick.id,
          );
      ref.invalidate(chatDetailsProvider(widget.chatId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pick.name} добавлен(а) в чат')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось добавить участника')),
        );
      }
    }
  }
}

class _ArchiveList extends ConsumerWidget {
  const _ArchiveList({required this.chatId, required this.kind});

  final String chatId;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      chatArchiveProvider((chatId: chatId, kind: kind)),
    );

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Не удалось загрузить')),
      data: (items) {
        if (kind == 'media') {
          final photos = items
              .where((item) => item.attachmentUrl != null)
              .toList();
          if (photos.isEmpty) {
            return const Center(child: Text('Медиа пока нет'));
          }
          return GridView.builder(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final item = photos[index];
              return GestureDetector(
                onTap: () => ChatImageViewer.open(
                  context,
                  url: item.attachmentUrl!,
                ),
                child: Image.network(
                  item.attachmentUrl!,
                  fit: BoxFit.cover,
                ),
              );
            },
          );
        }

        if (items.isEmpty) {
          return Center(
            child: Text(
              switch (kind) {
                'media' => 'Медиа пока нет',
                'files' => 'Файлов пока нет',
                'voice' => 'Голосовых пока нет',
                _ => 'Ссылок пока нет',
              },
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (kind == 'links') {
              return Column(
                children: item.urls
                    .map(
                      (url) => ListItem(
                        title: url,
                        subtitle: item.senderName,
                        leading: const Icon(Icons.link, size: 20),
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ссылка скопирована')),
                            );
                          }
                        },
                      ),
                    )
                    .toList(),
              );
            }

            if (kind == 'voice' && item.attachmentUrl != null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VoiceMessagePlayer(
                      url: item.attachmentUrl!,
                      content: item.content,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.senderName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }

            return ListItem(
              title: item.attachmentName ?? item.content ?? 'Файл',
              subtitle: item.senderName,
              leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
              onTap: item.attachmentUrl == null
                  ? null
                  : () async {
                      try {
                        await openRemoteAttachment(
                          url: item.attachmentUrl!,
                          fileName: item.attachmentName,
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Не удалось открыть файл'),
                          ),
                        );
                      }
                    },
            );
          },
        );
      },
    );
  }
}

class _TelegramProfile extends StatelessWidget {
  const _TelegramProfile({
    required this.chat,
    this.avatarUrl,
    required this.onMessage,
    required this.onSound,
    required this.onSearch,
    required this.onMore,
  });

  final ChatDetails chat;
  final String? avatarUrl;
  final VoidCallback onMessage;
  final VoidCallback onSound;
  final VoidCallback onSearch;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final phone = chat.peerPhone?.trim() ?? '';
    return Column(
      children: [
        const SizedBox(height: 8),
        AppAvatar(label: chat.title, imageUrl: avatarUrl, size: 96),
        const SizedBox(height: 12),
        Text(
          chat.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _ProfileAction(
              icon: Icons.chat_bubble_outline,
              label: 'Сообщение',
              onTap: onMessage,
            ),
            _ProfileAction(
              icon: chat.muted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined,
              label: 'Звук',
              onTap: onSound,
            ),
            _ProfileAction(
              icon: Icons.search,
              label: 'Поиск',
              onTap: onSearch,
            ),
            _ProfileAction(
              icon: Icons.more_horiz,
              label: 'Ещё',
              onTap: onMore,
            ),
          ],
        ),
        if (chat.type == 'personal' && phone.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'мобильный',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPhone(phone),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.accentText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(icon, size: 22, color: colors.accentText),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }
  if (digits.length == 11 && digits.startsWith('7')) {
    return '+7 ${digits.substring(1, 4)} ${digits.substring(4, 7)} ${digits.substring(7, 9)} ${digits.substring(9)}';
  }
  return raw;
}

String _chatRoleLabel(String role) {
  return switch (role) {
    'complectator' => 'Менеджер',
    'designer' => 'Дизайнер',
    'surveyor' => 'Замерщик',
    'admin' => 'Админ',
    _ => 'Клиент',
  };
}


/// Group members: everyone sees the list; the remove cross shows only where the viewer may
/// remove (admins — anyone; a client — other clients, i.e. family; staff otherwise — nobody).
class _GroupMembers extends ConsumerWidget {
  const _GroupMembers({required this.chat, required this.onAdd, required this.onRemove});

  final ChatDetails chat;
  final VoidCallback onAdd;
  final ValueChanged<ChatParticipant> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final me = ref.watch(authProvider).user;
    final isAdmin = me?.hasRole(UserRole.admin) == true;
    final isStaff = me?.isStaff == true;
    bool canRemove(ChatParticipant p) {
      if (p.id == me?.id) return false;
      if (isAdmin) return true;
      return !isStaff && p.role == 'client';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Участники · ${chat.participants.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: colors.surfaceMuted,
            child: Icon(Icons.person_add_alt_1_outlined, color: colors.textPrimary, size: 20),
          ),
          title: const Text('Добавить участника'),
          onTap: onAdd,
        ),
        for (final p in chat.participants)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppAvatar(label: p.name, imageUrl: p.avatarUrl, size: 40),
            title: Text(p.id == me?.id ? '${p.name} (вы)' : p.name),
            subtitle: p.phone.isEmpty ? null : Text(p.phone),
            trailing: canRemove(p)
                ? IconButton(
                    tooltip: 'Удалить из группы',
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => onRemove(p),
                  )
                : null,
          ),
      ],
    );
  }
}

/// People the user already talks to — pick several and add them to the group.
class _MemberPicker extends ConsumerStatefulWidget {
  const _MemberPicker({required this.exclude});

  final Set<String> exclude;

  @override
  ConsumerState<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends ConsumerState<_MemberPicker> {
  final _picked = <String>{};
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FutureBuilder<List<ChatContact>>(
      future: ref.read(chatRepositoryProvider).getContacts(),
      builder: (context, snap) {
        final all = (snap.data ?? const <ChatContact>[]).where((c) => !widget.exclude.contains(c.id));
        final q = _query.toLowerCase();
        final list = all
            .where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(q))
            .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Имя или телефон', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: snap.connectionState != ConnectionState.done
                      ? const Center(child: CircularProgressIndicator())
                      : list.isEmpty
                          ? Center(child: Text('Никого не нашлось', style: TextStyle(color: colors.textSecondary)))
                          : ListView(
                              children: [
                                for (final c in list)
                                  CheckboxListTile(
                                    value: _picked.contains(c.id),
                                    onChanged: (v) => setState(() => v == true ? _picked.add(c.id) : _picked.remove(c.id)),
                                    secondary: AppAvatar(label: c.name, imageUrl: c.avatarUrl, size: 40),
                                    title: Text(c.name),
                                    subtitle: Text(c.phone ?? c.roleLabel),
                                  ),
                              ],
                            ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: _picked.isEmpty ? 'Выберите участников' : 'Добавить (${_picked.length})',
                    onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.toList()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader({required this.tabBar, required this.color});

  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: tabBar);

  @override
  bool shouldRebuild(_TabsHeader old) => old.tabBar != tabBar || old.color != color;
}
