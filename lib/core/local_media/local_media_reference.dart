import 'package:equatable/equatable.dart';

import '../posts/post/src/types/booru_post_data.dart';

final class LocalMediaReference extends Equatable {
  const LocalMediaReference._(this.sha256);

  factory LocalMediaReference.parse(String value) {
    if (value.length != 64 || !_hex.hasMatch(value)) {
      throw const FormatException('Invalid Local Media SHA-256');
    }
    return LocalMediaReference._(value);
  }

  static final _hex = RegExp(r'^[0-9a-f]+$');

  // The colon prevents this namespace from colliding with an HTTP host.
  static const namespace = 'local-media:';

  final String sha256;

  String get shard => sha256.substring(0, 2);

  @override
  List<Object> get props => [sha256];
}

final class LocalMediaPostData extends Equatable
    implements BooruPostData, StableBookmarkPostKeyData, SitePostIdData {
  const LocalMediaPostData(this.reference);

  final LocalMediaReference reference;

  @override
  String get typeKey => 'localMedia';

  @override
  int get schemaVersion => 1;

  @override
  String get stableBookmarkPostKey => reference.sha256;

  @override
  String? get sitePostId => null;

  @override
  List<Object> get props => [reference];
}
