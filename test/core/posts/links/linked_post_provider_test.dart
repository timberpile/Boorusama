import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/sankaku/posts/post_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:boorusama/core/posts/links/linked_post_provider.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../../../bulk_downloads/common.dart';
import 'boorusama_post_link_test.dart' show config;

class _Repository extends Fake implements PostRepository<Post> {
  Post? result;
  BooruError? error;
  final ids = <PostId>[];
  @override
  PostOrError<Post> getPost(PostId id, {PostFetchOptions? options}) {
    ids.add(id);
    return error == null ? TaskEither.right(result) : TaskEither.left(error!);
  }
}

void main() {
  Future<Post?> load(
    _Repository repository,
    BoorusamaPostLink link,
    BooruConfig profile,
  ) async {
    final container = ProviderContainer(
      overrides: [
        originAwarePostRepoProvider.overrideWith(
          (ref, config) => OriginAwarePostRepository.fromConfig(
            delegate: repository,
            config: config,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(linkedPostProvider((link, profile)).future);
  }

  BoorusamaPostLink link(BooruType type, String key) => BoorusamaPostLink.parse(
    Uri(
      scheme: 'boorusama',
      host: 'post',
      path: '/open',
      queryParameters: {
        'v': '1',
        'engine': type.yamlName,
        'site': 'https://site.test',
        'key': key,
      },
    ).toString(),
  );

  test(
    'fetch uses the exact recipient profile and verifies the returned ID',
    () async {
      final profile = config('https://site.test');
      final repository = _Repository()..result = dummyPost(id: 42);
      final result = await load(
        repository,
        link(BooruType.danbooru, 'id:42'),
        profile,
      );
      expect(result!.id, 42);
      expect(result.origin.profileIdHint, profile.id);
      expect(result.origin.sourceHost, 'site.test');
      expect(repository.ids, [const NumericPostId(42)]);
      repository.result = dummyPost(id: 43);
      expect(
        await load(repository, link(BooruType.danbooru, 'id:42'), profile),
        isNull,
      );
    },
  );

  test('wrong site or engine is rejected before any request', () async {
    final repository = _Repository()..result = dummyPost(id: 42);
    final reference = link(BooruType.danbooru, 'id:42');
    expect(
      await load(repository, reference, config('https://wrong.test')),
      isNull,
    );
    expect(
      await load(
        repository,
        reference,
        config('https://site.test', type: BooruType.moebooru),
      ),
      isNull,
    );
    expect(repository.ids, isEmpty);
  });

  test(
    'Sankaku uses its server identity rather than a generated numeric ID',
    () async {
      const data = SankakuPostData(
        sankakuId: SankakuPostIdData(value: 'abc123', isNumeric: false),
        isFavorited: false,
        favoriteCount: 0,
        artistDetailsTags: [],
        characterDetailsTags: [],
        copyrightDetailsTags: [],
        generalDetailsTags: [],
        metaDetailsTags: [],
      );
      final profile = config('https://site.test', type: BooruType.sankaku);
      final repository = _Repository()
        ..result = dummyPost(id: 999).copyWith(booruData: data);
      final result = await load(
        repository,
        link(BooruType.sankaku, 'id:abc123'),
        profile,
      );
      expect(result, isNotNull);
      expect(repository.ids, [const StringPostId('abc123')]);
      expect(BoorusamaPostLink.fromPost(result!)!.key, 'id:abc123');
    },
  );

  test(
    'Pixiv verifies the page returned by the repository and round trips it',
    () async {
      final profile = config('https://site.test', type: BooruType.pixiv);
      final repository = _Repository()
        ..result = dummyPost(id: 123001).copyWith(booruData: _pixivData(1));
      final reference = link(BooruType.pixiv, 'work-page:123:1');
      final result = await load(repository, reference, profile);
      expect(result, isNotNull);
      expect(repository.ids, [const NumericPostId(123001)]);
      expect(BoorusamaPostLink.fromPost(result)!, reference);
      repository.result = dummyPost(
        id: 123001,
      ).copyWith(booruData: _pixivData(0));
      expect(await load(repository, reference, profile), isNull);
    },
  );

  test(
    'repository errors remain errors, not misleading missing-post results',
    () async {
      final error = ServerError(
        httpStatusCode: 403,
        message: 'private diagnostics',
      );
      final repository = _Repository()..error = error;
      await expectLater(
        load(
          repository,
          link(BooruType.danbooru, 'id:42'),
          config('https://site.test'),
        ),
        throwsA(same(error)),
      );
    },
  );
}

PixivPostData _pixivData(int page) => PixivPostData(
  illustId: 123,
  pageIndex: page,
  pageCount: 2,
  userId: 7,
  userName: 'artist',
  userAccount: 'artist',
  illustType: PixivIllustType.unknown,
  totalBookmarks: 0,
  totalView: 0,
  aiType: 0,
  seriesTitle: null,
  isUgoira: false,
  isRestricted: false,
);
