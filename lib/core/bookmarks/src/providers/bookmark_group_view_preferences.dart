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
    );

class BookmarkGroupViewPreferences
    extends Notifier<Map<String, BookmarkGroupViewMode>> {
  Future<void> _writeQueue = Future<void>.value();
  var _disposed = false;

  @override
  Map<String, BookmarkGroupViewMode> build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return Map.unmodifiable(
      _decode(ref.read(miscDataStoreProvider).get(_storageKey)),
    );
  }

  BookmarkGroupViewMode modeFor(String id) =>
      state[_canonicalId(id)] ?? BookmarkGroupViewMode.structure;

  Future<void> setMode(String id, BookmarkGroupViewMode mode) =>
      _enqueue(() async {
        if (_disposed) return;
        final key = _canonicalId(id);
        if (state[key] == mode ||
            (state[key] == null && mode == BookmarkGroupViewMode.structure)) {
          return;
        }
        final next = Map<String, BookmarkGroupViewMode>.of(state)..[key] = mode;
        await _persist(next);
      });

  Future<void> forgetGroup(String id) => _enqueue(() async {
    if (_disposed) return;
    final key = _canonicalId(id);
    if (!state.containsKey(key)) return;
    final next = Map<String, BookmarkGroupViewMode>.of(state)..remove(key);
    await _persist(next);
  });

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    // A failed write is returned to its caller, but must not poison later work.
    _writeQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _persist(Map<String, BookmarkGroupViewMode> next) async {
    final encoded = <String, String>{
      for (final id in next.keys.toList()..sort()) id: next[id]!.name,
    };
    await ref.read(miscDataStoreProvider).put(_storageKey, jsonEncode(encoded));
    if (!_disposed) state = Map.unmodifiable(next);
  }

  String _canonicalId(String id) {
    if (!Uuid.isValidUUID(fromString: id)) {
      throw ArgumentError.value(id, 'id', 'Expected a valid group UUID');
    }
    return id.toLowerCase();
  }

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
