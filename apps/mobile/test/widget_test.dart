import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:davart_mobile/app.dart';
import 'package:davart_mobile/features/auth/data/auth_repository.dart';
import 'package:davart_mobile/features/auth/presentation/auth_notifier.dart';
import 'package:davart_mobile/features/catalog/presentation/catalog_notifier.dart';

void main() {
  testWidgets('Guest lands in the shop after splash', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _UnauthenticatedAuthNotifier()),
          catalogProvider.overrideWith(() => _LoadedCatalogNotifier()),
        ],
        child: const DavartApp(),
      ),
    );

    // The app keeps periodic timers (live sync, socket retry), so it never fully
    // settles; pump long enough for the splash and the first route instead.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));

    // Guests browse without signing in; login is asked only for personal actions.
    expect(find.text('Магазин'), findsWidgets);
  });

  testWidgets('Authenticated user sees catalog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _AuthenticatedAuthNotifier()),
          catalogProvider.overrideWith(() => _LoadedCatalogNotifier()),
        ],
        child: const DavartApp(),
      ),
    );

    // The app keeps periodic timers (live sync, socket retry), so it never fully
    // settles; pump long enough for the splash and the first route instead.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Магазин'), findsWidgets);
  });
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();

  @override
  Future<void> restoreSession() async {
    state = const AuthState.unauthenticated();
  }
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState.authenticated(
      UserProfile(id: '1', phone: '+79001234567'),
    );
  }

  @override
  Future<void> restoreSession() async {}
}

class _LoadedCatalogNotifier extends CatalogNotifier {
  @override
  CatalogState build() => const CatalogState(isLoading: false);

  @override
  Future<void> loadInitial() async {}
}
