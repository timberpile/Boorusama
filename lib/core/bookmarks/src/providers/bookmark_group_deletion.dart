Future<void> deleteBookmarkGroupAndRefresh({
  required Future<Set<int>> Function() deleteGroup,
  required Future<void> Function(Set<int> orphanBookmarkIds)
  removeOrphanBookmarks,
  required Future<void> Function() resetSelection,
  required void Function() refreshProviders,
}) async {
  try {
    final orphanBookmarkIds = await deleteGroup();
    if (orphanBookmarkIds.isNotEmpty) {
      await removeOrphanBookmarks(orphanBookmarkIds);
    }
  } finally {
    try {
      await resetSelection();
    } finally {
      refreshProviders();
    }
  }
}
