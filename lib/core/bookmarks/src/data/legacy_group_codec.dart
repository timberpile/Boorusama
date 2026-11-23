import '../../../content/content_map.dart';
import '../../../posts/related/related_posts_order_value.dart';
import '../types/legacy_group_bookmark.dart';
import '../types/pool_bookmark.dart';

/// A known compatibility envelope for old source facts, not an exemption for
/// unsupported native Group snapshots. No membership or guessed URL is stored.
final class LegacyGroupCodec {
  const LegacyGroupCodec();

  static const _localFields = {
    'localId',
    'groupIds',
    'addedAt',
    'createdAt',
    'observedAt',
  };

  Map<String, Object?> encode(LegacyGroupBookmark bookmark) {
    if (bookmark.metadata.loadedDetails != null) {
      throw const FormatException(
        'Loaded Details require a native Group snapshot',
      );
    }
    final metadata = bookmark.metadata.toJson();
    _localFields.forEach(metadata.remove);
    return {'version': 1, 'metadata': metadata};
  }

  LegacyGroupBookmark decode(
    Object? value, {
    required int id,
    required DateTime createdAt,
    required DateTime observedAt,
    RelatedPostsOrder? preferredOrder,
  }) {
    try {
      final map = contentMap(value);
      if (map['version'] != 1) {
        throw const FormatException('Unsupported legacy Group evidence');
      }
      final metadata = contentMap(map['metadata']);
      if (metadata.keys.any(_localFields.contains)) {
        throw const FormatException('Legacy metadata contains local authority');
      }
      final parsed = CollectionBookmark.fromJson({
        ...metadata,
        'localId': '$id',
        'createdAt': createdAt.toUtc().toIso8601String(),
        'observedAt': observedAt.toUtc().toIso8601String(),
        'groupIds': const <String>[],
        'addedAt': const <String, String>{},
      });
      return LegacyGroupBookmark.fromMetadata(
        id: id,
        metadata: parsed,
        preferredOrder: preferredOrder,
      );
      // Normalize untrusted legacy Hive/JSON field failures before any write.
      // ignore: avoid_catching_errors
    } on TypeError {
      throw const FormatException('Invalid legacy Group evidence');
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw const FormatException('Invalid legacy Group evidence');
    }
  }
}
