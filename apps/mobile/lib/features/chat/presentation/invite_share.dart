import 'package:url_launcher/url_launcher.dart';

const kDavartInviteAppUrl = 'https://davart.ru/app';

String davartChatInviteMessage() =>
    'Привет! Присоединяйся ко мне в DAVart — чат и проекты по дизайну интерьера. '
    'Скачать приложение: $kDavartInviteAppUrl';

/// Opens the system Messages / SMS composer with a prefilled invite (TG/WA style).
Future<bool> openDavartInviteSms({String? phone}) async {
  final body = Uri.encodeComponent(davartChatInviteMessage());
  final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
  final path = digits.isEmpty ? '' : digits;
  final uri = Uri.parse('sms:$path?body=$body');
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
  }
  // iOS sometimes prefers &body=
  final fallback = Uri.parse('sms:$path&body=$body');
  if (await canLaunchUrl(fallback)) {
    return launchUrl(fallback);
  }
  return false;
}
