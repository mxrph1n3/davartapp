import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../deep_link/deep_link.dart';
import '../shell/main_shell.dart';
import '../shell/staff_shell.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/catalog/presentation/search_screen.dart';
import '../../features/documents/presentation/document_viewer_screen.dart';
import '../../features/commerce/presentation/cart_screen.dart';
import '../../features/commerce/presentation/checkout_screen.dart';
import '../../features/commerce/presentation/favorites_screen.dart';
import '../../features/commerce/presentation/order_detail_screen.dart';
import '../../features/commerce/presentation/orders_screen.dart';
import '../../features/chat/presentation/chat_detail_screen.dart';
import '../../features/chat/presentation/chat_info_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/profile/presentation/addresses_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/faq_screen.dart';
import '../../features/profile/presentation/legal_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/projects/presentation/brief_screen.dart';
import '../../features/projects/presentation/project_detail_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/staff/presentation/staff_audit_screen.dart';
import '../../features/staff/presentation/staff_brief_screen.dart';
import '../../features/staff/presentation/staff_checkout_screen.dart';
import '../../features/staff/presentation/staff_client_cart_screen.dart';
import '../../features/staff/presentation/staff_client_profile_screen.dart';
import '../../features/staff/presentation/staff_clients_screen.dart';
import '../../features/staff/presentation/staff_order_detail_screen.dart';
import '../../features/staff/presentation/staff_profile_screen.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const phone = '/phone';
  static const otp = '/otp';
  static const catalog = '/catalog';
  static const projects = '/projects';
  static const chat = '/chat';
  static const profile = '/profile';
  static const search = '/search';
  static const cart = '/cart';
  static const favorites = '/favorites';
  static const checkout = '/checkout';
  static const orders = '/orders';

  // Staff shell
  static const staffChats = '/staff/chats';
  static const staffClients = '/staff/clients';
  static const staffCatalog = '/staff/catalog';
  static const staffProfile = '/staff/profile';
  static const staffAudit = '/staff/audit';
  static const adminUsers = '/staff/admin/users';

  static String productDetail(String id) => '/product/$id';
  static String orderDetail(String id) => '/orders/$id';
  static String projectDetail(String id) => '/projects/$id';
  static String projectBrief(String id) => '/projects/$id/brief';
  static String documentViewer(String id) => '/documents/$id';
  static String chatDetail(String id) => '/chat/$id';
  static String chatInfo(String id) => '/chat/$id/info';
  static String staffClientProfile(String id) => '/staff/clients/$id';
  static String staffProjectCart(String projectId) =>
      '/staff/projects/$projectId/cart';
  static String staffProjectCheckout(String projectId) =>
      '/staff/projects/$projectId/checkout';
  static String staffClientOrder(String clientId, String orderId) =>
      '/staff/clients/$clientId/orders/$orderId';
  static String staffClientBrief(String clientId, String projectId) =>
      '/staff/clients/$clientId/projects/$projectId/brief';
  static const editProfile = '/profile/edit';
  static const addresses = '/profile/addresses';
  static const settings = '/profile/settings';
  static const faq = '/profile/faq';
  static const privacy = '/profile/privacy';
  static const terms = '/profile/terms';

  static String homeForRole(UserRole role) =>
      role.isStudio ? staffChats : catalog;
}

String catalogPathForRole(UserRole? role) =>
    role?.isStudio == true ? AppRoutes.staffCatalog : AppRoutes.catalog;

String profilePathForRole(UserRole? role) =>
    role?.isStudio == true ? AppRoutes.staffProfile : AppRoutes.profile;

String chatPathForRole(UserRole? role) =>
    role?.isStudio == true ? AppRoutes.staffChats : AppRoutes.chat;

String projectsPathForRole(UserRole? role) =>
    role?.isStudio == true ? AppRoutes.staffClients : AppRoutes.projects;

/// Staff overlay routes often sit on the root navigator with an empty stack,
/// so [AppBar] will not imply a back button and [GoRouter.pop] would throw.
void popOrGo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

bool _isStaffPath(String location) => location.startsWith('/staff');

bool _isClientShellPath(String location) {
  return location == AppRoutes.catalog ||
      location == AppRoutes.projects ||
      location == AppRoutes.chat ||
      location == AppRoutes.cart ||
      location == AppRoutes.profile;
}

final routerProvider = Provider<GoRouter>((ref) {
  // read (not watch): recreate GoRouter only when this provider is disposed,
  // not when auth refresh fires — avoids Duplicate GlobalKey on the shell.
  final refreshNotifier = ref.read(routerRefreshProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;

      if (authState.status == AuthStatus.unknown) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final isAuthRoute =
          location == AppRoutes.phone || location == AppRoutes.otp;
      final isSplash = location == AppRoutes.splash;
      final embeddedLogin = state.uri.queryParameters['embedded'] == '1';

      if (!authState.isAuthenticated) {
        if (isAuthRoute) return null;
        if (isSplash) return AppRoutes.catalog;
        if (_isStaffPath(location)) return AppRoutes.catalog;
        return null;
      }

      final role = authState.user?.role ?? UserRole.client;
      final home = AppRoutes.homeForRole(role);

      if (isAuthRoute || isSplash) {
        if (isAuthRoute && embeddedLogin) return null;
        final pending = ref.read(pendingDeepLinkProvider);
        if (pending != null) {
          Future<void>.microtask(() {
            ref.read(pendingDeepLinkProvider.notifier).state = null;
          });
          return pending;
        }
        return home;
      }

      if (role.isStudio && _isClientShellPath(location)) {
        if (location == AppRoutes.catalog) return AppRoutes.staffCatalog;
        if (location == AppRoutes.chat) return AppRoutes.staffChats;
        if (location == AppRoutes.profile) return AppRoutes.staffProfile;
        return AppRoutes.staffChats;
      }

      if (!role.isStudio && _isStaffPath(location)) {
        return AppRoutes.catalog;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.phone,
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ??
              state.extra as String? ??
              '';
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) {
          final query = state.uri.queryParameters['q'] ?? '';
          return SearchScreen(initialQuery: query);
        },
      ),
      GoRoute(
        path: '/product/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final productId = state.pathParameters['id']!;
          return ProductDetailScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/documents/:id',
        builder: (context, state) {
          final documentId = state.pathParameters['id']!;
          return DocumentViewerScreen(documentId: documentId);
        },
      ),
      GoRoute(
        path: '/chat/:id/info',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chatId = state.pathParameters['id']!;
          return ChatInfoScreen(chatId: chatId);
        },
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final chatId = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'];
          final clientId = state.uri.queryParameters['clientId'];
          final projectId = state.uri.queryParameters['projectId'];
          return ChatDetailScreen(
            chatId: chatId,
            title: title,
            clientId: clientId,
            projectId: projectId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.staffAudit,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StaffAuditScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminUsers,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/staff/clients/:clientId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final clientId = state.pathParameters['clientId']!;
          return StaffClientProfileScreen(clientId: clientId);
        },
        routes: [
          GoRoute(
            path: 'orders/:orderId',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final clientId = state.pathParameters['clientId']!;
              final orderId = state.pathParameters['orderId']!;
              return StaffOrderDetailScreen(
                clientId: clientId,
                orderId: orderId,
              );
            },
          ),
          GoRoute(
            path: 'projects/:projectId/brief',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final clientId = state.pathParameters['clientId']!;
              final projectId = state.pathParameters['projectId']!;
              return StaffBriefScreen(
                clientId: clientId,
                projectId: projectId,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/staff/projects/:projectId/cart',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          return StaffProjectCartScreen(projectId: projectId);
        },
      ),
      GoRoute(
        path: '/staff/projects/:projectId/checkout',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          return StaffCheckoutScreen(projectId: projectId);
        },
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.faq,
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const LegalScreen(type: 'privacy'),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const LegalScreen(type: 'terms'),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/projects/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final projectId = state.pathParameters['id']!;
          return ProjectDetailScreen(projectId: projectId);
        },
        routes: [
          GoRoute(
            path: 'brief',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final projectId = state.pathParameters['id']!;
              return BriefScreen(projectId: projectId);
            },
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.catalog,
                builder: (context, state) => const CatalogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.projects,
                builder: (context, state) => const ProjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.cart,
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return StaffShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.staffChats,
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.staffClients,
                builder: (context, state) => const StaffClientsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.staffCatalog,
                builder: (context, state) => const CatalogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.staffProfile,
                builder: (context, state) => const StaffProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
