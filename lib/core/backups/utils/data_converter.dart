// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:coreutils/coreutils.dart';

// Project imports:
import '../types/types.dart';

class DataBackupConverter {
  DataBackupConverter({
    required this.version,
    required this.exportVersion,
  });

  final int version;
  final Version? exportVersion;

  String encode({
    required List<dynamic> payload,
    Map<String, dynamic> extraFields = const {},
  }) {
    return encodeData(
      version: version,
      exportDate: DateTime.now(),
      exportVersion: exportVersion,
      payload: payload,
      extraFields: extraFields,
    );
  }

  ExportDataPayload decode({required String data, BuildContext? uiContext}) {
    return decodeData(data: data);
  }

  String encodeSingle(Map<String, dynamic> item) => encode(payload: [item]);

  T decodeSingle<T>(String data, T Function(Map<String, dynamic>) parser) {
    final payload = decode(data: data);
    if (payload.data.isEmpty) throw Exception('No data found in payload');
    return parser(payload.data.first as Map<String, dynamic>);
  }
}

String encodeData({
  required int version,
  required DateTime exportDate,
  required Version? exportVersion,
  required List<dynamic> payload,
  Map<String, dynamic> extraFields = const {},
}) {
  final data = ExportDataPayload(
    version: version,
    exportDate: exportDate,
    exportVersion: exportVersion,
    data: payload,
    extraFields: extraFields,
  ).toJson();

  return jsonEncode(data);
}

ExportDataPayload decodeData({required String data, BuildContext? uiContext}) {
  dynamic json;
  try {
    json = jsonDecode(data);
  } on FormatException catch (error) {
    throw _invalidBackupFormat('JSON decoding failed: $error');
  }

  return switch (json) {
    {
      'version': final int version,
      'data': final List<dynamic> payload,
    } =>
      ExportDataPayload(
        version: version,
        exportDate: switch (json['date']) {
          final String dateStr => DateTime.tryParse(dateStr),
          _ => null,
        },
        exportVersion: Version.tryParse(json['exportVersion']),
        data: payload,
        extraFields: Map<String, dynamic>.from(json)
          ..removeWhere(
            (key, _) => {
              'version',
              'exportVersion',
              'date',
              'data',
            }.contains(key),
          ),
      ),
    final List<dynamic> legacyList => ExportDataPayload.legacy(
      data: legacyList,
    ),
    final Map<String, dynamic> legacyMap => ExportDataPayload.legacy(
      data: [legacyMap],
    ),
    final Map<dynamic, dynamic> map => throw _invalidBackupFormat(
      'Backup object must contain an integer "version" and a list "data". '
      'Found keys: ${map.keys.join(', ')}; '
      'version type: ${map['version'].runtimeType}; '
      'data type: ${map['data'].runtimeType}.',
    ),
    final value => throw _invalidBackupFormat(
      'Expected a backup object or list, got ${value.runtimeType}.',
    ),
  };
}

Never _invalidBackupFormat(String details) {
  if (kDebugMode) {
    debugPrint('[Backup import] $details');
    throw InvalidBackupFormatException(details);
  }

  throw const InvalidBackupFormatException();
}
