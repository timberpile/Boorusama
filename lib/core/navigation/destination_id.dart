import 'dart:convert';

import 'package:equatable/equatable.dart';

enum AppDestination {
  following('following'),
  bookmarks('bookmarks'),
  blacklist('blacklist'),
  favoriteTags('favorite-tags'),
  bulkDownload('bulk-download'),
  downloadManager('download-manager'),
  profiles('profiles'),
  backups('backups'),
  donate('donate'),
  support('support'),
  settings('settings'),
  browseRecovery('browse-recovery'),
  favoritesRecovery('favorites-recovery');

  const AppDestination(this.wireName);
  final String wireName;
}

enum DestinationKind { app, browse, favorites, tool }

/// Identity is independent of labels, profile order and currently selected account.
final class DestinationId extends Equatable {
  const DestinationId.app(AppDestination destination)
    : kind = DestinationKind.app,
      appDestination = destination,
      profileId = null,
      toolId = null;
  const DestinationId.browse(String id)
    : kind = DestinationKind.browse,
      profileId = id,
      appDestination = null,
      toolId = null;
  const DestinationId.favorites(String id)
    : kind = DestinationKind.favorites,
      profileId = id,
      appDestination = null,
      toolId = null;
  const DestinationId.tool(String id, String tool)
    : kind = DestinationKind.tool,
      profileId = id,
      toolId = tool,
      appDestination = null;

  final DestinationKind kind;
  final AppDestination? appDestination;
  final String? profileId;
  final String? toolId;

  String toStorageKey() => jsonEncode([
    1,
    kind.name,
    if (kind == DestinationKind.app) appDestination!.wireName else profileId,
    if (kind == DestinationKind.tool) toolId,
  ]);

  static DestinationId? tryParse(String value) {
    try {
      final data = jsonDecode(value);
      if (data is! List ||
          data.length < 3 ||
          data[0] != 1 ||
          data[2] is! String) {
        return null;
      }
      final id = data[2] as String;
      if (id.isEmpty) return null;
      return switch (data) {
        [1, 'app', _] => _parseApp(id),
        [1, 'browse', _] => DestinationId.browse(id),
        [1, 'favorites', _] => DestinationId.favorites(id),
        [1, 'tool', _, final String tool] when tool.isNotEmpty =>
          DestinationId.tool(id, tool),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  static DestinationId? _parseApp(String name) {
    final destination = AppDestination.values
        .where((e) => e.wireName == name)
        .firstOrNull;
    return destination == null ? null : DestinationId.app(destination);
  }

  String get location => Uri(
    pathSegments: [
      '',
      '_nav',
      if (kind == DestinationKind.app) ...[
        'app',
        appDestination!.wireName,
      ] else ...[
        'profile',
        profileId!,
        if (kind == DestinationKind.tool) ...['tool', toolId!] else kind.name,
      ],
    ],
  ).toString();

  @override
  List<Object?> get props => [kind, appDestination, profileId, toolId];
}
