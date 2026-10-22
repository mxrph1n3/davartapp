import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../data/brief_questionnaire.dart';
import '../data/projects_models.dart';
import '../data/projects_repository.dart';

final projectsListProvider = FutureProvider.autoDispose<List<Project>>((ref) {
  if (!ref.watch(authProvider).isAuthenticated) return [];
  return ref.watch(projectsRepositoryProvider).getProjects();
});

final showcaseProjectsProvider =
    FutureProvider.autoDispose<List<Project>>((ref) {
  return ref.watch(projectsRepositoryProvider).getShowcaseProjects();
});

final projectDetailProvider =
    FutureProvider.autoDispose.family<Project, String>((ref, projectId) {
  final repo = ref.watch(projectsRepositoryProvider);
  if (!ref.watch(authProvider).isAuthenticated) {
    return repo.getShowcaseProject(projectId);
  }
  return repo.getProjectOrShowcase(projectId);
});

final projectMembersProvider =
    FutureProvider.autoDispose.family<List<ProjectMember>, String>((
  ref,
  projectId,
) {
  return ref.watch(projectsRepositoryProvider).getMembers(projectId);
});

final briefProvider =
    FutureProvider.autoDispose.family<Brief, String>((ref, projectId) {
  return ref.watch(projectsRepositoryProvider).getBrief(projectId);
});

class BriefFormState {
  const BriefFormState({
    this.answers = const BriefAnswers(),
    this.rooms = const [],
    this.isSaving = false,
    this.errorMessage,
  });

  final BriefAnswers answers;
  final List<BriefRoom> rooms;
  final bool isSaving;
  final String? errorMessage;

  BriefFormState copyWith({
    BriefAnswers? answers,
    List<BriefRoom>? rooms,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BriefFormState(
      answers: answers ?? this.answers,
      rooms: rooms ?? this.rooms,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final briefFormProvider = NotifierProvider.autoDispose
    .family<BriefFormNotifier, BriefFormState, String>(BriefFormNotifier.new);

class BriefFormNotifier extends AutoDisposeFamilyNotifier<BriefFormState, String> {
  @override
  BriefFormState build(String projectId) => const BriefFormState();

  ProjectsRepository get _repository => ref.read(projectsRepositoryProvider);

  void loadFromBrief(Brief brief) {
    final general = Map<String, String>.from(brief.answers.general);
    final styles = briefSelectedIds(general['likedStyles'])
        .where((id) => id != 'travans')
        .join(',');
    if (styles != (general['likedStyles'] ?? '')) {
      general['likedStyles'] = styles;
    }
    state = BriefFormState(
      answers: brief.answers.copyWith(general: general),
      rooms: brief.rooms,
    );
  }

  void setGeneral(String id, String value) {
    final general = Map<String, String>.from(state.answers.general);
    general[id] = value;
    state = state.copyWith(answers: state.answers.copyWith(general: general));
  }

  void toggleChoice(
    String fieldId,
    String choiceId, {
    int? max,
    bool exclusiveNone = false,
  }) {
    final raw = state.answers.general[fieldId];
    if (exclusiveNone) {
      setGeneral(
        fieldId,
        briefToggleExclusiveNone(raw, choiceId, noneId: 'none'),
      );
      return;
    }
    if (max == 1) {
      setGeneral(fieldId, raw == choiceId ? '' : choiceId);
      return;
    }
    setGeneral(fieldId, briefToggleId(raw, choiceId, max: max));
  }

  void setRoomIncluded(String roomId, bool included) {
    final rooms = Map<String, BriefRoomAnswers>.from(state.answers.rooms);
    final current = rooms[roomId] ?? const BriefRoomAnswers();
    final fields = Map<String, String>.from(current.fields);
    if (included && (fields['count'] == null || fields['count']!.isEmpty)) {
      fields['count'] = '1';
    }
    rooms[roomId] = current.copyWith(included: included, fields: fields);
    state = state.copyWith(answers: state.answers.copyWith(rooms: rooms));
  }

  void setRoomCount(String roomId, int count) {
    final safe = count < 1 ? 1 : count;
    final rooms = Map<String, BriefRoomAnswers>.from(state.answers.rooms);
    final current = rooms[roomId] ?? const BriefRoomAnswers();
    final fields = Map<String, String>.from(current.fields);
    fields['count'] = '$safe';
    rooms[roomId] = current.copyWith(included: true, fields: fields);
    state = state.copyWith(answers: state.answers.copyWith(rooms: rooms));
  }

  void setFamilyMembers(List<BriefFamilyMember> members) {
    setGeneral('householdMembers', briefEncodeFamilyMembers(members));
    setGeneral('household', briefFamilyMembersSummary(members));
  }

  void addFamilyMember() {
    final members = [
      ...briefParseFamilyMembers(state.answers.general['householdMembers']),
      const BriefFamilyMember(),
    ];
    setFamilyMembers(members);
  }

  void updateFamilyMember(int index, BriefFamilyMember member) {
    final members =
        briefParseFamilyMembers(state.answers.general['householdMembers']);
    if (index < 0 || index >= members.length) return;
    members[index] = member;
    setFamilyMembers(members);
  }

  void removeFamilyMember(int index) {
    final members =
        briefParseFamilyMembers(state.answers.general['householdMembers']);
    if (index < 0 || index >= members.length) return;
    members.removeAt(index);
    setFamilyMembers(members);
  }

  void setRoomField(String roomId, String fieldId, String value) {
    final rooms = Map<String, BriefRoomAnswers>.from(state.answers.rooms);
    final current = rooms[roomId] ?? const BriefRoomAnswers();
    final fields = Map<String, String>.from(current.fields);
    fields[fieldId] = value;
    rooms[roomId] = current.copyWith(fields: fields);
    state = state.copyWith(answers: state.answers.copyWith(rooms: rooms));
  }

  void addRoom() {
    state = state.copyWith(
      rooms: [...state.rooms, const BriefRoom(name: '')],
    );
  }

  void updateRoom(int index, BriefRoom room) {
    final rooms = [...state.rooms];
    rooms[index] = room;
    state = state.copyWith(rooms: rooms);
  }

  void removeRoom(int index) {
    final rooms = [...state.rooms]..removeAt(index);
    state = state.copyWith(rooms: rooms);
  }

  Future<bool> save() async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final rooms = state.rooms
          .where((room) => room.name.trim().isNotEmpty)
          .map(
            (room) => BriefRoom(
              name: room.name.trim(),
              type: room.type,
              area: room.area,
            ),
          )
          .toList();

      await _repository.updateBrief(
        arg,
        UpdateBriefRequest(
          style: state.answers.general['likedStyles']?.trim().isEmpty ?? true
              ? null
              : state.answers.general['likedStyles']!.trim(),
          budget: double.tryParse(
            (state.answers.general['budget'] ?? '').replaceAll(RegExp(r'[^\d.]'), ''),
          ),
          wishes: state.answers.general['details']?.trim().isEmpty ?? true
              ? null
              : state.answers.general['details']!.trim(),
          rooms: rooms,
          answers: state.answers,
        ),
      );

      ref.invalidate(briefProvider(arg));
      ref.invalidate(projectDetailProvider(arg));
      ref.invalidate(projectsListProvider);

      state = state.copyWith(isSaving: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Не удалось сохранить анкету',
      );
      return false;
    }
  }

  Future<bool> downloadPdf() async {
    try {
      final bytes = await _repository.downloadBriefPdf(arg);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/brief-$arg.pdf');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
      return true;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Не удалось скачать PDF');
      return false;
    }
  }
}
