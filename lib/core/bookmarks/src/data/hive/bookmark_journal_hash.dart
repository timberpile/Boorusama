import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// Keep the journal's existing JSON ordering and digest for every version.
/// Only large, already encoded plans need a worker; no repository crosses it.
Future<String> bookmarkJournalHash(Map<String, Object?> plan) {
  final task = _JournalHashTask(plan);
  return _largePlan(plan)
      ? Isolate.run(task.digest)
      : Future.value(task.digest());
}

bool _largePlan(Object? value) {
  var nodes = 4096;
  var characters = 256 * 1024;
  bool visit(Object? value, int depth) {
    if (--nodes <= 0 || depth >= 64) return true;
    if (value is String) {
      characters -= value.length;
      return characters <= 0;
    }
    if (value is Map) {
      for (final entry in value.entries) {
        if (visit(entry.key, depth + 1) || visit(entry.value, depth + 1)) {
          return true;
        }
      }
    } else if (value is List) {
      for (final item in value) {
        if (visit(item, depth + 1)) return true;
      }
    }
    return false;
  }

  return visit(value, 0);
}

final class _JournalHashTask {
  const _JournalHashTask(this.plan);

  final Map<String, Object?> plan;

  String digest() => sha256.convert(utf8.encode(jsonEncode(plan))).toString();
}
