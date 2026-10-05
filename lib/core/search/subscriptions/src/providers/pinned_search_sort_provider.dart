// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../settings/providers.dart';
import '../types/pinned_search_sort.dart';

final pinnedSearchSortProvider =
    NotifierProvider<PinnedSearchSortNotifier, PinnedSearchSort>(
      PinnedSearchSortNotifier.new,
    );

class PinnedSearchSortNotifier extends Notifier<PinnedSearchSort> {
  Future<void> _selectionTail = Future.value();

  @override
  PinnedSearchSort build() => PinnedSearchSort.parse(
    ref.watch(settingsProvider).pinnedSearchSort,
  );

  Future<bool> select(PinnedSearchSort sort) {
    final result = _selectionTail.then((_) async {
      try {
        return await ref
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) => settings.copyWith(pinnedSearchSort: sort.name),
            );
      } catch (_) {
        return false;
      }
    });
    _selectionTail = result.then((_) {});
    return result;
  }
}
