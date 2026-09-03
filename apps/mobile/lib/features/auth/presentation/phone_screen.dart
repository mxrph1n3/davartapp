import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../data/auth_repository.dart';
import 'auth_notifier.dart';
import 'require_login.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController(text: '+7');
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || !RegExp(r'^\+7\d{10}$').hasMatch(value)) {
      return 'Введите номер в формате +7XXXXXXXXXX';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final debugCode = await ref
          .read(authProvider.notifier)
          .sendOtp(_controller.text.trim());
      if (mounted) {
        final phone = _controller.text.trim();
        final embedded = isEmbeddedLogin(GoRouterState.of(context));
        final path = otpPath(phone: phone, embedded: embedded);
        if (embedded) {
          // Keep phone under OTP so finishEmbeddedLogin can pop both.
          context.push(path, extra: debugCode);
        } else {
          // Avoid stacking phone → otp → phone again after a failed attempt.
          context.pushReplacement(path, extra: debugCode);
        }
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final embedded = isEmbeddedLogin(GoRouterState.of(context));

    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        if (embedded) {
          finishEmbeddedLogin(context);
        } else {
          context.go(
            AppRoutes.homeForRole(next.user?.role ?? UserRole.client),
          );
        }
      }
    });

    if (ref.watch(authProvider).isAuthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: embedded || context.canPop()
            ? AppBackButton(fallback: AppRoutes.catalog)
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Text('Вход', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Мы отправим код подтверждения в Telegram',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppInput(
                  controller: _controller,
                  labelText: 'Телефон',
                  hintText: '+79001234567',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  validator: _validatePhone,
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Получить код',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                if (!embedded) ...[
                  const SizedBox(height: AppSpacing.sm),
                  GhostButton(
                    label: 'Продолжить без входа',
                    onPressed: () => context.go(AppRoutes.catalog),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
