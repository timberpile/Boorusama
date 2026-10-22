import 'dart:async';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../search/following_topics/topic_test_utils.dart';

void main() {
  test('late callbacks cannot recover through an expired mutation snapshot', () async {
    Bookmark row(int id) => Bookmark.empty.copyWith(
      id: id,
      sourceUrl: 'https://example.com',
      postId: () => id,
    );
    final repository = _Rows([row(1)]);
    final groups = _CapturingGroups();
    final container = ProviderContainer(
      overrides: [
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: []),
        ),
        settingsNotifierProvider.overrideWith(
          () => _Settings(Settings.defaultSettings),
        ),
        bookmarkRepoProvider.overrideWith((ref) => repository),
        bookmarkGroupRepoProvider.overrideWith((ref) => groups),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, booruId) => const DefaultImageUrlResolver(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;
    await notifier.createGroup('Capture');
    final completedZone = groups.captured!;

    // An authoritative external mutation publishes a newer library after the
    // captured operation has already completed.
    await notifier.runSerializedMutation(() async {
      repository.rows.add(row(2));
    });
    expect((await notifier.snapshotForExport()).items, hasLength(2));
    final reads = repository.reads;

    // Mimic a deferred callback registered during the earlier operation. Its
    // failing mutation must reload storage, never publish that old zone's base.
    await expectLater(
      completedZone.run(
        () => notifier.deleteGroup(
          '550e8400-e29b-41d4-a716-446655440099',
        ),
      ),
      throwsStateError,
    );
    expect(repository.reads, greaterThan(reads));
    expect((await notifier.snapshotForExport()).items, hasLength(2));
  });
}

class _CapturingGroups extends BookmarkGroupRepositoryHive {
  _CapturingGroups()
    : super(
        MemoryBox<BookmarkGroupHiveObject>(),
        organizationBox: MemoryBox<dynamic>(),
      );

  Zone? captured;

  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) {
    if (name == 'Capture') captured = Zone.current;
    return super.createGroup(name, id: id);
  }
}

class _Rows implements BookmarkRepository<Post> {
  _Rows(this.rows);
  final List<Bookmark> rows;
  int reads = 0;

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) {
    reads++;
    return TaskEither.right(rows.toList());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    invocation.memberName.toString(),
  );
}

class _Settings extends SettingsNotifier {
  _Settings(super.initialSettings);
}
