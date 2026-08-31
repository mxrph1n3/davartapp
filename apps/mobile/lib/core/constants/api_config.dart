/// API / socket endpoints for the mobile app.
///
/// Teammates install on a phone via Xcode without any local `.env`.
/// Default is the staging VPS. Override when needed:
///   `--dart-define=API_BASE_URL=http://localhost:3000/api`
///   or `apps/mobile/dart_defines.device.json` via `scripts/run-ios-device.sh`
abstract final class ApiConfig {
  static const _fromEnvironment = String.fromEnvironment('API_BASE_URL');

  /// Staging VPS used when no dart-define is passed (Xcode Product → Run).
  static const stagingBaseUrl = 'http://217.198.6.88:3000/api';

  static String get baseUrl {
    if (_fromEnvironment.isNotEmpty) return _fromEnvironment;
    return stagingBaseUrl;
  }

  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    return '${uri.scheme}://${uri.host}:$port';
  }
}
