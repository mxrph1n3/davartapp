class ProjectStaff {
  const ProjectStaff({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  factory ProjectStaff.fromJson(Map<String, dynamic> json) {
    return ProjectStaff(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }
}

typedef ProjectDesigner = ProjectStaff;

class BriefRoom {
  const BriefRoom({
    required this.name,
    this.type,
    this.area,
  });

  final String name;
  final String? type;
  final double? area;

  factory BriefRoom.fromJson(Map<String, dynamic> json) {
    return BriefRoom(
      name: json['name'] as String,
      type: json['type'] as String?,
      area: (json['area'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (type != null) 'type': type,
        if (area != null) 'area': area,
      };
}

class BriefRoomAnswers {
  const BriefRoomAnswers({
    this.included = true,
    this.fields = const {},
  });

  final bool included;
  final Map<String, String> fields;

  factory BriefRoomAnswers.fromJson(Map<String, dynamic> json) {
    final fields = <String, String>{};
    json.forEach((key, value) {
      if (key == 'included') return;
      if (value != null) fields[key] = value.toString();
    });
    return BriefRoomAnswers(
      included: json['included'] as bool? ?? true,
      fields: fields,
    );
  }

  Map<String, dynamic> toJson() => {
        'included': included,
        ...fields,
      };

  BriefRoomAnswers copyWith({
    bool? included,
    Map<String, String>? fields,
  }) {
    return BriefRoomAnswers(
      included: included ?? this.included,
      fields: fields ?? this.fields,
    );
  }
}

class BriefAnswers {
  const BriefAnswers({
    this.general = const {},
    this.rooms = const {},
  });

  final Map<String, String> general;
  final Map<String, BriefRoomAnswers> rooms;

  factory BriefAnswers.fromJson(Object? json) {
    if (json is! Map) return const BriefAnswers();
    final map = Map<String, dynamic>.from(json);
    final generalRaw = map['general'];
    final roomsRaw = map['rooms'];
    final general = <String, String>{};
    if (generalRaw is Map) {
      generalRaw.forEach((key, value) {
        if (value != null) general[key.toString()] = value.toString();
      });
    }
    final rooms = <String, BriefRoomAnswers>{};
    if (roomsRaw is Map) {
      roomsRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          rooms[key.toString()] = BriefRoomAnswers.fromJson(value);
        } else if (value is Map) {
          rooms[key.toString()] = BriefRoomAnswers.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    return BriefAnswers(general: general, rooms: rooms);
  }

  Map<String, dynamic> toJson() => {
        'general': general,
        'rooms': rooms.map((key, value) => MapEntry(key, value.toJson())),
      };

  BriefAnswers copyWith({
    Map<String, String>? general,
    Map<String, BriefRoomAnswers>? rooms,
  }) {
    return BriefAnswers(
      general: general ?? this.general,
      rooms: rooms ?? this.rooms,
    );
  }
}

class Brief {
  const Brief({
    this.id,
    this.style,
    this.budget,
    this.wishes,
    required this.rooms,
    this.answers = const BriefAnswers(),
    required this.isLocked,
    this.lockedAt,
    required this.updatedAt,
  });

  final String? id;
  final String? style;
  final double? budget;
  final String? wishes;
  final List<BriefRoom> rooms;
  final BriefAnswers answers;
  final bool isLocked;
  final DateTime? lockedAt;
  final DateTime updatedAt;

  factory Brief.fromJson(Map<String, dynamic> json) {
    final roomsJson = json['rooms'];
    return Brief(
      id: json['id'] as String?,
      style: json['style'] as String?,
      budget: (json['budget'] as num?)?.toDouble(),
      wishes: json['wishes'] as String?,
      rooms: roomsJson is List
          ? roomsJson
              .map((room) => BriefRoom.fromJson(room as Map<String, dynamic>))
              .toList()
          : [],
      answers: BriefAnswers.fromJson(json['answers']),
      isLocked: json['isLocked'] as bool? ?? false,
      lockedAt: json['lockedAt'] != null
          ? DateTime.parse(json['lockedAt'] as String)
          : null,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.name,
    this.number,
    this.address,
    this.area,
    this.style,
    this.objectType,
    this.startDate,
    this.userId,
    required this.status,
    required this.statusLabel,
    this.isShowcase = false,
    this.isDraft = false,
    this.designer,
    this.manager,
    this.surveyor,
    this.brief,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  /// «Дизайн-проект №16068» once the admin has entered the contract [number].
  final String name;
  final String? number;
  final String? address;
  final double? area;
  final String? style;
  final String? objectType;
  final DateTime? startDate;
  final String? userId;
  final String status;
  final String statusLabel;
  final bool isShowcase;
  final bool isDraft;
  final ProjectStaff? designer;
  final ProjectStaff? manager;
  final ProjectStaff? surveyor;
  final Brief? brief;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Project.fromJson(Map<String, dynamic> json) {
    ProjectStaff? staff(String key) {
      final value = json[key];
      if (value is! Map<String, dynamic>) return null;
      return ProjectStaff.fromJson(value);
    }

    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String?,
      address: json['address'] as String?,
      area: (json['area'] as num?)?.toDouble(),
      style: json['style'] as String?,
      objectType: json['objectType'] as String?,
      userId: json['userId'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      status: json['status'] as String,
      statusLabel: json['statusLabel'] as String,
      isShowcase: json['isShowcase'] as bool? ?? false,
      isDraft: json['isDraft'] as bool? ?? false,
      designer: staff('designer'),
      manager: staff('manager'),
      surveyor: staff('surveyor'),
      brief: json['brief'] != null
          ? Brief.fromJson(json['brief'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class UpdateBriefRequest {
  const UpdateBriefRequest({
    this.style,
    this.budget,
    this.wishes,
    this.rooms,
    this.answers,
  });

  final String? style;
  final double? budget;
  final String? wishes;
  final List<BriefRoom>? rooms;
  final BriefAnswers? answers;

  Map<String, dynamic> toJson() => {
        if (style != null) 'style': style,
        if (budget != null) 'budget': budget,
        if (wishes != null) 'wishes': wishes,
        if (rooms != null) 'rooms': rooms!.map((room) => room.toJson()).toList(),
        if (answers != null) 'answers': answers!.toJson(),
      };
}

class ProjectMemberUser {
  const ProjectMemberUser({
    required this.id,
    required this.phone,
    this.name,
  });

  final String id;
  final String phone;
  final String? name;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : phone;

  factory ProjectMemberUser.fromJson(Map<String, dynamic> json) {
    return ProjectMemberUser(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
    );
  }
}

class ProjectMember {
  const ProjectMember({
    required this.id,
    required this.role,
    required this.user,
    this.relation,
  });

  final String id;
  final String role;
  final ProjectMemberUser user;
  final String? relation;

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Клиент';
      case 'viewer':
        return 'Наблюдатель';
      default:
        return 'Участник';
    }
  }

  /// Subtitle under the participant name in project detail.
  String? get participantSubtitle {
    final relationLabel = relation?.trim();
    if (relationLabel != null && relationLabel.isNotEmpty) {
      return relationLabel;
    }
    if (role == 'owner') {
      return user.name != null && user.name!.trim().isNotEmpty
          ? (user.phone.isNotEmpty ? user.phone : null)
          : 'Клиент';
    }
    if (user.phone.isNotEmpty) return user.phone;
    return roleLabel;
  }

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'member',
      relation: json['relation'] as String?,
      user: ProjectMemberUser.fromJson(
        json['user'] as Map<String, dynamic>,
      ),
    );
  }
}

