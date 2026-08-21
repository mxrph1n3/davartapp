import 'package:intl/intl.dart';

/// Premium price display: `82 000 ₽` (no decimals).
String formatPrice(double value) {
  if (value <= 0) return 'по запросу';
  final rounded = value.round();
  final formatted = NumberFormat('#,###', 'ru_RU').format(rounded).replaceAll(',', ' ');
  return '$formatted ₽';
}
