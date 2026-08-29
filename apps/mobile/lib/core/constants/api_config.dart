import 'dart:io' show Platform;

abstract final class ApiConfig {
  static const _fromEnvironment = String.fromEnvironment('API_BASE_URL');

  /// Override with `--dart-define=API_BASE_URL=http://…`.
  /// Android emulator defaults to `10.0.2.2` (host loopback).
  static String get baseUrl {
    if (_fromEnvironment.isNotEmpty) return _fromEnvironment;
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }

  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    return '${uri.scheme}://${uri.host}:$port';
  }
}
