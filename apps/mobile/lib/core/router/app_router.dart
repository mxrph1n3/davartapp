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
import '../../features/chat/presentation/new_chat_screen.dart';
import '../../features/profile/presentation/addresses_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/faq_screen.dart';
import '../../features/profile/presentation/legal_screen.dart';
import '../../features/profile/presentation/notifications_settings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/projects/presentation/brief_screen.dart';
import '../../features/projects/presentation/portfolio_screen.dart';
import '../../features/projects/presentation/project_detail_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/staff/presentation/staff_audit_screen.dart';
import '../../features/staff/presentation/staff_brief_screen.dart';
import '../../features/staff/presentation/staff_checkout_screen.dart';
import '../../features/staff/presentation/staff_client_cart_screen.dart';
import '../../features/staff/presentation/staff_client_profile_screen.dart';
import '../../features/staff/presentation/staff_order_detail_screen.dart';
import '../../features/staff/presentation/staff_profile_screen.dart';
import '../../features/staff/presentation/staff_project_workspace_screen.dart';
import '../shell/staff_second_tab.dart';

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
  static String staffProductDetail(String id) => '/staff/product/$id';
  static String orderDetail(String id) => '/orders/$id';
  static String projectDetail(String id) => '/projects/$id';
  static String projectBrief(String id) => '/projects/$id/brief';
  static const portfolio = '/projects/portfolio';
  static String documentViewer(String id) => '/documents/$id';
  static String chatDetail(String id) => '/chat/$id';
  static String chatInfo(String id) => '/chat/$id/info';
  static const newChat = '/chat/new';
  static const staffNewChat = '/staff/chats/new';
  static String staffChatInfo(String id) => '/staff/chats/$id/info';
  static String staffClientProfile(String id) => '/staff/clients/$id';
  static String staffProjectWorkspace(String projectId) =>
      '/staff/projects/$projectId/workspace';
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
  static const notifications = '/profile/notifications';
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

String newChatPathForRole(UserRole? role) =>
    role?.isStudio == true ? AppRoutes.staffNewChat : AppRoutes.newChat;

String chatInfoPathForRole(UserRole? role, String chatId) =>
    AppRoutes.chatInfo(chatId);

String productPathForRole(UserRole? role, String id) =>
    role?.isStudio == true
        ? AppRoutes.staffProductDetail(id)
        : AppRoutes.productDetail(id);

String searchPathForRole(UserRole? role) =>
    role?.isStudio == true ? '/staff/search' : AppRoutes.search;

String favoritesPathForRole(UserRole? role) =>
    role?.isStudio == true ? '/staff/favorites' : AppRoutes.favorites;

String editProfilePathForRole(UserRole? role) =>
    role?.isStudio == true ? '/staff/profile/edit' : AppRoutes.editProfile;

String notificationsPathForRole(UserRole? role) =>
    role?.isStudio == true
        ? '/staff/profile/notifications'
        : AppRoutes.notifications;

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

final rootNavigatorKey = GlobalKey<NavigatorState>();

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
    navigatorKey: rootNavigatorKey,
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
      final isStudio = authState.user?.isStaff ?? role.isStudio;
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

      if (isStudio && _isClientShellPath(location)) {
        if (location == AppRoutes.catalog) return AppRoutes.staffCatalog;
        if (location == AppRoutes.chat) return AppRoutes.staffChats;
        if (location == AppRoutes.profile) return AppRoutes.staffProfile;
        return AppRoutes.staffChats;
      }

      if (!isStudio && _isStaffPath(location)) {
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
          final phone = state.uri.queryParameters['phone'] ?? '';
          final initialCode =
              state.extra is String ? state.extra as String : null;
          return OtpScreen(phone: phone, initialCode: initialCode);
        },
      ),
      // Fullscreen chat thread — bottom nav hidden.
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final id = state.pathParameters['id'];
          if (id == 'new') return AppRoutes.newChat;
          return null;
        },
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
        path: '/chat/:id/info',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final chatId = state.pathParameters['id']!;
          return ChatInfoScreen(chatId: chatId);
        },
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
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) {
                  final query = state.uri.queryParameters['q'] ?? '';
                  return SearchScreen(initialQuery: query);
                },
              ),
              GoRoute(
                path: '/product/:id',
                builder: (context, state) {
                  final productId = state.pathParameters['id']!;
                  return ProductDetailScreen(productId: productId);
                },
              ),
              GoRoute(
                path: AppRoutes.favorites,
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.projects,
                builder: (context, state) => const ProjectsScreen(),
                routes: [
                  GoRoute(
                    path: 'portfolio',
                    builder: (context, state) => const PortfolioScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final projectId = state.pathParameters['id']!;
                      return ProjectDetailScreen(projectId: projectId);
                    },
                    routes: [
                      GoRoute(
                        path: 'brief',
                        builder: (context, state) {
                          final projectId = state.pathParameters['id']!;
                          return BriefScreen(projectId: projectId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/documents/:id',
                builder: (context, state) {
                  final documentId = state.pathParameters['id']!;
                  return DocumentViewerScreen(documentId: documentId);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (context, state) => const ChatScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const NewChatScreen(),
                  ),
                  GoRoute(
                    path: ':id/info',
                    builder: (context, state) {
                      final chatId = state.pathParameters['id']!;
                      return ChatInfoScreen(chatId: chatId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.cart,
                builder: (context, state) => const CartScreen(),
                routes: [
                  GoRoute(
                    path: 'checkout',
                    builder: (context, state) => const CheckoutScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.checkout,
                builder: (context, state) => const CheckoutScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'addresses',
                    builder: (context, state) => const AddressesScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) =>
                        const NotificationsSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'faq',
                    builder: (context, state) => const FaqScreen(),
                  ),
                  GoRoute(
                    path: 'privacy',
                    builder: (context, state) =>
                        const LegalScreen(type: 'privacy'),
                  ),
                  GoRoute(
                    path: 'terms',
                    builder: (context, state) =>
                        const LegalScreen(type: 'terms'),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.orders,
                builder: (context, state) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final orderId = state.pathParameters['id']!;
                      return OrderDetailScreen(orderId: orderId);
                    },
                  ),
                ],
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
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const NewChatScreen(),
                  ),
                  GoRoute(
                    path: ':id/info',
                    builder: (context, state) {
                      final chatId = state.pathParameters['id']!;
                      return ChatInfoScreen(chatId: chatId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.staffClients,
                builder: (context, state) => const StaffSecondTab(),
                routes: [
                  GoRoute(
                    path: ':clientId',
                    builder: (context, state) {
                      final clientId = state.pathParameters['clientId']!;
                      return StaffClientProfileScreen(clientId: clientId);
                    },
                    routes: [
                      GoRoute(
                        path: 'orders/:orderId',
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
                ],
              ),
              GoRoute(
                path: '/staff/projects/:projectId/workspace',
                builder: (context, state) {
                  final projectId = state.pathParameters['projectId']!;
                  return StaffProjectWorkspaceScreen(projectId: projectId);
                },
              ),
              GoRoute(
                path: '/staff/projects/:projectId/cart',
                builder: (context, state) {
                  final projectId = state.pathParameters['projectId']!;
                  return StaffProjectCartScreen(projectId: projectId);
                },
              ),
              GoRoute(
                path: '/staff/projects/:projectId/checkout',
                builder: (context, state) {
                  final projectId = state.pathParameters['projectId']!;
                  return StaffCheckoutScreen(projectId: projectId);
                },
              ),
              GoRoute(
                path: AppRoutes.staffAudit,
                builder: (context, state) => const StaffAuditScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.staffCatalog,
                builder: (context, state) => const CatalogScreen(),
              ),
              GoRoute(
                path: '/staff/search',
                builder: (context, state) {
                  final query = state.uri.queryParameters['q'] ?? '';
                  return SearchScreen(initialQuery: query);
                },
              ),
              GoRoute(
                path: '/staff/product/:id',
                builder: (context, state) {
                  final productId = state.pathParameters['id']!;
                  return ProductDetailScreen(productId: productId);
                },
              ),
              GoRoute(
                path: '/staff/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.staffProfile,
                builder: (context, state) => const StaffProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) =>
                        const NotificationsSettingsScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.adminUsers,
                builder: (context, state) => const AdminUsersScreen(),
              ),
            ],
          ),
        ],
      ),
    ]
  );
  ref.onDispose(router.dispose);
  return router;
});
