import 'package:path/path.dart' as p;

import '../../../foundation/filesystem.dart';
import '../../cache/hive_misc_data_store.dart';
import '../../cache/misc_data_store.dart';

/// Authority (keys, reservations and OBSERVED) must survive before shared
/// publication or mirror apply can proceed. Ordinary preferences need no such
/// barrier; keep it specific to this opt-in consumer.
final class DurableSyncPreferences implements MiscDataStore {
  const DurableSyncPreferences(this.delegate, this.fs);
  final HiveMiscDataStore delegate;
  final AppFileSystem fs;

  @override
  String? get(String key) => delegate.get(key);

  @override
  Future<void> put(String key, String value) async {
    await delegate.put(key, value);
    await synchronize();
  }

  /// Also barrier any cached write left by an earlier failed provider attempt
  /// before reading existing keys or high-water marks in a new generation.
  Future<void> synchronize() async {
    final path = delegate.box.path;
    if (path == null) throw StateError('Sync authority has no durable path');
    await delegate.box.flush();
    await fs.syncFile(path);
    await fs.syncDirectory(p.dirname(path));
  }
}
