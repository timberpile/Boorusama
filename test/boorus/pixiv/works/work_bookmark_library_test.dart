import 'dart:convert';

import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_series_projection.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:flutter_test/flutter_test.dart';

import 'work_test_fixtures.dart';

const _works = '22222222-2222-4222-8222-222222222222';
const _pages = '33333333-3333-4333-8333-333333333333';

void main() {
  final access = workAccess();
  final dto = work();
  final at = DateTime.utc(2026);
  final workBookmark = PixivWorkBookmarkTarget(
    access: access,
    summary: pixivWorkSummary(dto, access),
    details: pixivWorkDetails(dto, access),
  ).draft(currentAccess: access, at: at).copyWith(id: 7);
  final pageBookmark = PixivPageBookmarkTarget(
    access: access,
    post: pixivWorkPagePosts(dto, access).last,
  ).draft(currentAccess: access, at: at).copyWith(id: 8);
  final groups = [
    BookmarkGroup(
      id: _works,
      name: 'Works',
      bookmarkIds: const {7},
      addedAt: {7: at.add(const Duration(days: 2))},
    ),
    BookmarkGroup(
      id: _pages,
      name: 'Pages',
      bookmarkIds: const {8},
      addedAt: {8: at.add(const Duration(days: 1))},
    ),
  ];
  final state = BookmarkLibraryState(
    bookmarks: [pageBookmark],
    records: [workBookmark, pageBookmark],
    groups: groups,
  );

  List<BookmarkGridEntry> select({
    BookmarkView view = const BookmarkView.all(),
    List<String> tags = const [],
    String? source,
    Set<int>? available,
  }) => selectBookmarkGridEntries(
    state: state,
    view: view,
    selectedTags: tags,
    selectedBooruUrl: source,
    availableNativeGroupIds: available,
    sortType: BookmarkSortType.newest,
  );

  test(
    'native Work and real Page retain distinct grid and filtered-media indices',
    () {
      final entries = select();
      expect(entries, hasLength(2));
      expect(entries.first, isA<BookmarkNativeGroupEntry>());
      expect(entries.last, isA<BookmarkPostEntry>());
      expect(
        select(view: BookmarkView.group(_works)).single,
        isA<BookmarkNativeGroupEntry>(),
      );
      expect(
        select(view: BookmarkView.group(_pages)).single,
        isA<BookmarkPostEntry>(),
      );
      final visible = visibleBookmarkGridEntries(entries, [pageBookmark.post]);
      expect(visible.entries, entries);
      expect(visible.postIndices, {entries.last.key: 0});
      final filtered = visibleBookmarkGridEntries(entries, const []);
      expect(filtered.entries.single, same(entries.first));
      expect(filtered.postIndices, isEmpty);
    },
  );

  test(
    'Work search and availability remain local and independent from Page rows',
    () {
      expect(select(tags: ['fixture']), hasLength(2));
      expect(select(tags: ['-fixture']), isEmpty);
      expect(select(tags: ['unknown']), isEmpty);
      expect(select(source: 'www.pixiv.net'), hasLength(2));
      expect(select(source: 'foreign.example'), isEmpty);
      expect(select(available: const {}).single, isA<BookmarkPostEntry>());
    },
  );

  test('v10 backup keeps Work/Page identities, cover policy and separate memberships', () {
    final codec = BookmarkBackupCodec(
      postDataCodec: (_) => const PixivPostCodec(),
    );
    final data = BookmarkBackupData.unified(
      records: state.records,
      groups: [
        for (final group in groups)
          BookmarkGroupBackup(
            id: group.id,
            name: group.name,
            bookmarkIds: group.bookmarkIds.toList(),
            addedAt: group.addedAt,
          ),
      ],
    );
    final wire = jsonEncode({
      'version': 10,
      'data': codec.encode(data),
      ...data.extraFields,
    });
    final restored = codec.parse(decodeData(data: wire));
    expect(restored.records, hasLength(2));
    final whole = restored.records.whereType<ContentGroupBookmark>().single;
    final page = restored.records.whereType<PostBookmark>().single;
    expect(whole.reference.sourceKey, 'work:120');
    expect(page.post.pixivData!.stableBookmarkPostKey, 'work-page:120:2');
    expect(
      whole.summary.cover!.visibility,
      workBookmark.summary.cover!.visibility,
    );
    expect(
      whole.snapshot.details!.description,
      workBookmark.snapshot.details!.description,
    );
    expect(
      restored.groups.singleWhere((group) => group.id == _works).bookmarkIds,
      [whole.id],
    );
    expect(
      restored.groups.singleWhere((group) => group.id == _pages).bookmarkIds,
      [page.id],
    );
    expect(wire, isNot(contains('work-page:120:1')));
    expect(wire, isNot(contains('original/120_p1')));
  });
}
