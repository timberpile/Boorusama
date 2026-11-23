import 'package:collection/collection.dart';

import '../types/topic_feed.dart';

/// One mounted route accepts recent data once, then only on explicit apply.
/// Ordinary retention, progress and provenance changes cannot reopen that gate.
class FeedDisplaySnapshot {
  TopicFeed? accepted;
  TopicFeed? pending;
  TopicFeed? _acceptedStored;
  TopicFeed? _latest;
  Object? _definition;
  var _observed = false;
  var _removed = false;
  var _initializing = true;
  var generation = 0;

  void observe(
    TopicFeed? candidate, {
    required Object definition,
    TopicFeed? stored,
  }) {
    _latest = candidate;
    if (!_observed ||
        !const DeepCollectionEquality().equals(_definition, definition)) {
      final first = !_observed;
      final mayInitialize = first || _initializing;
      final reset =
          !first &&
          !mayInitialize &&
          candidate != null &&
          (_removed ||
              (accepted != null &&
                  accepted!.cacheGeneration != candidate.cacheGeneration));
      if (!first && candidate == null) _removed = true;
      if (candidate != null) _removed = false;
      _observed = true;
      _definition = definition;
      generation++;
      accepted = reset ? candidate.copyWith(posts: const []) : candidate;
      _acceptedStored = reset
          ? (stored ?? candidate).copyWith(posts: const [])
          : stored ?? candidate;
      pending = reset && candidate.posts.isNotEmpty ? candidate : null;
      _initializing =
          mayInitialize &&
          (candidate == null ||
              (candidate.posts.isEmpty &&
                  !candidate.sourceIds.every(
                    candidate.initializedSourceIds.contains,
                  )));
      return;
    }
    if (_initializing) {
      accepted = candidate;
      _acceptedStored = stored ?? candidate;
      if (candidate != null &&
          (candidate.posts.isNotEmpty ||
              candidate.sourceIds.every(
                candidate.initializedSourceIds.contains,
              ))) {
        _initializing = false;
      }
      return;
    }
    _updatePending();
  }

  void revalidateAccepted(TopicFeed Function(TopicFeed) authorize) {
    final snapshot = _acceptedStored;
    if (snapshot == null) return;
    final current = authorize(snapshot);
    if (current != accepted) accepted = current;
    if (!_initializing) _updatePending();
  }

  void _updatePending() {
    final samePosts = const ListEquality().equals(
      accepted?.posts,
      _latest?.posts,
    );
    final sameGrouping = const MapEquality().equals(
      accepted?.seriesMemberships,
      _latest?.seriesMemberships,
    );
    pending = samePosts && sameGrouping ? null : _latest;
  }

  void settleInitialization(int expectedGeneration) {
    if (generation == expectedGeneration) _initializing = false;
  }

  void apply(
    TopicFeed latest, {
    required int expectedGeneration,
    TopicFeed? stored,
  }) {
    if (generation != expectedGeneration) return;
    accepted = latest;
    _acceptedStored = stored ?? latest;
    _latest = latest;
    pending = null;
    _initializing = false;
  }
}
