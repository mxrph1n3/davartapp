import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

String? locationFromDeepLink(Uri uri) {
  final path = _normalizedPath(uri);
  if (path == null) return null;

  final segments = path.split('/').where((part) => part.isNotEmpty).toList();

  // Generic in-app navigation: davart://go/chat → /chat (for QA / store screenshots).
  if (segments.length >= 2 && segments[0] == 'go') {
    final rest = segments.skip(1).join('/');
    return rest.startsWith('/') ? rest : '/$rest';
  }

  if (segments.length >= 4 &&
      segments[0] == 'open' &&
      segments[1] == 'orders') {
    return '/staff/clients/${segments[2]}/orders/${segments[3]}';
  }

  if (segments.length >= 5 &&
      segments[0] == 'api' &&
      segments[1] == 'open' &&
      segments[2] == 'orders') {
    return '/staff/clients/${segments[3]}/orders/${segments[4]}';
  }

  if (segments.length >= 5 &&
      segments[0] == 'staff' &&
      segments[1] == 'clients' &&
      segments[3] == 'orders') {
    return '/staff/clients/${segments[2]}/orders/${segments[4]}';
  }

  if (path.startsWith('/staff/') || path.startsWith('/orders/')) {
    return path;
  }

  return null;
}

String? _normalizedPath(Uri uri) {
  if (uri.scheme == 'davart') {
    if (uri.host.isEmpty) {
      return uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    }
    return '/${uri.host}${uri.path}';
  }

  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return uri.path;
  }

  return null;
}
