import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/misc_data_store.dart';

/// Protected local policy facts, never exported with Bookmarks or profiles.
final contentPolicySnapshotStoreProvider = Provider<ContentPolicySnapshotStore>(
  (ref) => ContentPolicySnapshotStore(ref.watch(miscDataStoreProvider)),
  dependencies: [miscDataStoreProvider],
);

class ContentPolicySnapshotStore {
  ContentPolicySnapshotStore(this.store);
  final MiscDataStore store;

  Set<String>? read(String generation) {
    final raw = store.get('contentPolicyV1/$generation');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((e) => e is! String)) return null;
      return decoded.cast<String>().toSet();
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String generation, Set<String> tags) => store.put(
    'contentPolicyV1/$generation',
    jsonEncode(tags.toList()..sort()),
  );
}

bool isTransientPolicyFailure(Object? error) {
  if (error is! DioException) return false;
  final status = error.response?.statusCode;
  if (status != null) return status == 408 || status == 429 || status >= 500;
  return const {
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
  }.contains(error.type);
}
