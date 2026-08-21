import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../projects/data/projects_models.dart';
import '../../projects/presentation/brief_answers_view.dart';
import '../data/staff_repository.dart';

final staffBriefProvider = FutureProvider.autoDispose
    .family<Brief, ({String clientId, String projectId})>((ref, ids) {
  return ref
      .watch(staffRepositoryProvider)
      .getBrief(ids.clientId, ids.projectId);
});

/// Read-only questionnaire for staff.
class StaffBriefScreen extends ConsumerWidget {
  const StaffBriefScreen({
    super.key,
    required this.clientId,
    required this.projectId,
  });

  final String clientId;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefAsync = ref.watch(
      staffBriefProvider((clientId: clientId, projectId: projectId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Анкета'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(
            context,
            AppRoutes.staffClientProfile(clientId),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Скачать PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              try {
                final bytes = await ref
                    .read(staffRepositoryProvider)
                    .downloadBriefPdf(clientId, projectId);
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/brief-$projectId.pdf');
                await file.writeAsBytes(bytes);
                await OpenFilex.open(file.path);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Не удалось открыть PDF')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: briefAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить анкету',
          onRetry: () => ref.invalidate(
            staffBriefProvider((clientId: clientId, projectId: projectId)),
          ),
        ),
        data: (brief) {
          if (!briefHasFilledContent(brief)) {
            return const Center(
              child: Text('Анкета ещё не заполнена'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Card(
                child: const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Только просмотр'),
                  subtitle: Text('Сотрудник не редактирует анкету клиента'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              BriefAnswersView(brief: brief),
            ],
          );
        },
      ),
    );
  }
}
