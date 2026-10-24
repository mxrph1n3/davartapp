import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

const kDavartInviteAppUrl = 'https://davart.ru/app';

String davartChatInviteMessage() =>
    'Привет! Присоединяйся ко мне в DAVart — чат и проекты по дизайну интерьера. '
    'Скачать приложение: $kDavartInviteAppUrl';

/// Opens the system Messages composer with the download link already filled in.
/// The person still taps Send — iOS and Android do not send SMS from the app.
Future<bool> openDavartInviteSms({String? phone}) async {
  final body = Uri.encodeComponent(davartChatInviteMessage());
  final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
  final uris = Platform.isIOS
      ? [
          Uri.parse('sms:$digits&body=$body'),
          Uri.parse('sms:$digits?body=$body'),
        ]
      : [
          Uri.parse('sms:$digits?body=$body'),
          Uri.parse('sms:$digits&body=$body'),
        ];
  for (final uri in uris) {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return true;
    } catch (_) {}
  }
  return false;
}

Future<bool> openDavartSystemSettings() async {
  if (!Platform.isIOS) return false;
  try {
    return await launchUrl(
      Uri.parse('app-settings:'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
