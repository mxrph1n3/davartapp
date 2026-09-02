import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../profile/presentation/profile_notifier.dart';
import '../data/brief_questionnaire.dart';
import '../data/projects_models.dart';
import 'brief_pickers.dart';
import 'projects_notifier.dart';
import 'surveyor_request.dart';

class BriefScreen extends ConsumerStatefulWidget {
  const BriefScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<BriefScreen> createState() => _BriefScreenState();
}

class _BriefStep {
  const _BriefStep({required this.id, required this.title, this.roomId});

  final String id;
  final String title;
  final String? roomId;
}

class _BriefScreenState extends ConsumerState<BriefScreen> {
  final _controllers = <String, TextEditingController>{};
  var _prefilled = false;
  var _hydrated = false;
  var _step = 0;

  TextEditingController _controller(String key, String text) {
    final existing = _controllers[key];
    if (existing == null) {
      final created = TextEditingController(text: text);
      _controllers[key] = created;
      return created;
    }
    return existing;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _hydrate(Brief brief) {
    if (!mounted) return;
    _sync(brief);
    _prefillContacts(brief);
  }

  void _sync(Brief brief) {
    if (_hydrated) return;
    _hydrated = true;
    ref.read(briefFormProvider(widget.projectId).notifier).loadFromBrief(brief);

    void write(String key, String value) {
      final controller = _controller(key, value);
      if (controller.text != value) controller.text = value;
    }

    for (final field in briefGeneralFields) {
      write('g.${field.id}', brief.answers.general[field.id] ?? '');
    }
    for (final section in briefRoomSections) {
      final room = brief.answers.rooms[section.id];
      for (final field in section.fields) {
        write('r.${section.id}.${field.id}', room?.fields[field.id] ?? '');
      }
    }
  }

  void _prefillContacts(Brief brief) {
    if (_prefilled) return;
    final general = brief.answers.general;
    final profile = ref.read(profileProvider).asData?.value;
    final project = ref.read(projectDetailProvider(widget.projectId)).asData?.value;
    if (profile == null) return;
    _prefilled = true;
    final notifier = ref.read(briefFormProvider(widget.projectId).notifier);
    if ((general['phone'] ?? '').trim().isEmpty) {
      notifier.setGeneral('phone', profile.phone);
      _controller('g.phone', profile.phone).text = profile.phone;
    }
    final email = profile.email?.trim() ?? '';
    if ((general['email'] ?? '').trim().isEmpty && email.isNotEmpty) {
      notifier.setGeneral('email', email);
      _controller('g.email', email).text = email;
    }
    final address = project?.address?.trim() ?? '';
    if ((general['address'] ?? '').trim().isEmpty && address.isNotEmpty) {
      notifier.setGeneral('address', address);
      _controller('g.address', address).text = address;
    }
    final members = briefParseFamilyMembers(general['householdMembers']);
    if (members.isEmpty) {
      notifier.setFamilyMembers([
        const BriefFamilyMember(role: 'self'),
      ]);
    }
  }

  bool _roomIncluded(BriefAnswers answers, String roomId) {
    if (answers.rooms.isEmpty) return false;
    return answers.rooms[roomId]?.included ?? true;
  }

  List<_BriefStep> _steps(BriefAnswers answers) {
    final objectType = answers.general['objectType'] ?? '';
    final isCommercial =
        objectType == 'office' || objectType == 'commercial';
    final rooms = briefRoomSections
        .where((section) => _roomIncluded(answers, section.id))
        .toList();
    return [
      const _BriefStep(id: 'object', title: 'Объект и адрес'),
      const _BriefStep(id: 'rooms', title: 'Какие комнаты есть?'),
      if (!isCommercial) const _BriefStep(id: 'family', title: 'Состав семьи'),
      if (!isCommercial)
        const _BriefStep(id: 'routine', title: 'Как проходит день?'),
      if (!isCommercial)
        const _BriefStep(id: 'hobbies', title: 'Чем увлекаетесь?'),
      if (!isCommercial)
        const _BriefStep(id: 'interests', title: 'Что должно быть дома?'),
      const _BriefStep(id: 'colors', title: 'Какие цвета близки?'),
      const _BriefStep(id: 'styles', title: 'Какой стиль откликается?'),
      const _BriefStep(id: 'disliked', title: 'Чего точно не хотите?'),
      const _BriefStep(id: 'budget', title: 'Какой бюджет?'),
      const _BriefStep(id: 'extras', title: 'Инженерные решения'),
      ...rooms.map(
        (section) => _BriefStep(
          id: 'room:${section.id}',
          title: section.title,
          roomId: section.id,
        ),
      ),
      const _BriefStep(id: 'finish', title: 'Ещё детали'),
    ];
  }

  void _syncZones(BriefFormNotifier notifier, BriefAnswers answers) {
    final zones = briefRoomSections
        .where((section) => _roomIncluded(answers, section.id))
        .map((section) {
          final count =
              int.tryParse(answers.rooms[section.id]?.fields['count'] ?? '1') ??
                  1;
          return count > 1 ? '${section.title} ×$count' : section.title;
        })
        .join(', ');
    notifier.setGeneral('zones', zones);
  }

  Future<void> _goNext({
    required List<_BriefStep> steps,
    required bool isLocked,
    required BriefFormNotifier notifier,
    required String fallback,
  }) async {
    final isLast = _step >= steps.length - 1;
    if (!isLast) {
      setState(() => _step += 1);
      if (!isLocked) {
        await notifier.save();
      }
      return;
    }

    if (!isLocked) {
      final success = await notifier.save();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Анкета сохранена'),
            duration: Duration(seconds: 1),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        popOrGo(context, fallback);
      }
      return;
    }

    popOrGo(context, fallback);
  }

  Future<void> _exitBrief(String fallback) async {
    final brief = ref.read(briefProvider(widget.projectId)).asData?.value;
    if (brief != null && !brief.isLocked) {
      await ref.read(briefFormProvider(widget.projectId).notifier).save();
    }
    if (!mounted) return;
    popOrGo(context, fallback);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final briefAsync = ref.watch(briefProvider(widget.projectId));
    final formState = ref.watch(briefFormProvider(widget.projectId));
    ref.watch(profileProvider);
    ref.watch(projectDetailProvider(widget.projectId));
    final fallback = AppRoutes.projectDetail(widget.projectId);

    ref.listen(briefProvider(widget.projectId), (previous, next) {
      next.whenData(_hydrate);
    });
    ref.listen(profileProvider, (previous, next) {
      final brief = ref.read(briefProvider(widget.projectId)).asData?.value;
      if (brief != null) _prefillContacts(brief);
    });

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Закрыть анкету',
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => _exitBrief(fallback),
        ),
        title: const Text('Анкета'),
        actions: [
          TextButton(
            onPressed: () => requestSurveyorConfirm(
              context,
              ref,
              widget.projectId,
            ),
            child: const Text('Вызов замерщика'),
          ),
        ],
      ),
      body: briefAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Не удалось загрузить анкету')),
        data: (brief) {
          if (!_hydrated) {
            Future(() => _hydrate(brief));
            return const Center(child: CircularProgressIndicator());
          }
          final isLocked = brief.isLocked;
          final notifier = ref.read(briefFormProvider(widget.projectId).notifier);
          final steps = _steps(formState.answers);
          final stepIndex = _step.clamp(0, steps.length - 1);
          final step = steps[stepIndex];
          final progress = (stepIndex + 1) / steps.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  4,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: colors.accent,
                    backgroundColor: colors.surfaceMuted,
                  ),
                ),
              ),
              if (isLocked)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: _LockedBanner(),
                ),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.xl,
                      AppSpacing.screenPadding,
                      AppSpacing.xl,
                    ),
                    child: _stepContent(
                      step: step,
                      stepIndex: stepIndex,
                      total: steps.length,
                      formState: formState,
                      notifier: notifier,
                      isLocked: isLocked,
                    ),
                  ),
                ),
              ),
              if (formState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: Text(
                    formState.errorMessage!,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              BottomActionBar(
                children: [
                  if (stepIndex > 0) ...[
                    SizedBox(
                      width: 120,
                      child: SecondaryButton(
                        label: 'Назад',
                        onPressed: () => setState(() => _step -= 1),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: PrimaryButton(
                      label: stepIndex == steps.length - 1
                          ? (isLocked ? 'Готово' : 'Сохранить')
                          : 'Далее',
                      isLoading: formState.isSaving &&
                          stepIndex == steps.length - 1,
                      onPressed: () => _goNext(
                        steps: steps,
                        isLocked: isLocked,
                        notifier: notifier,
                        fallback: fallback,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stepContent({
    required _BriefStep step,
    required int stepIndex,
    required int total,
    required BriefFormState formState,
    required BriefFormNotifier notifier,
    required bool isLocked,
  }) {
    final general = formState.answers.general;
    final eyebrow = '${stepIndex + 1} из $total';
    final enabled = !isLocked;

    Widget chips({
      required List<BriefChoice> choices,
      required String fieldId,
      int? max,
      bool exclusiveNone = false,
    }) {
      return BriefChipWrap(
        choices: choices,
        selectedIds: briefSelectedIds(general[fieldId]),
        enabled: enabled,
        onToggle: (id) => notifier.toggleChoice(
          fieldId,
          id,
          max: max,
          exclusiveNone: exclusiveNone,
        ),
      );
    }

    Widget note(String fieldId, String hint, {int lines = 3}) {
      return AppInput(
        controller: _controller('g.$fieldId', general[fieldId] ?? ''),
        hintText: hint,
        maxLines: lines,
        enabled: enabled,
        onChanged: (value) => notifier.setGeneral(fieldId, value),
      );
    }

    switch (step.id) {
      case 'family':
        final members = briefParseFamilyMembers(general['householdMembers']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Добавьте, кто будет жить, и возраст.',
            ),
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < members.length; i++) ...[
              _FamilyMemberCard(
                member: members[i],
                enabled: enabled,
                onChanged: (member) => notifier.updateFamilyMember(i, member),
                onRemove: enabled && members.length > 1
                    ? () => notifier.removeFamilyMember(i)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (enabled)
              _DashedAddFamilyButton(onPressed: notifier.addFamilyMember),
            const SizedBox(height: AppSpacing.xl),
            Text('Питомцы', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            chips(choices: briefPetChoices, fieldId: 'pets', exclusiveNone: true),
          ],
        );
      case 'routine':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Отметьте, что ближе — можно несколько вариантов.',
            ),
            const SizedBox(height: AppSpacing.xl),
            chips(choices: briefRoutineChoices, fieldId: 'routine'),
            const SizedBox(height: AppSpacing.xl),
            note('routineNote', 'Как обычно выглядит ваш день', lines: 4),
          ],
        );
      case 'hobbies':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Что занимает свободное время.',
            ),
            const SizedBox(height: AppSpacing.xl),
            chips(choices: briefHobbyChoices, fieldId: 'hobbies'),
            const SizedBox(height: AppSpacing.xl),
            note('hobbiesNote', 'Если чего-то нет в списке — напишите', lines: 3),
          ],
        );
      case 'interests':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Что обязательно должно жить в этом доме.',
            ),
            const SizedBox(height: AppSpacing.xl),
            chips(choices: briefInterestChoices, fieldId: 'interests'),
            const SizedBox(height: AppSpacing.xl),
            note(
              'interestsNote',
              'Своя зона, коллекция, ритуал — всё, что важно сохранить',
              lines: 3,
            ),
          ],
        );
      case 'colors':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Палитра, в которой хочется жить. Не больше четырёх.',
            ),
            const SizedBox(height: AppSpacing.xl),
            BriefPalettePicker(
              selectedIds: briefSelectedIds(general['likedColors']),
              enabled: enabled,
              onToggle: (id) => notifier.toggleChoice('likedColors', id, max: 4),
            ),
          ],
        );
      case 'styles':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Выберите один или два образа.',
            ),
            const SizedBox(height: AppSpacing.xl),
            BriefImageChoiceGrid(
              options: briefStyleOptions,
              selectedIds: briefSelectedIds(general['likedStyles']),
              enabled: enabled,
              onToggle: (id) => notifier.toggleChoice('likedStyles', id, max: 2),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Свой стиль', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            note('likedStylesCustom', 'Опишите стиль своими словами', lines: 2),
          ],
        );
      case 'disliked':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'То, чего в интерьере быть не должно.',
            ),
            const SizedBox(height: AppSpacing.xl),
            chips(choices: briefDislikeChoices, fieldId: 'disliked'),
          ],
        );
      case 'budget':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Ориентир на ремонт — без точных смет.',
            ),
            const SizedBox(height: AppSpacing.xl),
            chips(choices: briefBudgetChoices, fieldId: 'budget', max: 1),
          ],
        );
      case 'object':
        final objectType = general['objectType'] ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Тип объекта и адрес — от этого зависит анкета.',
            ),
            const SizedBox(height: AppSpacing.xl),
            BriefImageChoiceGrid(
              options: briefObjectOptions,
              selectedIds: briefSelectedIds(general['objectType']),
              enabled: enabled,
              onToggle: (id) {
                final alreadySet = formState.answers.rooms.isNotEmpty;
                notifier.setGeneral('objectType', id);
                if (!alreadySet) {
                  final defaults = briefDefaultRoomsByObject[id] ?? const [];
                  for (final section in briefRoomSections) {
                    notifier.setRoomIncluded(
                      section.id,
                      defaults.contains(section.id),
                    );
                  }
                }
                _syncZones(
                  notifier,
                  ref.read(briefFormProvider(widget.projectId)).answers,
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Адрес', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            note(
              'address',
              'Город, ЖК, улица, дом, квартира',
              lines: 2,
            ),
            if (objectType == 'apartment' ||
                objectType == 'house' ||
                objectType == 'office' ||
                objectType == 'commercial') ...[
              const SizedBox(height: AppSpacing.xl),
              if (objectType == 'house') ...[
                Text(
                  'Количество этажей',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                note('floors', 'Например, 2', lines: 1),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (objectType == 'commercial') ...[
                Text(
                  'Тип коммерческого объекта',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                chips(
                  choices: briefCommercialTypeChoices,
                  fieldId: 'commercialType',
                  max: 1,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              Text('Площадь, м²', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              note(
                'area',
                objectType == 'house'
                    ? 'Общая площадь дома'
                    : 'Общая площадь',
                lines: 1,
              ),
            ],
          ],
        );
      case 'rooms':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Отметьте помещения и укажите, сколько их.',
            ),
            const SizedBox(height: AppSpacing.xl),
            BriefImageChoiceGrid(
              options: [
                for (final section in briefRoomSections)
                  BriefVisualOption(
                    id: section.id,
                    label: section.title,
                    asset: section.imageAsset,
                  ),
              ],
              selectedIds: [
                for (final section in briefRoomSections)
                  if (_roomIncluded(formState.answers, section.id)) section.id,
              ],
              enabled: enabled,
              onToggle: (id) {
                if (formState.answers.rooms.isEmpty) {
                  for (final section in briefRoomSections) {
                    notifier.setRoomIncluded(section.id, section.id == id);
                  }
                } else {
                  notifier.setRoomIncluded(
                    id,
                    !_roomIncluded(formState.answers, id),
                  );
                }
                _syncZones(
                  notifier,
                  ref.read(briefFormProvider(widget.projectId)).answers,
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final section in briefRoomSections)
              if (_roomIncluded(formState.answers, section.id))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RoomCountRow(
                    title: section.title,
                    count: int.tryParse(
                          formState.answers.rooms[section.id]?.fields['count'] ??
                              '1',
                        ) ??
                        1,
                    enabled: enabled,
                    onChanged: (value) {
                      notifier.setRoomCount(section.id, value);
                      _syncZones(
                        notifier,
                        ref.read(briefFormProvider(widget.projectId)).answers,
                      );
                    },
                  ),
                ),
          ],
        );
      case 'extras':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Коротко про стены, климат и технику.',
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Перепланировка', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            chips(choices: briefReplanChoices, fieldId: 'replan', max: 1),
            const SizedBox(height: AppSpacing.xl),
            Text('Тёплый пол', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            chips(choices: briefFloorHeatingChoices, fieldId: 'floorHeating', max: 1),
            const SizedBox(height: AppSpacing.xl),
            Text('Стиральная машина', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            chips(choices: briefWasherChoices, fieldId: 'washerLocation', max: 1),
            const SizedBox(height: AppSpacing.xl),
            Text('Кондиционер', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            chips(choices: briefSplitChoices, fieldId: 'split', max: 1),
            const SizedBox(height: AppSpacing.xl),
            Text('Розетки под гаджеты', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            chips(choices: briefGadgetChoices, fieldId: 'gadgetOutlets', max: 1),
            const SizedBox(height: AppSpacing.xl),
            Text('Радиаторы, окна, двери', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            chips(choices: briefRadiatorChoices, fieldId: 'radiators', max: 1),
          ],
        );
      case 'finish':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Всё, что не вошло в предыдущие шаги.',
            ),
            const SizedBox(height: AppSpacing.xl),
            note('details', 'Важные детали, ограничения, сроки', lines: 4),
            const SizedBox(height: AppSpacing.md),
            note(
              'existingItems',
              'Купленные и переезжающие вещи: ссылки или размеры',
              lines: 4,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Вместе с анкетой приложите в документы проекта',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...briefAttachments.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        );
      default:
        final section = briefRoomSections.firstWhere(
          (item) => item.id == step.roomId,
        );
        final room = formState.answers.rooms[section.id] ?? const BriefRoomAnswers();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefCoverImage(asset: section.imageAsset),
            const SizedBox(height: AppSpacing.lg),
            BriefStepHeader(
              eyebrow: eyebrow,
              title: section.title,
              subtitle: 'Коротко по этой комнате — можно пропускать поля.',
            ),
            const SizedBox(height: AppSpacing.xl),
            ...section.fields.map((field) {
              final key = 'r.${section.id}.${field.id}';
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppInput(
                  controller: _controller(key, room.fields[field.id] ?? ''),
                  labelText: field.label,
                  maxLines: field.lines,
                  enabled: enabled,
                  onChanged: (value) =>
                      notifier.setRoomField(section.id, field.id, value),
                ),
              );
            }),
          ],
        );
    }
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Проект в работе — редактирование недоступно'),
          ),
        ],
      ),
    );
  }
}

class _RoomCountRow extends StatelessWidget {
  const _RoomCountRow({
    required this.title,
    required this.count,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final int count;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          _CountChip(
            enabled: enabled && count > 1,
            icon: Icons.remove,
            onTap: () => onChanged(count - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _CountChip(
            enabled: enabled,
            icon: Icons.add,
            onTap: () => onChanged(count + 1),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.enabled,
    required this.icon,
    required this.onTap,
  });

  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: enabled ? colors.surfaceMuted : colors.surfaceMuted.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? colors.textPrimary : colors.textDisabled,
          ),
        ),
      ),
    );
  }
}

class _DashedAddFamilyButton extends StatelessWidget {
  const _DashedAddFamilyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: colors.border,
            radius: 16,
          ),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 22, color: colors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'Добавить участника',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({
    required this.member,
    required this.enabled,
    required this.onChanged,
    this.onRemove,
  });

  final BriefFamilyMember member;
  final bool enabled;
  final ValueChanged<BriefFamilyMember> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Кто',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in briefFamilyRoleChoices)
                ChoiceChip(
                  label: Text(choice.label),
                  selected: member.role == choice.id,
                  onSelected: enabled
                      ? (selected) {
                          if (!selected) return;
                          onChanged(member.copyWith(role: choice.id));
                        }
                      : null,
                ),
            ],
          ),
          if (member.role == 'other') ...[
            const SizedBox(height: AppSpacing.sm),
            AppInput(
              initialValue: member.customRole,
              hintText: 'Кто именно',
              enabled: enabled,
              onChanged: (value) =>
                  onChanged(member.copyWith(customRole: value)),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppInput(
            initialValue: member.age,
            labelText: 'Возраст',
            hintText: 'Например, 32',
            keyboardType: TextInputType.number,
            enabled: enabled,
            onChanged: (value) => onChanged(member.copyWith(age: value)),
          ),
        ],
      ),
    );
  }
}
