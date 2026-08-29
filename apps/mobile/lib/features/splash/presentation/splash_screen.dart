import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_service.dart';
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
    // Navigation is owned by GoRouter.redirect — splash only removes the
    // native splash and warms push once auth leaves unknown.
    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.unknown) return;
      FlutterNativeSplash.remove();
      if (next.isAuthenticated) {
        ref.read(pushServiceProvider).initialize();
      }
    });

    return const Scaffold(
      backgroundColor: AppColors.brandDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'DAVart',
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
