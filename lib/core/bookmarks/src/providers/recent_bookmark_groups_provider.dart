import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_group_repository.dart';
import 'bookmark_provider.dart';

final recentBookmarkGroupsProvider =
    FutureProvider.autoDispose<List<BookmarkGroup>>(
      (ref) async {
        final library = ref.watch(bookmarkProvider).valueOrNull;
        if (library == null) return const [];
        final repository = await ref.watch(bookmarkGroupRepoProvider.future);
        final ids = await repository.getRecentGroupIds();
        final groups = {for (final group in library.groups) group.id: group};
        return [
          for (final id in ids)
            if (groups[id] case final group?) group,
        ];
      },
      dependencies: [bookmarkProvider],
    );
