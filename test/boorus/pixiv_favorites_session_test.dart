import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/favorites/session.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final origin = postOriginFromConfig(
    BooruConfig.defaultConfig(
      booruType: BooruType.pixiv,
      url: 'https://www.pixiv.net',
      customDownloadFileNameFormat: null,
    ),
  );

  test('sequential cursors, retry, terminal page and refresh', () async {
    final cursors = <String?>[];
    var fail = true;
    final session = PixivFavoritesSession(
      origin: origin,
      load: (cursor, token) async {
        cursors.add(cursor);
        if (cursor == '90' && fail) {
          fail = false;
          throw StateError('fixture');
        }
        return PixivBookmarkPage(
          const [],
          nextBookmarkId: cursor == null ? '90' : null,
        );
      },
    );
    addTearDown(session.dispose);
    expect((await session.getPosts(1).run()).isRight(), isTrue);
    expect((await session.getPosts(2).run()).isLeft(), isTrue);
    expect((await session.getPosts(2).run()).isRight(), isTrue);
    expect((await session.getPosts(3).run()).isRight(), isTrue);
    expect(cursors, [null, '90', '90']);
    await session.getPosts(1).run();
    expect(cursors.last, isNull);
  });

  test(
    'dispose cancels a pending source and prevents publishing its result',
    () async {
      final gate = Completer<PixivBookmarkPage>();
      var cancelled = false;
      final session = PixivFavoritesSession(
        origin: origin,
        load: (_, token) {
          token.whenCancel.then((_) => cancelled = true);
          return gate.future;
        },
      );
      final result = session.getPosts(1).run();
      await Future<void>.value();
      session.dispose();
      gate.complete(const PixivBookmarkPage([]));
      expect((await result).isLeft(), isTrue);
      expect(cancelled, isTrue);
    },
  );

  test('independent account/filter sessions do not share cursors', () async {
    final seenA = <String?>[];
    final seenB = <String?>[];
    PixivFavoritesSession create(List<String?> seen) => PixivFavoritesSession(
      origin: origin,
      load: (cursor, _) async {
        seen.add(cursor);
        return PixivBookmarkPage(
          const [],
          nextBookmarkId: cursor == null ? '90' : null,
        );
      },
    );
    final a = create(seenA), b = create(seenB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.getPosts(1).run();
    await a.getPosts(2).run();
    await b.getPosts(1).run();
    expect(seenA, [null, '90']);
    expect(seenB, [null]);
  });

  test(
    'keeps final-page posts, origin and source continuation after filtering',
    () async {
      PixivIllustDto artwork(
        int id, {
        bool visible = true,
      }) => PixivIllustDto.fromJson({
        'id': id,
        'type': 'illust',
        'user': {'id': 5, 'name': 'Fixture'},
        'page_count': 1,
        'visible': visible,
        'image_urls': {'medium': 'https://i.pximg.net/img-master/${id}_p0.jpg'},
        'meta_single_page': {
          'original_image_url': 'https://i.pximg.net/img-original/${id}_p0.jpg',
        },
      });
      final session = PixivFavoritesSession(
        origin: origin,
        load: (cursor, _) async => cursor == null
            ? PixivBookmarkPage([
                artwork(100, visible: false),
              ], nextBookmarkId: '90')
            : PixivBookmarkPage([artwork(101)]),
      );
      addTearDown(session.dispose);
      (await session.getPosts(1).run()).fold((_) => fail('Unexpected error'), (
        page,
      ) {
        expect(page.posts, isEmpty);
        expect(page.hasMore, isTrue);
        expect(page.total, isNull);
      });
      (await session.getPosts(2).run()).fold((_) => fail('Unexpected error'), (
        page,
      ) {
        expect(page.posts, hasLength(1));
        expect(page.posts.single.origin, origin);
        expect(page.hasMore, isFalse);
        expect(page.maxPage, 2);
      });
    },
  );
}
