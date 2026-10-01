// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'export_selection.dart';
import 'import_action.dart';

const kExportPackageFormat = 'boorusama-export';
const kExportPackageFormatVersion = 1;
const kExportPackageExtension = '.bsexport';
const kExportPackageMimeType = 'application/vnd.boorusama.export';

final class ExportPartManifest extends Equatable {
  ExportPartManifest({
    required this.path,
    required this.sha256,
    required this.byteLength,
  }) {
    if (!isSafeExportPartPath(path)) {
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
    if (path is! String ||
        sha256 is! String ||
        byteLength is! int ||
        !isSafeExportPartPath(path) ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256) ||
        byteLength < 0) {
      throw const FormatException('Invalid export part manifest');
    }
    return ExportPartManifest(
      path: path,
      sha256: sha256.toLowerCase(),
      byteLength: byteLength,
    );
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
    this.selection,
    this.recommendedAction,
    Map<String, ImportAction> itemRecommendedActions = const {},
    required List<ExportPartManifest> parts,
  }) : itemRecommendedActions = Map.unmodifiable(itemRecommendedActions),
       parts = List.unmodifiable(parts) {
    if (id.isEmpty ||
        schemaVersion < 1 ||
        parts.isEmpty ||
        (selection != null && selection!.nodeId != id) ||
        itemRecommendedActions.keys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError('Invalid export source manifest');
    }
  }

  factory ExportSourceManifest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final schemaVersion = json['schemaVersion'];
    final rawSelection = json['selection'];
    final rawRecommendedAction = json['recommendedAction'];
    final rawItemRecommendedActions = json['itemRecommendedActions'];
    final rawParts = json['parts'];
    if (id is! String ||
        schemaVersion is! int ||
        rawParts is! List<dynamic> ||
        id.isEmpty ||
        schemaVersion < 1 ||
        rawParts.isEmpty) {
      throw const FormatException('Invalid export source manifest');
    }
    final selection = switch (rawSelection) {
      null => null,
      final Map<String, dynamic> value => ExportNodeSelection.fromJson({
        ...value,
        'nodeId': value['nodeId'] ?? id,
      }),
      _ => throw const FormatException('Invalid export source selection'),
    };
    if (selection != null && selection.nodeId != id) {
      throw const FormatException('Invalid export source selection');
    }
    final recommendedAction = switch (rawRecommendedAction) {
      null => null,
      _ => importActionFromJson(rawRecommendedAction),
    };
    final itemRecommendedActions = _parseItemRecommendedActions(
      rawItemRecommendedActions,
    );
    return ExportSourceManifest(
      id: id,
      schemaVersion: schemaVersion,
      selection: selection,
      recommendedAction: recommendedAction,
      itemRecommendedActions: itemRecommendedActions,
      parts: rawParts.map((raw) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid export part manifest');
        }
        return ExportPartManifest.fromJson(raw);
      }).toList(),
    );
  }

  final String id;
  final int schemaVersion;
  final ExportNodeSelection? selection;
  final ImportAction? recommendedAction;
  final Map<String, ImportAction> itemRecommendedActions;
  final List<ExportPartManifest> parts;

  Map<String, Object> toJson() {
    final selectionJson = selection?.toJson()?..remove('nodeId');
    if (selection?.kind == ExportNodeSelectionKind.all) {
      selectionJson?.remove('childIds');
    }
    final itemRecommendedActionsJson = itemRecommendedActions.isEmpty
        ? null
        : {
            for (final id in itemRecommendedActions.keys.toList()..sort())
              id: itemRecommendedActions[id]!.name,
          };
    return {
      'id': id,
      'schemaVersion': schemaVersion,
      'selection': ?selectionJson,
      'parts': parts.map((part) => part.toJson()).toList(),
      'recommendedAction': ?recommendedAction?.name,
      'itemRecommendedActions': ?itemRecommendedActionsJson,
    };
  }

  @override
  List<Object?> get props => [
    id,
    schemaVersion,
    selection,
    parts,
    recommendedAction,
    itemRecommendedActions,
  ];
}

final class ExportPackageManifest extends Equatable {
  ExportPackageManifest({
    String format = kExportPackageFormat,
    this.formatVersion = kExportPackageFormatVersion,
    required String exportId,
    required this.createdAt,
    required this.appVersion,
    required ExportSelectionMode preset,
    required bool containsCredentials,
    required List<ExportSourceManifest> sources,
  }) : format = format,
       exportId = exportId,
       preset = preset,
       containsCredentials = containsCredentials,
       sources = List.unmodifiable(sources) {
    if (format != kExportPackageFormat ||
        formatVersion != kExportPackageFormatVersion ||
        exportId.trim().isEmpty ||
        appVersion.isEmpty) {
      throw ArgumentError('Invalid export package manifest');
    }
  }

  ExportPackageManifest._legacy({
    required this.format,
    required this.formatVersion,
    required this.exportId,
    required this.createdAt,
    required this.appVersion,
    required this.preset,
    required this.containsCredentials,
    required List<ExportSourceManifest> sources,
  }) : sources = List.unmodifiable(sources);

  factory ExportPackageManifest.fromJson(Map<String, dynamic> json) {
    final format = json['format'];
    final formatVersion = json['formatVersion'];
    final exportId = json['exportId'];
    final rawCreatedAt = json['createdAt'];
    final appVersion = json['appVersion'];
    final rawPreset = json['preset'];
    final containsCredentials = json['containsCredentials'];
    final rawSources = json['sources'];
    if ((format != null && format != kExportPackageFormat) ||
        formatVersion is! int ||
        (exportId != null &&
            (exportId is! String || exportId.trim().isEmpty)) ||
        rawCreatedAt is! String ||
        appVersion is! String ||
        (containsCredentials != null && containsCredentials is! bool) ||
        rawSources is! List<dynamic> ||
        formatVersion != kExportPackageFormatVersion ||
        appVersion.isEmpty) {
      throw const FormatException('Invalid export package manifest');
    }
    final preset = switch (rawPreset) {
      null => null,
      'full' => ExportSelectionMode.full,
      'custom' => ExportSelectionMode.custom,
      _ => throw const FormatException('Invalid export package preset'),
    };
    final createdAt = DateTime.tryParse(rawCreatedAt);
    if (createdAt == null) {
      throw const FormatException('Invalid export package manifest');
    }
    final sources = rawSources.map((raw) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid export source manifest');
      }
      return ExportSourceManifest.fromJson(raw);
    }).toList();
    if (sources.map((source) => source.id).toSet().length != sources.length) {
      throw const FormatException('Repeated export source manifest');
    }
    return ExportPackageManifest._legacy(
      format: format as String?,
      formatVersion: formatVersion,
      exportId: exportId as String?,
      createdAt: createdAt.toUtc(),
      appVersion: appVersion,
      preset: preset,
      containsCredentials: containsCredentials as bool?,
      sources: sources,
    );
  }

  final String? format;
  final int formatVersion;
  final String? exportId;
  final DateTime createdAt;
  final String appVersion;
  final ExportSelectionMode? preset;
  final bool? containsCredentials;
  final List<ExportSourceManifest> sources;

  Map<String, Object> toJson() => {
    'format': ?format,
    'formatVersion': formatVersion,
    'exportId': ?exportId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'preset': ?preset?.name,
    'containsCredentials': ?containsCredentials,
    'sources': sources.map((source) => source.toJson()).toList(),
  };

  @override
  List<Object?> get props => [
    format,
    formatVersion,
    exportId,
    createdAt,
    appVersion,
    preset,
    containsCredentials,
    sources,
  ];
}

bool isSafeExportPartPath(String path) {
  if (path.isEmpty || path.startsWith('/') || path.contains(r'\')) return false;
  final segments = path.split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
}

Map<String, ImportAction> _parseItemRecommendedActions(Object? raw) {
  if (raw == null) return const {};
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('Invalid item recommended actions');
  }
  final actions = <String, ImportAction>{};
  for (final entry in raw.entries) {
    if (entry.key.trim().isEmpty) {
      throw const FormatException('Invalid item recommended action ID');
    }
    actions[entry.key] = importActionFromJson(entry.value);
  }
  return actions;
}
