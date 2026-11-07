import '../../../boorus/booru/types.dart';
import '../../../content/content_map.dart';
import '../../../content/types.dart';
import '../../../posts/post/types.dart';
import '../../../posts/related/related_posts_order_value.dart';
import '../types/bookmark.dart';
import '../types/bookmark_record_fields.dart';
import '../types/content_group_bookmark.dart';
import '../types/legacy_group_bookmark.dart';
import 'legacy_group_codec.dart';
import 'stored_group_codec.dart';

/// A tagged record shared by durable mutation journals and v10 transfers. IDs
/// in a transfer are file-local; only the repository may publish a local ID.
final class StoredBookmarkCodec {
  const StoredBookmarkCodec({
    this.groups = const StoredGroupCodec(),
    this.postDataCodec,
  });

  final StoredGroupCodec groups;
  final BooruPostDataCodec? Function(BooruType type)? postDataCodec;
  static const _legacy = LegacyGroupCodec();

  /// Match the existing Post export policy: local source-page URLs are not
  /// transferred. Their semantic namespace cannot reconstruct a transport URL.
  Map<String, Object?> encodeForTransfer(Bookmark bookmark) {
    final wire = encode(bookmark);
    if (bookmark is PostBookmark) wire.remove('sourceUrl');
    return wire;
  }

  Map<String, Object?> encode(Bookmark bookmark) {
    final map = switch (bookmark) {
      PostBookmark() => {
        'kind': 'post',
        'id': bookmark.id,
        'createdAt': bookmark.createdAt.toIso8601String(),
        'updatedAt': bookmark.updatedAt.toIso8601String(),
        'postId': bookmark.postId,
        'sourceUrl': bookmark.sourceUrl,
        'snapshot': bookmark.snapshot.toJson(),
      },
      ContentGroupBookmark() => {
        'kind': bookmark is RelatedBookmark ? 'related' : 'group',
        'id': bookmark.id,
        'createdAt': bookmark.createdAt.toIso8601String(),
        'observedAt': bookmark.observedAt.toIso8601String(),
        'snapshot': groups.encode(bookmark.snapshot),
        'sourceProfileHint': ?bookmark.sourceProfileHint,
        if (bookmark case RelatedBookmark(:final preferredOrder?))
          'preferredOrder': preferredOrder.name,
      },
      LegacyGroupBookmark() => {
        'kind': bookmark.metadata.isRelated ? 'related' : 'group',
        'id': bookmark.id,
        'createdAt': bookmark.createdAt.toIso8601String(),
        'observedAt': bookmark.observedAt.toIso8601String(),
        'legacy': _legacy.encode(bookmark),
        if (bookmark case LegacyRelatedGroupBookmark(:final preferredOrder?))
          'preferredOrder': preferredOrder.name,
      },
      _ => throw const FormatException('Unsupported Bookmark record'),
    };
    // Construction can come from an adapter as well as a decoder. Use the same
    // interpretation checks before a journal or transfer can publish the data.
    decode(map);
    return map;
  }

  Bookmark decode(Object? value) {
    try {
      final map = contentMap(value);
      final id = map['id'];
      if (id is! int || id < 0 || id > 9007199254740991) {
        throw const FormatException('Invalid Bookmark file ID');
      }
      final created = _date(map['createdAt']);
      final kind = map['kind'];
      if (kind == 'post') {
        if (map.containsKey('legacy') || map.containsKey('preferredOrder')) {
          throw const FormatException('Conflicting Post record');
        }
        final snapshot = StoredPostSnapshot.fromJson(
          contentMap(map['snapshot']),
        );
        final decoded = const StoredPostCodec().decode(
          snapshot,
          dataCodec: postDataCodec?.call(
            BooruType.fromLegacyId(snapshot.origin.booruTypeId),
          ),
        );
        if (decoded is! StoredPostDecodeSuccess) {
          throw const FormatException('Invalid Post snapshot');
        }
        final postId = map['postId'];
        if (postId != null && (postId is! int || postId != decoded.post.id)) {
          throw const FormatException('Conflicting Post snapshot identity');
        }
        return PostBookmark.fromSnapshot(
          id: id,
          createdAt: DateTime.parse(contentString(map['createdAt'])),
          updatedAt: DateTime.parse(contentString(map['updatedAt'])),
          snapshot: snapshot,
          post: postId == null
              ? decoded.post.copyWith(
                  origin: PostOrigin.fromSource(
                    booruType: decoded.post.origin.booruType,
                    booruId: decoded.post.origin.booruId,
                    source: '',
                    profileIdHint: decoded.post.origin.profileIdHint,
                  ),
                )
              : decoded.post,
          postId: postId as int?,
          sourceUrl: map['sourceUrl'] as String?,
        );
      }
      if (kind != 'group' && kind != 'related') {
        throw const FormatException('Unsupported Bookmark record kind');
      }
      if (map.containsKey('legacy') == map.containsKey('snapshot')) {
        throw const FormatException('Expected one Group payload');
      }
      final observed = _date(map['observedAt']);
      final preferredOrder = map['preferredOrder'] == null
          ? null
          : RelatedPostsOrder.values
                    .where((order) => order.name == map['preferredOrder'])
                    .firstOrNull ??
                (throw const FormatException('Unsupported Related order'));
      if (kind == 'group' && map.containsKey('preferredOrder')) {
        throw const FormatException('Only Related stores member order');
      }
      if (map.containsKey('legacy')) {
        final legacy = _legacy.decode(
          map['legacy'],
          id: id,
          createdAt: created,
          observedAt: observed,
          preferredOrder: preferredOrder,
        );
        if ((kind == 'related') != legacy.metadata.isRelated) {
          throw const FormatException('Conflicting legacy Group kind');
        }
        return legacy;
      }
      final snapshot = groups.decode(map['snapshot']);
      if (kind == 'related') {
        return RelatedBookmark(
          id: id,
          snapshot: snapshot,
          createdAt: created,
          observedAt: observed,
          sourceProfileHint: map['sourceProfileHint'] as String?,
          preferredOrder: preferredOrder,
        );
      }
      if (snapshot.summary.reference.engine == BooruType.danbooru &&
          snapshot.summary.reference.sourceKey.startsWith('related:')) {
        throw const FormatException('Related family requires a Related record');
      }
      return ContentGroupBookmark(
        id: id,
        snapshot: snapshot,
        createdAt: created,
        observedAt: observed,
        sourceProfileHint: map['sourceProfileHint'] as String?,
      );
      // Normalize untrusted JSON/Hive fields before any mutation can start.
      // ignore: avoid_catching_errors
    } on TypeError {
      throw const FormatException('Invalid Bookmark record field');
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw const FormatException('Invalid Bookmark record field');
    }
  }

  static DateTime _date(Object? value) =>
      DateTime.parse(contentString(value)).toUtc();

  ContentIdentity? identityOf(Bookmark bookmark) =>
      bookmarkContentIdentity(bookmark);

  BooruType engineOf(Bookmark bookmark) => bookmarkEngine(bookmark);
}
