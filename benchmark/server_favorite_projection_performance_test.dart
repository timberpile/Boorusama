import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

import '../test/core/bookmarks/server_favorites/test_support.dart';

void main() {
  for (final count in [1000, 5000]) {
    test(
      'reports favorite projection work for $count saved bookmarks',
      () async {
        final h = FavoriteHarness();
        await h.open();
        addTearDown(h.close);
        final library = h.container.read(bookmarkLibraryProvider.notifier);
        await h.bookmarks.addBookmarks(
          h.profile.booruId,
          [for (var i = 1; i <= count; i++) h.post(i)],
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
          postLinkGenerator: (_) => const NoLinkPostLinkGenerator(),
        );
        await library.syncActiveTargetFromSettings();
        final group = await library.createGroup('Favorites');
        await h.container
            .read(serverFavoriteSettingsProvider.notifier)
            .setGlobal(group.id);
        final fetch = h.container.read(serverFavoriteFetchProvider.notifier);
        addTearDown(performanceRecorder.clear);
        // Warm the same path before reporting three comparable samples.
        for (var sample = 0; sample < 4; sample++) {
          final post = h.post(count + sample + 1);
          h.source.posts = [post];
          final projection = await fetch.prepareProjection(
            h.profile.auth,
            post.id,
            true,
            profileId: h.profile.id,
          );
          performanceRecorder.start();
          final elapsed = Stopwatch()..start();
          await projection!();
          elapsed.stop();
          performanceRecorder.stop();
          expect(
            (await library.snapshotForExport())
                .groupsById[group.id]!
                .bookmarkIds,
            hasLength(sample + 1),
          );
          if (sample > 0) {
            stdout.writeln(
              jsonEncode({
                'benchmark': 'serverFavoriteProjection',
                'bookmarks': count,
                'sample': sample,
                'wallMs': elapsed.elapsedMicroseconds / 1000,
                'summary': performanceRecorder.snapshot()['summary'],
              }),
            );
          }
        }
      },
    );
  }
}
