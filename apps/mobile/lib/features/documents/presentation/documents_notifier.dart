import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../data/documents_models.dart';
import '../data/documents_repository.dart';

final projectDocumentsProvider =
    FutureProvider.autoDispose.family<List<ProjectDocument>, String>(
  (ref, projectId) {
    if (!ref.watch(authProvider).isAuthenticated) return [];
    return ref.watch(documentsRepositoryProvider).getProjectDocuments(projectId);
  },
);

final documentDownloadProvider =
    FutureProvider.autoDispose.family<DocumentDownload, String>(
  (ref, documentId) {
    return ref.watch(documentsRepositoryProvider).getDownloadUrl(documentId);
  },
);

final documentPdfBytesProvider =
    FutureProvider.autoDispose.family<List<int>, String>(
  (ref, documentId) async {
    final download =
        await ref.watch(documentsRepositoryProvider).getDownloadUrl(documentId);
    return ref.watch(documentsRepositoryProvider).downloadFile(download.url);
  },
);

class DocumentsActions {
  DocumentsActions(this._repository);

  final DocumentsRepository _repository;

  Future<void> seedDemo(String projectId) => _repository.seedDemo(projectId);

  Future<bool> downloadAndOpen(ProjectDocument document) async {
    try {
      final download = await _repository.getDownloadUrl(document.id);
      final bytes = await _repository.downloadFile(download.url);
      final dir = await getTemporaryDirectory();
      final safeName = document.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final documentsActionsProvider = Provider<DocumentsActions>((ref) {
  return DocumentsActions(ref.watch(documentsRepositoryProvider));
});
