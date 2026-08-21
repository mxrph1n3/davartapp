import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../auth/presentation/require_login.dart';
import 'profile_notifier.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  var _initialized = false;
  var _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(authProvider).isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: AppBackButton(fallback: AppRoutes.profile),
          title: const Text('Профиль'),
        ),
        body: const LoginRequiredView(
          subtitle: 'Чтобы указать имя и email',
        ),
      );
    }

    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: profilePathForRole(ref.watch(authProvider).user?.role),
        ),
        title: const Text('Личные данные'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить профиль',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) {
          if (!_initialized) {
            _nameController.text = profile.name ?? '';
            _emailController.text = profile.email ?? '';
            _initialized = true;
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              ListItem(
                title: 'Телефон',
                subtitle: profile.phone,
                leading: const Icon(Icons.phone_outlined, size: 22),
                showChevron: false,
              ),
              const SizedBox(height: AppSpacing.md),
              AppInput(controller: _nameController, labelText: 'Имя'),
              const SizedBox(height: AppSpacing.sm),
              AppInput(
                controller: _emailController,
                labelText: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Сохранить',
                isLoading: _isSaving,
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);
                        try {
                          await ref.read(profileActionsProvider).updateProfile(
                                name: _nameController.text.trim(),
                                email: _emailController.text.trim(),
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Профиль сохранён')),
                            );
                            popOrGo(
                              context,
                              profilePathForRole(
                                ref.read(authProvider).user?.role,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}
