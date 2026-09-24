// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../../boorus/booru/types.dart';

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
    int? profileIdHint,
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
  final int? profileIdHint;

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
        profileIdHint: json['profileIdHint'] as int?,
      );

  final int booruTypeId;
  final int booruId;
  final String sourceHost;
  final int? profileIdHint;

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
  if (uri == null || uri.host.isEmpty) return trimmed.toLowerCase();

  final host = uri.host.toLowerCase();
  final isDefaultPort =
      (uri.scheme.toLowerCase() == 'https' && uri.port == 443) ||
      (uri.scheme.toLowerCase() == 'http' && uri.port == 80);

  return uri.hasPort && !isDefaultPort ? '$host:${uri.port}' : host;
}
