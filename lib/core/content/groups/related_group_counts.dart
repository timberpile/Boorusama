import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boorus/booru/types.dart';
import '../content_access.dart';
import '../content_reference.dart';

typedef RelatedGroupCountKey = ({
  ContentIdentity group,
  ContentAccessKey access,
});

RelatedGroupCountKey? relatedGroupCountKey(GroupMetadataKey key) =>
    key.reference.engine == BooruType.danbooru &&
        key.reference.sourceKey.startsWith('related:')
    ? (group: key.reference.identity, access: key.access)
    : null;

/// A refresh tombstone suppresses old snapshot totals until a new read succeeds.
/// Null/absent API totals never become a count of the displayed member subset.
int? relatedGroupTotal(
  Map<RelatedGroupCountKey, int?> counts,
  GroupMetadataKey key, {
  int? fallback,
}) {
  final identity = relatedGroupCountKey(key);
  if (identity == null) return null;
  return counts.containsKey(identity)
      ? counts[identity]
      : fallback != null && fallback >= 0
      ? fallback
      : null;
}

/// Container-lived presentation facts survive gallery navigation, without disk
/// writes or keeping sources/clients alive. Both facts and read fences are bounded.
final relatedGroupCountsProvider =
    NotifierProvider<RelatedGroupCounts, Map<RelatedGroupCountKey, int?>>(
      RelatedGroupCounts.new,
    );

class RelatedGroupCounts extends Notifier<Map<RelatedGroupCountKey, int?>> {
  RelatedGroupCounts({this.maxEntries = 256}) {
    if (maxEntries < 1) throw ArgumentError.value(maxEntries, 'maxEntries');
  }

  final int maxEntries;
  final _slots = <RelatedGroupCountKey, _CountGeneration>{};
  var _serial = 0;
  var _disposed = false;

  @override
  Map<RelatedGroupCountKey, int?> build() {
    ref.onDispose(() => _disposed = true);
    return const {};
  }

  /// Starting a request changes no observable state (including during a source
  /// provider's build). Only admitted results and explicit refreshes notify cards.
  RelatedGroupCountRead? begin(GroupMetadataKey key) {
    if (_disposed) return null;
    final identity = relatedGroupCountKey(key);
    if (identity == null) return null;
    return RelatedGroupCountRead._(identity, _slot(identity), ++_serial);
  }

  _CountGeneration _slot(RelatedGroupCountKey key) {
    final slot = _slots.remove(key) ?? _CountGeneration();
    _slots[key] = slot;
    while (_slots.length > maxEntries) {
      _slots.remove(_slots.keys.first);
    }
    return slot;
  }

  void publish(RelatedGroupCountRead? read, int? total) {
    if (_disposed || read == null || total == null || total < 0) return;
    if (!identical(_slots[read._key], read._generation) ||
        read._serial < read._generation.publishedSerial) {
      return;
    }
    read._generation.publishedSerial = read._serial;
    _set(read._key, total);
  }

  void invalidate(GroupMetadataKey key) {
    if (_disposed) return;
    final identity = relatedGroupCountKey(key);
    if (identity == null) return;
    _slot(identity);
    _slots[identity] = _CountGeneration();
    _set(identity, null);
  }

  void _set(RelatedGroupCountKey key, int? total) {
    final next = {
      for (final entry in state.entries)
        if (_slots.containsKey(entry.key)) entry.key: entry.value,
      key: total,
    };
    if (state.containsKey(key) &&
        state[key] == total &&
        next.length == state.length) {
      return;
    }
    state = Map.unmodifiable(next);
  }
}

final class RelatedGroupCountRead {
  const RelatedGroupCountRead._(this._key, this._generation, this._serial);
  final RelatedGroupCountKey _key;
  final _CountGeneration _generation;
  final int _serial;
}

final class _CountGeneration {
  var publishedSerial = 0;
}
