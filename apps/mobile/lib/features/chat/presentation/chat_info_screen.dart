import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
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
  const ChatInfoScreen({super.key, required this.chatId});

  final String chatId;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('О чате'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            popOrGo(
              context,
              chatPathForRole(ref.watch(authProvider).user?.role),
            );
          },
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

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  children: [
                    Text(chat.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      summary ??
                          (chat.type == 'project'
                              ? 'Проектный чат'
                              : chat.type),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (chat.isProject) ...[
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'Корзина проекта',
                        onPressed: () => _openCart(chat),
                      ),
                    ],
                    if (isStaff) ...[
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
                            leading: AppAvatar(label: p.name, size: 40),
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
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Архив',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(text: 'Медиа'),
                        Tab(text: 'Файлы'),
                        Tab(text: 'Голосовые'),
                        Tab(text: 'Ссылки'),
                      ],
                    ),
                    SizedBox(
                      height: 320,
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _ArchiveList(chatId: widget.chatId, kind: 'media'),
                          _ArchiveList(chatId: widget.chatId, kind: 'files'),
                          _ArchiveList(chatId: widget.chatId, kind: 'voice'),
                          _ArchiveList(chatId: widget.chatId, kind: 'links'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onParticipantTap(ChatParticipant person) async {
    final roles = <UserRole>{UserRole.fromJson(person.role)};
    await showModalBottomSheet<void>(
      context: context,
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

    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    var relation = 'relative';
    final result = await showDialog<({String phone, String name, String relation})>(
      context: context,
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
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        hintText: '+79001234567',
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
            if (kind == 'media' && item.attachmentUrl != null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item.attachmentUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            }

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

String _chatRoleLabel(String role) {
  return switch (role) {
    'complectator' => 'Менеджер',
    'designer' => 'Дизайнер',
    'surveyor' => 'Замерщик',
    'admin' => 'Админ',
    _ => 'Клиент',
  };
}
