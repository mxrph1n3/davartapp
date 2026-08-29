import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../chat/data/chat_models.dart';
import '../../commerce/data/commerce_models.dart';
import '../../profile/data/profile_repository.dart' show CreateAddressRequest, UserAddress;
import '../../projects/data/projects_models.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(ref.watch(dioProvider));
});

class StaffRepository {
  StaffRepository(this._dio);

  final Dio _dio;

  Future<StaffClientsPage> listClients({
    String? q,
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _dio.get(
      '/staff/clients',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'page': page,
        'limit': limit,
      },
    );
    return StaffClientsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChatSummary> getClientChat(String clientId) async {
    final response = await _dio.get('/staff/clients/$clientId/chat');
    return ChatSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<StaffRosterMember>> listRoster({
    required String role,
  }) async {
    final response = await _dio.get(
      '/staff/roster',
      queryParameters: {'role': role},
    );
    final items = response.data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => StaffRosterMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> assignProjectStaff({
    required String projectId,
    String? designerId,
    String? surveyorId,
  }) async {
    await _dio.patch(
      '/staff/projects/$projectId/staff',
      data: {
        if (designerId != null) 'designerId': designerId,
        if (surveyorId != null) 'surveyorId': surveyorId,
      },
    );
  }

  Future<void> inviteByPhone({required String phone, String? name}) async {
    await _dio.post(
      '/staff/clients/invite',
      data: {
        'phone': phone,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
  }

  Future<StaffClientProfile> getClient(String clientId) async {
    final response = await _dio.get('/staff/clients/$clientId');
    return StaffClientProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<UserAddress>> getAddresses(String clientId) async {
    final response = await _dio.get('/staff/clients/$clientId/addresses');
    return (response.data as List<dynamic>)
        .map((item) => UserAddress.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserAddress> createAddress(
    String clientId,
    CreateAddressRequest request,
  ) async {
    final response = await _dio.post(
      '/staff/clients/$clientId/addresses',
      data: request.toJson(),
    );
    return UserAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Project>> getProjects(String clientId) async {
    final response = await _dio.get('/staff/clients/$clientId/projects');
    return (response.data as List<dynamic>)
        .map((item) => Project.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Project> createProject(
    String clientId, {
    String? name,
  }) async {
    final response = await _dio.post(
      '/staff/clients/$clientId/projects',
      data: {
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Project> getProject(String clientId, String projectId) async {
    final response =
        await _dio.get('/staff/clients/$clientId/projects/$projectId');
    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Brief> getBrief(String clientId, String projectId) async {
    final response =
        await _dio.get('/staff/clients/$clientId/projects/$projectId/brief');
    return Brief.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<int>> downloadBriefPdf(String clientId, String projectId) async {
    final response = await _dio.get<List<int>>(
      '/staff/clients/$clientId/projects/$projectId/brief/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  Future<Cart> getCart(String projectId) async {
    final response = await _dio.get('/staff/projects/$projectId/cart');
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> addToCart(
    String projectId, {
    required String productId,
    int quantity = 1,
  }) async {
    final response = await _dio.post(
      '/staff/projects/$projectId/cart/items',
      data: {'productId': productId, 'quantity': quantity},
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> updateCartItem(
    String projectId, {
    required String itemId,
    required int quantity,
  }) async {
    final response = await _dio.patch(
      '/staff/projects/$projectId/cart/items/$itemId',
      data: {'quantity': quantity},
    );
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> removeCartItem(String projectId, String itemId) async {
    final response =
        await _dio.delete('/staff/projects/$projectId/cart/items/$itemId');
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> clearCart(String projectId) async {
    final response = await _dio.delete('/staff/projects/$projectId/cart');
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Order> createOrder(
    String projectId, {
    required List<String> cartItemIds,
    required String address,
    String? comment,
  }) async {
    final response = await _dio.post(
      '/staff/projects/$projectId/orders',
      data: {
        'cartItemIds': cartItemIds,
        'address': address,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Order>> listOrders(String clientId) async {
    final response = await _dio.get('/staff/clients/$clientId/orders');
    return (response.data as List<dynamic>)
        .map((item) => Order.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Order> getOrder(String clientId, String orderId) async {
    final response =
        await _dio.get('/staff/clients/$clientId/orders/$orderId');
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StaffAuditPage> listAudit({
    String? clientId,
    int page = 1,
    int limit = 40,
  }) async {
    final response = await _dio.get(
      '/staff/audit',
      queryParameters: {
        if (clientId != null) 'clientId': clientId,
        'page': page,
        'limit': limit,
      },
    );
    return StaffAuditPage.fromJson(response.data as Map<String, dynamic>);
  }
}

class StaffClientsPage {
  const StaffClientsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory StaffClientsPage.fromJson(Map<String, dynamic> json) {
    return StaffClientsPage(
      items: (json['items'] as List<dynamic>)
          .map((e) => StaffClient.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 30,
    );
  }

  final List<StaffClient> items;
  final int total;
  final int page;
  final int limit;
}

class StaffClient {
  const StaffClient({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    required this.projectsCount,
    required this.ordersCount,
    required this.cartItemsCount,
  });

  factory StaffClient.fromJson(Map<String, dynamic> json) {
    return StaffClient(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      projectsCount: json['projectsCount'] as int? ?? 0,
      ordersCount: json['ordersCount'] as int? ?? 0,
      cartItemsCount: json['cartItemsCount'] as int? ?? 0,
    );
  }

  final String id;
  final String phone;
  final String? name;
  final String? email;
  final int projectsCount;
  final int ordersCount;
  final int cartItemsCount;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : phone;
}

class StaffRosterMember {
  const StaffRosterMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  factory StaffRosterMember.fromJson(Map<String, dynamic> json) {
    return StaffRosterMember(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['phone'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String phone;
  final String role;
}

class StaffClientProfile {
  const StaffClientProfile({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    required this.projectsCount,
    required this.ordersCount,
    required this.addressesCount,
    required this.cartItemsCount,
    required this.createdAt,
  });

  factory StaffClientProfile.fromJson(Map<String, dynamic> json) {
    return StaffClientProfile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      projectsCount: json['projectsCount'] as int? ?? 0,
      ordersCount: json['ordersCount'] as int? ?? 0,
      addressesCount: json['addressesCount'] as int? ?? 0,
      cartItemsCount: json['cartItemsCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String phone;
  final String? name;
  final String? email;
  final int projectsCount;
  final int ordersCount;
  final int addressesCount;
  final int cartItemsCount;
  final DateTime createdAt;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : phone;
}

class StaffAuditPage {
  const StaffAuditPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory StaffAuditPage.fromJson(Map<String, dynamic> json) {
    return StaffAuditPage(
      items: (json['items'] as List<dynamic>)
          .map((e) => StaffAuditEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 40,
    );
  }

  final List<StaffAuditEntry> items;
  final int total;
  final int page;
  final int limit;
}

class StaffAuditEntry {
  const StaffAuditEntry({
    required this.id,
    required this.action,
    required this.actionLabel,
    required this.createdAt,
    required this.actorName,
    required this.clientName,
    required this.clientId,
  });

  factory StaffAuditEntry.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>? ?? {};
    final client = json['client'] as Map<String, dynamic>? ?? {};
    return StaffAuditEntry(
      id: json['id'] as String,
      action: json['action'] as String,
      actionLabel: json['actionLabel'] as String? ?? json['action'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      actorName: actor['name'] as String? ?? actor['phone'] as String? ?? '—',
      clientName:
          client['name'] as String? ?? client['phone'] as String? ?? '—',
      clientId: client['id'] as String? ?? '',
    );
  }

  final String id;
  final String action;
  final String actionLabel;
  final DateTime createdAt;
  final String actorName;
  final String clientName;
  final String clientId;
}

final staffClientsQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

final staffClientsListProvider =
    FutureProvider.autoDispose<StaffClientsPage>((ref) async {
  final q = ref.watch(staffClientsQueryProvider);
  return ref.watch(staffRepositoryProvider).listClients(
        q: q.isEmpty ? null : q,
      );
});

final staffClientProfileProvider =
    FutureProvider.autoDispose.family<StaffClientProfile, String>((ref, id) {
  return ref.watch(staffRepositoryProvider).getClient(id);
});

final staffClientAddressesProvider =
    FutureProvider.autoDispose.family<List<UserAddress>, String>((ref, id) {
  return ref.watch(staffRepositoryProvider).getAddresses(id);
});

final staffClientProjectsProvider =
    FutureProvider.autoDispose.family<List<Project>, String>((ref, id) {
  return ref.watch(staffRepositoryProvider).getProjects(id);
});

final staffAuditProvider =
    FutureProvider.autoDispose<StaffAuditPage>((ref) async {
  return ref.watch(staffRepositoryProvider).listAudit();
});
