import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:davart_mobile/app.dart';
import 'package:davart_mobile/features/auth/data/auth_repository.dart';
import 'package:davart_mobile/features/auth/presentation/auth_notifier.dart';
import 'package:davart_mobile/features/catalog/presentation/catalog_notifier.dart';

void main() {
  testWidgets('Unauthenticated user sees phone screen after splash', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _UnauthenticatedAuthNotifier()),
        ],
        child: const DavartApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Введите номер телефона'), findsOneWidget);
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

    await tester.pumpAndSettle();

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
