import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boorusama/boorus/danbooru/pools/bookmarks.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/boorus/danbooru/pools/details/src/data/providers.dart';
import 'package:boorusama/boorus/szurubooru/pools/bookmarks.dart';
import 'package:boorusama/boorus/szurubooru/pools/providers.dart';
import 'package:boorusama/boorus/szurubooru/pools/types.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_collection_projection.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/bookmark_test_storage.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  test(
    'Danbooru Pool loaded details survive draft save, reopen and v10 export',
    () async {
      final site = Uri.parse('http://dan.local:8081/install');
      final created = DateTime.utc(2021, 2, 3, 4, 5, 6);
      final updated = DateTime.utc(2025, 6, 7, 8, 9, 10);
      final rawPool = DanbooruPool(
        id: 42,
        postIds: const [77123, 77124],
        category: DanbooruPoolCategory.series,
        description: '[b]Saved source description[/b]',
        postCount: 2,
        name: 'Danbooru source title',
        createdAt: created,
        updatedAt: updated,
      );
      await _verifyLoadedDetails(
        engine: BooruType.danbooru,
        site: site,
        remote: danbooruBookmarkPool(rawPool, site: site),
        expectedTitle: 'Danbooru source title',
        expectedCount: 2,
        expectedDescription: '[b]Saved source description[/b]',
        expectedFormat: GroupTextFormat.dtext,
        expectedCreated: created,
        expectedUpdated: updated,
        memberPostIds: rawPool.postIds!,
      );
    },
  );

  test(
    'Szurubooru Pool loaded details survive draft save, reopen and v10 export',
    () async {
      final site = Uri.parse('http://szuru.local:8092/install');
      final created = DateTime.utc(2020, 3, 4, 5, 6, 7);
      final updated = DateTime.utc(2026, 8, 9, 10, 11, 12);
      const description =
          '**Raw Markdown source text**\n\nKeep this exact string.';
      final rawPool = SzurubooruPool(
        id: 73,
        names: const ['Szurubooru source title'],
        category: 'series',
        description: description,
        postCount: 3,
        postIds: const [88231, 88232, 88233],
        thumbnailUrls: const ['https://media.example/cover.jpg'],
        createdAt: created,
        updatedAt: updated,
      );
      await _verifyLoadedDetails(
        engine: BooruType.szurubooru,
        site: site,
        remote: szurubooruBookmarkPool(rawPool, site: site),
        expectedTitle: 'Szurubooru source title',
        expectedCount: 3,
        expectedDescription: description,
        // The saved snapshot retains safe source text; the existing native UI
        // continues to render its original Markdown.
        expectedFormat: GroupTextFormat.plainText,
        expectedCreated: created,
        expectedUpdated: updated,
        memberPostIds: rawPool.postIds!,
      );
    },
  );
}

Future<void> _verifyLoadedDetails({
  required BooruType engine,
  required Uri site,
  required RemoteBookmarkPool remote,
  required String expectedTitle,
  required int expectedCount,
  required String expectedDescription,
  required GroupTextFormat expectedFormat,
  required DateTime expectedCreated,
  required DateTime expectedUpdated,
  required List<int> memberPostIds,
}) async {
  final config = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: engine,
      url: site.toString(),
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': poolProfile,
  });
  var postRepositoryReads = 0;
  var blacklistReads = 0;
  var danbooruMemberReads = 0;
  var szurubooruMemberReads = 0;
  var danbooruDescriptionReads = 0;
  final container = ProviderContainer(
    overrides: [
      bookmarkProvider.overrideWith(() => _EmptyLibrary()),
      originAwarePostRepoProvider.overrideWith((ref, config) {
        postRepositoryReads++;
        throw StateError('Loaded Pool drafts must not request member Posts');
      }),
      blacklistTagsProvider.overrideWith((ref, filter) async {
        blacklistReads++;
        throw StateError('Loaded Pool drafts must not load blacklist tags');
      }),
      danbooruPoolRepoProvider.overrideWith((ref, auth) {
        danbooruMemberReads++;
        throw StateError('Loaded Pool drafts must not fetch Pool members');
      }),
      szurubooruPoolRepoProvider.overrideWith((ref, auth) {
        szurubooruMemberReads++;
        throw StateError('Loaded Pool drafts must not fetch Pool members');
      }),
      poolDescriptionRepoProvider.overrideWith((ref, auth) {
        danbooruDescriptionReads++;
        throw StateError('Loaded Pool drafts must not refetch descriptions');
      }),
    ],
  );
  final draft = await container.read(
    poolBookmarkDraftProvider((config, remote)).future,
  );
  container.dispose();

  expect(draft, isA<PoolBookmark>());
  expect(draft.sourceSite, site);
  expect(draft.origin.booruType, engine);
  expect(draft.origin.sourceHost, '${site.authority}${site.path}');
  expect(draft.referenceId, remote.id);
  expect(draft.category, remote.category);
  expect(draft.title, expectedTitle);
  expect(draft.total, expectedCount);
  expect(draft.loadedDetails, isNotNull);
  expect(postRepositoryReads, 0);
  expect(blacklistReads, 0);
  expect(danbooruMemberReads, 0);
  expect(szurubooruMemberReads, 0);
  expect(danbooruDescriptionReads, 0);

  final provisionalRecord = collectionRecordForSave(draft, id: 0);
  expect(provisionalRecord, isA<ContentGroupBookmark>());
  final provisional = provisionalRecord as ContentGroupBookmark;
  expect(provisional.reference.engine, engine);
  expect(provisional.reference.site, site);
  expect(
    provisional.snapshot.details!.description,
    draft.loadedDetails!.description,
  );
  expect(
    provisional.snapshot.details!.sourceDates,
    draft.loadedDetails!.sourceDates,
  );
  expect(provisional.snapshot.details!.summary.title, expectedTitle);
  expect(provisional.snapshot.details!.description!.text, expectedDescription);
  expect(provisional.snapshot.details!.description!.format, expectedFormat);
  expect(provisional.snapshot.details!.sourceDates!.createdAt, expectedCreated);
  expect(provisional.snapshot.details!.sourceDates!.updatedAt, expectedUpdated);
  expect(provisional.snapshot.details!.creators, isNull);
  expect(provisional.snapshot.details!.sourceData, isNull);

  final directory = await Directory.systemTemp.createTemp(
    'loaded-pool-details-${engine.name}-',
  );
  late Box<BookmarkHiveObject> posts;
  late Box<BookmarkGroupHiveObject> legacyGroups;
  late Box<dynamic> legacyOrganization;
  late BookmarkTestStorage storage;
  late BookmarkHiveRepository bookmarks;
  late UnifiedBookmarkGroupRepository groups;

  Future<void> openBoxes() async {
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    legacyOrganization = await Hive.openBox<dynamic>('organization');
    storage = await BookmarkTestStorage.open(posts);
    bookmarks = storage.repository(posts);
  }

  Future<void> openActive() async {
    final reader = await BookmarkStorageMigration(
      bookmarks: bookmarks,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: storage.metadataBox,
    ).open();
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: bookmarks,
      reader: reader,
    );
  }

  try {
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    await openBoxes();
    final retainedPost = testPoolPost(17).copyWith(id: 0);
    final postDate = DateTime.utc(2024, 1, 2, 3, 4, 5, 123, 456);
    await posts.put(0, favoriteToHiveObject(retainedPost));
    await legacyGroups.put(
      poolGroupA,
      BookmarkGroupHiveObject(
        id: poolGroupA,
        name: 'Saved Pool target',
        bookmarkIds: [0],
        addedAt: {0: postDate.toIso8601String()},
      ),
    );
    await legacyOrganization.put('version', 1);
    await legacyOrganization.put('poolBookmarks', []);
    await openActive();
    final service = BookmarkLibraryService(
      bookmarkRepository: bookmarks,
      groupRepository: groups,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
    final counterBefore =
        contentMap(
              storage.metadataBox.get('idReservation'),
            )['nextId']!
            as int;
    final saved = await service.saveDraftsToGroup(
      [provisionalRecord],
      poolGroupA,
    );
    final savedRecord = saved.createdRecords.single as ContentGroupBookmark;
    expect(saved.addedCount, 1);
    expect(savedRecord.id, counterBefore);
    expect(savedRecord.id, isNot(provisionalRecord.id));
    expect(await bookmarks.read(0), retainedPost);
    var target = (await groups.getGroup(poolGroupA))!;
    expect(target.bookmarkIds, {0, savedRecord.id});
    expect(target.addedAt[0], postDate);
    expect(target.addedAt[savedRecord.id], isNotNull);
    expect(
      contentMap(storage.metadataBox.get('idReservation'))['nextId'],
      counterBefore + 1,
    );

    await Hive.close();
    Hive.init(directory.path);
    await openBoxes();
    await openActive();
    final reopened =
        (await bookmarks.read(savedRecord.id))! as ContentGroupBookmark;
    expect(reopened, savedRecord);
    expect(reopened.reference.engine, engine);
    expect(reopened.reference.site, site);
    expect(reopened.snapshot.details!.summary.title, expectedTitle);
    expect(reopened.snapshot.details!.description!.text, expectedDescription);
    expect(reopened.snapshot.details!.description!.format, expectedFormat);
    expect(reopened.snapshot.details!.sourceDates!.createdAt, expectedCreated);
    expect(reopened.snapshot.details!.sourceDates!.updatedAt, expectedUpdated);
    expect(reopened.snapshot.details!.creators, isNull);
    expect(await bookmarks.read(0), retainedPost);
    target = (await groups.getGroup(poolGroupA))!;
    expect(target.bookmarkIds, {0, savedRecord.id});
    expect(target.addedAt[0], postDate);
    expect(target.addedAt[savedRecord.id], isNotNull);
    expect(legacyGroups.get(poolGroupA)!.bookmarkIds, [0]);

    final backup = BookmarkBackupData.unified(
      records: [reopened],
      groups: [
        BookmarkGroupBackup(
          id: poolGroupA,
          name: 'Saved Pool target',
          bookmarkIds: [reopened.id],
          addedAt: {reopened.id: target.addedAt[reopened.id]!},
        ),
      ],
    );
    final codec = BookmarkBackupCodec();
    final payload = <String, dynamic>{
      'version': 10,
      'data': codec.encode(backup),
      ...backup.extraFields,
    };
    final encoded = jsonEncode(payload);
    expect(memberPostIds.every((id) => !encoded.contains('$id')), isTrue);
    final decoded = codec.parse(decodeData(data: encoded));
    final roundTrip = decoded.records.single as ContentGroupBookmark;
    expect(roundTrip.snapshot.details, reopened.snapshot.details);
    expect(roundTrip.snapshot.details!.description!.text, expectedDescription);
    expect(roundTrip.snapshot.details!.description!.format, expectedFormat);
    expect(roundTrip.snapshot.details!.sourceDates!.createdAt, expectedCreated);
    expect(roundTrip.snapshot.details!.sourceDates!.updatedAt, expectedUpdated);
    expect(decoded.groups.single.bookmarkIds, [reopened.id]);
  } finally {
    await Hive.close();
    await directory.delete(recursive: true);
  }
}

class _EmptyLibrary extends BookmarkLibraryNotifier {
  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: const [],
    groups: const [],
  );
}
