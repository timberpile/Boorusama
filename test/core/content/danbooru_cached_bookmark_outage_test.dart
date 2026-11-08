import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/boorus/danbooru/blacklist/providers.dart'
    as danbooru_blacklist;
import 'package:boorusama/boorus/danbooru/danbooru.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/src/types/user.dart';
import 'package:boorusama/boorus/danbooru/users/user/src/types/user_level.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/configs/search/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../posts/details/progressive_image_test_utils.dart' as images;

const _url = 'https://cdn.donmai.us/sample/offline-fixture.png';

BooruConfig _profile({
  BlacklistCombinationMode mode = BlacklistCombinationMode.merge,
}) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': '11111111-1111-4111-8111-111111111111',
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
  'url': 'https://danbooru.donmai.us',
  'login': 'offline-test',
  'apiKey': 'fixture-not-a-credential',
  'blacklistedConfigs': {
    'enable': true,
    'combinationMode': mode.id,
    'blacklistedTags': '["profile_rule"]',
  },
});

List<Override> _overrides(
  BooruConfig profile,
  FutureOr<UserSelf?> Function() user,
) => [
  booruConfigProvider.overrideWith(
    () => BooruConfigNotifier(initialConfigs: [profile]),
  ),
  globalBlacklistedTagsProvider.overrideWith(_GlobalBlacklist.new),
  blacklistTagsRefRepoProvider.overrideWith(
    (ref, auth) => danbooru_blacklist.DanbooruBlacklistTagRepository(ref, auth),
  ),
  danbooruCurrentUserProvider.overrideWith((ref, auth) => user()),
  danbooruProvider.overrideWithValue(DanbooruParser().parse() as Danbooru),
];

void main() {
  test(
    'pending and failed server preferences do not block local filter/access',
    () async {
      final profile = _profile();
      final remote = Completer<UserSelf?>();
      final container = ProviderContainer(
        overrides: _overrides(profile, () => remote.future),
      );
      addTearDown(() {
        if (!remote.isCompleted) remote.complete(null);
      });
      addTearDown(container.dispose);
      final access = container.listen(
        contentProfileAccessProvider(profile.id),
        (_, _) {},
      );
      addTearDown(access.close);

      expect(
        await container
            .read(blacklistTagsProvider(profile.filter).future)
            .timeout(const Duration(seconds: 5)),
        {'global_rule', 'profile_rule'},
      );
      expect(remote.isCompleted, isFalse);
      expect(
        container.read(contentProfileAccessProvider(profile.id))?.config,
        profile,
      );

      final failed = expectLater(
        container.read(danbooruCurrentUserProvider(profile.auth).future),
        throwsStateError,
      );
      remote.completeError(StateError('Danbooru unavailable'));
      await failed;
      await container.pump();
      expect(
        await container.read(blacklistTagsProvider(profile.filter).future),
        {'global_rule', 'profile_rule'},
      );
      expect(
        container.read(contentProfileAccessProvider(profile.id))?.config,
        profile,
      );
    },
  );

  test(
    'replacement profile rules still replace global rules during an outage',
    () async {
      final profile = _profile(mode: BlacklistCombinationMode.replace);
      final container = ProviderContainer(
        overrides: _overrides(
          profile,
          () => Future<UserSelf?>.error(StateError('offline')),
        ),
      );
      addTearDown(container.dispose);
      expect(
        await container
            .read(blacklistTagsProvider(profile.filter).future)
            .timeout(const Duration(seconds: 5)),
        {'profile_rule'},
      );
    },
  );

  test('server rules join local rules when the source recovers', () async {
    final profile = _profile();
    final remote = Completer<UserSelf?>();
    final container = ProviderContainer(
      overrides: _overrides(profile, () => remote.future),
    );
    addTearDown(() {
      if (!remote.isCompleted) remote.complete(null);
    });
    addTearDown(container.dispose);
    final subscription = container.listen(
      blacklistTagsProvider(profile.filter),
      (_, _) {},
    );
    addTearDown(subscription.close);
    expect(
      await container.read(blacklistTagsProvider(profile.filter).future),
      {'global_rule', 'profile_rule'},
    );
    remote.complete(
      const UserSelf(
        id: 1,
        level: UserLevel.gold,
        name: 'fixture',
        blacklistedTags: {'server_rule'},
      ),
    );
    await container.read(danbooruCurrentUserProvider(profile.auth).future);
    await container.pump();
    expect(
      await container.read(blacklistTagsProvider(profile.filter).future),
      {'global_rule', 'profile_rule', 'server_rule'},
    );
  });

  for (final failed in [false, true]) {
    testWidgets(
      'cached Bookmark media decodes with server failed=$failed',
      (tester) async {
        final profile = _profile();
        final remote = Completer<UserSelf?>();
        final cache = _ImageCache({_url: images.lowerPng});
        final adapter = _OfflineAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final container = ProviderContainer(
          overrides: [
            ..._overrides(
              profile,
              () => failed
                  ? Future<UserSelf?>.error(StateError('offline'))
                  : remote.future,
            ),
            automaticMediaLoadingEnabledProvider.overrideWithValue(true),
            settingsProvider.overrideWithValue(Settings.defaultSettings),
            imageListingSettingsProvider.overrideWithValue(
              Settings.defaultSettings.listing,
            ),
            deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
            defaultImageCacheManagerProvider.overrideWithValue(cache),
            dioForWidgetProvider.overrideWith((ref, auth) => dio),
            httpHeadersProvider.overrideWith((ref, auth) => {}),
          ],
        );
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: images.testApp(_CachedBookmarkMedia(profile)),
            ),
          );
          await tester.runAsync(
            () => images.pumpUntil(
              tester,
              () => tester
                  .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
                  .any((image) => image.image != null),
              reason: 'cached Danbooru image with no server response',
            ),
          );
          expect(cache.reads, contains(_url));
          expect(adapter.requests, isEmpty);
          expect(remote.isCompleted, isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          remote.complete(null);
          dio.close(force: true);
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        }
      },
    );
  }
}

// Same access/scope/image boundary used by a saved Post cell. Do not override
// contentProfileAccessProvider or the cache provider: those are the regressions.
class _CachedBookmarkMedia extends ConsumerWidget {
  const _CachedBookmarkMedia(this.profile);
  final BooruConfig profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: BooruType.danbooru.id,
      source: profile.url,
      profileIdHint: profile.id,
    );
    final access = ref.watch(contentAccessForOriginProvider(origin));
    if (access?.config == null) return const SizedBox.shrink();
    return CurrentBooruConfigScope(
      config: access!.config!,
      accessKey: access.key,
      requireAccess: true,
      bookmarkId: 17,
      child: BooruImage(config: access.config!.auth, imageUrl: _url),
    );
  }
}

class _GlobalBlacklist extends GlobalBlacklistedTagsNotifier {
  @override
  FutureOr<IList<BlacklistedTag>> build() => [
    BlacklistedTag(
      id: 1,
      name: 'global_rule',
      isActive: true,
      createdDate: DateTime.utc(2024),
      updatedDate: DateTime.utc(2024),
    ),
  ].lock;
}

class _ImageCache extends images.TestImageCache {
  _ImageCache(super.bytes);
  final reads = <String>[];
  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) =>
      bytes.containsKey(key);
  @override
  String generateCacheKey(String url, {String? customKey}) => customKey ?? url;
  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) {
    reads.add(key);
    return bytes[key];
  }
}

class _OfflineAdapter implements HttpClientAdapter {
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options.uri.toString());
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}
