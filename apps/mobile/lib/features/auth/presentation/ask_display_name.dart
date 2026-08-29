import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../profile/presentation/profile_notifier.dart';
import 'auth_notifier.dart';

/// Shows a dismissible «Как вас зовут?» sheet when the signed-in user has no name.
Future<void> maybeAskDisplayName(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider).user;
  if (user == null) return;
  final existing = user.name?.trim() ?? '';
  if (existing.isNotEmpty) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return const _AskDisplayNameSheet();
    },
  );
}

class _AskDisplayNameSheet extends ConsumerStatefulWidget {
  const _AskDisplayNameSheet();

  @override
  ConsumerState<_AskDisplayNameSheet> createState() =>
      _AskDisplayNameSheetState();
}

class _AskDisplayNameSheetState extends ConsumerState<_AskDisplayNameSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileActionsProvider).updateProfile(name: name);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить имя')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.screenPadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.screenPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Как вас зовут?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Имя поможет студии обращаться к вам в чатах и проектах. Можно пропустить.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppInput(
            controller: _controller,
            labelText: 'Ваше имя',
            hintText: 'Например, Анна',
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Сохранить',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: AppSpacing.sm),
          GhostButton(
            label: 'Пропустить',
            onPressed: _saving ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
