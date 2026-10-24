import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds/ds.dart';
import 'phone_book.dart';

/// «+7XXXXXXXXXX» from any Russian number in the address book; null if it is not one.
String? normalizeRuPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && (digits.startsWith('8') || digits.startsWith('7'))) {
    digits = digits.substring(1);
  }
  if (digits.length != 10) return null;
  return '+7$digits';
}

/// Lets the person pick someone from the phone's contacts; returns name and number.
Future<({String name, String phone})?> pickPhoneContact(BuildContext context) {
  return showModalBottomSheet<({String name, String phone})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _PhoneContactSheet(),
  );
}

class _PhoneContactSheet extends StatefulWidget {
  const _PhoneContactSheet();

  @override
  State<_PhoneContactSheet> createState() => _PhoneContactSheetState();
}

class _PhoneContactSheetState extends State<_PhoneContactSheet> {
  late final Future<PhoneBookPage> _book = PhoneBook.load();
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FutureBuilder<PhoneBookPage>(
      future: _book,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
        }
        final page = snap.data;
        if (page == null || !page.granted) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Нет доступа к контактам', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'Разрешите доступ в настройках телефона или введите номер вручную.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  SecondaryButton(label: 'Открыть настройки', onPressed: PhoneBook.openSettings),
                ],
              ),
            ),
          );
        }
        final q = _query.toLowerCase();
        final rows = <({String name, String phone})>[
          for (final e in page.entries)
            for (final raw in e.phones)
              if (normalizeRuPhone(raw) case final phone?)
                (name: e.name.trim().isEmpty ? phone : e.name.trim(), phone: phone),
        ]
            .where((r) => q.isEmpty || r.name.toLowerCase().contains(q) || r.phone.contains(q.replaceAll(' ', '')))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Поиск по контактам', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: rows.isEmpty
                      ? Center(child: Text('Никого не нашлось', style: TextStyle(color: colors.textSecondary)))
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (_, i) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: AppAvatar(label: rows[i].name, size: 40),
                            title: Text(rows[i].name),
                            subtitle: Text(rows[i].phone),
                            onTap: () => Navigator.pop(context, rows[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
