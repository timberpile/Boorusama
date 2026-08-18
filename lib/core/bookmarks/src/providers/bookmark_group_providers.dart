// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../settings/providers.dart';
import '../data/providers.dart';
import '../types/bookmark_group.dart';
import 'bookmark_provider.dart';

const kUngroupedBookmarkGroupId = -1;

/// A null selected view represents the virtual All Bookmarks view.
final selectedBookmarkGroupIdProvider = StateProvider.autoDispose<int?>(
  (ref) => null,
);

final bookmarkGroupsProvider = FutureProvider<List<BookmarkGroup>>((ref) async {
  return (await ref.watch(bookmarkGroupRepoProvider.future)).getGroups();
});

final activeBookmarkGroupIdProvider = Provider<int>((ref) {
  return ref.watch(
    settingsProvider.select((settings) => settings.activeBookmarkGroupId),
  );
});

/// Returns the persisted target when it still exists, otherwise Ungrouped.
final effectiveActiveBookmarkGroupIdProvider = Provider<int>((ref) {
  final target = ref.watch(activeBookmarkGroupIdProvider);
  final groups = ref.watch(bookmarkGroupsProvider).valueOrNull;

  if (target == kUngroupedBookmarkGroupId || groups == null) {
    return target;
  }

  return groups.any((group) => group.id == target)
      ? target
      : kUngroupedBookmarkGroupId;
});

Future<void> setActiveBookmarkGroupId(WidgetRef ref, int groupId) {
  return ref
      .read(settingsNotifierProvider.notifier)
      .updateWith(
        (settings) => settings.copyWith(activeBookmarkGroupId: groupId),
      );
}

Future<void> setActiveBookmarkGroupIdInContainer(
  ProviderContainer container,
  int groupId,
) {
  return container
      .read(settingsNotifierProvider.notifier)
      .updateWith(
        (settings) => settings.copyWith(activeBookmarkGroupId: groupId),
      );
}

void refreshBookmarkGroupProviders(WidgetRef ref) {
  ref
    ..invalidate(bookmarkGroupsProvider)
    ..invalidate(bookmarkProvider);
}
