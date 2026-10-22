import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// Returns mock [debugCode] when API runs with SMS_PROVIDER=mock (non-prod).
  Future<String?> sendOtp(
    String phone, {
    String channel = 'sms',
  }) async {
    final response = await _dio.post(
      '/auth/send-otp',
      data: {
        'phone': phone,
        'channel': channel,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final code = data['debugCode'];
      if (code is String && code.isNotEmpty) return code;
    }
    return null;
  }

  Future<AuthTokens> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await _dio.post(
      '/auth/verify-otp',
      data: {'phone': phone, 'code': code},
    );

    return AuthTokens.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    return AuthTokens.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
  }

  Future<UserProfile> getMe() async {
    final response = await _dio.get('/users/me');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: userJson is Map<String, dynamic>
          ? UserProfile.fromJson(userJson)
          : null,
    );
  }

  final String accessToken;
  final String refreshToken;
  final UserProfile? user;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    this.name,
    this.role = UserRole.client,
    this.extraRoles = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final extra = (json['extraRoles'] as List<dynamic>? ?? [])
        .map((item) => UserRole.fromJson(item as String?))
        .toList();
    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      role: UserRole.fromJson(json['role'] as String?),
      extraRoles: extra,
    );
  }

  final String id;
  final String phone;
  final String? name;
  final UserRole role;
  final List<UserRole> extraRoles;

  List<UserRole> get allRoles => {role, ...extraRoles}.toList();

  bool get isStaff => allRoles.any((item) => item.isStudio);

  bool hasRole(UserRole value) => allRoles.contains(value);

  bool get canSeeClients =>
      hasRole(UserRole.admin) || hasRole(UserRole.complectator);

  bool get canAssignRoles => hasRole(UserRole.admin);

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role.name,
        'extraRoles': [for (final item in extraRoles) item.name],
      };
}

enum UserRole {
  client,
  designer,
  complectator,
  surveyor,
  admin;

  bool get isStudio =>
      this == UserRole.designer ||
      this == UserRole.complectator ||
      this == UserRole.surveyor ||
      this == UserRole.admin;

  static UserRole fromJson(String? value) {
    switch (value) {
      case 'designer':
        return UserRole.designer;
      case 'complectator':
      case 'staff':
        return UserRole.complectator;
      case 'surveyor':
        return UserRole.surveyor;
      case 'admin':
        return UserRole.admin;
      case 'client':
      default:
        return UserRole.client;
    }
  }
}
