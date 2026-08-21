import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/profile_repository.dart';

final legalDocumentProvider =
    FutureProvider.autoDispose.family<LegalDocument, String>((ref, type) {
  final repository = ref.watch(profileRepositoryProvider);
  if (type == 'privacy') {
    return repository.getPrivacyPolicy();
  }
  return repository.getTermsOfService();
});

class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentAsync = ref.watch(legalDocumentProvider(type));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: profilePathForRole(ref.watch(authProvider).user?.role),
        ),
        title: Text(type == 'privacy' ? 'Конфиденциальность' : 'Условия'),
      ),
      body: documentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить документ',
          onRetry: () => ref.invalidate(legalDocumentProvider(type)),
        ),
        data: (document) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(document.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Версия ${document.version} · ${document.updatedAt}'),
            const SizedBox(height: 16),
            ...document.sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.heading,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(section.body),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
