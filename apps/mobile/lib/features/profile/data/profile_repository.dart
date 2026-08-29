import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../auth/data/auth_repository.dart' show UserRole;

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<UserProfile> getMe() async {
    final response = await _dio.get('/users/me');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    bool? notificationsEnabled,
  }) async {
    final response = await _dio.patch(
      '/users/me',
      data: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (notificationsEnabled != null)
          'notificationsEnabled': notificationsEnabled,
      },
    );
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> registerFcmToken({
    required String token,
    String? platform,
  }) async {
    await _dio.post(
      '/users/me/fcm-token',
      data: {
        'token': token,
        if (platform != null) 'platform': platform,
      },
    );
  }

  Future<List<UserAddress>> getAddresses() async {
    final response = await _dio.get('/users/me/addresses');
    return (response.data as List<dynamic>)
        .map((item) => UserAddress.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserAddress> createAddress(CreateAddressRequest request) async {
    final response = await _dio.post('/users/me/addresses', data: request.toJson());
    return UserAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserAddress> updateAddress(
    String id,
    CreateAddressRequest request,
  ) async {
    final response = await _dio.patch(
      '/users/me/addresses/$id',
      data: request.toJson(),
    );
    return UserAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete('/users/me/addresses/$id');
  }

  Future<List<FaqItem>> getFaq() async {
    final response = await _dio.get('/faq');
    return (response.data as List<dynamic>)
        .map((item) => FaqItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatSupportInfo> getSupportChat() async {
    final response = await _dio.get('/chats/support');
    return ChatSupportInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LegalDocument> getPrivacyPolicy() async {
    final response = await _dio.get('/legal/privacy');
    return LegalDocument.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LegalDocument> getTermsOfService() async {
    final response = await _dio.get('/legal/terms');
    return LegalDocument.fromJson(response.data as Map<String, dynamic>);
  }
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.version,
    required this.updatedAt,
    required this.sections,
  });

  final String title;
  final String version;
  final String updatedAt;
  final List<LegalSection> sections;

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      title: json['title'] as String,
      version: json['version'] as String,
      updatedAt: json['updatedAt'] as String,
      sections: (json['sections'] as List<dynamic>)
          .map((item) => LegalSection.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;

  factory LegalSection.fromJson(Map<String, dynamic> json) {
    return LegalSection(
      heading: json['heading'] as String,
      body: json['body'] as String,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    required this.notificationsEnabled,
    this.role = UserRole.client,
    this.extraRoles = const [],
  });

  final String id;
  final String phone;
  final String? name;
  final String? email;
  final bool notificationsEnabled;
  final UserRole role;
  final List<UserRole> extraRoles;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final extra = (json['extraRoles'] as List<dynamic>? ?? [])
        .map((item) => UserRole.fromJson(item as String?))
        .toList();
    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      role: UserRole.fromJson(json['role'] as String?),
      extraRoles: extra,
    );
  }
}

class UserAddress {
  const UserAddress({
    required this.id,
    this.label,
    required this.city,
    required this.street,
    required this.building,
    this.apartment,
    required this.isDefault,
    required this.formatted,
  });

  final String id;
  final String? label;
  final String city;
  final String street;
  final String building;
  final String? apartment;
  final bool isDefault;
  final String formatted;

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'] as String,
      label: json['label'] as String?,
      city: json['city'] as String,
      street: json['street'] as String,
      building: json['building'] as String,
      apartment: json['apartment'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      formatted: json['formatted'] as String,
    );
  }
}

class CreateAddressRequest {
  const CreateAddressRequest({
    this.label,
    required this.city,
    required this.street,
    required this.building,
    this.apartment,
    this.isDefault = false,
  });

  final String? label;
  final String city;
  final String street;
  final String building;
  final String? apartment;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
        if (label != null) 'label': label,
        'city': city,
        'street': street,
        'building': building,
        if (apartment != null) 'apartment': apartment,
        'isDefault': isDefault,
      };
}

class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });

  final String id;
  final String question;
  final String answer;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
    );
  }
}

class ChatSupportInfo {
  const ChatSupportInfo({required this.id, required this.title});

  final String id;
  final String title;

  factory ChatSupportInfo.fromJson(Map<String, dynamic> json) {
    return ChatSupportInfo(
      id: json['id'] as String,
      title: json['title'] as String,
    );
  }
}
