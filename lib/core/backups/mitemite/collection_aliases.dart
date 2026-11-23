import 'dart:convert';

import 'package:collection/collection.dart';

import '../../../foundation/data_mutation_coordinator.dart';
import '../../cache/misc_data_store.dart';
import 'catalog.dart';
import 'protocol.dart';

/// Installation-local display preferences. This store grants no mirror edit or
/// trust authority; the service validates the current source owner before edits.
final class SyncCollectionAliases {
  SyncCollectionAliases(this.preferences);
  static const key = 'mitemite.v1.collection_aliases';
  final MiscDataStore preferences;
  final _writes = DataMutationCoordinator();
  Map<SyncCollectionId, String>? _values;
  bool _writeFailed = false;

  Map<SyncCollectionId, String> get values => _values ??= _read();

  Map<SyncCollectionId, String> _read() {
    final raw = preferences.get(key);
    if (raw == null) return const {};
    final json = jsonDecode(raw);
    if (json is! Map || json['version'] != 1 || json['aliases'] is! Map) {
      throw const FormatException('Invalid local collection aliases');
    }
    final entries = json['aliases'] as Map;
    if (entries.length > miteMiteMaxEntries) {
      throw const FormatException('Too many local collection aliases');
    }
    final aliases = <SyncCollectionId, String>{};
    for (final entry in entries.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid local collection alias');
      }
      final parts = (entry.key as String).split('/');
      if (parts.length != 3) {
        throw const FormatException('Invalid collection alias identity');
      }
      final id = SyncCollectionId(
        publisher: parts[0],
        kind: parts[1],
        source: parts[2],
      );
      aliases[id] = syncLabel(entry.value);
    }
    return Map.unmodifiable(aliases);
  }

  Future<void> set(SyncCollectionId id, String? value) =>
      _writes.runExclusive(() async {
        final next = Map<SyncCollectionId, String>.of(values);
        final normalized = value?.trim();
        if (normalized == null || normalized.isEmpty) {
          next.remove(id);
        } else {
          next[id] = syncLabel(normalized);
        }
        await _save(next);
      });

  /// Only a recovered, committed owner snapshot can authorize orphan cleanup.
  Future<void> retain(String kind, Set<SyncCollectionId> owned) =>
      _writes.runExclusive(
        () => _save({
          for (final entry in values.entries)
            if (entry.key.kind != kind || owned.contains(entry.key))
              entry.key: entry.value,
        }),
      );

  Future<void> forget(String publisher) => _writes.runExclusive(
    () => _save({
      for (final entry in values.entries)
        if (entry.key.publisher != publisher) entry.key: entry.value,
    }),
  );

  Future<void> _save(Map<SyncCollectionId, String> next) async {
    if (next.length > miteMiteMaxEntries) {
      throw const FormatException('Too many local collection aliases');
    }
    if (!_writeFailed && const MapEquality().equals(values, next)) return;
    try {
      await preferences.put(
        key,
        canonicalSyncJson({
          'version': 1,
          'aliases': {
            for (final entry in next.entries) entry.key.key: entry.value,
          },
        }),
      );
    } catch (_) {
      // Hive may already expose a failed write in its cache. Keep the last
      // confirmed display snapshot, and reassert even an unchanged next edit.
      _writeFailed = true;
      rethrow;
    }
    _values = Map.unmodifiable(next);
    _writeFailed = false;
  }
}
