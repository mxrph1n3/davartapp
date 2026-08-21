import 'package:flutter/material.dart';

class ProjectDocument {
  const ProjectDocument({
    required this.id,
    required this.projectId,
    required this.type,
    required this.typeLabel,
    required this.name,
    this.mimeType,
    this.size,
    required this.uploadedAt,
  });

  final String id;
  final String projectId;
  final String type;
  final String typeLabel;
  final String name;
  final String? mimeType;
  final int? size;
  final DateTime uploadedAt;

  bool get isPdf =>
      mimeType == 'application/pdf' || name.toLowerCase().endsWith('.pdf');

  factory ProjectDocument.fromJson(Map<String, dynamic> json) {
    return ProjectDocument(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      type: json['type'] as String,
      typeLabel: json['typeLabel'] as String,
      name: json['name'] as String,
      mimeType: json['mimeType'] as String?,
      size: json['size'] as int?,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );
  }
}

class DocumentDownload {
  const DocumentDownload({
    required this.url,
    required this.expiresIn,
    required this.expiresAt,
    required this.name,
    this.mimeType,
  });

  final String url;
  final int expiresIn;
  final DateTime expiresAt;
  final String name;
  final String? mimeType;

  factory DocumentDownload.fromJson(Map<String, dynamic> json) {
    return DocumentDownload(
      url: json['url'] as String,
      expiresIn: json['expiresIn'] as int,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      name: json['name'] as String,
      mimeType: json['mimeType'] as String?,
    );
  }
}

IconData documentTypeIcon(String type) {
  return switch (type) {
    'contract' => Icons.description,
    'pdf' => Icons.picture_as_pdf,
    'dwg' => Icons.architecture,
    'specification' => Icons.list_alt,
    'invoice' => Icons.receipt_long,
    _ => Icons.insert_drive_file,
  };
}
