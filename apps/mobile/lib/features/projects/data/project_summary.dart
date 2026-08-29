import 'brief_questionnaire.dart';
import 'projects_models.dart';

/// Living / zone room count from brief answers (for cards & summary).
int? projectRoomCount(Project project) {
  final rooms = project.brief?.answers.rooms;
  if (rooms != null && rooms.isNotEmpty) {
    var total = 0;
    for (final entry in rooms.entries) {
      if (entry.value.included == false) continue;
      final id = entry.key;
      if (id == 'hallway' ||
          id == 'bathroom' ||
          id == 'wardrobe' ||
          id == 'loggia' ||
          id == 'kitchen') {
        continue;
      }
      final count = int.tryParse(entry.value.fields['count'] ?? '') ?? 1;
      total += count;
    }
    if (total > 0) return total;
  }

  final legacy = project.brief?.rooms ?? const [];
  if (legacy.isNotEmpty) return legacy.length;
  return null;
}

String? projectObjectTypeLabel(Project project) {
  final typeId =
      (project.objectType ?? project.brief?.answers.general['objectType'] ?? '')
          .trim();
  if (typeId.isEmpty) return null;
  return briefValueLabels['objectType']?[typeId] ?? typeId;
}

double? projectAreaValue(Project project) {
  if (project.area != null && project.area! > 0) return project.area;
  final raw =
      (project.brief?.answers.general['area'] ?? '').replaceAll(',', '.').trim();
  return double.tryParse(raw);
}

String? projectAddressValue(Project project) {
  final address =
      (project.address ?? project.brief?.answers.general['address'] ?? '')
          .trim();
  return address.isEmpty ? null : address;
}

/// Compact one-line summary: тип объекта · N комн. · адрес
String? projectBriefSummary(Project project) {
  final parts = <String>[];

  final typeLabel = projectObjectTypeLabel(project);
  if (typeLabel != null) parts.add(typeLabel);

  final rooms = projectRoomCount(project);
  if (rooms != null && rooms > 0) {
    parts.add('$rooms комн.');
  }

  final address = projectAddressValue(project);
  if (address != null) {
    parts.add(address.length > 48 ? '${address.substring(0, 48)}…' : address);
  }

  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
