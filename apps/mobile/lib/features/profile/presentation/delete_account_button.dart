import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/profile_repository.dart';

class DeleteAccountButton extends ConsumerStatefulWidget {
  const DeleteAccountButton({super.key});

  @override
  ConsumerState<DeleteAccountButton> createState() =>
      _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends ConsumerState<DeleteAccountButton> {
  var _busy = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Профиль, сообщения, избранное и проекты этого аккаунта будут удалены. '
          'Это нельзя отменить. Войти по этому номеру больше не получится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Удалить',
              style: TextStyle(color: AppColors.of(context).error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Аккаунт удалён'),
          content: const Text(
            'Аккаунт и связанные данные удалены. Войти по этому номеру больше нельзя.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      await ref.read(authProvider.notifier).signOut();
      if (mounted) context.go(AppRoutes.catalog);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить аккаунт')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: TextButton(
          onPressed: _busy ? null : _delete,
          child: Text(
            _busy ? 'Удаляем…' : 'Удалить аккаунт',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.of(context).error,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
