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
      title: const Text('Замер'),
      content: const Text(
        'Для назначения даты и времени замера менеджер свяжется с Вами в ближайшее время☺️',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Ок'),
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
        const SnackBar(content: Text('Заявка на замер отправлена')),
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
