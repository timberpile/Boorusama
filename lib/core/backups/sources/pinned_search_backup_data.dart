// Package imports:
import 'package:equatable/equatable.dart';

class PinnedSearchBackupData extends Equatable {
  const PinnedSearchBackupData({required this.records});

  final List<PinnedSearchBackupRecord> records;

  @override
  List<Object?> get props => [records];
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
  return uri
      .replace(
        host: uri.host.toLowerCase(),
        path: uri.path.endsWith('/')
            ? uri.path.substring(0, uri.path.length - 1)
            : uri.path,
      )
      .toString();
}
