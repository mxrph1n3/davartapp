import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/brief_questionnaire.dart';
import '../data/projects_models.dart';

bool briefHasFilledContent(Brief brief) {
  final answers = brief.answers;
  for (final field in briefGeneralFields) {
    if (_filled(field.id, answers.general[field.id])) return true;
  }
  for (final section in briefRoomSections) {
    final room = answers.rooms[section.id];
    if (room == null || room.included == false) continue;
    for (final field in section.fields) {
      if ((room.fields[field.id] ?? '').trim().isNotEmpty) return true;
    }
  }
  return brief.rooms.any((room) => room.name.trim().isNotEmpty);
}

bool _filled(String fieldId, String? raw) {
  return briefDisplayValue(fieldId, raw).trim().isNotEmpty;
}

class BriefAnswersView extends StatelessWidget {
  const BriefAnswersView({super.key, required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answers = brief.answers;

    final generalItems = <Widget>[
      for (final field in briefGeneralFields)
        if (field.id != 'householdMembers')
          if (_filled(field.id, answers.general[field.id]))
          if (field.id == 'likedColors')
            _ColorAnswer(label: field.label, raw: answers.general[field.id])
          else
            _Answer(
              label: field.label,
              value: briefDisplayValue(field.id, answers.general[field.id]),
            ),
    ];

    final roomItems = <Widget>[
      for (final section in briefRoomSections)
        ..._roomBlock(theme, answers, section),
    ];

    final extraRooms = brief.rooms
        .where((room) => room.name.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (generalItems.isNotEmpty) ...[
          Text('Общие вопросы', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ...generalItems,
        ],
        if (roomItems.isNotEmpty) ...[
          if (generalItems.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          Text('Пожелания к помещениям', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ...roomItems,
        ],
        if (extraRooms.isNotEmpty) ...[
          Text('Другие помещения', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            extraRooms
                .map((room) => [
                      room.name,
                      if (room.type != null) room.type,
                      if (room.area != null) '${room.area} м²',
                    ].join(', '))
                .join('\n'),
          ),
        ],
      ],
    );
  }

  List<Widget> _roomBlock(
    ThemeData theme,
    BriefAnswers answers,
    BriefRoomSection section,
  ) {
    final room = answers.rooms[section.id];
    if (room == null || room.included == false) return const [];

    final fields = [
      for (final field in section.fields)
        if ((room.fields[field.id] ?? '').trim().isNotEmpty)
          _Answer(label: field.label, value: room.fields[field.id]),
    ];
    if (fields.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...fields,
          ],
        ),
      ),
    ];
  }
}

class _ColorAnswer extends StatelessWidget {
  const _ColorAnswer({required this.label, this.raw});

  final String label;
  final String? raw;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ids = briefSelectedIds(raw);
    final swatches = [
      for (final id in ids)
        ...briefColorSwatches.where((item) => item.id == id),
    ];
    final fallback = briefDisplayValue('likedColors', raw);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (swatches.isEmpty)
            Text(fallback, style: Theme.of(context).textTheme.bodyLarge)
          else
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final swatch in swatches)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Color(swatch.hex),
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.border),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        swatch.label,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value!.trim(), style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
