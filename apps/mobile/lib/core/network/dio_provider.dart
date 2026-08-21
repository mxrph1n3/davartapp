import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_config.dart';
import '../../features/auth/data/token_storage.dart';

/// Bumped when access/refresh fails so [AuthNotifier] can mark user logged out.
final sessionExpiredTickProvider = StateProvider<int>((ref) => 0);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<void>? refreshInFlight;

  Future<void> invalidateSession() async {
    await ref.read(tokenStorageProvider).clear();
    ref.read(sessionExpiredTickProvider.notifier).state++;
  }

  Future<String?> refreshAccessToken() async {
    if (refreshInFlight != null) {
      await refreshInFlight;
      return ref.read(tokenStorageProvider).getAccessToken();
    }

    final completer = Completer<void>();
    refreshInFlight = completer.future;

    try {
      final tokenStorage = ref.read(tokenStorageProvider);
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        await invalidateSession();
        return null;
      }

      final response = await Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
          .post('/auth/refresh', data: {'refreshToken': refreshToken});

      final newAccess = response.data['accessToken'] as String;
      final newRefresh = response.data['refreshToken'] as String;

      await tokenStorage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return newAccess;
    } catch (_) {
      await invalidateSession();
      return null;
    } finally {
      completer.complete();
      refreshInFlight = null;
    }
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final tokenStorage = ref.read(tokenStorageProvider);
        final accessToken = await tokenStorage.getAccessToken();

        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode != 401) {
          handler.next(error);
          return;
        }

        final path = error.requestOptions.path;
        if (path.contains('/auth/refresh') ||
            path.contains('/auth/send-otp') ||
            path.contains('/auth/verify-otp') ||
            path.contains('/auth/logout')) {
          handler.next(error);
          return;
        }

        final newAccess = await refreshAccessToken();
        if (newAccess == null) {
          handler.next(error);
          return;
        }

        try {
          final requestOptions = error.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retryResponse = await dio.fetch(requestOptions);
          handler.resolve(retryResponse);
        } catch (retryError) {
          handler.next(retryError is DioException ? retryError : error);
        }
      },
    ),
  );

  return dio;
});
