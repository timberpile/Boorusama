import 'package:equatable/equatable.dart';

import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../../../posts/related/related_family.dart';
import 'pool_bookmark.dart';
import 'pool_bookmark_capability.dart';

/// The bookmark operation, independent of its anchor, dialog or context menu.
sealed class BookmarkPickerRequest extends Equatable {
  const BookmarkPickerRequest();
  BooruConfigAuth get config;
  BooruConfig? get source => null;
  Object? get collectionIdentity => null;
}

final class PostBookmarkPickerRequest extends BookmarkPickerRequest {
  const PostBookmarkPickerRequest({
    required this.config,
    required this.post,
    this.source,
  });
  @override
  final BooruConfigAuth config;
  final Post post;
  @override
  final BooruConfig? source;
  @override
  List<Object?> get props => [config, post, source];
}

final class StoredBookmarkPickerRequest extends BookmarkPickerRequest {
  const StoredBookmarkPickerRequest({
    required this.config,
    required this.collection,
    this.source,
  });
  @override
  final BooruConfigAuth config;
  final CollectionBookmark collection;
  @override
  final BooruConfig? source;
  @override
  Object get collectionIdentity => collection.identity;
  @override
  List<Object?> get props => [config, collection, source];
}

final class RemotePoolBookmarkPickerRequest extends BookmarkPickerRequest {
  const RemotePoolBookmarkPickerRequest({
    required BooruConfig config,
    required this.pool,
  }) : source = config;
  @override
  final BooruConfig source;
  @override
  BooruConfigAuth get config => source.auth;
  final RemoteBookmarkPool pool;
  @override
  Object get collectionIdentity => (
    config.booruType.id,
    normalizePostSourceHost(source.url),
    pool.id,
  );
  @override
  List<Object?> get props => [
    source,
    pool.id,
    pool.title,
    pool.category,
    pool.total,
    pool.supportsUploadOrder,
  ];
}

final class RelatedBookmarkPickerRequest extends BookmarkPickerRequest {
  const RelatedBookmarkPickerRequest({
    required BooruConfig config,
    required this.family,
  }) : source = config;
  @override
  final BooruConfig source;
  @override
  BooruConfigAuth get config => source.auth;
  final RelatedFamilyReference family;
  @override
  Object get collectionIdentity => family.identity;
  @override
  List<Object?> get props => [source, family];
}
