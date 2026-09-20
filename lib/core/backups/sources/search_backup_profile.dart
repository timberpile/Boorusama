import 'package:equatable/equatable.dart';

import '../../configs/config/types.dart';
import '../types/types.dart';

class BackupProfileReference extends Equatable {
  const BackupProfileReference({
    required this.id,
    required this.booruType,
    required this.url,
    required this.name,
  });

  final int id;
  final String booruType;
  final String url;
  final String name;

  Map<String, Object?> toJson() => {
    'id': id,
    'booruType': booruType,
    'url': normalizeBackupProfileUrl(url),
    'name': name,
  };

  @override
  List<Object?> get props => [id, booruType, url, name];
}

String normalizeBackupProfileUrl(String url) => normalizeBooruSiteUrl(url);

BackupProfileReference parseBackupProfile(Object? raw, String field) {
  if (raw is! Map<String, dynamic>) {
    throw InvalidBackupFormatException('$field must be an object');
  }
  final id = switch (raw['id']) {
    final int value when value >= 0 => value,
    _ => throw InvalidBackupFormatException('$field.id is invalid'),
  };
  final type = switch (raw['booruType']) {
    final String value when value.trim().isNotEmpty => value,
    _ => throw InvalidBackupFormatException('$field.booruType is invalid'),
  };
  final url = switch (raw['url']) {
    final String value when value.trim().isNotEmpty => value,
    _ => throw InvalidBackupFormatException('$field.url is invalid'),
  };
  final name = switch (raw['name']) {
    final String value when value.trim().isNotEmpty => value,
    _ => throw InvalidBackupFormatException('$field.name is invalid'),
  };
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty) {
    throw InvalidBackupFormatException('$field.url is invalid');
  }
  return BackupProfileReference(
    id: id,
    booruType: type,
    url: normalizeBackupProfileUrl(url),
    name: name,
  );
}

BooruConfig? resolveBackupProfile(
  BackupProfileReference reference,
  List<BooruConfig> profiles,
) {
  final normalizedUrl = normalizeBackupProfileUrl(reference.url);
  final matches = profiles
      .where(
        (profile) =>
            profile.auth.booruType.name == reference.booruType &&
            normalizeBackupProfileUrl(profile.url) == normalizedUrl,
      )
      .toList();
  for (final profile in matches) {
    if (profile.id == reference.id) return profile;
  }
  return matches.length == 1 ? matches.single : null;
}
