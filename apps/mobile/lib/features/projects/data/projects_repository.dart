import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'projects_models.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.watch(dioProvider));
});

class ProjectsRepository {
  ProjectsRepository(this._dio);

  final Dio _dio;

  Future<List<Project>> getProjects() async {
    final response = await _dio.get('/projects');
    return (response.data as List<dynamic>)
        .map((item) => Project.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Project>> getShowcaseProjects() async {
    final response = await _dio.get('/projects/showcase');
    return (response.data as List<dynamic>)
        .map((item) => Project.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Project> getProject(String projectId) async {
    final response = await _dio.get('/projects/$projectId');
    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Project> getShowcaseProject(String projectId) async {
    final response = await _dio.get('/projects/showcase/$projectId');
    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  /// Own project first; fall back to studio showcase portfolio.
  Future<Project> getProjectOrShowcase(String projectId) async {
    try {
      return await getProject(projectId);
    } catch (_) {
      return getShowcaseProject(projectId);
    }
  }

  Future<Brief> getBrief(String projectId) async {
    final response = await _dio.get('/projects/$projectId/brief');
    return Brief.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Brief> updateBrief(String projectId, UpdateBriefRequest request) async {
    final response = await _dio.put(
      '/projects/$projectId/brief',
      data: request.toJson(),
    );
    return Brief.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<int>> downloadBriefPdf(String projectId) async {
    final response = await _dio.get<List<int>>(
      '/projects/$projectId/brief/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  Future<void> seedDemo() async {
    await _dio.post('/projects/seed-demo');
  }

  Future<Project> createProject({
    String? name,
    String? address,
    double? area,
    String? style,
  }) async {
    final response = await _dio.post(
      '/projects',
      data: {
        if (name != null && name.isNotEmpty) 'name': name,
        'address': ?address,
        'area': ?area,
        'style': ?style,
      },
    );
    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ProjectMember>> getMembers(String projectId) async {
    final response = await _dio.get('/projects/$projectId/members');
    final items = response.data['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => ProjectMember.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectMember> inviteMember({
    required String projectId,
    required String phone,
    required String name,
    String? relation,
  }) async {
    final response = await _dio.post(
      '/projects/$projectId/members',
      data: {
        'phone': phone,
        'name': name,
        if (relation != null && relation.trim().isNotEmpty)
          'relation': relation.trim(),
      },
    );
    return ProjectMember.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeMember({
    required String projectId,
    required String userId,
  }) async {
    await _dio.delete('/projects/$projectId/members/$userId');
  }

  Future<Project> requestSurveyor(String projectId) async {
    final response = await _dio.post('/projects/$projectId/request-surveyor');
    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteProject(String projectId) async {
    await _dio.delete('/projects/$projectId');
  }
}
