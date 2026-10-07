import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
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
  List<_BookContact> _registered = const [];
  List<_BookContact> _toInvite = const [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
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

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
      _matchError = false;
    });

    // Directory of everyone already in DAVart (works even without contacts).
    List<ChatContact> directory = const [];
    try {
      directory = await ref.read(chatRepositoryProvider).getContacts();
    } catch (_) {
      directory = const [];
    }

    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      final fromDir = [
        for (final u in directory)
          _BookContact(
            name: u.name,
            phone: u.phone ?? '',
            user: u,
          ),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionDenied = true;
        _registered = fromDir;
        _toInvite = const [];
      });
      return;
    }

    try {
      final raw = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final byPhone = <String, _BookContact>{};
      for (final contact in raw) {
        final displayName = contact.displayName.trim();
        for (final phone in contact.phones) {
          final rawNumber = phone.number.trim();
          if (rawNumber.isEmpty) continue;
          final digits = rawNumber.replaceAll(RegExp(r'\D'), '');
          if (digits.length < 7) continue;
          final normalized = _normalizePhone(rawNumber);
          final shown = normalized ?? rawNumber;
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

      final matchByLast10 = <String, ChatContact>{};
      for (final entry in matches.entries) {
        matchByLast10[_last10(entry.key)] = entry.value;
        final p = entry.value.phone;
        if (p != null) matchByLast10[_last10(p)] = entry.value;
      }
      for (final u in directory) {
        if (u.phone == null) continue;
        matchByLast10.putIfAbsent(_last10(u.phone!), () => u);
      }

      final registeredById = <String, _BookContact>{};

      // 1) Address-book people who are registered — keep phonebook names.
      for (final item in bookItems) {
        final user = matchByLast10[_last10(item.phone)] ?? matches[item.phone];
        if (user == null) continue;
        registeredById[user.id] = _BookContact(
          name: item.name,
          phone: item.phone,
          user: user,
        );
      }

      // 2) Other DAVart users not in the phone book.
      for (final u in directory) {
        if (registeredById.containsKey(u.id)) continue;
        registeredById[u.id] = _BookContact(
          name: u.name,
          phone: u.phone ?? '',
          user: u,
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
        _registered = [
          for (final u in directory)
            _BookContact(name: u.name, phone: u.phone ?? '', user: u),
        ];
        _toInvite = const [];
        _loading = false;
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

  Future<void> _onTapInvite(_BookContact contact) async {
    if (_openingKey.isNotEmpty) return;
    setState(() => _openingKey = contact.phone);

    try {
      try {
        final matches = await ref
            .read(chatRepositoryProvider)
            .matchPhones([contact.phone]);
        final hit =
            matches[contact.phone] ?? matches[_last10(contact.phone)];
        if (hit != null) {
          final chat = await ref
              .read(chatRepositoryProvider)
              .createPersonalChat(hit.id);
          await _openChat(chat);
          return;
        }
      } catch (_) {}

      final ok = await openDavartInviteSms(phone: contact.phone);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть Сообщения')),
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
        leading: AppBackButton(
          fallback: chatPathForRole(ref.watch(authProvider).user?.role),
        ),
        title: const Text('Новый чат'),
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
                ? 'Разрешите доступ, чтобы видеть, кто из телефонной книги уже в DAVart.'
                : (_query.isEmpty
                    ? 'Когда кто-то зарегистрируется — появится здесь.'
                    : 'Попробуйте другое имя или номер'),
            actionLabel: _permissionDenied ? 'Разрешить' : 'Обновить',
            onAction: _loadContacts,
          ),
        ],
      );
    }

    return ListView(
      children: [
        if (_matchError)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              0,
            ),
            child: Text(
              'Не удалось сверить телефонную книгу. Показаны пользователи DAVart.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ),
        if (_permissionDenied)
          Padding(
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
                    'Разрешите доступ к контактам, чтобы видеть все номера телефона.',
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
          ),
        if (registered.isNotEmpty) ...[
          _sectionHeader(colors, 'В приложении'),
          ...registered.map((c) => _registeredTile(colors, c)),
        ],
        if (invite.isNotEmpty) ...[
          _sectionHeader(colors, 'Все номера'),
          ...invite.map((c) => _inviteTile(colors, c)),
        ],
      ],
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
              color: colors.accent,
            ),
      ),
      trailing: opening
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.chat_bubble_outline,
              size: 20,
              color: colors.textSecondary,
            ),
      onTap: opening ? null : () => _openDm(contact),
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
          : Icon(
              Icons.sms_outlined,
              size: 20,
              color: colors.textSecondary,
            ),
      onTap: opening ? null : () => _onTapInvite(contact),
    );
  }
}
