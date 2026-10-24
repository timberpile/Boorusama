import 'dart:async';
import 'dart:convert';

import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

import 'test_support.dart';

void main() {
  late FavoriteHarness h;
  setUp(() async {
    h = FavoriteHarness();
    await h.open(sharedAuth: true);
  });
  tearDown(() => h.close());

  test('favoriting publishes committed memberships without decoding the saved library', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final group = await library.createGroup('Favorites');
    await library.addPostsToGroup(h.profile.auth, [h.post(1)], null);
    await h.container
        .read(serverFavoriteSettingsProvider.notifier)
        .setGlobal(group.id);
    final before = await library.snapshotForExport();
    final saved = before.items.single;
    final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
    performanceRecorder.start();
    addTearDown(performanceRecorder.clear);
    // Cover an existing post joining this group, a new bookmark, and a repeat.
    for (final id in [1, 2, 2]) {
      final projection = await fetch.prepareProjection(
        h.profile.auth,
        id,
        true,
        profileId: h.profile.id,
      );
      await projection!();
    }
    performanceRecorder.stop();
    final operations =
        (performanceRecorder.snapshot()['summary']! as Map)['operations']
            as List;
    expect(
      operations.where((op) => (op as Map)['op'] == 'bookmarkDecodeAll'),
      isEmpty,
    );
    final after = await library.snapshotForExport();
    expect(after.items.map((b) => b.post.id), [1, 2]);
    expect(identical(after.bookmarksById[saved.id], saved), isTrue);
    expect(before.groupsById[group.id]!.bookmarkIds, isEmpty);
    expect(before.items, [saved]);
    expect(
      after.groupsById[group.id]!.bookmarkIds,
      after.bookmarksById.keys.toSet(),
    );
    expect(after.membershipsFor(saved.uniqueId), {
      before.activeTarget.groupId,
      group.id,
    });
    // A cold reload must produce the same contents and all derived indexes.
    await library.syncActiveTargetFromSettings();
    final reloaded = await library.snapshotForExport();
    expect(after, reloaded);
    expect(after.bookmarksById, reloaded.bookmarksById);
    expect(after.bookmarksByUniqueId, reloaded.bookmarksByUniqueId);
    expect(after.membershipsByBookmark, reloaded.membershipsByBookmark);
    expect(after.bookmarks, reloaded.bookmarks);
  });

  test('explicit favorites pages use bulk pacing while direct actions stay interactive', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final group = await library.createGroup('Favorites');
    await h.container
        .read(serverFavoriteSettingsProvider.notifier)
        .setGlobal(group.id);
    final source = _RequestContextSource([h.post(1), h.post(2), h.post(3)])
      ..pages = {
        1: [h.post(1)],
        2: [h.post(2)],
      };
    h.sources[h.profile.id] = source;
    final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
    expect(
      (await fetch.start(h.profile.id)).status,
      ServerFavoriteFetchStatus.completed,
    );
    expect(source.pageContexts, hasLength(2));
    for (final context in source.pageContexts) {
      expect(context.requestClass, ApiRequestClass.bulkTransfer);
      expect(context.allowCooldownRetry, isFalse);
      expect(context.canStart?.call(), isTrue);
    }
    final projection = await fetch.prepareProjection(
      h.profile.auth,
      3,
      true,
      profileId: h.profile.id,
    );
    await projection!();
    expect(
      source.postContexts.single.requestClass,
      ApiRequestClass.interactive,
    );
    expect(
      ApiRequestContext.current().requestClass,
      ApiRequestClass.interactive,
    );
  });

  test(
    'cancelling a favorites job revokes admission for queued requests',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final group = await library.createGroup('Favorites');
      await h.container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(group.id);
      final source = _RequestContextSource([h.post(1)])..pending = Completer();
      h.sources[h.profile.id] = source;
      final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
      final running = fetch.start(h.profile.id);
      await source.requested.future;
      final context = source.pageContexts.single;
      expect(context.canStart?.call(), isTrue);
      fetch.cancel(h.profile.id);
      expect((await running).status, ServerFavoriteFetchStatus.cancelled);
      expect(context.canStart?.call(), isFalse);
      source.pending!.complete(
        ServerFavoritePage(source.posts, hasMore: false),
      );
      expect((await library.snapshotForExport()).items, isEmpty);
    },
  );

  for (final favorited in [true, false]) {
    test(
      'account replacement during ${favorited ? 'favorite' : 'unfavorite'} preparation cannot redirect a projection',
      () async {
        final library = h.container.read(bookmarkLibraryProvider.notifier);
        final target = await library.createGroup('Favorites');
        await h.container
            .read(serverFavoriteSettingsProvider.notifier)
            .setGlobal(target.id);
        if (!favorited) {
          await library.addPostsToGroup(h.profile.auth, [h.post(1)], target.id);
        }
        final before = await library.snapshotForExport();
        final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
        final preparation = fetch.prepareProjection(
          h.profile.auth,
          1,
          favorited,
          profileId: h.profile.id,
        );
        // The first continuation checks the original auth; this queued change
        // runs before _capture resumes after its own settings await. The fake's
        // notifier and repository share this list, so both see the replacement.
        scheduleMicrotask(() {
          h.profiles.profiles[0] = BooruConfig.fromJson({
            ...h.profile.toJson(),
            'login': 'replacement-account',
          });
        });
        await expectLater(
          preparation,
          throwsA(
            isA<ServerFavoriteException>().having(
              (error) => error.problem,
              'problem',
              ServerFavoriteProblem.accountChanged,
            ),
          ),
        );
        expect(await library.snapshotForExport(), before);
      },
    );
  }

  test(
    'multi-page favorites keep server order under newest bookmark sorting',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final target = await library.createGroup('Favorites');
      await h.container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(target.id);
      // Favorite order deliberately differs from numeric post/upload order.
      h.source.pages = {
        1: [h.post(90), h.post(12)],
        2: [h.post(700), h.post(2)],
        3: [h.post(4)],
      };
      final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
      expect(
        (await fetch.start(h.profile.id)).status,
        ServerFavoriteFetchStatus.completed,
      );
      final state = await library.snapshotForExport();
      final ordered = filterBookmarks(
        bookmarks: state.items,
        selectedTags: [],
        sortType: BookmarkSortType.newest,
      );
      expect(ordered.map((b) => b.post.id), [90, 12, 700, 2, 4]);
      final originals = {for (final b in state.items) b.post.id: b};
      expect((await fetch.start(h.profile.id)).added, 0);
      expect({
        for (final b in (await library.snapshotForExport()).items) b.post.id: b,
      }, originals);
    },
  );

  test('fetching one inheriting profile preserves other favorites and manual bookmarks', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final target = await library.createGroup('Shared');
    await h.container
        .read(serverFavoriteSettingsProvider.notifier)
        .setGlobal(target.id);
    await library.addPostsToGroup(h.profile.auth, [h.post(99)], target.id);
    final other = h.profiles.profiles.last;
    final source = FavoriteTestSource([h.post(3), h.post(2)]);
    h.sources[other.id] = source;
    final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
    await fetch.start(other.id);
    final before = await library.snapshotForExport();
    final preserved = {for (final b in before.items) b.post.id: b};
    h.source.posts = [h.post(1), h.post(2)];
    final result = await fetch.start(h.profile.id);
    expect(result.added, 1);
    expect(source.calls, 1);
    final after = await library.snapshotForExport();
    expect(
      after.groupsById[target.id]!.bookmarkIds
          .map((id) => after.bookmarksById[id]!.post.id)
          .toSet(),
      {99, 3, 2, 1},
    );
    for (final b in after.items.where(
      (b) => preserved.containsKey(b.post.id),
    )) {
      expect(b, preserved[b.post.id]);
    }
  });

  test(
    'confirmed first binding clears only selected groups and never fetches',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final global = await library.createGroup('Global');
      final override = await library.createGroup('Override');
      final other = await library.createGroup('Keep');
      await library.addPostsToGroup(h.profile.auth, [h.post(3)], global.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(4)], override.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(3)], other.id);
      final before = await library.snapshotForExport();
      final settings = h.container.read(
        serverFavoriteSettingsProvider.notifier,
      );
      await settings.saveForProfile(
        profile: h.profile,
        expected: await h.container.read(serverFavoriteSettingsProvider.future),
        globalGroupId: global.id,
        target: ServerFavoriteTarget.group(override.id),
        confirmedClears: [
          before.groupsById[global.id]!,
          before.groupsById[override.id]!,
        ],
      );
      final after = await library.snapshotForExport();
      expect(after.groupsById[global.id]!.bookmarkIds, isEmpty);
      expect(after.groupsById[override.id]!.bookmarkIds, isEmpty);
      expect(
        after.groupsById[other.id]!.bookmarkIds,
        before.groupsById[other.id]!.bookmarkIds,
      );
      expect(after.items.map((b) => b.post.id), [3]);
      expect(h.source.calls, 0);
      final progress = await h.container
          .read(serverFavoriteFetchProvider.notifier)
          .start(h.profile.id);
      expect(progress.added, 2);
      expect(
        (await library.snapshotForExport())
            .groupsById[override.id]!
            .bookmarkIds
            .length,
        2,
      );
    },
  );

  test(
    'changed contents invalidate confirmation before any group is cleared',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final first = await library.createGroup('First');
      final second = await library.createGroup('Second');
      await library.addPostsToGroup(h.profile.auth, [h.post(3)], first.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(4)], second.id);
      final shown = await library.snapshotForExport();
      await library.addPostsToGroup(h.profile.auth, [h.post(5)], second.id);
      final before = await library.snapshotForExport();
      await expectLater(
        h.container
            .read(serverFavoriteSettingsProvider.notifier)
            .saveForProfile(
              profile: h.profile,
              expected: await h.container.read(
                serverFavoriteSettingsProvider.future,
              ),
              globalGroupId: first.id,
              target: ServerFavoriteTarget.group(second.id),
              confirmedClears: [
                shown.groupsById[first.id]!,
                shown.groupsById[second.id]!,
              ],
            ),
        throwsA(
          isA<ServerFavoriteException>().having(
            (e) => e.problem,
            'problem',
            ServerFavoriteProblem.confirmationRequired,
          ),
        ),
      );
      expect(await library.snapshotForExport(), before);
      expect(
        (await h.container.read(serverFavoriteSettingsProvider.future))
            .globalGroupId,
        isNull,
      );
      expect(h.source.calls, 0);
    },
  );

  test(
    'failed combined persistence restores cleared bookmarks and assignments',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final first = await library.createGroup('First');
      final second = await library.createGroup('Second');
      await library.addPostsToGroup(h.profile.auth, [h.post(3)], first.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(4)], second.id);
      final before = await library.snapshotForExport();
      final old = await h.container.read(serverFavoriteSettingsProvider.future);
      h.store.fail = true;
      await expectLater(
        h.container
            .read(serverFavoriteSettingsProvider.notifier)
            .saveForProfile(
              profile: h.profile,
              expected: old,
              globalGroupId: first.id,
              target: ServerFavoriteTarget.group(second.id),
              confirmedClears: [
                before.groupsById[first.id]!,
                before.groupsById[second.id]!,
              ],
            ),
        throwsStateError,
      );
      final after = await library.snapshotForExport();
      for (final group in [first, second]) {
        expect(
          after.groupsById[group.id]!.bookmarkIds
              .map((id) => after.bookmarksById[id]!.post.id)
              .toSet(),
          before.groupsById[group.id]!.bookmarkIds
              .map((id) => before.bookmarksById[id]!.post.id)
              .toSet(),
        );
      }
      expect(after.items.map((b) => b.post.id).toSet(), {3, 4});
      expect(
        await h.container.read(serverFavoriteSettingsProvider.future),
        old,
      );
      expect(h.source.calls, 0);
    },
  );

  test(
    'combined save preserves other profile changes and rejects stale drafts',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final group = await library.createGroup('Target');
      final settings = h.container.read(
        serverFavoriteSettingsProvider.notifier,
      );
      final old = await h.container.read(serverFavoriteSettingsProvider.future);
      final other = h.profiles.profiles.last;
      await settings.setProfile(other.id, const ServerFavoriteTarget.none());
      await settings.saveForProfile(
        profile: h.profile,
        expected: old,
        globalGroupId: group.id,
        target: const ServerFavoriteTarget.inherit(),
      );
      final updated = await h.container.read(
        serverFavoriteSettingsProvider.future,
      );
      expect(updated.targetFor(other.id), const ServerFavoriteTarget.none());
      expect(updated.resolve(h.profile.id), group.id);
      await expectLater(
        settings.saveForProfile(
          profile: h.profile,
          expected: old,
          globalGroupId: null,
          target: const ServerFavoriteTarget.none(),
        ),
        throwsA(
          isA<ServerFavoriteException>().having(
            (e) => e.problem,
            'problem',
            ServerFavoriteProblem.targetChanged,
          ),
        ),
      );
      expect(
        await h.container.read(serverFavoriteSettingsProvider.future),
        updated,
      );
    },
  );

  test(
    'Save & Fetch refuses a changed account or target rather than redirecting',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final first = await library.createGroup('First');
      final second = await library.createGroup('Second');
      final settings = h.container.read(
        serverFavoriteSettingsProvider.notifier,
      );
      await settings.setGlobal(first.id);
      final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
      final result = await fetch.start(
        h.profile.id,
        expectedSession: ServerFavoriteSession(h.profile, second.id),
      );
      expect(result.problem, ServerFavoriteProblem.targetChanged);
      final oldProfile = BooruConfig.fromJson({
        ...h.profile.toJson(),
        'login': 'old-account',
      });
      expect(
        (await fetch.start(
          h.profile.id,
          expectedSession: ServerFavoriteSession(oldProfile, first.id),
        )).problem,
        ServerFavoriteProblem.accountChanged,
      );
      expect(h.source.calls, 0);
    },
  );

  test('shared targets repeat additively with real bookmark storage', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final target = await library.createGroup('Favorites');
    await h.container
        .read(serverFavoriteSettingsProvider.notifier)
        .setGlobal(target.id);
    final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
    final first = await fetch.start(h.profile.id);
    expect(first.status, ServerFavoriteFetchStatus.completed);
    expect(first.added, 2);
    final secondProfile = h.profiles.profiles.last;
    await h.container
        .read(serverFavoriteSettingsProvider.notifier)
        .setProfile(secondProfile.id, ServerFavoriteTarget.group(target.id));
    expect((await fetch.start(secondProfile.id)).added, 0);
    expect(
      (await library.snapshotForExport())
          .groupsById[target.id]!
          .bookmarkIds
          .length,
      2,
    );
    expect(h.bookmarkBox.length, 2);
  });

  test(
    'exact originating profile disambiguates shared auth and opt-out',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final target = await library.createGroup('Favorites');
      final settings = h.container.read(
        serverFavoriteSettingsProvider.notifier,
      );
      await settings.setGlobal(target.id);
      await settings.setProfile(
        h.profiles.profiles.last.id,
        const ServerFavoriteTarget.none(),
      );
      final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
      await expectLater(
        fetch.prepareProjection(h.profile.auth, 1, true),
        throwsA(isA<ServerFavoriteException>()),
      );
      final add = await fetch.prepareProjection(
        h.profile.auth,
        1,
        true,
        profileId: h.profile.id,
      );
      await add!();
      final none = await fetch.prepareProjection(
        h.profile.auth,
        2,
        true,
        profileId: h.profiles.profiles.last.id,
      );
      expect(none, isNull);
      expect(
        (await library.snapshotForExport())
            .groupsById[target.id]!
            .bookmarkIds
            .length,
        1,
      );
    },
  );

  test('changed targets and accounts reject captured writes', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final target = await library.createGroup('Favorites');
    final other = await library.createGroup('Other');
    final settings = h.container.read(serverFavoriteSettingsProvider.notifier);
    await settings.setGlobal(target.id);
    final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
    final oldTarget = await fetch.prepareProjection(
      h.profile.auth,
      1,
      true,
      profileId: h.profile.id,
    );
    await settings.setGlobal(other.id);
    await expectLater(oldTarget!(), throwsA(isA<ServerFavoriteException>()));
    final oldAccount = await fetch.prepareProjection(
      h.profile.auth,
      1,
      true,
      profileId: h.profile.id,
    );
    h.profiles.profiles = [
      BooruConfig.fromJson({...h.profile.toJson(), 'login': 'changed'}),
    ];
    await h.container.read(booruConfigProvider.notifier).fetch();
    await expectLater(oldAccount!(), throwsA(isA<ServerFavoriteException>()));
    expect(h.bookmarkBox.isEmpty, isTrue);
  });

  test('target change cancels a late page without redirecting it', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final target = await library.createGroup('Favorites');
    final other = await library.createGroup('Other');
    final settings = h.container.read(serverFavoriteSettingsProvider.notifier);
    await settings.setGlobal(target.id);
    h.source.pending = Completer<ServerFavoritePage<Post>>();
    final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
    final result = fetch.start(h.profile.id);
    await h.source.requested.future;
    await settings.setGlobal(other.id);
    expect((await result).status, ServerFavoriteFetchStatus.cancelled);
    h.source.pending!.complete(ServerFavoritePage([h.post(1)], hasMore: false));
    await Future<void>.value();
    expect(h.bookmarkBox.isEmpty, isTrue);
  });

  test(
    'unfavorite cancels an overlapping page and preserves other memberships',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final target = await library.createGroup('Favorites');
      final other = await library.createGroup('Other');
      await h.container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(target.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(1)], target.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(1)], other.id);
      final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
      h.source.pending = Completer<ServerFavoritePage<Post>>();
      final fetching = fetch.start(h.profile.id);
      await h.source.requested.future;
      final remove = await fetch.prepareProjection(
        h.profile.auth,
        1,
        false,
        profileId: h.profile.id,
      );
      await remove!();
      expect((await fetching).status, ServerFavoriteFetchStatus.cancelled);
      h.source.pending!.complete(
        ServerFavoritePage([h.post(1)], hasMore: false),
      );
      final saved = await library.snapshotForExport();
      expect(saved.groupsById[target.id]!.bookmarkIds, isEmpty);
      expect(saved.groupsById[other.id]!.bookmarkIds.length, 1);
      expect(saved.items.length, 1);
    },
  );

  test(
    'renamed and moved group keeps its UUID; deleted group rejects projection',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final group = await library.createGroup('Favorites');
      await h.container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(group.id);
      final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
      final captured = await fetch.prepareProjection(
        h.profile.auth,
        1,
        true,
        profileId: h.profile.id,
      );
      final folder = await library.createFolder('Folder');
      await library.renameGroup(group.id, 'Renamed');
      await library.moveFolderItems(
        groupIds: {group.id},
        destination: folder.id,
      );
      await captured!();
      var snapshot = await library.snapshotForExport();
      expect(snapshot.groupsById[group.id]!.name, 'Renamed');
      expect(snapshot.groupsById[group.id]!.folderId, folder.id);
      expect(snapshot.groupsById[group.id]!.bookmarkIds.length, 1);
      final deleted = await fetch.prepareProjection(
        h.profile.auth,
        2,
        true,
        profileId: h.profile.id,
      );
      await library.deleteGroup(group.id);
      await expectLater(deleted!(), throwsA(isA<ServerFavoriteException>()));
      snapshot = await library.snapshotForExport();
      expect(snapshot.items, isEmpty);
      expect(
        (await h.container.read(serverFavoriteSettingsProvider.future))
            .globalGroupId,
        group.id,
      );
    },
  );

  test('settings remain separate from the ordinary group export', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final target = await library.createGroup('Exportable');
    await h.container
        .read(serverFavoriteSettingsProvider.notifier)
        .setGlobal(target.id);
    await h.container
        .read(serverFavoriteFetchProvider.notifier)
        .start(h.profile.id);
    final snapshot = await library.snapshotForExport();
    final data = buildBookmarkBackupData(
      bookmarks: snapshot.items,
      groups: snapshot.groups,
      folders: snapshot.folders,
      scope: const BookmarkExportScope.all(),
    );
    final encoded = jsonEncode({
      'data': BookmarkBackupCodec().encode(data),
      ...data.extraFields,
    });
    expect(encoded, contains('Exportable'));
    for (final secret in [
      'fixture-key',
      'globalGroupId',
      'server_favorite_targets',
      'apiKey',
      'login',
      'cursor',
    ]) {
      expect(encoded, isNot(contains(secret)));
    }
    expect(data.bookmarks.length, 2);
    expect(
      jsonDecode(
        h.store.values[serverFavoriteSettingsStorageKey]!,
      )['globalGroupId'],
      target.id,
    );
  });
}

class _RequestContextSource extends FavoriteTestSource {
  _RequestContextSource(super.posts);

  final pageContexts = <ApiRequestContext>[];
  final postContexts = <ApiRequestContext>[];

  @override
  Future<ServerFavoritePage<Post>> fetchPage(
    int page, {
    ServerFavoriteCancellation? cancellation,
  }) {
    pageContexts.add(ApiRequestContext.current());
    return super.fetchPage(page, cancellation: cancellation);
  }

  @override
  Future<Post?> getPost(int postId) {
    postContexts.add(ApiRequestContext.current());
    return super.getPost(postId);
  }
}
