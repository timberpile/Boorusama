import 'dart:async';
import 'dart:io';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/pixiv_original_hashes_provider.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/posts/links/boorusama_post_link_test.dart' show config;
import 'providers_test.dart' show Profiles;

class _Client extends Fake implements PixivClient {
  _Client(this.artwork);
  final PixivIllustDto artwork;
  var calls = 0;

  @override
  Future<PixivIllustDto?> getIllustDetail({required int illustId}) async {
    expect(illustId, 141607376);
    calls++;
    return artwork;
  }
}

void main() {
  test(
    'pending blacklist data stays alive until source metadata is read',
    () async {
      final source = config('https://pixiv.net', type: BooruType.pixiv)
          .copyWith(
            apiKey: 'unused-test-refresh-token',
          );
      final blocked = Completer<Set<String>>();
      final client = _Client(
        const PixivIllustDto(
          id: 141607376,
          type: 'illust',
          visible: false,
          pageCount: 1,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(() => Profiles([source])),
          blacklistTagsProvider.overrideWith((ref, filter) => blocked.future),
          pixivClientProvider.overrideWith((ref, auth) => client),
        ],
      );
      addTearDown(container.dispose);
      final artwork = PixivArtworkReference.parseSharedText(
        'https://www.pixiv.net/artworks/141607376',
      )!;
      final provider = pixivOriginalHashResolverProvider(artwork);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final pending = container.read(provider).resolve();
      await container.pump();
      blocked.complete({});
      await pending;
      expect(client.calls, 1);
    },
  );

  for (final (name, visible, muted, filter) in [
    ('Pixiv access restriction', false, false, BooruConfigRatingFilter.none),
    ('muted artwork', true, true, BooruConfigRatingFilter.none),
    (
      'source profile rating filter',
      true,
      false,
      BooruConfigRatingFilter.hideNSFW,
    ),
  ]) {
    test('$name is explicit and cannot start an original download', () async {
      final source = BooruConfig.fromJson({
        ...config('https://pixiv.net', type: BooruType.pixiv).toJson(),
        'apiKey': 'unused-test-refresh-token',
        'ratingFilter': filter.index,
      });
      final client = _Client(
        PixivIllustDto.fromJson({
          'id': 141607376,
          'type': 'illust',
          'user': {'id': 1},
          'page_count': 1,
          'x_restrict': 1,
          'visible': visible,
          'is_muted': muted,
          'meta_single_page': {
            'original_image_url': visible
                ? 'https://i.pximg.net/img-original/141607376_p0.png'
                : 'https://s.pximg.net/common/images/limit_r18_360.png',
          },
        }),
      );
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(() => Profiles([source])),
          blacklistTagsProvider.overrideWith((ref, filter) => <String>{}),
          pixivClientProvider.overrideWith((ref, auth) {
            expect(auth, source.auth);
            return client;
          }),
        ],
      );
      addTearDown(container.dispose);
      final artwork = PixivArtworkReference.parseSharedText(
        'https://www.pixiv.net/en/artworks/141607376',
      )!;
      final provider = pixivOriginalHashResolverProvider(artwork);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      var downloads = 0;
      await HttpOverrides.runZoned(
        () async {
          final result = await container.read(provider).resolve();
          expect(result.issue, PixivLookupCoverageIssue.restricted);
          expect(result.hashes, isEmpty);
          expect(client.calls, 1);
          expect(downloads, 0);
        },
        createHttpClient: (_) {
          downloads++;
          throw StateError('A restricted original must never be requested');
        },
      );
    });
  }
}
