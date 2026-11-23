// Package imports:
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shelf/shelf.dart' as shelf;

// Project imports:
import '../../../foundation/filesystem.dart';

const _kChecksumHeader = 'X-File-Checksum';

Future<shelf.Response> createDbStreamResponse({
  required AppFileSystem fs,
  required String filePath,
  required String fileName,
  String contentType = 'application/octet-stream',
  String checksumHeader = _kChecksumHeader,
}) async {
  if (!fs.fileExistsSync(filePath)) {
    return shelf.Response.notFound('Database file not found');
  }

  // Calculate checksum by consuming the file stream.
  final hash = await sha256.bind(fs.openRead(filePath)).single;
  final checksum = hash.toString();

  // Reopen file stream since the previous stream was consumed.
  final fileStream = fs.openRead(filePath);

  return shelf.Response.ok(
    fileStream,
    headers: {
      'Content-Type': contentType,
      'Content-Disposition': 'attachment; filename="$fileName"',
      checksumHeader: checksum,
    },
  );
}

/// Downloads and verifies a database at a caller-owned staging path.
Future<void> downloadDbToFile({
  required AppFileSystem fs,
  required Dio dio,
  required String url,
  required String filePath,
  String checksumHeader = _kChecksumHeader,
}) async {
  final response = await dio.get<ResponseBody>(
    url,
    options: Options(responseType: ResponseType.stream),
  );
  final expectedChecksum = response.headers.value(checksumHeader);
  if (expectedChecksum == null) {
    await response.data?.stream.listen(null).cancel();
    throw const FormatException('No checksum provided in header');
  }

  final sink = await fs.openWrite(filePath);
  try {
    await sink.addStream(response.data!.stream);
  } finally {
    await sink.close();
  }

  final checksum = await computeFileChecksum(fs: fs, filePath: filePath);
  if (checksum != expectedChecksum) {
    throw const FormatException('Database file is corrupted');
  }
}

Future<String> computeFileChecksum({
  required AppFileSystem fs,
  required String filePath,
}) async {
  final digest = await sha256.bind(fs.openRead(filePath)).single;
  return digest.toString();
}
