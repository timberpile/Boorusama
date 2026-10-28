import 'dart:collection';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/posts/post/types.dart';

import '../../test/core/search/following_topics/topic_test_utils.dart';

const scalabilityProfileId = '00000000-0000-4000-8000-00000000000c';
const scalabilityGroupId = '00000000-0000-4000-8000-000000000001';
final scalabilityEpoch = DateTime.utc(2026, 1, 1);

/// Counter wrappers are used in separate probes, never in timing samples.
class BookmarkReadCounter {
  var ids = 0;
  var dates = 0;
  var posts = 0;
  void reset() {
    ids = 0;
    dates = 0;
    posts = 0;
  }

  Map<String, int> toJson() => {
    'id_reads': ids,
    'date_reads': dates,
    'post_reads': posts,
  };
}

class ReadCountedBookmark extends Bookmark {
  ReadCountedBookmark(Bookmark value, this.counter)
    : super.fromSnapshot(
        id: value.id,
        createdAt: value.createdAt,
        updatedAt: value.updatedAt,
        snapshot: value.snapshot,
        post: value.post,
        postId: value.postId,
        sourceUrl: value.sourceUrl,
      );
  final BookmarkReadCounter counter;
  @override
  int get id {
    counter.ids++;
    return super.id;
  }

  @override
  DateTime get createdAt {
    counter.dates++;
    return super.createdAt;
  }

  @override
  Post get post {
    counter.posts++;
    return super.post;
  }
}

Bookmark scalabilityBookmark(
  int id, {
  int? upstreamId,
  DateTime? savedAt,
  DateTime? uploadedAt,
  String site = 'https://example.test',
  bool bookmarkable = true,
  BookmarkReadCounter? counter,
}) {
  final post = testSearchPost(upstreamId ?? id, uploadedAt).copyWith(
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: 0,
      source: site,
      profileIdHint: scalabilityProfileId,
    ),
  );
  final value = Bookmark.fromSnapshot(
    id: id,
    createdAt: savedAt ?? scalabilityEpoch.add(Duration(seconds: id % 31)),
    updatedAt: scalabilityEpoch,
    snapshot: const StoredPostCodec().encode(post),
    post: post,
    postId: bookmarkable ? post.id : null,
    sourceUrl: site,
  );
  return counter == null ? value : ReadCountedBookmark(value, counter);
}

BookmarkLibraryState scalabilityLibrary(
  List<Bookmark> bookmarks, {
  Set<int>? members,
}) => BookmarkLibraryState(
  bookmarks: bookmarks,
  groups: [
    BookmarkGroup(
      id: defaultBookmarkGroupId,
      name: 'Default',
      bookmarkIds: bookmarks.map((b) => b.id).toSet(),
    ),
    BookmarkGroup(
      id: scalabilityGroupId,
      name: 'Selected',
      bookmarkIds: members ?? bookmarks.map((b) => b.id).toSet(),
    ),
  ],
);

/// Counts visits to stored snapshot rows without replacing production decoders.
class ReadCountingList<T> extends ListBase<T> {
  ReadCountingList(Iterable<T> values) : _values = List.of(values);
  final List<T> _values;
  var reads = 0;
  @override
  int get length => _values.length;
  @override
  set length(int value) => throw UnsupportedError('Read-only fixture');
  @override
  T operator [](int index) {
    reads++;
    return _values[index];
  }

  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Read-only fixture');
}
