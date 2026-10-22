// Run serially on the candidate and exact base with the same fixture and SDK.
// These are host diagnostics; no timing threshold is an acceptance assertion.
// Add --dart-define=BOOKMARK_GROUP_TOGGLE_BENCHMARK=true for the 9k/20k
// viewer workload with 200-row and near-library-sized target groups.
// BOOKMARK_GRID_MUTATION_BENCHMARK=true runs the same matrix with the search
// index visible, as it is when removing bookmarks directly from the timeline.
import 'dart:convert';
import 'dart:io';

import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_details_mutation_notifier.dart';
import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_hydration_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/performance.dart';
import 'package:hive_ce/hive.dart';

import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  final profile = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.gelbooruV2,
      url: 'https://gelbooru.example',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '00000000-0000-4000-8000-000000000001',
  });
  Post post(int id) => Post(
    origin: PostOrigin.fromSource(
      booruType: BooruType.gelbooruV2,
      booruId: profile.booruId,
      source: profile.url,
      profileIdHint: profile.id,
    ),
    core: PostCoreData(
      id: id,
      createdAt: DateTime.utc(2026),
      thumbnailImageUrl: 'https://cdn.example/$id-thumb.jpg',
      sampleImageUrl: 'https://cdn.example/$id.jpg',
      originalImageUrl: 'https://cdn.example/$id-original.jpg',
      videoUrl: '',
      videoThumbnailUrl: '',
      width: 1400,
      height: 1000,
      format: 'jpg',
      md5: 'hash_$id',
      fileSize: 1000000,
      duration: 0,
      rating: Rating.general,
      hasComment: false,
      isTranslated: false,
      hasParentOrChildren: false,
      source: PostSource.none(),
      score: id,
      tags: {for (var tag = 0; tag < 30; tag++) 'tag_${id % 11}_$tag'},
    ),
    booruData: const GelbooruV2PostData(hasNotes: true),
  );

  const groupToggleBenchmark = bool.fromEnvironment(
    'BOOKMARK_GROUP_TOGGLE_BENCHMARK',
  );
  const gridMutationBenchmark = bool.fromEnvironment(
    'BOOKMARK_GRID_MUTATION_BENCHMARK',
  );
  final sizes = groupToggleBenchmark || gridMutationBenchmark
      ? [(9000, 200), (9000, 8500), (20000, 200), (20000, 19500)]
      : [(100, 100), (5000, 5000)];
  for (final (count, targetCount) in sizes) {
    test(
      'Hive mutations: $count rows, $targetCount target members',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'bookmark-latency-',
        );
        Hive.init(directory.path);
        if (!Hive.isAdapterRegistered(4)) {
          Hive.registerAdapter(BookmarkHiveObjectAdapter());
        }
        if (!Hive.isAdapterRegistered(5)) {
          Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
        }
        final metrics = _Metrics();
        final rows = await Hive.openBox<BookmarkHiveObject>('rows');
        final groupBox = await Hive.openBox<BookmarkGroupHiveObject>('groups');
        final organization = await Hive.openBox<dynamic>('organization');
        final repository = _Bookmarks(rows, metrics);
        final groups = _Groups(groupBox, organization, metrics);
        final saved = await repository.addBookmarks(
          profile.booruId,
          [for (var id = 1; id <= count; id++) post(id)],
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
          postLinkGenerator: (_) => const NoLinkPostLinkGenerator(),
        );
        final target = await groups.createGroup('Large target');
        final other = await groups.createGroup('Shared');
        final allIds = saved.map((row) => row.id).toSet();
        await groups.addBookmarks(target.id, allIds.take(targetCount).toSet());
        await groups.addBookmarks(other.id, allIds);
        final container = ProviderContainer(
          overrides: [
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: [profile]),
            ),
            bookmarkRepoProvider.overrideWith((ref) => repository),
            postLinkGeneratorProvider.overrideWith(
              (ref, _) => const NoLinkPostLinkGenerator(),
            ),
            bookmarkGroupRepoProvider.overrideWith((ref) => groups),
            bookmarkUrlResolverProvider.overrideWith(
              (ref, _) => const DefaultImageUrlResolver(),
            ),
            settingsNotifierProvider.overrideWith(
              () => _Settings(Settings.defaultSettings),
            ),
          ],
        );
        addTearDown(() async {
          performanceRecorder.clear();
          container.dispose();
          await rows.close();
          await groupBox.close();
          await organization.close();
          await directory.delete(recursive: true);
        });
        final notifier = container.read(bookmarkProvider.notifier);
        await container.read(bookmarkProvider.future);
        if (groupToggleBenchmark || gridMutationBenchmark) {
          final view = BookmarkView.group(target.id);
          final indexProvider = bookmarkTagIndexProvider(view);
          for (final withTagIndex in [false, true]) {
            final indexSubscription = withTagIndex
                ? container.listen(indexProvider, (_, _) {})
                : null;
            if (withTagIndex) await container.read(indexProvider.future);
            if (!gridMutationBenchmark) {
              container
                  .read(bookmarkDetailsMutationProvider.notifier)
                  .begin(sourceView: view);
            }
            await container.pump();
            if (withTagIndex) await container.read(indexProvider.future);
            for (var sample = -3; sample < 20; sample++) {
              metrics.reset();
              var publicationUs = 0;
              final watch = Stopwatch()..start();
              final subscription = container.listen(bookmarkProvider, (_, _) {
                publicationUs = watch.elapsedMicroseconds;
              });
              performanceRecorder.start();
              final outcome = await notifier.togglePostTarget(
                profile.auth,
                saved.first.post,
                target: BookmarkTarget.group(target.id),
              );
              await container.pump();
              if (withTagIndex) await container.read(indexProvider.future);
              watch.stop();
              performanceRecorder.stop();
              subscription.close();
              expect(
                outcome,
                anyOf(
                  BookmarkToggleOutcome.added,
                  BookmarkToggleOutcome.removed,
                ),
              );
              if (sample >= 0) {
                stdout.writeln(
                  jsonEncode({
                    'benchmark': 'bookmarkGroupToggle',
                    'viewerVisible': !gridMutationBenchmark,
                    'total': count,
                    'targetRows': targetCount,
                    'withTagIndex': withTagIndex,
                    'sample': sample,
                    'wallUs': watch.elapsedMicroseconds,
                    'publicationUs': publicationUs,
                    'writeWallUs': metrics.writeUs,
                    'wholeReads': metrics.reads,
                    'repairs': metrics.repairs,
                    'operations':
                        (performanceRecorder.snapshot()['summary']
                            as Map)['operations'],
                  }),
                );
              }
            }
            indexSubscription?.close();
            await container.pump();
            await notifier.setPostTargetMembership(
              profile.auth,
              saved.first.post,
              target: BookmarkTarget.group(target.id),
              bookmarked: true,
            );
            container.read(bookmarkDetailsMutationProvider.notifier).end();
            await container.pump();
            final state = await container.read(bookmarkProvider.future);
            expect(state.items, hasLength(count));
            expect(
              state.groupsById[target.id]!.bookmarkIds,
              hasLength(targetCount),
            );
          }
          return;
        }
        var nextId = count + 1;
        // Three warm-up cycles precede twenty measured cycles per process.
        for (var sample = -3; sample < 20; sample++) {
          Future<T> measure<T>(
            String operation,
            Future<T> Function() action,
          ) async {
            metrics.reset();
            var publicationUs = 0;
            final watch = Stopwatch()..start();
            final subscription = container.listen(bookmarkProvider, (_, _) {
              publicationUs = watch.elapsedMicroseconds;
            });
            performanceRecorder.start();
            final result = await action();
            watch.stop();
            performanceRecorder.stop();
            subscription.close();
            if (sample >= 0) {
              stdout.writeln(
                jsonEncode({
                  'benchmark': 'bookmarkMutation',
                  'bookmarks': count,
                  'operation': operation,
                  'sample': sample,
                  'wallUs': watch.elapsedMicroseconds,
                  'publicationUs': publicationUs,
                  'writeWallUs': metrics.writeUs,
                  'wholeReadWallUs': metrics.readUs,
                  'wholeReads': metrics.reads,
                  'repairs': metrics.repairs,
                  'operations':
                      (performanceRecorder.snapshot()['summary']
                          as Map)['operations'],
                }),
              );
            }
            return result;
          }

          final fresh = post(nextId++);
          expect(
            await measure(
              'newAdd',
              () => notifier.togglePostTarget(profile.auth, fresh),
            ),
            BookmarkToggleOutcome.added,
          );
          await measure(
            'existingGroupAdd',
            () => notifier.addPostsToGroup(profile.auth, [fresh], target.id),
          );
          final shared = await measure(
            'sharedRemoval',
            () => notifier.removePostsFromGroup(profile.auth, [
              fresh,
            ], defaultBookmarkGroupId),
          );
          expect(shared.deletedCount, 0);
          final removal = await measure(
            'finalRemoval',
            () =>
                notifier.removePostsFromGroup(profile.auth, [fresh], target.id),
          );
          expect(removal.deletedCount, 1);
          await measure('undo', () => notifier.undoRemoval(removal));
          await measure(
            'noOpMembership',
            () => notifier.setPostTargetMembership(
              profile.auth,
              fresh,
              target: BookmarkTarget.group(target.id),
              bookmarked: true,
            ),
          );
          await notifier.deleteBookmarksForPosts(profile.auth, [fresh]);
          final batch = [for (var i = 0; i < 20; i++) post(nextId++)];
          await measure(
            'bulkAdd20',
            () => notifier.addPostsToGroup(profile.auth, batch, target.id),
          );
          await measure(
            'bulkRemove20',
            () => notifier.removePostsFromGroup(profile.auth, batch, target.id),
          );
          final rapid = post(nextId++);
          final outcomes = await measure(
            'rapidToggle10',
            () => Future.wait([
              for (var i = 0; i < 10; i++)
                notifier.togglePostTarget(profile.auth, rapid),
            ]),
          );
          expect(
            outcomes.where((outcome) => outcome == BookmarkToggleOutcome.added),
            hasLength(5),
          );
        }
        // Throughput includes all commit/publication work. Immediate successes
        // keep network delay from hiding local work.
        final legacyRows = saved.map((row) {
          final legacyPost = row.post.copyWith(
            booruData: const LegacyPostData(typeKey: 'legacy', custom: {}),
          );
          return row.copyWith(
            post: legacyPost,
            snapshot: const StoredPostCodec().encode(legacyPost),
          );
        }).toList();
        await notifier.runSerializedMutation(() async {
          for (final row in legacyRows) {
            await repository.updateBookmark(row);
          }
        });
        metrics.reset();
        final hydrationWatch = Stopwatch()..start();
        final hydrated = await notifier.hydrateBookmarks(
          configs: [profile],
          recovery: BookmarkRecoveryService(
            fetchPost: (_, id) async => post(id),
            codecFor: (_) => const GelbooruV2PostCodec(),
          ),
          cancellation: BookmarkHydrationCancellation(),
          onProgress: (_) {},
        );
        hydrationWatch.stop();
        expect(hydrated.updated, count);
        stdout.writeln(
          jsonEncode({
            'benchmark': 'bookmarkHydrationThroughput',
            'bookmarks': count,
            'wallUs': hydrationWatch.elapsedMicroseconds,
            'updated': hydrated.updated,
            'writeWallUs': metrics.writeUs,
            'wholeReads': metrics.reads,
          }),
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }
}

class _Settings extends SettingsNotifier {
  _Settings(super.initialSettings);
  @override
  Future<bool> updateWith(Settings Function(Settings) selector) async {
    state = selector(state);
    return true;
  }
}

class _Metrics {
  var writeUs = 0;
  var readUs = 0;
  var reads = 0;
  var repairs = 0;
  void reset() {
    writeUs = readUs = reads = repairs = 0;
  }

  Future<T> write<T>(Future<T> Function() action) async {
    final watch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      writeUs += watch.elapsedMicroseconds;
    }
  }
}

class _Bookmarks extends BookmarkHiveRepository {
  _Bookmarks(super._box, this.metrics)
    : super(postDataCodec: (_) => const GelbooruV2PostCodec());
  final _Metrics metrics;
  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int?) imageUrlResolver,
  }) => TaskEither(() async {
    metrics.reads++;
    final watch = Stopwatch()..start();
    try {
      return await super
          .getAllBookmarks(imageUrlResolver: imageUrlResolver)
          .run();
    } finally {
      metrics.readUs += watch.elapsedMicroseconds;
    }
  });
  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int?) imageUrlResolver,
    required PostLinkGenerator Function(int?) postLinkGenerator,
  }) => metrics.write(
    () => super.addBookmark(
      booruId,
      post,
      imageUrlResolver: imageUrlResolver,
      postLinkGenerator: postLinkGenerator,
    ),
  );
  @override
  Future<List<Bookmark>> addBookmarkWithBookmarks(List<Bookmark> bookmarks) =>
      metrics.write(() => super.addBookmarkWithBookmarks(bookmarks));
  @override
  Future<void> removeBookmark(Bookmark bookmark) =>
      metrics.write(() => super.removeBookmark(bookmark));
  @override
  Future<void> removeBookmarks(Iterable<Bookmark> bookmarks) =>
      metrics.write(() => super.removeBookmarks(bookmarks));
  @override
  Future<void> updateBookmark(Bookmark bookmark) =>
      metrics.write(() => super.updateBookmark(bookmark));
}

class _Groups extends BookmarkGroupRepositoryHive {
  _Groups(super._box, Box<dynamic> organization, this.metrics)
    : super(organizationBox: organization);
  final _Metrics metrics;
  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> ids) =>
      metrics.write(() => super.addBookmarks(id, ids));
  @override
  Future<BookmarkGroup> removeBookmarks(String id, Set<int> ids) =>
      metrics.write(() => super.removeBookmarks(id, ids));
  @override
  Future<BookmarkGroup> replaceMemberships(String id, Set<int> ids) =>
      metrics.write(() => super.replaceMemberships(id, ids));
  @override
  Future<bool> repair({required Set<int> validBookmarkIds}) {
    metrics.repairs++;
    return super.repair(validBookmarkIds: validBookmarkIds);
  }
}
