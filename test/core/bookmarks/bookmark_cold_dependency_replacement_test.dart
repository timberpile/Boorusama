import 'dart:async';

import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes/memory_repositories.dart';

void main() {
  test('cold library follows a repository replaced before its first load completes', () async {
    final generation = StateProvider((_) => 0);
    final first = Completer<BookmarkRepository>();
    final started = Completer<void>();
    final replacement = MemoryBookmarkRepository();
    final container = ProviderContainer(
      overrides: [
        miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
        bookmarkRepoProvider.overrideWith((ref) {
          if (ref.watch(generation) == 0) {
            if (!started.isCompleted) started.complete();
            return first.future;
          }
          return replacement;
        }),
        bookmarkGroupRepoProvider.overrideWith(
          (_) => MemoryBookmarkGroupRepository(),
        ),
      ],
    );
    addTearDown(() {
      if (!first.isCompleted) first.complete(MemoryBookmarkRepository());
      container.dispose();
    });
    final subscription = container.listen(bookmarkProvider, (_, _) {});
    addTearDown(subscription.close);
    final library = container.read(bookmarkProvider.future);
    await started.future;
    container.read(generation.notifier).state = 1;
    await container.pump();
    final loaded = await library.timeout(const Duration(seconds: 10));
    expect(loaded.items, isEmpty);
    expect(loaded.groups.single.isDefault, isTrue);
    expect(
      first.isCompleted,
      isFalse,
      reason: 'The cancelled initial repository must not hold the current library loading.',
    );
    expect(container.read(bookmarkProvider).hasValue, isTrue);
  });
}
