import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/links/boorusama_search_link.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boorusama_post_link_test.dart' show config;

void main() {
  BoorusamaSearchLink link({
    String site = 'https://site.test',
    BooruType type = BooruType.danbooru,
    String mode = 'raw',
    String query = 'one_piece -rating:s',
  }) => BoorusamaSearchLink.parse(
    Uri(
      scheme: 'boorusama',
      host: 'search',
      path: '/open',
      queryParameters: {
        'v': '1',
        'engine': type.yamlName,
        'site': site,
        'mode': mode,
        'q': query,
      },
    ).toString(),
  );

  test('raw search round trips without local profile identities', () {
    final profile = config('https://site.test');
    final result = BoorusamaSearchLink.fromRaw(
      auth: profile.auth,
      query: 'one_piece -rating:s',
    )!;
    expect(result, link());
    expect(result.uri.toString(), startsWith('boorusama://search/open?'));
    expect(result.searchParams.query, 'one_piece -rating:s');
    expect(result.searchParams.queryType, QueryType.simple);
    expect(result.searchParams.tags, isNull);
    expect(BoorusamaSearchLink.parse(result.uri.toString()), result);
    expect(result.matchingProfiles([profile]), [profile]);
    expect(result.matchingProfiles([]), isEmpty);
  });

  test('typed filters retain order, operators, and token boundaries', () {
    final profile = config('https://site.test');
    final tags = ['one_piece', '-rating:s', 'user:artist_name'];
    final result = BoorusamaSearchLink.fromTags(
      auth: profile.auth,
      tags: tags,
    )!;
    expect(result.isRaw, isFalse);
    expect(result.typedTags, tags);
    expect(result.searchParams.queryType, QueryType.list);
    expect(result.searchParams.tags!.list, tags);
    expect(result.searchParams.query, isNull);
    expect(BoorusamaSearchLink.parse(result.uri.toString()), result);
  });

  test('only the site and engine identify a recipient profile', () {
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
        config('https://example.test:8443/different'),
        config('https://example.test/booru'),
        config('https://example.test:8443/booru', type: BooruType.moebooru),
      ]),
      [first, second],
    );
  });

  test('sender credentials never leak into the portable site URL', () {
    const auth = BooruConfigAuth(
      booruId: 1,
      booruIdHint: 1,
      url: 'https://user:pass@site.test/booru?token=secret#fragment',
      apiKey: 'api-secret',
      login: 'private-login',
      passHash: null,
      proxySettings: null,
      networkSettings: null,
    );
    final result = BoorusamaSearchLink.fromRaw(
      auth: auth,
      query: 'one_piece',
    )!;
    expect(result.site.toString(), 'https://site.test/booru');
    for (final secret in ['pass', 'token', 'private-login', 'api-secret']) {
      expect(result.uri.toString(), isNot(contains(secret)));
    }
  });

  test('bad version, URL, structure and duplicates are rejected', () {
    final valid = link().uri;
    final bad = [
      valid.replace(scheme: 'https').toString(),
      valid.replace(host: 'post').toString(),
      valid.replace(path: '/wrong').toString(),
      valid.replace(fragment: 'fragment').toString(),
      valid.replace(userInfo: 'name').toString(),
      valid.replace(port: 5000).toString(),
      '$valid&mode=raw',
      '$valid&local_profile_id=secret',
      '$valid&v=1',
      '$valid%',
      ' $valid',
      '$valid\n',
      for (final (field, value) in [
        ('v', '2'),
        ('engine', 'fake'),
        ('q', ''),
        ('q', ' one_piece'),
        ('q', 'one_piece\nsecret'),
        ('mode', 'unknown'),
      ])
        valid
            .replace(
              queryParameters: {...valid.queryParameters, field: value},
            )
            .toString(),
      for (final site in [
        'https://user:pass@site.test',
        'https://site.test?token=private',
        'https://site.test#fragment',
        'file:///etc/passwd',
        'https://',
        'site.test',
        'https://site.test:99999',
      ])
        valid
            .replace(
              queryParameters: {...valid.queryParameters, 'site': site},
            )
            .toString(),
    ];
    for (final uri in bad) {
      expect(
        () => BoorusamaSearchLink.parse(uri),
        throwsFormatException,
        reason: uri,
      );
    }
  });

  test('typed JSON rejects empty, malformed or ambiguous filters', () {
    for (final bad in [
      '[]',
      '[4]',
      '[""]',
      '[" one_piece"]',
      '["one_piece "]',
      '{"tags":["one_piece"]}',
      'broken json',
    ]) {
      expect(
        () => link(mode: 'tags', query: bad),
        throwsFormatException,
        reason: bad,
      );
    }
    expect(
      () => link(mode: 'tags', query: '[${List.filled(65, '"a"').join(',')}]'),
      throwsFormatException,
    );
  });

  test('invalid or too-long search is not shareable', () {
    final auth = config('https://site.test').auth;
    expect(BoorusamaSearchLink.fromRaw(auth: auth, query: ''), isNull);
    expect(BoorusamaSearchLink.fromRaw(auth: auth, query: '  '), isNull);
    expect(
      BoorusamaSearchLink.fromRaw(
        auth: auth,
        query: List.filled(BoorusamaSearchLink.maxQueryLength + 1, 'a').join(),
      ),
      isNull,
    );
    expect(BoorusamaSearchLink.fromTags(auth: auth, tags: []), isNull);
    expect(BoorusamaSearchLink.fromTags(auth: auth, tags: ['ok', ' ']), isNull);
  });
}
