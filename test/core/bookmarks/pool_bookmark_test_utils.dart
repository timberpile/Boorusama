import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

import '../../support/fakes/test_post.dart';

const poolGroupA = '550e8400-e29b-41d4-a716-446655440000';
const poolGroupB = '550e8400-e29b-41d4-a716-446655440001';
const poolProfile = '550e8400-e29b-41d4-a716-446655440002';

PostOrigin poolOrigin({
  String host = 'danbooru.donmai.us',
  BooruType type = BooruType.danbooru,
}) => PostOrigin.fromSource(
  booruType: type,
  booruId: type.id,
  source: host,
  profileIdHint: poolProfile,
);

PoolBookmark testPool({
  int id = 10,
  String? localId,
  Set<String> groups = const {poolGroupA},
  Set<String> tags = const {'alpha', 'beta'},
  PoolTagCoverage coverage = PoolTagCoverage.partial,
  DateTime? newest,
  DateTime? oldest,
  String host = 'danbooru.donmai.us',
  BookmarkedPoolCategory category = BookmarkedPoolCategory.series,
}) => PoolBookmark(
  localId:
      localId ?? '550e8400-e29b-41d4-a716-${id.toString().padLeft(12, '0')}',
  origin: poolOrigin(host: host),
  poolId: id,
  category: category,
  title: 'Series $id',
  createdAt: DateTime.utc(2026, 1, 1),
  observedAt: DateTime.utc(2026, 1, 2),
  groupIds: groups,
  tags: tags,
  coverage: coverage,
  total: 20,
  newestUpload: newest,
  oldestUpload: oldest,
);

Bookmark testPoolPost(int id, {Set<String> tags = const {}}) {
  final post = TestPost(
    id: id,
    tags: tags,
    origin: poolOrigin(),
    booruData: const LegacyPostData(typeKey: 'legacy_danbooru', custom: {}),
  );
  return Bookmark.fromSnapshot(
    id: id,
    createdAt: DateTime.utc(2026, 1, id),
    updatedAt: DateTime.utc(2026, 1, id),
    postId: id,
    snapshot: const StoredPostCodec().encode(post),
    post: post,
  );
}
