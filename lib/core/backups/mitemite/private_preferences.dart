import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import '../../../foundation/data_mutation_coordinator.dart';
import '../../../foundation/filesystem.dart';
import '../../cache/hive_misc_data_store.dart';
import '../../cache/misc_data_store.dart';

/// Device-local sync authority must outlive cache eviction and must never be
/// copied to another install by Android backup. Ordinary cache keys stay put.
final class PrivateSyncPreferences implements MiscDataStore {
  PrivateSyncPreferences({
    required this.legacy,
    required this.box,
    required this.fs,
    required bool boxWasPresent,
  }) {
    try {
      final encoded = box.get(snapshotKey);
      if (encoded == null) {
        if (boxWasPresent || box.isNotEmpty) {
          throw const FormatException('Incomplete sync authority');
        }
        _baseline = {
          for (final key in legacy.box.keys.whereType<String>())
            if (owns(key)) key: legacy.box.get(key)!,
        };
        _migrationPending = true;
      } else {
        final value = jsonDecode(encoded);
        if (value is! Map<String, dynamic> ||
            value['version'] != 1 ||
            value['values'] is! Map<String, dynamic>) {
          throw const FormatException('Invalid sync authority snapshot');
        }
        final values = value['values'] as Map<String, dynamic>;
        if (values.entries.any(
              (entry) => !owns(entry.key) || entry.value is! String,
            ) ||
            box.keys.any(
              (key) => key != snapshotKey && (key is! String || !owns(key)),
            )) {
          throw const FormatException('Invalid sync authority entries');
        }
        _baseline = values.cast<String, String>();
      }
      if ((_baseline.isNotEmpty ||
              box.keys.any((key) => key is String && owns(key))) &&
          box.get(identityKey) == null &&
          !_baseline.containsKey(identityKey)) {
        throw const FormatException('Sync authority is missing its identity');
      }
    } catch (error, stack) {
      // Keep normal startup available, but never fall back to stale cache or
      // let the opt-in service replace a corrupt/missing signing identity.
      _loadError = error;
      _loadStack = stack;
    }
  }

  static const directoryName = 'mitemite_private';
  static const boxName = 'state_v1';
  static const snapshotKey = 'migration_v1';
  static const identityKey = 'mitemite.v1.identity';
  static bool owns(String key) => key.startsWith('mitemite.v1.');

  final HiveMiscDataStore legacy;
  final Box<String> box;
  final AppFileSystem fs;
  final _writes = DataMutationCoordinator();
  Map<String, String> _baseline = const {};
  var _migrationPending = false;
  var _confirmedBarrier = false;
  final _confirmed = <String, String>{};
  Object? _loadError;
  late StackTrace _loadStack;

  @override
  String? get(String key) {
    if (!owns(key)) return legacy.get(key);
    if (_loadError != null) return null;
    return box.get(key) ?? _baseline[key];
  }

  void _check() {
    if (_loadError case final error?) {
      Error.throwWithStackTrace(error, _loadStack);
    }
  }

  Future<void> _barrier({bool includeAncestors = false}) async {
    _confirmedBarrier = false;
    final path = box.path;
    if (path == null) throw StateError('Sync authority has no private file');
    await box.flush();
    await fs.syncFile(path);
    final directory = p.dirname(path);
    // Initial creation must persist the private-directory entry and Android's
    // no-backup parent entry as well as the Hive file's immediate parent.
    for (final target in {
      directory,
      if (includeAncestors) p.dirname(directory),
      if (includeAncestors) p.dirname(p.dirname(directory)),
    }) {
      await fs.syncDirectory(target);
    }
    _confirmed
      ..clear()
      ..addAll(_baseline)
      ..addAll({
        for (final key in box.keys.whereType<String>())
          if (owns(key)) key: box.get(key)!,
      });
    _confirmedBarrier = true;
  }

  Future<void> _migrate() async {
    _check();
    if (!_migrationPending) return;
    // One Hive frame contains the complete legacy prefix. A crash cannot leave
    // an identity copied without its trust/counter/receipt baseline.
    await box.put(snapshotKey, jsonEncode({'version': 1, 'values': _baseline}));
    await _barrier(includeAncestors: true);
    _migrationPending = false;
  }

  /// Also retry the barrier for cached writes after an interrupted/failed flush.
  Future<void> synchronize() => _writes.runExclusive(() async {
    _check();
    if (_migrationPending) {
      await _migrate();
    } else if (!_confirmedBarrier) {
      await _barrier(includeAncestors: true);
    }
  });

  @override
  Future<void> put(String key, String value) {
    if (!owns(key)) return legacy.put(key, value);
    return _writes.runExclusive(() async {
      await _migrate();
      if (_confirmedBarrier && _confirmed[key] == value && get(key) == value) {
        return;
      }
      // Invalidate before the Hive await: a failed write can still be visible
      // in memory and must never count as confirmed durable on retry.
      _confirmedBarrier = false;
      // Subsequent writes append only their key, rather than rewriting a large
      // migration snapshot or exact notification outbox for every reservation.
      await box.put(key, value);
      await _barrier();
    });
  }
}
