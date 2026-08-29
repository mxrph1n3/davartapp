import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/projects_repository.dart';
import 'projects_notifier.dart';

Future<void> requestSurveyorConfirm(
  BuildContext context,
  WidgetRef ref,
  String projectId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Вызов замерщика'),
      content: const Text(
        'Отправить заявку на вызов замерщика? Студия свяжется с вами для согласования времени.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Вызвать'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(projectsRepositoryProvider).requestSurveyor(projectId);
    ref.invalidate(projectDetailProvider(projectId));
    ref.invalidate(projectsListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заявка на вызов замерщика отправлена')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить заявку')),
      );
    }
  }
}
