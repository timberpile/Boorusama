import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  late FavoriteHarness h;
  setUp(() async {
    h = FavoriteHarness();
    await h.open(sharedAuth: true);
  });
  tearDown(() => h.close());

  for (final assignment in ['global', 'profile', 'single editor', 'all editors']) {
    test('$assignment assignment preserves mixed bookmarks and membership dates', () async {
      final library = h.container.read(bookmarkLibraryProvider.notifier);
      final target = await library.createGroup('Existing');
      final other = await library.createGroup('Other');
      await library.addPostsToGroup(h.profile.auth, [h.post(3)], target.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(3)], other.id);
      final created = DateTime.utc(2026, 10, 1);
      final added = DateTime.utc(2026, 10, 2);
      final origin = postOriginFromConfig(h.profile);
      await h.groups.writePoolBookmarks([
        PoolBookmark(
          poolId: 42,
          localId: '00000000-0000-4000-8000-000000000042',
          origin: origin,
          category: BookmarkedPoolCategory.series,
          title: 'Existing series',
          createdAt: created,
          observedAt: added,
          groupIds: {target.id, other.id},
          addedAt: {target.id: added, other.id: created},
          tags: const {},
          coverage: PoolTagCoverage.unknown,
        ),
        RelatedBookmark(
          family: RelatedFamilyReference(origin: origin, anchorId: 99),
          localId: '00000000-0000-4000-8000-000000000099',
          createdAt: created,
          observedAt: added,
          groupIds: {target.id},
          addedAt: {target.id: added},
        ),
      ]);
      await library.refresh();
      final before = await library.snapshotForExport();
      final settings = h.container.read(serverFavoriteSettingsProvider.notifier);
      final expected = await h.container.read(serverFavoriteSettingsProvider.future);
      switch (assignment) {
        case 'global':
          await settings.setGlobal(target.id);
        case 'profile':
          await settings.setProfile(h.profile.id, ServerFavoriteTarget.group(target.id));
        case 'single editor':
          await settings.saveForProfile(
            profile: h.profile,
            expected: expected,
            globalGroupId: target.id,
            target: const ServerFavoriteTarget.inherit(),
          );
        case 'all editors':
          await settings.saveAll(
            profiles: h.profiles.profiles,
            expected: expected,
            updated: expected.withGlobal(target.id),
          );
      }
      expect((await h.container.read(serverFavoriteSettingsProvider.future)).resolve(h.profile.id), target.id);
      expect(await library.snapshotForExport(), before);
      expect(h.source.calls, 0);
      expect(h.store.writes, 1);
      await library.refresh();
      expect(await library.snapshotForExport(), before);
    });
  }

  test('a settings write failure leaves populated target contents untouched', () async {
    final library = h.container.read(bookmarkLibraryProvider.notifier);
    final target = await library.createGroup('Existing');
    await library.addPostsToGroup(h.profile.auth, [h.post(3), h.post(4)], target.id);
    final before = await library.snapshotForExport();
    final old = await h.container.read(serverFavoriteSettingsProvider.future);
    h.store.fail = true;
    await expectLater(
      h.container.read(serverFavoriteSettingsProvider.notifier).setGlobal(target.id),
      throwsStateError,
    );
    expect(await library.snapshotForExport(), before);
    expect(await h.container.read(serverFavoriteSettingsProvider.future), old);
    expect(h.source.calls, 0);
    await library.refresh();
    expect(await library.snapshotForExport(), before);
  });
}
