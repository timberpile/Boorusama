// Package imports:
import 'package:equatable/equatable.dart';

const kExportPackageFormatVersion = 1;
const kExportPackageExtension = '.bsexport';
const kExportPackageMimeType = 'application/vnd.boorusama.export';

final class ExportPartManifest extends Equatable {
  ExportPartManifest({
    required this.path,
    required this.sha256,
    required this.byteLength,
  }) {
    if (!_isSafeRelativePath(path)) {
      throw ArgumentError.value(path, 'path', 'Must be a safe relative path');
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      throw ArgumentError.value(sha256, 'sha256', 'Must be a SHA-256 digest');
    }
    if (byteLength < 0) {
      throw ArgumentError.value(byteLength, 'byteLength', 'Must be positive');
    }
  }

  factory ExportPartManifest.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    final sha256 = json['sha256'];
    final byteLength = json['byteLength'];
    if (path is! String || sha256 is! String || byteLength is! int) {
      throw const FormatException('Invalid export part manifest');
    }
    try {
      return ExportPartManifest(
        path: path,
        sha256: sha256.toLowerCase(),
        byteLength: byteLength,
      );
    } on ArgumentError {
      throw const FormatException('Invalid export part manifest');
    }
  }

  final String path;
  final String sha256;
  final int byteLength;

  Map<String, Object> toJson() => {
    'path': path,
    'sha256': sha256,
    'byteLength': byteLength,
  };

  @override
  List<Object> get props => [path, sha256, byteLength];
}

final class ExportSourceManifest extends Equatable {
  ExportSourceManifest({
    required this.id,
    required this.schemaVersion,
    required List<ExportPartManifest> parts,
  }) : parts = List.unmodifiable(parts) {
    if (id.isEmpty || schemaVersion < 1 || parts.isEmpty) {
      throw ArgumentError('Invalid export source manifest');
    }
  }

  factory ExportSourceManifest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final schemaVersion = json['schemaVersion'];
    final rawParts = json['parts'];
    if (id is! String || schemaVersion is! int || rawParts is! List<dynamic>) {
      throw const FormatException('Invalid export source manifest');
    }
    try {
      return ExportSourceManifest(
        id: id,
        schemaVersion: schemaVersion,
        parts: rawParts.map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Invalid export part manifest');
          }
          return ExportPartManifest.fromJson(raw);
        }).toList(),
      );
    } on ArgumentError {
      throw const FormatException('Invalid export source manifest');
    }
  }

  final String id;
  final int schemaVersion;
  final List<ExportPartManifest> parts;

  Map<String, Object> toJson() => {
    'id': id,
    'schemaVersion': schemaVersion,
    'parts': parts.map((part) => part.toJson()).toList(),
  };

  @override
  List<Object> get props => [id, schemaVersion, parts];
}

final class ExportPackageManifest extends Equatable {
  ExportPackageManifest({
    this.formatVersion = kExportPackageFormatVersion,
    required this.createdAt,
    required this.appVersion,
    required List<ExportSourceManifest> sources,
  }) : sources = List.unmodifiable(sources) {
    if (formatVersion != kExportPackageFormatVersion || appVersion.isEmpty) {
      throw ArgumentError('Invalid export package manifest');
    }
  }

  factory ExportPackageManifest.fromJson(Map<String, dynamic> json) {
    final formatVersion = json['formatVersion'];
    final rawCreatedAt = json['createdAt'];
    final appVersion = json['appVersion'];
    final rawSources = json['sources'];
    if (formatVersion is! int ||
        rawCreatedAt is! String ||
        appVersion is! String ||
        rawSources is! List<dynamic>) {
      throw const FormatException('Invalid export package manifest');
    }
    final createdAt = DateTime.tryParse(rawCreatedAt);
    if (createdAt == null) {
      throw const FormatException('Invalid export package manifest');
    }
    try {
      return ExportPackageManifest(
        formatVersion: formatVersion,
        createdAt: createdAt.toUtc(),
        appVersion: appVersion,
        sources: rawSources.map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Invalid export source manifest');
          }
          return ExportSourceManifest.fromJson(raw);
        }).toList(),
      );
    } on ArgumentError {
      throw const FormatException('Invalid export package manifest');
    }
  }

  final int formatVersion;
  final DateTime createdAt;
  final String appVersion;
  final List<ExportSourceManifest> sources;

  Map<String, Object> toJson() => {
    'formatVersion': formatVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'sources': sources.map((source) => source.toJson()).toList(),
  };

  @override
  List<Object> get props => [formatVersion, createdAt, appVersion, sources];
}

bool _isSafeRelativePath(String path) {
  if (path.isEmpty || path.startsWith('/') || path.contains(r'\')) return false;
  final segments = path.split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
}
