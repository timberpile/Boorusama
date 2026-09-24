// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../types/pinned_search_sort.dart';

final pinnedSearchSortProvider =
    NotifierProvider<PinnedSearchSortNotifier, PinnedSearchSort>(
      PinnedSearchSortNotifier.new,
    );

class PinnedSearchSortNotifier extends Notifier<PinnedSearchSort> {
  @override
  PinnedSearchSort build() => PinnedSearchSort.manual;

  void select(PinnedSearchSort sort) => state = sort;
}
