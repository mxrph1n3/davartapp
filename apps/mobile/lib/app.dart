import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/deep_link/deep_link.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/settings/settings_notifier.dart';
import 'features/auth/presentation/auth_notifier.dart';

class DavartApp extends ConsumerStatefulWidget {
  const DavartApp({super.key});

  @override
  ConsumerState<DavartApp> createState() => _DavartAppState();
}

class _DavartAppState extends ConsumerState<DavartApp> {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, _listenDeepLinks);
  }

  Future<void> _listenDeepLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) _open(initial);
    } catch (_) {}

    _linkSub = appLinks.uriLinkStream.listen(_open);
  }

  void _open(Uri uri) {
    final location = locationFromDeepLink(uri);
    if (location == null) return;

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      ref.read(routerProvider).go(location);
    } else {
      ref.read(pendingDeepLinkProvider.notifier).state = location;
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeModeAsync = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Davart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeModeAsync.value ?? ThemeMode.system,
      routerConfig: router,
    );
  }
}
