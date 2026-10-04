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

  final String id;
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

typedef BackupProfileIdResolver =
    String? Function(
      BackupProfileReference reference,
    );

String normalizeBackupProfileUrl(String url) => normalizeBooruSiteUrl(url);

BackupProfileReference parseBackupProfile(Object? raw, String field) {
  if (raw is! Map<String, dynamic>) {
    throw InvalidBackupFormatException('$field must be an object');
  }
  final id = switch (raw['id']) {
    final String value when isCanonicalProfileId(value) => value,
    _ => throw InvalidBackupFormatException(
      '$field.id must be a lowercase UUID',
    ),
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
  for (final profile in profiles) {
    if (profile.id == reference.id &&
        profile.auth.booruType.name == reference.booruType &&
        normalizeBackupProfileUrl(profile.url) ==
            normalizeBackupProfileUrl(reference.url)) {
      return profile;
    }
  }
  return null;
}

String? resolveBackupProfileId(
  BackupProfileReference reference,
  List<BooruConfig> profiles, {
  BackupProfileIdResolver? resolver,
}) =>
    resolver?.call(reference) ?? resolveBackupProfile(reference, profiles)?.id;
