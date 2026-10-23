import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/local_providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

void main() {
  test('source scopes and profile invalidation cannot reuse an incompatible All index', () async {
    final notifier = _Library(
      BookmarkLibraryState(
        bookmarks: [
          Bookmark.empty.copyWith(
            id: 1,
            sourceUrl: 'https://a.test',
            tags: {'a'},
          ),
          Bookmark.empty.copyWith(
            id: 2,
            sourceUrl: 'https://b.test',
            tags: {'b'},
          ),
        ],
        groups: const [],
        activeTarget: const BookmarkTarget.defaultGroup(),
      ),
    );
    final profiles = _Profiles();
    final container = ProviderContainer(
      overrides: [
        bookmarkProvider.overrideWith(() => notifier),
        booruConfigProvider.overrideWith(
          () => profiles,
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = bookmarkTagIndexProvider(const BookmarkView.all());
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final all = await container.read(provider.future);
    container.read(selectedBooruUrlProvider.notifier).state = 'https://a.test';
    await container.pump();
    expect((await container.read(provider.future)).byName.keys, ['a']);
    container.read(selectedBooruUrlProvider.notifier).state = null;
    await container.pump();
    expect(identical(await container.read(provider.future), all), isTrue);

    notifier.publish(
      notifier.library.applyCommittedChanges(
        groups: notifier.library.groups,
        folders: notifier.library.folders,
        activeTarget: const BookmarkTarget.defaultGroup(),
      ),
    );
    await container.pump();
    expect(identical(await container.read(provider.future), all), isTrue);
    profiles.publish([]);
    await container.pump();
    final reconfigured = await container.read(provider.future);
    expect(identical(reconfigured, all), isFalse);
    expect(reconfigured.entries, all.entries);

    // Restore/import can replace every snapshot while retaining storage IDs.
    notifier.publish(
      BookmarkLibraryState(
        bookmarks: [
          Bookmark.empty.copyWith(
            id: 2,
            sourceUrl: 'https://b.test',
            tags: {'restored'},
          ),
        ],
        groups: const [],
        activeTarget: const BookmarkTarget.defaultGroup(),
      ),
    );
    await container.pump();
    expect((await container.read(provider.future)).byName.keys, ['restored']);
  });
  test('unchanged All reopens retain one builder and do no repeated tag work', () async {
    final rows = [
      for (var id = 1; id <= 100; id++)
        Bookmark.empty.copyWith(id: id, tags: {'shared', 'tag_$id'}),
    ];
    final notifier = _Library(
      BookmarkLibraryState(
        bookmarks: rows,
        groups: const [],
        activeTarget: const BookmarkTarget.defaultGroup(),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        bookmarkProvider.overrideWith(() => notifier),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: []),
        ),
      ],
    );
    addTearDown(container.dispose);
    performanceRecorder.start();
    addTearDown(performanceRecorder.clear);
    final provider = bookmarkTagIndexProvider(const BookmarkView.all());
    Object? original;
    for (var visit = 0; visit < 3; visit++) {
      final subscription = container.listen(provider, (_, _) {});
      final index = await container.read(provider.future);
      original ??= index;
      expect(identical(index, original), isTrue);
      subscription.close();
      await container.pump();
    }
    expect(_total('bookmarkTagBuilderCreated'), 1);
    expect(_total('bookmarkTagFullBuild'), 1);
    expect(_total('bookmarkTagReferences'), 200);

    // A snapshot replacement removes the old contribution and adds the new one.
    notifier.publish(
      BookmarkLibraryState(
        bookmarks: [
          rows.first.copyWith(tags: {'replacement'}),
          ...rows.skip(1),
        ],
        groups: notifier.library.groups,
        activeTarget: notifier.library.activeTarget,
      ),
    );
    final subscription = container.listen(provider, (_, _) {});
    final changed = await container.read(provider.future);
    expect(changed.byName['shared']!.count, 99);
    expect(changed.byName['replacement']!.count, 1);
    expect(_total('bookmarkTagReferences'), 203);
    subscription.close();
  });

  test('group builders are disposed between visits', () async {
    final container = ProviderContainer(
      overrides: [
        bookmarkProvider.overrideWith(
          () => _Library(
            BookmarkLibraryState(
              bookmarks: const [],
              groups: const [],
              activeTarget: const BookmarkTarget.defaultGroup(),
            ),
          ),
        ),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: []),
        ),
      ],
    );
    addTearDown(container.dispose);
    performanceRecorder.start();
    addTearDown(performanceRecorder.clear);
    for (var visit = 0; visit < 3; visit++) {
      final provider = bookmarkTagIndexProvider(
        const BookmarkView.defaultGroup(),
      );
      final subscription = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      subscription.close();
      await container.pump();
    }
    expect(_total('bookmarkTagBuilderCreated'), 3);
    expect(_total('bookmarkTagBuilderDisposed'), 3);
  });
}

int _total(String counter) {
  final counters =
      (performanceRecorder.snapshot()['summary'] as Map)['counters'] as Map;
  final sample = counters[counter] as Map?;
  return sample?['total'] as int? ?? 0;
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.library);
  BookmarkLibraryState library;
  @override
  Future<BookmarkLibraryState> build() async => library;
  void publish(BookmarkLibraryState value) {
    library = value;
    state = AsyncData(value);
  }
}

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: []);
  void publish(List<BooruConfig> configs) => state = configs;
}
