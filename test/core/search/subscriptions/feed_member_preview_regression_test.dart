import 'dart:async';
import 'dart:io';

import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_codec.dart';
import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/following_feed_management_page.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pinned_search_card.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/dio_extended_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

import '../../posts/details/progressive_image_test_utils.dart'
    show ControlledImageAdapter;
import 'feed_member_preview_test.dart' show ByteCache;
import 'pinned_search_test_utils.dart';

class ProfileStore implements BooruConfigRepository {
  ProfileStore(this.profiles);
  List<BooruConfig> profiles;
  @override
  Future<List<BooruConfig>> getAll() async => profiles;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late PinnedSearchHarness h;
  late ByteCache cache;
  late ProfileStore profiles;
  late List<String> mediaRequests;
  final owner = BooruConfig.fromJson({
    ...otherTestProfile.toJson(),
    'booruId': BooruType.danbooru.id,
  });
  setUp(() {
    cache = ByteCache();
    profiles = ProfileStore([testProfile, owner]);
    mediaRequests = [];
    h = PinnedSearchHarness(
      loadImages: true,
      profiles: profiles.profiles,
      profileRepository: profiles,
      imageCacheManager: cache,
      onMediaRequest: (r) => mediaRequests.add(r.uri.toString()),
      postCapability: const BooruPostCapability<BooruPostData>(
        booruType: BooruType.danbooru,
        codec: DanbooruPostCodec(),
        presentation: GenericPostPresentation(),
      ),
    );
  });
  tearDown(() => h.dispose());

  Future<SearchFollowingFeed> seed(
    WidgetTester tester, {
    String thumbnail = 'thumb',
    String sample = 'sample',
    Map<String, String> variants = const {},
  }) async {
    late SearchFollowingFeed feed;
    await tester.runAsync(() async {
      feed = await h.repository.saveFeed(
        profileId: owner.id,
        name: 'Artists',
        queries: ['cat'],
      );
      await h.seed([
        pinnedFixture(
          id: feed.sourceIds.single,
          profileId: owner.id,
          query: 'cat',
          previewCount: 1,
        ),
      ]);
      final post = _post(owner, 0, thumbnail, sample, variants);
      feed = feed.copyWith(
        posts: [
          feedPostSnapshotFromPost(post, dataCodec: const DanbooruPostCodec()),
        ],
      );
      await h.repository.restoreFeeds(owner.id, [feed]);
      await h.container.read(searchSubscriptionsProvider.future);
    });
    return feed;
  }

  testWidgets(
    'Automatic decodes the matching native variant and skips arbitrary cached feed posts',
    (tester) async {
      final feed = await seed(tester, variants: {'720x720': 'native720'});
      await tester.runAsync(() async {
        cache.entries['native720'] = await File(
          'test/fixtures/post_quality/target.png',
        ).readAsBytes();
        cache.entries['sample'] = await File(
          'test/fixtures/post_quality/original.png',
        ).readAsBytes();
        final unrelated = feedPostSnapshotFromPost(
          _post(owner, 99, 'unrelated', 'unrelated', {}),
          dataCodec: const DanbooruPostCodec(),
        );
        await h.repository.restoreFeeds(owner.id, [
          feed.copyWith(posts: [unrelated, ...feed.posts]),
        ]);
        await h.container
            .read(searchSubscriptionsProvider.notifier)
            .runSerializedMutation((_) async {});
      });
      await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
      await drain(tester);
      expect(_image(tester).bytes, cache.entries['native720']);
      expect(cache.reads, isNot(contains('unrelated')));
      expect(h.requests, isEmpty);
      expect(mediaRequests, isEmpty);
    },
  );

  testWidgets(
    'the first four matching previews retain member order independently of feed snapshot ordering',
    (tester) async {
      final feed = await seed(tester);
      await tester.runAsync(() async {
        final bytes = await Future.wait([
          for (final name in ['lower', 'target', 'original', 'portrait'])
            File('test/fixtures/post_quality/$name.png').readAsBytes(),
        ]);
        for (var id = 0; id < 4; id++) {
          cache.entries['thumb$id'] = bytes[id];
        }
        await h.seed([
          pinnedFixture(
            id: feed.sourceIds.single,
            profileId: owner.id,
            query: 'cat',
            previewCount: 4,
          ),
        ]);
        await h.repository.restoreFeeds(owner.id, [
          feed.copyWith(
            posts: [
              for (final id in [3, 2, 99, 0, 1])
                feedPostSnapshotFromPost(
                  _post(owner, id, 'thumb$id', 'sample$id', {}),
                  dataCodec: const DanbooruPostCodec(),
                ),
            ],
          ),
        ]);
        await h.container
            .read(searchSubscriptionsProvider.notifier)
            .runSerializedMutation((_) async {});
      });
      await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
      await drain(tester);
      final images = tester
          .widgetList<Image>(
            find.descendant(
              of: find.byType(PinnedSearchCard),
              matching: find.byType(Image),
            ),
          )
          .toList();
      expect(images, hasLength(4));
      expect(images.map((i) => (i.image as MemoryImage).bytes), [
        for (var id = 0; id < 4; id++) cache.entries['thumb$id'],
      ]);
      expect(cache.reads, isNot(contains('thumb99')));
      expect(h.requests, isEmpty);
      expect(mediaRequests, isEmpty);
    },
  );

  testWidgets(
    'global and owner quality react without following active profile and owner disappearance omits bytes',
    (tester) async {
      final feed = await seed(tester);
      await tester.runAsync(() async {
        cache.entries['thumb'] = await File(
          'test/fixtures/post_quality/lower.png',
        ).readAsBytes();
        cache.entries['sample'] = await File(
          'test/fixtures/post_quality/target.png',
        ).readAsBytes();
        await h.container
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (s) => s.copyWith(
                listing: s.listing.copyWith(imageQuality: ImageQuality.high),
              ),
            );
      });
      await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
      await drain(tester);
      expect(_image(tester).bytes, cache.entries['sample']);
      await tester.runAsync(() async {
        profiles.profiles = [
          testProfile,
          BooruConfig.fromJson({
            ...owner.toJson(),
            'listing': ListingConfigs(
              enable: true,
              settings: Settings.defaultSettings.listing.copyWith(
                imageQuality: ImageQuality.low,
              ),
            ).toJson(),
          }),
        ];
        await h.container.read(booruConfigProvider.notifier).fetch();
      });
      await drain(tester);
      expect(_image(tester).bytes, cache.entries['thumb']);
      await tester.runAsync(() async {
        profiles.profiles = [testProfile];
        await h.container.read(booruConfigProvider.notifier).fetch();
      });
      await drain(tester);
      expect(
        find.descendant(
          of: find.byType(PinnedSearchCard),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      expect(find.byType(PinnedSearchCard), findsOneWidget);
      expect(
        tester.widget<PinnedSearchCard>(find.byType(PinnedSearchCard)).onOpen,
        isNull,
      );
      final source = (await tester.runAsync(
        () => h.repository.getById(feed.sourceIds.single),
      ))!;
      await tester.runAsync(() async {
        await expectLater(
          h.container
              .read(searchSubscriptionsProvider.notifier)
              .renameFeedMember(feedId: feed.id, source: source, name: 'Gone'),
          throwsStateError,
        );
      });
      expect(h.requests, isEmpty);
      expect(mediaRequests, isEmpty);
    },
  );

  testWidgets(
    'cached editor never joins a pending ordinary provider for the same URL or fetches after sorting',
    (tester) async {
      const url = 'https://images.example/pending.png';
      final feed = await seed(tester, thumbnail: url, sample: url);
      final adapter = ControlledImageAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final normalToken = CancelToken();
      final normal = DioExtendedNetworkImageProvider(
        url,
        dio: dio,
        cache: true,
        cacheManager: cache,
        cancelToken: normalToken,
        printError: false,
      );
      late ImageStream stream;
      late ImageStreamListener listener;
      final decoded = Completer<void>();
      await tester.runAsync(() async {
        stream = normal.resolve(ImageConfiguration.empty);
        listener = ImageStreamListener(
          (info, _) {
            info.dispose();
            if (!decoded.isCompleted) decoded.complete();
          },
          onError: (error, stack) {
            if (!decoded.isCompleted) decoded.complete();
          },
        );
        stream.addListener(listener);
      });
      await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
      await drain(tester);
      expect(adapter.requests, hasLength(1));
      expect(adapter.pending[url]!.isCompleted, isFalse);
      expect(
        find.descendant(
          of: find.byType(PinnedSearchCard),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      for (final sort in FollowingFeedMemberSort.values) {
        await tester.runAsync(
          () => h.container
              .read(followingFeedMemberSortProvider.notifier)
              .select(sort),
        );
        await drain(tester);
      }
      await tester.pump(const Duration(minutes: 1));
      await tester.runAsync(() => ensureI18nInitialized('de-DE'));
      await tester.pump();
      await drain(tester);
      expect(adapter.requests, hasLength(1));
      expect(mediaRequests, isEmpty);
      expect(h.requests, isEmpty);
      await tester.runAsync(() async {
        normalToken.cancel('fixture finished');
      });
      for (var attempt = 0; attempt < 20 && !decoded.isCompleted; attempt++) {
        await drain(tester);
      }
      expect(
        decoded.isCompleted,
        isTrue,
        reason:
            'The owned ordinary stream must finish cancellation before teardown',
      );
      stream.removeListener(listener);
      dio.close(force: true);
      await tester.runAsync(() => ensureI18nInitialized('en-US'));
    },
  );

  testWidgets(
    'evicted bytes disappear on a new editor mount with no media recovery',
    (tester) async {
      final feed = await seed(tester);
      await tester.runAsync(() async {
        cache.entries['thumb'] = await File(
          'test/fixtures/post_quality/lower.png',
        ).readAsBytes();
      });
      await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
      await drain(tester);
      expect(_image(tester).bytes, cache.entries['thumb']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      cache.entries.clear();
      h.container.invalidate(defaultCachedImageFileProvider);
      await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
      await drain(tester);
      expect(
        find.descendant(
          of: find.byType(PinnedSearchCard),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      expect(h.requests, isEmpty);
      expect(mediaRequests, isEmpty);
    },
  );
}

MemoryImage _image(WidgetTester tester) =>
    tester
            .widget<Image>(
              find.descendant(
                of: find.byType(PinnedSearchCard),
                matching: find.byType(Image),
              ),
            )
            .image
        as MemoryImage;

Post _post(
  BooruConfig owner,
  int id,
  String thumbnail,
  String sample,
  Map<String, String> variants,
) => Post(
  origin: PostOrigin.fromSource(
    booruType: owner.auth.booruType,
    booruId: owner.booruId,
    source: owner.url,
    profileIdHint: owner.id,
  ),
  core: PostCoreData(
    id: id,
    createdAt: checkedAt,
    thumbnailImageUrl: thumbnail,
    sampleImageUrl: sample,
    originalImageUrl: 'original',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 100,
    height: 100,
    format: 'png',
    md5: '',
    fileSize: 0,
    duration: 0,
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
    mediaVariants: variants,
  ),
  booruData: const DanbooruPostData(
    lastCommentAt: null,
    upScore: 1,
    downScore: 0,
    favCount: 0,
    approverId: null,
    generalTags: {},
    metaTags: {},
    hasChildren: false,
    hasLarge: true,
    pixelHash: '',
  ),
);
