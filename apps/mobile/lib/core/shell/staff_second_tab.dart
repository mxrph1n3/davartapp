import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/staff/presentation/staff_clients_screen.dart';
import '../../features/staff/presentation/staff_designer_projects_screen.dart';

class StaffSecondTab extends ConsumerWidget {
  const StaffSecondTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeeClients =
        ref.watch(authProvider).user?.canSeeClients ?? false;
    if (canSeeClients) return const StaffClientsScreen();
    return const StaffDesignerProjectsScreen();
  }
}
