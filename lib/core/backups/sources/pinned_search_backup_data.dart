// Package imports:
import 'package:equatable/equatable.dart';

class PinnedSearchBackupData extends Equatable {
  const PinnedSearchBackupData({
    required this.records,
    this.folders = const [],
    this.feeds = const [],
  });

  final List<PinnedSearchBackupRecord> records;
  final List<PinnedSearchFolderBackupRecord> folders;
  final List<PinnedSearchFeedBackupRecord> feeds;

  @override
  List<Object?> get props => [records, folders, feeds];
}

class PinnedSearchBackupRecord extends Equatable {
  const PinnedSearchBackupRecord({
    required this.id,
    required this.name,
    required this.query,
    required this.position,
    required this.profile,
  });

  final String id;
  final String? name;
  final String query;
  final int position;
  final PinnedSearchProfileReference profile;

  @override
  List<Object?> get props => [id, name, query, position, profile];
}

class PinnedSearchProfileReference extends Equatable {
  const PinnedSearchProfileReference({
    required this.id,
    required this.booruType,
    required this.url,
    required this.name,
  });

  final int id;
  final String booruType;
  final String url;
  final String name;

  @override
  List<Object?> get props => [id, booruType, url, name];
}

String normalizePinnedSearchProfileUrl(String url) {
  final uri = Uri.parse(url);
  return Uri(
    scheme: uri.scheme,
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
  ).toString();
}

class PinnedSearchFolderBackupRecord extends Equatable {
  const PinnedSearchFolderBackupRecord({
    required this.id,
    required this.name,
    required this.position,
    required this.searchIds,
    required this.profile,
  });
  final String id;
  final String name;
  final int position;
  final List<String> searchIds;
  final PinnedSearchProfileReference profile;
  @override
  List<Object?> get props => [id, name, position, searchIds, profile];
}

class PinnedSearchFeedBackupRecord extends Equatable {
  const PinnedSearchFeedBackupRecord({
    required this.id,
    required this.name,
    required this.position,
    required this.queries,
    required this.profile,
  });
  final String id;
  final String name;
  final int position;
  final List<String> queries;
  final PinnedSearchProfileReference profile;
  @override
  List<Object?> get props => [id, name, position, queries, profile];
}
