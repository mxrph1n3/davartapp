import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected unlocked cart line IDs for partial checkout.
final cartSelectionProvider = StateProvider<Set<String>>((ref) => {});
