import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/auth_notifier.dart';
import 'profile_notifier.dart';

class NotificationPrefs {
  const NotificationPrefs({
    required this.messages,
    required this.orders,
    required this.documents,
  });

  final bool messages;
  final bool orders;
  final bool documents;

  bool get anyEnabled => messages || orders || documents;

  NotificationPrefs copyWith({
    bool? messages,
    bool? orders,
    bool? documents,
  }) {
    return NotificationPrefs(
      messages: messages ?? this.messages,
      orders: orders ?? this.orders,
      documents: documents ?? this.documents,
    );
  }
}

const _messagesKey = 'notif_messages';
const _ordersKey = 'notif_orders';
const _documentsKey = 'notif_documents';

final notificationPrefsProvider =
    AsyncNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  NotificationPrefsNotifier.new,
);

class NotificationPrefsNotifier extends AsyncNotifier<NotificationPrefs> {
  @override
  Future<NotificationPrefs> build() async {
    final prefs = await SharedPreferences.getInstance();
    final authenticated = ref.watch(authProvider).isAuthenticated;

    var messages = prefs.getBool(_messagesKey) ?? true;
    var orders = prefs.getBool(_ordersKey) ?? true;
    var documents = prefs.getBool(_documentsKey) ?? true;

    if (authenticated) {
      try {
        final profile = await ref.watch(profileProvider.future);
        if (!profile.notificationsEnabled) {
          messages = false;
          orders = false;
          documents = false;
        }
      } catch (_) {}
    }

    return NotificationPrefs(
      messages: messages,
      orders: orders,
      documents: documents,
    );
  }

  Future<void> setMessages(bool value) => _update(messages: value);
  Future<void> setOrders(bool value) => _update(orders: value);
  Future<void> setDocuments(bool value) => _update(documents: value);

  Future<void> _update({
    bool? messages,
    bool? orders,
    bool? documents,
  }) async {
    final current = state.valueOrNull ??
        const NotificationPrefs(messages: true, orders: true, documents: true);
    final next = current.copyWith(
      messages: messages,
      orders: orders,
      documents: documents,
    );
    state = AsyncData(next);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_messagesKey, next.messages);
    await prefs.setBool(_ordersKey, next.orders);
    await prefs.setBool(_documentsKey, next.documents);

    if (!ref.read(authProvider).isAuthenticated) return;
    try {
      await ref.read(profileActionsProvider).updateProfile(
            notificationsEnabled: next.anyEnabled,
          );
    } catch (_) {
      state = AsyncData(current);
    }
  }
}
