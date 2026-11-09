import '../../boorus/booru/types.dart';
import '../../bookmarks/src/data/stored_bookmark_codec.dart';
import '../../bookmarks/src/data/stored_group_codec.dart';
import '../../content/types.dart';
import '../../posts/post/types.dart';

/// Resolve provider-backed codec lookups before sending a task to an isolate.
StoredBookmarkCodec detachBookmarkRecordCodec(StoredBookmarkCodec original) {
  final metadata = original.groups.metadata;
  final posts = {
    for (final engine in BooruYamlConfigs.values.map((config) => config.type))
      engine: original.postDataCodec?.call(engine),
  };
  final groups = {
    for (final engine in BooruYamlConfigs.values.map((config) => config.type))
      engine: metadata.dataCodecFor?.call(engine),
  };
  final keys = {
    for (final engine in BooruYamlConfigs.values.map((config) => config.type))
      if (engine != BooruType.unknown)
        engine: metadata.references.codecFor(engine),
  };
  return _codecFromMaps(posts, groups, keys);
}

StoredBookmarkCodec _codecFromMaps(
  Map<BooruType, BooruPostDataCodec?> posts,
  Map<BooruType, BooruGroupDataCodec?> groups,
  Map<BooruType, ContentKeyCodec> keys,
) => StoredBookmarkCodec(
  postDataCodec: (engine) => posts[engine],
  groups: StoredGroupCodec(
    metadata: GroupMetadataCodec(
      references: ContentReferenceCodec(keyCodecFor: (engine) => keys[engine]),
      dataCodecFor: (engine) => groups[engine],
    ),
  ),
);
