import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deep_link/deep_link.dart';
import '../../core/router/app_router.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/chat/presentation/chat_notifier.dart';
import '../../features/commerce/presentation/commerce_notifier.dart';
import '../../features/documents/presentation/documents_notifier.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/projects/presentation/projects_notifier.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

class PushService {
  PushService(this._ref);

  final Ref _ref;
  static const _iosChannel = MethodChannel('davart/push');
  static const _androidChannel = MethodChannel('davart/notify');

  StreamSubscription<String>? _tokenRefreshSub;
  var _firebaseReady = false;
  var _iosBound = false;
  var _openedBound = false;
  String? _apnsToken;
  String? _activeChatId;
  String? _handledPayloadKey;
  DateTime? _handledPayloadAt;
  Map<String, String>? _pendingOpen;

  Future<bool> bootstrap() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      _bindIosChannel();
      return true;
    }
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _firebaseReady = true;
      return true;
    } catch (error) {
      debugPrint('Firebase not configured yet: $error');
      return false;
    }
  }

  Future<void> initialize() async {
    final authState = _ref.read(authProvider);
    if (!authState.isAuthenticated || authState.user == null) return;

    if (Platform.isIOS) {
      _bindIosChannel();
      try {
        await _iosChannel.invokeMethod<bool>('register');
      } catch (error) {
        debugPrint('APNs register failed: $error');
      }
      await _sendApnsToken();
      await _openPending();
      flushPending();
      return;
    }

    if (Platform.isAndroid) {
      try {
        await _androidChannel.invokeMethod<bool>('prepare');
      } catch (error) {
        debugPrint('Android notification permission failed: $error');
      }
    }

    if (!_firebaseReady) {
      flushPending();
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) {
      await _sendToken(token);
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = messaging.onTokenRefresh.listen(_sendToken);

    if (!_openedBound) {
      _openedBound = true;
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        handleNotificationData(
          _ref.read(routerProvider),
          message.data,
          messageId: message.messageId,
        );
      });
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        handleNotificationData(
          _ref.read(routerProvider),
          initial.data,
          messageId: initial.messageId,
        );
      }
    }
    flushPending();
  }

  String? get activeChatId => _activeChatId;

  Future<void> setActiveChat(String chatId) async {
    _activeChatId = chatId;
    if (kIsWeb || !Platform.isIOS) return;
    _bindIosChannel();
    try {
      await _iosChannel.invokeMethod<void>('setActiveChat', {'chatId': chatId});
    } catch (_) {}
  }

  Future<void> clearActiveChat(String chatId) async {
    if (_activeChatId != chatId) return;
    _activeChatId = null;
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _iosChannel.invokeMethod<void>('setActiveChat', {'chatId': ''});
    } catch (_) {}
  }

  /// System banner. On iOS this is a local notification; on Android the
  /// status-bar notification. A closed or powered-off iPhone still gets the
  /// copy Apple stored from the server.
  Future<void> showChatBanner({
    required String messageId,
    required String title,
    required String body,
    required String chatId,
  }) async {
    if (kIsWeb) return;
    try {
      if (Platform.isIOS) {
        _bindIosChannel();
        await _iosChannel.invokeMethod<void>('show', {
          'messageId': messageId,
          'title': title,
          'body': body,
          'chatId': chatId,
        });
        return;
      }
      await _androidChannel.invokeMethod<void>('show', {
        'messageId': messageId,
        'title': title,
        'body': body,
        'chatId': chatId,
      });
    } catch (error) {
      debugPrint('Chat banner failed: $error');
    }
  }

  void _bindIosChannel() {
    if (_iosBound) return;
    _iosBound = true;
    _iosChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'token':
          final token = call.arguments as String?;
          if (token == null || token.isEmpty) return;
          _apnsToken = token;
          await _sendApnsToken();
        case 'open':
          _openNotification(_stringMap(call.arguments));
      }
    });
  }

  Future<void> _sendApnsToken() async {
    final token = _apnsToken;
    final authState = _ref.read(authProvider);
    if (token == null || !authState.isAuthenticated) return;
    await _sendToken(token, platform: kDebugMode ? 'ios-sandbox' : 'ios');
  }

  Future<void> _openPending() async {
    try {
      final pending = await _iosChannel.invokeMethod<Object?>('pendingOpen');
      _openNotification(_stringMap(pending));
    } catch (_) {}
  }

  Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item?.toString() ?? ''));
  }

  void _openChat(String? chatId, String? title) {
    if (chatId == null || chatId.isEmpty) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    final label = (title == null || title.trim().isEmpty) ? 'Чат' : title.trim();
    try {
      final router = _ref.read(routerProvider);
      final path = router.state.uri.path;
      final target = AppRoutes.chatDetail(chatId);
      // Already on this chat: refresh it instead of opening another copy on top.
      if (_activeChatId == chatId || path == target || path.startsWith('$target/')) {
        unawaited(
          _ref.read(chatMessagesProvider(chatId).notifier).refreshLatest(),
        );
        return;
      }
      router.go('$target?title=${Uri.encodeComponent(label)}');
    } catch (_) {}
  }

  Future<void> _sendToken(String token, {String? platform}) async {
    try {
      await _ref.read(profileRepositoryProvider).registerFcmToken(
            token: token,
            platform: platform ?? Platform.operatingSystem,
          );
    } catch (_) {}
  }

  void handleNotificationData(
    GoRouter router,
    Map<String, dynamic> data, {
    String? messageId,
  }) {
    final payload = _stringMap(data);
    if (messageId != null && messageId.isNotEmpty) {
      payload['messageId'] = messageId;
    }
    _openNotification(payload, router);
  }

  /// Opens a tap that arrived before the session was ready.
  void flushPending() {
    final pending = _pendingOpen;
    if (pending == null) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    _pendingOpen = null;
    _openNotification(pending);
  }

  void _openNotification(Map<String, String> data, [GoRouter? router]) {
    if (data.isEmpty) return;
    final key = _payloadKey(data);
    if (_isDuplicate(key)) return;

    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated) {
      _pendingOpen = data;
      return;
    }

    _handledPayloadKey = key;
    _handledPayloadAt = DateTime.now();
    _pendingOpen = null;

    final GoRouter destination = router ?? _ref.read(routerProvider);
    final path = destination.state.uri.path;
    final waitingForSession = path == AppRoutes.splash ||
        path == AppRoutes.phone ||
        path == AppRoutes.otp;
    final location = _locationFor(data);
    if (location == null) return;

    _prepareTarget(data);
    if (waitingForSession) {
      _ref.read(pendingDeepLinkProvider.notifier).state = location;
      _ref.read(routerRefreshProvider).refresh();
      return;
    }

    switch (data['type']) {
      case 'cart':
        destination.go(location);
      case 'order':
      case 'project':
      case 'document':
        destination.push(location);
      default:
        _openChat(data['chatId'], data['title']);
    }
  }

  void _prepareTarget(Map<String, String> data) {
    switch (data['type']) {
      case 'cart':
        unawaited(_ref.read(cartProvider.notifier).loadCart());
      case 'order':
        _ref.invalidate(ordersProvider);
        _ref.invalidate(orderDetailProvider);
      case 'document':
      case 'project':
        _ref.invalidate(projectsListProvider);
        _ref.invalidate(projectDetailProvider);
        _ref.invalidate(projectDocumentsProvider);
      default:
        break;
    }
  }

  String? _locationFor(Map<String, String> data) {
    final type = (data['type'] ?? '').isEmpty &&
            (data['chatId'] ?? '').isNotEmpty
        ? 'chat'
        : data['type'];
    switch (type) {
      case 'chat':
        final chatId = data['chatId'];
        if (chatId == null || chatId.isEmpty) return null;
        final title = data['title']?.trim() ?? '';
        if (title.isEmpty) return AppRoutes.chatDetail(chatId);
        return '${AppRoutes.chatDetail(chatId)}?title=${Uri.encodeComponent(title)}';
      case 'order':
        final orderId = data['orderId'];
        if (orderId == null || orderId.isEmpty) return null;
        return AppRoutes.orderDetail(orderId);
      case 'cart':
        return AppRoutes.cart;
      case 'document':
        final documentId = data['documentId'];
        final projectId = data['projectId'];
        if (projectId != null && projectId.isNotEmpty) {
          return AppRoutes.projectDetail(projectId);
        }
        if (documentId != null && documentId.isNotEmpty) {
          return AppRoutes.documentViewer(documentId);
        }
        return null;
      case 'project':
        final projectId = data['projectId'];
        if (projectId == null || projectId.isEmpty) return null;
        return AppRoutes.projectDetail(projectId);
      default:
        final chatId = data['chatId'];
        if (chatId == null || chatId.isEmpty) return null;
        return AppRoutes.chatDetail(chatId);
    }
  }

  bool _isDuplicate(String key) {
    if (key.isEmpty || key != _handledPayloadKey) return false;
    final at = _handledPayloadAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < const Duration(seconds: 5);
  }

  String _payloadKey(Map<String, String> data) {
    final messageId = data['messageId'] ?? data['google.message_id'] ?? '';
    if (messageId.isNotEmpty) return messageId;
    return [
      data['type'] ?? '',
      data['chatId'] ?? '',
      data['orderId'] ?? '',
      data['projectId'] ?? '',
      data['documentId'] ?? '',
    ].join('|');
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
  }
}
