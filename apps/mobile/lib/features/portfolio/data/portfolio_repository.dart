import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepository(ref.watch(dioProvider));
});

class PortfolioTile {
  const PortfolioTile({required this.label, this.style, this.kind, this.coverUrl});

  final String label;
  final String? style;
  final String? kind;
  final String? coverUrl;
}

class PortfolioTiles {
  const PortfolioTiles({required this.collage, required this.styles, required this.kinds});

  factory PortfolioTiles.fromJson(Map<String, dynamic> json) => PortfolioTiles(
    collage: [
      for (final u in json['collage'] as List<dynamic>)
        if (u is String) u,
    ],
    styles: [
      for (final s in json['styles'] as List<dynamic>)
        PortfolioTile(label: s['label'] as String, style: s['slug'] as String, coverUrl: s['coverUrl'] as String?),
    ],
    kinds: [
      for (final k in json['kinds'] as List<dynamic>)
        PortfolioTile(label: k['label'] as String, kind: k['kind'] as String, coverUrl: k['coverUrl'] as String?),
    ],
  );

  /// Renders for the «Все проекты» collage.
  final List<String> collage;
  final List<PortfolioTile> styles;

  /// Архитектура, Экстерьер, Ландшафт — below the styles.
  final List<PortfolioTile> kinds;
}

class PortfolioCard {
  const PortfolioCard({
    required this.id,
    required this.number,
    required this.title,
    required this.images,
    this.styleLabel,
    this.area,
  });

  factory PortfolioCard.fromJson(Map<String, dynamic> json) => PortfolioCard(
    id: json['id'] as String,
    number: json['number'] as String,
    title: json['title'] as String,
    styleLabel: json['styleLabel'] as String?,
    area: (json['area'] as num?)?.toDouble(),
    images: [
      for (final u in json['images'] as List<dynamic>)
        if (u is String) u,
    ],
  );

  final String id;
  final String number;
  final String title;
  final String? styleLabel;
  final double? area;
  final List<String> images;
}

class PortfolioImage {
  const PortfolioImage({required this.url, this.room});

  final String url;
  final String? room;
}

class PortfolioProject {
  const PortfolioProject({
    required this.id,
    required this.number,
    required this.title,
    required this.kindLabel,
    required this.images,
    required this.rooms,
    required this.favorite,
    this.objectType,
    this.styleLabel,
    this.area,
    this.designer,
    this.completedAt,
    this.materialsCost,
    this.description,
    this.inRealization = false,
  });

  factory PortfolioProject.fromJson(Map<String, dynamic> json) => PortfolioProject(
    id: json['id'] as String,
    number: json['number'] as String,
    title: json['title'] as String,
    kindLabel: json['kindLabel'] as String,
    objectType: json['objectType'] as String?,
    styleLabel: json['styleLabel'] as String?,
    area: (json['area'] as num?)?.toDouble(),
    designer: json['designer'] as String?,
    completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
    materialsCost: (json['materialsCost'] as num?)?.toDouble(),
    description: json['description'] as String?,
    inRealization: json['inRealization'] as bool? ?? false,
    favorite: json['favorite'] as bool? ?? false,
    rooms: [for (final r in json['rooms'] as List<dynamic>) r as String],
    images: [
      for (final i in json['images'] as List<dynamic>)
        PortfolioImage(url: i['url'] as String, room: i['room'] as String?),
    ],
  );

  final String id;
  final String number;
  final String title;
  final String kindLabel;
  final String? objectType;
  final String? styleLabel;
  final double? area;
  final String? designer;
  final DateTime? completedAt;
  final double? materialsCost;
  final String? description;
  final bool inRealization;
  final bool favorite;
  final List<String> rooms;
  final List<PortfolioImage> images;
}

class PortfolioFilters {
  const PortfolioFilters({this.objectTypes = const {}, this.areaMin, this.areaMax, this.style});

  final Set<String> objectTypes;
  final double? areaMin;
  final double? areaMax;

  /// Only in «Все проекты».
  final String? style;

  int get activeCount =>
      (objectTypes.isNotEmpty ? 1 : 0) + (areaMin != null || areaMax != null ? 1 : 0) + (style != null ? 1 : 0);

  static const empty = PortfolioFilters();
}

class PortfolioFilterOptions {
  const PortfolioFilterOptions({required this.objectTypes, required this.styles});

  final List<String> objectTypes;
  final List<({String slug, String label})> styles;
}

class PortfolioRepository {
  PortfolioRepository(this._dio);

  final Dio _dio;

  Future<PortfolioTiles> tiles() async {
    final response = await _dio.get('/portfolio/tiles');
    return PortfolioTiles.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PortfolioCard>> list({
    String? style,
    String? kind,
    PortfolioFilters filters = PortfolioFilters.empty,
  }) async {
    final response = await _dio.get(
      '/portfolio',
      options: Options(listFormat: ListFormat.multi),
      queryParameters: {
        'style': ?(style ?? filters.style),
        'kind': ?kind,
        if (filters.objectTypes.isNotEmpty) 'objectType': filters.objectTypes.toList(),
        'areaMin': ?filters.areaMin,
        'areaMax': ?filters.areaMax,
      },
    );
    return [for (final p in response.data as List<dynamic>) PortfolioCard.fromJson(p as Map<String, dynamic>)];
  }

  Future<PortfolioFilterOptions> filterOptions() async {
    final response = await _dio.get('/portfolio/filters');
    final data = response.data as Map<String, dynamic>;
    return PortfolioFilterOptions(
      objectTypes: [for (final t in data['objectTypes'] as List<dynamic>) t as String],
      styles: [
        for (final s in data['styles'] as List<dynamic>) (slug: s['slug'] as String, label: s['label'] as String),
      ],
    );
  }

  Future<PortfolioProject> project(String id) async {
    final response = await _dio.get('/portfolio/$id');
    return PortfolioProject.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setFavorite(String id, bool on) async {
    if (on) {
      await _dio.put('/portfolio/$id/favorite');
    } else {
      await _dio.delete('/portfolio/$id/favorite');
    }
  }
}
