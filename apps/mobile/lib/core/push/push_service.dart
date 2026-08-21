import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
  StreamSubscription<String>? _tokenRefreshSub;
  var _firebaseReady = false;

  Future<bool> bootstrap() async {
    if (kIsWeb) return false;
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

    if (!_firebaseReady) {
      await _registerDevToken(authState.user!.id);
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final token = await messaging.getToken();
    if (token != null) {
      await _sendToken(token);
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = messaging.onTokenRefresh.listen(_sendToken);
  }

  Future<void> _registerDevToken(String userId) async {
    final token =
        'davart-$userId-${Platform.operatingSystem}-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _sendToken(token);
    } catch (_) {}
  }

  Future<void> _sendToken(String token) async {
    try {
      await _ref.read(profileRepositoryProvider).registerFcmToken(
            token: token,
            platform: Platform.operatingSystem,
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
