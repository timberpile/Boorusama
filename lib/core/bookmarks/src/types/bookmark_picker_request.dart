import 'package:equatable/equatable.dart';

import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../../../posts/related/related_family.dart';
import '../../../posts/related/related_posts_order_value.dart';
import 'pool_bookmark.dart';
import 'bookmark.dart';
import 'pool_bookmark_capability.dart';
import 'content_group_bookmark.dart';
import '../../../content/content_access.dart';

/// The bookmark operation, independent of its anchor, dialog or context menu.
sealed class BookmarkPickerRequest extends Equatable {
  const BookmarkPickerRequest();
  BooruConfigAuth get config;
  BooruConfig? get source => null;
  Object? get collectionIdentity => null;
  int? get savedRecordId => null;
}

/// Frozen native Group facts. The provisional draft ID never addresses storage.
final class ContentGroupBookmarkPickerRequest extends BookmarkPickerRequest {
  const ContentGroupBookmarkPickerRequest({
    required this.draft,
    required this.source,
    required this.access,
  });
  final ContentGroupBookmark draft;
  final ContentAccessKey access;
  @override
  final BooruConfig source;
  @override
  BooruConfigAuth get config => source.auth;
  @override
  List<Object?> get props => [draft, source, access];
}

final class PostBookmarkPickerRequest extends BookmarkPickerRequest {
  const PostBookmarkPickerRequest({
    required this.config,
    required this.post,
    this.source,
    this.access,
  });
  @override
  final BooruConfigAuth config;
  final Post post;
  final ContentAccessKey? access;
  @override
  final BooruConfig? source;
  @override
  List<Object?> get props => [config, post, source, access];
}

/// A frozen local record remains editable without an addressable source or a
/// matching profile. The ID never comes from a transfer document.
final class SavedBookmarkPickerRequest extends BookmarkPickerRequest {
  const SavedBookmarkPickerRequest({
    required this.config,
    required this.record,
  });
  @override
  final BooruConfigAuth config;
  final Bookmark record;
  @override
  int get savedRecordId => record.id;
  @override
  List<Object?> get props => [config, record];
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
  int? get savedRecordId => collection.bookmarkId;
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
    this.visibleOrder,
  }) : source = config;
  @override
  final BooruConfig source;
  @override
  BooruConfigAuth get config => source.auth;
  final RelatedFamilyReference family;
  final RelatedPostsOrder? visibleOrder;
  @override
  Object get collectionIdentity => family.identity;
  @override
  List<Object?> get props => [source, family, visibleOrder];
}
