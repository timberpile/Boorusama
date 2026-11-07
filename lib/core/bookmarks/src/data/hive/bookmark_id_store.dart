import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import '../../../../../foundation/filesystem.dart';
import '../../../../content/content_map.dart';
import '../bookmark_id_allocator.dart';

/// One Hive frame stores both structural version and reservation bound. Payload
/// kinds and the activation journal share the owning metadata box, not a counter.
final class HiveBookmarkIdStore implements BookmarkIdStore {
  const HiveBookmarkIdStore(
    this.box, {
    this.fs = const IoFileSystem(),
    this.sync,
  });

  final Box<dynamic> box;
  final AppFileSystem fs;
  final Future<void> Function()? sync;
  static const reservationKey = 'idReservation';

  @override
  Future<int?> readNextId() async {
    final raw = box.get(reservationKey);
    if (raw == null) return null;
    final map = contentMap(raw);
    final next = map['nextId'];
    if (map['version'] != 1 || next is! int) {
      throw const FormatException('Unsupported Bookmark reservation state');
    }
    return next;
  }

  @override
  Future<void> writeNextId(int nextId) => box.put(reservationKey, {
    'version': 1,
    'nextId': nextId,
  });

  @override
  Future<void> durableSync() async {
    if (sync case final sync?) {
      await sync();
      return;
    }
    await box.flush();
    final path = box.path;
    if (path == null) {
      throw StateError('The Bookmark reservation store has no durable path');
    }
    await fs.syncFile(path);
    // The first reservation must also retain the newly created counter file.
    await fs.syncDirectory(p.dirname(path));
  }
}
