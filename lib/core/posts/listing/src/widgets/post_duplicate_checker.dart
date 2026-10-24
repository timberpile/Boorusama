// Project imports:
import '../../../post/types.dart';

enum DuplicateCheckMode {
  id,
  idAndMd5,
  originAndId,
}

class PostDuplicateTracker<T extends Post> {
  PostDuplicateTracker({
    this.mode = DuplicateCheckMode.id,
    this.identityExtractor,
  });

  final DuplicateCheckMode mode;
  // Collections may supply engine-specific keys. Unknown identities (null)
  // must remain visible rather than sharing an invented numeric identity.
  final Object? Function(T item)? identityExtractor;
  final Set<Object> _idKeys = {};
  final Set<String> _md5Keys = {};

  bool isDuplicate(T item) {
    switch (mode) {
      case DuplicateCheckMode.id:
      case DuplicateCheckMode.originAndId:
        return _idKeys.contains(_identity(item));
      case DuplicateCheckMode.idAndMd5:
        return _idKeys.contains(_identity(item)) ||
            (item.md5.isNotEmpty && _md5Keys.contains(item.md5));
    }
  }

  Object? _identity(T item) => identityExtractor != null
      ? identityExtractor!(item)
      : mode == DuplicateCheckMode.originAndId
      ? (
          item.origin.booruType,
          item.origin.sourceHost.isEmpty
              ? 'profile:${item.origin.profileIdHint ?? item.origin.booruId}'
              : item.origin.sourceHost,
          item.id,
        )
      : item.id;

  void trackItem(T item) {
    final identity = _identity(item);
    if (identity != null) _idKeys.add(identity);

    if (mode == DuplicateCheckMode.idAndMd5) {
      if (item.md5.isNotEmpty) {
        _md5Keys.add(item.md5);
      }
    }
  }

  void clear() {
    _idKeys.clear();
    _md5Keys.clear();
  }

  void rebuildFrom(Iterable<T> items) {
    clear();
    items.forEach(trackItem);
  }
}
