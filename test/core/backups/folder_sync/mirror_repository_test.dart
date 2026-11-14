import 'dart:io';

import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_mirror_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_record_fields.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../../boorus/pixiv/works/work_test_fixtures.dart';

const local = '11111111-1111-4111-8111-111111111111';
const publisher = '22222222-1111-4111-8111-111111111111';
const source = '33333333-1111-4111-8111-111111111111';

void main() {
  late Directory directory;
  late BookmarkHiveRepository repository;
  late UnifiedBookmarkGroupRepository groups;
  late BookmarkLibraryService service;
  late Box<dynamic> metadata;
  var interruptOrganization = false;

  Future<void> open() async {
    final posts = await Hive.openBox<BookmarkHiveObject>('posts');
    final payloads = await Hive.openBox<dynamic>('payloads');
    metadata = await Hive.openBox<dynamic>('metadata');
    final legacy = await Hive.openBox<BookmarkGroupHiveObject>('legacy');
    final folders = await Hive.openBox<dynamic>('folders');
    repository = BookmarkHiveRepository(
      posts,
      groupPayloadBox: payloads,
      metadataBox: metadata,
      coordinator: DataMutationCoordinator(),
      postDataCodec: (_) => const PixivPostCodec(),
      syncBoxes: (boxes) async {
        for (final box in boxes) {
          await box.flush();
        }
        if (interruptOrganization &&
            boxes.any((box) => box.name.endsWith('_hierarchy_v3'))) {
          interruptOrganization = false;
          throw StateError(
            'Interrupted after organization before ownership commit',
          );
        }
      },
    );
    final reader = await BookmarkStorageMigration(
      bookmarks: repository,
      legacyGroups: legacy,
      legacyOrganization: folders,
      metadata: metadata,
    ).open();
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: repository,
      reader: reader,
    );
    service = BookmarkLibraryService(
      bookmarkRepository: repository,
      groupRepository: groups,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
    await service.load();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync_mirror_repo_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    await open();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<BookmarkGroup> install({bool withRecord = true}) async {
    final at = DateTime.utc(2026, 11, 14);
    final records = <Bookmark>[];
    if (withRecord) {
      final access = workAccess();
      final draft = PixivWorkBookmarkTarget(
        access: access,
        summary: pixivWorkSummary(work(), access),
      ).draft(currentAccess: access, at: at);
      records.add(
        bookmarkWithId(draft, (await repository.reserveIds(1)).single),
      );
    }
    final group = BookmarkGroup(
      id: local,
      name: 'Source owned',
      bookmarkIds: records.map((r) => r.id).toSet(),
      addedAt: {for (final record in records) record.id: at},
    );
    final before = await repository.readMirrorState();
    final owner = BookmarkMirrorOwner(
      publisher: publisher,
      source: source,
      revision: 1,
      payloadDigest: 'a' * 64,
      groupDigest: bookmarkMirrorGroupDigest(group),
    );
    await repository.commitMirrorOrganization(
      expected: before,
      next: BookmarkMirrorState(
        epoch: before.epoch + 1,
        owners: {local: owner},
        subscriptions: {
          publisher: {source},
        },
      ),
      records: records,
      groups: [group],
    );
    return group;
  }

  test('ownership and memberships survive restart; All Bookmarks requires a local membership', () async {
    final mirror = await install();
    var state = await service.load();
    expect(state.mirrors.isReceived(mirror.id), isTrue);
    expect(
      selectNativeGroupBookmarks(
        state: state,
        view: const BookmarkView.all(),
        selectedTags: const [],
      ),
      isEmpty,
    );
    expect(state.bookmarkIdsForView(const BookmarkView.all()), isEmpty);
    expect(
      state.bookmarkIdsForView(BookmarkView.group(mirror.id)),
      mirror.bookmarkIds,
    );
    final editable = await groups.createGroup('Local');
    await groups.replaceMemberships(editable.id, mirror.bookmarkIds);
    state = await service.load();
    expect(
      state.bookmarkIdsForView(const BookmarkView.all()),
      mirror.bookmarkIds,
    );
    expect(state.records, hasLength(1));
    await Hive.close();
    Hive.init(directory.path);
    await open();
    expect((await repository.readMirrorState()).owners[local]!.source, source);
    expect(metadata.get('repositorySchema'), 2);
    expect(
      (await service.load()).bookmarkIdsForView(const BookmarkView.all()),
      mirror.bookmarkIds,
    );
  });

  test('repository rejects mirror rename, move, membership, global deletion and local children', () async {
    final mirror = await install();
    await expectLater(
      groups.renameGroup(local, 'Local rename'),
      throwsA(isA<BookmarkMirrorReadOnly>()),
    );
    await expectLater(
      groups.replaceMemberships(local, {}),
      throwsA(isA<BookmarkMirrorReadOnly>()),
    );
    await expectLater(
      repository.commitOrganization(groups: [mirror.copyWith(position: 9)]),
      throwsA(isA<BookmarkMirrorReadOnly>()),
    );
    await expectLater(
      repository.commitOrganization(removeGroupIds: {local}),
      throwsA(isA<BookmarkMirrorReadOnly>()),
    );
    await expectLater(
      repository.delete(mirror.bookmarkIds.single),
      throwsA(isA<BookmarkMirrorReadOnly>()),
    );
    await expectLater(
      repository.commitOrganization(
        groups: [
          BookmarkGroup(
            id: source,
            name: 'Mixed child',
            parentGroupId: local,
            bookmarkIds: {},
          ),
        ],
      ),
      throwsA(isA<BookmarkMirrorReadOnly>()),
    );
    expect(
      (await groups.getGroups()).singleWhere((g) => g.id == local),
      mirror,
    );
  });

  test('ordinary upsert cannot rewrite a received-only snapshot', () async {
    final mirror = await install();
    final saved =
        (await repository.read(mirror.bookmarkIds.single))!
            as ContentGroupBookmark;
    await expectLater(
      repository.upsert(saved.copyWith(observedAt: DateTime.utc(2026, 12))),
      throwsA(isA<BookmarkMirrorReadOnly>()),
    );
    final localGroup = await groups.createGroup('Local');
    await groups.replaceMemberships(localGroup.id, mirror.bookmarkIds);
    await repository.upsert(saved.copyWith(observedAt: DateTime.utc(2026, 12)));
    expect(
      (await repository.read(saved.id) as ContentGroupBookmark).observedAt,
      DateTime.utc(2026, 12),
    );
  });

  test(
    'receive authority cannot claim or edit an existing local Group',
    () async {
      final editable = await groups.createGroup('Local', id: local);
      final before = await repository.readMirrorState();
      final owner = BookmarkMirrorOwner(
        publisher: publisher,
        source: source,
        revision: 1,
        payloadDigest: 'a' * 64,
        groupDigest: bookmarkMirrorGroupDigest(editable),
      );
      await expectLater(
        repository.commitMirrorOrganization(
          expected: before,
          next: BookmarkMirrorState(
            epoch: before.epoch + 1,
            owners: {local: owner},
          ),
          groups: [editable],
        ),
        throwsFormatException,
      );
      expect((await repository.readMirrorState()).owners, isEmpty);
    },
  );

  test('interrupted organization is recovered with its ownership and applied marker', () async {
    interruptOrganization = true;
    await expectLater(install(), throwsStateError);
    expect(metadata.containsKey('pendingMutation'), isTrue);
    expect(metadata.get('receivedBookmarkOwnership'), isNull);
    await Hive.close();
    Hive.init(directory.path);
    await open();
    final state = await service.load();
    expect(state.mirrors.owners[local]!.revision, 1);
    expect(state.groupsById[local]!.bookmarkIds, hasLength(1));
    expect(state.localBookmarkIds, isEmpty);
    expect(metadata.containsKey('pendingMutation'), isFalse);
    await expectLater(
      groups.renameGroup(local, 'No bypass after recovery'),
      throwsA(isA<BookmarkMirrorReadOnly>()),
    );
  });
}
