import 'dart:async';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_button_state_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_details_mutation_notifier.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/local_providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

void main() {
  test(
    'opening the viewer during load skips superseded tag indexing',
    () async {
      final pending = Completer<BookmarkLibraryState>();
      final notifier = _Library(pending.future);
      final container = ProviderContainer(
        overrides: [
          bookmarkProvider.overrideWith(() => notifier),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
        ],
      );
      addTearDown(container.dispose);
      const view = BookmarkView.defaultGroup();
      final provider = bookmarkTagIndexProvider(view);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.pump();
      performanceRecorder.start();
      addTearDown(performanceRecorder.clear);
      container
          .read(bookmarkDetailsMutationProvider.notifier)
          .begin(sourceView: view);
      await container.pump();
      expect((await container.read(provider.future)).entries, isEmpty);
      final row = Bookmark.empty.copyWith(
        id: 1,
        sourceUrl: 'https://example.com',
        postId: () => 101,
        tags: {'one_piece'},
      );
      pending.complete(
        BookmarkLibraryState(
          bookmarks: [row],
          groups: [
            BookmarkGroup(
              id: defaultBookmarkGroupId,
              name: 'Default',
              bookmarkIds: {1},
            ),
          ],
        ),
      );
      await container.pump();
      performanceRecorder.stop();
      final operations =
          (performanceRecorder.snapshot()['summary'] as Map)['operations']
              as List;
      expect(
        operations.where(
          (operation) => (operation as Map)['op'] == 'bookmarkSelect',
        ),
        isEmpty,
      );
      container.read(bookmarkDetailsMutationProvider.notifier).end();
      await container.pump();
      expect((await container.read(provider.future)).byName.keys, [
        'one_piece',
      ]);
    },
  );

  test(
    'covered bookmark search keeps its index until the viewer closes',
    () async {
      const groupId = '550e8400-e29b-41d4-a716-446655440000';
      final view = BookmarkView.group(groupId);
      final rows = [
        Bookmark.empty.copyWith(
          id: 1,
          sourceUrl: 'https://example.com',
          postId: () => 101,
          tags: {'one_piece'},
        ),
        Bookmark.empty.copyWith(
          id: 2,
          sourceUrl: 'https://example.com',
          postId: () => 102,
          tags: {'glasses'},
        ),
      ];
      final initial = BookmarkLibraryState(
        bookmarks: rows,
        groups: [
          BookmarkGroup(
            id: defaultBookmarkGroupId,
            name: 'Default',
            bookmarkIds: {1, 2},
          ),
          BookmarkGroup(id: groupId, name: 'Target', bookmarkIds: {1}),
        ],
      );
      final notifier = _Library(initial);
      final container = ProviderContainer(
        overrides: [
          bookmarkProvider.overrideWith(() => notifier),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = bookmarkTagIndexProvider(view);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final before = await container.read(provider.future);
      expect(before.byName.keys, ['one_piece']);
      performanceRecorder.start();
      addTearDown(performanceRecorder.clear);

      container
          .read(bookmarkDetailsMutationProvider.notifier)
          .begin(sourceView: view);
      await container.pump();
      expect(identical(await container.read(provider.future), before), isTrue);
      notifier.publish(
        initial.applyCommittedChanges(
          groups: [
            initial.groups.first,
            initial.groups.last.copyWith(bookmarkIds: {2}),
          ],
          folders: initial.folders,
        ),
      );
      await container.pump();
      expect(identical(await container.read(provider.future), before), isTrue);
      performanceRecorder.stop();
      final operations =
          (performanceRecorder.snapshot()['summary'] as Map)['operations']
              as List;
      expect(
        operations.where(
          (operation) => (operation as Map)['op'] == 'bookmarkSelect',
        ),
        isEmpty,
      );

      container.read(bookmarkDetailsMutationProvider.notifier).end();
      await container.pump();
      final revealed = await container.read(provider.future);
      expect(revealed.byName.keys, ['glasses']);
      expect(identical(revealed, before), isFalse);
    },
  );

  test(
    'visible search reconciles group, source, snapshot and Undo changes',
    () async {
      const groupId = '550e8400-e29b-41d4-a716-446655440000';
      final rows = [
        Bookmark.empty.copyWith(
          id: 1,
          sourceUrl: 'https://a.test',
          postId: () => 101,
          tags: {'shared', 'a'},
        ),
        Bookmark.empty.copyWith(
          id: 2,
          sourceUrl: 'https://b.test',
          postId: () => 102,
          tags: {'shared', 'b'},
        ),
      ];
      final initial = BookmarkLibraryState(
        bookmarks: rows,
        groups: [
          BookmarkGroup(
            id: defaultBookmarkGroupId,
            name: 'Default',
            bookmarkIds: const {1, 2},
          ),
          BookmarkGroup(id: groupId, name: 'Target', bookmarkIds: const {1, 2}),
        ],
      );
      final notifier = _Library(initial);
      final container = ProviderContainer(
        overrides: [
          bookmarkProvider.overrideWith(() => notifier),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
        ],
      );
      addTearDown(container.dispose);
      final groupProvider = bookmarkTagIndexProvider(
        BookmarkView.group(groupId),
      );
      final allProvider = bookmarkTagIndexProvider(const BookmarkView.all());
      final subscriptions = [
        container.listen(groupProvider, (_, _) {}),
        container.listen(allProvider, (_, _) {}),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });
      final groupBefore = await container.read(groupProvider.future);
      final allBefore = await container.read(allProvider.future);
      final removed = initial.applyCommittedChanges(
        groups: [
          initial.groups.first,
          initial.groups.last.copyWith(bookmarkIds: {2}),
        ],
        folders: initial.folders,
      );
      notifier.publish(removed);
      await container.pump();
      expect(
        (await container.read(groupProvider.future)).byName.keys,
        unorderedEquals(['shared', 'b']),
      );
      expect(
        identical(await container.read(allProvider.future), allBefore),
        isTrue,
      );
      expect(groupBefore.byName['shared']!.count, 2);
      container.read(selectedBooruUrlProvider.notifier).state = 'a.test';
      expect((await container.read(groupProvider.future)).entries, isEmpty);
      expect(
        (await container.read(allProvider.future)).byName.keys,
        unorderedEquals(['shared', 'a']),
      );
      container.read(selectedBooruUrlProvider.notifier).state = null;
      final replaced = removed.applyCommittedChanges(
        upserts: [
          rows.last.copyWith(tags: {'updated'}),
        ],
        groups: removed.groups,
        folders: removed.folders,
      );
      notifier.publish(replaced);
      expect((await container.read(groupProvider.future)).byName.keys, [
        'updated',
      ]);
      notifier.publish(initial);
      expect(
        (await container.read(groupProvider.future)).entries,
        groupBefore.entries,
      );
      expect(
        (await container.read(allProvider.future)).entries,
        allBefore.entries,
      );
    },
  );

  test('group metadata leaves tag counts, source URLs and unrelated buttons unchanged', () async {
    const groupId = '550e8400-e29b-41d4-a716-446655440000';
    final row = Bookmark.empty.copyWith(
      id: 1,
      sourceUrl: 'https://example.com',
      postId: () => 101,
    );
    final initial = BookmarkLibraryState(
      bookmarks: [row],
      groups: [
        BookmarkGroup(
          id: defaultBookmarkGroupId,
          name: 'Default',
          bookmarkIds: {1},
        ),
        BookmarkGroup(id: groupId, name: 'Other', bookmarkIds: {}),
      ],
    );
    final notifier = _Library(initial);
    final container = ProviderContainer(
      overrides: [
        bookmarkProvider.overrideWith(() => notifier),
      ],
    );
    addTearDown(container.dispose);
    await container.read(bookmarkProvider.future);
    var buttonChanges = 0;
    final subscriptions = [
      container.listen(tagMapProvider, (_, _) {}),
      container.listen(availableBooruUrlsProvider, (_, _) {}),
      container.listen(
        bookmarkButtonStateProvider(row.uniqueId).select((state) => state),
        (_, _) => buttonChanges++,
      ),
    ];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });
    final tags = await container.read(tagMapProvider.future);
    final urls = await container.read(availableBooruUrlsProvider.future);
    await container.pump();
    buttonChanges = 0;
    final metadata = initial.applyCommittedChanges(
      groups: [
        initial.groups.first,
        initial.groups.last.copyWith(name: 'Renamed'),
      ],
      folders: initial.folders,
    );
    notifier.publish(metadata);
    await container.pump();
    expect(
      identical(tags, await container.read(tagMapProvider.future)),
      isTrue,
    );
    expect(
      identical(urls, await container.read(availableBooruUrlsProvider.future)),
      isTrue,
    );
    expect(buttonChanges, 0);

    // A membership change must still update the affected post's button.
    notifier.publish(
      metadata.applyCommittedChanges(
        groups: [
          metadata.groups.first,
          metadata.groups.last.copyWith(bookmarkIds: {1}),
        ],
        folders: metadata.folders,
      ),
    );
    await container.pump();
    expect(buttonChanges, 1);
    expect(
      identical(tags, await container.read(tagMapProvider.future)),
      isTrue,
    );
    expect(
      identical(urls, await container.read(availableBooruUrlsProvider.future)),
      isTrue,
    );

    // Actual snapshot replacement must invalidate the derived data again.
    notifier.publish(
      container
          .read(bookmarkProvider)
          .requireValue
          .applyCommittedChanges(
            upserts: [row.copyWith(sourceUrl: 'https://other.example')],
            groups: container.read(bookmarkProvider).requireValue.groups,
            folders: metadata.folders,
          ),
    );
    await container.pump();
    expect(await container.read(availableBooruUrlsProvider.future), [
      'other.example',
    ]);
  });
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.initial);
  final FutureOr<BookmarkLibraryState> initial;

  @override
  FutureOr<BookmarkLibraryState> build() => initial;

  void publish(BookmarkLibraryState next) => state = AsyncValue.data(next);
}
