import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

final chatContactsProvider =
    FutureProvider.autoDispose.family<List<ChatContact>, String>((ref, q) {
  return ref.watch(chatRepositoryProvider).getContacts(q: q);
});

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchController = TextEditingController();
  var _query = '';
  var _openingId = '';
  var _inviting = false;

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

  bool get _queryLooksLikePhone {
    final digits = _query.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }

  Future<void> _openChat(ChatSummary chat) async {
    ref.invalidate(chatsListProvider);
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

  Future<void> _openContact(ChatContact contact) async {
    if (_openingId.isNotEmpty || _inviting) return;
    setState(() => _openingId = contact.id);
    try {
      final chat =
          await ref.read(chatRepositoryProvider).createPersonalChat(contact.id);
      await _openChat(chat);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть чат')),
      );
    } finally {
      if (mounted) setState(() => _openingId = '');
    }
  }

  Future<void> _inviteByPhone({String? presetPhone}) async {
    if (_inviting) return;
    final phoneController = TextEditingController(
      text: presetPhone ?? (_normalizePhone(_query) ?? _query),
    );

    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Пригласить в чат'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Отправим SMS со ссылкой на приложение и откроем чат.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+79001234567',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(phoneController.text.trim()),
              child: const Text('Пригласить'),
            ),
          ],
        );
      },
    );

    if (phone == null || phone.isEmpty) return;
    final normalized = _normalizePhone(phone);
    if (normalized == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите номер в формате +7XXXXXXXXXX')),
      );
      return;
    }

    setState(() => _inviting = true);
    try {
      final chat = await ref.read(chatRepositoryProvider).inviteByPhone(
            phone: normalized,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Приглашение отправлено на $normalized')),
      );
      await _openChat(chat);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось пригласить')),
      );
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final contactsAsync = ref.watch(chatContactsProvider(_query));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: chatPathForRole(ref.watch(authProvider).user?.role),
        ),
        title: const Text('Новый чат'),
        actions: [
          TextButton(
            onPressed: _inviting ? null : () => _inviteByPhone(),
            child: _inviting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Пригласить'),
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
              onChanged: (value) {
                setState(() => _query = value.trim());
              },
            ),
          ),
          Expanded(
            child: contactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorState(
                message: 'Не удалось загрузить контакты',
                onRetry: () => ref.invalidate(chatContactsProvider(_query)),
              ),
              data: (contacts) {
                final phone = _normalizePhone(_query);
                final phoneInContacts = phone != null &&
                    contacts.any(
                      (c) =>
                          c.phone != null &&
                          _normalizePhone(c.phone!) == phone,
                    );

                if (contacts.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    children: [
                      const SizedBox(height: 40),
                      EmptyState(
                        icon: Icons.person_outline,
                        title: _query.isEmpty
                            ? 'Напишите человеку или пригласите'
                            : 'Контакт не найден',
                        subtitle: _query.isEmpty
                            ? 'Введите имя или телефон сверху — или пригласите по SMS'
                            : 'Пригласите по SMS — откроем чат и отправим ссылку',
                        actionLabel: 'Пригласить по SMS',
                        onAction: _inviting
                            ? null
                            : () => _inviteByPhone(
                                  presetPhone: phone ?? _query,
                                ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  itemCount: contacts.length +
                      (_queryLooksLikePhone && !phoneInContacts ? 1 : 0),
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 76,
                    color: colors.divider,
                  ),
                  itemBuilder: (context, index) {
                    if (index == contacts.length) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colors.surfaceMuted,
                          child: Icon(
                            Icons.sms_outlined,
                            color: colors.textSecondary,
                          ),
                        ),
                        title: const Text('Пригласить по SMS'),
                        subtitle: Text(
                          phone ?? _query,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                        ),
                        onTap: _inviting
                            ? null
                            : () => _inviteByPhone(presetPhone: phone ?? _query),
                      );
                    }

                    final contact = contacts[index];
                    final opening = _openingId == contact.id;
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
                        [
                          contact.roleLabel,
                          if (contact.phone != null) contact.phone!,
                        ].where((s) => s.isNotEmpty).join(' · '),
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
                          : null,
                      onTap: opening ? null : () => _openContact(contact),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
