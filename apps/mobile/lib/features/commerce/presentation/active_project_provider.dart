import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active project whose cart is being edited (client or staff).
class ActiveProject {
  const ActiveProject({
    required this.id,
    required this.name,
    this.ownerClientId,
  });

  final String id;
  final String name;
  /// For staff flows — primary client of the project.
  final String? ownerClientId;
}

final activeProjectProvider =
    StateProvider<ActiveProject?>((ref) => null);
