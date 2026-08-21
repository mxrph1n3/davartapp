import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/brief_questionnaire.dart';

class BriefChipWrap extends StatelessWidget {
  const BriefChipWrap({
    super.key,
    required this.choices,
    required this.selectedIds,
    required this.onToggle,
    this.enabled = true,
  });

  final List<BriefChoice> choices;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in choices)
          _BriefChip(
            label: choice.label,
            selected: selectedIds.contains(choice.id),
            onTap: enabled ? () => onToggle(choice.id) : null,
          ),
      ],
    );
  }
}

class _BriefChip extends StatelessWidget {
  const _BriefChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: selected ? AppColors.accent : AppColors.surfaceMuted,
        foregroundColor: AppColors.textPrimary,
        disabledBackgroundColor: AppColors.surfaceMuted,
        disabledForegroundColor: AppColors.textDisabled,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(48, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: AppColors.textPrimary,
        ),
      ),
      child: Text(label),
    );
  }
}

class BriefPalettePicker extends StatelessWidget {
  const BriefPalettePicker({
    super.key,
    required this.selectedIds,
    required this.onToggle,
    this.maxSelected = 4,
    this.enabled = true,
  });

  final List<String> selectedIds;
  final ValueChanged<String> onToggle;
  final int maxSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите 2–$maxSelected оттенка',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
          children: [
            for (final swatch in briefColorSwatches)
              _SwatchTile(
                swatch: swatch,
                selected: selectedIds.contains(swatch.id),
                onTap: enabled ? () => onToggle(swatch.id) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final BriefColorSwatch swatch;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(swatch.hex);
    final isLight = color.computeLuminance() > 0.72;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
        children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? AppColors.textPrimary
                    : (isLight ? AppColors.border : Colors.transparent),
                width: selected ? 3 : 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x1A111111),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: 22,
                    color: isLight ? AppColors.textPrimary : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            swatch.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.2,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
        ],
        ),
      ),
    );
  }
}

class BriefImageChoiceGrid extends StatelessWidget {
  const BriefImageChoiceGrid({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onToggle,
    this.enabled = true,
  });

  final List<BriefVisualOption> options;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final option in options)
              SizedBox(
                width: width,
                child: _ImageChoiceCard(
                  option: option,
                  selected: selectedIds.contains(option.id),
                  onTap: enabled ? () => onToggle(option.id) : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ImageChoiceCard extends StatelessWidget {
  const _ImageChoiceCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final BriefVisualOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(option.asset, fit: BoxFit.cover),
                    if (selected)
                      const Positioned(
                        top: 10,
                        right: 10,
                        child: _SelectedBadge(),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Text(
                  option.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 16, color: AppColors.textPrimary),
    );
  }
}

class BriefCoverImage extends StatelessWidget {
  const BriefCoverImage({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.imageRadius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(asset, fit: BoxFit.cover),
      ),
    );
  }
}

class BriefStepHeader extends StatelessWidget {
  const BriefStepHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                letterSpacing: 0.4,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 6),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}
