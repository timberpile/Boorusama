// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'post_origin.dart';

final class StoredPostSnapshot extends Equatable {
  const StoredPostSnapshot({
    required this.origin,
    required this.common,
    required this.custom,
    required this.codecVersion,
  });

  factory StoredPostSnapshot.fromJson(Map<String, dynamic> json) =>
      StoredPostSnapshot(
        origin: PostOriginSnapshot.fromJson(
          Map<String, dynamic>.from(json['origin'] as Map),
        ),
        common: Map<String, Object?>.from(json['common'] as Map),
        custom: Map<String, Object?>.from(json['custom'] as Map),
        codecVersion: json['codecVersion'] as int,
      );

  final PostOriginSnapshot origin;
  final Map<String, Object?> common;
  final Map<String, Object?> custom;
  final int codecVersion;

  Map<String, Object?> toJson() => {
    'origin': origin.toJson(),
    'common': common,
    'custom': custom,
    'codecVersion': codecVersion,
  };

  @override
  List<Object?> get props => [origin, common, custom, codecVersion];
}
