import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/providers/feed_member_preview_provider.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/following_feed_management_page.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pinned_search_card.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libavif/flutter_libavif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pinned_search_test_utils.dart';

class ByteCache implements ImageCacheManager {
  final entries = <String, Uint8List>{};
  final reads = <String>[];
  final failKeys = <String>{};
  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) {
    reads.add(key);
    if (failKeys.contains(key)) {
      throw const FileSystemException('cache lookup failed');
    }
    return entries[key];
  }

  @override
  String generateCacheKey(String url, {String? customKey}) => url;
  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) => null;
  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    entries[key] = bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final c in [
    (
      label: 'enabled inactive owner',
      override: true,
      global: ImageQuality.original,
      expected: 'sample',
    ),
    (
      label: 'disabled inactive owner',
      override: false,
      global: ImageQuality.original,
      expected: 'original',
    ),
    (
      label: 'missing inactive owner override',
      override: null,
      global: ImageQuality.high,
      expected: 'sample',
    ),
  ]) {
    testWidgets(
      '${c.label} selects its cached bytes independently of the active profile',
      (tester) async {
        final cache = ByteCache();
        final mediaRequests = <String>[];
        final owner = BooruConfig.fromJson({
          ...otherTestProfile.toJson(),
          'listing': c.override == null
              ? null
              : ListingConfigs(
                  enable: c.override!,
                  settings: Settings.defaultSettings.listing.copyWith(
                    imageQuality: ImageQuality.high,
                  ),
                ).toJson(),
        });
        final active = BooruConfig.fromJson({
          ...testProfile.toJson(),
          'listing': ListingConfigs(
            enable: true,
            settings: Settings.defaultSettings.listing.copyWith(
              imageQuality: ImageQuality.low,
            ),
          ).toJson(),
        });
        late PinnedSearchHarness h;
        PinnedSearchHarness makeHarness() => PinnedSearchHarness(
          loadImages: true,
          profiles: [active, owner],
          imageCacheManager: cache,
          onMediaRequest: (r) => mediaRequests.add(r.uri.toString()),
          settings: Settings.defaultSettings.copyWith(
            listing: Settings.defaultSettings.listing.copyWith(
              imageQuality: c.global,
            ),
          ),
        );
        addTearDown(() => h.dispose());
        late SearchFollowingFeed feed;
        late Uint8List expectedBytes;
        await tester.runAsync(() async {
          h = makeHarness();
          cache.entries['thumb'] = await File(
            'test/fixtures/post_quality/lower.png',
          ).readAsBytes();
          cache.entries['sample'] = await File(
            'test/fixtures/post_quality/target.png',
          ).readAsBytes();
          cache.entries['original'] = await File(
            'test/fixtures/post_quality/original.png',
          ).readAsBytes();
          expectedBytes = cache.entries[c.expected]!;
          h.container.read(selectedTestProfileProvider.notifier).select(active);
          feed = await h.repository.saveFeed(
            profileId: owner.id,
            name: 'Artists',
            queries: ['cat'],
          );
          final source = pinnedFixture(
            id: feed.sourceIds.single,
            profileId: owner.id,
            query: 'cat',
            previewCount: 1,
          );
          await h.seed([source]);
          final snapshot = feedPostSnapshotFromJson({
            'id': 0,
            'createdAt': checkedAt.toIso8601String(),
            'thumbnail': 'thumb',
            'sample': 'sample',
            'original': 'original',
            'tags': ['cat'],
            'rating': 'general',
            'width': 100,
            'height': 100,
            'format': 'png',
          }, profileId: owner.id);
          feed = feed.copyWith(posts: [snapshot]);
          await h.repository.restoreFeeds(owner.id, [feed]);
          await h.container.read(searchSubscriptionsProvider.future);
        });
        await tester.runAsync(() async {
          await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
          final key = (feedId: feed.id, sourceId: feed.sourceIds.first);
          for (
            var attempt = 0;
            attempt < 100 &&
                h.container.read(feedMemberPreviewProvider(key)).isLoading;
            attempt++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
          }
          expect(
            h.container.read(feedMemberPreviewProvider(key)).isLoading,
            isFalse,
            reason:
                'Cached byte decoding must settle before checking rendered previews',
          );
          await tester.pump();
        });
        final images = find.descendant(
          of: find.byType(PinnedSearchCard),
          matching: find.byType(Image),
        );
        expect(images, findsOneWidget);
        final provider = tester.widget<Image>(images).image as MemoryImage;
        expect(provider.bytes, expectedBytes);
        expect(
          find.descendant(
            of: find.byType(PinnedSearchCard),
            matching: find.byType(RawImage),
          ),
          findsOneWidget,
        );
        expect(h.requests, isEmpty);
        expect(mediaRequests, isEmpty);
        expect(
          h.container.read(currentReadOnlyBooruConfigProvider).id,
          active.id,
        );
        h.container
            .read(selectedTestProfileProvider.notifier)
            .select(testProfile);
        await tester.pump();
        await drain(tester);
        expect(
          (tester.widget<Image>(images).image as MemoryImage).bytes,
          expectedBytes,
        );
        expect(mediaRequests, isEmpty);
      },
    );
  }

  for (final kind in [
    'cold',
    'corrupt',
    'corrupt avif',
    'fallback',
    'avif',
    'missing snapshot',
    'unused fallback error',
  ]) {
    testWidgets(
      '$kind cache renders only valid matching member bytes with no HTTP',
      (tester) async {
        final cache = ByteCache();
        final requests = <String>[];
        late PinnedSearchHarness h;
        PinnedSearchHarness makeHarness() => PinnedSearchHarness(
          loadImages: true,
          imageCacheManager: cache,
          onMediaRequest: (r) => requests.add(r.uri.toString()),
          settings: Settings.defaultSettings.copyWith(
            listing: Settings.defaultSettings.listing.copyWith(
              imageQuality: ImageQuality.high,
            ),
          ),
        );
        addTearDown(() => h.dispose());
        late SearchFollowingFeed feed;
        await tester.runAsync(() async {
          h = makeHarness();
          if (kind == 'corrupt avif') {
            final avif = await File(
              'packages/extended_image/test/fixtures/red.avif',
            ).readAsBytes();
            cache.entries['sample'] = Uint8List.fromList(
              avif.take(32).toList(),
            );
          }
          if (kind == 'corrupt') {
            cache.entries['sample'] = Uint8List.fromList([1, 2, 3]);
          }
          if (kind == 'fallback' || kind == 'missing snapshot') {
            cache.entries['thumb'] = await File(
              'test/fixtures/post_quality/lower.png',
            ).readAsBytes();
          }
          if (kind == 'unused fallback error') {
            cache.entries['sample'] = await File(
              'test/fixtures/post_quality/target.png',
            ).readAsBytes();
            cache.failKeys.add('thumb');
          }
          if (kind == 'avif') {
            cache.entries['sample'] = await File(
              'packages/extended_image/test/fixtures/red.avif',
            ).readAsBytes();
          }
          feed = await h.repository.saveFeed(
            profileId: testProfile.id,
            name: 'Artists',
            queries: ['cat'],
          );
          await h.seed([
            pinnedFixture(
              id: feed.sourceIds.single,
              query: 'cat',
              previewCount: 1,
            ),
          ]);
          if (kind != 'missing snapshot') {
            final snapshot = feedPostSnapshotFromJson({
              'id': 0,
              'createdAt': checkedAt.toIso8601String(),
              'thumbnail': 'thumb',
              'sample': 'sample',
              'original': 'original',
              'tags': ['cat'],
              'rating': 'general',
              'width': 100,
              'height': 100,
              'format': kind == 'avif' ? 'avif' : 'png',
            }, profileId: testProfile.id);
            feed = feed.copyWith(posts: [snapshot]);
            await h.repository.restoreFeeds(testProfile.id, [feed]);
          }
          await h.container.read(searchSubscriptionsProvider.future);
        });
        await tester.runAsync(() async {
          await h.pump(tester, FollowingFeedManagementPage(feedId: feed.id));
          final key = (feedId: feed.id, sourceId: feed.sourceIds.first);
          for (
            var attempt = 0;
            attempt < 100 &&
                h.container.read(feedMemberPreviewProvider(key)).isLoading;
            attempt++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
          }
          expect(
            h.container.read(feedMemberPreviewProvider(key)).isLoading,
            isFalse,
            reason:
                'Cached byte decoding must settle before checking rendered previews',
          );
          await tester.pump();
        });
        final images = find.descendant(
          of: find.byType(PinnedSearchCard),
          matching: find.byType(Image),
        );
        expect(
          images,
          kind == 'fallback' ||
                  kind == 'avif' ||
                  kind == 'unused fallback error'
              ? findsOneWidget
              : findsNothing,
        );
        if (kind == 'avif') {
          expect(tester.widget<Image>(images).image, isA<AvifMemoryImage>());
          expect(
            tester
                .widget<RawImage>(
                  find.descendant(of: images, matching: find.byType(RawImage)),
                )
                .image,
            isNotNull,
          );
        }
        if (kind == 'fallback') {
          expect(
            (tester.widget<Image>(images).image as MemoryImage).bytes,
            cache.entries['thumb'],
          );
        }
        expect(tester.takeException(), isNull);
        expect(h.requests, isEmpty);
        expect(requests, isEmpty);
      },
    );
  }
}
