import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../data/staff_repository.dart';

final _dateFormat = DateFormat('dd.MM HH:mm');

class StaffAuditScreen extends ConsumerWidget {
  const StaffAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffAuditProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Активность'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(context, AppRoutes.staffProfile),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить журнал',
          onRetry: () => ref.invalidate(staffAuditProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'Пока пусто',
              subtitle: 'Действия с клиентами появятся здесь',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(staffAuditProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: page.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = page.items[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.actionLabel),
                  subtitle: Text(
                    '${entry.actorName} → ${entry.clientName}\n'
                    '${_dateFormat.format(entry.createdAt.toLocal())}',
                  ),
                  isThreeLine: true,
                  trailing: entry.clientId.isEmpty
                      ? null
                      : const Icon(Icons.chevron_right, size: 20),
                  onTap: entry.clientId.isEmpty
                      ? null
                      : () => context.push(
                            AppRoutes.staffClientProfile(entry.clientId),
                          ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
