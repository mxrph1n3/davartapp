import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/auth_notifier.dart';
import '../chat/data/chat_socket_service.dart';
import '../commerce/presentation/commerce_notifier.dart';
import '../documents/presentation/documents_notifier.dart';
import '../projects/presentation/projects_notifier.dart';
import '../staff/presentation/staff_cart_actions.dart';

/// Keeps shared screens in step with the other person without a reload.
final liveSyncProvider = Provider<void>((ref) {
  final socket = ref.watch(chatSocketServiceProvider);
  final signedIn = ref.watch(authProvider).isAuthenticated;

  void onCart(Map<String, String> _) {
    unawaited(ref.read(cartProvider.notifier).loadCart());
    ref.invalidate(staffProjectCartProvider);
  }

  void onOrder(Map<String, String> _) {
    onCart(const {});
    ref.invalidate(ordersProvider);
    ref.invalidate(orderDetailProvider);
  }

  void onProject(Map<String, String> _) {
    ref.invalidate(projectsListProvider);
    ref.invalidate(projectDetailProvider);
    ref.invalidate(briefProvider);
    ref.invalidate(projectMembersProvider);
  }

  void onDocument(Map<String, String> _) {
    ref.invalidate(projectDocumentsProvider);
  }

  socket.addDomainListener('cart:updated', onCart);
  socket.addDomainListener('order:updated', onOrder);
  socket.addDomainListener('project:updated', onProject);
  socket.addDomainListener('document:updated', onDocument);

  ref.onDispose(() {
    socket.removeDomainListener('cart:updated', onCart);
    socket.removeDomainListener('order:updated', onOrder);
    socket.removeDomainListener('project:updated', onProject);
    socket.removeDomainListener('document:updated', onDocument);
  });

  if (signedIn) {
    unawaited(socket.connect());
  }
});

void refreshSharedData(WidgetRef ref) {
  if (!ref.read(authProvider).isAuthenticated) return;
  unawaited(ref.read(cartProvider.notifier).loadCart());
  ref.invalidate(ordersProvider);
  ref.invalidate(orderDetailProvider);
  ref.invalidate(projectsListProvider);
  ref.invalidate(projectDetailProvider);
  ref.invalidate(briefProvider);
  ref.invalidate(projectMembersProvider);
  ref.invalidate(projectDocumentsProvider);
  ref.invalidate(staffProjectCartProvider);
}
