import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/push/push_service.dart';
import '../../chat/data/chat_socket_service.dart';
import '../../commerce/presentation/active_project_provider.dart';
import '../../profile/data/profile_repository.dart' as profile;
import '../../staff/presentation/working_client_provider.dart';
import '../data/auth_repository.dart';
import '../data/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.authenticated(UserProfile user)
      : this(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated({String? errorMessage})
      : this(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.unknown;
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.listen<int>(sessionExpiredTickProvider, (previous, next) {
      if (previous == next) return;
      markUnauthenticated();
    });
    return const AuthState.unknown();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);
  TokenStorage get _tokenStorage => ref.read(tokenStorageProvider);

  Future<void> restoreSession() async {
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (refreshToken == null) {
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final user = await _repository.getMe();
      state = AuthState.authenticated(user);
    } on DioException catch (error) {
      // Always try refresh when /me fails; clear tokens only on confirmed 401.
      try {
        final tokens = await _repository.refresh(refreshToken);
        await _tokenStorage.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        final user = await _repository.getMe();
        state = AuthState.authenticated(user);
      } on DioException catch (refreshError) {
        if (refreshError.response?.statusCode == 401 ||
            error.response?.statusCode == 401) {
          await _tokenStorage.clear();
        }
        // Network/5xx: keep tokens so the next online request can restore.
        state = const AuthState.unauthenticated();
      } catch (_) {
        if (error.response?.statusCode == 401) {
          await _tokenStorage.clear();
        }
        state = const AuthState.unauthenticated();
      }
    } catch (_) {
      // Keep tokens; splash can proceed as guest until next retry.
      state = const AuthState.unauthenticated();
    }
  }

  void updateUserProfile(profile.UserProfile profile) {
    if (!state.isAuthenticated) return;
    final current = state.user;
    state = AuthState.authenticated(
      UserProfile(
        id: profile.id,
        phone: profile.phone,
        name: profile.name,
        role: profile.role,
        extraRoles:
            profile.extraRoles.isNotEmpty
                ? profile.extraRoles
                : (current?.extraRoles ?? const []),
      ),
    );
  }

  Future<String?> sendOtp(String phone, {String channel = 'sms'}) async {
    try {
      return await _repository.sendOtp(phone, channel: channel);
    } on DioException catch (error) {
      throw Exception(_extractError(error));
    }
  }

  Future<void> verifyOtp({
    required String phone,
    required String code,
  }) async {
    try {
      final tokens = await _repository.verifyOtp(phone: phone, code: code);
      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      // Authenticate immediately so OTP can dismiss before /me finishes.
      final fallback = tokens.user ?? UserProfile(id: 'session', phone: phone);
      state = AuthState.authenticated(fallback);
      unawaited(
        ref.read(chatSocketServiceProvider).connect(force: true),
      );
      unawaited(ref.read(pushServiceProvider).initialize());

      try {
        final me = await _repository.getMe().timeout(const Duration(seconds: 12));
        if (state.isAuthenticated) {
          state = AuthState.authenticated(me);
        }
      } catch (_) {
        // Keep tokens.user / fallback — session is already usable.
      }
    } on DioException catch (error) {
      final message = _extractError(error);
      // A duplicate verify (auto-submit + button) must not wipe a just-issued session.
      if (!state.isAuthenticated) {
        state = AuthState.unauthenticated(errorMessage: message);
      }
      throw Exception(message);
    }
  }

  Future<void> signOut() async {
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (refreshToken != null) {
      try {
        await _repository.logout(refreshToken);
      } catch (_) {
        // Ignore logout API errors
      }
    }

    await _tokenStorage.clear();
    ref.read(chatSocketServiceProvider).disconnect();
    ref.read(workingClientProvider.notifier).state = null;
    ref.read(activeProjectProvider.notifier).state = null;
    state = const AuthState.unauthenticated();
  }

  /// Clears local auth without calling logout API (used by Dio 401 handler).
  void markUnauthenticated() {
    if (state.status == AuthStatus.unauthenticated) return;
    ref.read(chatSocketServiceProvider).disconnect();
    ref.read(workingClientProvider.notifier).state = null;
    ref.read(activeProjectProvider.notifier).state = null;
    state = const AuthState.unauthenticated();
  }

  String _extractError(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? apiMessage;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        apiMessage = message.trim();
      } else if (message is List && message.isNotEmpty) {
        apiMessage = message.map((e) => e.toString()).join(', ');
      }
    } else if (data is String && data.trim().isNotEmpty) {
      apiMessage = data.trim();
    }

    if (status == 429) {
      return 'Слишком много запросов кода. Подождите несколько минут.';
    }
    // Prefer provider/backend text over a generic 503 (e.g. TargetSMS sender error).
    if (apiMessage != null && apiMessage.isNotEmpty) {
      return apiMessage;
    }
    if (status == 503) {
      return 'Сервис временно недоступен. Попробуйте позже.';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Сервер не отвечает. Проверьте интернет.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Нет связи с сервером.';
    }

    return 'Не удалось выполнить запрос';
  }
}

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();
  ref.listen(authProvider, (previous, next) {
    if (next.status != previous?.status ||
        next.user?.role != previous?.user?.role) {
      notifier.refresh();
    }
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
