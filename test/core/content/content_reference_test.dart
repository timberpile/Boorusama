import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/following_topics/topic_test_utils.dart';

void main() {
  const codec = ContentReferenceCodec();
  ContentReference address({
    BooruType engine = BooruType.danbooru,
    String site = 'https://EXAMPLE.test:8443/booru/',
    ContentKind kind = ContentKind.post,
    String key = 'id:123',
  }) => codec.parse(
    engine: engine,
    site: Uri.parse(site),
    kind: kind,
    sourceKey: key,
  );

  test(
    'semantic identity preserves deployed namespace separately from locator',
    () {
      final http = address(site: 'http://example.test/booru/');
      final https = address(site: 'https://example.test/booru');
      expect(http.identity, https.identity);
      expect(http, isNot(https));
      expect(http.site.toString(), 'http://example.test/booru');
      expect(address().siteNamespace, 'example.test:8443/booru');
      expect(address().identity, isNot(https.identity));
      expect(
        address(site: 'https://example.test/other').identity,
        isNot(https.identity),
      );
      expect(
        address(site: 'https://alias.test/booru').identity,
        isNot(https.identity),
      );
      final otherEngine = address(
        engine: BooruType.e621,
        site: 'http://example.test/booru',
      );
      expect(otherEngine.identity, http.identity);
      expect(otherEngine, isNot(http));
      expect(
        () => codec.requireCompatible(http, otherEngine),
        throwsFormatException,
      );
    },
  );

  test('resource grammar separates Post, Pool, Related and Work/Page', () {
    final post = address(key: 'id:42');
    final pool = address(kind: ContentKind.group, key: 'pool:42');
    final related = address(kind: ContentKind.group, key: 'related:42');
    expect({post.identity, pool.identity, related.identity}, hasLength(3));
    final work = address(
      engine: BooruType.pixiv,
      kind: ContentKind.group,
      key: 'work:120',
    );
    final page = address(engine: BooruType.pixiv, key: 'work-page:120:2');
    expect(work.identity, isNot(page.identity));
    expect(page.sourceKey, 'work-page:120:2');
    expect(
      const BooruContentKeyCodec(BooruType.pixiv).postIdFor(page.sourceKey),
      const NumericPostId(120002),
    );
    expect(
      const BooruContentKeyCodec(BooruType.sankaku).postIdFor('id:abc_9-z'),
      const StringPostId('abc_9-z'),
    );
    expect(
      () => address(
        engine: BooruType.e621,
        kind: ContentKind.group,
        key: 'pool:42',
      ),
      throwsFormatException,
    );
    expect(
      () => address(key: 'pool:42'),
      throwsFormatException,
    );
  });

  test(
    'explicit source binding preserves HTTP instead of inventing transport',
    () {
      final post = testSearchPost(123, DateTime.utc(2026)).copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: 1,
          source: 'http://example.test:8080/install',
        ),
      );
      final reference = codec.fromPost(
        post,
        site: Uri.parse('http://example.test:8080/install/'),
      )!;
      expect(reference.sourceKey, 'id:123');
      expect(reference.site.toString(), 'http://example.test:8080/install');
      expect(
        codec.fromPost(post),
        isNull,
        reason: 'A namespace cannot prove the lost transport scheme',
      );
      expect(
        codec.fromPost(post, site: Uri.parse('https://other.test')),
        isNull,
      );
      expect(
        codec.fromPost(
          post.copyWith(origin: PostOrigin.forBooruType(BooruType.unknown)),
        ),
        isNull,
      );
      final legacy = post.copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.pixiv,
          booruId: 1,
          source: 'https://www.pixiv.net',
        ),
      );
      expect(
        codec.fromPost(legacy, site: Uri.parse('https://www.pixiv.net')),
        isNull,
      );
    },
  );

  test('versioned codecs normalize dynamic Hive maps defensively', () {
    final value = address();
    final hive = <Object?, Object?>{
      for (final e in codec.encode(value).entries) e.key: e.value,
    };
    expect(codec.decode(hive), value);
    expect(() => codec.decode({...hive, 'version': 2}), throwsFormatException);
    expect(
      () => codec.decode({...hive, 'engine': 'future_engine'}),
      throwsFormatException,
    );
    expect(
      () => codec.decode({...hive, 'kind': 'work'}),
      throwsFormatException,
    );
    expect(() => codec.decode({...hive, 'key': 'id:0'}), throwsFormatException);
  });

  for (final site in [
    'file:///tmp/data',
    'https://user:pass@example.test',
    'https://example.test/x?q=1',
    'https://example.test/#part',
    'https://example.test/a/%2e%2e/b',
    'https://example.test/a%2fb',
    'https://example.test/%zz',
    'https://example.test/%0a',
    'https://example.test:0',
  ]) {
    test('rejects unsafe locator $site', () {
      expect(
        () => codec.decode({
          'version': 1,
          'engine': 'danbooru',
          'site': site,
          'kind': 'post',
          'key': 'id:1',
        }),
        throwsFormatException,
      );
    });
  }

  for (final key in [
    'id:0',
    'id:-1',
    'id:01',
    'id:9007199254740992',
    'id:1/2',
    'id:1?x=2',
  ]) {
    test(
      'rejects invalid numeric key $key',
      () => expect(() => address(key: key), throwsFormatException),
    );
  }
  for (final key in [
    'work-page:120:1000',
    'work-page:120:02',
    'work-page:0:0',
    'work-page:9007199254740991:0',
  ]) {
    test(
      'rejects invalid Page key $key',
      () => expect(
        () => address(engine: BooruType.pixiv, key: key),
        throwsFormatException,
      ),
    );
  }
}
