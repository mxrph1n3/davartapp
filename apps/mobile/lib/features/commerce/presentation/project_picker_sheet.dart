import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../projects/data/projects_models.dart';
import '../../projects/data/projects_repository.dart';
import '../../staff/data/staff_repository.dart';
import 'active_project_provider.dart';

/// Returns selected [ActiveProject], or null if dismissed.
Future<ActiveProject?> showProjectPickerSheet(
  BuildContext context,
  WidgetRef ref, {
  String? title,
  String? staffClientId,
}) {
  return showModalBottomSheet<ActiveProject>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ProjectPickerSheet(
      title: title ?? 'Выберите проект',
      staffClientId: staffClientId,
    ),
  );
}

/// Ensures an active project is set. Shows picker when needed.
/// Returns projectId or null if cancelled / no projects.
/// When [silent] is true, never shows the picker — reuses current or first project.
Future<String?> ensureActiveProject(
  BuildContext context,
  WidgetRef ref, {
  String? staffClientId,
  bool forcePicker = false,
  bool silent = false,
}) async {
  final current = ref.read(activeProjectProvider);
  if (!forcePicker && current != null) {
    if (staffClientId == null || current.ownerClientId == staffClientId) {
      return current.id;
    }
  }

  var projects = await _loadProjects(ref, staffClientId: staffClientId);
  if (projects.isEmpty) {
    try {
      final created = staffClientId != null
          ? await ref.read(staffRepositoryProvider).createProject(staffClientId)
          : await ref.read(projectsRepositoryProvider).createProject();
      projects = [created];
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось создать проект для корзины'),
          ),
        );
      }
      return null;
    }
  }

  if (!forcePicker && (silent || projects.length == 1)) {
    final p = projects.first;
    final active = ActiveProject(
      id: p.id,
      name: p.name,
      ownerClientId: staffClientId,
    );
    ref.read(activeProjectProvider.notifier).state = active;
    return active.id;
  }

  if (!context.mounted) return null;
  final picked = await showProjectPickerSheet(
    context,
    ref,
    staffClientId: staffClientId,
  );
  if (picked == null) return null;
  ref.read(activeProjectProvider.notifier).state = picked;
  return picked.id;
}

Future<List<Project>> _loadProjects(
  WidgetRef ref, {
  String? staffClientId,
}) async {
  if (staffClientId != null) {
    return ref.read(staffRepositoryProvider).getProjects(staffClientId);
  }
  return ref.read(projectsRepositoryProvider).getProjects();
}

class _ProjectPickerSheet extends ConsumerStatefulWidget {
  const _ProjectPickerSheet({
    required this.title,
    this.staffClientId,
  });

  final String title;
  final String? staffClientId;

  @override
  ConsumerState<_ProjectPickerSheet> createState() =>
      _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends ConsumerState<_ProjectPickerSheet> {
  late Future<List<Project>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadProjects(ref, staffClientId: widget.staffClientId);
  }

  @override
  Widget build(BuildContext context) {
    final activeId = ref.watch(activeProjectProvider)?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          0,
          AppSpacing.screenPadding,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<Project>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Не удалось загрузить проекты'),
                  );
                }
                final projects = snapshot.data ?? const [];
                if (projects.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Нет проектов'),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: projects.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final selected = project.id == activeId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(project.name),
                        subtitle: project.address != null
                            ? Text(project.address!)
                            : null,
                        trailing: selected
                            ? Icon(Icons.check, color: AppColors.of(context).accent)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop(
                            ActiveProject(
                              id: project.id,
                              name: project.name,
                              ownerClientId: widget.staffClientId,
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
