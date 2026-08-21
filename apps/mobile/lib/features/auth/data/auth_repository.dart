import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<void> sendOtp(String phone) async {
    await _dio.post('/auth/send-otp', data: {'phone': phone});
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
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    this.name,
    this.role = UserRole.client,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      role: UserRole.fromJson(json['role'] as String?),
    );
  }

  final String id;
  final String phone;
  final String? name;
  final UserRole role;

  bool get isStaff => role.isStudio;
}

enum UserRole {
  client,
  designer,
  complectator,
  admin;

  bool get isStudio =>
      this == UserRole.designer ||
      this == UserRole.complectator ||
      this == UserRole.admin;

  static UserRole fromJson(String? value) {
    switch (value) {
      case 'designer':
        return UserRole.designer;
      case 'complectator':
      case 'staff': // legacy JWT / cached payloads
        return UserRole.complectator;
      case 'admin':
        return UserRole.admin;
      case 'client':
      default:
        return UserRole.client;
    }
  }
}
