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
    if ((general['phone'] ?? '').trim().isNotEmpty &&
        (general['email'] ?? '').trim().isNotEmpty &&
        (general['address'] ?? '').trim().isNotEmpty) {
      _prefilled = true;
      return;
    }
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
  }

  bool _roomIncluded(BriefAnswers answers, String roomId) {
    if (answers.rooms.isEmpty) return false;
    return answers.rooms[roomId]?.included ?? true;
  }

  List<_BriefStep> _steps(BriefAnswers answers) {
    final rooms = briefRoomSections
        .where((section) => _roomIncluded(answers, section.id))
        .toList();
    return [
      const _BriefStep(id: 'family', title: 'Кто будет жить?'),
      const _BriefStep(id: 'routine', title: 'Как проходит день?'),
      const _BriefStep(id: 'hobbies', title: 'Чем увлекаетесь?'),
      const _BriefStep(id: 'interests', title: 'Что должно быть дома?'),
      const _BriefStep(id: 'colors', title: 'Какие цвета близки?'),
      const _BriefStep(id: 'styles', title: 'Какой стиль откликается?'),
      const _BriefStep(id: 'disliked', title: 'Чего точно не хотите?'),
      const _BriefStep(id: 'budget', title: 'Какой бюджет?'),
      const _BriefStep(id: 'object', title: 'Какой объект?'),
      const _BriefStep(id: 'rooms', title: 'Какие комнаты есть?'),
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
        .map((section) => section.title)
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
    }
    if (!isLocked) {
      final success = await notifier.save();
      if (!mounted) return;
      if (isLast && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Анкета сохранена')),
        );
      }
      return;
    }
    if (isLast) {
      popOrGo(context, fallback);
    }
  }

  void _goBack(String fallback) {
    if (_step > 0) {
      setState(() => _step -= 1);
      return;
    }
    popOrGo(context, fallback);
  }

  @override
  Widget build(BuildContext context) {
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
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => _goBack(fallback),
        ),
        title: const Text('Анкета'),
        actions: [
          IconButton(
            onPressed: () async {
              final success = await ref
                  .read(briefFormProvider(widget.projectId).notifier)
                  .downloadPdf();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF открыт')),
                );
              }
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Скачать PDF',
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
                    color: AppColors.accent,
                    backgroundColor: AppColors.surfaceMuted,
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
                child: SingleChildScrollView(
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
              if (formState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: Text(
                    formState.errorMessage!,
                    style: const TextStyle(color: AppColors.error),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Семья, дети, питомцы — от этого зависит планировка.',
            ),
            const SizedBox(height: AppSpacing.xl),
            chips(choices: briefHouseholdChoices, fieldId: 'householdKind', max: 1),
            const SizedBox(height: AppSpacing.xl),
            Text('Дети', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            chips(choices: briefKidsChoices, fieldId: 'kids', exclusiveNone: true),
            const SizedBox(height: AppSpacing.xl),
            Text('Питомцы', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            chips(choices: briefPetChoices, fieldId: 'pets', exclusiveNone: true),
            const SizedBox(height: AppSpacing.xl),
            note(
              'household',
              'Имена и возраст, если хотите уточнить',
              lines: 3,
            ),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'От типа объекта зависит набор комнат.',
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
          ],
        );
      case 'rooms':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BriefStepHeader(
              eyebrow: eyebrow,
              title: step.title,
              subtitle: 'Отметьте помещения, которые есть или появятся.',
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
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
