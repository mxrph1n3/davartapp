import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class PhoneBookEntry {
  const PhoneBookEntry({required this.name, required this.phones});

  final String name;
  final List<String> phones;
}

class PhoneBookPage {
  const PhoneBookPage({
    required this.granted,
    required this.entries,
    this.prompted = true,
  });

  final bool granted;
  final bool prompted;
  final List<PhoneBookEntry> entries;
}

class PhoneBook {
  static const _channel = MethodChannel('davart/contacts');

  /// Asks for the address book and returns it. On iOS the system prompt is
  /// raised from the app itself, on the main thread.
  static Future<PhoneBookPage> load() async {
    if (Platform.isIOS) {
      final raw = await _channel.invokeMapMethod<String, dynamic>('load');
      final granted = raw?['granted'] == true;
      final prompted = raw?['prompted'] != false;
      final items = raw?['contacts'];
      final entries = <PhoneBookEntry>[];
      if (items is List) {
        for (final item in items) {
          if (item is! Map) continue;
          final name = item['name']?.toString() ?? '';
          final phonesRaw = item['phones'];
          final phones = phonesRaw is List
              ? [for (final phone in phonesRaw) phone.toString()]
              : const <String>[];
          entries.add(PhoneBookEntry(name: name, phones: phones));
        }
      }
      return PhoneBookPage(
        granted: granted,
        prompted: prompted,
        entries: entries,
      );
    }

    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      return const PhoneBookPage(granted: false, entries: []);
    }
    final raw = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    return PhoneBookPage(
      granted: true,
      entries: [
        for (final contact in raw)
          PhoneBookEntry(
            name: contact.displayName ?? '',
            phones: [for (final phone in contact.phones) phone.number],
          ),
      ],
    );
  }

  static Future<bool> openSettings() async {
    if (!Platform.isIOS) return false;
    final opened = await _channel.invokeMethod<bool>('openSettings');
    return opened ?? false;
  }
}
