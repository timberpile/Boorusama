import 'dart:async';

import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_tag_index.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cooperative publication matches cold counts and ordering across merge boundaries', () async {
    for (final size in [0, 1, 255, 256, 257, 512, 513, 1025, 3000]) {
      final rows = [
        for (var id = 0; id < size; id++)
          _row(
            id,
            'https://a.test',
            {'shared', 'tag_$id'},
            artist: {'tag_$id'},
          ),
      ];
      var yields = 0;
      final builder = BookmarkTagIndexBuilder();
      final index = await builder.updateAsync(
        rows,
        isCurrent: () => true,
        yieldControl: () async {
          yields++;
        },
      );
      expect(
        index!.entries,
        BookmarkTagIndex.fromBookmarks(rows).entries,
        reason: 'size=$size',
      );
      expect(index.byName, BookmarkTagIndex.fromBookmarks(rows).byName);
      if (size > 0) expect(yields, greaterThan(0));
      expect(() => index.entries.clear(), throwsUnsupportedError);
      expect(() => index.byName.clear(), throwsUnsupportedError);
    }
  });

  for (final cancelAt in [1, 5, 40, 60]) {
    test(
      'superseding a build at yield $cancelAt cannot corrupt the next generation',
      () async {
        final builder = BookmarkTagIndexBuilder();
        final rows = [
          for (var id = 1; id <= 1200; id++)
            _row(id, 'https://a.test', {'shared', 'tag_$id'}),
        ];
        final before = builder.update(rows.take(2));
        final entered = Completer<void>();
        final resume = Completer<void>();
        var current = true;
        var yields = 0;
        final old = builder.updateAsync(
          rows,
          isCurrent: () => current,
          yieldControl: () async {
            if (++yields == cancelAt) {
              entered.complete();
              await resume.future;
            }
          },
        );
        await entered.future;
        current = false;
        final replacement = cancelAt == 5
            ? <Bookmark>[]
            : [
                _row(900, 'https://b.test', {'replacement'}),
              ];
        final next = builder.updateAsync(
          replacement,
          isCurrent: () => true,
          yieldControl: () async {},
        );
        resume.complete();
        expect(await old, isNull);
        expect(
          (await next)!.entries,
          BookmarkTagIndex.fromBookmarks(replacement).entries,
        );
        expect(before.byName['shared']!.count, 2);
      },
    );
  }

  test(
    'failed cooperative work does not poison the serialized builder',
    () async {
      var fail = true;
      final builder = BookmarkTagIndexBuilder(
        siteUrl: (row) {
          if (fail) throw StateError('controlled resolution failure');
          return row.sourceUrl;
        },
      );
      final rows = [
        _row(1, 'https://a.test', {'a'}),
      ];
      await expectLater(
        builder.updateAsync(
          rows,
          isCurrent: () => true,
          yieldControl: () async {},
        ),
        throwsStateError,
      );
      fail = false;
      expect(
        (await builder.updateAsync(
          rows,
          isCurrent: () => true,
          yieldControl: () async {},
        ))!.entries,
        BookmarkTagIndex.fromBookmarks(rows).entries,
      );
    },
  );

  test(
    '20,000-row updates process only changed snapshots and retain old results',
    () {
      var processed = 0;
      final builder = BookmarkTagIndexBuilder(
        siteUrl: (bookmark) {
          processed++;
          return bookmark.sourceUrl;
        },
      );
      final rows = [
        for (var id = 1; id <= 20000; id++)
          Bookmark.empty.copyWith(id: id, tags: {'shared', 'tag_${id % 11}'}),
      ];
      final original = builder.update(rows);
      expect(processed, 20000);
      expect(identical(builder.update(rows.reversed), original), isTrue);
      expect(processed, 20000);
      final removed = builder.update(rows.skip(1));
      expect(processed, 20001);
      expect(original.byName['shared']!.count, 20000);
      expect(removed.byName['shared']!.count, 19999);
      expect(
        identical(original.byName['tag_2'], removed.byName['tag_2']),
        isTrue,
      );
      expect(
        removed.entries,
        BookmarkTagIndex.fromBookmarks(rows.skip(1)).entries,
      );
      final restored = builder.update(rows);
      expect(processed, 20002);
      expect(restored.entries, original.entries);
    },
  );

  test(
    'removal, replacement, Undo and reload match cold source/category counts',
    () {
      final a = _row(
        1,
        'https://a.test',
        {'ONE PIECE', 'one_piece'},
        artist: {'one_piece'},
      );
      final b = _row(
        2,
        'https://a.test',
        {'one_piece'},
        character: {'ONE PIECE'},
      );
      final c = _row(
        3,
        'https://b.test',
        {'one_piece', 'other'},
        artist: {'one_piece'},
      );
      final unknown = _row(4, 'https://a.test', {'one_piece'});
      final replacement = _row(
        2,
        'https://b.test',
        {'new', 'one_piece'},
        copyright: {'one_piece'},
      );
      final builder = BookmarkTagIndexBuilder();
      final original = builder.update([a, b, c, unknown]);
      for (final rows in [
        [a, b, unknown],
        [b, unknown],
        [unknown],
        [c, unknown],
        [c, unknown, a.copyWith(id: 15)],
        [c, unknown, replacement],
        <Bookmark>[],
        [a.copyWith(), b.copyWith(), c.copyWith(), unknown.copyWith()],
      ]) {
        final next = builder.update(rows);
        expect(next.entries, BookmarkTagIndex.fromBookmarks(rows).entries);
        expect(next.byName, BookmarkTagIndex.fromBookmarks(rows).byName);
      }
      expect(original.byName['one_piece']!.count, 4);
      expect(original.byName['one_piece']!.sources.values.first, {
        'artist',
        'character',
      });
      expect(() => original.byName.clear(), throwsUnsupportedError);
      expect(
        () => original.byName['one_piece']!.sources.values.first.clear(),
        throwsUnsupportedError,
      );
    },
  );
}

Bookmark _row(
  int id,
  String source,
  Set<String> tags, {
  Set<String>? artist,
  Set<String>? character,
  Set<String>? copyright,
}) {
  final base = Bookmark.empty;
  return base.copyWith(
    id: id,
    sourceUrl: source,
    post: Post(
      origin: base.post.origin,
      booruData: base.post.booruData,
      core: PostCoreData(
        id: id,
        thumbnailImageUrl: '',
        sampleImageUrl: '',
        originalImageUrl: '',
        videoUrl: '',
        videoThumbnailUrl: '',
        width: 1,
        height: 1,
        format: 'jpg',
        md5: '',
        fileSize: 1,
        duration: 0,
        tags: tags,
        rating: Rating.general,
        hasComment: false,
        isTranslated: false,
        hasParentOrChildren: false,
        source: PostSource.none(),
        score: 0,
        artistTags: artist,
        characterTags: character,
        copyrightTags: copyright,
      ),
    ),
  );
}
