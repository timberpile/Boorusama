import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import 'pool_bookmark_test_utils.dart';

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> posts;
  late Box<dynamic> groups;
  late Box<dynamic> metadata;
  late BookmarkHiveRepository repository;
  String? failAfterCommit;
  int? interruptedId;
  Future<void> sync(Iterable<BoxBase<dynamic>> boxes) async {
    final list = boxes.toList();
    const fs = IoFileSystem();
    for (final box in list) {
      await box.flush();
      await fs.syncFile(box.path!);
      await fs.syncDirectory(p.dirname(box.path!));
    }
    final pending = metadata.containsKey('pendingMutation');
    final phase = switch (true) {
      _ when list.any((box) => identical(box, groups)) => 'payload',
      _ when pending && metadata.get('record:${interruptedId}') == null =>
        'journal',
      _ when pending && metadata.get('record:${interruptedId}') != null =>
        'index',
      _ when !pending && interruptedId != null => 'cleanup',
      _ => null,
    };
    if (failAfterCommit != null && failAfterCommit == phase) {
      failAfterCommit = null;
      throw StateError('Fixture committed $phase failure');
    }
  }

  Future<void> open() async {
    posts = await Hive.openBox<BookmarkHiveObject>('posts');
    groups = await Hive.openBox<dynamic>('groups');
    metadata = await Hive.openBox<dynamic>('metadata');
    repository = BookmarkHiveRepository(
      posts,
      groupPayloadBox: groups,
      metadataBox: metadata,
      coordinator: DataMutationCoordinator(),
      syncBoxes: sync,
    );
  }

  Future<void> restart() async {
    await Hive.close();
    await open();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'unified-bookmark-store-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    failAfterCommit = null;
    interruptedId = null;
    await open();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  ContentGroupBookmark group(int id, {BooruType engine = BooruType.danbooru}) =>
      ContentGroupBookmark(
        id: id,
        snapshot: StoredGroupSnapshot(
          summary: ContentGroupSummary(
            reference: const ContentReferenceCodec().parse(
              engine: engine,
              site: Uri.parse('http://example.test:8080/install'),
              kind: ContentKind.group,
              sourceKey: 'pool:42',
            ),
          ),
        ),
        createdAt: DateTime.utc(2025),
        observedAt: DateTime.utc(2026),
      );

  test('one durable namespace dispatches by kind and preserves existing Post ID zero', () async {
    final old = testPoolPost(7).copyWith(id: 0);
    await posts.put(0, favoriteToHiveObject(old));
    expect((await repository.readAll()).single.id, 0);
    final id = (await repository.reserveIds(1)).single;
    expect(id, 1);
    await repository.upsert(group(id));
    final imported = await repository.addBookmarkWithBookmarks([
      testPoolPost(8).copyWith(id: 0),
    ]);
    expect(imported.single.id, 2);
    expect(await repository.read(0), old);
    expect(await repository.read(1), isA<ContentGroupBookmark>());
    expect((await repository.readAll()).map((record) => record.id), [0, 1, 2]);
    await restart();
    expect((await repository.readAll()).map((record) => record.id), [0, 1, 2]);
    expect(await repository.read(1), isA<ContentGroupBookmark>());
  });

  test('delete and Undo recreation never recycle an issued ID', () async {
    final first = (await repository.addBookmarkWithBookmarks([testPoolPost(7)]))
        .single;
    await repository.delete(first.id);
    await expectLater(repository.upsert(first), throwsFormatException);
    final restored = (await repository.addBookmarkWithBookmarks([first]))
        .single;
    expect(restored.id, greaterThan(first.id));
    expect(restored.snapshot, first.snapshot);
    expect(restored.createdAt, first.createdAt);
    expect(await repository.read(first.id), isNull);
  });

  test(
    'concurrent Post and Group creation use distinct reserved IDs',
    () async {
      final results = await Future.wait<Object>([
        repository.addBookmarkWithBookmarks([testPoolPost(7)]),
        () async {
          final id = (await repository.reserveIds(1)).single;
          await repository.upsert(group(id));
          return id;
        }(),
      ]);
      final post = (results[0] as List<PostBookmark>).single;
      final groupId = results[1] as int;
      expect(post.id, isNot(groupId));
      expect((await repository.readAll()).map((record) => record.id).toSet(), {
        post.id,
        groupId,
      });
    },
  );

  test(
    'compatible repeat imports reuse content independently from file-local IDs',
    () async {
      final first = (await repository.addBookmarkWithBookmarks([
        testPoolPost(7),
      ])).single;
      final repeated = (await repository.addBookmarkWithBookmarks([
        testPoolPost(7).copyWith(id: maxBookmarkId + 10),
      ])).single;
      expect(repeated.id, first.id);
      expect(await repository.readAll(), hasLength(1));
    },
  );

  test(
    'incompatible equal identities fail before publishing a second record',
    () async {
      final id = (await repository.reserveIds(1)).single;
      await repository.upsert(group(id));
      final other = (await repository.reserveIds(1)).single;
      await expectLater(
        repository.upsert(group(other, engine: BooruType.szurubooru)),
        throwsFormatException,
      );
      expect(await repository.readAll(), [group(id)]);
      expect(await repository.read(other), isNull);
    },
  );

  test(
    'commit-then-throw at each mutation sync boundary replays durably',
    () async {
      for (final boundary in ['journal', 'payload', 'index', 'cleanup']) {
        final id = (await repository.reserveIds(1)).single;
        interruptedId = id;
        failAfterCommit = boundary;
        await expectLater(
          repository.upsert(group(id)),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains(boundary),
            ),
          ),
        );
        await restart();
        expect(await repository.read(id), group(id), reason: boundary);
        expect(
          metadata.containsKey('pendingMutation'),
          isFalse,
          reason: boundary,
        );
        expect(
          (await repository.reserveIds(1)).single,
          greaterThan(id),
          reason: boundary,
        );
        interruptedId = null;
        await repository.delete(id);
      }
    },
  );

  test(
    'deletion interruption cannot expose a kind index without its payload',
    () async {
      final id = (await repository.reserveIds(1)).single;
      await repository.upsert(group(id));
      interruptedId = id;
      failAfterCommit = 'payload';
      await expectLater(repository.delete(id), throwsStateError);
      await restart();
      expect(await repository.read(id), isNull);
      expect(await repository.readAll(), isEmpty);
    },
  );

  test('unreserved IDs and damaged journals block writes without overwriting payloads', () async {
    await expectLater(repository.upsert(group(100)), throwsFormatException);
    expect(groups, isEmpty);
    await metadata.put('pendingMutation', {
      'version': 1,
      'hash': 'incorrect',
      'plan': {},
    });
    await metadata.flush();
    await expectLater(repository.readAll(), throwsFormatException);
    expect(groups, isEmpty);
  });

  test('startup rejects a corrupt reservation counter', () async {
    await metadata.put('idReservation', {'version': 1, 'nextId': -1});
    await metadata.flush();
    await expectLater(repository.readAll(), throwsFormatException);
    expect(metadata.containsKey('repositorySchema'), isFalse);
  });

  test('startup rejects a corrupt content index', () async {
    final id = (await repository.reserveIds(1)).single;
    await repository.upsert(group(id));
    final contentKey = metadata.keys.whereType<String>().singleWhere(
      (key) => key.startsWith('content:'),
    );
    await metadata.put(contentKey, {
      ...(metadata.get(contentKey) as Map).cast<String, Object?>(),
      'id': id + 1,
    });
    await metadata.flush();
    await restart();
    await expectLater(repository.readAll(), throwsFormatException);
  });
}
