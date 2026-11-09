import 'dart:convert';
import 'dart:isolate';

import 'package:coreutils/coreutils.dart';

import '../types/types.dart';
import '../utils/data_converter.dart';
import 'bookmark_backup_codec.dart';
import 'bookmark_backup_data.dart';
import 'detached_bookmark_codec.dart';

/// Only snapshots and detached codecs cross this boundary. Repository access,
/// preparation steps and import execution remain with the calling source.
final class BookmarkBackupWorker {
  BookmarkBackupWorker(BookmarkBackupCodec codec) : _codec = _detach(codec);

  final BookmarkBackupCodec _codec;

  Future<String> encodeRevision(BookmarkBackupData data) =>
      Isolate.run(_RevisionTask(data, _codec).encode);

  Future<String> encodeRollback(
    BookmarkBackupData data, {
    required int version,
    required Version? exportVersion,
    required DateTime exportDate,
  }) => Isolate.run(
    _RollbackTask(data, _codec, version, exportVersion, exportDate).encode,
  );

  Future<({ExportDataPayload metadata, BookmarkBackupData parsed})> decode(
    String encoded,
  ) => Isolate.run(_DecodeTask(encoded, _codec).decode);
}

BookmarkBackupCodec _detach(BookmarkBackupCodec original) {
  final records = detachBookmarkRecordCodec(original.records);
  return BookmarkBackupCodec(
    postDataCodec: records.postDataCodec,
    groupMetadata: records.groups.metadata,
  );
}

final class _RevisionTask {
  const _RevisionTask(this.data, this.codec);

  final BookmarkBackupData data;
  final BookmarkBackupCodec codec;

  String encode() => jsonEncode({
    'data': codec.encodeLocalRecovery(data),
    ...data.extraFields,
  });
}

final class _RollbackTask {
  const _RollbackTask(
    this.data,
    this.codec,
    this.version,
    this.exportVersion,
    this.exportDate,
  );

  final BookmarkBackupData data;
  final BookmarkBackupCodec codec;
  final int version;
  final Version? exportVersion;
  final DateTime exportDate;

  String encode() => encodeData(
    version: version,
    exportVersion: exportVersion,
    exportDate: exportDate,
    payload: codec.encodeLocalRecovery(data),
    extraFields: data.extraFields,
  );
}

final class _DecodeTask {
  const _DecodeTask(this.encoded, this.codec);

  final String encoded;
  final BookmarkBackupCodec codec;

  ({ExportDataPayload metadata, BookmarkBackupData parsed}) decode() {
    final metadata = decodeData(data: encoded);
    return (metadata: metadata, parsed: codec.parse(metadata));
  }
}
