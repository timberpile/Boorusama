import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../content/content_map.dart';
import '../export_import/package/bookmark_transfer_format.dart';
import '../export_import/package/export_package_exception.dart';

/// Decode only complete rows and cap bytes before UTF-8 or JSON decoding.
Stream<Map<String, Object?>> readBookmarkTransferRows(
  Stream<List<int>> input, {
  void Function(int bytes)? onRowProcessed,
}) async* {
  final row = BytesBuilder(copy: false);
  await for (final data in input) {
    final chunk = data is Uint8List ? data : Uint8List.fromList(data);
    var start = 0;
    while (start < chunk.length) {
      final end = chunk.indexOf(10, start);
      final stop = end < 0 ? chunk.length : end;
      if (row.length + stop - start > bookmarkTransferRowBytes) {
        throw const ExportPackageLimitException('Bookmark row is too large');
      }
      row.add(Uint8List.sublistView(chunk, start, stop));
      if (end < 0) break;
      final bytes = row.length + 1;
      yield contentMap(jsonDecode(utf8.decode(row.takeBytes())));
      onRowProcessed?.call(bytes);
      start = end + 1;
    }
  }
  if (row.isNotEmpty) {
    throw const FormatException('Incomplete Bookmark transfer row');
  }
}

final class BookmarkTransferRowsWriter {
  BookmarkTransferRowsWriter(this.directory, this.table, this.chargeBytes);

  static const _bufferBytes = 512 * 1024;
  final String directory;
  final BookmarkTransferTable table;
  final void Function(int) chargeBytes;
  final List<String> paths = [];
  final _buffer = BytesBuilder(copy: false);
  RandomAccessFile? _file;
  var _bytes = 0;

  Future<void> add(Map<String, Object?> row) async {
    final bytes = utf8.encode(jsonEncode(row));
    if (bytes.length > bookmarkTransferRowBytes) {
      throw const ExportPackageLimitException('Bookmark row is too large');
    }
    final length = bytes.length + 1;
    chargeBytes(length);
    if (_file == null || _bytes + length > bookmarkTransferPartBytes) {
      await _closePart();
      await _openPart();
    }
    _buffer.add(bytes);
    _buffer.addByte(10);
    _bytes += length;
    if (_buffer.length >= _bufferBytes) await _flush();
  }

  Future<void> _flush() async {
    if (_buffer.isNotEmpty) await _file!.writeFrom(_buffer.takeBytes());
  }

  Future<void> _openPart() async {
    final path = bookmarkTransferPartPath(table, paths.length);
    final output = File(p.join(directory, path));
    await output.parent.create(recursive: true);
    _file = await output.open(mode: FileMode.write);
    paths.add(path);
    _bytes = 0;
  }

  Future<void> _closePart() async {
    final file = _file;
    if (file == null) return;
    try {
      await _flush();
    } finally {
      _file = null;
      await file.close();
    }
  }

  Future<void> close({required bool completed}) async {
    if (completed && paths.isEmpty) await _openPart();
    await _closePart();
  }
}
