import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../boorus/booru/types.dart';
import '../../../../content/anonymous_source_policy.dart';

/// Credential-free source identity, never mirror ownership or an access grant.
/// Existing local copies retain their fixed account-binding policy. Imported
/// references can resolve a unique compatible local profile without being owned
/// by that profile; the foreign UUID is provenance, not local account authority.
final class FollowingTopicSource extends Equatable {
  FollowingTopicSource({
    required this.booruType,
    required String url,
    this.importedProfileId,
    this.importedProfileName,
  }) : url = _site(url) {
    final id = importedProfileId;
    if (id != null &&
        (id != id.toLowerCase() || !Uuid.isValidUUID(fromString: id))) {
      throw const FormatException(
        'Invalid imported Following profile identity',
      );
    }
    if (importedProfileName != null &&
        (id == null || importedProfileName!.trim().isEmpty)) {
      throw const FormatException('Invalid imported Following profile name');
    }
  }

  factory FollowingTopicSource.fromJson(Map json) => FollowingTopicSource(
    booruType: json['booruType'] as String,
    url: json['url'] as String,
    importedProfileId: json['importedProfileId'] as String?,
    importedProfileName: json['importedProfileName'] as String?,
  );

  final String booruType;
  final String url;
  final String? importedProfileId;
  final String? importedProfileName;

  bool get isImported => importedProfileId != null;

  AnonymousSource? anonymous(AnonymousSourcePolicy policy) {
    final engine = BooruYamlConfigs.byId.values
        .where((config) => config.type.name == booruType)
        .firstOrNull
        ?.type;
    return engine == null ? null : policy.resolve(engine, Uri.parse(url));
  }

  bool matches(String engine, String site) =>
      booruType == engine && Uri.parse(url) == Uri.parse(site);

  Map<String, Object?> toJson() => {
    'booruType': booruType,
    'url': url,
    if (importedProfileId != null) 'importedProfileId': importedProfileId,
    if (importedProfileName != null) 'importedProfileName': importedProfileName,
  };

  static String _site(String value) {
    final uri = Uri.parse(value);
    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid local Following source');
    }
    return uri
        .replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''))
        .toString();
  }

  @override
  List<Object?> get props => [
    booruType,
    url,
    importedProfileId,
    importedProfileName,
  ];
}

final class FollowingLocalCopySourceUnavailable implements Exception {
  const FollowingLocalCopySourceUnavailable();
}
