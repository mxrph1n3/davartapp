import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'documents_models.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository(ref.watch(dioProvider));
});

class DocumentsRepository {
  DocumentsRepository(this._dio);

  final Dio _dio;

  Future<List<ProjectDocument>> getProjectDocuments(String projectId) async {
    final response = await _dio.get('/projects/$projectId/documents');
    return (response.data as List<dynamic>)
        .map((item) => ProjectDocument.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DocumentDownload> getDownloadUrl(String documentId) async {
    final response = await _dio.get('/documents/$documentId/download');
    return DocumentDownload.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<int>> downloadFile(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  Future<void> seedDemo(String projectId) async {
    await _dio.post('/projects/$projectId/documents/seed-demo');
  }
}
