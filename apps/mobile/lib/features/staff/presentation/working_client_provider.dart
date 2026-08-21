import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active client whose cart the staff member is editing.
class WorkingClient {
  const WorkingClient({
    required this.id,
    required this.displayName,
    required this.phone,
  });

  final String id;
  final String displayName;
  final String phone;
}

final workingClientProvider =
    StateProvider<WorkingClient?>((ref) => null);
