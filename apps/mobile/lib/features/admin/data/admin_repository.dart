import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../auth/data/auth_repository.dart' show UserRole;

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioProvider));
});

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  Future<AdminUsersPage> listUsers({
    String? q,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/admin/users',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'page': page,
        'limit': limit,
      },
    );
    return AdminUsersPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminUser> createUser({
    required String phone,
    required UserRole role,
    String? name,
  }) async {
    final response = await _dio.post(
      '/admin/users',
      data: {
        'phone': phone,
        'role': role.name,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return AdminUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminUser> updateUser({
    required String userId,
    String? phone,
    String? name,
    UserRole? role,
  }) async {
    final response = await _dio.patch(
      '/admin/users/$userId',
      data: {
        if (phone != null) 'phone': phone,
        if (name != null) 'name': name,
        if (role != null) 'role': role.name,
      },
    );
    return AdminUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminUser> setRole({
    required String userId,
    required UserRole role,
  }) async {
    final response = await _dio.patch(
      '/admin/users/$userId/role',
      data: {'role': role.name},
    );
    return AdminUser.fromJson(response.data as Map<String, dynamic>);
  }
}

class AdminUsersPage {
  const AdminUsersPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AdminUser> items;
  final int total;
  final int page;
  final int limit;

  factory AdminUsersPage.fromJson(Map<String, dynamic> json) {
    return AdminUsersPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 30,
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String phone;
  final String? name;
  final String? email;
  final UserRole role;
  final DateTime createdAt;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: UserRole.fromJson(json['role'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

String adminRoleLabel(UserRole role) {
  return switch (role) {
    UserRole.admin => 'Админ (бог)',
    UserRole.designer => 'Дизайнер',
    UserRole.complectator => 'Менеджер',
    UserRole.client => 'Клиент',
  };
}
