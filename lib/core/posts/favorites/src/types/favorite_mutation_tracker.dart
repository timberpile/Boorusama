/// Keeps overlapping optimism separate from acknowledged favorite state.
/// Only currently pending operations are retained; no mutations are queued.
final class FavoriteMutationTracker<Key> {
  final _pending = <Key, _Mutations>{};
  var _sequence = 0;

  int start(Key key, bool? prior, bool target) {
    final mutations = _pending.putIfAbsent(key, () => _Mutations(prior));
    final sequence = ++_sequence;
    mutations.latest = sequence;
    mutations.targets[sequence] = target;
    return sequence;
  }

  ({bool? favorite})? finish(
    Key key,
    int operation, {
    required bool acknowledged,
  }) {
    final mutations = _pending[key];
    if (mutations == null || !mutations.targets.containsKey(operation)) {
      return null;
    }
    final target = mutations.targets.remove(operation)!;
    if (acknowledged && operation > mutations.confirmedSequence) {
      mutations.confirmed = target;
      mutations.confirmedSequence = operation;
    }
    final favorite = mutations.targets[mutations.latest] ?? mutations.confirmed;
    if (mutations.targets.isEmpty) _pending.remove(key);
    return (favorite: favorite);
  }

  void forget(Key key) => _pending.remove(key);
}

final class _Mutations {
  _Mutations(this.confirmed);
  bool? confirmed;
  var latest = 0;
  var confirmedSequence = 0;
  final targets = <int, bool>{};
}
