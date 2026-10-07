import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/profile/data/profile_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(ref);
});

class PushService {
  PushService(this._ref);

  final Ref _ref;
  static const _iosChannel = MethodChannel('davart/push');

  StreamSubscription<String>? _tokenRefreshSub;
  var _firebaseReady = false;
  var _iosBound = false;
  String? _apnsToken;

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
      return;
    }

    if (!_firebaseReady) {
      await _registerDevToken(authState.user!.id);
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
  }

  /// System banner that slides down on the iPhone, including while the app is open.
  Future<void> showChatBanner({
    required String messageId,
    required String title,
    required String body,
    required String chatId,
  }) async {
    if (kIsWeb || !Platform.isIOS) return;
    _bindIosChannel();
    try {
      await _iosChannel.invokeMethod<void>('show', {
        'messageId': messageId,
        'title': title,
        'body': body,
        'chatId': chatId,
      });
    } catch (error) {
      debugPrint('iOS banner failed: $error');
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
          final args = _stringMap(call.arguments);
          _openChat(args['chatId'], args['title']);
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
      final args = _stringMap(pending);
      _openChat(args['chatId'], args['title']);
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
      _ref.read(routerProvider).push(
            '${AppRoutes.chatDetail(chatId)}?title=${Uri.encodeComponent(label)}',
          );
    } catch (_) {}
  }

  Future<void> _registerDevToken(String userId) async {
    final token =
        'davart-$userId-${Platform.operatingSystem}-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _sendToken(token);
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

  void handleNotificationData(GoRouter router, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'chat':
        final chatId = data['chatId'] as String?;
        if (chatId != null) {
          router.push(
            '${AppRoutes.chatDetail(chatId)}?title=${Uri.encodeComponent('Чат')}',
          );
        }
      case 'order':
        final orderId = data['orderId'] as String?;
        if (orderId != null) {
          router.push(AppRoutes.orderDetail(orderId));
        }
      case 'document':
        final projectId = data['projectId'] as String?;
        if (projectId != null) {
          router.push(AppRoutes.projectDetail(projectId));
        }
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
  }
}
