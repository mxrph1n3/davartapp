/// First character for avatar display (handles phones and names).
String avatarInitial(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return '?';

  if (trimmed.startsWith('+') || RegExp(r'^\d').hasMatch(trimmed)) {
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) {
      return digits.substring(digits.length - 2);
    }
    return digits.isNotEmpty ? digits : '?';
  }

  return trimmed[0].toUpperCase();
}
