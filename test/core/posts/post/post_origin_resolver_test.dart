// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import '../../../profile_uuid_utils.dart';

void main() {
  const resolver = PostOriginResolver();

  test('discards an old numeric profile hint safely', () {
    final snapshot = PostOriginSnapshot.fromJson({
      'booruTypeId': BooruType.danbooru.id,
      'booruId': 20,
      'sourceHost': 'danbooru.donmai.us',
      'profileIdHint': 12,
    });

    expect(snapshot.profileIdHint, isNull);
    expect(snapshot.toJson(), isNot(contains('profileIdHint')));
  });

  test('normalizes one installation across schemes and URL decoration', () {
    final origin = PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: 20,
      source: 'http://user:pass@EXAMPLE.com:80/Artwork/booru///?q=cat#top',
    );

    expect(origin.sourceHost, 'example.com/Artwork/booru');
    expect(
      normalizePostSourceHost('https://example.com:443/Artwork/booru/'),
      origin.sourceHost,
    );
    expect(
      normalizePostSourceHost('https://example.com:8443/Artwork/booru'),
      'example.com:8443/Artwork/booru',
    );
  });

  test('preserves an explicit nondefault port through snapshot reload', () {
    final source = PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: BooruType.danbooru.id,
      source: 'http://example.com:443/board/',
    );
    final reloaded = PostOrigin.fromSnapshot(source.toSnapshot());

    expect(source.sourceHost, 'example.com:443/board');
    expect(reloaded.sourceHost, source.sourceHost);
    expect(normalizePostSourceHost('example.com:443/board'), source.sourceHost);
    expect(
      normalizePostSourceHost('https://example.com:443/board'),
      'example.com/board',
    );
  });

  test('keeps encoded and case-sensitive installation paths distinct', () {
    expect(
      normalizePostSourceHost('https://example.com/Art%20Box/'),
      'example.com/Art%20Box',
    );
    expect(
      normalizePostSourceHost('https://example.com/Art Box'),
      'example.com/Art%20Box',
    );
    expect(
      normalizePostSourceHost('https://example.com/art%20box'),
      isNot('example.com/Art%20Box'),
    );
    expect(
      normalizePostSourceHost('https://example.com/a%2Fb'),
      isNot(normalizePostSourceHost('https://example.com/a/b')),
    );
  });

  test('keeps IPv6 literals and ports reparseable', () {
    final source = normalizePostSourceHost('http://[::1]:8080/board/');

    expect(source, '[::1]:8080/board');
    expect(normalizePostSourceHost(source), source);
    expect(
      normalizePostSourceHost('https://[::1]:443/board'),
      '[::1]/board',
    );
  });

  test('invalid or empty source has no installation identity', () {
    expect(normalizePostSourceHost(''), isEmpty);
    expect(normalizePostSourceHost('https://'), isEmpty);
  });

  test('resolves only the installation matching the full site path', () {
    final expected = _config(
      id: profileUuid(2),
      type: BooruType.danbooru,
      url: 'https://example.com/second/',
    );
    final result = resolver.resolve(
      PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 20,
        source: 'http://example.com/second',
      ),
      [
        _config(
          id: profileUuid(1),
          type: BooruType.danbooru,
          url: 'https://example.com/first/',
        ),
        expected,
      ],
    );

    expect(result, ResolvedPostOrigin(expected));
  });

  test('a matching profile hint resolves that exact profile', () {
    final expected = _config(
      id: profileUuid(2),
      type: BooruType.danbooru,
      url: 'https://danbooru.donmai.us/',
    );

    final result = resolver.resolve(
      PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 20,
        source: 'https://danbooru.donmai.us/',
        profileIdHint: profileUuid(2),
      ),
      [
        _config(
          id: profileUuid(1),
          type: BooruType.danbooru,
          url: 'https://donmai.moe/',
        ),
        expected,
      ],
    );

    expect(result, ResolvedPostOrigin(expected));
  });

  test('a stale profile hint falls back to one engine and host match', () {
    final expected = _config(
      id: profileUuid(9),
      type: BooruType.e621,
      url: 'https://e621.net/',
    );

    final result = resolver.resolve(
      PostOrigin.fromSource(
        booruType: BooruType.e621,
        booruId: 25,
        source: 'https://E621.NET:443/',
        profileIdHint: profileUuid(404),
      ),
      [expected],
    );

    expect(result, ResolvedPostOrigin(expected));
  });

  test('multiple engine and host matches are ambiguous', () {
    final result = resolver.resolve(
      PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 20,
        source: 'danbooru.donmai.us',
      ),
      [
        _config(
          id: profileUuid(1),
          type: BooruType.danbooru,
          url: 'https://danbooru.donmai.us/',
        ),
        _config(
          id: profileUuid(2),
          type: BooruType.danbooru,
          url: 'https://danbooru.donmai.us/',
        ),
      ],
    );

    expect(result, const AmbiguousPostOrigin());
  });

  for (final testCase in [
    (
      name: 'a removed profile',
      origin: PostOrigin.fromSource(
        booruType: BooruType.pixiv,
        booruId: 37,
        source: 'https://www.pixiv.net/',
        profileIdHint: profileUuid(3),
      ),
      configs: <BooruConfig>[],
    ),
    (
      name: 'a mismatched host',
      origin: PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 20,
        source: 'https://danbooru.donmai.us/',
      ),
      configs: [
        _config(
          id: profileUuid(1),
          type: BooruType.danbooru,
          url: 'https://donmai.moe/',
        ),
      ],
    ),
    (
      name: 'a mismatched engine',
      origin: PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 20,
        source: 'https://example.com/',
      ),
      configs: [
        _config(
          id: profileUuid(1),
          type: BooruType.e621,
          url: 'https://example.com/',
        ),
      ],
    ),
  ]) {
    test('${testCase.name} does not resolve a profile', () {
      expect(
        resolver.resolve(testCase.origin, testCase.configs),
        const MissingPostOrigin(),
      );
    });
  }
}

BooruConfig _config({
  required String id,
  required BooruType type,
  required String url,
}) => BooruConfigData.anonymous(
  booru: type,
  booruHint: type,
  name: 'Profile $id',
  filter: BooruConfigRatingFilter.none,
  url: url,
  customDownloadFileNameFormat: null,
  customBulkDownloadFileNameFormat: null,
  imageDetaisQuality: null,
  videoQuality: null,
).toBooruConfig(id: id)!;
