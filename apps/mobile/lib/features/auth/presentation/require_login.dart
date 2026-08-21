import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../commerce/presentation/commerce_notifier.dart';
import 'auth_notifier.dart';

const loginPhonePath = '${AppRoutes.phone}?embedded=1';
const loginOtpPath = '${AppRoutes.otp}?embedded=1';

String otpPath({required String phone, bool embedded = false}) {
  final params = <String, String>{'phone': phone};
  if (embedded) params['embedded'] = '1';
  return Uri(path: AppRoutes.otp, queryParameters: params).toString();
}

bool isEmbeddedLogin(GoRouterState state) =>
    state.uri.queryParameters['embedded'] == '1';

/// Opens phone + OTP on top of the current screen. Returns true after login.
Future<bool> promptLogin(BuildContext? context, WidgetRef ref) async {
  if (ref.read(authProvider).isAuthenticated) return true;
  if (context == null || !context.mounted) return false;
  await context.push(loginPhonePath);
  return ref.read(authProvider).isAuthenticated;
}

Future<void> toggleFavoriteWithLogin(
  BuildContext? context,
  WidgetRef ref,
  String productId,
) async {
  if (!await promptLogin(context, ref)) return;
  await ref.read(favoritesProvider.notifier).toggleFavorite(productId);
}

void finishEmbeddedLogin(BuildContext context) {
  var pops = 0;
  while (context.canPop() && pops < 2) {
    context.pop();
    pops += 1;
  }
  if (pops == 0 && context.mounted) {
    context.go(AppRoutes.catalog);
  }
}

class LoginRequiredView extends ConsumerWidget {
  const LoginRequiredView({
    super.key,
    this.title = 'Войдите по номеру',
    this.subtitle =
        'Чтобы сохранять товары, оформлять заказы и вести проекты',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      icon: Icons.phone_iphone,
      title: title,
      subtitle: subtitle,
      actionLabel: 'Войти',
      onAction: () => promptLogin(context, ref),
    );
  }
}

/// Shows [child] when signed in, otherwise the phone login prompt.
class AuthGate extends ConsumerWidget {
  const AuthGate({
    super.key,
    required this.child,
    this.title = 'Войдите по номеру',
    this.subtitle =
        'Чтобы сохранять товары, оформлять заказы и вести проекты',
  });

  final Widget child;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider).isAuthenticated) return child;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: LoginRequiredView(title: title, subtitle: subtitle),
    );
  }
}
