import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/deep_link/deep_link.dart';
import '../../../core/push/push_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_notifier.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () async {
      await ref.read(authProvider.notifier).restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.unknown) return;
      FlutterNativeSplash.remove();
      if (next.isAuthenticated) {
        ref.read(pushServiceProvider).initialize();
        final pending = ref.read(pendingDeepLinkProvider);
        if (pending != null) {
          ref.read(pendingDeepLinkProvider.notifier).state = null;
          context.go(pending);
        } else {
          context.go(AppRoutes.homeForRole(next.user!.role));
        }
      } else {
        context.go(AppRoutes.catalog);
      }
    });

    return const Scaffold(
      backgroundColor: AppColors.brandDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Davart',
              style: TextStyle(
                color: AppColors.background,
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
