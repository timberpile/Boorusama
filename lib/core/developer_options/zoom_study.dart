import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

final zoomStudyRecorderProvider = Provider<ZoomStudyRecorder>(
  (ref) => const ZoomStudyRecorder(),
);

/// Records user-selected zoom levels without retaining media bytes or URLs.
class ZoomStudyRecorder {
  const ZoomStudyRecorder();

  static const _boxName = 'zoom_study_observations';
  static const _key = 'records';

  Future<int> record(Map<String, Object?> observation) async {
    final box = await Hive.openBox<String>(_boxName);
    final rows = decodeZoomStudyRecords(box.get(_key))
      ..add(Map<String, dynamic>.from(observation));
    await box.put(_key, jsonEncode(rows));
    return rows.length;
  }

  Future<String> export() async {
    final box = await Hive.openBox<String>(_boxName);
    final rows = decodeZoomStudyRecords(box.get(_key));
    if (rows.isEmpty) {
      throw StateError('No zoom study observations recorded');
    }
    final contents = jsonEncode({
      'schema_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'zoom_reference': 'scale relative to initial contain fit',
      'observations': rows,
    });
    return const ZoomStudyExport().save(
      contents: contents,
      fileName: zoomStudyFileName(DateTime.now()),
    );
  }

  Future<void> clear() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(_key);
  }
}

List<Map<String, dynamic>> decodeZoomStudyRecords(String? serialized) {
  final decoded = jsonDecode(serialized ?? '[]');
  if (decoded is! List) {
    throw const FormatException('Invalid zoom study data');
  }
  return [
    for (final row in decoded)
      if (row is Map<String, dynamic>)
        Map<String, dynamic>.from(row)
      else
        throw const FormatException('Invalid zoom study observation'),
  ];
}

String zoomStudyFileName(DateTime timestamp) {
  final utc = timestamp.toUtc();
  String pad(int number, int width) => number.toString().padLeft(width, '0');
  return 'boorusama-zoom-study-'
      '${pad(utc.year, 4)}${pad(utc.month, 2)}${pad(utc.day, 2)}T'
      '${pad(utc.hour, 2)}${pad(utc.minute, 2)}${pad(utc.second, 2)}'
      '${pad(utc.millisecond, 3)}Z.json';
}

class ZoomStudyExport {
  const ZoomStudyExport();

  static const channel = MethodChannel('boorusama/performance_diagnostics');

  Future<String> save({
    required String contents,
    required String fileName,
  }) async {
    final path = await channel.invokeMethod<String>('saveZoomStudy', {
      'contents': contents,
      'fileName': fileName,
    });
    if (path == null || path.isEmpty) {
      throw PlatformException(code: 'diagnostic_export_failed');
    }
    return path;
  }
}
