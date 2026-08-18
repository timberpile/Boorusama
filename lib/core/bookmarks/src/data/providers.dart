// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import '../types/bookmark_group_repository.dart';
import 'hive/bookmark_group_hive_object.dart';
import 'hive/bookmark_group_membership_hive_object.dart';
import 'hive/bookmark_group_repository_hive.dart';

// Project imports:
import '../types/bookmark_repository.dart';
import 'hive/bookmark_hive_object.dart';
import 'hive/repository.dart';

export 'image_cache.dart';

final bookmarkGroupRepoProvider = FutureProvider<BookmarkGroupRepository>(
  (ref) async {
    final groupsBox = await Hive.openBox<BookmarkGroupHiveObject>(
      'bookmark_groups',
    );
    final membershipsBox =
        await Hive.openBox<BookmarkGroupMembershipHiveObject>(
          'bookmark_group_memberships',
        );
    final repository = BookmarkGroupRepositoryHive(
      groupsBox: groupsBox,
      membershipsBox: membershipsBox,
    );

    ref.onDispose(() async {
      await membershipsBox.close();
      await groupsBox.close();
    });

    return repository;
  },
);

final bookmarkRepoProvider = FutureProvider<BookmarkRepository>(
  (ref) async {
    final bookmarkBox = await Hive.openBox<BookmarkHiveObject>('favorites');
    final bookmarkRepo = BookmarkHiveRepository(bookmarkBox);

    ref.onDispose(() async {
      await bookmarkBox.close();
    });

    return bookmarkRepo;
  },
  name: 'bookmarkRepoProvider',
);
