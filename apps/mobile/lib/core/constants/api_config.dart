abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    return '${uri.scheme}://${uri.host}:$port';
  }
}
