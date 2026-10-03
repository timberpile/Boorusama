// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../../boorus/booru/types.dart';
import '../../../../configs/config/src/types/profile_id.dart';

final class PostOrigin extends Equatable {
  const PostOrigin._({
    required this.booruType,
    required this.booruId,
    required this.sourceHost,
    required this.profileIdHint,
  });

  factory PostOrigin.fromSource({
    required BooruType booruType,
    required int booruId,
    required String source,
    String? profileIdHint,
  }) => PostOrigin._(
    booruType: booruType,
    booruId: booruId,
    sourceHost: normalizePostSourceHost(source),
    profileIdHint: profileIdHint,
  );

  factory PostOrigin.forBooruType(BooruType booruType) => PostOrigin.fromSource(
    booruType: booruType,
    booruId: booruType.id,
    source: '',
  );

  factory PostOrigin.fromSnapshot(PostOriginSnapshot snapshot) => PostOrigin._(
    booruType: BooruType.fromLegacyId(snapshot.booruTypeId),
    booruId: snapshot.booruId,
    sourceHost: normalizePostSourceHost(snapshot.sourceHost),
    profileIdHint: snapshot.profileIdHint,
  );

  final BooruType booruType;
  final int booruId;
  final String sourceHost;
  final String? profileIdHint;

  PostOriginSnapshot toSnapshot() => PostOriginSnapshot(
    booruTypeId: booruType.id,
    booruId: booruId,
    sourceHost: sourceHost,
    profileIdHint: profileIdHint,
  );

  @override
  List<Object?> get props => [booruType, booruId, sourceHost, profileIdHint];
}

final class PostOriginSnapshot extends Equatable {
  const PostOriginSnapshot({
    required this.booruTypeId,
    required this.booruId,
    required this.sourceHost,
    required this.profileIdHint,
  });

  factory PostOriginSnapshot.fromJson(Map<String, dynamic> json) =>
      PostOriginSnapshot(
        booruTypeId: json['booruTypeId'] as int,
        booruId: json['booruId'] as int,
        sourceHost: json['sourceHost'] as String,
        profileIdHint: switch (json['profileIdHint']) {
          final String id when isCanonicalProfileId(id) => id,
          _ => null,
        },
      );

  final int booruTypeId;
  final int booruId;
  final String sourceHost;
  final String? profileIdHint;

  Map<String, Object?> toJson() => {
    'booruTypeId': booruTypeId,
    'booruId': booruId,
    'sourceHost': sourceHost,
    if (profileIdHint case final id?) 'profileIdHint': id,
  };

  @override
  List<Object?> get props => [booruTypeId, booruId, sourceHost, profileIdHint];
}

String normalizePostSourceHost(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) return '';

  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return '';

  final rawHost = uri.host.toLowerCase();
  final host = rawHost.contains(':') ? '[$rawHost]' : rawHost;
  final isDefaultPort =
      (uri.scheme.toLowerCase() == 'https' && uri.port == 443) ||
      (uri.scheme.toLowerCase() == 'http' && uri.port == 80);

  final authority = uri.hasPort && !isDefaultPort ? '$host:${uri.port}' : host;
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  return '$authority$path';
}
