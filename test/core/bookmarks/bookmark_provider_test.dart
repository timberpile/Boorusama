// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';
  late Directory tempDirectory;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<BookmarkGroupHiveObject> groupBox;
  late BookmarkHiveRepository bookmarkRepository;
  late BookmarkGroupRepositoryHive groupRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_provider_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    bookmarkBox = await Hive.openBox<BookmarkHiveObject>('bookmarks_test');
    groupBox = await Hive.openBox<BookmarkGroupHiveObject>('groups_test');
    bookmarkRepository = BookmarkHiveRepository(bookmarkBox);
    groupRepository = BookmarkGroupRepositoryHive(groupBox);
  });

  tearDown(() async {
    await bookmarkBox.close();
    await groupBox.close();
    await tempDirectory.delete(recursive: true);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        bookmarkRepoProvider.overrideWith((ref) => bookmarkRepository),
        bookmarkGroupRepoProvider.overrideWith((ref) => groupRepository),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, booruId) => const DefaultImageUrlResolver(),
        ),
        bookmarkImageCacheManagerProvider.overrideWithValue(null),
        settingsNotifierProvider.overrideWith(
          () => _TestSettingsNotifier(Settings.defaultSettings),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'adding to No Group never clears existing named memberships',
    () async {
      final bookmark = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/grouped.jpg',
      );
      await bookmarkRepository.addBookmarkWithBookmarks([bookmark]);
      final stored = (await bookmarkRepository.getAllBookmarksOrEmpty(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      )).single;
      await groupRepository.createGroup('Shared', id: groupId);
      await groupRepository.addBookmarks(groupId, {stored.id});
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      await notifier.addBookmark(
        BooruConfigAuth.fromConfig(
          BooruConfig.empty.copyWith(booruIdHint: stored.booruId),
        ),
        stored.toPost(),
      );

      expect((await groupRepository.getGroup(groupId))?.bookmarkIds, {
        stored.id,
      });
      expect(
        await bookmarkRepository.getAllBookmarksOrEmpty(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'active target publishes the newly persisted group deterministically',
    () async {
      await groupRepository.createGroup('Target', id: groupId);
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.future;

      final saved = await notifier.setActiveTarget(
        BookmarkTarget.group(groupId),
      );

      expect(saved, isTrue);
      expect(
        container.read(bookmarkProvider).value?.activeTarget.groupId,
        groupId,
      );
      expect(
        container.read(settingsProvider).activeBookmarkGroupId,
        groupId,
      );
    },
  );
}

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(super.initialSettings);

  @override
  Future<bool> updateWith(Settings Function(Settings) selector) async {
    state = selector(state);
    return true;
  }
}
