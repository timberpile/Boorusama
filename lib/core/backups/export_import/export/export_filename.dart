import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../../foundation/filesystem.dart';
import '../models/package_manifest.dart';

/// Empty input uses this pattern; all placeholders resolve in UTC.
const defaultExportFileNamePattern = 'boorusama-{timestamp}';

String exportFileName(DateTime timestamp) =>
    resolveExportFileNamePattern('', timestamp);

/// Supports {timestamp}, {date:yyyy-MM-dd}, and {time:HH-mm-ss}.
/// Custom date/time formats use numeric, filesystem-safe UTC components.
String resolveExportFileNamePattern(String pattern, DateTime timestamp) {
  final source = pattern.trim().isEmpty
      ? defaultExportFileNamePattern
      : pattern.trim();
  final utc = timestamp.toUtc();
  final resolved = source.replaceAllMapped(RegExp(r'\{([^{}]*)\}'), (match) {
    final token = match.group(1)!;
    if (token == 'timestamp') {
      return DateFormat("yyyy-MM-dd_HH-mm-ss'Z'", 'en_US').format(utc);
    }
    final isDate = token.startsWith('date:');
    final isTime = token.startsWith('time:');
    if (!isDate && !isTime) {
      throw const FormatException('Unsupported export file name placeholder');
    }
    final format = token.substring(5);
    final allowed = isDate
        ? RegExp(r'^(?:y{2,4}|M{1,2}|d{1,2}|[-_. ])+$')
        : RegExp(r'^(?:H{1,2}|m{1,2}|s{1,2}|[-_. ])+$');
    if (format.isEmpty || !allowed.hasMatch(format)) {
      throw const FormatException('Unsupported UTC date or time format');
    }
    return DateFormat(format, 'en_US').format(utc);
  });
  if (resolved.contains('{') || resolved.contains('}')) {
    throw const FormatException('Invalid export file name placeholder');
  }
  final name = normalizedExportFileName(resolved);
  if (name == null) {
    throw const FormatException('Invalid export file name pattern');
  }
  return name;
}

bool isValidExportFileNamePattern(String pattern) {
  try {
    resolveExportFileNamePattern(pattern, DateTime.utc(2000));
    return true;
  } on FormatException {
    return false;
  }
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
