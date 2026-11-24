import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/cache/persistent_cache_store.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_presentation_covers.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';
import 'package:boorusama/core/cache/hive_persistent_cache_store.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/memory_repositories.dart';

PoolBookmarkCover cover(String name) => PoolBookmarkCover(
  thumbnail: 'https://cdn.donmai.us/$name.jpg',
  sample: 'https://cdn.donmai.us/$name.jpg',
  original: 'https://cdn.donmai.us/$name.jpg',
  variants: const {},
  postId: 1,
  visibility: GroupCoverVisibility(
    tags: const {'cat'},
    rating: 'general',
    deleted: false,
    banned: false,
    postFacts: const {
      'score': 15,
      'source': 'https://pixiv.net/works/1',
      'uploaderName': 'artist',
      'uploaderId': 5,
      'downvotes': 2,
    },
  ),
);

class _FailedWrite implements PersistentCacheStore {
  final delegate = MemoryPersistentCacheStore();
  @override
  Iterable<String> get keys => delegate.keys;
  @override
  int get length => delegate.length;
  @override
  String? get(String key) => delegate.get(key);
  @override
  Future<void> clear() => delegate.clear();
  var fail = true;
  @override
  Future<void> put(String key, String value) async {
    await delegate.put(key, value);
    if (fail) throw StateError('disk write failed after cache update');
  }
}

void main() {
  test('policy changes suppress and restore the same persisted cover', () {
    final selected = cover('chosen');
    final bytes = jsonEncode(selected.toJson());
    final config = BooruConfig.defaultConfig(
      booruType: BooruType.danbooru,
      url: 'https://danbooru.donmai.us',
      customDownloadFileNameFormat: null,
    );
    expect(bookmarkCoverAllowed(selected, config, {}), isTrue);
    for (final pattern in [
      'cat',
      'source:*pixiv*',
      'uploader:artist',
      'uploaderid:5',
      '-score:<10',
      'downvotes:>1',
    ]) {
      expect(
        bookmarkCoverAllowed(selected, config, {pattern}),
        isFalse,
        reason: pattern,
      );
      expect(jsonEncode(selected.toJson()), bytes);
      expect(bookmarkCoverAllowed(selected, config, {}), isTrue);
    }
    expect(
      bookmarkCoverAllowed(
        PoolBookmarkCover(
          thumbnail: selected.thumbnail,
          sample: selected.sample,
          original: selected.original,
          variants: const {},
        ),
        config,
        {},
      ),
      isFalse,
    );
  });
  test('receiver choice survives a real Hive restart and is never replaced by another candidate', () async {
    final dir = await Directory.systemTemp.createTemp('sticky-cover');
    Hive.init(dir.path);
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final box = await Hive.openBox<String>('choices');
    final first = BookmarkPresentationCovers(HivePersistentCacheStore(box));
    await first.remember('revision', cover('chosen'), current: () => true);
    final bytes = box.get(BookmarkPresentationCovers.storageKey);
    await box.close();
    final reopened = await Hive.openBox<String>('choices');
    final next = BookmarkPresentationCovers(HivePersistentCacheStore(reopened));
    expect(next.selected('revision'), cover('chosen'));
    await next.remember('revision', cover('other'), current: () => true);
    expect(reopened.get(BookmarkPresentationCovers.storageKey), bytes);
    expect(next.selected('replaced-revision'), isNull);
    await next.remember('revoked', cover('other'), current: () => false);
    expect(next.selected('revoked'), isNull);
  });
  test(
    'failed cache write is not a confirmed choice and can be retried',
    () async {
      final store = _FailedWrite();
      final choices = BookmarkPresentationCovers(store);
      await expectLater(
        choices.remember('revision', cover('chosen'), current: () => true),
        throwsStateError,
      );
      expect(choices.selected('revision'), isNull);
      store.fail = false;
      await choices.remember('revision', cover('chosen'), current: () => true);
      expect(choices.selected('revision'), cover('chosen'));
      expect(
        BookmarkPresentationCovers(store).selected('revision'),
        cover('chosen'),
      );
    },
  );
}
