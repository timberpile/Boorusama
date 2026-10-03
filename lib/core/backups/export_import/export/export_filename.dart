import 'package:path/path.dart' as p;

import '../../../../foundation/filesystem.dart';
import '../models/package_manifest.dart';

String exportFileName(DateTime timestamp) {
  final utc = timestamp.toUtc().toIso8601String();
  final dateAndTime = utc
      .substring(0, 19)
      .replaceFirst('T', '_')
      .replaceAll(':', '-');
  return 'boorusama-${dateAndTime}Z$kExportPackageExtension';
}

String nextAvailableExportPath(
  String directory,
  String preferredName,
  bool Function(String path) fileExists,
) {
  final initialPath = p.join(directory, preferredName);
  if (!fileExists(initialPath)) return initialPath;

  final extension = p.extension(preferredName);
  final stem = p.basenameWithoutExtension(preferredName);
  var suffix = 2;
  while (true) {
    final candidate = p.join(directory, '$stem-$suffix$extension');
    if (!fileExists(candidate)) return candidate;
    suffix++;
  }
}

Future<String> copyExportToDirectory(
  AppFileSystem fs,
  String source,
  String directory,
) async {
  while (true) {
    final destination = nextAvailableExportPath(
      directory,
      p.basename(source),
      fs.fileExistsSync,
    );
    if (await fs.copyFileIfAbsent(source, destination)) return destination;
  }
}
