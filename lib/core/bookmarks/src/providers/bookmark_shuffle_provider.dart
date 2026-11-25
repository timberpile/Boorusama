// Dart imports:
import 'dart:math';

// Package imports:
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookmarkShuffleState extends Equatable {
  const BookmarkShuffleState({
    this.seed,
  });

  final int? seed;

  BookmarkShuffleState copyWith({
    int? seed,
  }) {
    return BookmarkShuffleState(
      seed: seed ?? this.seed,
    );
  }

  BookmarkShuffleState withNewShuffle() {
    return BookmarkShuffleState(
      seed: max(DateTime.now().microsecondsSinceEpoch, (seed ?? 0) + 1),
    );
  }

  BookmarkShuffleState reset() {
    return const BookmarkShuffleState();
  }

  static final sessionDefault = const BookmarkShuffleState().withNewShuffle();

  List<T> applyShuffleToList<T>(
    List<T> items, {
    required String Function(T) key,
  }) {
    if (seed == null) return items;
    final ranked = [
      for (final item in items) (item: item, key: key(item)),
    ];
    ranked.sort((a, b) {
      final rank = Object.hash(seed, a.key).compareTo(Object.hash(seed, b.key));
      return rank != 0 ? rank : a.key.compareTo(b.key);
    });
    return [for (final row in ranked) row.item];
  }

  bool get shouldShowAsActive => seed != null;

  @override
  List<Object?> get props => [seed];
}

class BookmarkShuffleNotifier
    extends AutoDisposeNotifier<BookmarkShuffleState> {
  @override
  BookmarkShuffleState build() {
    return const BookmarkShuffleState();
  }

  void shuffle() {
    state = state.withNewShuffle();
  }

  void reset() {
    state = state.reset();
  }

  void resetOnUserAction() {
    if (state.seed != null) {
      reset();
    }
  }
}

final bookmarkShuffleProvider =
    AutoDisposeNotifierProvider<BookmarkShuffleNotifier, BookmarkShuffleState>(
      () => BookmarkShuffleNotifier(),
    );
