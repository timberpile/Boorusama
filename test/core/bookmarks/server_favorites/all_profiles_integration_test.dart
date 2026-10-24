import 'dart:async';

import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  late FavoriteHarness h;
  setUp(() async {
    h = FavoriteHarness();
    await h.open(sharedAuth: true);
  });
  tearDown(() => h.close());

  test(
    'all profile choices persist in one write and never fetch on save',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final global = await library.createGroup('Global');
      final override = await library.createGroup('Override');
      final old = await h.container.read(serverFavoriteSettingsProvider.future);
      final updated = old
          .withGlobal(global.id)
          .withProfile(h.profile.id, const ServerFavoriteTarget.none())
          .withProfile(
            h.profiles.profiles.last.id,
            ServerFavoriteTarget.group(override.id),
          );
      await h.container
          .read(serverFavoriteSettingsProvider.notifier)
          .saveAll(
            profiles: h.profiles.profiles,
            expected: old,
            updated: updated,
          );
      expect(
        await h.container.read(serverFavoriteSettingsProvider.future),
        updated,
      );
      expect(h.store.writes, 1);
      expect(h.source.calls, 0);
    },
  );

  test('changing any persisted account rejects all confirmed clears', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final first = await library.createGroup('First');
    final second = await library.createGroup('Second');
    await library.addPostsToGroup(h.profile.auth, [h.post(1)], first.id);
    await library.addPostsToGroup(h.profile.auth, [h.post(2)], second.id);
    final before = await library.snapshotForExport();
    final profiles = List.of(h.profiles.profiles);
    final old = await h.container.read(serverFavoriteSettingsProvider.future);
    h.profiles.profiles = [
      profiles.first,
      BooruConfig.fromJson({...profiles.last.toJson(), 'login': 'changed'}),
    ];
    await expectLater(
      h.container
          .read(serverFavoriteSettingsProvider.notifier)
          .saveAll(
            profiles: profiles,
            expected: old,
            updated: old
                .withGlobal(first.id)
                .withProfile(
                  profiles.last.id,
                  ServerFavoriteTarget.group(second.id),
                ),
            confirmedClears: [
              before.groupsById[first.id]!,
              before.groupsById[second.id]!,
            ],
          ),
      throwsA(
        isA<ServerFavoriteException>().having(
          (e) => e.problem,
          'problem',
          ServerFavoriteProblem.accountChanged,
        ),
      ),
    );
    expect(await library.snapshotForExport(), before);
    expect(h.store.writes, 0);
  });

  test('an external override change rejects the whole editor draft', () async {
    final old = await h.container.read(serverFavoriteSettingsProvider.future);
    final settings = h.container.read(serverFavoriteSettingsProvider.notifier);
    await settings.setProfile(
      h.profiles.profiles.last.id,
      const ServerFavoriteTarget.none(),
    );
    final current = await h.container.read(
      serverFavoriteSettingsProvider.future,
    );
    await expectLater(
      settings.saveAll(
        profiles: h.profiles.profiles,
        expected: old,
        updated: old.withProfile(
          h.profile.id,
          const ServerFavoriteTarget.none(),
        ),
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
      current,
    );
  });

  test('global fetch includes overrides and one failure does not stop another profile', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final global = await library.createGroup('Global');
    final override = await library.createGroup('Override');
    final other = h.profiles.profiles.last;
    final settings = h.container.read(serverFavoriteSettingsProvider.notifier);
    await settings.setGlobal(global.id);
    await settings.setProfile(
      other.id,
      ServerFavoriteTarget.group(override.id),
    );
    h.source.error = const ServerFavoriteException(
      ServerFavoriteProblem.remoteFailure,
    );
    h.sources[other.id] = FavoriteTestSource([h.post(2)]);
    final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
    await fetch.startAll([
      ServerFavoriteSession(h.profile, global.id),
      ServerFavoriteSession(other, override.id),
    ]);
    final progress = h.container.read(serverFavoriteFetchProvider);
    expect(
      progress[h.profile.id]!.problem,
      ServerFavoriteProblem.remoteFailure,
    );
    expect(progress[other.id]!.status, ServerFavoriteFetchStatus.completed);
    final after = await library.snapshotForExport();
    expect(after.groupsById[global.id]!.bookmarkIds, isEmpty);
    expect(after.groupsById[override.id]!.bookmarkIds, hasLength(1));
    expect(h.source.calls, 1);
    expect(h.sources[other.id]!.calls, 1);
  });

  test(
    'cancel all cancels every running profile without a late write',
    () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final group = await library.createGroup('Shared');
      await h.container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(group.id);
      final other = h.profiles.profiles.last;
      h.source.pending = Completer();
      final otherSource = FavoriteTestSource([h.post(2)])
        ..pending = Completer();
      h.sources[other.id] = otherSource;
      final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
      final running = fetch.startAll([
        for (final profile in h.profiles.profiles)
          ServerFavoriteSession(profile, group.id),
      ]);
      await Future.wait([
        h.source.requested.future,
        otherSource.requested.future,
      ]);
      fetch.cancelAll();
      await running;
      expect(
        h.container
            .read(serverFavoriteFetchProvider)
            .values
            .map((p) => p.status),
        everyElement(ServerFavoriteFetchStatus.cancelled),
      );
      h.source.pending!.complete(ServerFavoritePage(h.source.posts));
      otherSource.pending!.complete(ServerFavoritePage(otherSource.posts));
      expect((await library.snapshotForExport()).items, isEmpty);
    },
  );

  for (final supported in [false, true]) {
    test(
      '${supported ? 'Realbooru cookie-only' : 'unsupported'} successful actions never report unsupported fetch errors',
      () async {
        final type = supported ? BooruType.gelbooruV2 : BooruType.sankaku;
        final profile = BooruConfig.fromJson({
          ...h.profile.toJson(),
          'booruId': type.id,
          'booruIdHint': type.id,
          'url': supported
              ? 'https://realbooru.com'
              : 'https://unsupported.invalid',
          'login': '123',
          'apiKey': null,
          'passHash': 'fixture-cookie',
        });
        h.profiles.profiles = [profile];
        await h.container.read(booruConfigProvider.notifier).fetch();
        h.source.posts = [
          h.post(1).copyWith(origin: postOriginFromConfig(profile)),
        ];
        final library = h.container.read(bookmarkLibraryProvider.notifier);
        final group = await library.createGroup('Target');
        await h.container
            .read(serverFavoriteSettingsProvider.notifier)
            .setGlobal(group.id);
        var actions = 0;
        final repository = h.container.read(
          Provider(
            (ref) => createConfirmedFavoriteRepository(
              ref,
              profile.auth,
              FavoriteRepositoryBuilder<Post>(
                add: (_) async {
                  actions++;
                  return AddFavoriteStatus.success;
                },
                remove: (_) async {
                  actions++;
                  return true;
                },
                isFavorited: (_) => false,
                canFavorite: () => true,
              ),
              profileId: profile.id,
            ),
          ),
        );
        expect(await repository.addToFavorites(1), AddFavoriteStatus.success);
        final added = (await library.snapshotForExport())
            .groupsById[group.id]!
            .bookmarkIds;
        expect(added.length, supported ? 1 : 0);
        expect(await repository.removeFromFavorites(1), isTrue);
        expect(
          (await library.snapshotForExport()).groupsById[group.id]!.bookmarkIds,
          isEmpty,
        );
        expect(h.container.read(serverFavoriteFeedbackProvider), isNull);
        expect(actions, 2);
        expect(h.source.calls, 0);
      },
    );
  }
}
