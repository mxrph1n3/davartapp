import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/tab_page.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../data/staff_repository.dart';

class StaffClientsScreen extends ConsumerStatefulWidget {
  const StaffClientsScreen({super.key});

  @override
  ConsumerState<StaffClientsScreen> createState() => _StaffClientsScreenState();
}

class _StaffClientsScreenState extends ConsumerState<StaffClientsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(staffClientsListProvider);

    return TabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenHeader(title: 'Клиенты'),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Имя или телефон',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    ref.read(staffClientsQueryProvider.notifier).state =
                        value.trim();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                message: 'Не удалось загрузить клиентов',
                onRetry: () => ref.invalidate(staffClientsListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'Клиентов пока нет',
                    subtitle: 'Они появятся после первой регистрации',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final client = page.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AppAvatar(label: client.displayName, size: 44),
                      title: Text(client.displayName),
                      subtitle: Text(
                        [
                          client.phone,
                          if (client.projectsCount > 0)
                            'проектов: ${client.projectsCount}',
                          if (client.cartItemsCount > 0)
                            'в корзине: ${client.cartItemsCount}',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push(
                        AppRoutes.staffClientProfile(client.id),
                      ),
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
