import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../chat/data/chat_repository.dart';
import '../../projects/data/projects_models.dart';
import '../../projects/presentation/brief_answers_view.dart';
import '../../projects/presentation/projects_notifier.dart';
import '../../staff/data/staff_repository.dart';
import 'working_client_provider.dart';

class StaffProjectWorkspaceScreen extends ConsumerWidget {
  const StaffProjectWorkspaceScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final canAssign =
        ref.watch(authProvider).user?.canSeeClients == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Проект'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(context, AppRoutes.staffClients),
        ),
      ),
      body: projectAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить проект',
          onRetry: () => ref.invalidate(projectDetailProvider(projectId)),
        ),
        data: (project) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Text(project.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              StatusBadge(
                label: project.statusLabel,
                highlighted: project.status == 'in_progress',
              ),
              if (project.address != null && project.address!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  project.address!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Чат проекта',
                onPressed: () => _openProjectChat(context, ref, project.userId),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: 'Корзина проекта',
                onPressed: () {
                  if (project.userId != null) {
                    ref.read(workingClientProvider.notifier).state =
                        WorkingClient(
                      id: project.userId!,
                      displayName: project.name,
                      phone: '',
                    );
                  }
                  context.push(AppRoutes.staffProjectCart(projectId));
                },
              ),
              if (project.userId != null) ...[
                const SizedBox(height: AppSpacing.sm),
                GhostButton(
                  label: 'Чат DAVart с клиентом',
                  onPressed: () =>
                      _openSupportChat(context, ref, project.userId!),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text('Команда', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _StaffAssignRow(
                label: 'Дизайнер',
                staff: project.designer,
                canAssign: canAssign,
                onAssign: () => _assignStaff(
                  context,
                  ref,
                  role: 'designer',
                  project: project,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _StaffAssignRow(
                label: 'Замерщик',
                staff: project.surveyor,
                canAssign: canAssign,
                onAssign: () => _assignStaff(
                  context,
                  ref,
                  role: 'surveyor',
                  project: project,
                ),
              ),
              if (project.manager != null) ...[
                const SizedBox(height: AppSpacing.sm),
                ListItem(
                  title: project.manager!.name,
                  subtitle: 'Менеджер',
                  leading: AppAvatar(label: project.manager!.name, size: 40),
                  showChevron: false,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text('Анкета', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (project.brief == null)
                const Text('Анкета ещё не заполнена')
              else
                BriefAnswersView(brief: project.brief!),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assignStaff(
    BuildContext context,
    WidgetRef ref, {
    required String role,
    required Project project,
  }) async {
    List<StaffRosterMember> roster;
    try {
      roster = await ref.read(staffRepositoryProvider).listRoster(role: role);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить список')),
      );
      return;
    }

    if (!context.mounted) return;
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
                  role == 'surveyor'
                      ? 'Назначить замерщика'
                      : 'Назначить дизайнера',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final member in roster)
                ListTile(
                  leading: AppAvatar(label: member.name, size: 36),
                  title: Text(member.name),
                  subtitle:
                      member.phone.isNotEmpty ? Text(member.phone) : null,
                  onTap: () => Navigator.pop(ctx, member),
                ),
            ],
          ),
        );
      },
    );
    if (pick == null) return;

    try {
      await ref.read(staffRepositoryProvider).assignProjectStaff(
            projectId: projectId,
            designerId: role == 'designer' ? pick.id : null,
            surveyorId: role == 'surveyor' ? pick.id : null,
          );
      ref.invalidate(projectDetailProvider(projectId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${pick.name} назначен(а) и добавлен(а) в чат клиента',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось назначить')),
        );
      }
    }
  }

  Future<void> _openProjectChat(
    BuildContext context,
    WidgetRef ref,
    String? clientId,
  ) async {
    try {
      final chat =
          await ref.read(chatRepositoryProvider).getProjectChat(projectId);
      if (!context.mounted) return;
      final params = <String, String>{
        'title': chat.title,
        'projectId': projectId,
      };
      final resolvedClient = chat.clientId ?? clientId;
      if (resolvedClient != null) {
        params['clientId'] = resolvedClient;
      }
      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      context.push('${AppRoutes.chatDetail(chat.id)}?$query');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть чат проекта')),
      );
    }
  }

  Future<void> _openSupportChat(
    BuildContext context,
    WidgetRef ref,
    String clientId,
  ) async {
    try {
      final chat =
          await ref.read(staffRepositoryProvider).getClientChat(clientId);
      if (!context.mounted) return;
      context.push(
        '${AppRoutes.chatDetail(chat.id)}?title=${Uri.encodeComponent(chat.title)}&clientId=$clientId&projectId=$projectId',
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть чат с клиентом')),
      );
    }
  }
}

class _StaffAssignRow extends StatelessWidget {
  const _StaffAssignRow({
    required this.label,
    required this.staff,
    required this.canAssign,
    required this.onAssign,
  });

  final String label;
  final ProjectStaff? staff;
  final bool canAssign;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final name = staff?.name;
    final title =
        (name != null && name.trim().isNotEmpty) ? name : 'Не назначен';
    return ListItem(
      title: title,
      subtitle: canAssign ? '$label · нажать, чтобы назначить' : label,
      leading: AppAvatar(
        label: (name != null && name.trim().isNotEmpty) ? name : label,
        size: 40,
      ),
      showChevron: canAssign,
      onTap: canAssign ? onAssign : null,
    );
  }
}
