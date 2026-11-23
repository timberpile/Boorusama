import '../../../../foundation/data_mutation_coordinator.dart';
import '../types/bookmark.dart';

abstract interface class BookmarkIdStore {
  Future<int?> readNextId();
  Future<void> writeNextId(int nextId);
  Future<void> durableSync();
}

final class BookmarkIdExhaustedException implements Exception {
  const BookmarkIdExhaustedException();

  @override
  String toString() => 'The local Bookmark ID space is exhausted';
}

/// Every payload kind reserves from this durable bound. Reservation is separate
/// from publication, so interrupted writes may leave gaps but never recycle IDs.
final class BookmarkIdAllocator {
  BookmarkIdAllocator({
    required this.store,
    required this.coordinator,
    required this.highestExistingId,
  });

  final BookmarkIdStore store;
  final DataMutationCoordinator coordinator;
  final Future<int> Function() highestExistingId;
  int? _existingFloor;
  var _conservativeNext = 0;
  var _uncertain = false;

  Future<List<int>> reserve(int count) => coordinator.runExclusive(() async {
    if (count < 0) throw ArgumentError.value(count, 'count');
    var floor = _existingFloor;
    if (floor == null) {
      final highest = await highestExistingId();
      if (highest < -1 || highest > maxBookmarkId) {
        throw const FormatException('Invalid existing Bookmark ID');
      }
      floor = _existingFloor = highest + 1;
    }
    // Read under the shared coordinator on each reservation. Separate facade
    // instances must observe reservations made by another instance, not only
    // their own initial in-memory view.
    final stored = await store.readNextId();
    if (stored != null && (stored < 0 || stored > maxBookmarkId + 1)) {
      throw const FormatException('Invalid Bookmark reservation bound');
    }
    var next = stored ?? 0;
    if (floor > next) next = floor;
    if (_conservativeNext > next) next = _conservativeNext;
    _conservativeNext = next;
    if (_uncertain) {
      // A write or sync may have committed before throwing. Re-establish a
      // durable conservative bound before attempting another reservation.
      await _persist(next);
    }
    if (count == 0) return const [];
    if (count > maxBookmarkId + 1 - next) {
      throw const BookmarkIdExhaustedException();
    }
    _conservativeNext = next + count;
    await _persist(_conservativeNext);
    return List<int>.unmodifiable(
      List.generate(count, (offset) => next + offset),
    );
  });

  Future<void> _persist(int next) async {
    _uncertain = true;
    await store.writeNextId(next);
    await store.durableSync();
    _uncertain = false;
  }
}
