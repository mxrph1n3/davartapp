import 'package:flutter/services.dart';

/// Keeps Russian `+7` prefix and up to 10 digits after it.
class RuPhoneInputFormatter extends TextInputFormatter {
  const RuPhoneInputFormatter();

  static const prefix = '+7';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (!text.startsWith(prefix)) {
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith('8') && digits.isNotEmpty) {
        text = '$prefix${digits.substring(1)}';
      } else if (digits.startsWith('7')) {
        text = '$prefix${digits.substring(1)}';
      } else {
        text = '$prefix$digits';
      }
    }

    final rest = text.substring(prefix.length).replaceAll(RegExp(r'\D'), '');
    final clipped = rest.length > 10 ? rest.substring(0, 10) : rest;
    final next = '$prefix$clipped';
    return TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}
