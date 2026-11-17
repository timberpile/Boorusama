import 'dart:io';
import 'dart:async';

import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access_provider.dart';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/queries/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';

import '../../support/fakes/test_post.dart';

import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_mirror_state.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  late Directory directory;
  late BookmarkHiveRepository repository;
  late BookmarkGroupRepository groups;
  ProviderContainer? container;

  Future<void> open() async {
    final posts = await Hive.openBox<BookmarkHiveObject>('posts');
    final payloads = await Hive.openBox<dynamic>('posts_unified_payloads');
    final metadata = await Hive.openBox<dynamic>('posts_unified_metadata');
    repository = BookmarkHiveRepository(
      posts,
      groupPayloadBox: payloads,
      metadataBox: metadata,
      coordinator: DataMutationCoordinator(),
    );
    groups = await repository.openOrganization();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pool-cover-native-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    await open();
  });
  tearDown(() async {
    container?.dispose();
    container = null;
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Future<BookmarkLibraryNotifier> notifier({
    List<Override> overrides = const [],
    List<BooruConfig> profiles = const [],
  }) async {
    container = ProviderContainer(
      overrides: [
        dataMutationCoordinatorProvider.overrideWithValue(
          repository.coordinator,
        ),
        bookmarkRepoProvider.overrideWith((ref) => repository),
        bookmarkGroupRepoProvider.overrideWith((ref) => groups),
        booruConfigProvider.overrideWith(
          () => _Profiles(profiles),
        ),
        settingsNotifierProvider.overrideWith(
          () => SettingsNotifier(Settings.defaultSettings),
        ),
        ...overrides,
      ],
    );
    await container!.read(bookmarkProvider.future);
    return container!.read(bookmarkProvider.notifier);
  }

  ContentGroupBookmark record(int id, {String key = 'pool:42'}) {
    final summary = ContentGroupSummary(
      reference: const ContentReferenceCodec().parse(
        engine: poolOrigin().booruType,
        site: Uri.parse('https://danbooru.donmai.us'),
        kind: ContentKind.group,
        sourceKey: key,
      ),
      title: 'Original',
      memberCount: 23,
      displayCategory: 'series',
    );
    return ContentGroupBookmark(
      id: id,
      sourceProfileHint: poolProfile,
      snapshot: StoredGroupSnapshot(
        summary: summary,
        details: ContentGroupDetails(
          summary: summary,
          description: const GroupDescription(
            text: 'Original details',
            format: GroupTextFormat.plainText,
          ),
        ),
        index: GroupBookmarkIndex(
          tags: {'source-tag'},
          basis: GroupTagIndexBasis.sourceGroup,
          coverage: MetadataCoverage.complete,
          oldestMemberUpload: DateTime.utc(2020),
          newestMemberUpload: DateTime.utc(2026),
        ),
      ),
      createdAt: DateTime.utc(2019),
      observedAt: DateTime.utc(2025),
    );
  }

  CollectionBookmark summary(CollectionBookmark pool) => pool.copyWith(
    cover: PoolBookmarkCover(
      thumbnail: 'https://danbooru.donmai.us/cover.jpg',
      sample: 'https://danbooru.donmai.us/sample.jpg',
      original: 'https://danbooru.donmai.us/original.jpg',
      variants: {},
    ),
    coverUrl: 'https://danbooru.donmai.us/cover.jpg',
    coverPolicy: 'current-policy',
  );

  test('native cover-only fill preserves source index, details, unrelated records and dates after restart', () async {
    final ids = await repository.reserveIds(2);
    final original = record(ids[0]);
    final unrelated = record(ids[1], key: 'pool:43');
    final group = BookmarkGroup(
      id: poolGroupA,
      name: 'Local',
      bookmarkIds: ids.toSet(),
      addedAt: {for (final id in ids) id: DateTime.utc(2024)},
    );
    await repository.commitOrganization(
      records: [original, unrelated],
      groups: [group],
    );
    final service = await notifier();
    final pool = container!
        .read(bookmarkProvider)
        .requireValue
        .pools
        .firstWhere((p) => p.bookmarkId == original.id);
    await service.fillMissingPoolCover(summary(pool), canCommit: () => true);
    container!.dispose();
    container = null;
    await Hive.close();
    await open();
    final saved = await repository.read(original.id) as ContentGroupBookmark;
    expect(saved.snapshot.index!.basis, GroupTagIndexBasis.sourceGroup);
    expect(saved.snapshot.index!.tags, original.snapshot.index!.tags);
    expect(saved.snapshot.index!.coverage, original.snapshot.index!.coverage);
    expect(
      saved.snapshot.index!.oldestMemberUpload,
      original.snapshot.index!.oldestMemberUpload,
    );
    expect(
      saved.snapshot.index!.newestMemberUpload,
      original.snapshot.index!.newestMemberUpload,
    );
    expect(saved.snapshot.index!.coverPolicy, 'current-policy');
    expect(
      saved.summary.cover!.thumbnail,
      Uri.parse('https://danbooru.donmai.us/cover.jpg'),
    );
    expect(saved.summary.reference, original.summary.reference);
    expect(saved.summary.title, original.summary.title);
    expect(saved.summary.memberCount, 23);
    expect(
      saved.snapshot.details!.description,
      original.snapshot.details!.description,
    );
    expect(saved.createdAt, original.createdAt);
    expect(saved.observedAt, original.observedAt);
    expect(saved.sourceProfileHint, original.sourceProfileHint);
    expect(await repository.read(unrelated.id), unrelated);
    expect(await groups.getGroup(poolGroupA), group);
  });

  test(
    'retained legacy cover-only fill keeps its format and non-cover metadata',
    () async {
      final id = (await repository.reserveIds(1)).single;
      final original = LegacyGroupBookmark.fromMetadata(
        id: id,
        metadata: testPool(),
      );
      await repository.commitOrganization(
        records: [original],
        groups: [
          BookmarkGroup(
            id: poolGroupA,
            name: 'Local',
            bookmarkIds: {id},
            addedAt: {id: DateTime.utc(2024)},
          ),
        ],
      );
      final service = await notifier();
      final pool = container!.read(bookmarkProvider).requireValue.pools.single;
      await service.fillMissingPoolCover(summary(pool), canCommit: () => true);
      final saved = await repository.read(id) as LegacyGroupBookmark;
      expect(saved.metadata.cover, isNotNull);
      expect(saved.metadata.tags, original.metadata.tags);
      expect(saved.metadata.coverage, original.metadata.coverage);
      expect(saved.metadata.sourceSite, isNull);
      expect(saved.createdAt, original.createdAt);
      expect(saved.observedAt, original.observedAt);
    },
  );

  test(
    'received-only cover fill never attempts a publisher payload mutation',
    () async {
      final id = (await repository.reserveIds(1)).single;
      final original = record(id);
      final group = BookmarkGroup(
        id: poolGroupA,
        name: 'Received',
        bookmarkIds: {id},
        addedAt: {id: DateTime.utc(2024)},
      );
      final mirrors = BookmarkMirrorState(
        epoch: 1,
        owners: {
          poolGroupA: BookmarkMirrorOwner(
            publisher: poolProfile,
            source: poolGroupB,
            revision: 1,
            payloadDigest: 'a' * 64,
            groupDigest: bookmarkMirrorGroupDigest(group),
          ),
        },
        subscriptions: {
          poolProfile: {poolGroupB},
        },
      );
      await repository.commitMirrorOrganization(
        expected: const BookmarkMirrorState.empty(),
        next: mirrors,
        records: [original],
        groups: [group],
      );
      final service = await notifier();
      final beforeRevision = await repository.readRevision();
      final pool = container!.read(bookmarkProvider).requireValue.pools.single;
      await service.fillMissingPoolCover(summary(pool), canCommit: () => true);
      expect(await repository.read(id), original);
      expect(await repository.readMirrorState(), mirrors);
      expect(await repository.readRevision(), beforeRevision);
      expect(await groups.getGroup(poolGroupA), group);
    },
  );
  for (final membership in [
    'local',
    'received',
    'shared',
    'replaced',
    'revoked',
    'forgotten',
    'public',
    'public-replaced',
  ]) {
    test(
      'real Hive $membership cover lookup preserves publisher authority',
      () async {
        final id = (await repository.reserveIds(1)).single;
        final original = record(id).copyWith(
          sourceProfileHint: membership.startsWith('public')
              ? () => null
              : null,
        );
        final local = BookmarkGroup(
          id: poolGroupB,
          name: 'Local',
          bookmarkIds: {id},
          addedAt: {id: DateTime.utc(2023)},
        );
        final received = BookmarkGroup(
          id: poolGroupA,
          name: 'Received',
          bookmarkIds: {id},
          addedAt: {id: DateTime.utc(2024)},
        );
        var mirrors = const BookmarkMirrorState.empty();
        if (membership == 'local') {
          await repository.commitOrganization(
            records: [original],
            groups: [local],
          );
        } else {
          mirrors = BookmarkMirrorState(
            epoch: 1,
            owners: {
              poolGroupA: BookmarkMirrorOwner(
                publisher: poolProfile,
                source: poolGroupB,
                revision: 1,
                payloadDigest: 'a' * 64,
                groupDigest: bookmarkMirrorGroupDigest(received),
              ),
            },
            subscriptions: {
              poolProfile: {poolGroupB},
            },
          );
          await repository.commitMirrorOrganization(
            expected: const BookmarkMirrorState.empty(),
            next: mirrors,
            records: [original],
            groups: [received],
          );
        }
        if (membership == 'shared') {
          await repository.commitOrganization(groups: [local]);
        }
        var config = BooruConfig.fromJson({
          ...BooruConfig.empty.toJson(),
          'id': poolProfile,
          'url': 'https://danbooru.donmai.us',
          'booruId': original.reference.engine.id,
          'booruIdHint': original.reference.engine.id,
        });
        ContentAccessContext? publicAccess;
        if (membership.startsWith('public')) {
          final source = const AnonymousSourcePolicy().resolve(
            original.reference.engine,
            original.reference.site,
          )!;
          final scope = AnonymousReadScope(
            source: source,
            key: ContentAccessKey(
              engine: source.engine,
              siteNamespace: source.site.host,
              authEpoch: 1,
              policyEpoch: 1,
            ),
            createDio: () => throw StateError('Fake metadata only'),
            current: () => true,
          );
          addTearDown(scope.dispose);
          config = config.copyWith(anonymousReadScope: scope);
          publicAccess = ContentAccessContext.anonymous(
            config: config,
            scope: scope,
          );
        }
        var calls = 0;
        final entered = Completer<void>();
        final release = Completer<void>();
        final interrupted = [
          'replaced',
          'revoked',
          'forgotten',
          'public-replaced',
        ].contains(membership);
        await notifier(
          profiles: membership.startsWith('public') ? [] : [config],
          overrides: [
            if (publicAccess != null)
              contentAccessContextProvider(publicAccess.key)
                  .overrideWith((ref) => publicAccess),
            blacklistTagsProvider.overrideWith((ref, filter) async => {}),
            originAwarePostRepoProvider.overrideWith(
              (ref, config) => PostRepositoryBuilder<Post>(
                fetch: (tags, page, {limit, options}) async {
                  calls++;
                  expect(limit, lessThanOrEqualTo(40));
                  if (interrupted && calls == 1) {
                    entered.complete();
                    await release.future;
                  } else if (interrupted) {
                    return PostResult<Post>.empty();
                  }
                  return PostResult(
                    posts: [
                      TestPost(
                        id: 100,
                        origin: postOriginFromConfig(config),
                        thumbnailImageUrl:
                            'https://danbooru.donmai.us/cover.jpg',
                      ),
                    ],
                    total: 1,
                  );
                },
                fetchSingle: (_, {options}) async => null,
                getSettings: () async => Settings.defaultSettings.listing,
                tagComposer: EmptyTagQueryComposer(),
              ),
            ),
          ],
        );
        final pool = container!
            .read(bookmarkProvider)
            .requireValue
            .pools
            .single;
        final beforeGroups = await groups.getGroups();
        final revision = await repository.readRevision();
        final request = missingPoolCoverProvider((config, pool));
        final subscription = container!.listen(request, (_, _) {});
        addTearDown(subscription.close);
        final pending = container!.read(request.future);
        if (interrupted) {
          await entered.future;
          if (membership == 'revoked') {
            (container!.read(booruConfigProvider.notifier) as _Profiles)
                .revoke();
          } else if (membership == 'forgotten') {
            await repository.commitMirrorOrganization(
              expected: mirrors,
              next: BookmarkMirrorState(
                epoch: 2,
                owners: {},
                checkpoints: mirrors.checkpoints,
                forgotten: {poolProfile},
              ),
              removeIds: {id},
              removeGroupIds: {poolGroupA},
            );
            await container!.read(bookmarkProvider.notifier).refresh();
          } else {
            final replacement = original.copyWith(
              observedAt: DateTime.utc(2030),
            );
            final next = BookmarkMirrorState(
              epoch: 2,
              owners: {
                poolGroupA: BookmarkMirrorOwner(
                  publisher: poolProfile,
                  source: poolGroupB,
                  revision: 2,
                  payloadDigest: 'b' * 64,
                  groupDigest: bookmarkMirrorGroupDigest(received),
                ),
              },
              subscriptions: {
                poolProfile: {poolGroupB},
              },
            );
            await repository.commitMirrorOrganization(
              expected: mirrors,
              next: next,
              records: [replacement],
            );
            await container!.read(bookmarkProvider.notifier).refresh();
          }
          release.complete();
        }
        final covered = await pending;
        expect(covered?.cover, interrupted ? isNull : isNotNull);
        if (interrupted) {
          final after = await repository.read(id);
          expect(
            after is ContentGroupBookmark ? after.summary.cover : null,
            isNull,
          );
          return;
        }
        expect(calls, 1);
        expect(await repository.readMirrorState(), mirrors);
        expect(await groups.getGroups(), beforeGroups);
        final saved = await repository.read(id) as ContentGroupBookmark;
        if (membership != 'local') {
          expect(saved, original);
          expect(await repository.readRevision(), revision);
        } else {
          expect(saved.summary.cover, isNotNull);
          expect(saved.snapshot.index!.basis, GroupTagIndexBasis.sourceGroup);
        }
      },
    );
  }

  test('replacement or preexisting native cover cannot be overwritten by late summary', () async {
    final id = (await repository.reserveIds(1)).single;
    final original = record(id);
    await repository.commitOrganization(
      records: [original],
      groups: [
        BookmarkGroup(
          id: poolGroupA,
          name: 'Local',
          bookmarkIds: {id},
          addedAt: {id: DateTime.utc(2024)},
        ),
      ],
    );
    final service = await notifier();
    final draft = summary(
      container!.read(bookmarkProvider).requireValue.pools.single,
    );
    await service.fillMissingPoolCover(draft, canCommit: () => true);
    final covered = await repository.read(id);
    await service.fillMissingPoolCover(
      draft.copyWith(coverUrl: 'https://other.example/changed.jpg'),
      canCommit: () => true,
    );
    expect(await repository.read(id), covered);
    await service.fillMissingPoolCover(
      testPool(id: 43)
          .copyWith(localId: draft.localId, bookmarkId: () => draft.bookmarkId),
      canCommit: () => true,
    );
    expect(await repository.read(id), covered);
    await service.fillMissingPoolCover(draft, canCommit: () => false);
    expect(await repository.read(id), covered);
  });
}

class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> profiles) : super(initialConfigs: profiles);
  void revoke() => state = [];
}
