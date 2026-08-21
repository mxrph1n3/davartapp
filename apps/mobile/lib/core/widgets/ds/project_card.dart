import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import 'status_badge.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.name,
    required this.statusLabel,
    this.status,
    this.address,
    this.updatedAt,
    this.coverUrl,
    required this.onTap,
    this.compact = false,
  });

  final String name;
  final String statusLabel;
  final String? status;
  final String? address;
  final DateTime? updatedAt;
  final String? coverUrl;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactProjectCard(
        name: name,
        statusLabel: statusLabel,
        status: status,
        subtitle: address,
        coverUrl: coverUrl,
        onTap: onTap,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          boxShadow: AppShadows.card,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _cover(coverUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: statusLabel,
                        highlighted: isActiveProjectStatus(statusLabel),
                      ),
                    ],
                  ),
                  if (address != null) ...[
                    const SizedBox(height: 6),
                    Text(address!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(String? url) {
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: AppColors.imagePlaceholder,
          child: Center(
            child: Icon(
              Icons.apartment_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    return const ColoredBox(
      color: AppColors.imagePlaceholder,
      child: Center(
        child: Icon(
          Icons.apartment_outlined,
          size: 40,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CompactProjectCard extends StatelessWidget {
  const _CompactProjectCard({
    required this.name,
    required this.statusLabel,
    required this.onTap,
    this.status,
    this.subtitle,
    this.coverUrl,
  });

  final String name;
  final String statusLabel;
  final String? status;
  final String? subtitle;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = projectStatusColor(status ?? statusLabel);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 88,
                height: 88,
                child: coverUrl != null
                    ? Image.network(
                        coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.imagePlaceholder,
                          child: Icon(Icons.apartment_outlined, size: 28),
                        ),
                      )
                    : const ColoredBox(
                        color: AppColors.imagePlaceholder,
                        child: Icon(Icons.apartment_outlined, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
