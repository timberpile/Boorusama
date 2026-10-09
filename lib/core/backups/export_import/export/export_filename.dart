import 'dart:convert';

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

/// Returns a portable .bsexport file name, or null for an invalid name.
String? normalizedExportFileName(String input) {
  final trimmed = input.trim();
  final stem = trimmed.toLowerCase().endsWith(kExportPackageExtension)
      ? trimmed.substring(0, trimmed.length - kExportPackageExtension.length)
      : trimmed;
  if (stem.isEmpty ||
      stem != stem.trim() ||
      stem == '.' ||
      stem == '..' ||
      stem.endsWith('.') ||
      RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]').hasMatch(stem) ||
      RegExp(
        r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$',
        caseSensitive: false,
      ).hasMatch(stem) ||
      utf8.encode('$stem$kExportPackageExtension').length > 255) {
    return null;
  }
  return '$stem$kExportPackageExtension';
}

String exportFileNameStem(String fileName) =>
    fileName.substring(0, fileName.length - kExportPackageExtension.length);

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
  String directory, {
  String? fileName,
}) async {
  final name = fileName ?? p.basename(source);
  if (normalizedExportFileName(name) != name) {
    throw ArgumentError.value(name, 'fileName', 'Invalid export file name');
  }
  while (true) {
    final destination = nextAvailableExportPath(
      directory,
      name,
      fs.fileExistsSync,
    );
    if (await fs.copyFileIfAbsent(source, destination)) return destination;
  }
}
