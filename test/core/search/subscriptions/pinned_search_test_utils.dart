import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_hive_object.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_service.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:oktoast/oktoast.dart';

import 'subscription_test_utils.dart';

final selectedTestProfileProvider =
    NotifierProvider<SelectedTestProfile, BooruConfig>(SelectedTestProfile.new);

class SelectedTestProfile extends Notifier<BooruConfig> {
  @override
  BooruConfig build() => testProfile;

  void select(BooruConfig config) => state = config;
}

final testProfile = BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': 12,
  'url': 'https://active.example',
});
final otherTestProfile = BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': 99,
  'url': 'https://other.example',
});
final checkedAt = DateTime.utc(2026, 9, 14, 10);

SearchSubscription pinnedFixture({
  String id = 'cats',
  int profileId = 12,
  String query = 'cat  rating:safe order:score',
  String? name = 'Cats',
  int position = 0,
  int unreadCount = 3,
  int previewCount = 0,
  SearchRefreshErrorKind? error,
  bool checked = true,
}) => SearchSubscription(
  id: id,
  profileId: profileId,
  query: query,
  name: name,
  position: position,
  createdAt: checkedAt,
  previews: [
    for (var i = 0; i < previewCount; i++)
      SearchPostPreview(
        postId: i,
        postCreatedAt: checkedAt,
        thumbnailUrl: 'https://images.example/$i.jpg',
        sampleUrl: null,
        discoveredAt: checkedAt,
      ),
  ],
  recentPostIdentities: const [],
  unreadCount: unreadCount,
  lastSuccessfulCheckAt: checked ? checkedAt : null,
  lastAttemptAt: error == null ? null : checkedAt,
  lastErrorKind: error,
);

class PinnedSearchHarness {
  PinnedSearchHarness({
    this.repositoryReady,
    this.loadImages = false,
    this.supported = true,
  }) {
    repository = HiveSearchSubscriptionRepository(box: box);
    container = ProviderContainer(
      overrides: [
        pinnedSearchTrackingSupportedProvider.overrideWith(
          (ref, config) => supported,
        ),
        currentReadOnlyBooruConfigProvider.overrideWith(
          (ref) => ref.watch(selectedTestProfileProvider),
        ),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(
            initialConfigs: [testProfile, otherTestProfile],
          ),
        ),
        searchSubscriptionRepositoryProvider.overrideWith(
          () => _RepositoryNotifier(repository, repositoryReady),
        ),
        searchSubscriptionsProvider.overrideWith(
          () => SearchSubscriptionsNotifier(
            refreshService: SearchRefreshService(
              repository: repository,
              resolvePostRepository: (config) => TestSearchPostRepository(
                (query, page, limit) async {
                  requests.add((
                    profileId: config.auth.url == testProfile.url ? 12 : 99,
                    query: query,
                  ));
                  await refreshGate?.future;
                  return Either.of(const PostResult(posts: <Post>[], total: 0));
                },
              ),
              resolveQueryAdapter: (_) =>
                  const DefaultSearchRefreshQueryAdapter(),
              scanner: ChronologicalSearchScanner(),
            ),
          ),
        ),
        automaticMediaLoadingEnabledProvider.overrideWithValue(loadImages),
        imageListingSettingsProvider.overrideWithValue(
          Settings.defaultSettings.listing,
        ),
        deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
        defaultImageCacheManagerProvider.overrideWithValue(_NoImageCache()),
        dioForWidgetProvider.overrideWith(
          (ref, config) => Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.badResponse,
                      response: Response(
                        requestOptions: options,
                        statusCode: 404,
                      ),
                    ),
                  );
                },
              ),
            ),
        ),
        httpHeadersProvider.overrideWith((ref, config) => {}),
        routerProvider.overrideWith((_) => router),
      ],
    );
  }

  final Completer<void>? repositoryReady;
  final bool loadImages;
  final bool supported;
  final box = ControlledSubscriptionBox();
  late final SearchSubscriptionRepository repository;
  late final ProviderContainer container;
  late GoRouter router;
  Completer<void>? refreshGate;
  final requests = <({int profileId, String query})>[];

  Future<void> seed(List<SearchSubscription> items) async {
    for (final profileId in items.map((item) => item.profileId).toSet()) {
      await repository.restoreForProfile(
        profileId,
        items.where((item) => item.profileId == profileId).toList(),
      );
    }
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      wrap(MaterialApp(home: child, builder: themeBuilder)),
    );
    await settle(tester);
  }

  Widget wrap(Widget child) => UncontrolledProviderScope(
    container: container,
    child: BooruLocalization(child: OKToast(child: child)),
  );

  void dispose() => container.dispose();
}

Widget themeBuilder(BuildContext context, Widget? child) => KurumiTheme(
  data: KurumiThemeData.fromMaterial(Theme.of(context)),
  child: child!,
);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class ControlledSubscriptionBox extends MemorySubscriptionBox {
  Completer<void>? writeGate;
  var failWrites = false;

  @override
  Future<void> put(dynamic key, SearchSubscriptionHiveObject value) async {
    await writeGate?.future;
    if (failWrites) throw StateError('disk full');
    await super.put(key, value);
  }
}

class _RepositoryNotifier extends SearchSubscriptionRepositoryNotifier {
  _RepositoryNotifier(this.repository, this.ready);
  final SearchSubscriptionRepository repository;
  final Completer<void>? ready;

  @override
  Future<SearchSubscriptionRepository> build() async {
    await ready?.future;
    return repository;
  }
}

class _NoImageCache implements ImageCacheManager {
  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) => null;
  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      null;
  @override
  String generateCacheKey(String url, {String? customKey}) => url;
  @override
  Future<void> saveFile(String key, Uint8List bytes) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
