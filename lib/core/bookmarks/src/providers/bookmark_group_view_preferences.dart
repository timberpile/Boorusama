import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../cache/misc_data_store.dart';

const _storageKey = 'bookmarkGroupViewModes';

enum BookmarkGroupViewMode { structure, allBookmarks }

final bookmarkGroupViewPreferencesProvider =
    NotifierProvider<
      BookmarkGroupViewPreferences,
      Map<String, BookmarkGroupViewMode>
    >(
      BookmarkGroupViewPreferences.new,
      dependencies: [miscDataStoreProvider],
    );

class BookmarkGroupViewPreferences
    extends Notifier<Map<String, BookmarkGroupViewMode>> {
  Future<void> _writeQueue = Future<void>.value();
  var _disposed = false;
  Map<String, BookmarkGroupViewMode> _durable = const {};
  final _pendingModes =
      <({Object token, String id, BookmarkGroupViewMode mode})>[];
  Map<String, BookmarkGroupViewMode> _project() => Map.unmodifiable({
    ..._durable,
    for (final edit in _pendingModes) edit.id: edit.mode,
  });

  @override
  Map<String, BookmarkGroupViewMode> build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _durable = Map.unmodifiable(
      _decode(ref.read(miscDataStoreProvider).get(_storageKey)),
    );
    return _durable;
  }

  BookmarkGroupViewMode modeFor(String id) =>
      state[_canonicalId(id)] ?? BookmarkGroupViewMode.structure;

  Future<void> setMode(String id, BookmarkGroupViewMode mode) async {
    if (_disposed) return;
    final key = _canonicalId(id);
    if (state[key] == mode ||
        (state[key] == null && mode == BookmarkGroupViewMode.structure))
      return;
    final edit = (token: Object(), id: key, mode: mode);
    _pendingModes.add(edit);
    state = _project();
    try {
      await _enqueue(() => _persist({..._durable, key: mode}, publish: false));
    } finally {
      _pendingModes.remove(edit);
      if (!_disposed) state = _project();
    }
  }

  Future<void> forgetGroup(String id) => forgetGroups({id});

  Future<void> forgetGroups(Set<String> ids) {
    final requestedIds = Set<String>.of(ids);
    return _enqueue(() async {
      if (_disposed) return;
      final keys = _canonicalIds(requestedIds);
      final removed = keys.where(_durable.containsKey).toSet();
      if (removed.isEmpty) return;
      final next = Map<String, BookmarkGroupViewMode>.of(_durable)
        ..removeWhere((key, _) => removed.contains(key));
      await _persist(next);
    });
  }

  Future<void> retainGroups(Set<String> validIds) {
    final requestedIds = Set<String>.of(validIds);
    return _enqueue(() async {
      if (_disposed) return;
      final valid = _canonicalIds(requestedIds);
      if (_durable.keys.every(valid.contains)) return;
      final next = Map<String, BookmarkGroupViewMode>.of(_durable)
        ..removeWhere((key, _) => !valid.contains(key));
      await _persist(next);
    });
  }

  Future<void> restoreMissing(Map<String, BookmarkGroupViewMode> modes) {
    final requestedModes = Map<String, BookmarkGroupViewMode>.of(modes);
    return _enqueue(() async {
      if (_disposed) return;
      final normalized = <String, BookmarkGroupViewMode>{};
      for (final entry in requestedModes.entries) {
        final id = _canonicalId(entry.key);
        final previous = normalized[id];
        if (previous != null && previous != entry.value) {
          throw ArgumentError.value(
            requestedModes,
            'modes',
            'Duplicate canonical group ID',
          );
        }
        normalized[id] = entry.value;
      }
      final missing = normalized.entries.where(
        (entry) => !_durable.containsKey(entry.key),
      );
      if (missing.isEmpty) return;
      final next = Map<String, BookmarkGroupViewMode>.of(_durable)
        ..addEntries(missing);
      await _persist(next);
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    // A failed write is returned to its caller, but must not poison later work.
    _writeQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _persist(
    Map<String, BookmarkGroupViewMode> next, {
    bool publish = true,
  }) async {
    final encoded = <String, String>{
      for (final id in next.keys.toList()..sort()) id: next[id]!.name,
    };
    await ref.read(miscDataStoreProvider).put(_storageKey, jsonEncode(encoded));
    _durable = Map.unmodifiable(next);
    if (!_disposed && publish) state = _project();
  }

  String _canonicalId(String id) {
    if (!Uuid.isValidUUID(fromString: id)) {
      throw ArgumentError.value(id, 'id', 'Expected a valid group UUID');
    }
    return id.toLowerCase();
  }

  Set<String> _canonicalIds(Iterable<String> ids) => {
    for (final id in ids) _canonicalId(id),
  };

  Map<String, BookmarkGroupViewMode> _decode(String? encoded) {
    if (encoded == null) return {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return {};
      final modes = <String, BookmarkGroupViewMode>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final id = entry.key as String;
        if (!Uuid.isValidUUID(fromString: id)) continue;
        final mode = switch (entry.value as String) {
          'structure' => BookmarkGroupViewMode.structure,
          'allBookmarks' => BookmarkGroupViewMode.allBookmarks,
          _ => null,
        };
        if (mode != null) modes.putIfAbsent(id.toLowerCase(), () => mode);
      }
      return modes;
    } on FormatException {
      return {};
    }
  }
}
