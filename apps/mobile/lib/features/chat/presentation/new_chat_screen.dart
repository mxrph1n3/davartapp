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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openContact(ChatContact contact) async {
    if (_openingId.isNotEmpty) return;
    setState(() => _openingId = contact.id);
    try {
      final chat =
          await ref.read(chatRepositoryProvider).createPersonalChat(contact.id);
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть чат')),
      );
    } finally {
      if (mounted) setState(() => _openingId = '');
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
                hintText: 'Поиск',
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
                if (contacts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.person_outline,
                    title: 'Контактов нет',
                    subtitle: 'Здесь появятся люди, с которыми можно начать чат',
                  );
                }
                return ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 76,
                    color: colors.divider,
                  ),
                  itemBuilder: (context, index) {
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
