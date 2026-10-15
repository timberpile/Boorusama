import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../bulk_downloads/common.dart';

void main() {
  BoorusamaPostLink link({
    BooruType type = BooruType.danbooru,
    String site = 'https://danbooru.donmai.us',
    String key = 'id:42',
  }) => BoorusamaPostLink.parse(
    Uri(
      scheme: 'boorusama',
      host: 'post',
      path: '/open',
      queryParameters: {
        'v': '1',
        'engine': type.yamlName,
        'site': site,
        'key': key,
      },
    ).toString(),
  );

  test(
    'portable reference round trips without local identity or credentials',
    () {
      final post = dummyPost(id: 42).copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: 1,
          source: 'https://danbooru.donmai.us',
          profileIdHint: 'f9f749cb-7ea3-4d29-935e-744161c621ca',
        ),
      );
      const auth = BooruConfigAuth(
        booruId: 1,
        booruIdHint: 1,
        url: 'https://user:password@danbooru.donmai.us/?token=secret#private',
        apiKey: 'api-secret',
        login: 'private-login',
        passHash: null,
        proxySettings: null,
        networkSettings: null,
      );
      final result = BoorusamaPostLink.fromPost(post, auth: auth)!;
      expect(result, link());
      expect(BoorusamaPostLink.parse(result.uri.toString()), result);
      expect(result.postId, const NumericPostId(42));
      for (final secret in [
        'user',
        'password',
        'token',
        'secret',
        'private',
        'f9f749cb',
      ]) {
        expect(result.uri.toString(), isNot(contains(secret)));
      }
    },
  );

  test('a mixed-viewer fallback profile cannot change the source site', () {
    final post = dummyPost(id: 42).copyWith(
      origin: PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 1,
        source: 'https://source.test/booru',
      ),
    );
    final other = config('https://elsewhere.test').auth;
    expect(
      BoorusamaPostLink.fromPost(post, auth: other)!.site,
      Uri.parse('https://source.test/booru'),
    );
  });

  test(
    'Sankaku IDs are passed to the repository as strings, including digits',
    () {
      for (final key in ['id:12345', 'id:aB9_Z-x']) {
        final result = link(
          type: BooruType.sankaku,
          site: 'https://chan.sankakucomplex.com',
          key: key,
        );
        expect(result.postId, StringPostId(key.substring(3)));
        expect(BoorusamaPostLink.parse(result.uri.toString()), result);
      }
    },
  );

  test(
    'Pixiv preserves the page in a work rather than sharing a synthetic ID',
    () {
      final result = link(
        type: BooruType.pixiv,
        site: 'https://www.pixiv.net',
        key: 'work-page:123456:7',
      );
      expect(result.postId, const NumericPostId(123456007));
      expect(
        BoorusamaPostLink.parse(result.uri.toString()).key,
        'work-page:123456:7',
      );
      for (final key in [
        'id:123456007',
        'work-page:0:0',
        'work-page:12:-1',
        'work-page:12:1000',
        'work-page:9007199254740991:0',
      ]) {
        expect(
          () => link(type: BooruType.pixiv, key: key),
          throwsFormatException,
        );
      }
    },
  );

  test('legacy compound-engine snapshots never guess a portable ID', () {
    for (final type in [BooruType.sankaku, BooruType.pixiv]) {
      final post = dummyPost(id: 42).copyWith(
        origin: PostOrigin.fromSource(
          booruType: type,
          booruId: type.id,
          source: 'https://site.test',
        ),
        booruData: LegacyPostData(typeKey: type.yamlName, custom: const {}),
      );
      expect(BoorusamaPostLink.fromPost(post), isNull);
    }
  });

  test(
    'profile matching includes engine, port and base path, never sender ID',
    () {
      final result = link(site: 'https://EXAMPLE.test:8443/booru/');
      final first = config(
        'https://example.test:8443/booru',
        id: '00000000-0000-4000-8000-000000000001',
      );
      final second = config(
        'https://example.test:8443/booru/',
        id: '00000000-0000-4000-8000-000000000002',
      );
      expect(
        result.matchingProfiles([
          first,
          second,
          config('https://example.test:8443/other'),
          config('https://example.test/booru'),
          config('https://example.test:8443/booru', type: BooruType.moebooru),
        ]),
        [first, second],
      );
      expect(result.matchingProfiles([first]), [first]);
      expect(result.matchingProfiles([]), isEmpty);
    },
  );

  test(
    'credential-bearing, ambiguous, malformed or future links are rejected',
    () {
      final valid = link().uri;
      final bad = <String>[
        valid.replace(scheme: 'https').toString(),
        valid.replace(host: 'elsewhere').toString(),
        valid.replace(userInfo: 'user').toString(),
        valid.replace(port: 123).toString(),
        valid.replace(path: '/other').toString(),
        valid.replace(fragment: 'extra').toString(),
        '${valid.toString()}&key=id%3A43',
        '${valid.toString()}&cid=00000000-0000-4000-8000-000000000001',
        '${valid.toString()}&v=1',
        '${valid.toString()}%',
        ' ${valid.toString()}',
        '${valid.toString()}\n',
        'boorusama://post/open?${'a' * 4096}',
        for (final entry in <String, String>{
          'v': '2',
          'engine': 'nonexistent',
          'key': 'id:0',
        }.entries)
          valid
              .replace(
                queryParameters: {
                  ...valid.queryParameters,
                  entry.key: entry.value,
                },
              )
              .toString(),
        for (final site in [
          'file:///tmp/private',
          'https://user:pass@example.test',
          'https://example.test?api_key=secret',
          'https://example.test#fragment',
          'https://',
          'example.test',
          'https://example.test/\nfoo',
          'https://example.test:99999',
        ])
          valid
              .replace(
                queryParameters: {...valid.queryParameters, 'site': site},
              )
              .toString(),
        for (final key in [
          'id:-1',
          'id:01',
          'id:1.0',
          'id:9007199254740992',
          'id:abc',
          'id:42/other',
        ])
          valid
              .replace(queryParameters: {...valid.queryParameters, 'key': key})
              .toString(),
      ];
      for (final input in bad) {
        expect(
          () => BoorusamaPostLink.parse(input),
          throwsFormatException,
          reason: input,
        );
      }
    },
  );
}

BooruConfig config(
  String url, {
  BooruType type = BooruType.danbooru,
  String? id,
}) => BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: type,
    url: url,
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': id ?? '00000000-0000-4000-8000-000000000003',
});
