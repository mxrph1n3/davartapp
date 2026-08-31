import 'package:flutter/cupertino.dart';
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
    this.onMorePressed,
  });

  final String name;
  final String statusLabel;
  final String? status;
  final String? address;
  final DateTime? updatedAt;
  final String? coverUrl;
  final VoidCallback onTap;
  final bool compact;
  final VoidCallback? onMorePressed;

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
        onMorePressed: onMorePressed,
      );
    }

    final colors = AppColors.of(context);
    final brightness = Theme.of(context).brightness;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardRadius,
          boxShadow: AppShadows.cardFor(brightness),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _cover(coverUrl, colors),
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
                    Text(
                      address!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(String? url, DavartColors colors) {
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(
          color: colors.imagePlaceholder,
          child: Center(
            child: Icon(
              Icons.apartment_outlined,
              size: 40,
              color: colors.textSecondary,
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: colors.imagePlaceholder,
      child: Center(
        child: Icon(
          Icons.apartment_outlined,
          size: 40,
          color: colors.textSecondary,
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
    this.onMorePressed,
  });

  final String name;
  final String statusLabel;
  final String? status;
  final String? subtitle;
  final String? coverUrl;
  final VoidCallback onTap;
  final VoidCallback? onMorePressed;

  bool get _canDelete =>
      status == 'brief_filling' || statusLabel == 'На паузе';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor =
        projectStatusColor(status ?? statusLabel, colors);

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
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: colors.imagePlaceholder,
                          child: Icon(
                            Icons.apartment_outlined,
                            size: 28,
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    : ColoredBox(
                        color: colors.imagePlaceholder,
                        child: Icon(
                          Icons.apartment_outlined,
                          size: 28,
                          color: colors.textSecondary,
                        ),
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
                  if (statusLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (onMorePressed != null && _canDelete)
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                minimumSize: Size.zero,
                onPressed: onMorePressed,
                child: Icon(
                  CupertinoIcons.ellipsis_circle,
                  size: 26,
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
