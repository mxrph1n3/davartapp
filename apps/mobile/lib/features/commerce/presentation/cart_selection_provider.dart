import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected unlocked cart line ids.
/// Scope is `personal`, `project:$projectId`, or `staff:$projectId`.
final cartSelectionProvider =
    StateProvider.family<Set<String>, String>((ref, scope) => {});
