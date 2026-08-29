import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../data/documents_models.dart';
import 'documents_notifier.dart';

final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

class ProjectDocumentsSection extends ConsumerWidget {
  const ProjectDocumentsSection({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(projectDocumentsProvider(projectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Документы', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        documentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Не удалось загрузить документы'),
          data: (documents) {
            if (documents.isEmpty) {
              return const Text('Документов пока нет');
            }

            return Column(
              children: documents.map((document) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(documentTypeIcon(document.type)),
                    title: Text(document.name),
                    subtitle: Text(
                      '${document.typeLabel} · ${_dateFormat.format(document.uploadedAt)}',
                    ),
                    trailing: Icon(
                      document.isPdf ? Icons.visibility : Icons.download,
                    ),
                    onTap: () {
                      if (document.isPdf) {
                        context.push(AppRoutes.documentViewer(document.id));
                      } else {
                        _downloadDocument(context, ref, document);
                      }
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _downloadDocument(
    BuildContext context,
    WidgetRef ref,
    ProjectDocument document,
  ) async {
    final success =
        await ref.read(documentsActionsProvider).downloadAndOpen(document);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Файл открыт' : 'Не удалось скачать файл',
          ),
        ),
      );
    }
  }
}
