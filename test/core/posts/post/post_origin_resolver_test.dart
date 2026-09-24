// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  const resolver = PostOriginResolver();

  test('a matching profile hint resolves that exact profile', () {
    final expected = _config(
      id: 2,
      type: BooruType.danbooru,
      url: 'https://danbooru.donmai.us/',
    );

    final result = resolver.resolve(
      PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 20,
        source: 'https://danbooru.donmai.us/posts/4',
        profileIdHint: 2,
      ),
      [
        _config(
          id: 1,
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
      id: 9,
      type: BooruType.e621,
      url: 'https://e621.net/',
    );

    final result = resolver.resolve(
      PostOrigin.fromSource(
        booruType: BooruType.e621,
        booruId: 25,
        source: 'https://E621.NET:443/posts/4',
        profileIdHint: 404,
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
          id: 1,
          type: BooruType.danbooru,
          url: 'https://danbooru.donmai.us/',
        ),
        _config(
          id: 2,
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
        profileIdHint: 3,
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
          id: 1,
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
          id: 1,
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
  required int id,
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
