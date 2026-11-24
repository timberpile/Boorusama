// Package imports:
import 'package:equatable/equatable.dart';

import '../../../../../boorus/anime-pictures/posts/types.dart' show Post;

import '../../../../../boorus/danbooru/posts/post/types.dart' show Post;

import '../../../../../boorus/e621/posts/types.dart' show Post;

import '../../../../../boorus/eshuushuu/posts/types.dart' show Post;

import '../../../../../boorus/gelbooru/posts/types.dart' show Post;

import '../../../../../boorus/gelbooru_v1/posts/types.dart' show Post;

import '../../../../../boorus/gelbooru_v2/posts/types.dart' show Post;

import '../../../../../boorus/hybooru/posts/types.dart' show Post;

import '../../../../../boorus/hydrus/posts/types.dart' show Post;

import '../../../../../boorus/moebooru/posts/types.dart' show Post;

import '../../../../../boorus/nozomi/posts/types.dart' show Post;

import '../../../../../boorus/philomena/posts/types.dart' show Post;

import '../../../../../boorus/pixiv/posts/types.dart' show Post;

import '../../../../../boorus/sankaku/posts/types.dart' show Post;

import '../../../../../boorus/shimmie2/posts/types.dart' show Post;

import '../../../../../boorus/szurubooru/posts/types.dart' show Post;

import '../../../../../boorus/zerochan/posts/types.dart' show Post;

import '../../types.dart' show Post;

import 'post.dart' show Post;

abstract interface class BooruPostData {
  String get typeKey;
  int get schemaVersion;
}

/// Supplies the genuine identifier assigned by a source when [Post.id] can be
/// synthetic (for example Sankaku string IDs or Pixiv page IDs).
abstract interface class SitePostIdData {
  String? get sitePostId;
}

abstract interface class PostSourceUrlsData {
  Iterable<String> get sourceUrls;
}

abstract interface class StableBookmarkPostKeyData {
  String? get stableBookmarkPostKey;
}

abstract interface class BooruPostDataCodec<D extends BooruPostData> {
  String get typeKey;
  int get currentVersion;
  bool supports(BooruPostData data);
  Map<String, Object?> encode(D data);
  D decode(Map<String, Object?> json, {required int version});
}

class EmptyPostDataCodec implements BooruPostDataCodec<EmptyPostData> {
  const EmptyPostDataCodec(this.typeKey);

  @override
  final String typeKey;

  @override
  int get currentVersion => 1;

  @override
  bool supports(BooruPostData data) =>
      data is EmptyPostData && data.typeKey == typeKey;

  @override
  Map<String, Object?> encode(EmptyPostData data) {
    if (!supports(data)) {
      throw ArgumentError.value(data, 'data', 'Incompatible empty post data');
    }
    return const {};
  }

  @override
  EmptyPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) {
    if (version != currentVersion || json.isNotEmpty) {
      throw const FormatException('Invalid empty post data');
    }
    return EmptyPostData(typeKey: typeKey);
  }
}

/// Reserved shared snapshot variant, dispatched before any engine codec.
/// The listed snapshot has its own payload version and shape discriminator.
final class ListedPostData extends Equatable implements BooruPostData {
  const ListedPostData();
  static const payloadVersion = 1;
  @override
  String get typeKey => 'listed';
  @override
  int get schemaVersion => payloadVersion;
  @override
  List<Object?> get props => const [];
}

final class EmptyPostData extends Equatable implements BooruPostData {
  const EmptyPostData({required this.typeKey, this.schemaVersion = 1});

  @override
  final String typeKey;

  @override
  final int schemaVersion;

  @override
  List<Object?> get props => [typeKey, schemaVersion];
}

final class LegacyPostData extends Equatable implements BooruPostData {
  const LegacyPostData({
    required this.typeKey,
    required this.custom,
    this.schemaVersion = 1,
  });

  @override
  final String typeKey;

  @override
  final int schemaVersion;

  final Map<String, Object?> custom;

  @override
  List<Object?> get props => [typeKey, schemaVersion, custom];
}

enum UnknownPostDataReason {
  unavailableCodec,
  unsupportedVersion,
  malformedData,
  incompatiblePayload,
}

final class UnknownPostData extends Equatable implements BooruPostData {
  const UnknownPostData({
    required this.typeKey,
    required this.schemaVersion,
    required this.custom,
    required this.reason,
  });

  @override
  final String typeKey;

  @override
  final int schemaVersion;

  final Map<String, Object?> custom;
  final UnknownPostDataReason reason;

  @override
  List<Object?> get props => [typeKey, schemaVersion, custom, reason];
}
