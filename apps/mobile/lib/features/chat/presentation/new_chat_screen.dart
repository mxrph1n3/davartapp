import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_notifier.dart';
import 'invite_share.dart';
import 'phone_book.dart';

class _BookContact {
  const _BookContact({
    required this.name,
    required this.phone,
    this.user,
  });

  final String name;
  final String phone;
  final ChatContact? user;

  bool get isRegistered => user != null;
}

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchController = TextEditingController();
  var _query = '';
  var _loading = true;
  var _permissionDenied = false;
  var _matchError = false;
  var _openingKey = '';
  var _groupMode = false;
  final _selectedIds = <String>{};
  List<_BookContact> _registered = const [];
  List<_BookContact> _toInvite = const [];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('8')) {
      return '+7${digits.substring(1)}';
    }
    if (digits.length == 11 && digits.startsWith('7')) {
      return '+$digits';
    }
    if (digits.length == 10) {
      return '+7$digits';
    }
    if (RegExp(r'^\+7\d{10}$').hasMatch(raw.trim())) {
      return raw.trim();
    }
    return null;
  }

  String _last10(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  Future<void> _openContactsSettings() async {
    final opened = await PhoneBook.openSettings() || await openDavartSystemSettings();
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Откройте Настройки и разрешите доступ к контактам'),
      ),
    );
  }

  Future<void> _loadContacts() async {
    final retryAfterDenial = _permissionDenied;
    setState(() {
      _loading = true;
      _permissionDenied = false;
      _matchError = false;
    });

    late final PhoneBookPage book;
    try {
      book = await PhoneBook.load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionDenied = true;
        _registered = const [];
        _toInvite = const [];
      });
      return;
    }
    if (!book.granted) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionDenied = true;
        _registered = const [];
        _toInvite = const [];
      });
      if (retryAfterDenial || !book.prompted) await _openContactsSettings();
      return;
    }

    try {
      final myPhone = ref.read(authProvider).user?.phone;
      final myLast10 = myPhone == null ? '' : _last10(myPhone);

      final byPhone = <String, _BookContact>{};
      for (final contact in book.entries) {
        final displayName = contact.name.trim();
        for (final rawNumber in contact.phones) {
          final trimmed = rawNumber.trim();
          if (trimmed.isEmpty) continue;
          final digits = trimmed.replaceAll(RegExp(r'\D'), '');
          if (digits.length < 7) continue;
          final normalized = _normalizePhone(trimmed);
          final shown = normalized ?? trimmed;
          if (myLast10.isNotEmpty && _last10(shown) == myLast10) continue;
          final key = normalized ?? digits;
          byPhone.putIfAbsent(
            key,
            () => _BookContact(
              name: displayName.isEmpty ? shown : displayName,
              phone: shown,
            ),
          );
        }
      }

      final bookItems = byPhone.values.toList();
      var matchError = false;
      Map<String, ChatContact> matches = {};
      try {
        if (bookItems.isNotEmpty) {
          matches = await ref
              .read(chatRepositoryProvider)
              .matchPhones(bookItems.map((e) => e.phone).toList());
        }
      } catch (_) {
        matchError = true;
      }

      final registeredById = <String, _BookContact>{};
      for (final item in bookItems) {
        final user = matches[_last10(item.phone)] ?? matches[item.phone];
        if (user == null) continue;
        registeredById[user.id] = _BookContact(
          name: item.name,
          phone: item.phone,
          user: user,
        );
      }

      final registered = registeredById.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final registeredLast10 = {
        for (final c in registered)
          if (c.phone.isNotEmpty) _last10(c.phone),
      };

      final invite = [
        for (final item in bookItems)
          if (!registeredLast10.contains(_last10(item.phone))) item,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _registered = registered;
        _toInvite = invite;
        _matchError = matchError;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _registered = const [];
        _toInvite = const [];
        _loading = false;
        _matchError = true;
      });
    }
  }

  List<_BookContact> _filter(List<_BookContact> list) {
    final q = _query.toLowerCase();
    if (q.isEmpty) return list;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return list.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          (digits.isNotEmpty &&
              c.phone.replaceAll(RegExp(r'\D'), '').contains(digits));
    }).toList();
  }

  Future<void> _openChat(ChatSummary chat) async {
    unawaited(ref.read(chatsListProvider.notifier).refreshSilently());
    if (!mounted) return;
    final params = <String, String>{
      'title': chat.title,
      if (chat.clientId != null) 'clientId': chat.clientId!,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    context.pushReplacement('${AppRoutes.chatDetail(chat.id)}?$query');
  }

  Future<void> _openDm(_BookContact contact) async {
    if (_openingKey.isNotEmpty) return;
    final userId = contact.user?.id;
    if (userId == null) return;

    setState(() => _openingKey = contact.phone.isEmpty ? userId : contact.phone);
    try {
      final chat =
          await ref.read(chatRepositoryProvider).createPersonalChat(userId);
      await _openChat(chat);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть чат')),
      );
    } finally {
      if (mounted) setState(() => _openingKey = '');
    }
  }

  Future<void> _askGroupTitle() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Название группы'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Например, Кухня'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
    if (title == null || title.isEmpty || !mounted) return;
    setState(() => _openingKey = 'group');
    try {
      final chat = await ref.read(chatRepositoryProvider).createGroup(
            title: title,
            userIds: _selectedIds.toList(),
          );
      if (!mounted) return;
      final params = <String, String>{'title': chat.title};
      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      context.pushReplacement('${AppRoutes.chatDetail(chat.id)}?$query');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать группу')),
      );
    } finally {
      if (mounted) setState(() => _openingKey = '');
    }
  }

  Future<void> _onTapInvite(_BookContact contact) async {
    if (_openingKey.isNotEmpty) return;
    setState(() => _openingKey = contact.phone);

    try {
      final matches = await ref
          .read(chatRepositoryProvider)
          .matchPhones([contact.phone]);
      final hit = matches[contact.phone] ?? matches[_last10(contact.phone)];
      if (hit != null) {
        final chat =
            await ref.read(chatRepositoryProvider).createPersonalChat(hit.id);
        await _openChat(chat);
        return;
      }
      if (!mounted) return;
      final opened = await openDavartInviteSms(phone: contact.phone);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть сообщения')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть чат')),
      );
    } finally {
      if (mounted) setState(() => _openingKey = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final registered = _filter(_registered);
    final invite = _filter(_toInvite);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _groupMode
            ? IconButton(
                tooltip: 'Назад',
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => setState(() {
                  _groupMode = false;
                  _selectedIds.clear();
                }),
              )
            : AppBackButton(
                fallback: chatPathForRole(ref.watch(authProvider).user?.role),
              ),
        title: Text(_groupMode ? 'Новая группа' : 'Новый чат'),
        actions: [
          if (_groupMode)
            TextButton(
              onPressed: _selectedIds.isEmpty ? null : _askGroupTitle,
              child: const Text('Далее'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              0,
              AppSpacing.screenPadding,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Имя или телефон',
                prefixIcon: const Icon(Icons.search, size: 22),
                filled: true,
                fillColor: colors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(child: _buildBody(colors, registered, invite)),
        ],
      ),
    );
  }

  Widget _buildBody(
    DavartColors colors,
    List<_BookContact> registered,
    List<_BookContact> invite,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (registered.isEmpty && invite.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: _permissionDenied
                ? Icons.contacts_outlined
                : Icons.person_outline,
            title: _permissionDenied
                ? 'Нужен доступ к контактам'
                : (_query.isEmpty ? 'Пока никого нет' : 'Не найдено'),
            subtitle: _permissionDenied
                ? 'Разрешите доступ, чтобы написать тем, кто уже в DAVart, или отправить ссылку остальным.'
                : (_query.isEmpty
                    ? 'В телефонной книге нет номеров, которым можно написать.'
                    : 'Попробуйте другое имя или номер'),
            actionLabel: _permissionDenied ? 'Разрешить' : 'Обновить',
            onAction: _loadContacts,
          ),
        ],
      );
    }

    final rows = <Object>[
      if (!_groupMode && registered.isNotEmpty) 'create-group',
      if (_matchError) 'match-error',
      if (_permissionDenied) 'permission',
      if (registered.isNotEmpty) 'В приложении',
      ...registered,
      if (!_groupMode && invite.isNotEmpty) 'Пригласить',
      if (!_groupMode) ...invite,
    ];

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row == 'create-group') {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            leading: CircleAvatar(
              backgroundColor: colors.accent,
              child: Icon(Icons.group_outlined, color: colors.textOnAccent),
            ),
            title: const Text('Создать группу'),
            subtitle: const Text('Несколько человек из DAVart'),
            onTap: () => setState(() {
              _groupMode = true;
              _selectedIds.clear();
            }),
          );
        }
        if (row == 'match-error') {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              0,
            ),
            child: Text(
              'Не удалось проверить, кто уже в DAVart. Нажатие всё равно откроет чат или приглашение.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          );
        }
        if (row == 'permission') {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Без доступа к контактам список пустой. Разрешите его, чтобы писать своим номерам.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: _loadContacts,
                  child: const Text('Разрешить'),
                ),
              ],
            ),
          );
        }
        if (row is String) return _sectionHeader(colors, row);
        if (row is _BookContact && row.isRegistered) {
          return _registeredTile(colors, row);
        }
        if (row is _BookContact) return _inviteTile(colors, row);
        return const SizedBox.shrink();
      },
    );
  }

  Widget _sectionHeader(DavartColors colors, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _registeredTile(DavartColors colors, _BookContact contact) {
    final key = contact.phone.isEmpty ? contact.user!.id : contact.phone;
    final opening = _openingKey == key;
    final subtitle = contact.phone.isNotEmpty
        ? 'в DAVart · ${contact.phone}'
        : 'в DAVart';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: 4,
      ),
      leading: AppAvatar(label: contact.name, size: 48),
      title: Text(
        contact.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
            ),
      ),
      trailing: _groupMode
          ? Icon(
              _selectedIds.contains(contact.user?.id)
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: _selectedIds.contains(contact.user?.id)
                  ? colors.accentText
                  : colors.textSecondary,
            )
          : opening
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.accent,
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: colors.textOnAccent,
                  ),
                ),
      onTap: opening
          ? null
          : () {
              if (_groupMode) {
                final id = contact.user?.id;
                if (id == null || id.isEmpty) return;
                setState(() {
                  if (_selectedIds.contains(id)) {
                    _selectedIds.remove(id);
                  } else {
                    _selectedIds.add(id);
                  }
                });
                return;
              }
              _openDm(contact);
            },
    );
  }

  Widget _inviteTile(DavartColors colors, _BookContact contact) {
    final opening = _openingKey == contact.phone;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: 4,
      ),
      leading: AppAvatar(label: contact.name, size: 48),
      title: Text(
        contact.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        'Пригласить · ${contact.phone}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
      ),
      trailing: opening
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : CircleAvatar(
              radius: 16,
              backgroundColor: colors.accent,
              child: Icon(
                Icons.sms_outlined,
                size: 16,
                color: colors.textOnAccent,
              ),
            ),
      onTap: opening ? null : () => _onTapInvite(contact),
    );
  }
}
